# Builds docs/images from raw screenshots of the running port:
#   banner.jpg  the game's logo (cut from a title-screen screenshot) over a
#               darkened gameplay backdrop, with the port's tagline
#   *.jpg       README screenshots, resized to 1280 wide
# Screenshots come from your own copy of the game; none are generated here.
param(
  [Parameter(Mandatory = $true)][string]$Shots,   # folder of raw PNG screenshots
  [string]$Out = ""
)
# $PSScriptRoot is not set yet while Windows PowerShell 5.1 binds defaults.
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..\docs\images" }
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $Out | Out-Null
$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
function Save-Jpg($bmp, $path) {
  $p = New-Object System.Drawing.Imaging.EncoderParameters 1
  $p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]88)
  $bmp.Save($path, $jpeg, $p)
}
function Resize-Jpg($src, $name, $w = 1280, $crop = $null) {
  $img = [System.Drawing.Image]::FromFile($src)
  $r = if ($crop) { $crop } else { [Trim]::Content([System.Drawing.Bitmap]$img) }
  $h = [int]($r.Height * $w / $r.Width)
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), $r, [System.Drawing.GraphicsUnit]::Pixel)
  Save-Jpg $bmp (Join-Path $Out $name); $g.Dispose(); $bmp.Dispose(); $img.Dispose()
  "  $name"
}

Add-Type -ReferencedAssemblies System.Drawing @'
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
public static class Trim {
    // Bounds of `img` without fully black edge columns and rows (the unused
    // edge of the PlayStation display), so screenshots show only the picture.
    public static Rectangle Content(Bitmap img) {
        int w = img.Width, h = img.Height;
        var d = img.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var px = new int[w * h];
        System.Runtime.InteropServices.Marshal.Copy(d.Scan0, px, 0, px.Length);
        img.UnlockBits(d);
        System.Func<int, bool> darkCol = x => { long s = 0; for (int y = 0; y < h; y += 4) { int c = px[y * w + x]; s += ((c >> 16) & 255) + ((c >> 8) & 255) + (c & 255); } return s / (h / 4 + 1) < 24; };
        System.Func<int, bool> darkRow = y => { long s = 0; for (int x = 0; x < w; x += 4) { int c = px[y * w + x]; s += ((c >> 16) & 255) + ((c >> 8) & 255) + (c & 255); } return s / (w / 4 + 1) < 24; };
        int l = 0, r = w - 1, t = 0, b = h - 1;
        while (l < r && darkCol(l)) l++;
        while (r > l && darkCol(r)) r--;
        while (t < b && darkRow(t)) t++;
        while (b > t && darkRow(b)) b--;
        return new Rectangle(l, t, r - l + 1, b - t + 1);
    }
}
public static class LogoCut {
    // Copies `src` out of `img` and makes the background transparent: a flood
    // fill from the crop's border through every pixel that is not part of the
    // logo's white outline. The outline itself and everything inside it stay.
    public static Bitmap Cut(Image img, Rectangle src) {
        int w = src.Width, h = src.Height;
        var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp)) g.DrawImage(img, new Rectangle(0, 0, w, h), src, GraphicsUnit.Pixel);
        var d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        var px = new int[w * h];
        System.Runtime.InteropServices.Marshal.Copy(d.Scan0, px, 0, px.Length);
        var bg = new bool[w * h];
        var q = new Queue<int>();
        System.Func<int, bool> white = i => {
            int c = px[i]; int r = (c >> 16) & 255, gg = (c >> 8) & 255, b = c & 255;
            return r > 200 && gg > 200 && b > 200;
        };
        for (int x = 0; x < w; x++) { q.Enqueue(x); q.Enqueue((h - 1) * w + x); }
        for (int y = 0; y < h; y++) { q.Enqueue(y * w); q.Enqueue(y * w + w - 1); }
        while (q.Count > 0) {
            int i = q.Dequeue();
            if (bg[i] || white(i)) continue;
            bg[i] = true;
            int x = i % w, y = i / w;
            if (x > 0) q.Enqueue(i - 1); if (x < w - 1) q.Enqueue(i + 1);
            if (y > 0) q.Enqueue(i - w); if (y < h - 1) q.Enqueue(i + w);
        }
        for (int i = 0; i < px.Length; i++) if (bg[i]) px[i] = 0;
        System.Runtime.InteropServices.Marshal.Copy(px, 0, d.Scan0, px.Length);
        bmp.UnlockBits(d);
        return bmp;
    }
}
'@

# ---- banner ----
$W = 1920; $H = 380
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$bg = [System.Drawing.Image]::FromFile("$Shots\backdrop.png")
$bb = [Trim]::Content([System.Drawing.Bitmap]$bg)
$srcH = [int]($H * $bb.Width / $W)
$srcY = $bb.Y + [int](($bb.Height - $srcH) * 0.30)
$g.DrawImage($bg, (New-Object System.Drawing.Rectangle 0, 0, $W, $H), (New-Object System.Drawing.Rectangle $bb.X, $srcY, $bb.Width, $srcH), [System.Drawing.GraphicsUnit]::Pixel)
$bg.Dispose()
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, 16, 20, 51))), 0, 0, $W, $H)
$shade = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point ($W + 1), 0), ([System.Drawing.Color]::FromArgb(235, 16, 20, 51)), ([System.Drawing.Color]::FromArgb(30, 16, 20, 51))
$g.FillRectangle($shade, 0, 0, $W, $H)

$title = [System.Drawing.Image]::FromFile("$Shots\title.png")
$logo = [LogoCut]::Cut($title, (New-Object System.Drawing.Rectangle 180, 130, 1640, 760))
$title.Dispose()
$logoH = 330; $logoW = [int]($logo.Width * $logoH / $logo.Height)
$g.DrawImage($logo, 70, 25, $logoW, $logoH)
$logo.Dispose()

$tx = 70 + $logoW + 60
$big = New-Object System.Drawing.Font "Segoe UI", 56, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$small = New-Object System.Drawing.Font "Segoe UI Semibold", 30, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$shadowB = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(170, 0, 0, 0))
$pink = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 92, 165))
$g.DrawString("Native PC port", $big, $shadowB, $tx + 3, 128)
$g.DrawString("Native PC port", $big, [System.Drawing.Brushes]::White, $tx, 125)
$g.DrawString("Aim with your mouse or a controller", $small, $shadowB, $tx + 6, 203)
$g.DrawString("Aim with your mouse or a controller", $small, $pink, $tx + 4, 200)
Save-Jpg $bmp (Join-Path $Out 'banner.jpg'); $g.Dispose(); $bmp.Dispose()
"  banner.jpg"

# ---- screenshots ----
$map = [ordered]@{ 'title.png' = 'title.jpg'; 'gameplay-stage.png' = 'gameplay-stage.jpg'; 'gameplay-2.png' = 'gameplay-2.jpg';
                   'gameplay-3.png' = 'gameplay-3.jpg'; 'stage-select.png' = 'stage-select.jpg'; 'calibration.png' = 'calibration.jpg';
                   'mode-select.png' = 'mode-select.jpg'; 'arrange.png' = 'arrange.jpg' }
foreach ($k in $map.Keys) { if (Test-Path "$Shots\$k") { Resize-Jpg "$Shots\$k" $map[$k] } }
# The controller-sight shot is a full window capture; keep only the picture.
if (Test-Path "$Shots\controller-sight.png") {
  Resize-Jpg "$Shots\controller-sight.png" 'controller-sight.jpg' 960 (New-Object System.Drawing.Rectangle 8, 36, 960, 720)
}
