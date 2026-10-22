# Cliplet

轻量的 macOS 剪贴板历史工具。由 **TC023456-sys** 维护，基于 [p0deje/Maccy 2.7.1](https://github.com/p0deje/Maccy/tree/2.7.1) 的独立修改版，非原作者官方发布。

<img src="ClipletFork/Cliplet.png" width="160" alt="Cliplet icon">

## 功能

- 文字、PNG / TIFF / JPEG / HEIC 图片与文件引用历史，搜索与置顶。
- 自动粘贴、纯文本粘贴和可自定义快捷键，沿用上游功能。
- Cliplet 名称、应用图标、菜单栏默认图标和关于页。
- 仅检查 [本仓库的正式发布](https://github.com/TC023456-sys/Cliplet/releases)，不使用 Maccy 更新源，不静默下载安装。自动检查默认关闭，开启后最多每天一次。

## 下载与授权

[Cliplet Releases](https://github.com/TC023456-sys/Cliplet/releases) 为本修改版唯一更新渠道。首次构建通过之前可能没有公开安装包。

要求 macOS 14 或更高版本。修改版使用临时签名，未经过 Developer ID 签名或 Apple 公证。自动粘贴需要在系统设置里单独授予 Cliplet 辅助功能权限，更新后可能需要重新授权；不要关闭系统安全保护。

独立应用标识为 `com.tc023456.Cliplet`。不会自动删除原 Maccy 的数据库或设置。需要迁移历史时，先退出原版，再做本机离线备份及迁移；历史数据绝不提交至仓库。

## 构建

保留 Maccy 源码及内部模块名以降低改动风险。使用完整 Xcode 26：先运行 `python3 ClipletFork/prepare.py`，再按 [.github/workflows/cliplet.yml](.github/workflows/cliplet.yml) 运行测试、双架构 Release 构建和临时签名。

`prepare.py` 生成所有标准图标尺寸，更新本修改版标识、本地化名称和网络权限，并移除 Sparkle 工程依赖及旧 Icon Composer 资源引用。源码包保留图标原图与构建脚本，可以复现应用。

## 原作者与许可

原作者 **Alexey Rodionov（p0deje）** 和 Maccy 贡献者；[原项目](https://github.com/p0deje/Maccy)、[原作者官网](https://maccy.app)。原始版权和 [MIT 许可证](LICENSE) 保留，不将上游作品声称为独立原创。修改版维护、图标与更新渠道等说明见 [NOTICES](ClipletFork/NOTICES.md)。
