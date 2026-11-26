#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$OutputDir,
    [string]$DiscussionPath,
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw '当前导出脚本需要 Windows PowerShell 7。' }
. (Join-Path $PSScriptRoot 'render-brand-images.ps1')
. (Join-Path $PSScriptRoot 'write-brand-readmes.ps1')

$configFile = (Resolve-Path -LiteralPath $ConfigPath).Path
$configDir = Split-Path -Parent $configFile
$config = Get-Content -LiteralPath $configFile -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
$output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
if (Test-Path -LiteralPath $output) { throw "请指定尚未存在的输出目录：$output" }
$outputParent = [IO.Path]::GetDirectoryName($output)

function Resolve-BrandFile {
    param([string]$Value, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Value)) { throw "请提供$Label。" }
    $path = if ([IO.Path]::IsPathFullyQualified($Value)) { $Value } else { Join-Path $configDir $Value }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "找不到$Label：$path" }
    return (Resolve-Path -LiteralPath $path).Path
}

function Confirm-BrandNumber {
    param($Value, [double]$Min, [double]$Max, [string]$Label, [switch]$Integer)
    if (($Value -isnot [ValueType]) -or ($Value -is [bool]) -or
        ($Value -lt $Min) -or ($Value -gt $Max) -or
        ($Integer -and ($Value -ne [Math]::Truncate($Value)))) {
        throw "$Label 须为 $Min 到 $Max 之间的有效数值。"
    }
}

function Confirm-BrandColor {
    param($Value, [string]$Label)
    if ($Value -isnot [string] -or $Value -notmatch '^#[0-9a-fA-F]{6}$') { throw "$Label 须使用 #RRGGBB 格式。" }
}

function Confirm-BrandTitle {
    param($Value, [string]$Label, [switch]$Optional)
    if ($Optional -and [string]::IsNullOrEmpty($Value)) { return }
    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value) -or
        $Value.Length -gt 120 -or $Value -match '[\r\n\t]' -or $Value.Trim() -cne $Value) {
        throw "$Label 须为去除首尾空格的单行文字，最多 120 字符。"
    }
}

if ($config.slug -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $config.slug.Length -gt 64) {
    throw 'slug 须为 64 字符内的小写字母、数字与分隔连字符。'
}
Confirm-BrandTitle $config.name '品牌名称'
Confirm-BrandTitle $config['subtitle'] '副标题' -Optional

if (-not $PreviewOnly) {
    foreach ($item in @('logo', 'palette', 'copy', 'typography', 'proof')) {
        if ($config.approval[$item] -isnot [bool] -or -not $config.approval[$item]) {
            throw "尚未确认 $item。请先用 -PreviewOnly 生成样张，记录用户认可后再导出。"
        }
    }
}

$logoSettings = $config.logo
if ($logoSettings.mode -notin @('alpha', 'color-key')) { throw 'logo.mode 须为 alpha 或 color-key。' }
Confirm-BrandNumber $logoSettings.alphaThreshold 1 255 'alphaThreshold' -Integer
Confirm-BrandNumber $logoSettings.masterSize 64 8192 'masterSize' -Integer
if ($logoSettings.mode -eq 'color-key') {
    Confirm-BrandColor $logoSettings.keyColor '色键'
    Confirm-BrandNumber $logoSettings.keyTolerance 0 254 '色键容差' -Integer
    Confirm-BrandNumber $logoSettings.keyFeather 0 (255 - $logoSettings.keyTolerance) '色键羽化' -Integer
}
$source = Resolve-BrandFile $logoSettings.path 'Logo 源文件'
$archive = $null
if ($logoSettings['archive']) { $archive = Resolve-BrandFile $logoSettings.archive '归档底稿' }
$discussion = $null
if ($DiscussionPath) {
    $discussion = Resolve-BrandFile $DiscussionPath '讨论记录'
    if ([IO.Path]::GetExtension($discussion) -ne '.md') { throw '讨论记录须为 Markdown 文件。' }
}

