# Draws launcher_assets/img/boxart.tga: an original launcher cover for the port
# (a target and crosshair with the title set in a system font). It uses no art
# from the game.
param([string]$Out = "")
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\launcher_assets\img\boxart.tga" }
Add-Type -AssemblyName System.Drawing
$W = 512; $H = 712
$bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

# Background: deep navy to violet.
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point 0, $H), ([System.Drawing.Color]::FromArgb(255, 14, 18, 52)), ([System.Drawing.Color]::FromArgb(255, 58, 22, 92))
$g.FillRectangle($bg, 0, 0, $W, $H)

# Target: concentric rings, alternating pink and blue, centred low.
$cx = $W / 2; $cy = 420
$pink = [System.Drawing.Color]::FromArgb(255, 255, 79, 154)
$blue = [System.Drawing.Color]::FromArgb(255, 47, 123, 255)
$white = [System.Drawing.Color]::FromArgb(255, 245, 245, 255)
$radii = 190, 150, 110, 70, 32
for ($i = 0; $i -lt $radii.Count; $i++) {
  $r = $radii[$i]
  $c = if ($i % 2 -eq 0) { $pink } else { $blue }
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $c), $cx - $r, $cy - $r, 2 * $r, 2 * $r)
  $g.DrawEllipse((New-Object System.Drawing.Pen $white, 6), $cx - $r, $cy - $r, 2 * $r, 2 * $r)
}
# Crosshair over the target.
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(235, 255, 255, 255)), 10
$g.DrawLine($pen, $cx, $cy - 192, $cx, $cy - 50); $g.DrawLine($pen, $cx, $cy + 50, $cx, $cy + 235)
$g.DrawLine($pen, $cx - 235, $cy, $cx - 50, $cy); $g.DrawLine($pen, $cx + 50, $cy, $cx + 235, $cy)
$g.FillEllipse([System.Drawing.Brushes]::White, $cx - 9, $cy - 9, 18, 18)

# Title.
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Center
$big = New-Object System.Drawing.Font "Segoe UI Black", 92, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$small = New-Object System.Drawing.Font "Segoe UI Semibold", 28, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$shadow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(170, 0, 0, 0))
foreach ($t in @(@("POINT", 24), @("BLANK", 112))) {
  $g.DrawString($t[0], $big, $shadow, (New-Object System.Drawing.RectangleF 5, ($t[1] + 5), $W, 120), $fmt)
  $g.DrawString($t[0], $big, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, $t[1], $W, 120), $fmt)
}
$g.DrawString("PC PORT", $small, (New-Object System.Drawing.SolidBrush $pink), (New-Object System.Drawing.RectangleF 0, 650, $W, 40), $fmt)
$g.Dispose()

# Uncompressed 32-bit TGA, top-left origin.
$ms = New-Object System.IO.MemoryStream
$hdr = New-Object byte[] 18
$hdr[2] = 2
$hdr[12] = $W -band 255; $hdr[13] = $W -shr 8
$hdr[14] = $H -band 255; $hdr[15] = $H -shr 8
$hdr[16] = 32; $hdr[17] = 0x28
$ms.Write($hdr, 0, 18)
$rect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$px = New-Object byte[] ($W * $H * 4)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $px, 0, $px.Length)
$bmp.UnlockBits($data)
$ms.Write($px, 0, $px.Length)   # BGRA, which is TGA's byte order
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
[IO.File]::WriteAllBytes($Out, $ms.ToArray())
$bmp.Save(($Out -replace '\.tga$', '.png'), [System.Drawing.Imaging.ImageFormat]::Png)
"boxart: $Out"
