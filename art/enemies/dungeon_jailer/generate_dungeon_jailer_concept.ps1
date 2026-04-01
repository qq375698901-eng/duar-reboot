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

function Pose(
    [double]$cx, [double]$cy,
    [double]$px, [double]$py,
    [double]$hx, [double]$hy,
    [double]$fhx, [double]$fhy, [double]$fab,
    [double]$bhx, [double]$bhy, [double]$bab,
    [double]$ffx, [double]$ffy, [double]$flb,
    [double]$bfx, [double]$bfy, [double]$blb,
    [double]$wtx, [double]$wty,
    [double]$visor = 0.4,
    [double]$fork_open = 1.0,
    [double]$coat = 0.0,
    [double]$keys = 0.0
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
        visor = $visor
        fork_open = $fork_open
        coat = $coat
        keys = $keys
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

function AlphaColor([System.Drawing.Color]$color, [double]$factor) {
    $alpha = [Math]::Max(0, [Math]::Min(255, [int]([double]$color.A * $factor)))
    [System.Drawing.Color]::FromArgb($alpha, $color.R, $color.G, $color.B)
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

function DrawLine2D($graphics, [System.Drawing.Color]$color, [double]$width, [double]$x1, [double]$y1, [double]$x2, [double]$y2) {
    $pen = New-Object System.Drawing.Pen($color, [float]$width)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($pen, [float]$x1, [float]$y1, [float]$x2, [float]$y2)
    $pen.Dispose()
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
    DrawCapsuleSegment $graphics $hip $knee 8.0 $legColor $outlineColor
    DrawCapsuleSegment $graphics $knee $foot 7.0 $legColor $outlineColor
    FillEllipse2D $graphics $bootColor $outlineColor ($foot.X - 6.0) ($foot.Y - 4.0) 14.0 8.0
}

function DrawArm($graphics, $shoulder, $hand, [double]$bend, [System.Drawing.Color]$armColor, [System.Drawing.Color]$gloveColor, [System.Drawing.Color]$outlineColor) {
    $elbow = BendPoint $shoulder $hand $bend
    DrawCapsuleSegment $graphics $shoulder $elbow 6.5 $armColor $outlineColor
    DrawCapsuleSegment $graphics $elbow $hand 6.0 $armColor $outlineColor
    FillEllipse2D $graphics $gloveColor $outlineColor ($hand.X - 3.6) ($hand.Y - 3.6) 7.2 7.2
}

function DrawCageFork($graphics, $lowerGrip, $upperGrip, $tip, [double]$forkOpen, $palette) {
    $shaftDirection = NormalizeVec (SubVec $tip $upperGrip)
    $shaftBack = AddVec $lowerGrip (MulVec $shaftDirection -54.0)
    DrawCapsuleSegment $graphics $shaftBack $tip 4.0 $palette.weapon_wood $palette.outline

    $shaftNormal = PerpRight $shaftDirection
    $forkBase = AddVec $tip (MulVec $shaftDirection -18.0)
    $forkOpenPx = 7.0 + (6.0 * $forkOpen)
    $forkReach = 18.0
    $leftProngBase = AddVec $forkBase (MulVec $shaftNormal $forkOpenPx)
    $rightProngBase = AddVec $forkBase (MulVec $shaftNormal (-$forkOpenPx))
    $leftProngTip = AddVec $tip (MulVec $shaftNormal $forkOpenPx)
    $rightProngTip = AddVec $tip (MulVec $shaftNormal (-$forkOpenPx))
    $leftHook = AddVec $leftProngTip (MulVec $shaftDirection $forkReach)
    $rightHook = AddVec $rightProngTip (MulVec $shaftDirection $forkReach)

    DrawCapsuleSegment $graphics $leftProngBase $leftProngTip 5.0 $palette.weapon_steel $palette.outline
    DrawCapsuleSegment $graphics $rightProngBase $rightProngTip 5.0 $palette.weapon_steel $palette.outline
    DrawCapsuleSegment $graphics $leftProngTip $leftHook 4.0 $palette.weapon_steel $palette.outline
    DrawCapsuleSegment $graphics $rightProngTip $rightHook 4.0 $palette.weapon_steel $palette.outline
    DrawCapsuleSegment $graphics $leftProngBase $rightProngBase 4.5 $palette.weapon_steel_dark $palette.outline
    FillEllipse2D $graphics $palette.weapon_rivet $palette.outline ($forkBase.X - 3.0) ($forkBase.Y - 3.0) 6.0 6.0
}

function DrawHelmetHead($graphics, $center, [double]$visorGlow, $palette) {
    FillEllipse2D $graphics $palette.helmet_shadow $palette.outline ($center.X - 12.0) ($center.Y - 10.0) 24.0 22.0
    FillEllipse2D $graphics $palette.helmet_main $palette.outline ($center.X - 11.0) ($center.Y - 13.0) 22.0 20.0
    FillRect2D $graphics $palette.helmet_shadow ($center.X - 10.0) ($center.Y - 1.0) 20.0 9.0
    FillRect2D $graphics $palette.helmet_trim ($center.X - 13.0) ($center.Y - 13.0) 26.0 3.0
    FillRect2D $graphics $palette.face_shadow ($center.X - 7.0) ($center.Y - 4.0) 14.0 10.0

    $visorWidth = 9.0
    $visorColor = if ($visorGlow -gt 0.55) { $palette.visor_hot } elseif ($visorGlow -gt 0.25) { $palette.visor_mid } else { $palette.visor_dim }
    FillRect2D $graphics $visorColor ($center.X - ($visorWidth / 2.0)) ($center.Y - 1.0) $visorWidth 2.0
}

function DrawKeyRing($graphics, $anchor, [double]$swing, $palette) {
    $ring = AddVec $anchor (V (2.0 + ($swing * 4.0)) (10.0 + ([Math]::Abs($swing) * 2.0)))
    DrawLine2D $graphics $palette.chain 1.5 $anchor.X $anchor.Y $ring.X $ring.Y
    FillEllipse2D $graphics $palette.weapon_steel $palette.outline ($ring.X - 3.5) ($ring.Y - 3.5) 7.0 7.0
    DrawLine2D $graphics $palette.chain 1.4 $ring.X ($ring.Y + 2.5) ($ring.X + 7.0) ($ring.Y + 10.0)
    DrawLine2D $graphics $palette.chain 1.4 $ring.X ($ring.Y + 2.5) ($ring.X - 4.0) ($ring.Y + 11.0)
}

function DrawJailerFrame($graphics, $pose, [double]$originX, [double]$originY, $palette) {
    function T($point, [double]$ox, [double]$oy) {
        V ($point.X + $ox) ($point.Y + $oy)
    }

    $chest = T $pose.chest $originX $originY
    $pelvis = T $pose.pelvis $originX $originY
    $head = T $pose.head $originX $originY
    $frontHand = T $pose.front_hand $originX $originY
    $backHand = T $pose.back_hand $originX $originY
    $frontFoot = T $pose.front_foot $originX $originY
    $backFoot = T $pose.back_foot $originX $originY
    $weaponTip = T $pose.weapon_tip $originX $originY

    $axis = NormalizeVec (SubVec $chest $pelvis)
    $right = PerpRight $axis

    $frontShoulder = AddVec $chest (AddVec (MulVec $axis 2.0) (MulVec $right 6.5))
    $backShoulder = AddVec $chest (AddVec (MulVec $axis 1.0) (MulVec $right -5.0))
    $frontHip = AddVec $pelvis (MulVec $right 4.6)
    $backHip = AddVec $pelvis (MulVec $right -3.8)
    $beltCenter = AddVec $pelvis (MulVec $axis 1.0)

    FillEllipse2D $graphics (AlphaColor $palette.shadow 0.7) (AlphaColor $palette.shadow 0.2) ($pelvis.X - 22.0) ($frontFoot.Y - 5.0) 52.0 10.0

    DrawLeg $graphics $backHip $backFoot $pose.back_leg_bend $palette.leg_back $palette.boot_back $palette.outline
    DrawArm $graphics $backShoulder $backHand $pose.back_arm_bend $palette.arm_back $palette.glove_back $palette.outline

    $cloakTop = AddVec $chest (MulVec $axis -1.5)
    $cloakLeft = AddVec $pelvis (MulVec $right (-11.0 - ($pose.coat * 3.0)))
    $cloakRight = AddVec $pelvis (MulVec $right (9.0 + ($pose.coat * 2.0)))
    $cloakBottom = AddVec $pelvis (AddVec (MulVec $axis -24.0) (MulVec $right ($pose.coat * 10.0)))
    $cloakPoints = @(
        (AddVec $cloakTop (MulVec $right 7.0))
        (AddVec $cloakTop (MulVec $right -7.5))
        $cloakLeft
        $cloakBottom
        $cloakRight
    )
    FillPolygon2D $graphics $palette.cloak_back $palette.outline $cloakPoints

    $torsoTop = AddVec $chest (MulVec $axis 5.0)
    $torsoBottom = AddVec $pelvis (MulVec $axis -3.0)
    $torsoPoints = @(
        (AddVec $torsoTop (MulVec $right 9.5))
        (AddVec $torsoTop (MulVec $right -8.5))
        (AddVec $torsoBottom (MulVec $right -7.0))
        (AddVec $torsoBottom (MulVec $right 8.0))
    )
    FillPolygon2D $graphics $palette.tunic $palette.outline $torsoPoints

    $chestPlatePoints = @(
        (AddVec $chest (AddVec (MulVec $axis 4.0) (MulVec $right 6.0)))
        (AddVec $chest (AddVec (MulVec $axis 4.0) (MulVec $right -6.2)))
        (AddVec $pelvis (AddVec (MulVec $axis 0.5) (MulVec $right -4.5)))
        (AddVec $pelvis (AddVec (MulVec $axis 0.5) (MulVec $right 5.0)))
    )
    FillPolygon2D $graphics $palette.armor_main $palette.outline $chestPlatePoints

    FillRect2D $graphics $palette.belt ($beltCenter.X - 10.0) ($beltCenter.Y - 2.0) 20.0 4.0
    FillRect2D $graphics $palette.buckle ($beltCenter.X - 3.0) ($beltCenter.Y - 2.5) 6.0 5.0

    $gorgetPoints = @(
        (AddVec $chest (MulVec $right 8.0))
        (AddVec $chest (MulVec $right -8.0))
        (AddVec $chest (AddVec (MulVec $axis -5.0) (MulVec $right -3.5)))
        (AddVec $chest (AddVec (MulVec $axis -5.0) (MulVec $right 4.0)))
    )
    FillPolygon2D $graphics $palette.armor_trim $palette.outline $gorgetPoints

    FillEllipse2D $graphics $palette.shoulder_plate $palette.outline ($frontShoulder.X - 7.0) ($frontShoulder.Y - 5.5) 14.0 11.0
    FillEllipse2D $graphics $palette.shoulder_plate_dark $palette.outline ($backShoulder.X - 6.5) ($backShoulder.Y - 5.0) 13.0 10.0

    DrawHelmetHead $graphics $head $pose.visor $palette

    DrawKeyRing $graphics (AddVec $beltCenter (MulVec $right -2.0)) $pose.keys $palette

    DrawLeg $graphics $frontHip $frontFoot $pose.front_leg_bend $palette.leg_front $palette.boot_front $palette.outline
    DrawArm $graphics $frontShoulder $frontHand $pose.front_arm_bend $palette.arm_front $palette.glove_front $palette.outline

    DrawCageFork $graphics $backHand $frontHand $weaponTip $pose.fork_open $palette
}

function Build-AnimationFrameMeta([string]$name, [int[]]$indices, [int]$fps, [bool]$loop) {
    [PSCustomObject]@{
        name = $name
        indices = $indices
        fps = $fps
        loop = $loop
        file = ("dungeon_jailer_{0}_strip.png" -f $name)
        path = ("res://art/enemies/dungeon_jailer/dungeon_jailer_{0}_strip.png" -f $name)
    }
}

function Save-AnimationStrip($sourceBitmap, [int]$frameWidth, [int]$frameHeight, $meta, [string]$outputDir) {
    $frameCount = $meta.indices.Count
    $stripWidth = $frameWidth * $frameCount
    $bitmap = New-Object System.Drawing.Bitmap -ArgumentList $stripWidth, $frameHeight, $pixelFormat
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed

    for ($frameIndex = 0; $frameIndex -lt $frameCount; $frameIndex++) {
        $sourceIndex = [int]$meta.indices[$frameIndex]
        $srcRect = New-Object System.Drawing.Rectangle -ArgumentList ($sourceIndex * $frameWidth), 0, $frameWidth, $frameHeight
        $dstRect = New-Object System.Drawing.Rectangle -ArgumentList ($frameIndex * $frameWidth), 0, $frameWidth, $frameHeight
        $graphics.DrawImage($sourceBitmap, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    }

    $path = Join-Path $outputDir $meta.file
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

function New-SpriteSceneText($sheetMeta, [int]$frameWidth, [int]$frameHeight, [string]$rootName, [string]$spriteFramesId) {
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
        for ($i = 0; $i -lt $sheet.indices.Count; $i++) {
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
[sub_resource type="SpriteFrames" id="$spriteFramesId"]
animations = [$($animationBlocks -join ",`r`n")]

"@

    @"
[gd_scene load_steps=$($sheetMeta.Count + $atlasIndex + 2) format=3]

$($extLines -join "`r`n")
$($subLines -join "`r`n")
$spriteFramesBlock
[node name="$rootName" type="Node2D"]

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
position = Vector2(0, 0)
sprite_frames = SubResource("$spriteFramesId")
animation = &"idle"
frame = 0
centered = true
"@
}

$artDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$conceptStripPath = Join-Path $artDir "dungeon_jailer_concept_strip.png"
$previewPath = Join-Path $artDir "dungeon_jailer_concept_preview_4x.png"
$manifestPath = Join-Path $artDir "dungeon_jailer_manifest.json"
$readmePath = Join-Path $artDir "README.md"
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $artDir))
$sceneDir = Join-Path $projectRoot "scenes\enemies"
$spriteScenePath = Join-Path $sceneDir "dungeon_jailer_sprite.tscn"

$frameWidth = 192
$frameHeight = 192
$frameCount = 4
$previewScale = 4
$sheetWidth = [int]($frameWidth * $frameCount)
$pixelFormat = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb

$palette = [ordered]@{
    outline = HexColor "#171310"
    shadow = HexColor "#0d0d0f" 170
    tunic = HexColor "#6f5d49"
    cloak_back = HexColor "#44362c"
    armor_main = HexColor "#7d807c"
    armor_trim = HexColor "#979a95"
    shoulder_plate = HexColor "#878a86"
    shoulder_plate_dark = HexColor "#626562"
    belt = HexColor "#3b2418"
    buckle = HexColor "#b59452"
    helmet_main = HexColor "#858884"
    helmet_shadow = HexColor "#666864"
    helmet_trim = HexColor "#989b96"
    face_shadow = HexColor "#2b211b"
    visor_dim = HexColor "#8e3c1f"
    visor_mid = HexColor "#c86b2a"
    visor_hot = HexColor "#ffb05a"
    arm_back = HexColor "#6f706d"
    arm_front = HexColor "#868884"
    glove_back = HexColor "#5d4634"
    glove_front = HexColor "#72533b"
    leg_back = HexColor "#585551"
    leg_front = HexColor "#6b6763"
    boot_back = HexColor "#30221a"
    boot_front = HexColor "#3a291e"
    weapon_wood = HexColor "#7a5635"
    weapon_steel = HexColor "#9ea29d"
    weapon_steel_dark = HexColor "#6f726f"
    weapon_rivet = HexColor "#c3b596"
    chain = HexColor "#8f8061"
}

$poses = @(
    (Pose 92 96 92 118 92 76 118 98 -14 101 108 10 104 145 -8 84 145 10 148 92 0.42 0.9 -0.1 -0.2),
    (Pose 92 95 91 117 91 75 121 94 -18 99 109 12 107 145 -10 80 145 9 156 88 0.56 1.2 0.2 0.15),
    (Pose 90 97 90 118 90 76 124 91 -22 102 110 10 101 145 -6 82 145 8 165 82 0.68 1.5 0.35 0.4),
    (Pose 94 96 93 118 93 76 122 103 -10 100 112 16 109 145 -12 86 145 7 150 118 0.48 1.05 -0.35 -0.45)
)

$sheet = New-Object System.Drawing.Bitmap -ArgumentList $sheetWidth, $frameHeight, $pixelFormat
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$graphics.Clear([System.Drawing.Color]::Transparent)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed

for ($i = 0; $i -lt $poses.Count; $i++) {
    DrawJailerFrame $graphics $poses[$i] ($i * $frameWidth) 0 $palette
}

$sheet.Save($conceptStripPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()

$sheetMeta = @(
    (Build-AnimationFrameMeta "idle" @(0, 1, 0, 1) 5 $true),
    (Build-AnimationFrameMeta "move" @(0, 1, 2, 1, 0, 3) 7 $true),
    (Build-AnimationFrameMeta "attack_1" @(1, 1, 2, 2, 3, 3, 2, 1) 9 $false),
    (Build-AnimationFrameMeta "attack_2" @(0, 1, 1, 2, 2, 2, 1, 1, 2, 2, 2, 3, 3, 3, 3, 2, 2, 1, 0, 0) 8 $false),
    (Build-AnimationFrameMeta "attack_3" @(0, 1, 2, 3, 3, 2, 1, 0) 8 $false),
    (Build-AnimationFrameMeta "hit" @(3, 2, 0) 8 $false),
    (Build-AnimationFrameMeta "launch" @(3, 0) 7 $false),
    (Build-AnimationFrameMeta "down" @(3, 3) 5 $true),
    (Build-AnimationFrameMeta "get_up" @(3, 2, 1, 0, 0) 7 $false),
    (Build-AnimationFrameMeta "grabbed" @(2, 2) 5 $true),
    (Build-AnimationFrameMeta "death" @(2, 3, 3, 3) 7 $false)
)

foreach ($animationMeta in $sheetMeta) {
    Save-AnimationStrip $sheet $frameWidth $frameHeight $animationMeta $artDir
}

$previewWidth = [int](($sheetWidth * $previewScale) + 48)
$previewHeight = ($frameHeight * $previewScale) + 56
$preview = New-Object System.Drawing.Bitmap -ArgumentList $previewWidth, $previewHeight, $pixelFormat
$previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
$previewGraphics.Clear((HexColor "#151617"))
$previewGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$previewGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$previewGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None

FillRect2D $previewGraphics (HexColor "#202224") 16 16 ($previewWidth - 32) ($previewHeight - 32)
FillRect2D $previewGraphics (HexColor "#0f1011") 24 24 ($previewWidth - 48) ($previewHeight - 48)

for ($i = 0; $i -lt $frameCount; $i++) {
    $panelX = 24 + ($i * $frameWidth * $previewScale)
    FillRect2D $previewGraphics (HexColor "#141619") $panelX 24 ($frameWidth * $previewScale) ($frameHeight * $previewScale)
    if ($i -gt 0) {
        FillRect2D $previewGraphics (HexColor "#2f3337") ($panelX - 2) 24 4 ($frameHeight * $previewScale)
    }
}

$sheetImage = [System.Drawing.Image]::FromFile($conceptStripPath)
$previewGraphics.DrawImage(
    $sheetImage,
    (New-Object System.Drawing.Rectangle -ArgumentList 24, 24, ($sheetWidth * $previewScale), ($frameHeight * $previewScale))
)
$sheetImage.Dispose()
$preview.Save($previewPath, [System.Drawing.Imaging.ImageFormat]::Png)
$previewGraphics.Dispose()
$preview.Dispose()
$sheet.Dispose()

$manifestAnimations = @()
foreach ($animationMeta in $sheetMeta) {
    $manifestAnimations += [PSCustomObject]@{
        name = $animationMeta.name
        file = $animationMeta.file
        frames = $animationMeta.indices.Count
        fps = $animationMeta.fps
        loop = $animationMeta.loop
    }
}

$manifest = [PSCustomObject]@{
    name = "dungeon_jailer"
    display_name = "Dungeon Jailer"
    frame_width = $frameWidth
    frame_height = $frameHeight
    background = "transparent"
    fixed_frame_size = $true
    baseline_y = 145
    facing = "right"
    notes = @(
        "elite enemy concept assembled from four key poses"
        "long lock-neck cage fork silhouette for control pressure"
        "placeholder animation strips intended to support a complete scene setup"
    )
    animations = $manifestAnimations
}
Write-Utf8NoBom $manifestPath ($manifest | ConvertTo-Json -Depth 5)

$spriteSceneText = New-SpriteSceneText $sheetMeta $frameWidth $frameHeight "DungeonJailerSprite" "SpriteFrames_dungeon_jailer"
Write-Utf8NoBom $spriteScenePath $spriteSceneText

$readmeLines = @(
    "# Dungeon Jailer"
    ""
    "- Working title: Lock-Neck Jailer / dungeon_jailer"
    "- Role: elite enemy scene asset"
    "- Frame size: 192x192"
    "- Output: full animation strips, sprite scene and concept preview board"
    "- Weapon silhouette: long cage-fork polearm for spacing, control and capture pressure"
    ""
    "Animations:"
)
$readmeLines += $manifestAnimations | ForEach-Object { "- {0}: {1} frames @ {2} fps" -f $_.name, $_.frames, $_.fps }
Write-Utf8NoBom $readmePath ($readmeLines -join "`r`n")
