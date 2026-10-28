# Card forensics: measure each 2D card's subject ratio + dominant colours so the
# 3D models can be aligned to the original art.
#
# Each card is a 100x120 PNG holding TWO illustrations: the colour one on top,
# a greyscale "locked" copy below. Only the top half is colour, so sampling the
# whole image pulls the palette toward grey.
#
# ASCII only on purpose: Windows PowerShell 5.1 reads BOM-less UTF-8 as ANSI and
# a multi-byte comment can swallow the following line (parser errors).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools/model-ref/cards.ps1
param(
    [string]$CardRoot = "D:\PVZ3D\.ref\assets-full\663\images\Card",
    [string]$Out = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($Out -eq "") { $Out = Join-Path $here "out\cards.json" }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
$Script:CropRoot = Join-Path $here "out\cards"

# project kind -> card file name (23 plants + 12 zombies)
$plants = [ordered]@{
    "sunflower"    = "SunFlower.png"
    "peashooter"   = "Peashooter.png"
    "wallnut"      = "WallNut.png"
    "snowpea"      = "SnowPea.png"
    "repeater"     = "Repeater.png"
    "cherrybomb"   = "CherryBomb.png"
    "potatomine"   = "PotatoMine.png"
    "threepeater"  = "Threepeater.png"
    "chomper"      = "Chomper.png"
    "lilypad"      = "LilyPad.png"
    "tallnut"      = "TallNut.png"
    "jalapeno"     = "Jalapeno.png"
    "squash"       = "Squash.png"
    "pumpkin"      = "PumpkinHead.png"
    "kernelpult"   = "Kernelpult.png"
    "melonpult"    = "Melonpult.png"
    "puffshroom"   = "PuffShroom.png"
    "sunshroom"    = "SunShroom.png"
    "fumeshroom"   = "FumeShroom.png"
    "hypnoshroom"  = "HypnoShroom.png"
    "iceshroom"    = "IceShroom.png"
    "doomshroom"   = "DoomShroom.png"
    "magnetshroom" = "MagnetShroom.png"
}

$zombies = [ordered]@{
    "basic"       = "Zombie.png"
    "cone"        = "ConeheadZombie.png"
    "bucket"      = "BucketheadZombie.png"
    "flag"        = "FlagZombie.png"
    "newspaper"   = "NewspaperZombie.png"
    "football"    = "FootballZombie.png"
    "pole"        = "PoleVaultingZombie.png"
    "screendoor"  = "ScreenDoorZombie.png"
    "balloon"     = "Balloonzombie.png"
    "dancer"      = "DancingZombie.png"
    "backup"      = "BackupDancer.png"
    "gargantuar"  = "Gargantuar.png"
}

function Measure-Card {
    param([string]$Path, [string]$Kind, [string]$Group)

    $bmp = [System.Drawing.Bitmap]::FromFile($Path)
    try {
        # the card frame is a dark rim: inset past it, or the bbox is the card
        $w = $bmp.Width
        $h = [int]($bmp.Height * 0.5)
        $y0s = 6
        $y1s = $h - 8
        $x0s = 8
        $x1s = $w - 8
        $scanW = $x1s - $x0s
        $scanH = $y1s - $y0s
        $rowHit = New-Object 'int[]' ($h + 1)
        $colHit = New-Object 'int[]' ($w + 1)
        $buckets = @{}
        $counted = 0

        for ($y = $y0s; $y -lt $y1s; $y++) {
            for ($x = $x0s; $x -lt $x1s; $x++) {
                $c = $bmp.GetPixel($x, $y)
                $r = [int]$c.R; $g = [int]$c.G; $b = [int]$c.B
                $mx = [Math]::Max($r, [Math]::Max($g, $b))
                $mn = [Math]::Min($r, [Math]::Min($g, $b))
                $sat = if ($mx -eq 0) { 0.0 } else { ($mx - $mn) / $mx }
                $lum = ($r * 0.299 + $g * 0.587 + $b * 0.114) / 255.0
                # subject = saturated plant colour, or an ink line inside the art.
                # the card background is a pale blue/green gradient (low sat).
                $isSubject = ($sat -gt 0.38 -and $lum -lt 0.9) -or ($lum -lt 0.3)
                if (-not $isSubject) { continue }

                $rowHit[$y] = $rowHit[$y] + 1
                $colHit[$x] = $colHit[$x] + 1
                $counted++

                # 4 bits per channel; drop almost-black ink so it cannot win
                if ($lum -gt 0.18) {
                    $key = "{0:x1}{1:x1}{2:x1}" -f ($r -shr 4), ($g -shr 4), ($b -shr 4)
                    if ($buckets.ContainsKey($key)) {
                        $buckets[$key] = $buckets[$key] + 1
                    } else {
                        $buckets[$key] = 1
                    }
                }
            }
        }

        # frame/dividing lines light up a whole row or column: a real subject
        # row covers a fraction of the scan width, a border row covers all of it
        $x0 = 9999; $y0 = 9999; $x1 = -1; $y1 = -1
        for ($y = $y0s; $y -lt $y1s; $y++) {
            if ($rowHit[$y] -lt 2) { continue }
            if ($rowHit[$y] -gt ($scanW * 0.68)) { continue }
            if ($y -lt $y0) { $y0 = $y }
            if ($y -gt $y1) { $y1 = $y }
        }
        for ($x = $x0s; $x -lt $x1s; $x++) {
            if ($colHit[$x] -lt 2) { continue }
            if ($colHit[$x] -gt ($scanH * 0.68)) { continue }
            if ($x -lt $x0) { $x0 = $x }
            if ($x -gt $x1) { $x1 = $x }
        }
        if ($x1 -lt $x0) { $x0 = $x0s; $x1 = $x1s - 1 }
        if ($y1 -lt $y0) { $y0 = $y0s; $y1 = $y1s - 1 }

        $colors = @()
        $top = $buckets.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
        foreach ($kv in $top) {
            $k = [string]$kv.Key
            $r = [Convert]::ToInt32($k.Substring(0, 1), 16) * 17
            $g = [Convert]::ToInt32($k.Substring(1, 1), 16) * 17
            $b = [Convert]::ToInt32($k.Substring(2, 1), 16) * 17
            $share = if ($counted -gt 0) { [Math]::Round($kv.Value / $counted, 3) } else { 0.0 }
            $colors += [ordered]@{
                hex   = ("#{0:x2}{1:x2}{2:x2}" -f $r, $g, $b)
                share = $share
            }
        }

        $bw = [Math]::Max(1, $x1 - $x0 + 1)
        $bh = [Math]::Max(1, $y1 - $y0 + 1)

        # 5x crop of the colour card, so the art can be eyeballed next to a render
        $crop = New-Object System.Drawing.Bitmap 1, 1
        try {
            $pad = 2
            $cx = [Math]::Max(0, $x0 - $pad)
            $cy = [Math]::Max(0, $y0 - $pad)
            $cw = [Math]::Min($w - $cx, $bw + $pad * 2)
            $ch = [Math]::Min($h - $cy, $bh + $pad * 2)
            $crop = $bmp.Clone((New-Object System.Drawing.Rectangle $cx, $cy, $cw, $ch), $bmp.PixelFormat)
            $big = New-Object System.Drawing.Bitmap ($cw * 5), ($ch * 5)
            $gfx = [System.Drawing.Graphics]::FromImage($big)
            $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $gfx.DrawImage($crop, 0, 0, $big.Width, $big.Height)
            $gfx.Dispose()
            $cropDir = Join-Path $Script:CropRoot $Kind
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cropDir) | Out-Null
            $big.Save($cropDir + ".png", [System.Drawing.Imaging.ImageFormat]::Png)
            $big.Dispose()
        } finally {
            $crop.Dispose()
        }

        return [ordered]@{
            kind      = $Kind
            group     = $Group
            card      = [System.IO.Path]::GetFileName($Path)
            card_size = @($bmp.Width, $bmp.Height)
            bbox      = [ordered]@{ x = $x0; y = $y0; w = $bw; h = $bh }
            aspect    = [Math]::Round($bw / $bh, 3)
            pixels    = $counted
            colors    = $colors
        }
    } finally {
        $bmp.Dispose()
    }
}

