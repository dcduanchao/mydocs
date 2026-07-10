# mk部署安装

## conda 虚拟环境

```
# 创建 MkDocs 环境
conda create -n mkdocs python=3.11 -y
conda activate mkdocs

# 安装 MkDocs 与 Material 主题
pip install mkdocs mkdocs-material
mkdocs --version

```

## 创建文件夹或直接git拉取
```
比如：

cd ~/mydocs

测试
mkdocs serve -a 0.0.0.0:8008

```
##  mkdocs 配置
参考 [mkdocs.yml](../../mkdocs.yml)



## 正式
构建会多一个site 文件夹
```
mkdocs build

```


## nginx
可以根据自己nginx 配置 放site文件夹

```
docker run -d \
  --name nginx \
  -p 80:80 \
  -v ~/nginx/html/index.html:/usr/share/nginx/html/index.html:ro \
  -v ~/nginx/html/50x.html:/usr/share/nginx/html/50x.html:ro \
  -v ~/interview-notes/site:/usr/share/nginx/html/mynote:ro \
  -v ~/nginx/conf/default.conf:/etc/nginx/conf.d/default.conf:ro \
  --restart unless-stopped \
  nginx:latest
```


## 配置nginx

vim ~/nginx/conf/default.conf

```
server {
    listen 80;
    server_name _;

    # 默认首页
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ =404;
    }

    # MkDocs 面试笔记
    location /mynote {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ =404;
    }
}

```

## 不是docker 部署nginx
域名配置 [mydocs.du-ai.top.conf](../../nginx/mydocs.du-ai.top.conf)

```java
server {
    listen 80;
    listen [::]:80;

    server_name mydocs.du-ai.top;

    root /var/www/html/mydocs;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}

```