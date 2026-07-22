# docker 安装
[文档地址](https://docs.docker.com/engine/install)

## Ubuntu

```
# 卸载旧版本
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)

```
拉取源
```
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc


sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

安装最新版本

```
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

指定版本

```
apt list --all-versions docker-ce

docker-ce/noble 5:29.6.1-1~ubuntu.24.04~noble <arch>
docker-ce/noble 5:29.6.0-1~ubuntu.24.04~noble <arch>
...

VERSION_STRING=5:29.6.1-1~ubuntu.24.04~noble
sudo apt install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin


```


## 命令

```agsl
加入用户组
sudo usermod -aG docker $USER
newgrp docker

systemctl start docker  启动
systemctl stop docker 关闭
systemctl status docker  状态
systemctl restart docker 重启
docker version  版本
sudo systemctl enable docker  开机自起

docker stats: 内存占用情况
docker images 查看镜像       -a  所有信息      --digests  完整镜像id
docker search  查询镜像    -s  收藏大于 镜像
docker pull 拉取
docker rmi  删除  -f 强制删除
docker rmi  $(docker images -aq)  删除所有

```

## 代理配置

已经在 Linux 上运行 Clash 并设置了全局代理（比如配置了 export http_proxy=...），
但为什么：
❗ Docker 还是不能访问国外，比如 docker pull 失败？
✅ 原因核心：Docker 是一个守护进程（daemon），它不继承你当前终端的环境变量

```agsl

mkdir -p /etc/systemd/system/docker.service.d

cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890/"
Environment="HTTPS_PROXY=http://127.0.0.1:7890/"
Environment="NO_PROXY=localhost,127.0.0.1,::1，192.168.0.0/16"
EOF

或者
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://192.168.30.33:7890"
Environment="HTTPS_PROXY=http://192.168.30.33:7890"
Environment="NO_PROXY=localhost,127.0.0.1,192.168.0.0/16"
EOF


sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart docker


检查是否生效：

sudo systemctl show --property=Environment docker

```