foreach ($role in $config.palette.Keys) { Confirm-BrandColor $config.palette[$role] $role }
if ($config.palette.Count -lt 1) { throw '请至少记录一种 Logo 代表色。' }
foreach ($mode in @('light', 'dark')) {
    $surface = $config.surfaces[$mode]
    foreach ($role in @('name', 'background')) { Confirm-BrandColor $surface[$role] "$mode $role" }
    if ($config['subtitle']) { Confirm-BrandColor $surface.subtitle "$mode subtitle" }
}
if ($config.weights.Count -ne 2) { throw '请设置 bolder 和 heavier 两档字重。' }
foreach ($key in @('bolder', 'heavier')) {
    foreach ($role in @('titleStroke', 'subtitleStroke')) {
        Confirm-BrandNumber $config.weights[$key][$role] 0 30 "$key $role"
    }
}
if ($config.layouts.Count -lt 1 -or $config.layouts.Count -gt 3) { throw '请选择一种至三种组合布局。' }
$layoutKeys = @{}
$neededLines = @{}
foreach ($layout in $config.layouts) {
    if ($layout.key -cnotmatch '^[a-z][a-z0-9-]{0,35}$' -or $layoutKeys.ContainsKey($layout.key)) { throw '布局 key 须唯一且使用小写英文。' }
    $layoutKeys[$layout.key] = $true
    if ($layout.direction -notin @('horizontal', 'vertical')) { throw '布局方向须为 horizontal 或 vertical。' }
    Confirm-BrandNumber $layout.lines 1 2 '名称行数' -Integer
    Confirm-BrandNumber $layout.width 320 5000 '画布宽度' -Integer
    Confirm-BrandNumber $layout.height 320 5000 '画布高度' -Integer
    $neededLines[[int]$layout.lines] = $true
}
$nameRows = $config['twoLineName']
if ($neededLines.ContainsKey(2)) {
    if ($nameRows -isnot [array] -or $nameRows.Count -ne 2) { throw '双行布局需要 twoLineName 中的两行文字。' }
    foreach ($row in $nameRows) { Confirm-BrandTitle $row '双行名称' }
}

$fontSettings = $config.font
foreach ($style in @($fontSettings.nameStyle, $fontSettings.subtitleStyle)) {
    if ($style -notin @('regular', 'italic')) { throw '字形须为 regular 或 italic。' }
}
$defaultFonts = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets/fonts'
$fonts = [ordered]@{
    regular = Join-Path $defaultFonts 'CormorantGaramond[wght].ttf'
    italic = Join-Path $defaultFonts 'CormorantGaramond-Italic[wght].ttf'
    license = Join-Path $defaultFonts 'OFL.txt'
}
if ($fontSettings['regular'] -or $fontSettings['italic'] -or $fontSettings['license']) {
    foreach ($key in @('regular','license')) { $fonts[$key] = Resolve-BrandFile $fontSettings[$key] "字体 $key 文件" }
    $fonts.italic = if ($fontSettings['italic']) { Resolve-BrandFile $fontSettings.italic '斜体字体' } else { $null }
}
$usesItalic = $fontSettings.nameStyle -eq 'italic' -or ($config['subtitle'] -and $fontSettings.subtitleStyle -eq 'italic')
if ($usesItalic -and -not $fonts.italic) { throw '所选字形需要斜体字体文件。' }
foreach ($key in @('regular', 'italic')) {
    if ($fonts[$key] -and [IO.Path]::GetExtension($fonts[$key]) -notin @('.ttf', '.otf')) {
        throw '当前支持 TTF 或 OTF 字体文件。'
    }
}

