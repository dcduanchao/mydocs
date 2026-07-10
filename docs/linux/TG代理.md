# TG代理

## docker安装tg代理

[docker hun 地址](https://hub.docker.com/r/telegrammessenger/proxy)
```agsl
docker pull telegrammessenger/proxy

可以自定义外部端口
 --restart unless-stopped \
  --name=mtproto-proxy \
固定私钥
docker run -d -p443:443 -v proxy-config:/data -e SECRET=00baadf00d15abad1deaa51sbaadcafe telegrammessenger/proxy:latest

代理最多可以配置为接受 16 个不同的密钥。您可以在 SECRET 环境变量中将它们明确指定为以逗号分隔的十六进制字符串，也可以让容器使用 SECRET_COUNT 变量自动生成密钥，以限制生成的密钥数量。
docker run -d -p443:443 -v proxy-config:/data -e SECRET=935ddceb2f6bbbb78363b224099f75c8,2084c7e58d8213296a3206da70356c81 telegrammessenger/proxy:latest

日志查看秘钥 
docker run -d -p443:443 -v proxy-config:/data -e SECRET_COUNT=4 telegrammessenger/proxy:latest

docker run -d -p443:443 -v proxy-config:/data -e WORKERS=16 telegrammessenger/proxy:latest
```

# 连接
日志输出多个连接 其中如下
```agsl
手动配置
[*]   tg:// link for secret 1 auto configuration: tg://proxy?server=xxx&port=443&secret=e7bbaf4e411bbbe5a5b911567d1f2b2f

http访问自动配置
[*]   t.me link for secret 1: https://t.me/proxy?server=xxx&port=443&secret=e7bbaf4e411bbbe5a5b911567d1f2b2f

```