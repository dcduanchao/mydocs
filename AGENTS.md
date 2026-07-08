# Repository Guidelines

## Project Structure & Module Organization
本仓库是一个基于 MkDocs 的文档站点。源内容位于 `docs/`，按主题分组，例如 `docs/java/`、`docs/linux/`、`docs/python/` 和 `docs/project/`。站点配置、导航和主题设置都定义在 `mkdocs.yml` 中。部署脚本位于 `deploy_to_nginx.sh`，示例 Nginx 配置放在 `nginx/` 下。构建输出目录是 `site/`，不要直接手动修改。

## Build, Test, and Development Commands
使用 `mkdocs serve` 在本地启动带热更新的预览。使用 `mkdocs build` 将静态站点生成到 `site/`，并在提交前发现导航或 Markdown 错误。在部署机器上，执行 `bash deploy_to_nginx.sh` 会拉取 `main`、使用 `mkdocs` 的 Conda 环境构建站点，并同步到 `/var/www/html/mydocs`。

## Coding Style & Naming Conventions
Markdown 内容应简洁、聚焦主题，默认使用清晰中文，只有在必须时保留英文术语。优先使用 ATX 标题（`#`、`##`）和围栏代码块展示命令。保持现有命名风格：目录名小写，Markdown 文件名使用 snake_case，例如 `java_base.md`。修改 `mkdocs.yml` 时保持当前两空格缩进；新增或重命名页面时，记得同步更新 `nav`。


## Commit & Pull Request Guidelines
最近的提交历史同时包含简短中文和简单英文，例如 `java`、`忽略`、`Make deploy script cron-safe`。建议使用简短但明确的提交信息，直接说明实际改动。提交 PR 时应包含：变更摘要、涉及的页面或配置文件、执行过的验证命令（如 `mkdocs build`）；只有在布局或主题显示发生变化时才附截图。

## Deployment Notes
除非任务明确与部署有关，否则不要修改 `deploy_to_nginx.sh` 或 `nginx/` 下的文件。大多数贡献应限制在 `docs/` 和 `mkdocs.yml`。
