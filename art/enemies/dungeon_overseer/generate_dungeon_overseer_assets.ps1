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
    DrawCapsuleSegment $graphics $hip $knee ($thickness + 0.4) $legColor $outlineColor
    DrawCapsuleSegment $graphics $knee $foot $thickness $legColor $outlineColor
    FillEllipse2D $graphics $bootColor $outlineColor ($foot.X - 5.2) ($foot.Y - 3.0) 10.4 5.4
}

function DrawArm($graphics, $shoulder, $hand, [double]$bend, [double]$thickness, [System.Drawing.Color]$armColor, [System.Drawing.Color]$gloveColor, [System.Drawing.Color]$outlineColor) {
    $elbow = BendPoint $shoulder $hand $bend
    DrawCapsuleSegment $graphics $shoulder $elbow ($thickness + 0.2) $armColor $outlineColor
    DrawCapsuleSegment $graphics $elbow $hand $thickness $armColor $outlineColor
    $elbowPad = MidVec $shoulder $elbow
    $forearmBand = MidVec $elbow $hand
    FillEllipse2D $graphics $gloveColor $outlineColor ($elbowPad.X - 2.8) ($elbowPad.Y - 2.6) 5.6 5.2
    FillEllipse2D $graphics $gloveColor $outlineColor ($forearmBand.X - 2.2) ($forearmBand.Y - 2.0) 4.4 4.0
    FillEllipse2D $graphics $gloveColor $outlineColor ($hand.X - 2.8) ($hand.Y - 2.8) 5.6 5.6
}

function DrawGreataxe($graphics, $backHand, $frontHand, $tip, $palette) {
    $dir = NormalizeVec (SubVec $tip $frontHand)
    $normal = PerpRight $dir

    $shaftBack = AddVec $backHand (MulVec $dir -15.0)
    $shaftFront = AddVec $tip (MulVec $dir -7.6)
    DrawCapsuleSegment $graphics $shaftBack $shaftFront 3.9 $palette.shaft_main $palette.outline

    $gripCenter = MidVec $backHand $frontHand
    FillEllipse2D $graphics $palette.wrap_main $palette.outline ($gripCenter.X - 2.8) ($gripCenter.Y - 2.8) 5.6 5.6

    $headBase = AddVec $tip (MulVec $dir -7.2)
    $bladePoints = @(
        (AddVec $headBase (AddVec (MulVec $normal 12.8) (MulVec $dir -4.8)))
        (AddVec $tip (MulVec $normal 8.0))
        (AddVec $tip (MulVec $normal 1.8))
        (AddVec $tip (MulVec $normal (-6.8)))
        (AddVec $headBase (AddVec (MulVec $normal -3.0) (MulVec $dir 3.8)))
        (AddVec $headBase (AddVec (MulVec $normal 5.2) (MulVec $dir 7.0)))
    )
    FillPolygon2D $graphics $palette.blade_main $palette.outline $bladePoints

    $spikePoints = @(
        (AddVec $headBase (MulVec $normal -2.8))
        (AddVec $headBase (MulVec $dir -11.4))
        (AddVec $headBase (MulVec $normal 2.8))
    )
    FillPolygon2D $graphics $palette.blade_dark $palette.outline $spikePoints

    FillEllipse2D $graphics $palette.blade_light $palette.outline ($headBase.X - 2.5) ($headBase.Y - 2.5) 5.0 5.0
}

