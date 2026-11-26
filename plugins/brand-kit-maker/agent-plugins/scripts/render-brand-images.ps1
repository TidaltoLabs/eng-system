Add-Type -AssemblyName System.Drawing

if (-not ('BrandKit.Alpha' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace BrandKit {
    public static class Alpha {
        public static int[] Clean(IntPtr address, int stride, int width, int height,
                                  int minAlpha, int keyR, int keyG, int keyB, int tolerance, int feather) {
            int left = width, top = height, right = -1, bottom = -1;
            bool hasClear = false;
            byte[] row = new byte[width * 4];
            for (int y = 0; y < height; y++) {
                IntPtr line = IntPtr.Add(address, y * stride);
                Marshal.Copy(line, row, 0, row.Length);
                for (int x = 0; x < width; x++) {
                    int p = x * 4;
                    if (keyR >= 0 && row[p + 3] > 0) {
                        int distance = Math.Max(Math.Abs(row[p + 2] - keyR),
                            Math.Max(Math.Abs(row[p + 1] - keyG), Math.Abs(row[p] - keyB)));
                        int delta = distance - tolerance;
                        if (delta <= 0) {
                            row[p + 3] = 0;
                        } else if (delta < feather) {
                            double coverage = (double)delta / feather;
                            row[p] = Unmix(row[p], keyB, coverage);
                            row[p + 1] = Unmix(row[p + 1], keyG, coverage);
                            row[p + 2] = Unmix(row[p + 2], keyR, coverage);
                            row[p + 3] = (byte)Math.Round(row[p + 3] * coverage);
                        }
                    }
                    if (row[p + 3] < minAlpha) {
                        row[p] = row[p + 1] = row[p + 2] = row[p + 3] = 0;
                        hasClear = true;
                        continue;
                    }
                    left = Math.Min(left, x);
                    top = Math.Min(top, y);
                    right = Math.Max(right, x);
                    bottom = Math.Max(bottom, y);
                }
                Marshal.Copy(row, 0, line, row.Length);
            }
            return new int[] { left, top, right, bottom, hasClear ? 1 : 0 };
        }

        private static byte Unmix(int sample, int background, double coverage) {
            double value = (sample - background * (1 - coverage)) / coverage;
            return (byte)Math.Round(Math.Min(255, Math.Max(0, value)));
        }
    }
}
'@
}

function New-BrandBitmap {
    param([int]$Width, [int]$Height)
    return [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function New-BrandGraphics {
    param([System.Drawing.Bitmap]$Bitmap)
    $g = [System.Drawing.Graphics]::FromImage($Bitmap)
    $g.CompositingQuality = 'HighQuality'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    $g.SmoothingMode = 'AntiAlias'
    return $g
}

function Draw-BrandFit {
    param(
        [System.Drawing.Graphics]$Graphics, [System.Drawing.Image]$Image,
        [double]$X, [double]$Y, [double]$Width, [double]$Height
    )
    $scale = [Math]::Min($Width / $Image.Width, $Height / $Image.Height)
    $w = $Image.Width * $scale
    $h = $Image.Height * $scale
    $target = [System.Drawing.RectangleF]::new(($X + ($Width - $w) / 2), ($Y + ($Height - $h) / 2), $w, $h)
    $Graphics.DrawImage($Image, $target)
}

function Get-BrandCutout {
    param([string]$Path, [System.Collections.IDictionary]$Settings)
    $source = [System.Drawing.Bitmap]::new($Path)
    try {
        if ($source.RawFormat.Guid -ne [System.Drawing.Imaging.ImageFormat]::Png.Guid) {
            throw 'Logo 源文件须为 PNG。'
        }
        if ($source.Width -gt 8192 -or $source.Height -gt 8192) {
            throw 'Logo 源图的单边须在 8192 px 以内。'
        }
        $pixels = New-BrandBitmap $source.Width $source.Height
        try {
            $g = [System.Drawing.Graphics]::FromImage($pixels)
            try {
                $g.CompositingMode = 'SourceCopy'
                $g.DrawImageUnscaled($source, 0, 0)
            } finally { $g.Dispose() }

            $r = $gKey = $b = -1
            if ($Settings.mode -eq 'color-key') {
                $key = [System.Drawing.ColorTranslator]::FromHtml($Settings.keyColor)
                $r = $key.R; $gKey = $key.G; $b = $key.B
            }
            $area = [System.Drawing.Rectangle]::new(0, 0, $pixels.Width, $pixels.Height)
            $bits = $pixels.LockBits($area, 'ReadWrite', 'Format32bppArgb')
            try {
                $bounds = [BrandKit.Alpha]::Clean($bits.Scan0, $bits.Stride, $pixels.Width, $pixels.Height,
                    $Settings.alphaThreshold, $r, $gKey, $b, [int]$Settings['keyTolerance'], [int]$Settings['keyFeather'])
            } finally { $pixels.UnlockBits($bits) }
            if ($bounds[2] -lt $bounds[0]) { throw '清理后没有可见 Logo，请检查源图和抠图参数。' }
            if (-not $bounds[4]) { throw '检测不到透明像素，请指定正确的色键或提供透明 PNG。' }

            $width = $bounds[2] - $bounds[0] + 1
            $height = $bounds[3] - $bounds[1] + 1
            $crop = New-BrandBitmap ($width + 16) ($height + 16)
            $g = [System.Drawing.Graphics]::FromImage($crop)
            try {
                $g.CompositingMode = 'SourceCopy'
                $sourceArea = [System.Drawing.Rectangle]::new($bounds[0], $bounds[1], $width, $height)
                $target = [System.Drawing.Rectangle]::new(8, 8, $width, $height)
                $g.DrawImage($pixels, $target, $sourceArea, 'Pixel')
                return $crop
            } catch {
                $crop.Dispose()
                throw
            } finally { $g.Dispose() }
        } finally { $pixels.Dispose() }
    } finally { $source.Dispose() }
}

function Save-BrandPng {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Path)
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function Write-BrandIcon {
    param([string]$Path, [int[]]$Sizes, [string]$PngDir, [string]$Slug)
    $frames = @{}
    foreach ($size in $Sizes) { $frames[$size] = [IO.File]::ReadAllBytes((Join-Path $PngDir "$Slug-$size.png")) }
    $writer = [IO.BinaryWriter]::new([IO.File]::Open($Path, [IO.FileMode]::CreateNew))
    try {
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$Sizes.Count)
        $offset = 6 + 16 * $Sizes.Count
        foreach ($size in $Sizes) {
            [byte]$dimension = if ($size -eq 256) { 0 } else { $size }
            $writer.Write($dimension)
            $writer.Write($dimension)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]32)
            $writer.Write([uint32]$frames[$size].Length)
            $writer.Write([uint32]$offset)
            $offset += $frames[$size].Length
        }
        foreach ($size in $Sizes) { $writer.Write([byte[]]$frames[$size]) }
    } finally { $writer.Dispose() }
}

