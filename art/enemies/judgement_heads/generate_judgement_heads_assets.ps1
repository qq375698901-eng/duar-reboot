Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function Write-Utf8NoBom([string]$path, [string]$content) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $encoding)
}

function V([double]$x, [double]$y) {
    [PSCustomObject]@{
        X = $x
        Y = $y
    }
}

function State([hashtable]$overrides = @{}) {
    $base = [ordered]@{
        ox = 0.0
        oy = 0.0
        turn = 0.0
        eye = 0.16
        accent = 0.0
        jaw = 0.0
        crack = 0.0
        shatter = 0.0
        disable = 0.0
        tremor = 0.0
        focus = 0.0
    }
    foreach ($key in $overrides.Keys) {
        $base[$key] = $overrides[$key]
    }
    [PSCustomObject]$base
}

function HexColor([string]$hex, [int]$alpha = 255) {
    if ($hex.StartsWith("#")) {
        $hex = $hex.Substring(1)
    }
    $r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
    [System.Drawing.Color]::FromArgb($alpha, $r, $g, $b)
}

function AlphaColor([System.Drawing.Color]$color, [double]$factor) {
    $alpha = [Math]::Max(0, [Math]::Min(255, [int]([double]$color.A * $factor)))
    [System.Drawing.Color]::FromArgb($alpha, $color.R, $color.G, $color.B)
}

function BlendColor([System.Drawing.Color]$a, [System.Drawing.Color]$b, [double]$t, [int]$alpha = 255) {
    $mix = [Math]::Max(0.0, [Math]::Min(1.0, $t))
    $r = [int]($a.R + (($b.R - $a.R) * $mix))
    $g = [int]($a.G + (($b.G - $a.G) * $mix))
    $bValue = [int]($a.B + (($b.B - $a.B) * $mix))
    [System.Drawing.Color]::FromArgb($alpha, $r, $g, $bValue)
}

function AddVec($a, $b) { V ($a.X + $b.X) ($a.Y + $b.Y) }
function SubVec($a, $b) { V ($a.X - $b.X) ($a.Y - $b.Y) }
function MulVec($a, [double]$scale) { V ($a.X * $scale) ($a.Y * $scale) }
function LenVec($a) { [Math]::Sqrt(($a.X * $a.X) + ($a.Y * $a.Y)) }
function NormalizeVec($a) {
    $length = LenVec $a
    if ($length -lt 0.001) {
        return V 1 0
    }
    V ($a.X / $length) ($a.Y / $length)
}

function ToPointFArray([object[]]$points) {
    $array = New-Object 'System.Drawing.PointF[]' $points.Count
    for ($i = 0; $i -lt $points.Count; $i++) {
        $array[$i] = New-Object System.Drawing.PointF([float]$points[$i].X, [float]$points[$i].Y)
    }
    $array
}

function FillPolygon2D($graphics, [System.Drawing.Color]$fillColor, [System.Drawing.Color]$outlineColor, [object[]]$points) {
    $brush = New-Object System.Drawing.SolidBrush($fillColor)
    $pen = New-Object System.Drawing.Pen($outlineColor, 1)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Miter
    $pointArray = ToPointFArray $points
    $graphics.FillPolygon($brush, $pointArray)
    $graphics.DrawPolygon($pen, $pointArray)
    $brush.Dispose()
    $pen.Dispose()
}

function FillEllipse2D($graphics, [System.Drawing.Color]$fillColor, [System.Drawing.Color]$outlineColor, [double]$x, [double]$y, [double]$w, [double]$h) {
    $brush = New-Object System.Drawing.SolidBrush($fillColor)
    $pen = New-Object System.Drawing.Pen($outlineColor, 1)
    $graphics.FillEllipse($brush, [float]$x, [float]$y, [float]$w, [float]$h)
    $graphics.DrawEllipse($pen, [float]$x, [float]$y, [float]$w, [float]$h)
    $brush.Dispose()
    $pen.Dispose()
}

function FillRect2D($graphics, [System.Drawing.Color]$fillColor, [double]$x, [double]$y, [double]$w, [double]$h) {
    $brush = New-Object System.Drawing.SolidBrush($fillColor)
    $graphics.FillRectangle($brush, [float]$x, [float]$y, [float]$w, [float]$h)
    $brush.Dispose()
}

function DrawLine2D($graphics, [System.Drawing.Color]$color, [double]$width, [double]$x1, [double]$y1, [double]$x2, [double]$y2) {
    $pen = New-Object System.Drawing.Pen($color, [float]$width)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($pen, [float]$x1, [float]$y1, [float]$x2, [float]$y2)
    $pen.Dispose()
}

function DrawArc2D($graphics, [System.Drawing.Color]$color, [double]$width, [double]$x, [double]$y, [double]$w, [double]$h, [double]$startAngle, [double]$sweepAngle) {
    $pen = New-Object System.Drawing.Pen($color, [float]$width)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawArc($pen, [float]$x, [float]$y, [float]$w, [float]$h, [float]$startAngle, [float]$sweepAngle)
    $pen.Dispose()
}

function DrawGlowOrb($graphics, [System.Drawing.Color]$coreColor, [double]$cx, [double]$cy, [double]$radius, [double]$intensity) {
    if ($intensity -le 0.0) { return }
    $outer = AlphaColor $coreColor (0.20 * $intensity)
    $mid = AlphaColor $coreColor (0.38 * $intensity)
    $inner = AlphaColor $coreColor (0.72 * $intensity)
    FillEllipse2D $graphics $outer $outer ($cx - $radius * 1.9) ($cy - $radius * 1.6) ($radius * 3.8) ($radius * 3.2)
    FillEllipse2D $graphics $mid $mid ($cx - $radius * 1.15) ($cy - $radius * 1.0) ($radius * 2.3) ($radius * 2.0)
    FillEllipse2D $graphics $inner $inner ($cx - $radius * 0.55) ($cy - $radius * 0.5) ($radius * 1.1) ($radius * 1.0)
}

