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
    [bool]$eye = $true,
    [bool]$bolt = $true
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
        bolt = $bolt
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
    FillEllipse2D $graphics $bootColor $outlineColor ($foot.X - 3.3) ($foot.Y - 2.2) 6.7 4.1
}

function DrawArm($graphics, $shoulder, $hand, [double]$bend, [double]$thickness, [System.Drawing.Color]$armColor, [System.Drawing.Color]$gloveColor, [System.Drawing.Color]$outlineColor) {
    $elbow = BendPoint $shoulder $hand $bend
    DrawCapsuleSegment $graphics $shoulder $elbow ($thickness + 0.1) $armColor $outlineColor
    DrawCapsuleSegment $graphics $elbow $hand $thickness $armColor $outlineColor
    FillEllipse2D $graphics $gloveColor $outlineColor ($hand.X - 1.9) ($hand.Y - 1.9) 3.8 3.8
}

function DrawCrossbow($graphics, $grip, $support, $tip, [bool]$showBolt, $palette) {
    $dir = NormalizeVec (SubVec $tip $grip)
    $normal = PerpRight $dir

    $stockBack = AddVec $grip (MulVec $dir -7.0)
    $bodyMid = AddVec $grip (MulVec $dir 3.0)
    $limbCenter = AddVec $tip (MulVec $dir -2.3)
    $limbHalf = 4.6

    DrawCapsuleSegment $graphics $stockBack $bodyMid 2.6 $palette.wood_main $palette.outline
    DrawCapsuleSegment $graphics $bodyMid $limbCenter 2.2 $palette.metal_main $palette.outline

    $limbA = AddVec $limbCenter (MulVec $normal $limbHalf)
    $limbB = AddVec $limbCenter (MulVec $normal (-$limbHalf))
    DrawCapsuleSegment $graphics $limbCenter $limbA 1.8 $palette.wood_dark $palette.outline
    DrawCapsuleSegment $graphics $limbCenter $limbB 1.8 $palette.wood_dark $palette.outline

    $stringA = AddVec $limbA (MulVec $dir 1.0)
    $stringB = AddVec $limbB (MulVec $dir 1.0)
    $stringPen = New-Object System.Drawing.Pen($palette.string, 1)
    $graphics.DrawLine($stringPen, [float]$stringA.X, [float]$stringA.Y, [float]$stockBack.X, [float]$stockBack.Y)
    $graphics.DrawLine($stringPen, [float]$stringB.X, [float]$stringB.Y, [float]$stockBack.X, [float]$stockBack.Y)
    $stringPen.Dispose()

    if ($showBolt) {
        $boltStart = AddVec $bodyMid (MulVec $dir -0.5)
        $boltEnd = AddVec $tip (MulVec $dir 1.5)
        DrawCapsuleSegment $graphics $boltStart $boltEnd 1.2 $palette.bolt_main $palette.outline
        $boltTailA = AddVec $boltStart (MulVec $normal 1.3)
        $boltTailB = AddVec $boltStart (MulVec $normal (-1.3))
        $boltTailBack = AddVec $boltStart (MulVec $dir -1.8)
        FillPolygon2D $graphics $palette.bolt_fletch $palette.outline @($boltTailA, $boltTailBack, $boltTailB)
    }

    $headBase = AddVec $tip (MulVec $dir -2.0)
    $headPoints = @(
        (AddVec $headBase (MulVec $normal 1.2))
        $tip
        (AddVec $headBase (MulVec $normal (-1.2)))
        (AddVec $headBase (MulVec $dir -1.0))
    )
    FillPolygon2D $graphics $palette.metal_light $palette.outline $headPoints

    FillEllipse2D $graphics $palette.leather_main $palette.outline ($support.X - 1.5) ($support.Y - 1.5) 3.0 3.0
}