function DrawBody($graphics, $pose, $palette) {
    $axis = NormalizeVec (SubVec $pose.chest $pose.pelvis)
    $right = PerpRight $axis

    $frontShoulder = AddVec $pose.chest (AddVec (MulVec $axis 1.0) (MulVec $right 4.0))
    $backShoulder = AddVec $pose.chest (AddVec (MulVec $axis 0.4) (MulVec $right -3.4))
    $frontHip = AddVec $pose.pelvis (MulVec $right 2.7)
    $backHip = AddVec $pose.pelvis (MulVec $right -2.4)

    DrawLeg $graphics $backHip $pose.back_foot $pose.back_leg_bend 6.0 $palette.leg_back $palette.boot_back $palette.outline
    DrawArm $graphics $backShoulder $pose.back_hand $pose.back_arm_bend 5.4 $palette.arm_back $palette.glove_back $palette.outline

    $torsoPoints = @(
        (AddVec $pose.chest (MulVec $right 6.8))
        (AddVec $pose.chest (MulVec $right -6.0))
        (AddVec $pose.pelvis (MulVec $right -5.5))
        (AddVec $pose.pelvis (MulVec $right 6.1))
    )
    FillPolygon2D $graphics $palette.tunic_main $palette.outline $torsoPoints

    $platePoints = @(
        (AddVec $pose.chest (AddVec (MulVec $right 3.2) (MulVec $axis 1.6)))
        (AddVec $pose.chest (AddVec (MulVec $right -2.4) (MulVec $axis 1.2)))
        (AddVec $pose.pelvis (AddVec (MulVec $right -2.0) (MulVec $axis -0.9)))
        (AddVec $pose.pelvis (AddVec (MulVec $right 3.0) (MulVec $axis -0.6)))
    )
    FillPolygon2D $graphics $palette.plate_main $palette.outline $platePoints

    $apronPoints = @(
        (AddVec $pose.pelvis (MulVec $right 1.8))
        (AddVec $pose.pelvis (MulVec $right -1.5))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -2.0) (MulVec $right -1.2)))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -12.0) (MulVec $right -0.8)))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -11.5) (MulVec $right 2.0)))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -2.8) (MulVec $right 2.8)))
    )
    FillPolygon2D $graphics $palette.apron_main $palette.outline $apronPoints

    $frontPadCenter = AddVec $frontShoulder (MulVec $right 1.8)
    $backPadCenter = AddVec $backShoulder (MulVec $right -1.5)
    FillEllipse2D $graphics $palette.pad_back $palette.outline ($backPadCenter.X - 4.8) ($backPadCenter.Y - 3.1) 9.6 6.2
    FillEllipse2D $graphics $palette.pad_front $palette.outline ($frontPadCenter.X - 5.8) ($frontPadCenter.Y - 3.6) 11.6 7.2

    FillRect2D $graphics $palette.belt ($pose.pelvis.X - 6.8) ($pose.pelvis.Y - 2.3) 13.6 2.6
    FillRect2D $graphics $palette.chain ($pose.chest.X - 5.8) ($pose.chest.Y + 0.2) 11.6 1.3
    DrawPixel $graphics $palette.chain ($pose.chest.X - 3.0) ($pose.chest.Y + 2.0)
    DrawPixel $graphics $palette.chain ($pose.chest.X - 1.0) ($pose.chest.Y + 3.0)
    DrawPixel $graphics $palette.chain ($pose.chest.X + 1.0) ($pose.chest.Y + 4.0)

    $hoodX = $pose.head.X
    $hoodY = $pose.head.Y
    $helmetPoints = @(
        (V ($hoodX - 6.4) ($hoodY - 1.2))
        (V ($hoodX - 4.8) ($hoodY - 7.8))
        (V ($hoodX + 1.6) ($hoodY - 9.6))
        (V ($hoodX + 6.5) ($hoodY - 5.4))
        (V ($hoodX + 6.3) ($hoodY + 1.4))
        (V ($hoodX + 2.4) ($hoodY + 6.3))
        (V ($hoodX - 3.8) ($hoodY + 5.8))
        (V ($hoodX - 6.7) ($hoodY + 1.2))
    )
    FillPolygon2D $graphics $palette.helmet_main $palette.outline $helmetPoints

    $maskPoints = @(
        (V ($hoodX - 2.2) ($hoodY - 2.0))
        (V ($hoodX + 3.8) ($hoodY - 1.7))
        (V ($hoodX + 4.2) ($hoodY + 3.0))
        (V ($hoodX + 0.6) ($hoodY + 5.2))
        (V ($hoodX - 2.8) ($hoodY + 2.4))
    )
    FillPolygon2D $graphics $palette.mask_main $palette.mask_main $maskPoints

    if ($pose.eye) {
        DrawPixel $graphics $palette.eye ($hoodX + 0.5) ($hoodY + 0.1)
        DrawPixel $graphics $palette.eye_glow ($hoodX + 1.5) ($hoodY + 0.1)
    }

    DrawLeg $graphics $frontHip $pose.front_foot $pose.front_leg_bend 6.4 $palette.leg_front $palette.boot_front $palette.outline
    DrawArm $graphics $frontShoulder $pose.front_hand $pose.front_arm_bend 5.8 $palette.arm_front $palette.glove_front $palette.outline
    DrawGreataxe $graphics $pose.back_hand $pose.front_hand $pose.weapon_tip $palette
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

