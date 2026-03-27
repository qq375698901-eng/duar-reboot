Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function HexColor([string]$hex, [int]$alpha = 255) {
    if ($hex.StartsWith("#")) { $hex = $hex.Substring(1) }
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
    [System.Drawing.Color]::FromArgb($alpha, $r, $g, $b)
}

function New-Bitmap([int]$width, [int]$height) {
    New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function New-Graphics([System.Drawing.Bitmap]$bitmap) {
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics
}

function FillRect($graphics, [System.Drawing.Color]$color, [int]$x, [int]$y, [int]$w, [int]$h) {
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.FillRectangle($brush, $x, $y, $w, $h)
    $brush.Dispose()
}

function FillPolygon($graphics, [System.Drawing.Color]$color, [System.Drawing.Point[]]$points) {
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.FillPolygon($brush, $points)
    $brush.Dispose()
}

function DrawLine($graphics, [System.Drawing.Color]$color, [int]$x1, [int]$y1, [int]$x2, [int]$y2, [float]$width) {
    $pen = New-Object System.Drawing.Pen($color, $width)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($pen, $x1, $y1, $x2, $y2)
    $pen.Dispose()
}

function Point([int]$x, [int]$y) {
    [System.Drawing.Point]::new($x, $y)
}

function Save-Png([System.Drawing.Bitmap]$bitmap, [string]$path) {
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-Preview([System.Drawing.Bitmap]$source, [int]$scale) {
    $preview = New-Bitmap ($source.Width * $scale + 48) ($source.Height * $scale + 48)
    $graphics = New-Graphics $preview
    FillRect $graphics (HexColor "#0d1118") 0 0 $preview.Width $preview.Height
    $graphics.DrawImage($source, 24, 24, $source.Width * $scale, $source.Height * $scale)
    $graphics.Dispose()
    $preview
}

$metal_1 = HexColor "#F8FBFD"
$metal_2 = HexColor "#E5EEF3"
$metal_3 = HexColor "#C9D7E0"
$metal_4 = HexColor "#9BAAB8"
$metal_5 = HexColor "#6F7C89"
$iron_blue = HexColor "#7E8A98"
$black_steel = HexColor "#434C57"
$gold_1 = HexColor "#D7B562"
$gold_2 = HexColor "#B88D39"
$gold_3 = HexColor "#876221"
$wood_1 = HexColor "#A56C3F"
$wood_2 = HexColor "#81502C"
$wood_3 = HexColor "#5C351E"
$leather_1 = HexColor "#9D6136"
$leather_2 = HexColor "#784324"
$cloth_red = HexColor "#8C3437"
$cloth_red_dark = HexColor "#67242B"
$ember_1 = HexColor "#FFCB73"
$ember_2 = HexColor "#F08A3E"
$ember_3 = HexColor "#B9502B"
$bone_1 = HexColor "#F0E6CB"
$bone_2 = HexColor "#CEC19D"
$ash_wood = HexColor "#9A7A58"

function Draw-IronPrisonDagger($graphics) {
    DrawLine $graphics $metal_3 11 8 11 30 5
    DrawLine $graphics $metal_2 10 8 10 29 2
    DrawLine $graphics $metal_1 9 10 9 27 1
    DrawLine $graphics $metal_5 13 10 13 27 1
    FillPolygon $graphics $metal_2 @((Point 9 5), (Point 11 1), (Point 13 5), (Point 11 8))
    FillPolygon $graphics $metal_4 @((Point 11 1), (Point 14 4), (Point 13 5), (Point 12 4))
    FillRect $graphics $metal_5 8 15 1 2
    FillRect $graphics $metal_5 8 22 1 2
    FillRect $graphics $metal_5 13 11 1 1
    FillRect $graphics $metal_5 12 6 1 1

    FillRect $graphics $iron_blue 5 30 12 2
    FillRect $graphics $metal_4 6 29 10 1
    FillRect $graphics $metal_5 7 32 8 1

    DrawLine $graphics $wood_2 11 33 11 51 4
    DrawLine $graphics $leather_1 10 34 10 50 1
    DrawLine $graphics $wood_3 12 34 12 50 1
    FillRect $graphics $gold_2 8 36 6 2
    FillRect $graphics $gold_2 8 42 6 2
    FillRect $graphics $gold_2 8 48 6 2
    FillRect $graphics $gold_3 9 37 4 1
    FillRect $graphics $gold_3 9 43 4 1
    FillRect $graphics $gold_3 9 49 4 1

    FillRect $graphics $iron_blue 9 52 4 2
    FillRect $graphics $metal_5 10 54 2 1
    DrawLine $graphics $metal_4 11 55 15 59 2
    DrawLine $graphics $metal_5 15 59 18 57 1
    FillRect $graphics $metal_4 17 56 2 2
}

function Draw-WardenSpear($graphics) {
    FillPolygon $graphics $metal_3 @(
        (Point 11 1), (Point 14 6), (Point 15 15), (Point 13 22),
        (Point 11 26), (Point 9 22), (Point 7 15), (Point 8 6)
    )
    FillPolygon $graphics $metal_2 @(
        (Point 10 4), (Point 11 2), (Point 12 4), (Point 13 11),
        (Point 12 19), (Point 11 23), (Point 10 19), (Point 9 11)
    )
    DrawLine $graphics $metal_1 10 5 10 19 1
    DrawLine $graphics $metal_5 13 7 13 18 1
    FillRect $graphics $metal_5 6 13 1 2
    FillRect $graphics $metal_5 15 13 1 2

    DrawLine $graphics $wood_1 11 26 11 58 4
    DrawLine $graphics $wood_2 10 27 10 57 1
    DrawLine $graphics $wood_3 12 27 12 57 1

    FillPolygon $graphics $cloth_red @((Point 13 28), (Point 19 29), (Point 18 42), (Point 14 39))
    FillPolygon $graphics $cloth_red_dark @((Point 14 31), (Point 17 32), (Point 17 46), (Point 14 44))
    FillRect $graphics $gold_2 9 34 5 2
    FillRect $graphics $gold_3 10 35 3 1

    FillPolygon $graphics $metal_4 @((Point 10 58), (Point 12 58), (Point 14 62), (Point 11 63), (Point 8 62))
    FillPolygon $graphics $metal_2 @((Point 10 59), (Point 12 59), (Point 11 62))
}

function Draw-ExecutionerGreataxe($graphics) {
    DrawLine $graphics $wood_2 12 18 12 58 5
    DrawLine $graphics $wood_1 11 18 11 57 2
    DrawLine $graphics $wood_3 14 19 14 57 1
    FillRect $graphics $gold_2 9 36 6 2
    FillRect $graphics $cloth_red_dark 9 44 6 2

    FillPolygon $graphics $black_steel @(
        (Point 11 8), (Point 7 6), (Point 3 8), (Point 1 13), (Point 1 20),
        (Point 4 25), (Point 8 28), (Point 11 27), (Point 13 22), (Point 13 11)
    )
    FillPolygon $graphics $metal_3 @(
        (Point 10 9), (Point 7 8), (Point 4 10), (Point 3 14), (Point 3 19),
        (Point 5 23), (Point 8 25), (Point 10 24), (Point 11 20), (Point 11 12)
    )
    FillPolygon $graphics $metal_1 @(
        (Point 6 10), (Point 4 13), (Point 4 18), (Point 6 21), (Point 8 22), (Point 9 19), (Point 9 13)
    )
    FillRect $graphics $metal_5 4 18 1 2
    FillRect $graphics $metal_5 5 22 1 1
    FillRect $graphics $metal_5 8 9 1 1

    FillPolygon $graphics $metal_4 @((Point 12 8), (Point 17 3), (Point 18 6), (Point 14 11))
    FillPolygon $graphics $gold_2 @((Point 10 12), (Point 12 11), (Point 12 22), (Point 10 22))
    FillRect $graphics $gold_3 10 13 1 8
}

function Draw-EmberWarScythe($graphics) {
    DrawLine $graphics $wood_2 13 14 13 58 4
    DrawLine $graphics $wood_1 12 15 12 57 1
    DrawLine $graphics $wood_3 14 15 14 57 1
    FillRect $graphics $gold_2 11 50 4 2
    FillRect $graphics $gold_3 12 51 2 1

    FillPolygon $graphics $black_steel @(
        (Point 14 12), (Point 10 8), (Point 6 4), (Point 3 3), (Point 1 5),
        (Point 1 8), (Point 4 10), (Point 7 9), (Point 10 7), (Point 8 12),
        (Point 7 18), (Point 9 20), (Point 12 16), (Point 15 13)
    )
    FillPolygon $graphics $metal_3 @(
        (Point 13 11), (Point 10 8), (Point 7 5), (Point 4 4), (Point 3 6),
        (Point 3 8), (Point 5 9), (Point 8 8), (Point 10 7), (Point 9 12),
        (Point 8 16), (Point 9 17), (Point 11 14), (Point 13 12)
    )
    FillPolygon $graphics $metal_1 @((Point 6 6), (Point 4 6), (Point 4 7), (Point 6 8), (Point 9 8), (Point 10 7), (Point 8 6))
    FillRect $graphics $metal_5 7 15 1 2

    FillRect $graphics $ember_2 16 24 3 15
    FillRect $graphics $ember_1 17 25 1 12
    FillRect $graphics $ember_3 18 25 1 13
    FillPolygon $graphics $gold_2 @((Point 14 23), (Point 16 22), (Point 16 40), (Point 14 40))
}

function Draw-PilgrimHandCrossbow($graphics) {
    DrawLine $graphics $ash_wood 12 29 12 52 5
    DrawLine $graphics $wood_2 11 29 11 51 1
    DrawLine $graphics $wood_3 14 29 14 51 1
    FillRect $graphics $gold_2 10 34 5 2
    FillRect $graphics $cloth_red 11 47 3 3

    FillRect $graphics $ash_wood 6 21 12 6
    FillRect $graphics $wood_2 7 22 10 4
    FillRect $graphics $metal_1 8 22 8 1
    FillRect $graphics $metal_5 8 25 8 1

    FillPolygon $graphics $bone_2 @((Point 6 22), (Point 3 18), (Point 1 13), (Point 2 11), (Point 5 15), (Point 7 21))
    FillPolygon $graphics $bone_1 @((Point 5 22), (Point 3 18), (Point 2 14), (Point 3 13), (Point 5 16), (Point 6 21))
    FillPolygon $graphics $bone_2 @((Point 6 26), (Point 3 30), (Point 1 35), (Point 2 37), (Point 5 33), (Point 7 27))
    FillPolygon $graphics $bone_1 @((Point 5 26), (Point 3 30), (Point 2 34), (Point 3 35), (Point 5 32), (Point 6 27))
    FillPolygon $graphics $bone_2 @((Point 18 22), (Point 21 18), (Point 23 13), (Point 22 11), (Point 19 15), (Point 17 21))
    FillPolygon $graphics $bone_1 @((Point 19 22), (Point 21 18), (Point 22 14), (Point 21 13), (Point 19 16), (Point 18 21))
    FillPolygon $graphics $bone_2 @((Point 18 26), (Point 21 30), (Point 23 35), (Point 22 37), (Point 19 33), (Point 17 27))
    FillPolygon $graphics $bone_1 @((Point 19 26), (Point 21 30), (Point 22 34), (Point 21 35), (Point 19 32), (Point 18 27))

    DrawLine $graphics $bone_1 2 13 2 35 1
    DrawLine $graphics $bone_1 22 13 22 35 1

    FillRect $graphics $metal_2 9 19 7 2
    FillRect $graphics $metal_5 15 19 2 2
    FillPolygon $graphics $metal_4 @((Point 16 18), (Point 21 20), (Point 16 22))

    FillRect $graphics $gold_2 10 28 4 1
}

$outputDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$weapons = @(
    @{ File = "iron_prison_dagger"; Drawer = ${function:Draw-IronPrisonDagger} },
    @{ File = "warden_spear"; Drawer = ${function:Draw-WardenSpear} },
    @{ File = "executioner_greataxe"; Drawer = ${function:Draw-ExecutionerGreataxe} },
    @{ File = "ember_war_scythe"; Drawer = ${function:Draw-EmberWarScythe} },
    @{ File = "pilgrim_hand_crossbow"; Drawer = ${function:Draw-PilgrimHandCrossbow} }
)

$sheet = New-Bitmap 760 380
$sheetGraphics = New-Graphics $sheet
FillRect $sheetGraphics (HexColor "#0b0f16") 0 0 $sheet.Width $sheet.Height
$positions = @(
    @{ X = 20; Y = 16 },
    @{ X = 166; Y = 16 },
    @{ X = 312; Y = 16 },
    @{ X = 458; Y = 16 },
    @{ X = 604; Y = 16 }
)

for ($i = 0; $i -lt $weapons.Count; $i++) {
    $sprite = New-Bitmap 24 64
    $graphics = New-Graphics $sprite
    FillRect $graphics ([System.Drawing.Color]::Transparent) 0 0 24 64
    & $weapons[$i].Drawer $graphics
    $graphics.Dispose()

    $spritePath = Join-Path $outputDir ($weapons[$i].File + ".png")
    Save-Png $sprite $spritePath

    $preview = New-Preview $sprite 8
    $previewPath = Join-Path $outputDir ($weapons[$i].File + "_preview_8x.png")
    Save-Png $preview $previewPath

    FillRect $sheetGraphics (HexColor "#141a24") $positions[$i].X $positions[$i].Y 126 344
    $sheetGraphics.DrawImage($sprite, ($positions[$i].X + 15), ($positions[$i].Y + 8), 96, 256)

    $preview.Dispose()
    $sprite.Dispose()
}

$sheetGraphics.Dispose()
$sheetPath = Join-Path $outputDir "weapon_pitch_set_04_preview.png"
Save-Png $sheet $sheetPath
$sheet.Dispose()
