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
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
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

function DrawOutlinedLine(
    $graphics,
    [System.Drawing.Color]$fillColor,
    [System.Drawing.Color]$outlineColor,
    [int]$x1,
    [int]$y1,
    [int]$x2,
    [int]$y2,
    [float]$width
) {
    $outlinePen = New-Object System.Drawing.Pen($outlineColor, ($width + 2.0))
    $fillPen = New-Object System.Drawing.Pen($fillColor, $width)
    $outlinePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $outlinePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $fillPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $fillPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($outlinePen, $x1, $y1, $x2, $y2)
    $graphics.DrawLine($fillPen, $x1, $y1, $x2, $y2)
    $outlinePen.Dispose()
    $fillPen.Dispose()
}

function DrawOutlinedPolygon(
    $graphics,
    [System.Drawing.Color]$fillColor,
    [System.Drawing.Color]$outlineColor,
    [System.Drawing.Point[]]$points
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
        $x = $points[$i].X
        $y = $points[$i].Y
        $inner[$i] = [System.Drawing.Point]::new(
            [int][Math]::Round(($x * 0.84) + ($centerX * 0.16)),
            [int][Math]::Round(($y * 0.84) + ($centerY * 0.16))
        )
    }
    FillPolygon $graphics $fillColor $inner
}

