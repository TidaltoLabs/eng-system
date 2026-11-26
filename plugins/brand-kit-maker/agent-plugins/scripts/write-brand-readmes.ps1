function Get-BrandAssetList {
    param([string]$Directory, [string]$Filter = '*', [switch]$Dimensions, [switch]$OrderBySize)
    if ($Dimensions) {
        '| 文件 | 尺寸 |'
        '|---|---:|'
    }
    $files = Get-ChildItem -LiteralPath $Directory -Filter $Filter -File | Where-Object Name -ne 'README.md'
    $files = if ($OrderBySize) { $files | Sort-Object { [int]($_.BaseName -replace '^.*-', '') } } else { $files | Sort-Object Name }
    foreach ($file in $files) {
        $label = $file.Name -replace '\[', '\[' -replace '\]', '\]'
        $link = '[{0}]({1})' -f $label, [Uri]::EscapeDataString($file.Name)
        if ($Dimensions) {
            $image = [System.Drawing.Image]::FromFile($file.FullName)
            try { "| $link | $($image.Width)×$($image.Height) px |" }
            finally { $image.Dispose() }
        } else {
            "- $link"
        }
    }
}

function Format-BrandColorRow {
    param([string]$Role, [string]$Hex)
    $c = [System.Drawing.ColorTranslator]::FromHtml($Hex)
    return ('| {0} | {1} | {2}, {3}, {4} |' -f $Role.Replace('|','\|'), $Hex.ToUpperInvariant(), $c.R, $c.G, $c.B)
}

