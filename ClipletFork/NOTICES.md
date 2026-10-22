# Cliplet 1.0.0

修改版维护：TC023456-sys。基于 p0deje/Maccy 2.7.1（eb03ebac3bbf24044c797c06f4304b74e3187835），非上游官方发布。

- 项目、更新与问题反馈：https://github.com/TC023456-sys/Cliplet
- 原项目：https://github.com/p0deje/Maccy
- 原作者官网：https://maccy.app
- 保留原作者 Alexey Rodionov 及贡献者版权和 MIT 许可证，见根目录 LICENSE。

名称、应用图标、菜单栏默认图标和关于页已定制；软件更新只查询 TC023456-sys/Cliplet 的正式发布，最多每天自动检查一次，默认关闭；不会静默下载或安装，不使用原作者 Sparkle 更新通道。

使用独立标识 com.tc023456.Cliplet，临时签名，未经 Apple 公证。自动粘贴需要你在系统设置重新授予 Cliplet 辅助功能权限。原版数据不自动删除；在原版退出后才可进行本机离线迁移，不向仓库上传剪贴板历史或偏好设置。

内部 Maccy 模块名、模型和存储子目录为兼容而保留，不代表由原作者签名或维护。源代码里的技术参考和版权声明不会删除。

构建：完整 Xcode 26，运行 `python3 ClipletFork/prepare.py` 后按 .github/workflows/cliplet.yml 编译。ClipletFork/Cliplet.png 是用户确认的应用图标；脚本生成所有标准 AppIcon 尺寸。
