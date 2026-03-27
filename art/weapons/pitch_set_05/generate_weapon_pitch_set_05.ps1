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

function DrawLine($g, [System.Drawing.Color]$c, [int]$x1, [int]$y1, [int]$x2, [int]$y2, [float]$w) {
    $p = New-Object System.Drawing.Pen($c, $w)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($p, $x1, $y1, $x2, $y2)
    $p.Dispose()
}

function FillEllipse($g, [System.Drawing.Color]$c, [int]$x, [int]$y, [int]$w, [int]$h) {
    $b = New-Object System.Drawing.SolidBrush($c)
    $g.FillEllipse($b, $x, $y, $w, $h)
    $b.Dispose()
}

function Save-Png([System.Drawing.Bitmap]$bmp, [string]$path) {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-Preview([System.Drawing.Bitmap]$source, [int]$scale) {
    $preview = New-Bitmap ($source.Width * $scale + 64) ($source.Height * $scale + 64)
    $g = New-Graphics $preview
    FillRect $g (HexColor "#0c1017") 0 0 $preview.Width $preview.Height
    $g.DrawImage($source, 32, 32, $source.Width * $scale, $source.Height * $scale)
    $g.Dispose()
    return $preview
}

$steel_hi = HexColor "#F4F7FB"
$steel_1 = HexColor "#DCE5EC"
$steel_2 = HexColor "#BBC8D2"
$steel_3 = HexColor "#8592A0"
$steel_4 = HexColor "#4A5562"
$iron_dark = HexColor "#303843"
$gold_1 = HexColor "#D4B05B"
$gold_2 = HexColor "#A57C31"
$gold_3 = HexColor "#6C4F1B"
$wood_1 = HexColor "#A36B41"
$wood_2 = HexColor "#7A4A2A"
$wood_3 = HexColor "#55311C"
$leather_1 = HexColor "#A7673F"
$leather_2 = HexColor "#7B4325"
$red_1 = HexColor "#973940"
$red_2 = HexColor "#6D2631"
$ember_1 = HexColor "#FFCC74"
$ember_2 = HexColor "#F08B3F"
$ember_3 = HexColor "#B94E2A"
$bone_1 = HexColor "#F0E8CC"
$bone_2 = HexColor "#D7CCAA"
$bone_3 = HexColor "#AB9D7A"
$obsidian_1 = HexColor "#1E232B"
$obsidian_2 = HexColor "#444D58"
$obsidian_3 = HexColor "#697685"

function Draw-IronPrisonDagger($g) {
    DrawLine $g $steel_2 23 16 23 64 10
    DrawLine $g $steel_1 21 16 21 62 4
    DrawLine $g $steel_hi 19 20 19 56 2
    DrawLine $g $steel_3 27 18 27 58 2
    FillPoly $g $steel_2 @((Pt 18 18),(Pt 23 6),(Pt 28 18),(Pt 23 24))
    FillPoly $g $steel_3 @((Pt 23 6),(Pt 29 15),(Pt 27 18),(Pt 25 13))
    FillPoly $g $steel_4 @((Pt 26 34),(Pt 32 30),(Pt 31 38),(Pt 26 40))
    FillPoly $g $steel_4 @((Pt 18 49),(Pt 15 53),(Pt 19 58),(Pt 21 55))
    FillRect $g $iron_dark 16 42 2 2
    FillRect $g $iron_dark 17 26 2 2
    FillRect $g $iron_dark 28 45 1 3

    FillRect $g $steel_4 10 64 26 3
    FillRect $g $steel_2 13 61 20 3
    FillRect $g $steel_3 15 67 16 2
    FillRect $g $steel_4 18 59 2 3
    FillRect $g $steel_4 26 59 2 3

    DrawLine $g $wood_2 23 69 23 99 8
    DrawLine $g $leather_1 21 71 21 97 2
    DrawLine $g $wood_3 26 71 26 97 2
    foreach ($y in 75, 83, 91) {
        FillRect $g $gold_2 17 $y 12 4
        FillRect $g $gold_3 19 ($y + 1) 8 2
    }

    FillRect $g $steel_3 20 100 6 4
    FillEllipse $g $steel_3 19 104 8 8
    FillEllipse $g $steel_1 20 105 6 6
    DrawLine $g $steel_2 24 111 32 119 3
    DrawLine $g $steel_3 31 119 36 115 2
    FillEllipse $g $steel_3 34 113 5 5
}

function Draw-WardenSpear($g) {
    FillPoly $g $steel_2 @((Pt 24 4),(Pt 29 14),(Pt 31 28),(Pt 28 40),(Pt 24 48),(Pt 20 40),(Pt 17 28),(Pt 19 14))
    FillPoly $g $steel_1 @((Pt 23 10),(Pt 24 6),(Pt 26 10),(Pt 28 23),(Pt 27 34),(Pt 24 42),(Pt 21 34),(Pt 20 23))
    DrawLine $g $steel_hi 22 12 22 34 2
    DrawLine $g $steel_3 27 14 27 34 2
    FillRect $g $steel_4 16 24 2 3
    FillRect $g $steel_4 30 24 2 3

    FillPoly $g $steel_3 @((Pt 22 47),(Pt 20 59),(Pt 22 67),(Pt 24 67),(Pt 26 59),(Pt 25 47))
    DrawLine $g $wood_1 24 47 24 114 8
    DrawLine $g $wood_2 22 49 22 112 2
    DrawLine $g $wood_3 27 49 27 112 2

    FillPoly $g $red_1 @((Pt 29 54),(Pt 42 57),(Pt 40 86),(Pt 31 80))
    FillPoly $g $red_2 @((Pt 31 60),(Pt 37 62),(Pt 37 93),(Pt 31 88))
    FillRect $g $gold_2 20 62 9 4
    FillRect $g $gold_3 22 63 5 2

    FillPoly $g $steel_3 @((Pt 21 114),(Pt 24 121),(Pt 27 114),(Pt 26 126),(Pt 24 128),(Pt 22 126))
    FillPoly $g $steel_1 @((Pt 23 118),(Pt 24 116),(Pt 25 118),(Pt 24 125))
}

function Draw-ExecutionerGreataxe($g) {
    DrawLine $g $wood_2 24 36 24 114 10
    DrawLine $g $wood_1 22 36 22 110 3
    DrawLine $g $wood_3 28 37 28 110 2
    FillRect $g $gold_2 18 74 12 4
    FillRect $g $red_2 18 88 12 4
    FillRect $g $gold_3 20 75 8 2

    FillPoly $g $obsidian_2 @(
        (Pt 22 18),(Pt 15 12),(Pt 7 12),(Pt 2 18),(Pt 0 28),(Pt 0 42),(Pt 4 54),
        (Pt 10 61),(Pt 18 66),(Pt 24 64),(Pt 27 53),(Pt 27 24)
    )
    FillPoly $g $steel_2 @(
        (Pt 20 20),(Pt 15 16),(Pt 9 16),(Pt 5 21),(Pt 4 29),(Pt 4 40),(Pt 7 50),
        (Pt 12 56),(Pt 18 59),(Pt 22 57),(Pt 24 48),(Pt 24 25)
    )
    FillPoly $g $steel_1 @(
        (Pt 12 20),(Pt 8 24),(Pt 7 30),(Pt 7 39),(Pt 10 47),(Pt 14 51),(Pt 18 52),(Pt 20 45),(Pt 20 25),(Pt 16 20)
    )
    DrawLine $g $steel_hi 10 24 10 42 2
    DrawLine $g $steel_3 19 22 19 47 2
    FillRect $g $steel_4 6 40 2 4
    FillRect $g $steel_4 11 52 2 2

    FillPoly $g $steel_3 @((Pt 25 18),(Pt 36 7),(Pt 39 13),(Pt 28 26))
    FillPoly $g $gold_2 @((Pt 21 27),(Pt 24 24),(Pt 24 57),(Pt 21 57))
    FillRect $g $gold_3 21 30 2 21

    FillPoly $g $steel_3 @((Pt 21 114),(Pt 24 120),(Pt 27 114),(Pt 26 126),(Pt 24 128),(Pt 22 126))
}

function Draw-EmberWarScythe($g) {
    DrawLine $g $wood_2 24 26 24 114 8
    DrawLine $g $wood_1 22 27 22 111 2
    DrawLine $g $wood_3 27 27 27 111 2
    FillRect $g $gold_2 20 96 8 4
    FillRect $g $gold_3 22 97 4 2

    FillPoly $g $obsidian_2 @(
        (Pt 25 23),(Pt 20 18),(Pt 14 10),(Pt 9 6),(Pt 4 5),(Pt 1 8),(Pt 0 14),
        (Pt 3 18),(Pt 8 19),(Pt 14 17),(Pt 17 15),(Pt 16 23),(Pt 14 35),(Pt 16 39),(Pt 21 33),(Pt 26 24)
    )
    FillPoly $g $steel_2 @(
        (Pt 23 22),(Pt 19 18),(Pt 14 12),(Pt 10 9),(Pt 6 9),(Pt 4 11),(Pt 4 14),
        (Pt 6 16),(Pt 10 16),(Pt 14 15),(Pt 17 13),(Pt 15 23),(Pt 14 30),(Pt 15 32),(Pt 19 28),(Pt 23 23)
    )
    FillPoly $g $steel_hi @((Pt 9 11),(Pt 7 11),(Pt 7 13),(Pt 10 14),(Pt 15 14),(Pt 18 12),(Pt 15 11))
    DrawLine $g $steel_3 16 24 15 30 2

    FillRect $g $gold_2 25 46 3 4
    FillRect $g $gold_3 25 50 3 4
    FillRect $g $ember_2 28 44 6 28
    FillRect $g $ember_1 29 46 2 22
    FillRect $g $ember_3 32 46 2 24
    FillRect $g $obsidian_1 24 43 2 31
}

function Draw-PilgrimHandCrossbow($g) {
    DrawLine $g $wood_2 24 52 24 110 10
    DrawLine $g $wood_1 22 52 22 107 3
    DrawLine $g $wood_3 28 52 28 107 2
    FillRect $g $gold_2 18 72 12 4
    FillRect $g $red_1 20 96 8 5

    FillRect $g $steel_3 14 32 20 12
    FillRect $g $wood_2 16 34 16 8
    FillRect $g $steel_1 17 34 14 2
    FillRect $g $steel_4 17 40 14 2
    FillPoly $g $steel_2 @((Pt 30 31),(Pt 38 35),(Pt 30 39))

    FillPoly $g $bone_2 @((Pt 14 34),(Pt 9 26),(Pt 5 16),(Pt 6 11),(Pt 10 18),(Pt 15 31))
    FillPoly $g $bone_1 @((Pt 13 34),(Pt 10 27),(Pt 7 18),(Pt 8 15),(Pt 11 21),(Pt 14 30))
    FillPoly $g $bone_2 @((Pt 14 42),(Pt 9 50),(Pt 5 60),(Pt 6 65),(Pt 10 58),(Pt 15 45))
    FillPoly $g $bone_1 @((Pt 13 42),(Pt 10 49),(Pt 7 58),(Pt 8 61),(Pt 11 55),(Pt 14 46))
    FillPoly $g $bone_2 @((Pt 34 34),(Pt 39 26),(Pt 43 16),(Pt 42 11),(Pt 38 18),(Pt 33 31))
    FillPoly $g $bone_1 @((Pt 35 34),(Pt 38 27),(Pt 41 18),(Pt 40 15),(Pt 37 21),(Pt 34 30))
    FillPoly $g $bone_2 @((Pt 34 42),(Pt 39 50),(Pt 43 60),(Pt 42 65),(Pt 38 58),(Pt 33 45))
    FillPoly $g $bone_1 @((Pt 35 42),(Pt 38 49),(Pt 41 58),(Pt 40 61),(Pt 37 55),(Pt 34 46))

    DrawLine $g $bone_1 7 16 7 60 1
    DrawLine $g $bone_1 41 16 41 60 1
    FillRect $g $steel_1 18 30 12 3
    FillRect $g $steel_4 29 30 3 3

    FillPoly $g $gold_2 @((Pt 21 44),(Pt 24 41),(Pt 27 44),(Pt 27 52),(Pt 21 52))
    FillRect $g $gold_3 23 45 2 6
}

$outputDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$weapons = @(
    @{ File = "iron_prison_dagger"; Drawer = ${function:Draw-IronPrisonDagger} },
    @{ File = "warden_spear"; Drawer = ${function:Draw-WardenSpear} },
    @{ File = "executioner_greataxe"; Drawer = ${function:Draw-ExecutionerGreataxe} },
    @{ File = "ember_war_scythe"; Drawer = ${function:Draw-EmberWarScythe} },
    @{ File = "pilgrim_hand_crossbow"; Drawer = ${function:Draw-PilgrimHandCrossbow} }
)

$sheet = New-Bitmap 960 540
$sheetGraphics = New-Graphics $sheet
FillRect $sheetGraphics (HexColor "#0b0f16") 0 0 $sheet.Width $sheet.Height
$positions = @(
    @{ X = 24; Y = 16 },
    @{ X = 210; Y = 16 },
    @{ X = 396; Y = 16 },
    @{ X = 582; Y = 16 },
    @{ X = 768; Y = 16 }
)

for ($i = 0; $i -lt $weapons.Count; $i++) {
    $sprite = New-Bitmap 48 128
    $graphics = New-Graphics $sprite
    FillRect $graphics ([System.Drawing.Color]::Transparent) 0 0 48 128
    & $weapons[$i].Drawer $graphics
    $graphics.Dispose()

    $spritePath = Join-Path $outputDir ($weapons[$i].File + ".png")
    Save-Png $sprite $spritePath

    $preview = New-Preview $sprite 4
    $previewPath = Join-Path $outputDir ($weapons[$i].File + "_preview_4x.png")
    Save-Png $preview $previewPath

    FillRect $sheetGraphics (HexColor "#141a24") $positions[$i].X $positions[$i].Y 168 508
    $sheetGraphics.DrawImage($sprite, ($positions[$i].X + 12), ($positions[$i].Y + 8), 144, 384)

    $preview.Dispose()
    $sprite.Dispose()
}

$sheetGraphics.Dispose()
$sheetPath = Join-Path $outputDir "weapon_pitch_set_05_preview.png"
Save-Png $sheet $sheetPath
$sheet.Dispose()
