# 素材导出工具

在 Windows 上使用 PowerShell 7。入口 [export-brand-kit.ps1](export-brand-kit.ps1) 接收 `-ConfigPath` 和 `-OutputDir`。输出目录须不存在。使用 `-PreviewOnly` 时，仅输出 `preview.png` 并允许定稿项尚未确认。

最终导出时可传入 `-DiscussionPath`，将 Markdown 讨论记录保存为 `process/README.md`。相对路径以配置文件所在目录为准。

[render-brand-images.ps1](render-brand-images.ps1) 负责透明处理与绘制。[write-brand-readmes.ps1](write-brand-readmes.ps1) 根据实际文件编制说明。两个辅助脚本由入口调用。

默认导出包括 14 种尺寸的 PNG、两种 ICO、独立文字与组合图、可继续使用的品牌配置和各层 README。配置约定见 [定稿与交付](../skills/brand-kit/references/delivery.md)。
