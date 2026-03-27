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
    [double]$ktx, [double]$kty,
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
        knife_tip = V $ktx $kty
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
        return V 0 -1
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

function DrawLeg($graphics, $hip, $foot, [double]$bend, [System.Drawing.Color]$legColor, [System.Drawing.Color]$bootColor, [System.Drawing.Color]$outlineColor) {
    $knee = BendPoint $hip $foot $bend
    DrawCapsuleSegment $graphics $hip $knee 4.2 $legColor $outlineColor
    DrawCapsuleSegment $graphics $knee $foot 4.0 $legColor $outlineColor
    FillEllipse2D $graphics $bootColor $outlineColor ($foot.X - 3.5) ($foot.Y - 2.5) 7 4.5
}

function DrawArm($graphics, $shoulder, $hand, [double]$bend, [System.Drawing.Color]$armColor, [System.Drawing.Color]$gloveColor, [System.Drawing.Color]$outlineColor) {
    $elbow = BendPoint $shoulder $hand $bend
    DrawCapsuleSegment $graphics $shoulder $elbow 3.8 $armColor $outlineColor
    DrawCapsuleSegment $graphics $elbow $hand 3.5 $armColor $outlineColor
    FillEllipse2D $graphics $gloveColor $outlineColor ($hand.X - 2.1) ($hand.Y - 2.1) 4.2 4.2
}

function DrawKnife($graphics, $hand, $tip, [System.Drawing.Color]$metalColor, [System.Drawing.Color]$metalDark, [System.Drawing.Color]$handleColor, [System.Drawing.Color]$outlineColor) {
    $dir = NormalizeVec (SubVec $tip $hand)
    $normal = PerpRight $dir
    $bladeBase = AddVec $hand (MulVec $dir 2.0)
    $bladeWidth = 1.4

    $bladePoints = @(
        (AddVec $bladeBase (MulVec $normal $bladeWidth))
        (AddVec $tip (MulVec $normal 0.6))
        (AddVec $tip (MulVec $normal (-0.6)))
        (AddVec $bladeBase (MulVec $normal (-$bladeWidth)))
    )
    FillPolygon2D $graphics $metalColor $outlineColor $bladePoints

    $spinePoints = @(
        (AddVec $bladeBase (MulVec $normal 0.2))
        (AddVec $tip (MulVec $normal 0.0))
        (AddVec $tip (MulVec $normal (-0.3)))
        (AddVec $bladeBase (MulVec $normal (-0.5)))
    )
    FillPolygon2D $graphics $metalDark $metalDark $spinePoints

    $handleEnd = AddVec $hand (MulVec $dir (-2.0))
    DrawCapsuleSegment $graphics $handleEnd $hand 2.8 $handleColor $outlineColor
}

