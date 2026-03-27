Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function V([double]$x, [double]$y) {
    [PSCustomObject]@{
        X = $x
        Y = $y
    }
}

function Frame(
    [double]$cx, [double]$cy,
    [double]$px, [double]$py,
    [double]$hx, [double]$hy,
    [double]$fhx, [double]$fhy, [double]$fab,
    [double]$bhx, [double]$bhy, [double]$bab,
    [double]$ffx, [double]$ffy, [double]$flb,
    [double]$bfx, [double]$bfy, [double]$blb,
    [double]$wtx, [double]$wty,
    [bool]$eye = $true
) {
    [PSCustomObject]@{
        chest = V $cx $cy
        pelvis = V $px $py
        head = V $hx $hy
        front_hand = V $fhx $fhy
        front_arm_bend = $fab
        back_hand = V $bhx $bhy
        back_arm_bend = $bab
        front_foot = V $ffx $ffy
        front_leg_bend = $flb
        back_foot = V $bfx $bfy
        back_leg_bend = $blb
        weapon_tip = V $wtx $wty
        eye = $eye
    }
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
function PerpRight($a) { V (-$a.Y) $a.X }
function MidVec($a, $b) { V (($a.X + $b.X) / 2.0) (($a.Y + $b.Y) / 2.0) }

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

function DrawPixel($graphics, [System.Drawing.Color]$color, [double]$x, [double]$y) {
    FillRect2D $graphics $color $x $y 1 1
}

function DrawCapsuleSegment($graphics, $a, $b, [double]$thickness, [System.Drawing.Color]$fillColor, [System.Drawing.Color]$outlineColor) {
    $direction = SubVec $b $a
    $length = LenVec $direction
    if ($length -lt 0.01) {
        FillEllipse2D $graphics $fillColor $outlineColor ($a.X - ($thickness / 2.0)) ($a.Y - ($thickness / 2.0)) $thickness $thickness
        return
    }

    $normal = PerpRight (NormalizeVec $direction)
    $half = $thickness / 2.0
    $outlineHalf = $half + 1.0

    $outlinePoints = @(
        (AddVec $a (MulVec $normal $outlineHalf))
        (AddVec $b (MulVec $normal $outlineHalf))
        (AddVec $b (MulVec $normal (-$outlineHalf)))
        (AddVec $a (MulVec $normal (-$outlineHalf)))
    )
    FillPolygon2D $graphics $outlineColor $outlineColor $outlinePoints
    FillEllipse2D $graphics $outlineColor $outlineColor ($a.X - $outlineHalf) ($a.Y - $outlineHalf) ($outlineHalf * 2.0) ($outlineHalf * 2.0)
    FillEllipse2D $graphics $outlineColor $outlineColor ($b.X - $outlineHalf) ($b.Y - $outlineHalf) ($outlineHalf * 2.0) ($outlineHalf * 2.0)

    $innerPoints = @(
        (AddVec $a (MulVec $normal $half))
        (AddVec $b (MulVec $normal $half))
        (AddVec $b (MulVec $normal (-$half)))
        (AddVec $a (MulVec $normal (-$half)))
    )
    FillPolygon2D $graphics $fillColor $fillColor $innerPoints
    FillEllipse2D $graphics $fillColor $fillColor ($a.X - $half) ($a.Y - $half) ($half * 2.0) ($half * 2.0)
    FillEllipse2D $graphics $fillColor $fillColor ($b.X - $half) ($b.Y - $half) ($half * 2.0) ($half * 2.0)
}

function BendPoint($root, $target, [double]$bend) {
    $mid = MidVec $root $target
    $dir = SubVec $target $root
    $normal = PerpRight (NormalizeVec $dir)
    AddVec $mid (MulVec $normal $bend)
}

function DrawLeg($graphics, $hip, $foot, [double]$bend, [double]$thickness, [System.Drawing.Color]$legColor, [System.Drawing.Color]$bootColor, [System.Drawing.Color]$outlineColor) {
    $knee = BendPoint $hip $foot $bend
    DrawCapsuleSegment $graphics $hip $knee ($thickness + 0.2) $legColor $outlineColor
    DrawCapsuleSegment $graphics $knee $foot $thickness $legColor $outlineColor
    FillEllipse2D $graphics $bootColor $outlineColor ($foot.X - 3.4) ($foot.Y - 2.2) 7.0 4.0
}

function DrawArm($graphics, $shoulder, $hand, [double]$bend, [double]$thickness, [System.Drawing.Color]$armColor, [System.Drawing.Color]$gloveColor, [System.Drawing.Color]$outlineColor) {
    $elbow = BendPoint $shoulder $hand $bend
    DrawCapsuleSegment $graphics $shoulder $elbow ($thickness + 0.2) $armColor $outlineColor
    DrawCapsuleSegment $graphics $elbow $hand $thickness $armColor $outlineColor
    FillEllipse2D $graphics $gloveColor $outlineColor ($hand.X - 1.9) ($hand.Y - 1.9) 3.8 3.8
}

function DrawSpear($graphics, $hand, $tip, [System.Drawing.Color]$shaftColor, [System.Drawing.Color]$metalColor, [System.Drawing.Color]$metalDark, [System.Drawing.Color]$outlineColor) {
    $dir = NormalizeVec (SubVec $tip $hand)
    $shaftStart = AddVec $hand (MulVec $dir -10.0)
    $headBase = AddVec $tip (MulVec $dir -4.0)
    DrawCapsuleSegment $graphics $shaftStart $headBase 2.0 $shaftColor $outlineColor

    $normal = PerpRight $dir
    $headPoints = @(
        (AddVec $headBase (MulVec $normal 1.5))
        (AddVec $tip (MulVec $normal 0.0))
        (AddVec $headBase (MulVec $normal -1.5))
        (AddVec $headBase (MulVec $dir -1.0))
    )
    FillPolygon2D $graphics $metalColor $outlineColor $headPoints

    $spinePoints = @(
        (AddVec $headBase (MulVec $normal 0.3))
        (AddVec $tip (MulVec $normal 0.0))
        (AddVec $headBase (MulVec $normal -0.4))
        (AddVec $headBase (MulVec $dir -0.8))
    )
    FillPolygon2D $graphics $metalDark $metalDark $spinePoints

    $butt = AddVec $shaftStart (MulVec $dir -1.0)
    FillEllipse2D $graphics $metalDark $outlineColor ($butt.X - 0.8) ($butt.Y - 0.8) 1.6 1.6
}

function DrawBody($graphics, $pose, $palette) {
    $axis = NormalizeVec (SubVec $pose.chest $pose.pelvis)
    $right = PerpRight $axis

    $frontShoulder = AddVec $pose.chest (AddVec (MulVec $axis 0.8) (MulVec $right 2.6))
    $backShoulder = AddVec $pose.chest (AddVec (MulVec $axis 0.3) (MulVec $right -2.0))
    $frontHip = AddVec $pose.pelvis (MulVec $right 1.5)
    $backHip = AddVec $pose.pelvis (MulVec $right -1.4)

    DrawLeg $graphics $backHip $pose.back_foot $pose.back_leg_bend 3.6 $palette.leg_back $palette.boot_back $palette.outline
    DrawArm $graphics $backShoulder $pose.back_hand $pose.back_arm_bend 3.1 $palette.arm_back $palette.glove_back $palette.outline

    $torsoTop = $pose.chest
    $torsoBottom = $pose.pelvis
    $torsoPoints = @(
        (AddVec $torsoTop (MulVec $right 3.7))
        (AddVec $torsoTop (MulVec $right -3.2))
        (AddVec $torsoBottom (MulVec $right -3.0))
        (AddVec $torsoBottom (MulVec $right 3.1))
    )
    FillPolygon2D $graphics $palette.cloth_main $palette.outline $torsoPoints

    $vestPoints = @(
        (AddVec $torsoTop (AddVec (MulVec $right 1.8) (MulVec $axis 0.8)))
        (AddVec $torsoTop (AddVec (MulVec $right -1.3) (MulVec $axis 0.6)))
        (AddVec $torsoBottom (AddVec (MulVec $right -1.2) (MulVec $axis -0.5)))
        (AddVec $torsoBottom (AddVec (MulVec $right 1.7) (MulVec $axis -0.3)))
    )
    FillPolygon2D $graphics $palette.leather_main $palette.outline $vestPoints

    $capePoints = @(
        (AddVec $backShoulder (MulVec $right -1.0))
        (AddVec $backShoulder (AddVec (MulVec $right -3.0) (MulVec $axis 1.0)))
        (AddVec $pose.pelvis (AddVec (MulVec $right -2.7) (MulVec $axis -1.2)))
        (AddVec $pose.pelvis (AddVec (MulVec $right -1.0) (MulVec $axis -0.3)))
    )
    FillPolygon2D $graphics $palette.cape_main $palette.outline $capePoints

    $padCenter = AddVec $frontShoulder (MulVec $right 1.1)
    FillEllipse2D $graphics $palette.pad_main $palette.outline ($padCenter.X - 2.5) ($padCenter.Y - 1.8) 5.0 3.6

    FillRect2D $graphics $palette.belt ($pose.pelvis.X - 4.0) ($pose.pelvis.Y - 1.8) 8.0 2.0
    $clothPoints = @(
        (AddVec $pose.pelvis (MulVec $right 0.4))
        (AddVec $pose.pelvis (MulVec $right -0.6))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -1.2) (MulVec $right -0.2)))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -4.2) (MulVec $right 1.0)))
    )
    FillPolygon2D $graphics $palette.accent_red $palette.outline $clothPoints

    $hoodX = $pose.head.X
    $hoodY = $pose.head.Y
    $hoodPoints = @(
        (V ($hoodX - 4.2) ($hoodY - 1.0))
        (V ($hoodX - 2.8) ($hoodY - 5.1))
        (V ($hoodX + 1.5) ($hoodY - 6.5))
        (V ($hoodX + 4.8) ($hoodY - 3.0))
        (V ($hoodX + 4.2) ($hoodY + 1.5))
        (V ($hoodX + 1.2) ($hoodY + 4.6))
        (V ($hoodX - 2.4) ($hoodY + 4.0))
        (V ($hoodX - 4.8) ($hoodY + 1.0))
    )
    FillPolygon2D $graphics $palette.hood_main $palette.outline $hoodPoints

    $faceShadowPoints = @(
        (V ($hoodX - 1.5) ($hoodY - 2.7))
        (V ($hoodX + 2.7) ($hoodY - 2.4))
        (V ($hoodX + 2.9) ($hoodY + 1.0))
        (V ($hoodX + 0.5) ($hoodY + 2.8))
        (V ($hoodX - 1.8) ($hoodY + 1.5))
    )
    FillPolygon2D $graphics $palette.face_shadow $palette.face_shadow $faceShadowPoints

    if ($pose.eye) {
        DrawPixel $graphics $palette.eye ($hoodX + 0.8) ($hoodY - 0.2)
        DrawPixel $graphics $palette.eye_glow ($hoodX + 1.8) ($hoodY - 0.2)
    }

    DrawLeg $graphics $frontHip $pose.front_foot $pose.front_leg_bend 3.8 $palette.leg_front $palette.boot_front $palette.outline
    DrawArm $graphics $frontShoulder $pose.front_hand $pose.front_arm_bend 3.1 $palette.arm_front $palette.glove_front $palette.outline
    DrawSpear $graphics $pose.front_hand $pose.weapon_tip $palette.shaft_main $palette.metal_main $palette.metal_dark $palette.outline
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

