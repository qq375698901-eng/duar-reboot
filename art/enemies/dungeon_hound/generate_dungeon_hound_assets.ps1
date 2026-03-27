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
    [double]$sx, [double]$sy,
    [double]$hx, [double]$hy,
    [double]$nx, [double]$ny,
    [double]$fx, [double]$fy, [double]$fkb,
    [double]$rx, [double]$ry, [double]$rkb,
    [double]$tx, [double]$ty,
    [double]$jawOpen = 0.0,
    [bool]$eye = $true
) {
    [PSCustomObject]@{
        shoulder = V $sx $sy
        hip = V $hx $hy
        snout = V $nx $ny
        front_foot = V $fx $fy
        front_knee_bend = $fkb
        rear_foot = V $rx $ry
        rear_knee_bend = $rkb
        tail_tip = V $tx $ty
        jaw_open = $jawOpen
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

function DrawLeg($graphics, $root, $foot, [double]$bend, [double]$thickness, [System.Drawing.Color]$legColor, [System.Drawing.Color]$pawColor, [System.Drawing.Color]$outlineColor) {
    $knee = BendPoint $root $foot $bend
    DrawCapsuleSegment $graphics $root $knee ($thickness + 0.2) $legColor $outlineColor
    DrawCapsuleSegment $graphics $knee $foot $thickness $legColor $outlineColor
    FillEllipse2D $graphics $pawColor $outlineColor ($foot.X - 3.2) ($foot.Y - 1.8) 6.4 3.6
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

function DrawHound($graphics, $pose, $palette) {
    $shoulder = $pose.shoulder
    $hip = $pose.hip
    $spineMid = MidVec $shoulder $hip
    $backPeak = AddVec $spineMid (V 0.0 -6.0)
    $withers = AddVec $shoulder (V -1.0 -4.6)
    $neckBase = AddVec $shoulder (V 2.6 -4.2)
    $croup = AddVec $hip (V 1.7 -3.2)
    $bellyFront = AddVec $shoulder (V 0.0 2.9)
    $bellyMid = AddVec $spineMid (V 0.2 3.8)
    $bellyRear = AddVec $hip (V 1.1 2.7)
    $tailBase = AddVec $hip (V 2.4 -1.8)

    $rearBackRoot = AddVec $hip (V -1.1 -1.2)
    $frontBackRoot = AddVec $shoulder (V -1.0 -1.2)
    DrawLeg $graphics $rearBackRoot (AddVec $pose.rear_foot (V -1.6 -0.9)) ($pose.rear_knee_bend * 0.85) 2.1 $palette.leg_back $palette.paw_back $palette.outline
    DrawLeg $graphics $frontBackRoot (AddVec $pose.front_foot (V -1.4 -0.9)) ($pose.front_knee_bend * 0.85) 2.1 $palette.leg_back $palette.paw_back $palette.outline

    $tailMid = MidVec $tailBase $pose.tail_tip
    DrawCapsuleSegment $graphics $tailBase $tailMid 2.0 $palette.tail_main $palette.outline
    DrawCapsuleSegment $graphics $tailMid $pose.tail_tip 1.6 $palette.tail_tip $palette.outline

    $bodyPoints = @(
        (AddVec $withers (V -1.8 0.2))
        $neckBase
        (AddVec $backPeak (V 0.0 -0.6))
        $croup
        (AddVec $tailBase (V 0.4 0.9))
        $bellyRear
        $bellyMid
        $bellyFront
    )
    FillPolygon2D $graphics $palette.fur_main $palette.outline $bodyPoints

    $ribPatch = @(
        (AddVec $spineMid (V -1.0 -2.0))
        (AddVec $spineMid (V 2.8 -1.0))
        (AddVec $spineMid (V 3.0 1.4))
        (AddVec $spineMid (V -0.2 1.8))
    )
    FillPolygon2D $graphics $palette.fur_patch $palette.fur_patch $ribPatch

    $scarPoints = @(
        (AddVec $spineMid (V 1.2 -0.7))
        (AddVec $spineMid (V 3.2 0.1))
        (AddVec $spineMid (V 2.7 1.0))
        (AddVec $spineMid (V 0.8 0.2))
    )
    FillPolygon2D $graphics $palette.scar $palette.scar $scarPoints

    $headCenter = AddVec $pose.shoulder (V 7.2 -5.4)
    $headPoints = @(
        (AddVec $headCenter (V -4.8 -1.5))
        (AddVec $headCenter (V -2.4 -4.0))
        (AddVec $headCenter (V 1.8 -4.6))
        (AddVec $headCenter (V 4.2 -2.5))
        (AddVec $headCenter (V 4.6 0.4))
        (AddVec $headCenter (V 1.8 2.6))
        (AddVec $headCenter (V -2.5 2.4))
        (AddVec $headCenter (V -4.9 0.5))
    )
    FillPolygon2D $graphics $palette.head_main $palette.outline $headPoints

    $earPoints = @(
        (AddVec $headCenter (V -2.8 -3.2))
        (AddVec $headCenter (V -1.4 -6.2))
        (AddVec $headCenter (V 0.0 -3.0))
    )
    FillPolygon2D $graphics $palette.ear_main $palette.outline $earPoints

    $snoutBaseTop = AddVec $headCenter (V 2.6 -1.3)
    $snoutBaseBottom = AddVec $headCenter (V 1.8 0.8)
    $snoutPoints = @(
        $snoutBaseTop
        (AddVec $pose.snout (V 0.4 -1.2))
        (AddVec $pose.snout (V 1.8 0.0))
        (AddVec $pose.snout (V -0.4 1.1))
        $snoutBaseBottom
    )
    FillPolygon2D $graphics $palette.snout_main $palette.outline $snoutPoints

    $jawDrop = [double]$pose.jaw_open
    $jawPoints = @(
        $snoutBaseBottom
        (AddVec $pose.snout (V 0.4 0.8))
        (AddVec $pose.snout (V 1.3 (1.8 + $jawDrop)))
        (AddVec $pose.snout (V -1.0 (1.6 + $jawDrop)))
        (AddVec $headCenter (V 1.0 (1.9 + ($jawDrop * 0.65))))
    )
    FillPolygon2D $graphics $palette.jaw_main $palette.outline $jawPoints

    DrawPixel $graphics $palette.nose ($pose.snout.X + 1.2) ($pose.snout.Y + 0.1)
    DrawPixel $graphics $palette.tooth ($pose.snout.X - 0.4) ($pose.snout.Y + 1.4)
    DrawPixel $graphics $palette.tooth ($pose.snout.X + 0.9) ($pose.snout.Y + 1.9)
    if ($jawDrop -gt 0.6) {
        DrawPixel $graphics $palette.tooth ($pose.snout.X + 0.5) ($pose.snout.Y + 3.2)
        DrawPixel $graphics $palette.tooth ($pose.snout.X - 0.6) ($pose.snout.Y + 2.8)
    }

    if ($pose.eye) {
        DrawPixel $graphics $palette.eye ($headCenter.X + 0.1) ($headCenter.Y - 0.7)
        DrawPixel $graphics $palette.eye_glow ($headCenter.X + 1.1) ($headCenter.Y - 0.7)
    }

    $rearFrontRoot = AddVec $hip (V 0.6 -0.8)
    $frontFrontRoot = AddVec $shoulder (V 0.9 -0.9)
    DrawLeg $graphics $rearFrontRoot $pose.rear_foot $pose.rear_knee_bend 2.7 $palette.leg_front $palette.paw_front $palette.outline
    DrawLeg $graphics $frontFrontRoot $pose.front_foot $pose.front_knee_bend 2.8 $palette.leg_front $palette.paw_front $palette.outline
}

$frameWidth = 48
$frameHeight = 48
$baselineY = 41

$palette = @{
    outline = HexColor "#120f11"
    fur_main = HexColor "#47413b"
    fur_patch = HexColor "#5c5147"
    head_main = HexColor "#4f463f"
    ear_main = HexColor "#3b3532"
    snout_main = HexColor "#6d6259"
    jaw_main = HexColor "#3b312f"
    leg_back = HexColor "#3d3734"
    leg_front = HexColor "#554d45"
    paw_back = HexColor "#211d1c"
    paw_front = HexColor "#2d2625"
    tail_main = HexColor "#4b433b"
    tail_tip = HexColor "#352f2c"
    scar = HexColor "#7a3a35"
    eye = HexColor "#d9e1ea"
    eye_glow = HexColor "#9db1c7"
    tooth = HexColor "#d3c7b7"
    nose = HexColor "#1b1718"
}

$animations = @(
    @{
        name = "idle"
        fps = 5
        loop = $true
        frames = @(
            (Frame 16.5 29.2 29.5 30.6 39.5 25.6 18.4 41 2.2 30.6 41 -2.0 11 31.4 0.4 $true)
            (Frame 16.8 28.8 29.6 30.3 39.8 25.3 18.7 41 2.0 30.8 41 -1.8 11.4 31.0 0.3 $true)
            (Frame 16.2 29.8 29.3 31.0 39.0 26.0 18.0 41 2.5 30.2 41 -2.3 10.8 32.0 0.5 $true)
            (Frame 16.5 29.3 29.5 30.7 39.4 25.8 18.4 41 2.2 30.5 41 -2.0 11.1 31.5 0.4 $true)
        )
    }
    @{
        name = "move"
        fps = 9
        loop = $true
        frames = @(
            (Frame 16.2 29.4 29.0 30.8 39.0 25.7 19.8 41 3.4 29.4 41 -2.8 10.8 31.7 0.4 $true)
            (Frame 16.6 28.9 29.4 30.4 39.6 25.3 20.5 41 2.4 30.2 41 -1.9 11.0 31.0 0.3 $true)
            (Frame 17.2 28.7 30.0 30.2 40.3 25.0 19.2 41 1.5 31.8 41 -0.8 11.6 30.6 0.2 $true)
            (Frame 17.0 29.0 30.3 30.5 40.0 25.2 18.2 41 1.2 33.0 41 -0.3 11.8 30.8 0.2 $true)
            (Frame 16.4 29.6 29.6 31.0 39.2 25.8 17.6 41 1.5 32.4 41 0.2 11.2 31.7 0.3 $true)
            (Frame 16.2 29.1 29.1 30.6 39.0 25.4 18.6 41 2.1 31.0 41 -0.6 10.9 31.1 0.3 $true)
        )
    }
    @{
        name = "dash"
        fps = 10
        loop = $false
        frames = @(
            (Frame 16.4 29.2 29.4 30.6 39.4 25.6 18.8 41 2.4 30.8 41 -2.2 11.0 31.4 0.4 $true)
            (Frame 15.6 30.2 29.0 31.2 39.2 26.9 18.2 41 3.6 30.4 41 -3.0 10.5 32.4 1.0 $true)
            (Frame 14.8 31.2 28.7 31.9 39.0 28.3 17.6 41 4.8 30.0 41 -4.1 10.0 33.2 1.8 $true)
            (Frame 17.8 29.1 31.8 30.0 45.4 24.3 25.6 41 0.9 31.8 41 -2.0 12.8 29.8 2.2 $true)
            (Frame 21.2 27.7 34.5 28.6 48.6 22.1 31.6 41 -1.2 34.2 41 -1.0 14.8 28.6 2.8 $true)
            (Frame 22.2 28.1 35.0 29.0 47.0 22.7 30.8 41 -0.4 35.0 41 -0.3 15.2 29.0 1.9 $true)
            (Frame 20.2 28.9 33.2 29.8 43.8 24.0 27.4 41 0.7 33.8 41 -1.1 14.2 29.8 0.8 $true)
            (Frame 18.0 29.3 31.0 30.4 40.8 25.0 23.2 41 1.7 32.2 41 -1.7 12.8 30.8 0.4 $true)
        )
    }
    @{
        name = "attack"
        fps = 11
        loop = $false
        frames = @(
            (Frame 16.5 29.2 29.5 30.6 39.5 25.6 18.4 41 2.2 30.6 41 -2.0 11 31.4 0.4 $true)
            (Frame 15.6 30.0 29.1 31.2 39.2 26.8 18.0 41 3.3 30.2 41 -2.9 10.6 32.2 1.0 $true)
            (Frame 14.8 30.9 28.8 31.8 39.0 28.0 17.6 41 4.4 30.0 41 -3.7 10.0 32.8 1.8 $true)
            (Frame 17.8 29.1 31.2 30.4 44.8 24.5 24.8 41 0.8 31.8 41 -1.9 12.6 30.0 3.8 $true)
            (Frame 20.8 27.8 33.4 29.0 47.6 22.9 29.6 41 -0.7 33.8 41 -1.1 14.2 28.9 5.0 $true)
            (Frame 22.2 28.4 34.0 29.7 46.4 23.9 28.8 41 0.0 34.5 41 -0.6 14.9 29.7 2.6 $true)
            (Frame 19.8 29.4 32.1 30.6 42.8 25.2 25.8 41 1.2 33.2 41 -1.2 13.4 31.0 0.9 $true)
            (Frame 17.4 29.4 30.2 30.8 39.8 25.7 21.0 41 1.9 31.5 41 -1.6 11.8 31.4 0.4 $true)
        )
    }
    @{
        name = "pounce"
        fps = 10
        loop = $false
        frames = @(
            (Frame 16.4 29.2 29.4 30.6 39.4 25.6 18.8 41 2.4 30.8 41 -2.2 11.0 31.4 0.5 $true)
            (Frame 15.6 30.2 29.0 31.2 39.2 26.9 18.2 41 3.6 30.4 41 -3.0 10.5 32.4 1.3 $true)
            (Frame 14.7 31.2 28.7 31.9 39.0 28.4 17.5 41 4.8 30.0 41 -4.1 10.0 33.2 2.4 $true)
            (Frame 17.9 29.1 31.9 30.0 45.8 24.2 25.8 41 0.8 31.8 41 -2.1 12.9 29.7 4.2 $true)
            (Frame 21.4 27.6 34.8 28.5 48.8 22.0 31.8 41 -1.2 34.3 41 -1.0 14.9 28.4 5.8 $true)
            (Frame 22.4 28.1 35.2 29.0 47.2 22.5 31.0 41 -0.3 35.1 41 -0.3 15.3 28.9 3.8 $true)
            (Frame 20.3 28.9 33.4 29.8 44.0 23.9 27.6 41 0.7 33.9 41 -1.1 14.3 29.8 1.4 $true)
            (Frame 18.1 29.3 31.1 30.4 40.8 25.0 23.1 41 1.7 32.1 41 -1.7 12.9 30.8 0.6 $true)
        )
    }
    @{
        name = "hit"
        fps = 9
        loop = $false
        frames = @(
            (Frame 15.2 28.8 28.2 30.0 37.4 24.8 17.6 41 1.1 30.2 41 -1.0 10.0 30.4 0.3 $true)
            (Frame 14.2 28.2 27.5 29.4 36.4 24.3 17.0 41 0.6 30.6 41 -0.6 9.4 29.7 0.2 $true)
            (Frame 16.0 29.1 29.0 30.3 38.8 25.2 18.0 41 1.5 30.6 41 -1.4 10.5 31.0 0.3 $true)
        )
    }
    @{
        name = "launch"
        fps = 8
        loop = $false
        frames = @(
            (Frame 18.4 25.8 29.0 28.2 38.5 23.2 21.2 36.2 1.6 31.5 35.2 -1.4 12.2 27.1 1.0 $true)
            (Frame 19.0 25.2 29.6 27.8 39.0 22.7 22.0 35.4 1.2 32.0 34.4 -1.0 12.8 26.4 0.8 $true)
        )
    }
    @{
        name = "down"
        fps = 6
        loop = $true
        frames = @(
            (Frame 20.8 35.0 29.8 36.4 17.5 34.2 31.4 40.2 0.5 39.2 40.5 -0.4 12.0 37.0 0.0 $false)
            (Frame 20.2 35.4 29.1 36.8 16.8 34.6 30.8 40.4 0.4 38.5 40.6 -0.4 11.4 37.3 0.0 $false)
        )
    }
    @{
        name = "get_up"
        fps = 8
        loop = $false
        frames = @(
            (Frame 20.2 35.4 29.1 36.8 16.8 34.6 30.8 40.4 0.4 38.5 40.6 -0.4 11.4 37.3 0.0 $false)
            (Frame 18.8 32.8 29.0 35.2 21.0 31.0 27.8 40.2 1.2 34.8 40.8 -0.8 11.8 34.8 0.2 $true)
            (Frame 17.6 30.6 29.4 33.2 30.8 28.4 23.6 41 1.9 32.1 41 -1.2 11.5 33.0 0.3 $true)
            (Frame 16.8 29.4 29.5 31.2 36.8 26.5 20.8 41 2.1 31.0 41 -1.6 11.3 32.0 0.4 $true)
            (Frame 16.5 29.2 29.5 30.6 39.5 25.6 18.4 41 2.2 30.6 41 -2.0 11 31.4 0.4 $true)
        )
    }
    @{
        name = "grabbed"
        fps = 6
        loop = $true
        frames = @(
            (Frame 18.5 27.0 30.8 28.6 40.5 23.8 22.4 39.6 0.8 33.8 39.9 -0.7 12.6 27.8 0.6 $true)
            (Frame 18.9 27.8 31.0 29.2 40.7 24.4 22.8 39.8 0.8 34.0 40.0 -0.7 12.8 28.4 0.6 $true)
        )
    }
    @{
        name = "death"
        fps = 8
        loop = $false
        frames = @(
            (Frame 15.8 28.9 28.6 30.1 38.2 25.0 17.8 41 1.3 30.4 41 -1.2 10.2 30.8 0.4 $true)
            (Frame 17.4 31.4 29.3 34.4 24.0 31.6 23.6 40.8 1.4 35.0 40.9 -1.1 11.8 34.8 0.1 $false)
            (Frame 20.0 34.2 29.6 36.2 18.2 33.6 30.8 40.2 0.7 38.2 40.6 -0.5 12.0 36.8 0.0 $false)
            (Frame 20.2 35.4 29.1 36.8 16.8 34.6 30.8 40.4 0.4 38.5 40.6 -0.4 11.4 37.3 0.0 $false)
        )
    }
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$artDir = $PSScriptRoot
$sceneDir = Join-Path $repoRoot "scenes\enemies"
$scenePath = Join-Path $sceneDir "dungeon_hound_sprite.tscn"
$manifestPath = Join-Path $artDir "dungeon_hound_manifest.json"
$previewPath = Join-Path $artDir "dungeon_hound_preview_4x.png"
$readmePath = Join-Path $artDir "README.md"

New-Item -ItemType Directory -Force -Path $artDir | Out-Null
New-Item -ItemType Directory -Force -Path $sceneDir | Out-Null

$manifestAnimations = @()
$sheetMeta = @()

foreach ($animation in $animations) {
    $sheet = New-SheetBitmap ($frameWidth * $animation.frames.Count) $frameHeight
    for ($i = 0; $i -lt $animation.frames.Count; $i++) {
        $frameBitmap = New-SheetBitmap $frameWidth $frameHeight
        DrawHound $frameBitmap.Graphics $animation.frames[$i] $palette
        $sheet.Graphics.DrawImageUnscaled($frameBitmap.Bitmap, $i * $frameWidth, 0)
        $frameBitmap.Graphics.Dispose()
        $frameBitmap.Bitmap.Dispose()
    }

    $fileName = "dungeon_hound_{0}_strip.png" -f $animation.name
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
        path = "res://art/enemies/dungeon_hound/$fileName"
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
    name = "dungeon_hound"
    display_name = "Dungeon Hound"
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
        "low-profile hound silhouette with readable pounce and bite poses"
    )
    animations = $manifestAnimations
}
Write-Utf8NoBom $manifestPath ($manifest | ConvertTo-Json -Depth 5)

$readmeLines = @(
    "# Dungeon Hound"
    ""
    "- Display name: Dungeon Hound"
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
[sub_resource type="SpriteFrames" id="SpriteFrames_dungeon_hound"]
animations = [$($animationBlocks -join ",`r`n")]

"@

$sceneText = @"
[gd_scene load_steps=$($sheetMeta.Count + $atlasIndex + 2) format=3]

$($extLines -join "`r`n")
$($subLines -join "`r`n")
$spriteFramesBlock
[node name="DungeonHoundSprite" type="Node2D"]

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
position = Vector2(0, 0)
sprite_frames = SubResource("SpriteFrames_dungeon_hound")
animation = &"idle"
frame = 0
centered = true
"@

Write-Utf8NoBom $scenePath $sceneText
