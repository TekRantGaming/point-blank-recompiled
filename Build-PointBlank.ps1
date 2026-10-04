<#
  Point Blank builder.

  Builds the PC port on this computer from your own Point Blank disc
  (PlayStation, North America, SLUS-00481). Nothing from the game is
  downloaded or included: the game code is translated and compiled here,
  from your disc image.

  Steps: check build tools (offer to install them), pick your .cue, check it
  is Point Blank, translate the game code with psxrecomp, compile, and put
  the finished game in the PointBlank folder.
#>
param(
    [string]$Cue,                         # skip the file picker
    [string]$OutDir = "$PSScriptRoot\PointBlank",
    [switch]$Yes,                         # answer yes to every question
    [switch]$NoShortcut,                  # never add a desktop shortcut
    [switch]$NoLaunch                     # do not offer to start the game
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$serial = 'SLUS-00481'
$knownMd5 = 'd4804593a5dab1c91caf91eb81be8742'   # Redump "Point Blank (USA)" track 1

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Step($n, $text) { Write-Host ""; Write-Host " $n  $text" -ForegroundColor Green }
function Ask($question) {
    if ($Yes) { return $true }
    $a = Read-Host "$question [Y/n]"
    return ($a -eq '' -or $a -match '^[Yy]')
}
function Fail($text) {
    Write-Host ""; Write-Host " $text" -ForegroundColor Red
    if (-not $Yes) { Read-Host "Press Enter to close" }
    exit 1
}
# Native tools write progress to stderr; under 'Stop' Windows PowerShell 5.1
# would treat that as an error, so judge them by exit code instead.
function Run($what, [scriptblock]$cmd) {
    $ErrorActionPreference = 'Continue'
    & $cmd 2>&1 | ForEach-Object { "    $_" }
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($code -ne 0) { Fail "$what failed (exit code $code, see above)." }
}

Clear-Host
Say ""
Say "  POINT BLANK  -  PC port builder" 'Yellow'
Say "  Builds the game on this PC from your own PlayStation disc."
Say "  This takes about 15 to 30 minutes, most of it compiling."

if (-not (Test-Path "$root\psxrecomp\psxrecomp_cli.py")) {
    Fail "The psxrecomp folder is missing. Download the builder zip from the Releases page (not GitHub's 'Source code' zip), or clone with --recursive."
}

# ---------------------------------------------------------------- 1. tools ---
Step 1 "Checking build tools"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
function Find-VS { if (Test-Path $vswhere) { & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Llvm.Clang -property installationPath } }
function Have($exe, $fallback) { (Get-Command $exe -ErrorAction SilentlyContinue) -or ($fallback -and (Test-Path $fallback)) }
function Find-Python {
    foreach ($c in @("$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
                     "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
                     "$env:ProgramFiles\Python313\python.exe",
                     "$env:ProgramFiles\Python312\python.exe")) {
        if (Test-Path $c) { return $c }
    }
    # The Microsoft Store "python" alias only opens the Store; skip it.
    $p = Get-Command python -ErrorAction SilentlyContinue
    if ($p -and $p.Source -notmatch 'WindowsApps') { return $p.Source }
    return $null
}

$missing = @()
if (-not (Find-VS)) { $missing += 'vs' }
if (-not (Have cmake "$env:ProgramFiles\CMake\bin\cmake.exe")) { $missing += 'cmake' }
if (-not (Have ninja "")) { $missing += 'ninja' }
if (-not (Find-Python)) { $missing += 'python' }

if ($missing.Count) {
    Say "  Missing:" 'Yellow'
    if ($missing -contains 'vs') { Say "   - Visual Studio 2022 Build Tools with C++ and Clang (about 6 GB)" 'Yellow' }
    if ($missing -contains 'cmake') { Say "   - CMake" 'Yellow' }
    if ($missing -contains 'ninja') { Say "   - Ninja" 'Yellow' }
    if ($missing -contains 'python') { Say "   - Python 3" 'Yellow' }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Fail "winget is not available. Install the tools above yourself, then run this again." }
    if (-not (Ask "  Install them now with winget? Windows will ask for permission")) { Fail "The build tools are needed. Install them, then run this again." }
    $wg = @('--accept-package-agreements', '--accept-source-agreements', '--silent')
    if ($missing -contains 'cmake') { winget install --id Kitware.CMake -e @wg }
    if ($missing -contains 'ninja') { winget install --id Ninja-build.Ninja -e @wg }
    if ($missing -contains 'python') { winget install --id Python.Python.3.12 -e --scope user @wg }
    if ($missing -contains 'vs') {
        Say "  Installing Visual Studio Build Tools. This can take a while." 'Yellow'
        winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-package-agreements --accept-source-agreements --override "--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --add Microsoft.VisualStudio.Component.VC.Llvm.Clang --add Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset --add Microsoft.VisualStudio.Component.Windows11SDK.26100"
    }
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (Find-VS)) { Fail "Visual Studio Build Tools still not found. Restart your PC and run this again." }
    if (-not (Find-Python)) { Fail "Python still not found. Restart your PC and run this again." }
}
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) { $env:Path += ";$env:ProgramFiles\CMake\bin" }
$python = Find-Python