$frameWidth = 192
$frameHeight = 192
$baselineY = 131
$renderScale = 1.18
$renderOffsetX = 47.0
$renderOffsetY = 44.0

$palette = @{
    outline = HexColor "#110f12"
    tunic_main = HexColor "#4d463d"
    plate_main = HexColor "#64696a"
    apron_main = HexColor "#5b3230"
    pad_front = HexColor "#707172"
    pad_back = HexColor "#58585a"
    belt = HexColor "#342822"
    chain = HexColor "#8f918f"
    helmet_main = HexColor "#57595a"
    mask_main = HexColor "#222123"
    arm_back = HexColor "#4f5052"
    arm_front = HexColor "#666668"
    glove_back = HexColor "#3a322d"
    glove_front = HexColor "#453a35"
    leg_back = HexColor "#444448"
    leg_front = HexColor "#5b5b60"
    boot_back = HexColor "#211e22"
    boot_front = HexColor "#2a2528"
    shaft_main = HexColor "#5d4634"
    wrap_main = HexColor "#7f5d40"
    blade_main = HexColor "#a4a9ad"
    blade_dark = HexColor "#666c70"
    blade_light = HexColor "#d2d5d7"
    eye = HexColor "#ece9e0"
    eye_glow = HexColor "#bec8cc"
}

