# 将 Docker 镜像备份到 GitHub Container Registry（GHCR）

本文记录如何把本地已有的 Docker 镜像重新标记并推送到自己的 GitHub Container Registry（GHCR），便于长期保存和后续部署。

以下示例将镜像：

```text
ghcr.io/chenyme/grok2api:backup
```

备份到 GitHub 用户 `dcduanchao` 的 GHCR：

```text
ghcr.io/dcduanchao/grok2api:backup
```

## 1. 创建 GitHub Token

进入 GitHub：

```text
Settings → Developer settings → Personal access tokens → Tokens (classic)
```

创建一个 Personal Access Token（classic），至少勾选：

- `write:packages`：推送镜像到 GHCR。
- `read:packages`：拉取私有镜像时需要。

!!! warning "注意"
    Token 只会在创建时完整显示一次，请及时保存，不要将 Token 写入脚本、命令历史或提交到 Git 仓库。

## 2. 登录 GHCR

在服务器终端中安全读取 Token：

```bash
read -s GITHUB_TOKEN
```

粘贴 Token 后按回车，然后执行：

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u dcduanchao --password-stdin
unset GITHUB_TOKEN
```

出现以下提示表示登录成功：

```text
Login Succeeded
```

## 3. 确认本地镜像

查找需要备份的镜像：

```bash
docker images | grep grok2api
```

示例输出：

```text
ghcr.io/chenyme/grok2api   backup   260e74b61b90
```

这说明本地已经存在要上传的镜像：

```text
ghcr.io/chenyme/grok2api:backup
```

如果本地还没有该镜像，需要先拉取：

```bash
docker pull ghcr.io/chenyme/grok2api:backup
```

## 4. 重新标记镜像

将原镜像标记为自己 GHCR 仓库下的镜像：

```bash
docker tag \
  ghcr.io/chenyme/grok2api:backup \
  ghcr.io/dcduanchao/grok2api:backup
```

再次检查：

```bash
docker images | grep grok2api
```

应该看到类似结果：

```text
ghcr.io/dcduanchao/grok2api   backup   260e74b61b90
ghcr.io/chenyme/grok2api      backup   260e74b61b90
```

两个镜像的 `IMAGE ID` 相同是正常现象。`docker tag` 不会复制镜像数据，只是为同一个本地镜像增加一个新名称。

## 5. 推送镜像到 GHCR

执行：

```bash
docker push ghcr.io/dcduanchao/grok2api:backup
```

推送成功后会看到类似输出：

```text
backup: digest: sha256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

出现镜像摘要 `digest` 即表示上传成功。

## 6. 保存固定版本号

不建议只保留 `backup` 这种可重复覆盖的标签。可以额外添加一个带日期的固定版本号，例如：

```bash
docker tag \
  ghcr.io/dcduanchao/grok2api:backup \
  ghcr.io/dcduanchao/grok2api:v2026-08-14

docker push ghcr.io/dcduanchao/grok2api:v2026-08-14
```

完成后 GHCR 中会同时存在：

```text
ghcr.io/dcduanchao/grok2api:backup
ghcr.io/dcduanchao/grok2api:v2026-08-14
```

后续部署时，优先使用固定版本号，避免 `backup` 标签被覆盖后导致部署内容发生变化：

```bash
docker pull ghcr.io/dcduanchao/grok2api:v2026-08-14
```

## 7. 验证远程镜像

可以删除新标签对应的本地镜像，再从 GHCR 拉取，以确认远程镜像可用：

```bash
docker image rm ghcr.io/dcduanchao/grok2api:v2026-08-14
docker pull ghcr.io/dcduanchao/grok2api:v2026-08-14
```

也可以查看镜像摘要：

```bash
docker inspect \
  --format='{{json .RepoDigests}}' \
  ghcr.io/dcduanchao/grok2api:v2026-08-14
```

## 8. 镜像可见性

首次推送后，可以进入 GitHub 个人主页的 **Packages** 页面查看镜像包。GHCR 镜像默认可能是私有的；如需公开访问，请在对应 Package 的设置中修改可见性。

私有镜像在其他服务器上拉取前，需要先使用具有 `read:packages` 权限的 Token 登录 GHCR。

## 完整命令汇总

```bash
# 登录 GHCR
read -s GITHUB_TOKEN
echo "$GITHUB_TOKEN" | docker login ghcr.io -u dcduanchao --password-stdin
unset GITHUB_TOKEN

# 确认本地镜像
docker images | grep grok2api

# 添加自己的 GHCR 标签
docker tag \
  ghcr.io/chenyme/grok2api:backup \
  ghcr.io/dcduanchao/grok2api:backup

# 推送 backup 标签
docker push ghcr.io/dcduanchao/grok2api:backup

# 添加并推送固定版本标签
docker tag \
  ghcr.io/dcduanchao/grok2api:backup \
  ghcr.io/dcduanchao/grok2api:v2026-08-14

docker push ghcr.io/dcduanchao/grok2api:v2026-08-14
```