# Load the 64-bit Visual Studio environment (compilers, Windows SDK) into
# this PowerShell session.
$vs = Find-VS
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
cmd /c "`"$vcvars`" >nul && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($matches[1])" -Value $matches[2] }
}
if (-not (Get-Command clang-cl -ErrorAction SilentlyContinue)) { Fail "clang-cl was not found. In the Visual Studio Installer, add 'C++ Clang tools for Windows' to Build Tools." }
Say "  Build tools ready." 'Green'

# ------------------------------------------------------------------ 2. disc ---
Step 2 "Choosing your Point Blank disc"
if (-not $Cue) {
    Say "  Pick the .cue file of your Point Blank (USA) disc image."
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Select your Point Blank (USA) .cue file'
    $dlg.Filter = 'Cue sheet (*.cue)|*.cue'
    if ($dlg.ShowDialog() -ne 'OK') { Fail "No disc chosen." }
    $Cue = $dlg.FileName
}
if (-not (Test-Path $Cue)) { Fail "File not found: $Cue" }
$Cue = (Resolve-Path $Cue).Path

Say "  Checking the disc..."
New-Item -ItemType Directory -Force "$root\disc" | Out-Null
$probeJson = Join-Path $env:TEMP "pointblank_probe.json"
Run "Reading the disc" { & $python "$root\psxrecomp\tools\new_project_layout\probe_disc.py" $Cue --json-out $probeJson --write-boot-exe "$root\disc" }
$probe = Get-Content $probeJson -Raw | ConvertFrom-Json
if ($probe.serial -ne $serial) { Fail "That disc is $($probe.serial), not Point Blank (USA, $serial)." }
if ($probe.data_track_md5 -ne $knownMd5) {
    Say "  This is Point Blank ($serial), but not the exact Redump image this port was made with." 'Yellow'
    Say "  It will probably still work." 'Yellow'
} else {
    Say "  Found Point Blank ($serial), verified." 'Green'
}

# Point game.toml at this disc.
$toml = Get-Content "$root\game.toml" -Raw
$cueToml = $Cue -replace '\\', '/'
$toml = [regex]::Replace($toml, '(?m)^disc = .*$', "disc = `"$cueToml`"")
[IO.File]::WriteAllText("$root\game.toml", $toml)

# --------------------------------------------------------------- 3. translate ---
Step 3 "Translating the game code (a few minutes)"
Push-Location $root
try {
    Run "Building the recompiler" { cmake -S psxrecomp/recompiler -B build-recompiler -G Ninja -DCMAKE_BUILD_TYPE=Release }
    Run "Building the recompiler" { cmake --build build-recompiler }
    Run "Translating" { & $python psxrecomp/psxrecomp_cli.py generate --config game.toml --project-root . --disc $Cue }

    # -------------------------------------------------------------- 4. compile ---
    Step 4 "Compiling (the long part)"
    Run "Configuring" { cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl }
    Run "Compiling" { cmake --build build --target psx-runtime }
} finally { Pop-Location }

# ---------------------------------------------------------------- 5. stage ---
Step 5 "Putting the game together"
$bin = "$root\build"
New-Item -ItemType Directory -Force $OutDir | Out-Null
Copy-Item "$bin\PointBlank_Recompiled.exe", "$bin\game.toml", "$bin\game_options.toml", "$bin\psx_game_version.txt" $OutDir -Force
foreach ($d in 'assets', 'bios', 'mods') { Copy-Item "$bin\$d" $OutDir -Recurse -Force }
$exe = "$OutDir\PointBlank_Recompiled.exe"
Say "  Done: $exe" 'Green'

if (-not $NoShortcut -and (Ask "  Add a desktop shortcut?")) {
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Point Blank.lnk'
    $sh = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $sh.TargetPath = $exe; $sh.WorkingDirectory = $OutDir; $sh.Save()
    Say "  Shortcut added." 'Green'
}
Say ""
Say "  All done. Aim with the mouse or a controller; see README.md for the controls." 'Green'
if (-not $NoLaunch -and (Ask "  Start Point Blank now?")) { Start-Process $exe -WorkingDirectory $OutDir }