$result = [ordered]@{ generated = (Get-Date).ToString("s"); plants = @(); zombies = @() }
$missing = @()

foreach ($kind in $plants.Keys) {
    $p = Join-Path (Join-Path $CardRoot "Plants") $plants[$kind]
    if (-not (Test-Path $p)) { $missing += $p; continue }
    $result.plants += Measure-Card -Path $p -Kind $kind -Group "plant"
}
foreach ($kind in $zombies.Keys) {
    $p = Join-Path (Join-Path $CardRoot "Zombies") $zombies[$kind]
    if (-not (Test-Path $p)) { $missing += $p; continue }
    $result.zombies += Measure-Card -Path $p -Kind $kind -Group "zombie"
}

$json = $result | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($Out, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host ("cards -> " + $Out)
Write-Host ("plants " + $result.plants.Count + " / zombies " + $result.zombies.Count)
if ($missing.Count -gt 0) {
    Write-Host ("missing " + $missing.Count + ":")
    $missing | ForEach-Object { Write-Host ("  " + $_) }
}
$sample = @($result.plants) + @($result.zombies)
foreach ($row in $sample) {
    $hex = ($row.colors | ForEach-Object { $_.hex }) -join " "
    Write-Host ("  " + $row.kind.PadRight(12) + " aspect=" + $row.aspect + "  " + $hex)
}
