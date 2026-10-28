# Contact sheet: for each kind, put the 2D card next to the rendered 3D model
# (front + 3/4). Used to judge a model against the art it is supposed to copy.
#
# ASCII only (Windows PowerShell 5.1 reads BOM-less UTF-8 as ANSI).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools/model-ref/sheet.ps1 -Batch b1 `
#       -Kinds sunflower,peashooter,wallnut
param(
    [string]$Batch = "b1",
    [string]$Kinds = "",
    [string]$RefDir = "",
    [string]$Out = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($RefDir -eq "") { $RefDir = Join-Path $here "out" }
$cardDir = Join-Path $RefDir "cards"
$renderDir = Join-Path $RefDir "render"
if ($Out -eq "") { $Out = Join-Path (Join-Path $here "..\..\screenshots") ("model-ref-" + $Batch + ".png") }

if ($Kinds -eq "") { throw "pass -Kinds kind1,kind2,..." }
$list = $Kinds.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

# Card file names do not always match the gameplay kind, so keep a lookup for
# the ones that differ (the 2D source uses CamelCase asset names).
$cardNames = @{}

$rowH = 300
$cardW = 320
$cellW = 420
$pad = 8
$labelH = 26
$perSheet = 5

function Load-Or-Null {
    param([string]$Path)
    if (Test-Path $Path) { return [System.Drawing.Bitmap]::FromFile($Path) }
    return $null
}

$sheets = @()
$index = 0
while ($index -lt $list.Count) {
    $chunk = $list[$index..([Math]::Min($index + $perSheet - 1, $list.Count - 1))]
    $index += $perSheet

    $sheetW = $cardW + $cellW * 2 + $pad * 4
    $sheetH = $chunk.Count * ($rowH + $labelH + $pad) + $pad
    $bmp = New-Object System.Drawing.Bitmap $sheetW, $sheetH
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(24, 30, 26))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $font = New-Object System.Drawing.Font "Consolas", 14
    $brush = [System.Drawing.Brushes]::WhiteSmoke
    $brushDim = [System.Drawing.Brushes]::LightGray

    $y = $pad
    foreach ($k in $chunk) {
        $label = $k
        $g.DrawString($label, $font, $brush, $pad, $y)

        # renders are written with ':' turned into '-', cards use asset names
        $stem = $k.Replace(":", "-")
        $cardStem = if ($cardNames.ContainsKey($k)) { $cardNames[$k] } else { $k.Replace("z:", "") }

        # card crop
        $card = Load-Or-Null (Join-Path $cardDir ($cardStem + ".png"))
        if ($card -ne $null) {
            $scale = [Math]::Min($cardW / $card.Width, $rowH / $card.Height)
            $dw = [int]($card.Width * $scale)
            $dh = [int]($card.Height * $scale)
            $g.DrawImage($card, $pad, ($y + $labelH), $dw, $dh)
            $card.Dispose()
        } else {
            $g.DrawString("(no card)", $font, $brushDim, $pad, $y + $labelH)
        }

        # renders: fit the WHOLE 16:9 frame into the cell (a central square crop
        # would cut the sides off a wide model such as the pumpkin)
        $col = 1
        foreach ($view in @("front", "threeq")) {
            $r = Load-Or-Null (Join-Path $renderDir ($stem + "-" + $view + ".png"))
            if ($r -eq $null) {
                $g.DrawString("(no " + $view + ")", $font, $brushDim, $pad + $cardW * $col, $y + $labelH)
                $col++
                continue
            }
            $sc = [Math]::Min($cellW / $r.Width, $rowH / $r.Height)
            $dw = [int]($r.Width * $sc)
            $dh = [int]($r.Height * $sc)
            $dstX = $pad + $cardW + ($cellW * ($col - 1)) + [int](($cellW - $dw) / 2)
            $dstY = $y + $labelH + [int](($rowH - $dh) / 2)
            $g.DrawImage($r, $dstX, $dstY, $dw, $dh)
            $r.Dispose()
            $col++
        }

        $y += $rowH + $labelH + $pad
    }

    $g.Dispose()
    $suffix = if ($list.Count -gt $perSheet) { "-" + ($sheets.Count + 1) } else { "" }
    $path = $Out -replace "\.png$", ""
    $path = $path + $suffix + ".png"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $sheets += $path
    Write-Host ("sheet -> " + $path)
}
