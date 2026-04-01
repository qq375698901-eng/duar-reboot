Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function HexColor([string]$hex, [int]$alpha = 255) {
    if ($hex.StartsWith("#")) { $hex = $hex.Substring(1) }
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
    return [System.Drawing.Color]::FromArgb($alpha, $r, $g, $b)
}

function Pt([int]$x, [int]$y) {
    return [System.Drawing.Point]::new($x, $y)
}

function New-Bitmap([int]$w, [int]$h) {
    return New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function New-Graphics([System.Drawing.Bitmap]$bmp) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    return $g
}

function FillRect($g, [System.Drawing.Color]$c, [int]$x, [int]$y, [int]$w, [int]$h) {
    $b = New-Object System.Drawing.SolidBrush($c)
    $g.FillRectangle($b, $x, $y, $w, $h)
    $b.Dispose()
}

function FillPoly($g, [System.Drawing.Color]$c, [System.Drawing.Point[]]$pts) {
    $b = New-Object System.Drawing.SolidBrush($c)
    $g.FillPolygon($b, $pts)
    $b.Dispose()
}

function Save-Png([System.Drawing.Bitmap]$bmp, [string]$path) {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-Preview([System.Drawing.Bitmap]$source, [int]$scale, [int]$padding = 16) {
    $preview = New-Bitmap ($source.Width * $scale + ($padding * 2)) ($source.Height * $scale + ($padding * 2))
    $g = New-Graphics $preview
    FillRect $g (HexColor "#0c1017") 0 0 $preview.Width $preview.Height
    $g.DrawImage($source, $padding, $padding, $source.Width * $scale, $source.Height * $scale)
    $g.Dispose()
    return $preview
}

$steel_hi = HexColor "#F5F8FB"
$steel_light = HexColor "#D9E3EA"
$steel_mid = HexColor "#B8C6D1"
$steel_dark = HexColor "#8B98A3"
$shaft_mid = HexColor "#1F232A"
$shaft_dark = HexColor "#111419"
$shaft_light = HexColor "#343A44"
$brace = HexColor "#5B6068"

$outputDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$spritePath = Join-Path $outputDir "black_diamond_spear.png"
$previewPath = Join-Path $outputDir "black_diamond_spear_preview_12x.png"

$sprite = New-Bitmap 16 96
$g = New-Graphics $sprite
FillRect $g ([System.Drawing.Color]::Transparent) 0 0 16 96

# Diamond spearhead, silver with a clean central highlight.
FillPoly $g $steel_dark @(
    (Pt 8 2),(Pt 11 8),(Pt 11 22),(Pt 8 30),(Pt 5 22),(Pt 5 8)
)
FillPoly $g $steel_mid @(
    (Pt 8 4),(Pt 10 9),(Pt 10 21),(Pt 8 27),(Pt 6 21),(Pt 6 9)
)
FillPoly $g $steel_light @(
    (Pt 8 5),(Pt 9 10),(Pt 9 20),(Pt 8 24),(Pt 7 20),(Pt 7 10)
)
FillRect $g $steel_hi 7 9 1 13

# Socket and transition into the shaft.
FillRect $g $brace 6 30 4 4
FillRect $g $steel_dark 7 29 2 2
FillRect $g $steel_mid 6 32 4 1

# Long black shaft, roughly double the longsword height overall.
FillRect $g $shaft_mid 6 34 4 54
FillRect $g $shaft_dark 8 34 2 54
FillRect $g $shaft_light 6 36 1 48

# Bottom spike cap.
FillRect $g $brace 6 88 4 4
FillPoly $g $steel_dark @((Pt 8 92),(Pt 9 95),(Pt 7 95))
FillRect $g $steel_mid 7 92 2 2

$g.Dispose()
Save-Png $sprite $spritePath

$preview = New-Preview $sprite 12 16
Save-Png $preview $previewPath
$preview.Dispose()
$sprite.Dispose()