function DrawBody($graphics, $pose, $palette) {
    $axis = NormalizeVec (SubVec $pose.chest $pose.pelvis)
    $right = PerpRight $axis

    $frontShoulder = AddVec $pose.chest (AddVec (MulVec $axis 0.8) (MulVec $right 3.1))
    $backShoulder = AddVec $pose.chest (AddVec (MulVec $axis 0.4) (MulVec $right -2.4))
    $frontHip = AddVec $pose.pelvis (MulVec $right 2.0)
    $backHip = AddVec $pose.pelvis (MulVec $right -1.7)

    DrawLeg $graphics $backHip $pose.back_foot $pose.back_leg_bend $palette.leg_back $palette.boot_back $palette.outline
    DrawArm $graphics $backShoulder $pose.back_hand $pose.back_arm_bend $palette.arm_back $palette.glove_back $palette.outline

    $torsoTop = $pose.chest
    $torsoBottom = $pose.pelvis
    $torsoPoints = @(
        (AddVec $torsoTop (MulVec $right 4.5))
        (AddVec $torsoTop (MulVec $right -4.0))
        (AddVec $torsoBottom (MulVec $right -3.7))
        (AddVec $torsoBottom (MulVec $right 3.9))
    )
    FillPolygon2D $graphics $palette.cloth_main $palette.outline $torsoPoints

    $leatherPoints = @(
        (AddVec $torsoTop (AddVec (MulVec $right 2.5) (MulVec $axis 1.0)))
        (AddVec $torsoTop (AddVec (MulVec $right -1.6) (MulVec $axis 0.7)))
        (AddVec $torsoBottom (AddVec (MulVec $right -1.5) (MulVec $axis -0.8)))
        (AddVec $torsoBottom (AddVec (MulVec $right 2.2) (MulVec $axis -0.5)))
    )
    FillPolygon2D $graphics $palette.leather_main $palette.outline $leatherPoints

    $padCenter = AddVec $frontShoulder (MulVec $right 1.2)
    FillEllipse2D $graphics $palette.pad_main $palette.outline ($padCenter.X - 3.0) ($padCenter.Y - 2.3) 6.0 4.6

    FillRect2D $graphics $palette.belt ($pose.pelvis.X - 5.0) ($pose.pelvis.Y - 2.0) 10.0 2.0
    $clothPoints = @(
        (AddVec $pose.pelvis (MulVec $right 0.8))
        (AddVec $pose.pelvis (MulVec $right -1.2))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -1.5) (MulVec $right -0.4)))
        (AddVec $pose.pelvis (AddVec (MulVec $axis -4.8) (MulVec $right 1.8)))
    )
    FillPolygon2D $graphics $palette.accent_red $palette.outline $clothPoints

    $hoodX = $pose.head.X
    $hoodY = $pose.head.Y
    $hoodPoints = @(
        (V ($hoodX - 4.6) ($hoodY - 1.4))
        (V ($hoodX - 3.0) ($hoodY - 5.2))
        (V ($hoodX + 1.4) ($hoodY - 6.2))
        (V ($hoodX + 5.0) ($hoodY - 2.2))
        (V ($hoodX + 4.0) ($hoodY + 2.2))
        (V ($hoodX + 1.8) ($hoodY + 5.0))
        (V ($hoodX - 2.6) ($hoodY + 4.2))
        (V ($hoodX - 5.2) ($hoodY + 1.2))
    )
    FillPolygon2D $graphics $palette.hood_main $palette.outline $hoodPoints

    $faceShadowPoints = @(
        (V ($hoodX - 1.8) ($hoodY - 2.6))
        (V ($hoodX + 2.8) ($hoodY - 2.4))
        (V ($hoodX + 3.2) ($hoodY + 1.6))
        (V ($hoodX - 0.5) ($hoodY + 2.8))
        (V ($hoodX - 2.2) ($hoodY + 1.2))
    )
    FillPolygon2D $graphics $palette.face_shadow $palette.face_shadow $faceShadowPoints

    if ($pose.eye) {
        DrawPixel $graphics $palette.eye ($hoodX + 1.0) ($hoodY - 0.5)
        DrawPixel $graphics $palette.eye_glow ($hoodX + 2.0) ($hoodY - 0.5)
    }

    DrawLeg $graphics $frontHip $pose.front_foot $pose.front_leg_bend $palette.leg_front $palette.boot_front $palette.outline
    DrawArm $graphics $frontShoulder $pose.front_hand $pose.front_arm_bend $palette.arm_front $palette.glove_front $palette.outline
    DrawKnife $graphics $pose.front_hand $pose.knife_tip $palette.metal_main $palette.metal_dark $palette.handle $palette.outline
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
    outline = HexColor "#17120f"
    hood_main = HexColor "#3b4137"
    face_shadow = HexColor "#221d19"
    cloth_main = HexColor "#5f664b"
    leather_main = HexColor "#6c5134"
    pad_main = HexColor "#756344"
    belt = HexColor "#4a3322"
    accent_red = HexColor "#6b362d"
    arm_back = HexColor "#4d513d"
    arm_front = HexColor "#6a7353"
    glove_back = HexColor "#7d6f51"
    glove_front = HexColor "#8f7f5d"
    leg_back = HexColor "#4a4d3b"
    leg_front = HexColor "#60664d"
    boot_back = HexColor "#30261d"
    boot_front = HexColor "#3e3024"
    metal_main = HexColor "#8f8c86"
    metal_dark = HexColor "#5e5b56"
    handle = HexColor "#594128"
    eye = HexColor "#dde9f5"
    eye_glow = HexColor "#a9c8e5"
}