function DrawCrack($graphics, [System.Drawing.Color]$color, [double]$x, [double]$y, [double]$len, [double]$depth) {
    DrawLine2D $graphics $color 1.4 $x $y ($x + $len * 0.35) ($y + $depth * 0.35)
    DrawLine2D $graphics $color 1.1 ($x + $len * 0.35) ($y + $depth * 0.35) ($x + $len * 0.78) ($y + $depth * 0.9)
    DrawLine2D $graphics $color 1.0 ($x + $len * 0.36) ($y + $depth * 0.36) ($x + $len * 0.14) ($y + $depth * 1.05)
}

function DrawRuneBar($graphics, [System.Drawing.Color]$color, [double]$x, [double]$y, [double]$w, [double]$h, [double]$glow) {
    $fill = AlphaColor $color (0.12 + $glow * 0.18)
    $edge = AlphaColor $color (0.30 + $glow * 0.50)
    FillRect2D $graphics $fill $x $y $w $h
    DrawLine2D $graphics $edge 1.0 $x $y ($x + $w) $y
    DrawLine2D $graphics $edge 1.0 $x ($y + $h) ($x + $w) ($y + $h)
}

function DrawBeveledPanel($graphics, [double]$x, [double]$y, [double]$w, [double]$h, [System.Drawing.Color]$fillColor, [System.Drawing.Color]$outlineColor) {
    $cut = [Math]::Min(3.0, [Math]::Max(1.0, [Math]::Floor([Math]::Min($w, $h) / 4.0)))
    $points = @(
        (V ($x + $cut) $y)
        (V ($x + $w - $cut) $y)
        (V ($x + $w) ($y + $cut))
        (V ($x + $w) ($y + $h - $cut))
        (V ($x + $w - $cut) ($y + $h))
        (V ($x + $cut) ($y + $h))
        (V $x ($y + $h - $cut))
        (V $x ($y + $cut))
    )
    FillPolygon2D $graphics $fillColor $outlineColor $points

    $highlight = AlphaColor (BlendColor $fillColor ([System.Drawing.Color]::White) 0.28) 0.70
    $shadow = AlphaColor (BlendColor $fillColor ([System.Drawing.Color]::Black) 0.36) 0.78
    DrawLine2D $graphics $highlight 1.2 ($x + $cut + 1) ($y + 1) ($x + $w - $cut - 2) ($y + 1)
    DrawLine2D $graphics $highlight 1.0 ($x + 1) ($y + $cut + 1) ($x + 1) ($y + $h - $cut - 2)
    DrawLine2D $graphics $shadow 1.2 ($x + $cut + 1) ($y + $h - 1) ($x + $w - $cut - 2) ($y + $h - 1)
    DrawLine2D $graphics $shadow 1.0 ($x + $w - 1) ($y + $cut + 1) ($x + $w - 1) ($y + $h - $cut - 2)
}

function New-SheetBitmap([int]$width, [int]$height) {
    $bitmap = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed
    [PSCustomObject]@{
        Bitmap = $bitmap
        Graphics = $graphics
    }
}

