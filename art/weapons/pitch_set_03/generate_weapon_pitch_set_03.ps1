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

function New-Bitmap([int]$width, [int]$height) {
    return New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function New-Graphics([System.Drawing.Bitmap]$bitmap) {
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    return $graphics
}

function P($bmp, [int]$x, [int]$y, [System.Drawing.Color]$c) {
    if ($x -ge 0 -and $x -lt $bmp.Width -and $y -ge 0 -and $y -lt $bmp.Height) {
        $bmp.SetPixel($x, $y, $c)
    }
}

function FillPixelsRect($bmp, [int]$x, [int]$y, [int]$w, [int]$h, [System.Drawing.Color]$c) {
    for ($py = $y; $py -lt ($y + $h); $py++) {
        for ($px = $x; $px -lt ($x + $w); $px++) {
            P $bmp $px $py $c
        }
    }
}

function Save-Png([System.Drawing.Bitmap]$bitmap, [string]$path) {
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-ScaledPreview([System.Drawing.Bitmap]$source, [int]$scale) {
    $bg = HexColor "#0d1118"
    $preview = New-Bitmap ($source.Width * $scale + 32) ($source.Height * $scale + 32)
    $g = New-Graphics $preview
    $brush = New-Object System.Drawing.SolidBrush($bg)
    $g.FillRectangle($brush, 0, 0, $preview.Width, $preview.Height)
    $brush.Dispose()
    $g.DrawImage($source, 16, 16, $source.Width * $scale, $source.Height * $scale)
    $g.Dispose()
    return $preview
}

$metal_bright = HexColor "#F5F8FB"
$metal_light = HexColor "#D9E3EA"
$metal_mid = HexColor "#B8C6D1"
$metal_dark = HexColor "#8B98A3"
$gold_bright = HexColor "#D0A851"
$gold_light = HexColor "#B08A3C"
$gold_mid = HexColor "#8F6A2B"
$gold_dark = HexColor "#7A5C24"
$wood_light = HexColor "#8C5A34"
$wood_mid = HexColor "#6B3F23"
$wood_dark = HexColor "#4C2A17"
$wood_deep = HexColor "#2D180D"
$cloth_red = HexColor "#8E3938"
$cloth_red_dark = HexColor "#6F2A2B"
$ember = HexColor "#DD6C39"
$ember_bright = HexColor "#F2BF68"
$iron_dark = HexColor "#6E7884"

function Draw-IronPrisonDagger($bmp) {
    P $bmp 7 2 $metal_light
    P $bmp 8 2 $metal_mid
    P $bmp 6 3 $metal_bright
    P $bmp 7 3 $metal_light
    P $bmp 8 3 $metal_mid
    P $bmp 9 3 $metal_dark
    for ($y = 4; $y -le 18; $y++) {
        P $bmp 6 $y $metal_bright
        P $bmp 7 $y $metal_light
        P $bmp 8 $y $metal_mid
        P $bmp 9 $y $metal_dark
    }
    foreach ($y in 6, 9, 12, 15) {
        P $bmp 7 $y $metal_bright
    }
    P $bmp 6 19 $metal_bright
    P $bmp 7 19 $metal_light
    P $bmp 8 19 $metal_mid
    P $bmp 9 19 $metal_dark
    P $bmp 6 20 $metal_bright
    P $bmp 7 20 $metal_light
    P $bmp 8 20 $metal_mid
    P $bmp 7 21 $metal_light
    P $bmp 8 21 $metal_mid

    FillPixelsRect $bmp 5 22 6 1 $iron_dark
    FillPixelsRect $bmp 4 23 8 1 $metal_dark
    FillPixelsRect $bmp 5 24 6 1 $iron_dark

    for ($y = 25; $y -le 38; $y++) {
        P $bmp 7 $y $wood_light
        P $bmp 8 $y $wood_mid
    }
    foreach ($y in 28, 32, 36) {
        P $bmp 6 $y $gold_light
        P $bmp 7 $y $gold_mid
        P $bmp 8 $y $gold_dark
    }
    P $bmp 7 39 $iron_dark
    P $bmp 8 39 $iron_dark
    P $bmp 6 40 $iron_dark
    P $bmp 9 40 $iron_dark
    P $bmp 6 41 $iron_dark
    P $bmp 9 41 $iron_dark
    P $bmp 7 42 $iron_dark
    P $bmp 8 42 $iron_dark
    P $bmp 7 40 $metal_mid
    P $bmp 8 40 $metal_dark
    P $bmp 7 41 $metal_mid
    P $bmp 8 41 $metal_dark
}

function Draw-WardenSpear($bmp) {
    P $bmp 7 1 $metal_light
    P $bmp 8 1 $metal_mid
    P $bmp 6 2 $metal_bright
    P $bmp 7 2 $metal_light
    P $bmp 8 2 $metal_mid
    P $bmp 9 2 $metal_dark
    P $bmp 6 3 $metal_bright
    P $bmp 7 3 $metal_light
    P $bmp 8 3 $metal_mid
    P $bmp 9 3 $metal_dark
    for ($y = 4; $y -le 11; $y++) {
        P $bmp 5 $y $metal_bright
        P $bmp 6 $y $metal_bright
        P $bmp 7 $y $metal_light
        P $bmp 8 $y $metal_mid
        P $bmp 9 $y $metal_dark
    }
    P $bmp 6 12 $metal_bright
    P $bmp 7 12 $metal_light
    P $bmp 8 12 $metal_mid
    P $bmp 9 12 $metal_dark
    P $bmp 7 13 $metal_light
    P $bmp 8 13 $metal_mid

    for ($y = 14; $y -le 43; $y++) {
        P $bmp 7 $y $wood_light
        P $bmp 8 $y $wood_mid
    }
    foreach ($y in 18, 19, 20, 21, 22, 23, 24, 25) {
        P $bmp 9 $y $cloth_red
    }
    foreach ($y in 20, 21, 22, 23, 24, 25, 26, 27, 28) {
        P $bmp 10 $y $cloth_red_dark
    }
    foreach ($y in 22, 23, 24, 25) {
        P $bmp 11 $y $cloth_red
    }
    P $bmp 7 44 $iron_dark
    P $bmp 8 44 $iron_dark
    P $bmp 6 45 $metal_dark
    P $bmp 7 45 $metal_mid
    P $bmp 8 45 $metal_dark
    P $bmp 9 45 $iron_dark
}

function Draw-ExecutionerGreataxe($bmp) {
    for ($y = 11; $y -le 43; $y++) {
        P $bmp 7 $y $wood_light
        P $bmp 8 $y $wood_mid
    }
    foreach ($y in 26, 32) {
        P $bmp 6 $y $gold_light
        P $bmp 7 $y $gold_mid
        P $bmp 8 $y $gold_dark
        P $bmp 9 $y $cloth_red_dark
    }

    P $bmp 10 8 $metal_dark
    P $bmp 11 7 $metal_mid
    P $bmp 12 6 $metal_light
    P $bmp 13 5 $metal_mid
    P $bmp 14 4 $metal_dark

    P $bmp 3 6 $metal_dark
    P $bmp 4 5 $metal_mid
    P $bmp 5 4 $metal_light
    P $bmp 6 4 $metal_light
    P $bmp 7 4 $metal_mid
    P $bmp 2 7 $metal_dark
    P $bmp 3 7 $metal_mid
    P $bmp 4 6 $metal_bright
    P $bmp 5 5 $metal_bright
    P $bmp 6 5 $metal_light
    P $bmp 7 5 $metal_mid
    P $bmp 1 8 $metal_dark
    P $bmp 2 8 $metal_mid
    P $bmp 3 8 $metal_bright
    P $bmp 4 7 $metal_bright
    P $bmp 5 6 $metal_bright
    P $bmp 6 6 $metal_light
    P $bmp 7 6 $metal_mid
    P $bmp 0 9 $metal_dark
    P $bmp 1 9 $metal_mid
    P $bmp 2 9 $metal_bright
    P $bmp 3 9 $metal_bright
    P $bmp 4 8 $metal_bright
    P $bmp 5 7 $metal_light
    P $bmp 6 7 $metal_mid
    P $bmp 7 7 $metal_dark
    for ($y = 10; $y -le 14; $y++) {
        P $bmp 0 $y $metal_dark
        P $bmp 1 $y $metal_mid
        P $bmp 2 $y $metal_bright
        P $bmp 3 $y $metal_bright
        P $bmp 4 $y $metal_light
        P $bmp 5 $y $metal_mid
        P $bmp 6 $y $metal_dark
    }
    P $bmp 1 15 $metal_dark
    P $bmp 2 15 $metal_mid
    P $bmp 3 15 $metal_bright
    P $bmp 4 15 $metal_light
    P $bmp 5 15 $metal_mid
    P $bmp 6 15 $metal_dark
    P $bmp 2 16 $metal_dark
    P $bmp 3 16 $metal_mid
    P $bmp 4 16 $metal_light
    P $bmp 5 16 $metal_mid
    P $bmp 6 16 $metal_dark
    P $bmp 3 17 $metal_dark
    P $bmp 4 17 $metal_mid
    P $bmp 5 17 $metal_dark

    P $bmp 7 44 $iron_dark
    P $bmp 8 44 $iron_dark
    P $bmp 6 45 $metal_dark
    P $bmp 7 45 $metal_mid
    P $bmp 8 45 $metal_dark
    P $bmp 9 45 $iron_dark
}

function Draw-EmberWarScythe($bmp) {
    for ($y = 13; $y -le 43; $y++) {
        P $bmp 8 $y $wood_light
        P $bmp 9 $y $wood_mid
    }

    P $bmp 8 11 $metal_dark
    P $bmp 7 10 $metal_mid
    P $bmp 6 9 $metal_light
    P $bmp 5 8 $metal_bright
    P $bmp 4 7 $metal_bright
    P $bmp 3 6 $metal_light
    P $bmp 2 5 $metal_mid
    P $bmp 1 4 $metal_dark

    P $bmp 0 4 $metal_dark
    P $bmp 1 3 $metal_mid
    P $bmp 2 2 $metal_light
    P $bmp 3 2 $metal_light
    P $bmp 4 2 $metal_mid
    P $bmp 5 3 $metal_dark

    P $bmp 0 5 $metal_mid
    P $bmp 1 5 $metal_bright
    P $bmp 2 4 $metal_bright
    P $bmp 3 3 $metal_bright
    P $bmp 4 3 $metal_light
    P $bmp 5 4 $metal_mid
    P $bmp 6 5 $metal_dark
    P $bmp 1 6 $metal_bright
    P $bmp 2 6 $metal_bright
    P $bmp 3 5 $metal_light
    P $bmp 4 4 $metal_mid
    P $bmp 5 5 $metal_dark
    P $bmp 2 7 $metal_light
    P $bmp 3 7 $metal_mid
    P $bmp 4 6 $metal_dark
    P $bmp 4 8 $metal_dark
    P $bmp 5 9 $metal_mid
    P $bmp 6 10 $metal_dark

    foreach ($y in 17..24) {
        P $bmp 10 $y $ember
        P $bmp 11 $y $ember_bright
    }
    P $bmp 10 25 $gold_light
    P $bmp 11 25 $gold_mid
    P $bmp 8 44 $gold_light
    P $bmp 9 44 $gold_mid
    P $bmp 8 45 $gold_mid
    P $bmp 9 45 $gold_dark
}

function Draw-PilgrimHandCrossbow($bmp) {
    for ($x = 4; $x -le 11; $x++) {
        P $bmp $x 22 $wood_light
        P $bmp $x 23 $wood_mid
    }
    for ($x = 5; $x -le 10; $x++) {
        P $bmp $x 21 $metal_bright
        P $bmp $x 24 $metal_dark
    }
    P $bmp 12 22 $metal_dark
    P $bmp 12 23 $metal_mid
    P $bmp 13 22 $metal_mid
    P $bmp 14 22 $metal_light
    P $bmp 15 22 $metal_dark
    P $bmp 14 23 $metal_dark

    P $bmp 3 20 $metal_dark
    P $bmp 2 19 $metal_mid
    P $bmp 1 18 $metal_light
    P $bmp 0 17 $metal_dark
    P $bmp 3 21 $metal_mid
    P $bmp 2 21 $metal_bright
    P $bmp 1 21 $metal_light
    P $bmp 0 21 $metal_dark
    P $bmp 3 24 $metal_mid
    P $bmp 2 24 $metal_bright
    P $bmp 1 24 $metal_light
    P $bmp 0 24 $metal_dark
    P $bmp 3 25 $metal_dark
    P $bmp 2 26 $metal_mid
    P $bmp 1 27 $metal_light
    P $bmp 0 28 $metal_dark

    P $bmp 12 20 $metal_dark
    P $bmp 13 19 $metal_mid
    P $bmp 14 18 $metal_light
    P $bmp 15 17 $metal_dark
    P $bmp 12 21 $metal_mid
    P $bmp 13 21 $metal_bright
    P $bmp 14 21 $metal_light
    P $bmp 15 21 $metal_dark
    P $bmp 12 24 $metal_mid
    P $bmp 13 24 $metal_bright
    P $bmp 14 24 $metal_light
    P $bmp 15 24 $metal_dark
    P $bmp 12 25 $metal_dark
    P $bmp 13 26 $metal_mid
    P $bmp 14 27 $metal_light
    P $bmp 15 28 $metal_dark

    for ($y = 21; $y -le 24; $y++) {
        P $bmp 2 $y $metal_bright
        P $bmp 13 $y $metal_bright
    }

    P $bmp 7 25 $wood_light
    P $bmp 8 25 $wood_mid
    for ($y = 26; $y -le 35; $y++) {
        P $bmp 7 $y $wood_light
        P $bmp 8 $y $wood_mid
    }
    P $bmp 6 29 $gold_light
    P $bmp 7 29 $gold_mid
    P $bmp 8 29 $gold_dark
    P $bmp 7 36 $cloth_red
    P $bmp 8 36 $cloth_red_dark
    P $bmp 7 37 $gold_light
    P $bmp 8 37 $gold_mid
}

$outputDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$weapons = @(
    @{ File = "iron_prison_dagger"; Drawer = ${function:Draw-IronPrisonDagger} },
    @{ File = "warden_spear"; Drawer = ${function:Draw-WardenSpear} },
    @{ File = "executioner_greataxe"; Drawer = ${function:Draw-ExecutionerGreataxe} },
    @{ File = "ember_war_scythe"; Drawer = ${function:Draw-EmberWarScythe} },
    @{ File = "pilgrim_hand_crossbow"; Drawer = ${function:Draw-PilgrimHandCrossbow} }
)

$sheet = New-Bitmap 560 320
$sheetGraphics = New-Graphics $sheet
$sheetBrush = New-Object System.Drawing.SolidBrush((HexColor "#0b0f16"))
$sheetGraphics.FillRectangle($sheetBrush, 0, 0, $sheet.Width, $sheet.Height)
$sheetBrush.Dispose()
$positions = @(
    @{ X = 20; Y = 16 },
    @{ X = 128; Y = 16 },
    @{ X = 236; Y = 16 },
    @{ X = 344; Y = 16 },
    @{ X = 452; Y = 16 }
)

for ($i = 0; $i -lt $weapons.Count; $i++) {
    $sprite = New-Bitmap 16 48
    & $weapons[$i].Drawer $sprite
    $spritePath = Join-Path $outputDir ($weapons[$i].File + ".png")
    Save-Png $sprite $spritePath

    $preview = New-ScaledPreview $sprite 8
    $previewPath = Join-Path $outputDir ($weapons[$i].File + "_preview_8x.png")
    Save-Png $preview $previewPath

    $panelBrush = New-Object System.Drawing.SolidBrush((HexColor "#141a24"))
    $sheetGraphics.FillRectangle($panelBrush, $positions[$i].X, $positions[$i].Y, 88, 288)
    $panelBrush.Dispose()
    $sheetGraphics.DrawImage($sprite, ($positions[$i].X + 12), ($positions[$i].Y + 8), 64, 192)

    $preview.Dispose()
    $sprite.Dispose()
}

$sheetGraphics.Dispose()
$sheetPath = Join-Path $outputDir "weapon_pitch_set_03_preview.png"
Save-Png $sheet $sheetPath
$sheet.Dispose()
