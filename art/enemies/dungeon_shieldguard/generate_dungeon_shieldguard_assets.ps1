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
    [double]$scx, [double]$scy,
    [double]$sw, [double]$sh,
    [double]$sa,
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
        shield_center = V $scx $scy
        shield_width = $sw
        shield_height = $sh
        shield_angle = $sa
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
    FillEllipse2D $graphics $bootColor $outlineColor ($foot.X - 3.5) ($foot.Y - 2.3) 7.0 4.2
}

function DrawArm($graphics, $shoulder, $hand, [double]$bend, [double]$thickness, [System.Drawing.Color]$armColor, [System.Drawing.Color]$gloveColor, [System.Drawing.Color]$outlineColor) {
    $elbow = BendPoint $shoulder $hand $bend
    DrawCapsuleSegment $graphics $shoulder $elbow ($thickness + 0.1) $armColor $outlineColor
    DrawCapsuleSegment $graphics $elbow $hand $thickness $armColor $outlineColor
    FillEllipse2D $graphics $gloveColor $outlineColor ($hand.X - 2.0) ($hand.Y - 2.0) 4.0 4.0
}

function DrawClub($graphics, $hand, $tip, $palette) {
    $dir = NormalizeVec (SubVec $tip $hand)
    $normal = PerpRight $dir
    $handleStart = AddVec $hand (MulVec $dir -4.0)
    $headCenter = AddVec $tip (MulVec $dir -1.4)
    DrawCapsuleSegment $graphics $handleStart $headCenter 2.2 $palette.weapon_handle $palette.outline

    $headPoints = @(
        (AddVec $headCenter (MulVec $normal 2.6))
        (AddVec $tip (MulVec $normal 1.2))
        (AddVec $tip (MulVec $normal (-1.2)))
        (AddVec $headCenter (MulVec $normal (-2.6)))
        (AddVec $headCenter (MulVec $dir -1.8))
    )
    FillPolygon2D $graphics $palette.weapon_head $palette.outline $headPoints
}

function RotatePoint($center, [double]$angleDeg, [double]$x, [double]$y) {
    $rad = [Math]::PI * $angleDeg / 180.0
    $cos = [Math]::Cos($rad)
    $sin = [Math]::Sin($rad)
    V (
        $center.X + ($x * $cos) - ($y * $sin)
    ) (
        $center.Y + ($x * $sin) + ($y * $cos)
    )
}

function DrawShield($graphics, $center, [double]$width, [double]$height, [double]$angleDeg, $palette) {
    $halfW = $width / 2.0
    $halfH = $height / 2.0
    $points = @(
        (RotatePoint $center $angleDeg (-$halfW * 0.78) (-$halfH * 0.92))
        (RotatePoint $center $angleDeg ($halfW * 0.70) (-$halfH * 0.86))
        (RotatePoint $center $angleDeg ($halfW * 0.92) 0.0)
        (RotatePoint $center $angleDeg ($halfW * 0.62) ($halfH * 0.82))
        (RotatePoint $center $angleDeg 0.0 ($halfH * 1.08))
        (RotatePoint $center $angleDeg (-$halfW * 0.70) ($halfH * 0.80))
        (RotatePoint $center $angleDeg (-$halfW * 0.92) 0.0)
    )
    FillPolygon2D $graphics $palette.shield_main $palette.outline $points

    $innerPoints = @(
        (RotatePoint $center $angleDeg (-$halfW * 0.45) (-$halfH * 0.58))
        (RotatePoint $center $angleDeg ($halfW * 0.40) (-$halfH * 0.54))
        (RotatePoint $center $angleDeg ($halfW * 0.54) 0.0)
        (RotatePoint $center $angleDeg ($halfW * 0.36) ($halfH * 0.54))
        (RotatePoint $center $angleDeg 0.0 ($halfH * 0.72))
        (RotatePoint $center $angleDeg (-$halfW * 0.42) ($halfH * 0.52))
        (RotatePoint $center $angleDeg (-$halfW * 0.56) 0.0)
    )
    FillPolygon2D $graphics $palette.shield_inner $palette.shield_inner $innerPoints

    $bossW = [Math]::Max(2.8, $width * 0.18)
    $bossH = [Math]::Max(2.8, $height * 0.16)
    FillEllipse2D $graphics $palette.shield_boss $palette.outline ($center.X - ($bossW / 2.0)) ($center.Y - ($bossH / 2.0)) $bossW $bossH
}