$collection = [System.Drawing.Text.PrivateFontCollection]::new()
$mark = $null
$master = $null
$stage = $null
try {
    $collection.AddFontFile($fonts.regular)
    if ($fonts.italic) { $collection.AddFontFile($fonts.italic) }
    $family = $collection.Families | Where-Object Name -eq $fontSettings.family | Select-Object -First 1
    if ($null -eq $family) { throw "找不到字体系列 $($fontSettings.family)，请检查配置和字体文件。" }
    if (-not $family.IsStyleAvailable([System.Drawing.FontStyle]$fontSettings.nameStyle) -or
        ($config['subtitle'] -and -not $family.IsStyleAvailable([System.Drawing.FontStyle]$fontSettings.subtitleStyle))) {
        throw '字体文件没有指定的字形。'
    }
    $mark = Get-BrandCutout $source $logoSettings
    $size = [int]$logoSettings.masterSize
    $master = New-BrandBitmap $size $size
    $g = New-BrandGraphics $master
    try {
        $pad = [Math]::Max(2, [Math]::Floor($size * .045))
        Draw-BrandFit $g $mark $pad $pad ($size - $pad * 2) ($size - $pad * 2)
    } finally { $g.Dispose() }

    [IO.Directory]::CreateDirectory($outputParent) | Out-Null
    $stage = Join-Path $outputParent ".brand-kit-build-$([Guid]::NewGuid().ToString('N'))"
    $elements = Join-Path $stage 'brand-kit/elements'
    $compositions = Join-Path $stage 'brand-kit/compositions'
    [IO.Directory]::CreateDirectory($compositions) | Out-Null

    if (-not $PreviewOnly) {
        foreach ($dir in @('logo/source', 'logo/png', 'logo/icons', 'brand-kit/fonts', 'brand-kit/elements')) {
            [IO.Directory]::CreateDirectory((Join-Path $stage $dir)) | Out-Null
        }
        Copy-Item -LiteralPath $source -Destination (Join-Path $stage 'logo/source/original.png')
        $logoSettings.path = 'logo/source/original.png'
        if ($archive) {
            $archiveName = 'reference' + [IO.Path]::GetExtension($archive)
            Copy-Item -LiteralPath $archive -Destination (Join-Path $stage "logo/source/$archiveName")
            $logoSettings.archive = "logo/source/$archiveName"
        }
        foreach ($key in $fonts.Keys) {
            if ($fonts[$key]) {
                $extension = if ($key -eq 'license') { '.txt' } else { [IO.Path]::GetExtension($fonts[$key]) }
                $relative = "brand-kit/fonts/$key$extension"
                Copy-Item -LiteralPath $fonts[$key] -Destination (Join-Path $stage $relative)
                $fontSettings[$key] = $relative
            }
        }
        Save-BrandPng $mark (Join-Path $stage "logo/$($config.slug)-cutout.png")
        Save-BrandPng $master (Join-Path $stage "logo/$($config.slug)-master.png")
        Copy-Item -LiteralPath (Join-Path $stage "logo/$($config.slug)-cutout.png") -Destination (Join-Path $elements "$($config.slug)-mark.png")
        $pngDir = Join-Path $stage 'logo/png'
        foreach ($px in @(16, 24, 32, 48, 64, 96, 128, 180, 192, 256, 384, 512, 1024, 1280)) {
            $icon = New-BrandBitmap $px $px
            $graphics = New-BrandGraphics $icon
            try {
                $graphics.DrawImage($master, 0, 0, $px, $px)
                Save-BrandPng $icon (Join-Path $pngDir "$($config.slug)-$px.png")
            } finally {
                $graphics.Dispose()
                $icon.Dispose()
            }
        }
        Write-BrandIcon (Join-Path $stage 'logo/icons/favicon.ico') @(16, 32, 48) $pngDir $config.slug
        Write-BrandIcon (Join-Path $stage "logo/icons/$($config.slug)-windows.ico") @(16, 24, 32, 48, 64, 128, 256) $pngDir $config.slug
    }

    foreach ($mode in @('light', 'dark')) {
        $surface = $config.surfaces[$mode]
        foreach ($weightKey in $config.weights.Keys) {
            $weight = $config.weights[$weightKey]
            $names = @{}
            $subtitle = $null
            try {
                foreach ($lineCount in $neededLines.Keys) {
                    $rows = if ($lineCount -eq 1) { @($config.name) } else { $nameRows }
                    $names[$lineCount] = New-BrandText $rows $family $fontSettings.nameStyle 360 $surface.name $weight.titleStroke
                    if (-not $PreviewOnly) {
                        $label = if ($lineCount -eq 1) { 'single' } else { 'double' }
                        Save-BrandPng $names[$lineCount] (Join-Path $elements "name-$label-line-$weightKey-$mode.png")
                    }
                }
                if ($config['subtitle']) {
                    $subtitle = New-BrandText @($config.subtitle) $family $fontSettings.subtitleStyle 210 $surface.subtitle $weight.subtitleStroke
                    if (-not $PreviewOnly) { Save-BrandPng $subtitle (Join-Path $elements "subtitle-$weightKey-$mode.png") }
                }
                foreach ($layout in $config.layouts) {
                    $file = Join-Path $compositions "$($layout.key)-$weightKey-$mode.png"
                    Save-BrandComposition $file $layout $mark $names[[int]$layout.lines] $subtitle
                }
            } finally {
                foreach ($image in $names.Values) { $image.Dispose() }
                if ($null -ne $subtitle) { $subtitle.Dispose() }
            }
        }
    }
    $proofPath = if ($PreviewOnly) { Join-Path $stage 'preview.png' } else { Join-Path $stage 'brand-kit/preview.png' }
    Save-BrandPreview $proofPath $compositions $config $master
    if ($PreviewOnly) {
        $proofDir = Join-Path $stage 'proof'
        [IO.Directory]::CreateDirectory($proofDir) | Out-Null
        [IO.File]::Move($proofPath, (Join-Path $proofDir 'preview.png'))
        [IO.Directory]::Move($proofDir, $output)
    } else {
        if ($discussion) {
            [IO.Directory]::CreateDirectory((Join-Path $stage 'process')) | Out-Null
            Copy-Item -LiteralPath $discussion -Destination (Join-Path $stage 'process/README.md')
        }
        $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $stage 'brand.json') -Encoding utf8
        Write-BrandReadmes $stage $config
        [IO.Directory]::Move($stage, $output)
        $stage = $null
    }
    Write-Output "已生成 $output"
} finally {
    if ($null -ne $master) { $master.Dispose() }
    if ($null -ne $mark) { $mark.Dispose() }
    $collection.Dispose()
    if ($stage -and (Test-Path -LiteralPath $stage -PathType Container)) {
        $actual = (Resolve-Path -LiteralPath $stage).Path
        if ([IO.Path]::GetDirectoryName($actual) -eq $outputParent -and [IO.Path]::GetFileName($actual) -match '^\.brand-kit-build-[0-9a-f]{32}$') {
            Remove-Item -LiteralPath $actual -Recurse -Force
        }
    }
}