function DrawBody($graphics, $pose, $palette) {
    $axis = NormalizeVec (SubVec $pose.chest $pose.pelvis)
    $right = PerpRight $axis

    $frontShoulder = AddVec $pose.chest (AddVec (MulVec $axis 0.8) (MulVec $right 2.7))
    $backShoulder = AddVec $pose.chest (AddVec (MulVec $axis 0.3) (MulVec $right -2.1))
    $frontHip = AddVec $pose.pelvis (MulVec $right 1.7)
    $backHip = AddVec $pose.pelvis (MulVec $right -1.5)

    DrawLeg $graphics $backHip $pose.back_foot $pose.back_leg_bend 3.5 $palette.leg_back $palette.boot_back $palette.outline
    DrawArm $graphics $backShoulder $pose.back_hand $pose.back_arm_bend 3.0 $palette.arm_back $palette.glove_back $palette.outline

    $torsoPoints = @(
        (AddVec $pose.chest (MulVec $right 3.7))
        (AddVec $pose.chest (MulVec $right -3.2))
        (AddVec $pose.pelvis (MulVec $right -2.8))
        (AddVec $pose.pelvis (MulVec $right 3.1))
    )
    FillPolygon2D $graphics $palette.cloth_main $palette.outline $torsoPoints

    $vestPoints = @(
        (AddVec $pose.chest (AddVec (MulVec $right 1.9) (MulVec $axis 0.8)))
        (AddVec $pose.chest (AddVec (MulVec $right -1.3) (MulVec $axis 0.6)))
        (AddVec $pose.pelvis (AddVec (MulVec $right -1.1) (MulVec $axis -0.6)))
        (AddVec $pose.pelvis (AddVec (MulVec $right 1.7) (MulVec $axis -0.4)))
    )
    FillPolygon2D $graphics $palette.leather_main $palette.outline $vestPoints

    $capePoints = @(
        (AddVec $backShoulder (MulVec $right -0.8))
        (AddVec $backShoulder (AddVec (MulVec $right -2.7) (MulVec $axis 1.2)))
        (AddVec $pose.pelvis (AddVec (MulVec $right -2.5) (MulVec $axis -1.0)))
        (AddVec $pose.pelvis (AddVec (MulVec $right -0.8) (MulVec $axis -0.3)))
    )
    FillPolygon2D $graphics $palette.cape_main $palette.outline $capePoints

    $quiverX = $pose.pelvis.X + ($right.X * -2.4)
    $quiverY = $pose.chest.Y + ($axis.Y * 1.0)
    FillRect2D $graphics $palette.quiver_main ($quiverX - 1.5) ($quiverY - 2.0) 3.0 7.5
    DrawPixel $graphics $palette.bolt_fletch ($quiverX - 1.0) ($quiverY - 2.5)
    DrawPixel $graphics $palette.bolt_fletch ($quiverX + 0.0) ($quiverY - 3.0)
    DrawPixel $graphics $palette.bolt_fletch ($quiverX + 1.0) ($quiverY - 2.3)

    $padCenter = AddVec $frontShoulder (MulVec $right 1.0)
    FillEllipse2D $graphics $palette.pad_main $palette.outline ($padCenter.X - 2.4) ($padCenter.Y - 1.6) 4.8 3.4

    FillRect2D $graphics $palette.belt ($pose.pelvis.X - 4.0) ($pose.pelvis.Y - 1.8) 8.0 2.0
    $clothPoints = @(
        (AddVec $pose.pelvis (MulVec $right 0.6))
        (AddVec $pose.pelvis (MulVec $right -0.7))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -1.4) (MulVec $right -0.3)))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -4.0) (MulVec $right 0.8)))
    )
    FillPolygon2D $graphics $palette.accent_red $palette.outline $clothPoints

    $hoodX = $pose.head.X
    $hoodY = $pose.head.Y
    $hoodPoints = @(
        (V ($hoodX - 4.2) ($hoodY - 1.0))
        (V ($hoodX - 2.9) ($hoodY - 4.8))
        (V ($hoodX + 1.2) ($hoodY - 6.0))
        (V ($hoodX + 4.5) ($hoodY - 2.6))
        (V ($hoodX + 4.0) ($hoodY + 1.8))
        (V ($hoodX + 1.0) ($hoodY + 4.4))
        (V ($hoodX - 2.5) ($hoodY + 4.0))
        (V ($hoodX - 4.8) ($hoodY + 0.9))
    )
    FillPolygon2D $graphics $palette.hood_main $palette.outline $hoodPoints

    $faceShadowPoints = @(
        (V ($hoodX - 1.3) ($hoodY - 2.5))
        (V ($hoodX + 2.6) ($hoodY - 2.3))
        (V ($hoodX + 2.8) ($hoodY + 1.1))
        (V ($hoodX + 0.2) ($hoodY + 2.6))
        (V ($hoodX - 1.8) ($hoodY + 1.5))
    )
    FillPolygon2D $graphics $palette.face_shadow $palette.face_shadow $faceShadowPoints

    if ($pose.eye) {
        DrawPixel $graphics $palette.eye ($hoodX + 0.6) ($hoodY - 0.2)
        DrawPixel $graphics $palette.eye_glow ($hoodX + 1.6) ($hoodY - 0.2)
    }

    DrawLeg $graphics $frontHip $pose.front_foot $pose.front_leg_bend 3.7 $palette.leg_front $palette.boot_front $palette.outline
    DrawArm $graphics $frontShoulder $pose.front_hand $pose.front_arm_bend 3.0 $palette.arm_front $palette.glove_front $palette.outline
    DrawCrossbow $graphics $pose.front_hand $pose.back_hand $pose.weapon_tip $pose.bolt $palette
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
    hood_main = HexColor "#33383e"
    face_shadow = HexColor "#181619"
    cloth_main = HexColor "#4d564e"
    leather_main = HexColor "#5f4d3c"
    cape_main = HexColor "#40464a"
    quiver_main = HexColor "#56463b"
    pad_main = HexColor "#64696e"
    belt = HexColor "#372a24"
    accent_red = HexColor "#5c3036"
    arm_back = HexColor "#474d53"
    arm_front = HexColor "#556168"
    glove_back = HexColor "#756960"
    glove_front = HexColor "#85786e"
    leg_back = HexColor "#43494f"
    leg_front = HexColor "#576168"
    boot_back = HexColor "#242125"
    boot_front = HexColor "#2e292d"
    wood_main = HexColor "#5a4939"
    wood_dark = HexColor "#43372d"
    metal_main = HexColor "#8b939a"
    metal_light = HexColor "#a9b0b6"
    bolt_main = HexColor "#89756a"
    bolt_fletch = HexColor "#7e2d34"
    string = HexColor "#cfc6ae"
    eye = HexColor "#e6edf4"
    eye_glow = HexColor "#adc7de"
}