function DrawBody($graphics, $pose, $palette) {
    $axis = NormalizeVec (SubVec $pose.chest $pose.pelvis)
    $right = PerpRight $axis

    $frontShoulder = AddVec $pose.chest (AddVec (MulVec $axis 0.9) (MulVec $right 2.6))
    $backShoulder = AddVec $pose.chest (AddVec (MulVec $axis 0.3) (MulVec $right -2.0))
    $frontHip = AddVec $pose.pelvis (MulVec $right 1.8)
    $backHip = AddVec $pose.pelvis (MulVec $right -1.6)

    DrawLeg $graphics $backHip $pose.back_foot $pose.back_leg_bend 4.2 $palette.leg_back $palette.boot_back $palette.outline
    DrawArm $graphics $backShoulder $pose.back_hand $pose.back_arm_bend 3.4 $palette.arm_back $palette.glove_back $palette.outline

    $torsoPoints = @(
        (AddVec $pose.chest (MulVec $right 4.4))
        (AddVec $pose.chest (MulVec $right -3.8))
        (AddVec $pose.pelvis (MulVec $right -3.4))
        (AddVec $pose.pelvis (MulVec $right 3.9))
    )
    FillPolygon2D $graphics $palette.cloth_main $palette.outline $torsoPoints

    $platePoints = @(
        (AddVec $pose.chest (AddVec (MulVec $right 2.0) (MulVec $axis 0.9)))
        (AddVec $pose.chest (AddVec (MulVec $right -1.3) (MulVec $axis 0.7)))
        (AddVec $pose.pelvis (AddVec (MulVec $right -1.2) (MulVec $axis -0.6)))
        (AddVec $pose.pelvis (AddVec (MulVec $right 1.9) (MulVec $axis -0.4)))
    )
    FillPolygon2D $graphics $palette.plate_main $palette.outline $platePoints

    $padCenter = AddVec $frontShoulder (MulVec $right 1.0)
    FillEllipse2D $graphics $palette.pad_main $palette.outline ($padCenter.X - 2.7) ($padCenter.Y - 1.7) 5.4 3.6

    FillRect2D $graphics $palette.belt ($pose.pelvis.X - 4.2) ($pose.pelvis.Y - 1.9) 8.4 2.1
    $clothPoints = @(
        (AddVec $pose.pelvis (MulVec $right 0.7))
        (AddVec $pose.pelvis (MulVec $right -0.8))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -1.2) (MulVec $right -0.3)))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -4.4) (MulVec $right 1.0)))
    )
    FillPolygon2D $graphics $palette.accent_red $palette.outline $clothPoints

    $hoodX = $pose.head.X
    $hoodY = $pose.head.Y
    $hoodPoints = @(
        (V ($hoodX - 4.4) ($hoodY - 1.2))
        (V ($hoodX - 3.0) ($hoodY - 5.0))
        (V ($hoodX + 1.4) ($hoodY - 6.2))
        (V ($hoodX + 4.8) ($hoodY - 2.4))
        (V ($hoodX + 4.2) ($hoodY + 2.0))
        (V ($hoodX + 1.4) ($hoodY + 4.7))
        (V ($hoodX - 2.4) ($hoodY + 4.2))
        (V ($hoodX - 5.0) ($hoodY + 1.0))
    )
    FillPolygon2D $graphics $palette.hood_main $palette.outline $hoodPoints

    $faceShadowPoints = @(
        (V ($hoodX - 1.4) ($hoodY - 2.5))
        (V ($hoodX + 2.8) ($hoodY - 2.2))
        (V ($hoodX + 3.0) ($hoodY + 1.4))
        (V ($hoodX + 0.2) ($hoodY + 2.8))
        (V ($hoodX - 1.8) ($hoodY + 1.5))
    )
    FillPolygon2D $graphics $palette.face_shadow $palette.face_shadow $faceShadowPoints

    if ($pose.eye) {
        DrawPixel $graphics $palette.eye ($hoodX + 0.7) ($hoodY - 0.2)
        DrawPixel $graphics $palette.eye_glow ($hoodX + 1.7) ($hoodY - 0.2)
    }

    DrawLeg $graphics $frontHip $pose.front_foot $pose.front_leg_bend 4.4 $palette.leg_front $palette.boot_front $palette.outline
    DrawArm $graphics $frontShoulder $pose.front_hand $pose.front_arm_bend 3.5 $palette.arm_front $palette.glove_front $palette.outline
    DrawClub $graphics $pose.front_hand $pose.weapon_tip $palette
    DrawShield $graphics $pose.shield_center $pose.shield_width $pose.shield_height $pose.shield_angle $palette
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
    outline = HexColor "#141113"
    hood_main = HexColor "#3d4338"
    face_shadow = HexColor "#1c1818"
    cloth_main = HexColor "#5a604d"
    plate_main = HexColor "#696e73"
    pad_main = HexColor "#72755f"
    belt = HexColor "#403127"
    accent_red = HexColor "#643338"
    arm_back = HexColor "#4c5046"
    arm_front = HexColor "#5e6458"
    glove_back = HexColor "#7a6e61"
    glove_front = HexColor "#8b7d70"
    leg_back = HexColor "#4d5148"
    leg_front = HexColor "#5f655a"
    boot_back = HexColor "#2a2424"
    boot_front = HexColor "#352d2d"
    shield_main = HexColor "#5b4d3e"
    shield_inner = HexColor "#786654"
    shield_boss = HexColor "#8b9298"
    weapon_handle = HexColor "#5b4532"
    weapon_head = HexColor "#7c7f84"
    eye = HexColor "#e6edf4"
    eye_glow = HexColor "#b5cce0"
}

