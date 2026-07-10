# Docker 部署 Nginx（Ubuntu Server）

## 一、前提条件

确保系统已经安装：

* Docker
* Docker Compose（推荐，可选）

检查 Docker 是否正常运行：

```bash
docker --version
docker ps
```

如果 Docker 未启动：

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

---

## 二、拉取 Nginx 镜像

拉取最新版 Nginx：

```bash
docker pull nginx:latest
```

查看镜像：

```bash
docker images
```

---

## 三、快速启动 Nginx

直接运行：

```bash
docker run -d \
  --name nginx \
  --restart unless-stopped \
  -p 80:80 \
  nginx:latest
```

参数说明：

| 参数                       | 说明                |
| ------------------------ | ----------------- |
| -d                       | 后台运行              |
| --name nginx             | 容器名称              |
| --restart unless-stopped | 开机自动启动            |
| -p 80:80                 | 宿主机 80 端口映射到容器 80 |

查看容器：

```bash
docker ps
```

浏览器访问：

```
http://服务器IP
```

如果出现：

```
Welcome to nginx!
```

说明部署成功。

---

## 四、创建持久化目录（推荐）

为了方便后续修改配置、部署网站和查看日志，建议提前创建目录：

```bash
mkdir -p ~/docker/nginx
mkdir -p ~/docker/nginx/conf.d
mkdir -p ~/docker/nginx/html
mkdir -p ~/docker/nginx/logs
```

目录结构：

```
~/docker/nginx
├── conf.d
├── html
└── logs
```

---

## 五、复制默认配置

先启动一个临时容器：

```bash
docker run --name nginx-temp -d nginx
```

复制默认配置：

```bash
docker cp nginx-temp:/etc/nginx/nginx.conf ~/docker/nginx/nginx.conf

docker cp nginx-temp:/etc/nginx/conf.d ~/docker/nginx/
```

删除临时容器：

```bash
docker rm -f nginx-temp
```

---

## 六、正式部署（推荐）

运行：

```bash
docker run -d \
  --name nginx \
  --restart unless-stopped \
  -p 80:80 \
  -p 443:443 \
  -v ~/docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v ~/docker/nginx/conf.d:/etc/nginx/conf.d:ro \
  -v ~/docker/nginx/html:/usr/share/nginx/html \
  -v ~/docker/nginx/logs:/var/log/nginx \
  nginx:latest
```

说明：

* 网站目录

```
~/docker/nginx/html
```

* 配置目录

```
~/docker/nginx/conf.d
```

* 日志目录

```
~/docker/nginx/logs
```

---

## 七、Docker Compose 部署（推荐）

创建 `docker-compose.yml`：

```yaml
services:
  nginx:
    image: nginx:latest
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/html:/usr/share/nginx/html
      - ./nginx/logs:/var/log/nginx
```

启动：

```bash
docker compose up -d
```

停止：

```bash
docker compose down
```

重启：

```bash
docker compose restart
```

查看日志：

```bash
docker compose logs -f
```

---

## 八、常用 Docker 命令

查看容器：

```bash
docker ps
```

查看所有容器：

```bash
docker ps -a
```

查看日志：

```bash
docker logs nginx
```

实时日志：

```bash
docker logs -f nginx
```

进入容器：

```bash
docker exec -it nginx bash
```

重新启动：

```bash
docker restart nginx
```

停止容器：

```bash
docker stop nginx
```

启动容器：

```bash
docker start nginx
```

删除容器：

```bash
docker rm -f nginx
```

---

## 九、修改配置后重载

测试配置：

```bash
docker exec nginx nginx -t
```

重新加载配置：

```bash
docker exec nginx nginx -s reload
```

---

## 十、开放防火墙端口（如启用 UFW）

开放 HTTP：

```bash
sudo ufw allow 80/tcp
```

开放 HTTPS：

```bash
sudo ufw allow 443/tcp
```

查看状态：

```bash
sudo ufw status
```

---

# 十一、验证部署

查看容器：

```bash
docker ps
```

查看监听端口：

```bash
ss -tlnp
```

浏览器访问：

```
http://服务器IP
```

如果配置了域名：

```
http://你的域名
```

---

## 十二、目录建议

推荐目录结构：

```
~/docker
└── nginx
    ├── nginx.conf
    ├── conf.d
    │   └── default.conf
    ├── html
    │   └── index.html
    └── logs
```

---