$animations = @(
    @{
        name = "idle"
        fps = 5
        loop = $true
        frames = @(
            (Frame 24 22.5 22 33 27 16 29.5 28 -0.8 21 28 0.6 27 41 2.4 20 41 -1.8 40 28 $true $true)
            (Frame 24.5 22 22 32.5 27.5 15.5 30.5 27.5 -0.7 21.5 27.5 0.5 27 41 2.3 21 41 -1.6 41 27.5 $true $true)
            (Frame 23.5 23.2 21.5 34 26.5 16.8 29 29 -1.0 20.8 28.8 0.7 26.5 41 2.7 20 41 -2.0 39 29.5 $true $true)
            (Frame 24 22.7 22 33 27 16.2 29.8 28.2 -0.8 21.3 28.2 0.6 27 41 2.4 21 41 -1.6 40 28.4 $true $true)
        )
    }
    @{
        name = "move"
        fps = 8
        loop = $true
        frames = @(
            (Frame 23.3 23 21.6 34 26.5 16.5 29.5 28.5 -0.9 20.4 28.5 0.7 28 41 3.2 19 41 -2.4 40 28.5 $true $true)
            (Frame 24 22 22 33 27 15.7 30.5 27.8 -0.7 21.2 27.8 0.6 28.5 41 2.4 20.5 41 -1.8 41 27.9 $true $true)
            (Frame 25 22 22.8 33 28 15.8 31.3 28 -0.6 22.5 28 0.5 27.5 41 1.8 22.5 41 -1.1 42 28 $true $true)
            (Frame 24.6 22.4 22.4 33.4 27.6 16 30.8 28.2 -0.6 22.3 28.5 0.5 27 41 1.4 24 41 -0.6 41.5 28.5 $true $true)
            (Frame 23.8 23.1 21.9 34.1 26.8 16.7 29.7 29.0 -0.8 21.8 29.0 0.6 26.4 41 1.3 26.5 41 0.4 40.5 29.3 $true $true)
            (Frame 23.4 22.5 21.6 33.3 26.5 16.1 29.4 28.2 -0.8 20.9 28.3 0.6 27.1 41 1.8 24.2 41 -0.8 40 28.4 $true $true)
        )
    }
    @{
        name = "attack"
        fps = 10
        loop = $false
        frames = @(
            (Frame 24 22.5 22 33 27 16 29.5 28 -0.8 21 28 0.6 27 41 2.4 20 41 -1.8 40 28 $true $true)
            (Frame 23 23.5 21 34 26 17 26 29 -2.1 20 28.5 0.6 27 41 3.1 20 41 -2.1 34 29 $true $true)
            (Frame 21.8 24.2 20.2 34.8 24.8 18.2 22.5 28 -3.6 19.5 28.5 0.7 26.8 41 3.8 20 41 -2.6 28 28 $true $true)
            (Frame 21.5 24.5 20 34.8 24.5 18.5 19.5 27 -5.0 19.5 28.2 0.7 26.8 41 4.0 20 41 -2.8 24 27 $true $true)
            (Frame 22.8 23.2 21 34 25 17 31 26.5 -1.6 20.2 28 0.6 27.2 41 3.2 20.6 41 -2.0 43 26 $true $false)
            (Frame 25 22 22.5 33 27 16 34 27 0.1 21.4 28 0.5 28.5 41 2.2 21 41 -1.6 46 27 $true $false)
            (Frame 26 22.8 23.5 33.5 28 16.6 33 28.4 0.5 22.3 29 0.4 29 41 2.0 22 41 -1.4 44 29 $true $false)
            (Frame 24.4 22.8 22.3 33.2 27.2 16.4 31 28.2 -0.3 21.6 28.5 0.5 28.2 41 2.2 21.5 41 -1.5 41 28.6 $true $true)
        )
    }
    @{
        name = "hit"
        fps = 9
        loop = $false
        frames = @(
            (Frame 22 22 20 32.5 24.5 16 31.5 26.8 0.8 18.5 27.2 -0.7 27 41 2.0 21 41 -1.4 39 27 $true $true)
            (Frame 21 21 19 31.5 23.5 15.2 32.8 25.8 1.1 17.8 26.2 -0.9 26 41 1.3 21 41 -0.8 40 26 $true $true)
            (Frame 23 22.5 21 33 25.5 16.4 30.5 27.8 -0.3 19 28 0.4 27 41 2.2 21 41 -1.3 39 28 $true $true)
        )
    }
    @{
        name = "launch"
        fps = 8
        loop = $false
        frames = @(
            (Frame 26 21.2 20.5 30 29.5 16 31 23 1.1 19 24 -1.0 24 36 1.2 18 35 -1.1 38 23 $true $true)
            (Frame 27 20.8 20 29.5 30 15.5 32 22 0.8 18 23 -0.8 25 35 1.0 17 34 -0.9 39 22 $true $true)
        )
    }
    @{
        name = "down"
        fps = 6
        loop = $true
        frames = @(
            (Frame 21.4 34 28.5 36 18 33.5 31.5 36 0.4 24.5 39 -0.3 36 40 0.7 28.5 41 -0.6 35 36 $false $true)
            (Frame 20.8 35 28 37 17.2 34.2 31 37 0.4 24.2 39 -0.2 35 40 0.6 28 41 -0.5 34 37 $false $true)
        )
    }
    @{
        name = "get_up"
        fps = 8
        loop = $false
        frames = @(
            (Frame 20.8 35 28 37 17.2 34.2 31 37 0.4 24.2 39 -0.2 35 40 0.6 28 41 -0.5 34 37 $false $true)
            (Frame 21.2 31.3 27 36 18 29.5 24 34 -1.1 21 37 0.3 33 40 1.2 28 41 -0.8 29 33 $true $true)
            (Frame 22.5 28.2 24.5 35.2 21.5 23.8 27.5 31.8 -1.0 21 33 0.4 27 41 2.0 22 40 -1.4 35 31 $true $true)
            (Frame 23.5 25.2 22 34 25.5 19.2 29.5 30.1 -0.8 20 31.1 0.4 26 41 2.5 21 41 -1.7 38 30.2 $true $true)
            (Frame 24 22.5 22 33 27 16 29.5 28 -0.8 21 28 0.6 27 41 2.4 20 41 -1.8 40 28 $true $true)
        )
    }
    @{
        name = "grabbed"
        fps = 6
        loop = $true
        frames = @(
            (Frame 24 22.5 22 33 27 16 27 25.8 -0.2 20.5 26.5 0.1 27 41 2.1 21 41 -1.5 31 26.5 $true $true)
            (Frame 24 23.2 22 34 27 16.8 28 26.6 -0.2 21 27.4 0.1 27 41 2.2 21 41 -1.5 32 27 $true $true)
        )
    }
    @{
        name = "death"
        fps = 8
        loop = $false
        frames = @(
            (Frame 22 22.5 20 33 24.5 16 31 27.5 0.6 18.2 27.8 -0.7 27 41 2.2 21 41 -1.6 38 28 $true $true)
            (Frame 22.8 26.5 21 35 24 20.5 28.5 34.5 -0.2 19 33 0.3 26 41 2.8 20 41 -2.0 32 35 $false $true)
            (Frame 20.8 31.2 27 36 17.5 29.5 31.5 36 0.5 22.2 37.2 -0.2 35 40 0.9 28 41 -0.7 34 37 $false $true)
            (Frame 20.2 35 28 37.2 16.8 34 31.5 37 0.4 24 39 -0.1 36 40 0.6 28 41 -0.4 34 38 $false $true)
        )
    }
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$artDir = $PSScriptRoot
$sceneDir = Join-Path $repoRoot "scenes\enemies"
$scenePath = Join-Path $sceneDir "dungeon_crossbowman_sprite.tscn"
$manifestPath = Join-Path $artDir "dungeon_crossbowman_manifest.json"
$previewPath = Join-Path $artDir "dungeon_crossbowman_preview_4x.png"
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

    $fileName = "dungeon_crossbowman_{0}_strip.png" -f $animation.name
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
        path = "res://art/enemies/dungeon_crossbowman/$fileName"
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
    name = "dungeon_crossbowman"
    display_name = "Dungeon Crossbowman"
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
        "crossbow-focused silhouette with clear raise-aim-fire poses"
    )
    animations = $manifestAnimations
}
Write-Utf8NoBom $manifestPath ($manifest | ConvertTo-Json -Depth 5)

$readmeLines = @(
    "# Dungeon Crossbowman"
    ""
    "- Display name: Dungeon Crossbowman"
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
[sub_resource type="SpriteFrames" id="SpriteFrames_dungeon_crossbowman"]
animations = [$($animationBlocks -join ",`r`n")]

"@

$sceneText = @"
[gd_scene load_steps=$($sheetMeta.Count + $atlasIndex + 2) format=3]

$($extLines -join "`r`n")
$($subLines -join "`r`n")
$spriteFramesBlock
[node name="DungeonCrossbowmanSprite" type="Node2D"]

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
position = Vector2(0, 0)
sprite_frames = SubResource("SpriteFrames_dungeon_crossbowman")
animation = &"idle"
frame = 0
centered = true
"@

Write-Utf8NoBom $scenePath $sceneText