$animations = @(
    @{
        name = "idle"
        fps = 5
        loop = $true
        frames = @(
            (Frame 22.5 23.5 21 33.5 24.5 17 31 28 -0.4 18 27 0.4 27 41 2.0 19 41 -1.6 35 28 29 27.5 14 18 -6)
            (Frame 22.8 23.0 21.2 33.2 24.8 16.5 31.3 27.6 -0.4 18.2 27.0 0.4 27 41 1.9 19.5 41 -1.4 35.4 27.8 29.2 27.2 14 18 -5)
            (Frame 22.0 24.0 20.6 34.2 24.0 17.5 30.7 28.3 -0.5 17.8 27.5 0.3 26.5 41 2.2 19 41 -1.8 34.6 28.3 28.8 27.9 14 18 -7)
            (Frame 22.4 23.6 21.0 33.6 24.4 17.2 31.0 27.9 -0.4 18.0 27.2 0.4 27 41 2.0 19.4 41 -1.5 35.0 28.0 29.0 27.5 14 18 -6)
        )
    }
    @{
        name = "move"
        fps = 7
        loop = $true
        frames = @(
            (Frame 22.0 24.0 20.6 34.2 24.0 17.5 30.8 28.4 -0.5 17.4 27.6 0.4 28.0 41 2.8 18.6 41 -2.1 34.2 28.6 28.6 27.8 14 18 -8)
            (Frame 22.4 23.4 21.0 33.6 24.4 17.0 31.2 28.0 -0.4 18.0 27.2 0.4 28.5 41 2.2 19.1 41 -1.7 34.8 28.1 29.0 27.4 14 18 -7)
            (Frame 23.0 23.0 21.6 33.2 25.0 16.6 31.8 27.7 -0.3 18.8 27.0 0.4 27.8 41 1.8 20.4 41 -1.1 35.5 27.8 29.6 27.0 14 18 -6)
            (Frame 22.8 23.2 21.5 33.4 24.8 16.8 31.7 27.8 -0.3 19.4 27.2 0.3 27.0 41 1.4 22.0 41 -0.4 35.8 27.9 29.8 27.1 14 18 -5)
            (Frame 22.2 24.0 20.8 34.0 24.2 17.4 31.0 28.4 -0.4 19.0 27.8 0.3 26.2 41 1.2 24.0 41 0.2 35.0 28.5 29.2 27.9 14 18 -6)
            (Frame 22.0 23.6 20.8 33.8 24.2 17.1 30.8 28.1 -0.4 18.2 27.4 0.4 26.6 41 1.7 22.2 41 -0.3 34.6 28.2 28.9 27.6 14 18 -7)
        )
    }
    @{
        name = "guard"
        fps = 6
        loop = $true
        frames = @(
            (Frame 21.8 23.0 20.4 33.4 23.6 16.8 31.0 29.0 -0.2 18.0 26.8 0.3 26.8 41 1.8 19.0 41 -1.4 32.8 29.0 27.8 27.8 16 20 -10)
            (Frame 21.6 22.8 20.2 33.2 23.4 16.6 31.0 29.2 -0.2 17.8 26.9 0.3 26.6 41 1.7 18.8 41 -1.3 32.5 29.3 27.5 28.0 16 20 -11)
        )
    }
    @{
        name = "attack"
        fps = 10
        loop = $false
        frames = @(
            (Frame 22.0 23.5 20.8 33.6 24.0 17.1 30.6 28.0 -0.3 18.0 27.0 0.4 27.0 41 2.0 19.0 41 -1.5 33.0 28.0 29.5 27.6 14 18 -8)
            (Frame 21.4 24.2 20.2 34.0 23.3 17.9 27.0 26.0 -2.0 17.8 27.0 0.2 27.0 41 2.5 19.0 41 -1.8 29.0 25.5 31.0 27.0 15 19 -10)
            (Frame 21.6 24.0 20.8 33.8 23.8 17.6 30.0 25.2 -0.8 18.0 27.1 0.2 28.2 41 2.2 19.4 41 -1.6 31.0 24.8 35.2 26.8 17 21 -5)
            (Frame 22.6 23.4 21.6 33.2 24.8 16.9 32.5 25.7 -0.4 18.7 27.3 0.2 29.5 41 1.9 20.4 41 -1.2 33.0 25.2 40.5 26.6 18 22 -2)
            (Frame 23.4 22.9 22.2 32.8 25.5 16.5 34.2 26.4 0.1 19.6 27.8 0.3 30.2 41 1.5 21.2 41 -0.9 34.2 26.0 42.5 26.6 18 22 0)
            (Frame 22.8 23.3 21.6 33.1 24.9 16.8 32.4 27.2 -0.1 18.9 27.5 0.3 28.8 41 1.7 20.3 41 -1.1 33.0 26.9 37.8 27.0 16 20 -3)
            (Frame 22.3 23.6 21.0 33.5 24.4 17.1 31.2 27.9 -0.3 18.3 27.3 0.4 27.6 41 1.9 19.5 41 -1.4 32.6 27.8 34.5 27.4 14 18 -6)
        )
    }
    @{
        name = "hit"
        fps = 8
        loop = $false
        frames = @(
            (Frame 21.0 22.5 19.8 32.0 22.8 16.3 32.5 27.0 0.6 17.0 26.0 -0.6 26.5 41 1.6 19.0 41 -1.0 35.5 27.2 28.2 27.0 13 17 -3)
            (Frame 20.2 21.8 19.0 31.4 22.0 15.8 33.2 26.2 0.9 16.4 25.2 -0.9 25.8 41 1.2 19.2 41 -0.6 36.2 26.4 28.0 26.5 13 17 -2)
            (Frame 21.6 23.0 20.2 32.8 23.4 16.6 31.4 27.2 0.2 17.6 26.5 -0.3 26.6 41 1.7 19.4 41 -1.1 35.4 27.4 28.6 27.1 13 17 -4)
        )
    }
    @{
        name = "launch"
        fps = 8
        loop = $false
        frames = @(
            (Frame 25.5 21.2 20.2 30.0 29.0 16.0 31.0 22.0 1.0 19.0 23.0 -0.8 24.0 36.0 1.1 18.0 35.0 -1.0 37.0 21.0 28.0 24.0 13 17 -2)
            (Frame 26.2 20.7 19.8 29.4 29.6 15.4 32.0 21.2 0.8 18.4 22.2 -0.7 25.0 35.2 0.9 17.0 34.0 -0.8 38.0 20.2 28.4 23.6 13 17 -1)
        )
    }
    @{
        name = "down"
        fps = 6
        loop = $true
        frames = @(
            (Frame 21.6 34.0 28.5 36.0 18.2 33.5 31.5 36.0 0.4 24.5 39.0 -0.2 36.0 40.0 0.7 28.5 41.0 -0.5 33.0 37.0 27.0 35.0 13 17 8 $false)
            (Frame 21.0 35.0 28.0 37.0 17.4 34.2 31.0 37.0 0.4 24.2 39.0 -0.1 35.0 40.0 0.6 28.0 41.0 -0.4 32.5 38.0 26.5 35.5 13 17 9 $false)
        )
    }
    @{
        name = "get_up"
        fps = 8
        loop = $false
        frames = @(
            (Frame 21.0 35.0 28.0 37.0 17.4 34.2 31.0 37.0 0.4 24.2 39.0 -0.1 35.0 40.0 0.6 28.0 41.0 -0.4 32.5 38.0 26.5 35.5 13 17 9 $false)
            (Frame 21.0 31.2 27.2 36.0 18.2 29.4 26.0 34.0 -1.2 21.0 37.0 0.2 33.0 40.0 1.1 28.0 41.0 -0.8 28.5 34.5 25.5 31.5 13 17 5)
            (Frame 21.8 28.0 24.6 35.2 21.8 23.5 28.8 31.2 -1.0 20.5 33.0 0.3 27.4 41.0 1.9 22.2 40.0 -1.4 32.0 31.5 27.0 29.5 13 17 1)
            (Frame 22.2 25.0 22.0 34.0 23.8 19.0 30.5 29.8 -0.6 19.2 30.5 0.4 26.8 41.0 2.2 20.4 41.0 -1.7 34.0 29.5 28.4 28.5 14 18 -3)
            (Frame 22.5 23.5 21.0 33.5 24.5 17.0 31.0 28.0 -0.4 18.0 27.0 0.4 27.0 41.0 2.0 19.0 41.0 -1.6 35.0 28.0 29.0 27.5 14 18 -6)
        )
    }
    @{
        name = "grabbed"
        fps = 6
        loop = $true
        frames = @(
            (Frame 22.8 23.0 21.0 33.4 24.8 16.8 28.0 25.4 -0.2 18.4 25.8 0.1 27.0 41.0 1.9 19.2 41.0 -1.3 31.0 25.5 27.6 26.5 13 17 -3)
            (Frame 22.8 23.8 21.0 34.2 24.8 17.6 28.8 26.2 -0.1 18.8 26.4 0.1 27.0 41.0 2.0 19.2 41.0 -1.3 31.8 26.5 27.8 27.0 13 17 -3)
        )
    }
    @{
        name = "death"
        fps = 8
        loop = $false
        frames = @(
            (Frame 21.2 22.6 20.0 32.6 23.0 16.2 32.0 27.2 0.6 17.2 26.4 -0.5 26.6 41.0 1.7 19.1 41.0 -1.1 35.8 27.3 28.3 27.2 13 17 -2)
            (Frame 21.8 27.0 21.0 35.0 23.0 21.0 29.0 34.8 0.0 18.8 33.0 0.2 26.0 41.0 2.5 20.0 41.0 -1.8 31.8 35.0 27.0 33.0 13 17 4 $false)
            (Frame 20.8 31.0 27.2 36.0 18.2 29.5 31.5 36.0 0.4 22.5 37.0 -0.1 35.0 40.0 0.9 28.2 41.0 -0.7 33.0 37.0 26.8 35.0 13 17 8 $false)
            (Frame 20.2 35.0 28.0 37.2 16.8 34.0 31.0 37.0 0.3 24.0 39.0 -0.1 36.0 40.0 0.6 28.0 41.0 -0.4 32.5 38.0 26.5 35.5 13 17 9 $false)
        )
    }
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$artDir = $PSScriptRoot
$sceneDir = Join-Path $repoRoot "scenes\enemies"
$scenePath = Join-Path $sceneDir "dungeon_shieldguard_sprite.tscn"
$manifestPath = Join-Path $artDir "dungeon_shieldguard_manifest.json"
$previewPath = Join-Path $artDir "dungeon_shieldguard_preview_4x.png"
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

    $fileName = "dungeon_shieldguard_{0}_strip.png" -f $animation.name
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
        path = "res://art/enemies/dungeon_shieldguard/$fileName"
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
    name = "dungeon_shieldguard"
    display_name = "Dungeon Shieldguard"
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
        "shield-forward silhouette with explicit guard posture"
    )
    animations = $manifestAnimations
}
Write-Utf8NoBom $manifestPath ($manifest | ConvertTo-Json -Depth 5)

$readmeLines = @(
    "# Dungeon Shieldguard"
    ""
    "- Display name: Dungeon Shieldguard"
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
[sub_resource type="SpriteFrames" id="SpriteFrames_dungeon_shieldguard"]
animations = [$($animationBlocks -join ",`r`n")]

"@

$sceneText = @"
[gd_scene load_steps=$($sheetMeta.Count + $atlasIndex + 2) format=3]

$($extLines -join "`r`n")
$($subLines -join "`r`n")
$spriteFramesBlock
[node name="DungeonShieldguardSprite" type="Node2D"]

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
position = Vector2(0, 0)
sprite_frames = SubResource("SpriteFrames_dungeon_shieldguard")
animation = &"idle"
frame = 0
centered = true
"@

Write-Utf8NoBom $scenePath $sceneText