$animations = @(
    @{
        name = "idle"
        fps = 5
        loop = $true
        frames = @(
            (Frame 40.0 32.0 39.0 50.0 42.0 18.8 46.0 34.2 -1.8 31.8 38.4 1.0 44.0 69.0 2.6 33.0 69.0 -1.8 66.0 28.0 $true)
            (Frame 40.4 31.6 39.1 49.6 42.2 18.5 46.4 33.7 -1.7 32.0 38.1 1.0 44.2 69.0 2.4 33.2 69.0 -1.7 66.4 27.6 $true)
            (Frame 39.4 32.8 38.4 50.6 41.0 19.5 45.1 35.3 -1.9 31.0 39.2 1.1 43.6 69.0 2.8 32.2 69.0 -2.0 65.0 29.2 $true)
            (Frame 40.0 32.2 39.0 50.0 42.0 18.9 46.1 34.4 -1.8 31.8 38.5 1.0 44.0 69.0 2.6 33.0 69.0 -1.8 66.1 28.2 $true)
        )
    }
    @{
        name = "move"
        fps = 7
        loop = $true
        frames = @(
            (Frame 38.8 32.8 37.8 50.8 41.0 19.4 45.2 35.2 -1.7 30.2 39.0 1.2 45.2 69.0 3.2 31.2 69.0 -2.6 65.4 29.5 $true)
            (Frame 39.6 32.0 38.6 50.0 41.7 18.9 45.9 34.2 -1.7 31.0 38.2 1.1 44.6 69.0 2.6 32.6 69.0 -2.0 66.0 28.4 $true)
            (Frame 40.8 31.7 39.7 49.8 42.6 18.6 46.8 33.7 -1.6 32.1 37.8 0.9 43.2 69.0 1.4 34.0 69.0 -1.0 66.8 27.8 $true)
            (Frame 41.4 31.9 40.0 50.0 43.0 18.8 47.2 34.0 -1.6 32.8 38.0 0.9 42.6 69.0 0.8 35.6 69.0 -0.4 67.2 28.2 $true)
            (Frame 40.6 32.6 39.1 50.6 42.4 19.4 46.5 34.9 -1.7 32.0 38.8 1.1 42.2 69.0 0.6 37.4 69.0 0.6 66.4 29.2 $true)
            (Frame 39.8 32.2 38.5 50.2 41.8 19.0 45.8 34.3 -1.7 31.2 38.3 1.0 43.0 69.0 1.6 35.2 69.0 -0.6 65.8 28.6 $true)
        )
    }
    @{
        name = "attack_1"
        fps = 9
        loop = $false
        frames = @(
            (Frame 40.0 32.0 39.0 50.0 42.0 18.8 46.0 34.2 -1.8 31.8 38.4 1.0 44.0 69.0 2.6 33.0 69.0 -1.8 66.0 28.0 $true)
            (Frame 37.0 33.8 36.6 51.4 38.2 21.0 38.2 39.8 -4.4 30.0 41.2 1.6 44.8 69.0 3.4 33.2 69.0 -1.8 40.0 14.0 $true)
            (Frame 32.2 35.4 32.4 52.8 33.4 23.2 28.2 48.8 -7.6 28.8 42.4 1.4 45.2 69.0 4.0 33.4 69.0 -1.4 4.0 2.0 $true)
            (Frame 28.8 36.0 29.8 53.0 29.8 23.8 21.0 50.8 -8.4 29.6 41.6 0.8 45.4 69.0 4.4 33.6 69.0 -1.0 -22.0 10.0 $true)
            (Frame 38.6 32.8 38.4 50.2 40.8 19.8 46.8 37.6 -1.4 34.8 39.4 0.7 47.2 69.0 2.8 35.4 69.0 -0.8 86.0 48.0 $true)
            (Frame 47.4 31.0 45.2 49.0 50.8 18.0 58.8 34.2 1.3 41.2 37.0 0.2 50.2 69.0 1.2 39.2 69.0 -0.4 128.0 64.0 $true)
            (Frame 45.8 33.2 43.6 50.8 48.6 20.1 52.0 38.4 0.4 40.0 40.0 0.5 49.0 69.0 1.8 38.6 69.0 -0.8 110.0 44.0 $true)
            (Frame 41.8 32.8 40.4 50.4 43.8 19.4 47.6 35.8 -0.8 34.8 39.0 0.9 46.2 69.0 2.4 35.2 69.0 -1.1 78.0 30.0 $true)
        )
    }
    @{
        name = "attack_2"
        fps = 8
        loop = $false
        frames = @(
            (Frame 40.0 32.0 39.0 50.0 42.0 18.8 46.0 34.2 -1.8 31.8 38.4 1.0 44.0 69.0 2.6 33.0 69.0 -1.8 66.0 28.0 $true)
            (Frame 39.2 32.4 38.6 50.8 40.8 19.4 44.2 35.8 -2.2 32.4 39.0 1.0 44.1 69.0 2.8 33.0 69.0 -1.7 63.0 22.0 $true)
            (Frame 38.4 32.8 37.9 51.2 40.0 20.0 43.6 36.8 -2.8 32.8 39.6 1.1 44.2 69.0 3.0 33.1 69.0 -1.5 61.0 14.0 $true)
            (Frame 37.8 33.2 37.2 51.6 39.2 20.8 42.6 37.8 -3.2 33.0 40.2 1.2 44.4 69.0 3.2 33.2 69.0 -1.4 60.0 8.0 $true)
            (Frame 37.0 33.6 36.6 52.0 38.5 21.3 44.4 34.8 -4.0 34.2 39.4 0.6 44.5 69.0 3.4 33.3 69.0 -1.3 68.0 -2.0 $true)
            (Frame 36.4 33.9 36.0 52.4 37.9 21.7 45.6 32.6 -4.6 35.6 38.8 0.1 44.6 69.0 3.6 33.4 69.0 -1.2 73.0 -10.0 $true)
            (Frame 35.8 34.2 35.6 52.8 37.2 22.0 46.8 29.8 -5.0 37.4 38.0 -0.6 44.8 69.0 3.8 33.6 69.0 -1.2 78.0 -18.0 $true)
            (Frame 36.1 34.0 35.8 52.6 37.6 21.8 47.8 27.2 -5.3 38.8 35.8 -0.9 44.9 69.0 3.7 33.7 69.0 -1.1 84.0 -28.0 $true)
            (Frame 36.5 33.8 36.0 52.5 38.1 21.5 49.0 24.2 -5.6 39.8 33.8 -1.0 45.0 69.0 3.6 33.8 69.0 -1.0 88.0 -36.0 $true)
            (Frame 36.8 33.6 36.2 52.4 38.6 21.2 50.2 21.2 -5.8 40.6 31.4 -1.2 45.0 69.0 3.4 34.0 69.0 -1.0 92.0 -44.0 $true)
            (Frame 37.2 33.4 36.8 52.1 39.0 20.9 51.0 18.4 -6.0 41.8 28.8 -1.2 45.2 69.0 3.2 34.2 69.0 -0.9 97.0 -54.0 $true)
            (Frame 37.6 33.2 37.4 51.9 39.6 20.6 51.8 15.8 -6.1 42.8 26.2 -1.3 45.3 69.0 3.0 34.4 69.0 -0.9 101.0 -62.0 $true)
            (Frame 38.0 33.0 38.0 51.7 40.2 20.3 52.4 13.2 -6.2 43.8 24.4 -1.4 45.4 69.0 2.9 34.6 69.0 -0.8 104.0 -68.0 $true)
            (Frame 38.4 32.9 38.3 51.6 40.5 20.1 52.6 11.8 -6.2 44.2 23.6 -1.4 45.5 69.0 2.8 34.7 69.0 -0.8 105.0 -71.0 $true)
            (Frame 38.8 32.8 38.6 51.4 40.8 20.0 52.8 10.8 -6.2 44.6 22.8 -1.4 45.6 69.0 2.8 34.8 69.0 -0.8 106.0 -74.0 $true)
            (Frame 39.0 32.9 38.7 51.6 41.0 20.1 53.2 12.6 -6.0 45.0 24.6 -1.2 45.8 69.0 3.0 34.9 69.0 -0.8 108.0 -60.0 $true)
            (Frame 39.4 33.2 39.1 52.0 41.4 20.6 54.2 18.4 -5.2 46.0 30.8 -0.8 46.0 69.0 3.4 35.2 69.0 -0.7 112.0 -18.0 $true)
            (Frame 41.6 39.2 41.4 57.8 43.6 26.4 56.8 56.2 -1.8 48.8 47.6 0.8 46.4 69.0 5.2 36.0 69.0 -0.4 118.0 108.0 $true)
            (Frame 42.8 36.2 42.0 54.8 44.6 23.6 51.8 46.2 -0.6 44.8 42.2 0.8 46.2 69.0 4.2 35.4 69.0 -0.6 94.0 76.0 $true)
            (Frame 41.0 33.4 39.8 51.6 43.0 20.2 47.8 37.8 -0.6 38.4 38.8 0.9 45.4 69.0 2.8 34.4 69.0 -1.0 74.0 40.0 $true)
        )
    }
    @{
        name = "attack_3"
        fps = 8
        loop = $false
        frames = @(
            (Frame 40.0 32.0 39.0 50.0 42.0 18.8 46.0 34.2 -1.8 31.8 38.4 1.0 44.0 69.0 2.6 33.0 69.0 -1.8 66.0 28.0 $true)
            (Frame 38.8 33.0 38.0 50.8 40.2 20.0 42.0 37.4 -2.8 29.4 40.0 1.6 44.6 69.0 3.0 33.0 69.0 -1.6 42.0 46.0 $true)
            (Frame 34.8 34.2 34.4 52.2 36.2 21.6 35.0 39.2 -5.2 27.4 41.4 1.8 44.8 69.0 3.6 32.8 69.0 -1.2 8.0 68.0 $true)
            (Frame 31.6 35.2 31.6 53.0 33.0 22.4 29.4 41.0 -6.6 27.6 41.8 1.4 45.0 69.0 4.0 32.6 69.0 -1.0 -18.0 86.0 $true)
            (Frame 45.4 31.8 44.0 50.2 48.0 18.8 49.6 33.8 -0.2 41.2 38.2 0.6 48.6 69.0 1.8 35.8 69.0 -0.8 122.0 -4.0 $true)
            (Frame 47.4 32.4 45.2 50.8 50.0 19.4 53.6 34.8 0.6 42.0 39.0 0.6 50.0 69.0 2.0 37.0 69.0 -0.6 140.0 8.0 $true)
            (Frame 44.0 33.2 42.4 51.6 46.2 20.4 48.8 37.6 0.0 39.4 40.8 0.8 48.8 69.0 2.4 36.4 69.0 -0.8 102.0 20.0 $true)
            (Frame 41.4 32.8 40.0 50.8 43.6 19.6 46.8 35.8 -0.8 34.8 39.2 0.9 46.2 69.0 2.4 34.8 69.0 -1.2 72.0 30.0 $true)
        )
    }
    @{
        name = "hit"
        fps = 8
        loop = $false
        frames = @(
            (Frame 37.0 31.0 36.0 49.0 38.5 18.2 48.2 31.8 0.8 28.5 36.2 -1.2 44.0 69.0 1.8 33.0 69.0 -1.4 67.0 25.0 $true)
            (Frame 35.8 30.4 35.0 48.2 37.0 17.6 49.0 30.8 1.2 27.8 35.6 -1.4 43.2 69.0 1.2 33.0 69.0 -0.8 68.0 24.0 $true)
            (Frame 38.6 32.0 37.8 49.8 40.2 18.7 46.8 33.8 -0.4 30.6 37.8 0.4 44.0 69.0 2.0 33.2 69.0 -1.2 66.0 27.0 $true)
        )
    }
    @{
        name = "launch"
        fps = 7
        loop = $false
        frames = @(
            (Frame 43.0 28.0 35.0 44.0 46.0 16.0 49.0 24.0 1.2 30.0 28.0 -1.2 39.0 61.0 1.6 27.0 60.0 -1.2 69.0 18.0 $true)
            (Frame 44.5 27.2 34.0 43.0 47.4 15.2 50.2 23.0 1.0 29.0 27.0 -1.0 40.0 59.0 1.2 26.0 58.0 -1.0 70.0 16.0 $true)
        )
    }
    @{
        name = "down"
        fps = 5
        loop = $true
        frames = @(
            (Frame 31.0 58.0 44.0 61.0 24.0 56.0 49.0 61.0 0.4 37.0 63.0 -0.2 58.0 69.0 0.8 42.0 69.0 -0.6 62.0 58.0 $false)
            (Frame 30.0 60.0 43.5 63.0 22.8 58.0 48.0 63.0 0.4 36.2 64.0 -0.2 57.0 69.0 0.6 41.0 69.0 -0.4 60.0 61.0 $false)
        )
    }
    @{
        name = "get_up"
        fps = 7
        loop = $false
        frames = @(
            (Frame 30.0 60.0 43.5 63.0 22.8 58.0 48.0 63.0 0.4 36.2 64.0 -0.2 57.0 69.0 0.6 41.0 69.0 -0.4 60.0 61.0 $false)
            (Frame 31.0 54.0 42.0 60.0 24.0 49.0 38.0 57.0 -1.4 35.0 63.0 0.3 54.0 69.0 1.2 41.0 69.0 -0.8 49.0 55.0 $true)
            (Frame 34.0 47.0 40.0 57.0 28.0 40.0 39.5 50.0 -1.8 34.0 58.0 0.4 48.0 69.0 2.4 38.0 69.0 -1.2 53.0 41.0 $true)
            (Frame 37.5 40.0 39.0 53.0 34.0 30.0 42.0 42.0 -1.5 33.2 50.0 0.6 45.0 69.0 3.0 35.0 69.0 -1.4 58.0 31.0 $true)
            (Frame 40.0 32.0 39.0 50.0 42.0 18.8 46.0 34.2 -1.8 31.8 38.4 1.0 44.0 69.0 2.6 33.0 69.0 -1.8 66.0 28.0 $true)
        )
    }
    @{
        name = "grabbed"
        fps = 5
        loop = $true
        frames = @(
            (Frame 40.0 33.0 39.0 51.0 42.0 19.8 43.0 30.0 -0.2 34.0 31.0 0.1 44.0 69.0 2.2 33.0 69.0 -1.4 55.0 29.0 $true)
            (Frame 40.0 34.0 39.0 52.0 42.0 20.6 44.0 31.0 -0.2 35.0 32.0 0.1 44.0 69.0 2.2 33.0 69.0 -1.4 56.0 30.0 $true)
        )
    }
    @{
        name = "death"
        fps = 7
        loop = $false
        frames = @(
            (Frame 37.0 31.0 36.0 49.0 38.5 18.2 48.2 31.8 0.8 28.5 36.2 -1.2 44.0 69.0 1.8 33.0 69.0 -1.4 67.0 25.0 $true)
            (Frame 35.0 39.0 38.0 56.0 31.0 32.0 40.0 48.0 -0.8 32.0 53.0 0.3 46.0 69.0 3.1 34.0 69.0 -1.7 48.0 43.0 $false)
            (Frame 31.2 51.0 42.0 60.0 24.0 48.0 46.0 60.0 0.1 35.0 62.0 -0.2 54.0 69.0 1.4 39.0 69.0 -0.8 58.0 57.0 $false)
            (Frame 30.0 60.0 43.5 63.0 22.8 58.0 48.0 63.0 0.4 36.2 64.0 -0.2 57.0 69.0 0.6 41.0 69.0 -0.4 60.0 61.0 $false)
        )
    }
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$artDir = $PSScriptRoot
$sceneDir = Join-Path $repoRoot "scenes\enemies"
$scenePath = Join-Path $sceneDir "dungeon_overseer_sprite.tscn"
$manifestPath = Join-Path $artDir "dungeon_overseer_manifest.json"
$previewPath = Join-Path $artDir "dungeon_overseer_preview_4x.png"
$readmePath = Join-Path $artDir "README.md"

New-Item -ItemType Directory -Force -Path $artDir | Out-Null
New-Item -ItemType Directory -Force -Path $sceneDir | Out-Null

$manifestAnimations = @()
$sheetMeta = @()

foreach ($animation in $animations) {
    $sheet = New-SheetBitmap ($frameWidth * $animation.frames.Count) $frameHeight
    for ($i = 0; $i -lt $animation.frames.Count; $i++) {
        $frameBitmap = New-SheetBitmap $frameWidth $frameHeight
        $frameBitmap.Graphics.TranslateTransform([float]$renderOffsetX, [float]$renderOffsetY)
        $frameBitmap.Graphics.ScaleTransform([float]$renderScale, [float]$renderScale)
        DrawBody $frameBitmap.Graphics $animation.frames[$i] $palette
        $frameBitmap.Graphics.ResetTransform()
        $sheet.Graphics.DrawImageUnscaled($frameBitmap.Bitmap, $i * $frameWidth, 0)
        $frameBitmap.Graphics.Dispose()
        $frameBitmap.Bitmap.Dispose()
    }

    $fileName = "dungeon_overseer_{0}_strip.png" -f $animation.name
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
        path = "res://art/enemies/dungeon_overseer/$fileName"
        frames = $animation.frames.Count
        fps = $animation.fps
        loop = [bool]$animation.loop
    }
}