function Write-BrandReadmes {
    param([string]$Root, [System.Collections.IDictionary]$Config)
    $nl = [Environment]::NewLine
    $name = $Config.name
    $slug = $Config.slug
    $colorRows = @(
        foreach ($role in $Config.palette.Keys) { Format-BrandColorRow $role $Config.palette[$role] }
        foreach ($mode in @('light', 'dark')) {
            $surface = $Config.surfaces[$mode]
            $label = if ($mode -eq 'light') { '浅底' } else { '深底' }
            Format-BrandColorRow "$label·背景" $surface.background
            Format-BrandColorRow "$label·名称" $surface.name
            if ($Config['subtitle']) { Format-BrandColorRow "$label·副标题" $surface.subtitle }
        }
    ) -join $nl
    $subtitle = if ($Config['subtitle']) { "副标题为 *$($Config.subtitle)*。" } else { '本套件使用单独的品牌名称。' }
    $processLink = if (Test-Path -LiteralPath (Join-Path $Root 'process/README.md')) {
        '[需求、讨论与定稿记录](process/README.md)'
    }

    $docs = @{}
    $docs['README.md'] = @"
# $name 品牌素材

$($Config['description'])

$subtitle

## 快速选用

| 用途 | 文件 |
|---|---|
| 网站标签图标 | [favicon.ico](logo/icons/favicon.ico) |
| Windows 图标 | [多尺寸 Windows ICO](logo/icons/$slug-windows.ico) |
| 大尺寸图形 | [方形透明母图](logo/$slug-master.png)或[紧裁抠图](logo/$slug-cutout.png) |
| 各尺寸透明图标 | [PNG 尺寸表](logo/png/README.md) |
| 直接使用品牌组合 | [组合索引](brand-kit/compositions/README.md)和[深浅底预览](brand-kit/preview.png) |
| 自行排版 | [独立图形与字图](brand-kit/elements/README.md) |

[Logo 说明](logo/README.md) · [图文素材说明](brand-kit/README.md) · [定稿配置](brand.json)

$processLink

## 定稿色板

色板记录图形的代表色以及深浅底文字用色。正式图形和图文组合使用透明背景。

| 用途 | HEX | RGB |
|---|---|---|
$colorRows

## 字体

采用 **$($Config.font.family)**。字形、字体文件与授权原文见[字体说明](brand-kit/fonts/README.md)。
"@

    $crop = [System.Drawing.Image]::FromFile((Join-Path $Root "logo/$slug-cutout.png"))
    try { $cropSize = "$($crop.Width)×$($crop.Height) px" }
    finally { $crop.Dispose() }
    $docs['logo/README.md'] = @"
# $name Logo 素材

[品牌总说明与配色](../README.md) · [图文素材](../brand-kit/README.md)

| 素材 | 用途 |
|---|---|
| [底稿](source/README.md) | 原样归档的源文件 |
| [紧裁透明图]($slug-cutout.png) | $cropSize，用于自行排版 |
| [方形透明母图]($slug-master.png) | $($Config.logo.masterSize)×$($Config.logo.masterSize) px，用于缩放和再次导出 |
| [多尺寸 PNG](png/README.md) | 14 个方形透明图标 |
| [ICO](icons/README.md) | 网站 favicon 和 Windows 多尺寸图标 |
"@

    $sourceList = (Get-BrandAssetList (Join-Path $Root 'logo/source')) -join $nl
    $docs['logo/source/README.md'] = @"
# Logo 底稿

这里保存未经重新编码的原始资料。生成使用的源图和透明处理参数见[定稿配置](../../brand.json)。

$sourceList

[返回 Logo 素材](../README.md)
"@

    $pngRows = (Get-BrandAssetList (Join-Path $Root 'logo/png') '*.png' -Dimensions -OrderBySize) -join $nl
    $docs['logo/png/README.md'] = @"
# 多尺寸透明 PNG

16、32 和 48 px 主要用于小图标。大图展示使用较高分辨率的 PNG。

$pngRows

[返回 Logo 素材](../README.md) · [ICO 说明](../icons/README.md)
"@

    $docs['logo/icons/README.md'] = @"
# 网站和 Windows 图标

| 文件 | 图层（px） |
|---|---|
| [favicon.ico](favicon.ico) | 16、32、48 |
| [Windows ICO]($slug-windows.ico) | 16、24、32、48、64、128、256 |

ICO 内嵌透明 PNG。小图只保留 Logo 图形。

[返回 Logo 素材](../README.md) · [PNG 尺寸表](../png/README.md)
"@

    $elements = Join-Path $Root 'brand-kit/elements'
    $compositions = Join-Path $Root 'brand-kit/compositions'
    $elementCount = @(Get-ChildItem -LiteralPath $elements -Filter '*.png' -File).Count
    $compositionCount = @(Get-ChildItem -LiteralPath $compositions -Filter '*.png' -File).Count
    $docs['brand-kit/README.md'] = @"
# $name 图文素材包

[组合预览](preview.png)用于浅底与深底效果对照。正式图文素材为透明 PNG。

| 目录 | 内容 |
|---|---|
| [基础元素](elements/README.md) | $elementCount 张图，包括图形、独立名称和已配置的副标题 |
| [组合图](compositions/README.md) | $compositionCount 张组合图，按布局、字重和背景适配选择 |
| [字体与授权](fonts/README.md) | 字体文件及许可原文 |

[品牌总说明与色板](../README.md) · [Logo 规格](../logo/README.md)
"@

    $elementRows = (Get-BrandAssetList $elements '*.png' -Dimensions) -join $nl
    $docs['brand-kit/elements/README.md'] = @"
# 独立图形与文字

这里提供纯图形、单独的名称以及已配置的副标题，可用于自行排版。字重与深浅底的选用方法见[组合说明](../compositions/README.md)。

$elementRows

[返回图文素材](../README.md)
"@

    $compositionRows = (Get-BrandAssetList $compositions '*.png' -Dimensions) -join $nl
    $layoutRows = @(foreach ($layout in $Config.layouts) {
        $direction = if ($layout.direction -eq 'horizontal') { '横排' } else { '竖排' }
        "| $($layout.key) | $direction | $($layout.lines) |"
    }) -join $nl
    $docs['brand-kit/compositions/README.md'] = @"
# 图文组合

文件名由布局、字重和配色组成。light 适配浅色背景，dark 适配深色背景。bolder 与 heavier 是两档字重。选用前可看[组合预览](../preview.png)。

| 布局名 | 排列 | 名称行数 |
|---|---|---:|
$layoutRows

| 字重 | 名称描边 | 副标题描边 |
|---|---:|---:|
| bolder | $($Config.weights.bolder.titleStroke) px | $($Config.weights.bolder.subtitleStroke) px |
| heavier | $($Config.weights.heavier.titleStroke) px | $($Config.weights.heavier.subtitleStroke) px |

描边数值指文字母版的绘制参数，组合中的文字会随布局等比缩放。

$compositionRows

[返回图文素材](../README.md) · [完整色板](../../README.md#定稿色板)
"@

    $fontFiles = (Get-BrandAssetList (Join-Path $Root 'brand-kit/fonts')) -join $nl
    $styles = @{ regular = '常规字形'; italic = '斜体字形' }
    $mottoStyle = if ($Config['subtitle']) { "副标题用$($styles[$Config.font.subtitleStyle])。" }
    $docs['brand-kit/fonts/README.md'] = @"
# 字体与授权

字体为 **$($Config.font.family)**。名称用$($styles[$Config.font.nameStyle])。$mottoStyle

$fontFiles

字体分发与使用条件以随附的授权原文为准。

[返回图文素材](../README.md)
"@
    foreach ($relative in $docs.Keys) {
        $docs[$relative].TrimEnd() | Set-Content -LiteralPath (Join-Path $Root $relative) -Encoding utf8
    }
}