function New-BrandText {
    param(
        [string[]]$Lines, [System.Drawing.FontFamily]$Family, [string]$Style,
        [int]$Size, [string]$Color, [single]$Stroke
    )
    $paths = [System.Collections.Generic.List[System.Drawing.Drawing2D.GraphicsPath]]::new()
    $format = [System.Drawing.StringFormat]::GenericTypographic
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($Color))
    $pen = $null
    if ($Stroke -gt 0) {
        $pen = [System.Drawing.Pen]::new($brush, $Stroke)
        $pen.LineJoin = 'Round'
    }
    try {
        $width = 0.0
        $height = 0.0
        $gap = $Size * 0.15
        foreach ($line in $Lines) {
            $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
            $paths.Add($path)
            $fontStyle = [System.Drawing.FontStyle]$Style
            $path.AddString($line, $Family, [int]$fontStyle, $Size, [System.Drawing.PointF]::Empty, $format)
            $bounds = $path.GetBounds()
            if ($bounds.Width -le 0 -or $bounds.Height -le 0) { throw "文字无可见字形：$line" }
            $width = [Math]::Max($width, $bounds.Width)
            $height += $bounds.Height + $gap
        }
        $height -= $gap
        $pad = [Math]::Ceiling(12 + $Stroke / 2)
        if ($width + 2 * $pad -gt 16000) { throw '字图太长，请缩短文本。' }
        $bitmap = New-BrandBitmap ([Math]::Ceiling($width + 2 * $pad)) ([Math]::Ceiling($height + 2 * $pad))
        $g = New-BrandGraphics $bitmap
        try {
            $y = $pad
            foreach ($path in $paths) {
                $bounds = $path.GetBounds()
                $matrix = [System.Drawing.Drawing2D.Matrix]::new()
                try {
                    $matrix.Translate(($pad + ($width - $bounds.Width) / 2 - $bounds.X), ($y - $bounds.Y))
                    $path.Transform($matrix)
                } finally { $matrix.Dispose() }
                $g.FillPath($brush, $path)
                if ($null -ne $pen) { $g.DrawPath($pen, $path) }
                $y += $bounds.Height + $gap
            }
            return $bitmap
        } catch {
            $bitmap.Dispose()
            throw
        } finally { $g.Dispose() }
    } finally {
        if ($null -ne $pen) { $pen.Dispose() }
        $brush.Dispose()
        $format.Dispose()
        foreach ($path in $paths) { $path.Dispose() }
    }
}