function Save-Png([System.Drawing.Bitmap]$bitmap, [string]$path) {
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-PreviewCard([System.Drawing.Bitmap]$source, [string]$label) {
    $card = New-Bitmap 176 220
    $graphics = New-Graphics $card

    FillRect $graphics (HexColor "#12161f") 0 0 176 220
    FillRect $graphics (HexColor "#1a2130") 10 10 156 170
    FillRect $graphics (HexColor "#0d1017") 14 14 148 162
    FillRect $graphics (HexColor "#273348") 14 14 148 12

    $scaled = New-Bitmap ($source.Width * 4) ($source.Height * 4)
    $scaleGraphics = New-Graphics $scaled
    $scaleGraphics.Clear([System.Drawing.Color]::Transparent)
    $scaleGraphics.DrawImage($source, 0, 0, $scaled.Width, $scaled.Height)
    $scaleGraphics.Dispose()

    $offsetX = [int](($card.Width - $scaled.Width) / 2)
    $offsetY = 28
    $graphics.DrawImage($scaled, $offsetX, $offsetY, $scaled.Width, $scaled.Height)

    $font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush((HexColor "#d8dfef"))
    $stringRect = New-Object System.Drawing.RectangleF(12, 184, 152, 24)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $graphics.DrawString($label, $font, $brush, $stringRect, $format)

    $font.Dispose()
    $brush.Dispose()
    $format.Dispose()
    $scaled.Dispose()
    $graphics.Dispose()

    return $card
}

function Draw-IronPrisonDagger($graphics) {
    $outline = HexColor "#17181e"
    $steel = HexColor "#d9dee8"
    $steelDark = HexColor "#8c94a8"
    $wrap = HexColor "#744042"
    $gold = HexColor "#bf9655"
    $gem = HexColor "#d46d63"

    FillEllipse $graphics $outline 11 38 8 8
    FillEllipse $graphics $gem 13 40 4 4
    FillRect $graphics $outline 12 31 6 10
    FillRect $graphics $wrap 13 32 4 8
    FillRect $graphics $outline 9 28 12 4
    FillRect $graphics $gold 10 29 10 2

    $blade = @(
        (Point 12 28), (Point 21 10), (Point 24 7), (Point 26 10),
        (Point 18 28), (Point 16 32), (Point 14 31)
    )
    DrawOutlinedPolygon $graphics $steel $outline $blade

    $fuller = @((Point 16 26), (Point 22 14), (Point 23 15), (Point 17 27))
    FillPolygon $graphics $steelDark $fuller
    FillRect $graphics (HexColor "#f2f5fa") 21 11 1 9
    FillRect $graphics (HexColor "#f2f5fa") 18 16 1 7
}

function Draw-WardenSpear($graphics) {
    $outline = HexColor "#181a20"
    $shaft = HexColor "#74583b"
    $shaftLight = HexColor "#9a7750"
    $steel = HexColor "#d7e0ec"
    $steelDark = HexColor "#8491a7"
    $cloth = HexColor "#8f3130"

    DrawOutlinedLine $graphics $shaft $outline 7 42 22 10 4
    DrawOutlinedLine $graphics $shaftLight $shaftLight 8 41 21 12 1

    $head = @(
        (Point 18 11), (Point 23 4), (Point 28 11), (Point 24 15), (Point 22 14)
    )
    DrawOutlinedPolygon $graphics $steel $outline $head

    $headShade = @((Point 22 7), (Point 26 11), (Point 23 13), (Point 21 10))
    FillPolygon $graphics $steelDark $headShade

    FillRect $graphics $outline 16 15 5 4
    FillRect $graphics $steelDark 17 16 3 2
    FillRect $graphics $cloth 15 18 2 6
    FillRect $graphics $cloth 18 19 2 7
    FillRect $graphics $cloth 21 18 2 5

    FillEllipse $graphics $outline 4 40 6 6
    FillEllipse $graphics $steelDark 5 41 4 4
}

function Draw-ExecutionerGreataxe($graphics) {
    $outline = HexColor "#16171d"
    $shaft = HexColor "#6d5037"
    $shaftLight = HexColor "#8f6a48"
    $metal = HexColor "#c8cfdd"
    $metalDark = HexColor "#737f93"
    $accent = HexColor "#8a2b2b"

    DrawOutlinedLine $graphics $shaft $outline 14 43 18 8 5
    DrawOutlinedLine $graphics $shaftLight $shaftLight 15 41 17 10 1

    $head = @(
        (Point 7 8), (Point 18 4), (Point 23 9), (Point 21 15),
        (Point 12 19), (Point 8 17), (Point 10 12)
    )
    DrawOutlinedPolygon $graphics $metal $outline $head

    $edge = @((Point 9 10), (Point 18 6), (Point 21 9), (Point 12 16), (Point 9 15))
    FillPolygon $graphics $metalDark $edge

    $spike = @((Point 18 6), (Point 23 1), (Point 24 7), (Point 20 9))
    DrawOutlinedPolygon $graphics $metalDark $outline $spike

    FillRect $graphics $outline 12 30 8 4
    FillRect $graphics $accent 13 31 6 2
    FillRect $graphics $outline 11 36 10 3
    FillRect $graphics $accent 12 36 8 1

    FillEllipse $graphics $outline 11 41 8 6
    FillEllipse $graphics $metalDark 13 42 4 3
}

function Draw-EmberWarScythe($graphics) {
    $outline = HexColor "#18191f"
    $shaft = HexColor "#6c5339"
    $shaftLight = HexColor "#94704d"
    $blade = HexColor "#cfd5e2"
    $bladeDark = HexColor "#7b8698"
    $ember = HexColor "#dd6c39"
    $emberGlow = HexColor "#f2bf68"

    DrawOutlinedLine $graphics $shaft $outline 13 43 23 10 4
    DrawOutlinedLine $graphics $shaftLight $shaftLight 14 41 22 12 1

    $bladeShape = @(
        (Point 23 10), (Point 19 6), (Point 12 5), (Point 8 8), (Point 7 12),
        (Point 10 14), (Point 15 13), (Point 18 11), (Point 20 9), (Point 16 16),
        (Point 18 17), (Point 22 14), (Point 25 11)
    )
    DrawOutlinedPolygon $graphics $blade $outline $bladeShape

    $shade = @((Point 18 8), (Point 12 8), (Point 10 11), (Point 15 11), (Point 19 9))
    FillPolygon $graphics $bladeDark $shade

    FillRect $graphics $ember 19 13 3 6
    FillRect $graphics $ember 17 16 3 5
    FillRect $graphics $emberGlow 20 14 1 4
    FillRect $graphics $outline 11 38 8 3
    FillRect $graphics $ember 12 38 6 1
}

function Draw-PilgrimHandCrossbow($graphics) {
    $outline = HexColor "#17181f"
    $wood = HexColor "#6c4d35"
    $woodLight = HexColor "#9a704a"
    $metal = HexColor "#c8d2e0"
    $metalDark = HexColor "#7d899d"
    $cord = HexColor "#d4c8a2"
    $gold = HexColor "#b99257"
    $bolt = HexColor "#8f3130"

    FillRect $graphics $outline 9 21 15 6
    FillRect $graphics $wood 10 22 13 4
    FillRect $graphics $woodLight 11 22 7 1

    FillRect $graphics $outline 15 26 6 8
    FillRect $graphics $wood 16 27 4 6
    FillRect $graphics $outline 18 32 5 6
    FillRect $graphics $wood 19 33 3 4

    $bowTop = @((Point 9 21), (Point 4 15), (Point 5 12), (Point 10 16), (Point 12 20))
    $bowBottom = @((Point 9 26), (Point 4 32), (Point 5 35), (Point 10 31), (Point 12 27))
    DrawOutlinedPolygon $graphics $metal $outline $bowTop
    DrawOutlinedPolygon $graphics $metal $outline $bowBottom

    DrawOutlinedLine $graphics $cord $outline 5 13 5 34 1

    FillRect $graphics $outline 11 22 13 2
    FillRect $graphics $bolt 12 22 10 1
    $tip = @((Point 22 21), (Point 28 23), (Point 22 25))
    DrawOutlinedPolygon $graphics $metalDark $outline $tip

    FillRect $graphics $outline 20 18 4 4
    FillRect $graphics $gold 21 19 2 2
}

$outputDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$weapons = @(
    @{ File = "iron_prison_dagger"; Label = "Iron Prison Dagger"; Drawer = ${function:Draw-IronPrisonDagger} },
    @{ File = "warden_spear"; Label = "Warden Spear"; Drawer = ${function:Draw-WardenSpear} },
    @{ File = "executioner_greataxe"; Label = "Executioner Greataxe"; Drawer = ${function:Draw-ExecutionerGreataxe} },
    @{ File = "ember_war_scythe"; Label = "Ember War Scythe"; Drawer = ${function:Draw-EmberWarScythe} },
    @{ File = "pilgrim_hand_crossbow"; Label = "Pilgrim Hand Crossbow"; Drawer = ${function:Draw-PilgrimHandCrossbow} }
)

$cards = @()

foreach ($weapon in $weapons) {
    $sprite = New-Bitmap 32 48
    $graphics = New-Graphics $sprite
    $graphics.Clear([System.Drawing.Color]::Transparent)
    & $weapon.Drawer $graphics
    $graphics.Dispose()

    $spritePath = Join-Path $outputDir ($weapon.File + ".png")
    Save-Png $sprite $spritePath

    $card = New-PreviewCard $sprite $weapon.Label
    $previewPath = Join-Path $outputDir ($weapon.File + "_preview_4x.png")
    Save-Png $card $previewPath
    $cards += [PSCustomObject]@{
        Label = $weapon.Label
        Bitmap = $card
    }

    $sprite.Dispose()
}

$sheet = New-Bitmap 548 452
$sheetGraphics = New-Graphics $sheet
FillRect $sheetGraphics (HexColor "#0c0f15") 0 0 548 452
FillRect $sheetGraphics (HexColor "#151b27") 10 10 528 432

$positions = @(
    @{ X = 18; Y = 18 },
    @{ X = 186; Y = 18 },
    @{ X = 354; Y = 18 },
    @{ X = 102; Y = 226 },
    @{ X = 270; Y = 226 }
)

for ($i = 0; $i -lt $cards.Count; $i++) {
    $sheetGraphics.DrawImage($cards[$i].Bitmap, $positions[$i].X, $positions[$i].Y, $cards[$i].Bitmap.Width, $cards[$i].Bitmap.Height)
    $cards[$i].Bitmap.Dispose()
}

$titleFont = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$titleBrush = New-Object System.Drawing.SolidBrush((HexColor "#e5ecfa"))
$sheetGraphics.DrawString("Weapon Pitch Set 01", $titleFont, $titleBrush, 18, 408)
$titleFont.Dispose()
$titleBrush.Dispose()
$sheetGraphics.Dispose()

$sheetPath = Join-Path $outputDir "weapon_pitch_set_01_preview_4x.png"
Save-Png $sheet $sheetPath
$sheet.Dispose()
