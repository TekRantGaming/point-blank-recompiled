# Packages build\ into a ready-to-play Windows zip. Contains the game program,
# the open-source OpenBIOS, launcher assets and mods. No disc data: players
# install their own disc from the launcher.
param([string]$Version = (Get-Content (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\VERSION")).Trim())
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$bin = Join-Path $root 'build'
$name = "PointBlank-PC-Port-v$Version-windows-x64"
$stage = Join-Path $root "dist\$name"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force "$stage\disc", "$stage\saves" | Out-Null
Copy-Item "$bin\PointBlank_Recompiled.exe", "$root\game.toml", "$bin\game_options.toml", "$bin\psx_game_version.txt" $stage
foreach ($d in 'assets', 'bios', 'mods') { Copy-Item "$bin\$d" $stage -Recurse }
Copy-Item "$root\README.md" "$stage\README.md"
Set-Content -Encoding ascii "$stage\disc\PUT YOUR DISC HERE.txt" "Use the launcher's Browse For Disc and Install To Game Folder buttons, or copy your Point Blank (USA) .cue and .bin files into this folder."
$zip = Join-Path $root "dist\$name.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $stage -DestinationPath $zip
"$zip"