function Save-BrandComposition {
    param(
        [string]$Path, [System.Collections.IDictionary]$Layout,
        [System.Drawing.Bitmap]$Mark, [System.Drawing.Bitmap]$NameImage, [System.Drawing.Bitmap]$Subtitle
    )
    $w = $Layout.width
    $h = $Layout.height
    $bitmap = New-BrandBitmap $w $h
    $g = New-BrandGraphics $bitmap
    try {
        if ($Layout.direction -eq 'horizontal') {
            Draw-BrandFit $g $Mark ($w * .04) ($h * .10) ($w * .30) ($h * .80)
            if ($null -eq $Subtitle) {
                Draw-BrandFit $g $NameImage ($w * .37) ($h * .15) ($w * .58) ($h * .70)
            } else {
                Draw-BrandFit $g $NameImage ($w * .37) ($h * .23) ($w * .58) ($h * .35)
                Draw-BrandFit $g $Subtitle ($w * .40) ($h * .59) ($w * .52) ($h * .20)
            }
        } else {
            $nameHeight = if ($Layout.lines -eq 2) { .30 } else { .21 }
            $markHeight = if ($Layout.lines -eq 2) { .46 } else { .52 }
            $nameTop = .05 + $markHeight + .035
            Draw-BrandFit $g $Mark ($w * .15) ($h * .05) ($w * .70) ($h * $markHeight)
            Draw-BrandFit $g $NameImage ($w * .09) ($h * $nameTop) ($w * .82) ($h * $nameHeight)
            if ($null -ne $Subtitle) {
                Draw-BrandFit $g $Subtitle ($w * .12) ($h * ($nameTop + $nameHeight + .016)) ($w * .76) ($h * .10)
            }
        }
        Save-BrandPng $bitmap $Path
    } finally {
        $g.Dispose()
        $bitmap.Dispose()
    }
}

function Save-BrandPreview {
    param([string]$Path, [string]$CompositionDir, [System.Collections.IDictionary]$Config, [System.Drawing.Bitmap]$Master)
    $columns = $Config.layouts.Count * $Config.weights.Count
    $cellW = 490
    $cellH = 360
    $iconStrip = if ($null -eq $Master) { 0 } else { 72 }
    $rowHeight = $cellH + $iconStrip
    $bitmap = New-BrandBitmap ($columns * $cellW) ($rowHeight * 2)
    $g = New-BrandGraphics $bitmap
    $labelFont = [System.Drawing.Font]::new('Segoe UI', 18, 'Bold', 'Pixel')
    try {
        $row = 0
        foreach ($mode in @('light', 'dark')) {
            $surface = $Config.surfaces[$mode]
            $bg = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($surface.background))
            $fg = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($surface.name))
            try {
                $rowTop = $row * $rowHeight
                $g.FillRectangle($bg, 0, $rowTop, $bitmap.Width, $rowHeight)
                $column = 0
                foreach ($layout in $Config.layouts) {
                    foreach ($weight in $Config.weights.Keys) {
                        $label = "$($layout.key) / $weight"
                        $g.DrawString($label, $labelFont, $fg, (($column * $cellW) + 20), ($rowTop + 14))
                        $image = [System.Drawing.Bitmap]::new((Join-Path $CompositionDir "$($layout.key)-$weight-$mode.png"))
                        try {
                            Draw-BrandFit $g $image (($column * $cellW) + 16) ($rowTop + 50) ($cellW - 32) ($cellH - 68)
                        } finally { $image.Dispose() }
                        $column++
                    }
                }
                if ($null -ne $Master) {
                    $x = 24
                    foreach ($px in @(16, 32, 48)) {
                        $y = $rowTop + $cellH + 27
                        $g.DrawImage($Master, $x, ($y - [int]($px / 2)), $px, $px)
                        $g.DrawString("$px px", $labelFont, $fg, ($x + $px + 10), ($y - 11))
                        $x += $px + 76
                    }
                }
            } finally {
                $fg.Dispose()
                $bg.Dispose()
            }
            $row++
        }
        Save-BrandPng $bitmap $Path
    } finally {
        $labelFont.Dispose()
        $g.Dispose()
        $bitmap.Dispose()
    }
}