function SavePng($bitmap, [string]$path) {
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function BuildHeadAnimations([string]$style) {
    $idle = @(
        (State @{ eye = 0.16 }),
        (State @{ oy = -0.6; turn = 0.04; eye = 0.18 }),
        (State @{ oy = 0.5; jaw = 0.12; eye = 0.20 }),
        (State @{ oy = -0.2; turn = -0.03; eye = 0.17 })
    )

    $hit = @(
        (State @{ tremor = -2.0; crack = 0.36; eye = 0.10; accent = 0.15 }),
        (State @{ tremor = 2.4; crack = 0.46; eye = 0.06; accent = 0.08 }),
        (State @{ tremor = -0.8; crack = 0.26; eye = 0.12; accent = 0.10 })
    )

    $break = @(
        (State @{ crack = 0.34; accent = 0.25; eye = 0.20 }),
        (State @{ crack = 0.58; shatter = 0.18; accent = 0.18; eye = 0.14; tremor = -1.2 }),
        (State @{ crack = 0.82; shatter = 0.42; accent = 0.12; eye = 0.08; oy = 2.0 }),
        (State @{ crack = 1.0; shatter = 0.70; accent = 0.04; eye = 0.02; oy = 5.0; disable = 0.42 }),
        (State @{ crack = 1.0; shatter = 1.0; accent = 0.0; eye = 0.0; oy = 8.0; disable = 0.82 })
    )

    switch ($style) {
        "fire" {
            return @{
                idle = $idle
                active = @(
                    (State @{ eye = 0.08; accent = 0.14; turn = 0.08; focus = 0.20 }),
                    (State @{ eye = 0.10; accent = 0.22; turn = 0.20; focus = 0.42 }),
                    (State @{ eye = 0.12; accent = 0.32; turn = 0.34; oy = -0.5; focus = 0.66 }),
                    (State @{ eye = 0.14; accent = 0.40; turn = 0.52; focus = 0.82 }),
                    (State @{ eye = 0.16; accent = 0.48; turn = 0.72; focus = 1.0 })
                )
                cast = @(
                    (State @{ eye = 0.10; accent = 0.24; turn = 0.76; focus = 0.10 }),
                    (State @{ eye = 0.26; accent = 0.36; turn = 0.86; jaw = 0.08; focus = 0.08 }),
                    (State @{ eye = 0.48; accent = 0.52; turn = 0.98; jaw = 0.14; oy = -0.3; focus = 0.06 }),
                    (State @{ eye = 0.74; accent = 0.74; turn = 1.0; jaw = 0.22; focus = 0.04 }),
                    (State @{ eye = 1.0; accent = 1.0; turn = 0.90; jaw = 0.12; focus = 0.02 }),
                    (State @{ eye = 0.62; accent = 0.46; turn = 0.56; focus = 0.0 })
                )
                hit = $hit
                break = $break
            }
        }
        "thunder" {
            return @{
                idle = $idle
                active = @(
                    (State @{ eye = 0.08; accent = 0.18; focus = 0.24 }),
                    (State @{ eye = 0.10; accent = 0.30; focus = 0.44; oy = -0.4 }),
                    (State @{ eye = 0.12; accent = 0.42; focus = 0.66; oy = -0.8 }),
                    (State @{ eye = 0.14; accent = 0.56; focus = 0.84; oy = -1.2 }),
                    (State @{ eye = 0.16; accent = 0.70; focus = 1.0; oy = -1.4 })
                )
                cast = @(
                    (State @{ eye = 0.10; accent = 0.28; focus = 0.12; oy = -1.1 }),
                    (State @{ eye = 0.24; accent = 0.40; focus = 0.08; oy = -1.4 }),
                    (State @{ eye = 0.46; accent = 0.58; focus = 0.06; oy = -1.7; tremor = -0.2 }),
                    (State @{ eye = 0.70; accent = 0.78; focus = 0.04; oy = -2.0; tremor = 0.4 }),
                    (State @{ eye = 1.0; accent = 1.0; focus = 0.02; oy = -1.2 }),
                    (State @{ eye = 0.58; accent = 0.46; focus = 0.0; oy = -0.6 })
                )
                hit = $hit
                break = $break
            }
        }
        "wind" {
            return @{
                idle = @(
                    (State @{ eye = 0.10 }),
                    (State @{ oy = -0.8; jaw = 0.10; eye = 0.12 }),
                    (State @{ oy = 0.6; jaw = 0.20; eye = 0.14 }),
                    (State @{ oy = -0.2; jaw = 0.12; eye = 0.11 })
                )
                active = @(
                    (State @{ eye = 0.06; accent = 0.18; jaw = 0.18; focus = 0.24 }),
                    (State @{ eye = 0.08; accent = 0.28; jaw = 0.24; focus = 0.44 }),
                    (State @{ eye = 0.10; accent = 0.40; jaw = 0.32; focus = 0.66 }),
                    (State @{ eye = 0.12; accent = 0.54; jaw = 0.42; focus = 0.84 }),
                    (State @{ eye = 0.14; accent = 0.68; jaw = 0.50; focus = 1.0 })
                )
                cast = @(
                    (State @{ eye = 0.08; accent = 0.26; jaw = 0.58; focus = 0.12 }),
                    (State @{ eye = 0.18; accent = 0.38; jaw = 0.70; focus = 0.08; oy = -0.3 }),
                    (State @{ eye = 0.34; accent = 0.54; jaw = 0.82; focus = 0.06; oy = -0.5 }),
                    (State @{ eye = 0.58; accent = 0.74; jaw = 0.90; focus = 0.04 }),
                    (State @{ eye = 0.90; accent = 1.0; jaw = 0.76; focus = 0.02 }),
                    (State @{ eye = 0.42; accent = 0.48; jaw = 0.38; focus = 0.0 })
                )
                hit = $hit
                break = $break
            }
        }
        "guard" {
            return @{
                idle = @(
                    (State @{ eye = 0.18 }),
                    (State @{ oy = -0.3; eye = 0.19 }),
                    (State @{ oy = 0.3; eye = 0.20; accent = 0.04 }),
                    (State @{ oy = -0.2; eye = 0.18 })
                )
                active = @(
                    (State @{ eye = 0.08; accent = 0.22; focus = 0.24 }),
                    (State @{ eye = 0.10; accent = 0.34; focus = 0.46 }),
                    (State @{ eye = 0.12; accent = 0.46; focus = 0.68 }),
                    (State @{ eye = 0.14; accent = 0.60; focus = 0.86 }),
                    (State @{ eye = 0.16; accent = 0.72; focus = 1.0 })
                )
                cast = @(
                    (State @{ eye = 0.10; accent = 0.28; focus = 0.14; oy = -0.2 }),
                    (State @{ eye = 0.20; accent = 0.40; focus = 0.10; oy = -0.3 }),
                    (State @{ eye = 0.36; accent = 0.56; focus = 0.06; oy = -0.4 }),
                    (State @{ eye = 0.58; accent = 0.76; focus = 0.04; oy = -0.4 }),
                    (State @{ eye = 0.88; accent = 1.0; focus = 0.02; oy = -0.2 }),
                    (State @{ eye = 0.42; accent = 0.48; focus = 0.0 })
                )
                hit = @(
                    (State @{ tremor = -1.4; crack = 0.28; eye = 0.12; accent = 0.10 }),
                    (State @{ tremor = 1.6; crack = 0.36; eye = 0.10; accent = 0.08 }),
                    (State @{ tremor = -0.5; crack = 0.20; eye = 0.14; accent = 0.08 })
                )
                break = $break
            }
        }
        "restore" {
            return @{
                idle = @(
                    (State @{ eye = 0.16; accent = 0.04 }),
                    (State @{ oy = -0.4; eye = 0.18; accent = 0.06 }),
                    (State @{ oy = 0.4; eye = 0.20; accent = 0.10 }),
                    (State @{ oy = -0.2; eye = 0.18; accent = 0.06 })
                )
                active = @(
                    (State @{ eye = 0.08; accent = 0.24; focus = 0.24 }),
                    (State @{ eye = 0.10; accent = 0.38; focus = 0.46 }),
                    (State @{ eye = 0.12; accent = 0.54; focus = 0.68 }),
                    (State @{ eye = 0.14; accent = 0.70; focus = 0.86 }),
                    (State @{ eye = 0.16; accent = 0.86; focus = 1.0 })
                )
                cast = @(
                    (State @{ eye = 0.08; accent = 0.28; focus = 0.14; oy = -0.2 }),
                    (State @{ eye = 0.18; accent = 0.40; focus = 0.10; oy = -0.3 }),
                    (State @{ eye = 0.34; accent = 0.56; focus = 0.06; oy = -0.4 }),
                    (State @{ eye = 0.58; accent = 0.78; focus = 0.04; oy = -0.4 }),
                    (State @{ eye = 0.92; accent = 1.0; focus = 0.02; oy = -0.3 }),
                    (State @{ eye = 0.46; accent = 0.50; focus = 0.0 })
                )
                hit = @(
                    (State @{ tremor = -1.8; crack = 0.30; eye = 0.12; accent = 0.22 }),
                    (State @{ tremor = 1.8; crack = 0.42; eye = 0.08; accent = 0.10 }),
                    (State @{ tremor = -0.6; crack = 0.20; eye = 0.10; accent = 0.06 })
                )
                break = $break
            }
        }
    }
}

function DrawHeadCore($graphics, $spec, $state) {
    $turnOffset = $state.turn * 8.0
    $shakeX = $state.tremor
    $baseShift = V ($spec.centerX + $state.ox + $shakeX) ($spec.centerY + $state.oy)

    $stoneMain = $spec.palette.stoneMain
    $stoneMid = $spec.palette.stoneMid
    $stoneDark = $spec.palette.stoneDark
    $outline = $spec.palette.outline
    $accent = $spec.palette.accent
    $accentHot = $spec.palette.accentHot
    $crackColor = $spec.palette.crack
    $stoneLight = BlendColor $stoneMid ([System.Drawing.Color]::White) 0.16
    $stonePanel = BlendColor $stoneMain $stoneMid 0.30
    $stoneInset = BlendColor $stoneDark $stoneMain 0.20
    $stoneShadow = BlendColor $stoneDark ([System.Drawing.Color]::Black) 0.26
    $chipLight = BlendColor $stoneMid ([System.Drawing.Color]::White) 0.12

    $leftX = $baseShift.X - 24
    $rightX = $baseShift.X + 13
    $frontShift = $turnOffset * 0.55
    $faceShift = $turnOffset * 0.70

    DrawBeveledPanel $graphics ($baseShift.X - 18) ($baseShift.Y + 24) 36 14 (AlphaColor $stoneShadow (1.0 - $state.disable * 0.3)) $outline
    DrawBeveledPanel $graphics ($baseShift.X - 13) ($baseShift.Y + 18) 26 8 (AlphaColor $stoneDark (1.0 - $state.disable * 0.26)) $outline

    DrawBeveledPanel $graphics ($baseShift.X - 22) ($baseShift.Y - 33) 44 13 (AlphaColor $stoneMid (1.0 - $state.disable * 0.24)) $outline
    DrawBeveledPanel $graphics ($leftX) ($baseShift.Y - 22) 13 40 (AlphaColor $stoneMain (1.0 - $state.disable * 0.22)) $outline
    DrawBeveledPanel $graphics ($rightX + $frontShift) ($baseShift.Y - 22) 15 40 (AlphaColor $stoneInset (1.0 - $state.disable * 0.20)) $outline
    DrawBeveledPanel $graphics ($baseShift.X - 16) ($baseShift.Y + 15) 32 11 (AlphaColor $stoneMain (1.0 - $state.disable * 0.22)) $outline

    DrawBeveledPanel $graphics ($baseShift.X - 16) ($baseShift.Y - 22) 14 18 (AlphaColor $stonePanel (1.0 - $state.disable * 0.16)) $outline
    DrawBeveledPanel $graphics ($baseShift.X - 1 + $frontShift) ($baseShift.Y - 22) 16 18 (AlphaColor $stonePanel (1.0 - $state.disable * 0.16)) $outline
    DrawBeveledPanel $graphics ($baseShift.X - 15) ($baseShift.Y - 3) 13 16 (AlphaColor $stoneInset (1.0 - $state.disable * 0.14)) $outline
    DrawBeveledPanel $graphics ($baseShift.X - 1 + $frontShift) ($baseShift.Y - 3) 14 16 (AlphaColor $stoneInset (1.0 - $state.disable * 0.14)) $outline

    DrawBeveledPanel $graphics ($baseShift.X - 13 + $faceShift) ($baseShift.Y - 18) 28 34 (AlphaColor $stoneDark (0.86 - $state.disable * 0.20)) $outline
    DrawBeveledPanel $graphics ($baseShift.X - 12 + $faceShift) ($baseShift.Y - 17) 26 8 (AlphaColor $stoneLight (0.95 - $state.disable * 0.18)) $outline
    DrawBeveledPanel $graphics ($baseShift.X - 5 + $faceShift) ($baseShift.Y - 9) 8 22 (AlphaColor $stonePanel (0.94 - $state.disable * 0.18)) $outline
    DrawBeveledPanel $graphics ($baseShift.X - 10 + $faceShift) ($baseShift.Y + 12) 20 8 (AlphaColor $stoneInset (0.92 - $state.disable * 0.18)) $outline

    DrawBeveledPanel $graphics ($baseShift.X - 20) ($baseShift.Y - 18) 8 9 (AlphaColor $stoneMain 0.84) $outline
    DrawBeveledPanel $graphics ($baseShift.X + 15 + $frontShift) ($baseShift.Y - 15) 8 11 (AlphaColor $stoneInset 0.90) $outline

    DrawRuneBar $graphics $stoneLight ($baseShift.X - 18) ($baseShift.Y - 2) 5 2 (0.08 + $state.focus * 0.12)
    DrawRuneBar $graphics $stoneLight ($baseShift.X + 11 + $frontShift) ($baseShift.Y - 2) 5 2 (0.08 + $state.focus * 0.12)

    DrawLine2D $graphics (AlphaColor $stoneLight 0.45) 1.0 ($baseShift.X - 20) ($baseShift.Y - 26) ($baseShift.X + 16) ($baseShift.Y - 28)
    DrawLine2D $graphics (AlphaColor $stoneShadow 0.60) 1.0 ($baseShift.X - 13) ($baseShift.Y + 22) ($baseShift.X + 13) ($baseShift.Y + 22)

    if ($state.focus -gt 0.04) {
        $circleGlow = 0.20 + ($state.focus * 0.58)
        $circleColor = AlphaColor $accent $circleGlow
        $circleHot = AlphaColor $accentHot ($circleGlow * 0.9)
        $ringX = $baseShift.X - 12 + $faceShift
        $ringY = $baseShift.Y - 16
        DrawArc2D $graphics $circleColor 1.4 $ringX $ringY 26 26 206 128
        DrawArc2D $graphics $circleHot 1.0 ($ringX + 3) ($ringY + 3) 20 20 198 122
        DrawArc2D $graphics $circleColor 1.0 ($ringX + 7) ($ringY + 7) 12 12 0 360
        DrawLine2D $graphics $circleHot 1.0 ($baseShift.X + 1 + $faceShift) ($baseShift.Y - 15) ($baseShift.X + 1 + $faceShift) ($baseShift.Y + 8)
        DrawLine2D $graphics $circleHot 1.0 ($baseShift.X - 10 + $faceShift) ($baseShift.Y - 3) ($baseShift.X + 12 + $faceShift) ($baseShift.Y - 3)
        DrawLine2D $graphics $circleColor 1.0 ($baseShift.X - 8 + $faceShift) ($baseShift.Y - 11) ($baseShift.X + 10 + $faceShift) ($baseShift.Y + 6)
        DrawLine2D $graphics $circleColor 1.0 ($baseShift.X + 10 + $faceShift) ($baseShift.Y - 11) ($baseShift.X - 8 + $faceShift) ($baseShift.Y + 6)
    }

    $turnN = [Math]::Max(-1.0, [Math]::Min(1.0, $state.turn))
    $turnScale = ($turnN + 1.0) * 0.5
    $farEyeScale = 0.58 + (1.0 - $turnScale) * 0.16
    $nearEyeScale = 0.74 + $turnScale * 0.24
    $eyeGlow = $state.eye * (1.0 - $state.disable)

    $eyeY = $baseShift.Y - 6
    $leftEyeCx = $baseShift.X - 7 + ($turnOffset * 0.34)
    $rightEyeCx = $baseShift.X + 8 + ($turnOffset * 0.70)
    $leftEyeW = 8.0 * $farEyeScale
    $rightEyeW = 9.5 * $nearEyeScale
    $leftTilt = -0.45 + ($turnN * 0.16)
    $rightTilt = 0.35 + ($turnN * 0.20)

    DrawBeveledPanel $graphics ($leftEyeCx - 5.6) ($eyeY - 4.4) 9.0 7.6 (AlphaColor $stoneInset 0.98) $outline
    DrawBeveledPanel $graphics ($rightEyeCx - 6.2) ($eyeY - 4.6) 10.5 7.8 (AlphaColor $stoneInset 0.99) $outline

    $leftSlot = @(
        (V ($leftEyeCx - $leftEyeW * 0.52) ($eyeY - 0.6 - $leftTilt))
        (V ($leftEyeCx + $leftEyeW * 0.18) ($eyeY - 1.4 + $leftTilt))
        (V ($leftEyeCx + $leftEyeW * 0.40) ($eyeY + 0.1 + $leftTilt))
        (V ($leftEyeCx - $leftEyeW * 0.22) ($eyeY + 1.1 - $leftTilt))
    )
    $rightSlot = @(
        (V ($rightEyeCx - $rightEyeW * 0.50) ($eyeY - 1.0 - $rightTilt))
        (V ($rightEyeCx + $rightEyeW * 0.20) ($eyeY - 1.6 + $rightTilt))
        (V ($rightEyeCx + $rightEyeW * 0.46) ($eyeY + 0.0 + $rightTilt))
        (V ($rightEyeCx - $rightEyeW * 0.18) ($eyeY + 1.2 - $rightTilt))
    )
    FillPolygon2D $graphics (AlphaColor $stoneDark 0.98) $outline $leftSlot
    FillPolygon2D $graphics (AlphaColor $stoneDark 0.98) $outline $rightSlot
    DrawGlowOrb $graphics $accent $leftEyeCx $eyeY 3.8 $eyeGlow
    DrawGlowOrb $graphics $accent $rightEyeCx $eyeY 4.3 $eyeGlow
    FillPolygon2D $graphics (AlphaColor $accentHot (0.74 * $eyeGlow + 0.04)) $outline $leftSlot
    FillPolygon2D $graphics (AlphaColor $accentHot (0.82 * $eyeGlow + 0.05)) $outline $rightSlot
    DrawLine2D $graphics (AlphaColor $accentHot (0.90 * $eyeGlow + 0.08)) 1.0 ($leftEyeCx - $leftEyeW * 0.40) ($eyeY - 0.2) ($leftEyeCx + $leftEyeW * 0.28) ($eyeY - 0.4 + $leftTilt)
    DrawLine2D $graphics (AlphaColor $accentHot (0.96 * $eyeGlow + 0.10)) 1.0 ($rightEyeCx - $rightEyeW * 0.42) ($eyeY - 0.4) ($rightEyeCx + $rightEyeW * 0.32) ($eyeY - 0.2 + $rightTilt)

    $jawWidth = 18 + ($state.jaw * 9)
    DrawBeveledPanel $graphics ($baseShift.X - 12 + $faceShift) ($baseShift.Y + 6) $jawWidth 10 (AlphaColor $stoneShadow (1.0 - $state.disable * 0.24)) $outline
    DrawBeveledPanel $graphics ($baseShift.X - 8 + $faceShift) ($baseShift.Y + 9) ($jawWidth - 8) 4 (AlphaColor $stoneDark 0.98) $outline
    DrawLine2D $graphics (AlphaColor $stoneMid 0.45) 1.0 ($baseShift.X - 6 + $faceShift) ($baseShift.Y + 11) ($baseShift.X + 5 + $state.jaw * 2 + $faceShift) ($baseShift.Y + 11)

    switch ($spec.style) {
        "fire" {
            DrawRuneBar $graphics $accent ($baseShift.X - 20) ($baseShift.Y + 4) 6 2 (0.10 + $state.accent * 0.48)
            DrawGlowOrb $graphics $accentHot ($baseShift.X + 15 + $turnOffset) ($baseShift.Y - 1) 6.0 (0.30 + $state.accent * 0.95)
            DrawLine2D $graphics (AlphaColor $accentHot (0.28 + $state.accent * 0.48)) 2.0 ($baseShift.X + 14) ($baseShift.Y + 1) ($baseShift.X + 25 + $turnOffset) ($baseShift.Y - 7)
            DrawLine2D $graphics (AlphaColor $accentHot (0.32 + $state.accent * 0.56)) 2.0 ($baseShift.X + 14) ($baseShift.Y + 4) ($baseShift.X + 28 + $turnOffset) ($baseShift.Y + 2)
            DrawLine2D $graphics (AlphaColor $accentHot (0.24 + $state.accent * 0.40)) 1.6 ($baseShift.X + 14) ($baseShift.Y + 7) ($baseShift.X + 24 + $turnOffset) ($baseShift.Y + 10)
        }
        "thunder" {
            $crestPoints = @(
                (AddVec $baseShift (V -4 -30))
                (AddVec $baseShift (V 2 -38))
                (AddVec $baseShift (V 8 -30))
                (AddVec $baseShift (V 2 -18))
            )
            FillPolygon2D $graphics (AlphaColor $stoneMid 0.92) $outline $crestPoints
            DrawGlowOrb $graphics $accent ($baseShift.X + 2) ($baseShift.Y - 23) 5.0 (0.25 + $state.focus * 0.95)
            DrawLine2D $graphics (AlphaColor $accentHot (0.20 + $state.accent * 0.70)) 1.6 ($baseShift.X + 1) ($baseShift.Y - 18) ($baseShift.X - 5) ($baseShift.Y - 7)
            DrawLine2D $graphics (AlphaColor $accentHot (0.20 + $state.accent * 0.70)) 1.6 ($baseShift.X + 1) ($baseShift.Y - 18) ($baseShift.X + 8) ($baseShift.Y - 4)
        }
        "wind" {
            DrawArc2D $graphics (AlphaColor $accent (0.18 + $state.accent * 0.34)) 2.0 ($baseShift.X + 3) ($baseShift.Y - 2) 22 14 -18 88
            DrawArc2D $graphics (AlphaColor $accentHot (0.20 + $state.focus * 0.34)) 1.6 ($baseShift.X + 10) ($baseShift.Y - 5) 18 12 0 78
            DrawArc2D $graphics (AlphaColor $accent (0.14 + $state.accent * 0.28)) 1.2 ($baseShift.X - 6) ($baseShift.Y + 1) 18 10 8 72
        }
        "guard" {
            DrawBeveledPanel $graphics ($baseShift.X - 16 + $faceShift) ($baseShift.Y - 18) 32 32 (AlphaColor $stoneShadow 0.96) $outline
            DrawRuneBar $graphics $accent ($baseShift.X - 18) ($baseShift.Y - 18) 7 2 (0.18 + $state.accent * 0.72)
            DrawRuneBar $graphics $accent ($baseShift.X + 10) ($baseShift.Y - 18) 7 2 (0.18 + $state.accent * 0.72)
            DrawLine2D $graphics (AlphaColor $accentHot (0.18 + $state.focus * 0.38)) 1.4 ($baseShift.X - 6) ($baseShift.Y + 11) ($baseShift.X + 11) ($baseShift.Y + 11)
            DrawLine2D $graphics (AlphaColor $stoneLight 0.45) 1.0 ($baseShift.X - 18) ($baseShift.Y - 6) ($baseShift.X + 18) ($baseShift.Y - 6)
        }
        "restore" {
            DrawGlowOrb $graphics $accent ($baseShift.X + 2) ($baseShift.Y + 4) 6.0 (0.22 + $state.focus * 0.65)
            DrawArc2D $graphics (AlphaColor $accent (0.22 + $state.accent * 0.32)) 1.8 ($baseShift.X - 10) ($baseShift.Y - 12) 20 20 216 132
            DrawArc2D $graphics (AlphaColor $accentHot (0.20 + $state.focus * 0.42)) 1.4 ($baseShift.X - 2) ($baseShift.Y - 18) 18 18 194 128
            DrawLine2D $graphics (AlphaColor $accentHot (0.20 + $state.focus * 0.52)) 1.2 ($baseShift.X - 3) ($baseShift.Y + 6) ($baseShift.X - 7) ($baseShift.Y + 16)
            DrawLine2D $graphics (AlphaColor $accentHot (0.20 + $state.focus * 0.52)) 1.2 ($baseShift.X + 6) ($baseShift.Y + 6) ($baseShift.X + 11) ($baseShift.Y + 17)
        }
    }

    if ($state.crack -gt 0.0) {
        $crackAlpha = 0.24 + ($state.crack * 0.72)
        DrawCrack $graphics (AlphaColor $crackColor $crackAlpha) ($baseShift.X - 10) ($baseShift.Y - 18) 14 16
        DrawCrack $graphics (AlphaColor $crackColor ($crackAlpha * 0.82)) ($baseShift.X + 5) ($baseShift.Y - 12) 11 14
        if ($state.crack -gt 0.52) {
            DrawCrack $graphics (AlphaColor $crackColor ($crackAlpha * 0.70)) ($baseShift.X - 2) ($baseShift.Y + 1) 12 13
        }
    }

    if ($state.shatter -gt 0.0) {
        $chipColor = AlphaColor $chipLight (0.78 - $state.disable * 0.3)
        FillPolygon2D $graphics $chipColor $outline @(
            (AddVec $baseShift (V -24 (-12 - $state.shatter * 6)))
            (AddVec $baseShift (V -18 (-16 - $state.shatter * 8)))
            (AddVec $baseShift (V -16 (-8 - $state.shatter * 4)))
        )
        FillPolygon2D $graphics $chipColor $outline @(
            (AddVec $baseShift (V 18 (-22 - $state.shatter * 10)))
            (AddVec $baseShift (V 24 (-16 - $state.shatter * 12)))
            (AddVec $baseShift (V 20 (-10 - $state.shatter * 6)))
        )
        FillPolygon2D $graphics $chipColor $outline @(
            (AddVec $baseShift (V 10 (18 + $state.shatter * 4)))
            (AddVec $baseShift (V 16 (24 + $state.shatter * 8)))
            (AddVec $baseShift (V 8 (26 + $state.shatter * 5)))
        )
    }
}

$frameWidth = 96
$frameHeight = 96
$baselineY = 74

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$artDir = $PSScriptRoot
$sceneDir = Join-Path $repoRoot "scenes\enemies"
$manifestPath = Join-Path $artDir "judgement_heads_manifest.json"
$readmePath = Join-Path $artDir "README.md"

New-Item -ItemType Directory -Force -Path $artDir | Out-Null
New-Item -ItemType Directory -Force -Path $sceneDir | Out-Null

$heads = @(
    [PSCustomObject]@{
        id = "judgement_fire_head"
        display = "Fire Head"
        style = "fire"
        palette = [PSCustomObject]@{
            stoneMain = HexColor "#353346"
            stoneMid = HexColor "#55506C"
            stoneDark = HexColor "#181724"
            outline = HexColor "#09090F"
            accent = HexColor "#FF8B42"
            accentHot = HexColor "#FFD39A"
            crack = HexColor "#706A81"
        }
    }
    [PSCustomObject]@{
        id = "judgement_thunder_head"
        display = "Thunder Head"
        style = "thunder"
        palette = [PSCustomObject]@{
            stoneMain = HexColor "#34364A"
            stoneMid = HexColor "#565B79"
            stoneDark = HexColor "#171927"
            outline = HexColor "#090A11"
            accent = HexColor "#A3C4FF"
            accentHot = HexColor "#F0F6FF"
            crack = HexColor "#707897"
        }
    }
    [PSCustomObject]@{
        id = "judgement_wind_head"
        display = "Wind Head"
        style = "wind"
        palette = [PSCustomObject]@{
            stoneMain = HexColor "#313846"
            stoneMid = HexColor "#516070"
            stoneDark = HexColor "#141A24"
            outline = HexColor "#090B10"
            accent = HexColor "#8FB7B0"
            accentHot = HexColor "#D9F1EC"
            crack = HexColor "#6D798A"
        }
    }
    [PSCustomObject]@{
        id = "judgement_guard_head"
        display = "Guard Head"
        style = "guard"
        palette = [PSCustomObject]@{
            stoneMain = HexColor "#2D3142"
            stoneMid = HexColor "#4D536B"
            stoneDark = HexColor "#121521"
            outline = HexColor "#07080D"
            accent = HexColor "#B8C1CA"
            accentHot = HexColor "#F1F3F6"
            crack = HexColor "#646D84"
        }
    }
    [PSCustomObject]@{
        id = "judgement_restore_head"
        display = "Restore Head"
        style = "restore"
        palette = [PSCustomObject]@{
            stoneMain = HexColor "#334040"
            stoneMid = HexColor "#546968"
            stoneDark = HexColor "#151C1C"
            outline = HexColor "#080C0C"
            accent = HexColor "#9EC9BC"
            accentHot = HexColor "#ECFFF6"
            crack = HexColor "#6B7E7B"
        }
    }
)

$allManifestHeads = @()
$readmeLines = @(
    "# Judgement Heads"
    ""
    "- Boss unit set: 5 independent head modules only"
    "- Frame size: 96x96"
    "- Background: transparent"
    "- Facing: right by default"
    "- Delivery: one horizontal strip per animation, fixed canvas, no frame overlap"
    "- Shared theme: ancient stone judgement mechanism"
    ""
)

foreach ($head in $heads) {
    $animations = BuildHeadAnimations $head.style
    $animationOrder = @("idle", "active", "cast", "hit", "break")
    $manifestAnimations = @()
    $sheetMeta = @()

    foreach ($animationName in $animationOrder) {
        $frames = $animations[$animationName]
        $fps = switch ($animationName) {
            "idle" { 6 }
            "active" { 8 }
            "cast" { 9 }
            "hit" { 8 }
            "break" { 8 }
        }
        $loop = ($animationName -eq "idle")

        $sheet = New-SheetBitmap ($frameWidth * $frames.Count) $frameHeight
        for ($i = 0; $i -lt $frames.Count; $i++) {
            $frameBitmap = New-SheetBitmap $frameWidth $frameHeight
            $spec = [PSCustomObject]@{
                style = $head.style
                palette = $head.palette
                centerX = 47.0
                centerY = 42.0
            }
            DrawHeadCore $frameBitmap.Graphics $spec $frames[$i]
            $sheet.Graphics.DrawImageUnscaled($frameBitmap.Bitmap, $i * $frameWidth, 0)
            $frameBitmap.Graphics.Dispose()
            $frameBitmap.Bitmap.Dispose()
        }

        $fileName = "{0}_{1}_strip.png" -f $head.id, $animationName
        $filePath = Join-Path $artDir $fileName
        SavePng $sheet.Bitmap $filePath
        $sheet.Graphics.Dispose()
        $sheet.Bitmap.Dispose()

        $manifestAnimations += [PSCustomObject]@{
            name = $animationName
            file = $fileName
            frames = $frames.Count
            fps = $fps
            loop = [bool]$loop
        }

        $sheetMeta += [PSCustomObject]@{
            name = $animationName
            file = $fileName
            path = "res://art/enemies/judgement_heads/$fileName"
            frames = $frames.Count
            fps = $fps
            loop = [bool]$loop
        }
    }

    $previewScale = 4
    $previewGap = 8
    $maxPreviewWidth = 0
    $previewHeight = 0
    foreach ($sheet in $sheetMeta) {
        $rowWidth = $sheet.frames * $frameWidth * $previewScale
        if ($rowWidth -gt $maxPreviewWidth) {
            $maxPreviewWidth = $rowWidth
        }
        $previewHeight += ($frameHeight * $previewScale) + $previewGap
    }
    $previewHeight -= $previewGap

    $previewPath = Join-Path $artDir ("{0}_preview_4x.png" -f $head.id)
    $preview = New-Object System.Drawing.Bitmap($maxPreviewWidth, $previewHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
    $previewGraphics.Clear([System.Drawing.Color]::Transparent)
    $previewGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $previewGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $previewGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None

    $previewY = 0
    foreach ($sheet in $sheetMeta) {
        $imagePath = Join-Path $artDir $sheet.file
        $image = [System.Drawing.Image]::FromFile($imagePath)
        $destWidth = $image.Width * $previewScale
        $destHeight = $image.Height * $previewScale
        $previewGraphics.DrawImage($image, (New-Object System.Drawing.Rectangle(0, $previewY, $destWidth, $destHeight)))
        $image.Dispose()
        $previewY += $destHeight + $previewGap
    }
    SavePng $preview $previewPath
    $previewGraphics.Dispose()
    $preview.Dispose()

    $scenePath = Join-Path $sceneDir ("{0}_sprite.tscn" -f $head.id)
    $extLines = New-Object System.Collections.Generic.List[string]
    $subLines = New-Object System.Collections.Generic.List[string]
    $animationBlocks = New-Object System.Collections.Generic.List[string]
    $atlasIndex = 0
    $resourceIndex = 1
    $resourceMap = @{}

    foreach ($sheet in $sheetMeta) {
        $resourceId = "{0}_{1}" -f $resourceIndex, $sheet.name
        $resourceMap[$sheet.name] = $resourceId
        $extLines.Add(('[ext_resource type="Texture2D" path="{0}" id="{1}"]' -f $sheet.path, $resourceId))
        $extLines.Add("")
        $resourceIndex++
    }

    foreach ($sheet in $sheetMeta) {
        $frameRefs = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $sheet.frames; $i++) {
            $atlasName = "AtlasTexture_{0}" -f $atlasIndex
            $subLines.Add(('[sub_resource type="AtlasTexture" id="{0}"]' -f $atlasName))
            $subLines.Add(('atlas = ExtResource("{0}")' -f $resourceMap[$sheet.name]))
            $subLines.Add(('region = Rect2({0}, 0, {1}, {2})' -f ($i * $frameWidth), $frameWidth, $frameHeight))
            $subLines.Add("")
            $frameRefs.Add(('{{"duration": 1.0, "texture": SubResource("{0}")}}' -f $atlasName))
            $atlasIndex++
        }
        $loopText = if ($sheet.loop) { "true" } else { "false" }
        $animationBlocks.Add(@"
{
"frames": [$($frameRefs -join ", ")],
"loop": $loopText,
"name": &"$($sheet.name)",
"speed": $($sheet.fps).0
}
"@.Trim())
    }

    $spriteFramesBlock = @"
[sub_resource type="SpriteFrames" id="SpriteFrames_$($head.id)"]
animations = [$($animationBlocks -join ",`r`n")]

"@

    $rootName = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase(($head.id -replace "_", " "))
    $rootName = $rootName -replace " ", ""
    $sceneText = @"
[gd_scene load_steps=$($sheetMeta.Count + $atlasIndex + 2) format=3]

$($extLines -join "`r`n")
$($subLines -join "`r`n")
$spriteFramesBlock
[node name="$rootName" type="Node2D"]

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
position = Vector2(0, 0)
sprite_frames = SubResource("SpriteFrames_$($head.id)")
animation = &"idle"
frame = 0
centered = true
"@
    Write-Utf8NoBom $scenePath $sceneText

    $allManifestHeads += [PSCustomObject]@{
        id = $head.id
        display_name = $head.display
        style = $head.style
        preview = [System.IO.Path]::GetFileName($previewPath)
        animations = $manifestAnimations
    }

    $readmeLines += @(
        "## $($head.display)",
        ""
        "- Id: $($head.id)"
        "- Preview: $([System.IO.Path]::GetFileName($previewPath))"
    )
    $readmeLines += $manifestAnimations | ForEach-Object { "- {0}: {1} frames @ {2} fps" -f $_.name, $_.frames, $_.fps }
    $readmeLines += ""
}

$manifest = [PSCustomObject]@{
    name = "judgement_heads"
    display_name = "Judgement Boss Heads"
    frame_width = $frameWidth
    frame_height = $frameHeight
    background = "transparent"
    fixed_frame_size = $true
    baseline_y = $baselineY
    facing = "right"
    notes = @(
        "five independent head modules for the first boss"
        "shared ancient stone judgement mechanism art direction"
        "no pillar body, no arena art, no combined full boss sprite"
        "all strips use fixed 96x96 cells with transparent backgrounds"
        "heads are drawn facing right by default and can be mirrored in engine when needed"
    )
    heads = $allManifestHeads
}

Write-Utf8NoBom $manifestPath ($manifest | ConvertTo-Json -Depth 6)
Write-Utf8NoBom $readmePath ($readmeLines -join "`r`n")
