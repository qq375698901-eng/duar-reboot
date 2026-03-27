Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function HexColor([string]$hex, [int]$alpha = 255) {
    if ($hex.StartsWith("#")) {
        $hex = $hex.Substring(1)
    }
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

function FillRect($graphics, [System.Drawing.Color]$color, [int]$x, [int]$y, [int]$w, [int]$h) {
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.FillRectangle($brush, $x, $y, $w, $h)
    $brush.Dispose()
}

function FillEllipse($graphics, [System.Drawing.Color]$color, [int]$x, [int]$y, [int]$w, [int]$h) {
    $brush = New-Object System.Drawing.SolidBrush($color)
    $graphics.FillEllipse($brush, $x, $y, $w, $h)
    $brush.Dispose()
}

function Point([int]$x, [int]$y) {
    return [System.Drawing.Point]::new($x, $y)
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

function DrawOutlineLine(
    $graphics,
    [System.Drawing.Color]$fillColor,
    [System.Drawing.Color]$outlineColor,
    [int]$x1,
    [int]$y1,
    [int]$x2,
    [int]$y2,
    [float]$width
) {
    DrawLine $graphics $outlineColor $x1 $y1 $x2 $y2 ($width + 2.0)
    DrawLine $graphics $fillColor $x1 $y1 $x2 $y2 $width
}

function DrawOutlinePolygon(
    $graphics,
    [System.Drawing.Color]$fillColor,
    [System.Drawing.Color]$outlineColor,
    [System.Drawing.Point[]]$points,
    [float]$insetScale = 0.82
) {
    FillPolygon $graphics $outlineColor $points
    $centerX = 0.0
    $centerY = 0.0
    foreach ($point in $points) {
        $centerX += $point.X
        $centerY += $point.Y
    }
    $centerX /= $points.Length
    $centerY /= $points.Length
    $inner = New-Object 'System.Drawing.Point[]' $points.Length
    for ($i = 0; $i -lt $points.Length; $i++) {
        $inner[$i] = [System.Drawing.Point]::new(
            [int][Math]::Round(($points[$i].X * $insetScale) + ($centerX * (1.0 - $insetScale))),
            [int][Math]::Round(($points[$i].Y * $insetScale) + ($centerY * (1.0 - $insetScale)))
        )
    }
    FillPolygon $graphics $fillColor $inner
}

function Save-Png([System.Drawing.Bitmap]$bitmap, [string]$path) {
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-ScaledPreview([System.Drawing.Bitmap]$source, [int]$scale, [System.Drawing.Color]$bgColor) {
    $preview = New-Bitmap ($source.Width * $scale + 32) ($source.Height * $scale + 32)
    $graphics = New-Graphics $preview
    FillRect $graphics $bgColor 0 0 $preview.Width $preview.Height
    $graphics.DrawImage($source, 16, 16, $source.Width * $scale, $source.Height * $scale)
    $graphics.Dispose()
    return $preview
}

function Draw-IronPrisonDagger($graphics) {
    $outline = HexColor "#1c2027"
    $steelBright = HexColor "#f4f7fb"
    $steelMid = HexColor "#d9e3ea"
    $steelDark = HexColor "#8b98a3"
    $leather = HexColor "#7a5c24"
    $wood = HexColor "#6b3f23"
    $woodDark = HexColor "#4c2a17"
    $gold = HexColor "#d0a851"

    $blade = @(
        (Point 8 4), (Point 10 7), (Point 10 19), (Point 9 23),
        (Point 7 23), (Point 6 19), (Point 6 7)
    )
    DrawOutlinePolygon $graphics $steelMid $outline $blade 0.84
    FillRect $graphics $steelBright 8 6 1 12
    FillRect $graphics $steelDark 7 10 1 10

    FillRect $graphics $outline 4 22 8 3
    FillRect $graphics $gold 5 23 6 1
    FillRect $graphics $outline 7 25 3 12
    FillRect $graphics $wood 8 26 1 10
    FillRect $graphics $leather 7 29 3 2
    FillRect $graphics $leather 7 33 3 2
    FillRect $graphics $outline 6 37 5 4
    FillRect $graphics $woodDark 7 38 3 2
}

function Draw-WardenSpear($graphics) {
    $outline = HexColor "#1b2026"
    $steelBright = HexColor "#f5f8fb"
    $steelMid = HexColor "#d9e3ea"
    $steelDark = HexColor "#8b98a3"
    $shaft = HexColor "#8c5a34"
    $shaftDark = HexColor "#4c2a17"
    $cloth = HexColor "#8d3a35"

    $head = @(
        (Point 8 1), (Point 10 4), (Point 11 9), (Point 10 14),
        (Point 8 18), (Point 6 14), (Point 5 9), (Point 6 4)
    )
    DrawOutlinePolygon $graphics $steelMid $outline $head 0.84
    FillRect $graphics $steelBright 8 3 1 11
    FillRect $graphics $steelDark 7 6 1 10
    FillRect $graphics $steelDark 5 9 1 2
    FillRect $graphics $steelDark 10 9 1 2

    FillRect $graphics $outline 7 17 3 26
    FillRect $graphics $shaft 8 18 1 24
    FillRect $graphics $shaftDark 7 20 1 20

    FillRect $graphics $cloth 9 18 2 5
    FillRect $graphics $cloth 9 24 2 7
    FillRect $graphics $cloth 10 31 1 5

    FillRect $graphics $outline 6 41 5 4
    FillRect $graphics $steelDark 7 42 3 2
}

function Draw-ExecutionerGreataxe($graphics) {
    $outline = HexColor "#1a1e25"
    $metalBright = HexColor "#f1f4f8"
    $metalMid = HexColor "#cfd9e3"
    $metalDark = HexColor "#7f8a98"
    $shaft = HexColor "#8c5a34"
    $shaftDark = HexColor "#4c2a17"
    $band = HexColor "#8d3a35"
    $gold = HexColor "#b08a3c"

    FillRect $graphics $outline 7 8 3 35
    FillRect $graphics $shaft 8 9 1 33
    FillRect $graphics $shaftDark 7 12 1 28

    $axeHead = @(
        (Point 8 8), (Point 4 9), (Point 1 12), (Point 0 16), (Point 1 20),
        (Point 4 23), (Point 8 24), (Point 10 21), (Point 10 11)
    )
    DrawOutlinePolygon $graphics $metalMid $outline $axeHead 0.82
    FillRect $graphics $metalBright 5 10 2 10
    FillRect $graphics $metalDark 2 14 2 6
    FillRect $graphics $metalDark 7 20 1 3

    $backSpike = @((Point 9 8), (Point 12 4), (Point 13 7), (Point 10 10))
    DrawOutlinePolygon $graphics $metalDark $outline $backSpike 0.78

    FillRect $graphics $outline 6 27 5 3
    FillRect $graphics $band 7 28 3 1
    FillRect $graphics $outline 6 34 5 3
    FillRect $graphics $gold 7 35 3 1
    FillRect $graphics $outline 6 42 5 3
    FillRect $graphics $metalDark 7 43 3 1
}

function Draw-EmberWarScythe($graphics) {
    $outline = HexColor "#1a1f26"
    $metalBright = HexColor "#f3f6fa"
    $metalMid = HexColor "#d7dfe8"
    $metalDark = HexColor "#7b8795"
    $shaft = HexColor "#8c5a34"
    $shaftDark = HexColor "#4c2a17"
    $ember = HexColor "#dd6c39"
    $emberBright = HexColor "#f2bf68"

    FillRect $graphics $outline 8 7 3 36
    FillRect $graphics $shaft 9 8 1 34
    FillRect $graphics $shaftDark 8 11 1 28

    $blade = @(
        (Point 10 6), (Point 8 3), (Point 5 1), (Point 2 1), (Point 0 3),
        (Point 0 6), (Point 2 8), (Point 4 8), (Point 7 6), (Point 5 10),
        (Point 4 12), (Point 5 14), (Point 8 12), (Point 11 8)
    )
    DrawOutlinePolygon $graphics $metalMid $outline $blade 0.82
    FillRect $graphics $metalBright 4 3 2 3
    FillRect $graphics $metalDark 1 4 2 3
    FillRect $graphics $metalDark 6 8 1 3

    FillRect $graphics $ember 10 14 2 8
    FillRect $graphics $emberBright 10 15 1 5
    FillRect $graphics $outline 7 39 5 3
    FillRect $graphics $ember 8 40 3 1
}

function Draw-PilgrimHandCrossbow($graphics) {
    $outline = HexColor "#1a1f26"
    $wood = HexColor "#8c5a34"
    $woodDark = HexColor "#4c2a17"
    $metalBright = HexColor "#f1f5fa"
    $metalMid = HexColor "#d9e3ea"
    $metalDark = HexColor "#8b98a3"
    $cord = HexColor "#d9cba3"
    $accent = HexColor "#8d3a35"

    FillRect $graphics $outline 3 18 10 5
    FillRect $graphics $wood 4 19 8 3
    FillRect $graphics $woodDark 4 22 3 1

    $limbLeftTop = @((Point 3 18), (Point 1 15), (Point 1 13), (Point 3 14), (Point 5 18))
    $limbLeftBottom = @((Point 3 23), (Point 1 26), (Point 1 28), (Point 3 27), (Point 5 23))
    $limbRightTop = @((Point 12 18), (Point 14 15), (Point 14 13), (Point 12 14), (Point 10 18))
    $limbRightBottom = @((Point 12 23), (Point 14 26), (Point 14 28), (Point 12 27), (Point 10 23))

    DrawOutlinePolygon $graphics $metalMid $outline $limbLeftTop 0.82
    DrawOutlinePolygon $graphics $metalMid $outline $limbLeftBottom 0.82
    DrawOutlinePolygon $graphics $metalMid $outline $limbRightTop 0.82
    DrawOutlinePolygon $graphics $metalMid $outline $limbRightBottom 0.82

    DrawLine $graphics $cord 2 14 2 27 1
    DrawLine $graphics $cord 13 14 13 27 1

    FillRect $graphics $outline 7 14 3 5
    FillRect $graphics $metalDark 8 15 1 3
    FillRect $graphics $outline 7 23 3 12
    FillRect $graphics $wood 8 24 1 10
    FillRect $graphics $accent 7 29 3 2

    FillRect $graphics $outline 4 20 8 2
    FillRect $graphics $metalBright 5 20 6 1
    FillRect $graphics $metalDark 10 20 2 1

    $boltTip = @((Point 12 19), (Point 15 21), (Point 12 23))
    DrawOutlinePolygon $graphics $metalDark $outline $boltTip 0.74
}

$outputDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bg = HexColor "#0d1118"

$weapons = @(
    @{ File = "iron_prison_dagger"; Drawer = ${function:Draw-IronPrisonDagger} },
    @{ File = "warden_spear"; Drawer = ${function:Draw-WardenSpear} },
    @{ File = "executioner_greataxe"; Drawer = ${function:Draw-ExecutionerGreataxe} },
    @{ File = "ember_war_scythe"; Drawer = ${function:Draw-EmberWarScythe} },
    @{ File = "pilgrim_hand_crossbow"; Drawer = ${function:Draw-PilgrimHandCrossbow} }
)

$sheet = New-Bitmap 560 320
$sheetGraphics = New-Graphics $sheet
FillRect $sheetGraphics (HexColor "#0b0f16") 0 0 560 320

$sheetPositions = @(
    @{ X = 20; Y = 16 },
    @{ X = 128; Y = 16 },
    @{ X = 236; Y = 16 },
    @{ X = 344; Y = 16 },
    @{ X = 452; Y = 16 }
)

for ($i = 0; $i -lt $weapons.Count; $i++) {
    $sprite = New-Bitmap 16 48
    $graphics = New-Graphics $sprite
    $graphics.Clear([System.Drawing.Color]::Transparent)
    & $weapons[$i].Drawer $graphics
    $graphics.Dispose()

    $spritePath = Join-Path $outputDir ($weapons[$i].File + ".png")
    Save-Png $sprite $spritePath

    $preview = New-ScaledPreview $sprite 6 $bg
    $previewPath = Join-Path $outputDir ($weapons[$i].File + "_preview_6x.png")
    Save-Png $preview $previewPath

    FillRect $sheetGraphics (HexColor "#141a24") $sheetPositions[$i].X $sheetPositions[$i].Y 88 288
    $sheetGraphics.DrawImage($sprite, ($sheetPositions[$i].X + 16), ($sheetPositions[$i].Y + 8), 56, 168)

    $preview.Dispose()
    $sprite.Dispose()
}

$sheetGraphics.Dispose()
$sheetPath = Join-Path $outputDir "weapon_pitch_set_02_preview.png"
Save-Png $sheet $sheetPath
$sheet.Dispose()