$animations = @(
    @{
        name = "idle"
        fps = 5
        loop = $true
        frames = @(
            (Frame 24 24 23 33 25 17 33 31 -1.2 19 31 0.8 29 41 3.2 21 41 -2.2 38 32)
            (Frame 24 23 23 32 25 16 33 30 -1.0 19 30 0.9 29 41 3.0 21 41 -2.0 38 31)
            (Frame 24 25 22.5 34 25 18 32 32 -1.8 19 32 0.6 28 41 3.6 21 41 -2.4 37 34)
            (Frame 24 24 23 33 25 17.5 33 31 -0.8 20 31 0.7 28 41 2.9 22 41 -1.6 38 33)
        )
    }
    @{
        name = "move"
        fps = 8
        loop = $true
        frames = @(
            (Frame 23.5 25 23 34 24.5 18 33 31 -1.0 18 32 0.8 30 41 4.0 20 41 -3.0 38 33)
            (Frame 24 24 24 33 25 17 34 30 -0.8 20 31 0.9 29 41 2.6 21 41 -2.0 39 32)
            (Frame 25 24 24.5 33 26 17 34 30 -0.6 21 31 1.0 28 41 2.0 22 41 -1.2 39 32)
            (Frame 24.5 24 24 33 25.5 17 33 30 -0.7 21 31 0.8 27 41 1.8 24 41 -0.7 38 32)
            (Frame 23.5 25 23.5 34 24.5 18 32 31 -1.0 21 32 0.8 26 41 1.0 27 41 0.6 37 33)
            (Frame 23.5 24 23 33 24.5 17 32 30 -0.8 20 31 0.7 27 41 1.8 24 41 -0.8 37 32)
        )
    }
    @{
        name = "attack"
        fps = 10
        loop = $false
        frames = @(
            (Frame 24 24 23 33 25 17 33 31 -1.2 19 31 0.8 29 41 3.2 21 41 -2.2 38 32)
            (Frame 22.5 25 21.5 34 23.5 18.5 24 29 -4.0 18 31 0.8 28 41 4.0 20 41 -2.6 17 30)
            (Frame 21.5 26 20.5 35 22.5 20 19 26 -5.8 18 31 0.7 27 41 4.6 20 41 -3.2 11 27)
            (Frame 22 25 21.5 34 23 18.5 28 27 -2.4 19 31 0.6 27 41 3.8 20 41 -2.8 33 26)
            (Frame 24.5 23.5 23 33 24.5 16.5 38 28 0.4 20 31 0.4 28 41 2.4 21 41 -2.0 45 27)
            (Frame 27 24.5 25.5 34 27.5 18 40 31 1.6 22 32 0.3 30 41 2.0 22 41 -1.6 46 33)
            (Frame 26 25 24.5 34 26.5 18.5 36 32 0.8 22 32 0.4 29 41 2.3 22 41 -1.4 41 34)
            (Frame 24 24 23 33 25 17.5 33 31 -0.7 20 31 0.6 28 41 3.0 22 41 -1.6 38 32)
        )
    }
    @{
        name = "hit"
        fps = 9
        loop = $false
        frames = @(
            (Frame 22 23 21 32 22 16 35 29 0.7 17 28 -1.0 28 41 2.4 21 41 -1.6 40 30)
            (Frame 21 22 20 31 21 15 37 27 1.2 16 26 -1.4 27 41 1.6 21 41 -1.0 42 26)
            (Frame 23 24 22 33 23 17 34 31 -0.6 18 30 0.5 28 41 2.6 21 41 -1.5 39 32)
        )
    }
    @{
        name = "launch"
        fps = 8
        loop = $false
        frames = @(
            (Frame 26 22 21 30 30 17 35 23 1.6 19 24 -1.2 24 36 1.4 18 35 -1.4 40 21)
            (Frame 27 21 20 29 31 16 37 22 1.2 18 22 -1.0 25 35 1.2 17 34 -1.2 41 20)
        )
    }
    @{
        name = "down"
        fps = 6
        loop = $true
        frames = @(
            (Frame 22 34 29 36 18 33 34 36 0.4 25 39 -0.4 36 40 0.8 28 41 -0.8 39 37)
            (Frame 21 35 28 37 17 34 33 37 0.4 25 39 -0.2 35 40 0.6 28 41 -0.6 38 38)
        )
    }
    @{
        name = "get_up"
        fps = 8
        loop = $false
        frames = @(
            (Frame 21 35 28 37 17 34 33 37 0.4 25 39 -0.2 35 40 0.6 28 41 -0.6 38 38)
            (Frame 21 31 27 36 18 29 24 34 -1.6 21 37 0.5 33 40 1.4 28 41 -0.9 31 34)
            (Frame 23 28 25 35 22 23 30 32 -1.4 21 33 0.6 27 41 2.3 22 40 -1.6 35 31)
            (Frame 24 26 24 34 25 20 32 31 -1.1 20 31 0.7 26 41 2.8 21 41 -1.8 37 31)
            (Frame 24 24 23 33 25 17 33 31 -1.0 19 31 0.8 29 41 3.2 21 41 -2.2 38 32)
        )
    }
    @{
        name = "grabbed"
        fps = 6
        loop = $true
        frames = @(
            (Frame 24 24 23 33 25 17 29 27 -0.4 19 28 0.3 28 41 2.6 21 41 -1.8 33 26)
            (Frame 24 25 23 34 25 18 30 28 -0.2 20 29 0.2 28 41 2.8 21 41 -1.9 34 27)
        )
    }
    @{
        name = "death"
        fps = 8
        loop = $false
        frames = @(
            (Frame 22 24 21 33 22 17 34 30 0.8 17 29 -0.8 28 41 2.4 21 41 -1.8 39 30)
            (Frame 23 27 22 35 24 21 31 35 -0.4 18 33 0.4 26 41 3.0 20 41 -2.2 35 37)
            (Frame 21 31 27 36 18 29 33 36 0.6 22 37 -0.2 35 40 1.0 28 41 -0.8 37 37)
            (Frame 20.5 35 28 37.5 16.5 34 34 37 0.5 24 39 -0.2 36 40 0.6 28 41 -0.5 39 38)
        )
    }
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$artDir = $PSScriptRoot
$sceneDir = Join-Path $repoRoot "scenes\enemies"
$scenePath = Join-Path $sceneDir "dungeon_knifeman_sprite.tscn"
$manifestPath = Join-Path $artDir "dungeon_knifeman_manifest.json"
$previewPath = Join-Path $artDir "dungeon_knifeman_preview_4x.png"
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

    $fileName = "dungeon_knifeman_{0}_strip.png" -f $animation.name
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
        path = "res://art/enemies/dungeon_knifeman/$fileName"
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
    name = "dungeon_knifeman"
    display_name = "Dungeon Knifeman"
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
    )
    animations = $manifestAnimations
}
Write-Utf8NoBom $manifestPath ($manifest | ConvertTo-Json -Depth 5)

$readmeLines = @(
    "# Dungeon Knifeman"
    ""
    "- Display name: Dungeon Knifeman"
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
[sub_resource type="SpriteFrames" id="SpriteFrames_dungeon_knifeman"]
animations = [$($animationBlocks -join ",`r`n")]

"@

$sceneText = @"
[gd_scene load_steps=$($sheetMeta.Count + $atlasIndex + 2) format=3]

$($extLines -join "`r`n")
$($subLines -join "`r`n")
$spriteFramesBlock
[node name="DungeonKnifemanSprite" type="Node2D"]

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
position = Vector2(0, 0)
sprite_frames = SubResource("SpriteFrames_dungeon_knifeman")
animation = &"idle"
frame = 0
centered = true
"@

Write-Utf8NoBom $scenePath $sceneText