$previewScale = 4
$previewGap = 10
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
    name = "dungeon_overseer"
    display_name = "Dungeon Overseer"
    frame_width = $frameWidth
    frame_height = $frameHeight
    background = "transparent"
    fixed_frame_size = $true
    baseline_y = $baselineY
    facing = "right"
    notes = @(
        "all frames share a fixed 192x192 canvas"
        "transparent background"
        "designed for frame-by-frame 2D side-action elite enemy animation"
        "sprite sheets contain no overlapping frames"
        "heavy executioner silhouette with readable greataxe arcs"
    )
    animations = $manifestAnimations
}
Write-Utf8NoBom $manifestPath ($manifest | ConvertTo-Json -Depth 5)

$readmeLines = @(
    "# Dungeon Overseer"
    ""
    "- Display name: Dungeon Overseer"
    "- Frame size: 192x192"
    "- Background: transparent"
    "- Baseline: y = 131"
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
[sub_resource type="SpriteFrames" id="SpriteFrames_dungeon_overseer"]
animations = [$($animationBlocks -join ",`r`n")]

"@

$sceneText = @"
[gd_scene load_steps=$($sheetMeta.Count + $atlasIndex + 2) format=3]

$($extLines -join "`r`n")
$($subLines -join "`r`n")
$spriteFramesBlock
[node name="DungeonOverseerSprite" type="Node2D"]

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
position = Vector2(0, 0)
sprite_frames = SubResource("SpriteFrames_dungeon_overseer")
animation = &"idle"
frame = 0
centered = true
"@

Write-Utf8NoBom $scenePath $sceneText