function Write-Utf8NoBom([string]$path, [string]$content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

$frameWidth = 48
$frameHeight = 48
$baselineY = 41

$palette = @{
    outline = HexColor "#120f12"
    hood_main = HexColor "#2f3840"
    face_shadow = HexColor "#1a1719"
    cloth_main = HexColor "#4d5960"
    leather_main = HexColor "#4f453d"
    cape_main = HexColor "#3a4348"
    pad_main = HexColor "#676c72"
    belt = HexColor "#352823"
    accent_red = HexColor "#5f3037"
    arm_back = HexColor "#424b52"
    arm_front = HexColor "#556269"
    glove_back = HexColor "#72675e"
    glove_front = HexColor "#82766d"
    leg_back = HexColor "#43494e"
    leg_front = HexColor "#556067"
    boot_back = HexColor "#262126"
    boot_front = HexColor "#31292d"
    shaft_main = HexColor "#5d4b3d"
    metal_main = HexColor "#9aa0a5"
    metal_dark = HexColor "#686f77"
    eye = HexColor "#e6edf4"
    eye_glow = HexColor "#b5cce0"
}

$animations = @(
    @{
        name = "idle"
        fps = 5
        loop = $true
        frames = @(
            (Frame 24 22 21 33 27 16 30 28 -0.8 19 29 0.5 27 41 2.8 20 41 -2.1 44 28)
            (Frame 24.5 21.5 21 32.5 27.5 15.5 31 27 -0.9 19 28 0.5 27 41 2.6 21 41 -1.8 45 27.5)
            (Frame 23.5 23 20.5 34 26.5 17 29 29 -1.0 18.5 30 0.4 26 41 3.0 20 41 -2.4 43 29.5)
            (Frame 24 22.5 21 33 27 16.3 30 28 -0.7 19.5 29 0.5 27 41 2.8 21 41 -1.8 44 28.5)
        )
    }
    @{
        name = "move"
        fps = 9
        loop = $true
        frames = @(
            (Frame 23.5 23 20.5 34 26.5 17 30 29 -0.8 18.5 30 0.4 28 41 3.8 20 41 -2.7 43 29)
            (Frame 24 22 21 33 27 16 31 28 -0.7 19.5 29 0.5 28 41 2.6 21 41 -1.9 44 28)
            (Frame 25 22 22 33 28 16 32 28 -0.6 21 29 0.5 27 41 2.0 23 41 -1.0 45 28)
            (Frame 24.8 22.3 21.8 33 27.8 16.2 32 28 -0.6 21.3 29 0.5 26.5 41 1.7 24 41 -0.6 45 28)
            (Frame 24 23 21 34 27 17 31 29 -0.8 21 30 0.4 26 41 1.2 26.5 41 0.5 44 29)
            (Frame 23.5 22.2 20.5 33.2 26.5 16.4 30 28 -0.8 19.8 29 0.5 27 41 1.8 24 41 -0.9 43 28)
        )
    }
    @{
        name = "attack"
        fps = 11
        loop = $false
        frames = @(
            (Frame 24 22 21 33 27 16 30 28 -0.8 19 29 0.5 27 41 2.8 20 41 -2.1 44 28)
            (Frame 22.5 23 20.5 34 26 17 26 29 -2.0 18 30 0.7 27 41 3.8 20 41 -2.8 35 30)
            (Frame 21 24 19.5 34 25 18 22 29 -3.8 17.5 30 0.8 27 41 4.4 20 41 -3.1 28 31)
            (Frame 20.5 24.5 19 34.5 24.5 18.5 18 28 -5.2 17.5 30 0.8 27 41 4.8 20 41 -3.4 21 30)
            (Frame 22.5 23 20.5 33.5 25 17 28 27 -1.8 18.5 29 0.7 27 41 4.0 20 41 -2.8 38 27)
            (Frame 25 21.5 22 33 27 15.5 34 27 0.3 20.5 29 0.5 28 41 2.8 21 41 -2.0 47 26)
            (Frame 27.5 22 24.5 33.5 29 16 35.5 29 1.0 22 30 0.4 29 41 2.2 22 41 -1.5 47 29)
            (Frame 26.5 22.8 23.5 33.8 28 16.5 33 29 0.6 21.5 30 0.4 28 41 2.4 22 41 -1.6 45 30)
        )
    }
    @{
        name = "hit"
        fps = 9
        loop = $false
        frames = @(
            (Frame 22 21.5 19.5 32 24.5 15.5 33 27 0.6 17 27 -0.7 27 41 2.2 21 41 -1.4 43 27)
            (Frame 21 20.8 18.8 31 23.5 15 34 26.5 1.0 16 26 -1.1 26 41 1.5 21 41 -0.9 44 26)
            (Frame 23 22.2 20.5 33 25.5 16.2 31 28 -0.4 18 29 0.3 27 41 2.4 21 41 -1.4 43 28)
        )
    }
    @{
        name = "launch"
        fps = 8
        loop = $false
        frames = @(
            (Frame 26 21 20.5 29.5 29.5 16 33 22 1.1 18.5 23 -1.0 24 36 1.2 18 35 -1.2 42 21)
            (Frame 27 20.5 20 29 30 15.5 34 21 0.8 18 22 -0.8 25 35 1.0 17 34 -1.0 43 20)
        )
    }
    @{
        name = "down"
        fps = 6
        loop = $true
        frames = @(
            (Frame 21.5 34 28.5 36 18 33.5 33 36 0.4 24.5 39 -0.3 36 40 0.7 28.5 41 -0.6 38 37)
            (Frame 20.8 35 28 37 17.2 34.3 32 37 0.4 24.5 39 -0.2 35 40 0.6 28 41 -0.5 37 38)
        )
    }
    @{
        name = "get_up"
        fps = 8
        loop = $false
        frames = @(
            (Frame 20.8 35 28 37 17.2 34.3 32 37 0.4 24.5 39 -0.2 35 40 0.6 28 41 -0.5 37 38)
            (Frame 21 31.5 27 36 18 29.5 25 34 -1.1 21 37 0.3 33 40 1.2 28 41 -0.8 31 34)
            (Frame 22.5 28 24.5 35 21.5 23.5 29 31 -1.0 21 33 0.4 27 41 2.0 22 40 -1.4 37 31)
            (Frame 23.5 25 21.5 34 25.5 19 30 30 -0.8 19.5 31 0.4 26 41 2.5 21 41 -1.7 42 30)
            (Frame 24 22 21 33 27 16 30 28 -0.8 19 29 0.5 27 41 2.8 20 41 -2.1 44 28)
        )
    }
    @{
        name = "grabbed"
        fps = 6
        loop = $true
        frames = @(
            (Frame 24 22 21 33 27 16 27 25 -0.2 19 27 0.1 27 41 2.4 21 41 -1.6 35 24)
            (Frame 24 23 21 34 27 17 28 26 -0.2 20 28 0.1 27 41 2.5 21 41 -1.6 36 25)
        )
    }
    @{
        name = "death"
        fps = 8
        loop = $false
        frames = @(
            (Frame 22 22 19.5 33 24.5 16 33 28 0.6 17 28 -0.8 27 41 2.2 21 41 -1.6 42 28)
            (Frame 22.5 26 21 35 24 20.5 30 35 -0.2 18 33 0.3 26 41 2.8 20 41 -2.0 35 37)
            (Frame 20.5 31 27 36 17.5 29.5 33 36 0.5 22 37 -0.2 35 40 0.9 28 41 -0.7 37 37)
            (Frame 20 35 28 37.2 16.5 34 33 37 0.4 24 39 -0.1 36 40 0.6 28 41 -0.4 38 38)
        )
    }
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$artDir = $PSScriptRoot
$sceneDir = Join-Path $repoRoot "scenes\enemies"
$scenePath = Join-Path $sceneDir "dungeon_lancer_sprite.tscn"
$manifestPath = Join-Path $artDir "dungeon_lancer_manifest.json"
$previewPath = Join-Path $artDir "dungeon_lancer_preview_4x.png"
$readmePath = Join-Path $artDir "README.md"

New-Item -ItemType Directory -Force -Path $artDir | Out-Null
New-Item -ItemType Directory -Force -Path $sceneDir | Out-Null

$manifestAnimations = @()
$sheetMeta = @()

foreach ($animation in $animations) {
    $sheet = New-SheetBitmap ($frameWidth * $animation.frames.Count) $frameHeight
    for ($i = 0; $i -lt $animation.frames.Count; $i++) {
        $frameBitmap = New-SheetBitmap $frameWidth $frameHeight
        DrawBody $frameBitmap.Graphics $animation.frames[$i] $palette
        $sheet.Graphics.DrawImageUnscaled($frameBitmap.Bitmap, $i * $frameWidth, 0)
        $frameBitmap.Graphics.Dispose()
        $frameBitmap.Bitmap.Dispose()
    }

    $fileName = "dungeon_lancer_{0}_strip.png" -f $animation.name
    $filePath = Join-Path $artDir $fileName
    SavePng $sheet.Bitmap $filePath
    $sheet.Graphics.Dispose()
    $sheet.Bitmap.Dispose()

    $manifestAnimations += [PSCustomObject]@{
        name = $animation.name
        file = $fileName
        frames = $animation.frames.Count
        fps = $animation.fps
        loop = [bool]$animation.loop
    }

    $sheetMeta += [PSCustomObject]@{
        name = $animation.name
        file = $fileName
        path = "res://art/enemies/dungeon_lancer/$fileName"
        frames = $animation.frames.Count
        fps = $animation.fps
        loop = [bool]$animation.loop
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

$manifest = [PSCustomObject]@{
    name = "dungeon_lancer"
    display_name = "Dungeon Lancer"
    frame_width = $frameWidth
    frame_height = $frameHeight
    background = "transparent"
    fixed_frame_size = $true
    baseline_y = $baselineY
    facing = "right"
    notes = @(
        "all frames share a fixed 48x48 canvas"
        "transparent background"
        "designed for frame-by-frame 2D side-action enemy animation"
        "sprite sheets contain no overlapping frames"
        "thrust-focused silhouette with spear-forward poses"
    )
    animations = $manifestAnimations
}
Write-Utf8NoBom $manifestPath ($manifest | ConvertTo-Json -Depth 5)

$readmeLines = @(
    "# Dungeon Lancer"
    ""
    "- Display name: Dungeon Lancer"
    "- Frame size: 48x48"
    "- Background: transparent"
    "- Baseline: y = 41"
    "- Facing: right by default, mirror in engine for left"
    "- Delivery: one horizontal strip per animation, fixed cell size, no frame overlap"
    ""
    "Animations:"
)
$readmeLines += $manifestAnimations | ForEach-Object { "- {0}: {1} frames @ {2} fps" -f $_.name, $_.frames, $_.fps }
Write-Utf8NoBom $readmePath ($readmeLines -join "`r`n")

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
[sub_resource type="SpriteFrames" id="SpriteFrames_dungeon_lancer"]
animations = [$($animationBlocks -join ",`r`n")]

"@

$sceneText = @"
[gd_scene load_steps=$($sheetMeta.Count + $atlasIndex + 2) format=3]

$($extLines -join "`r`n")
$($subLines -join "`r`n")
$spriteFramesBlock
[node name="DungeonLancerSprite" type="Node2D"]

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
position = Vector2(0, 0)
sprite_frames = SubResource("SpriteFrames_dungeon_lancer")
animation = &"idle"
frame = 0
centered = true
"@

Write-Utf8NoBom $scenePath $sceneText
