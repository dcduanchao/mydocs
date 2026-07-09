# clash 下载

https://github.com/MetaCubeX/mihomo
如：mihomo-darwin-amd64-compatible-v1.19.4.gz  兼容

```agsl
改名或者其他
mv 原文件名 新文件名
gunzip clash-linux.gz
chmod +x clash-linux
```

## 订阅链接config配置
修改配置
```agsl
geoip: false   //true 改成false
删除最下有个大写 geoip

external-controller: '192.168.30.30:9090'
```
## 启动

```agsl
./clash -f ~/sd/config2.yaml
```
## sh 启动
mihomo-linux-amd64-compatible-v1.19.3 替换包名
CONF 启动选择config
root/class-v 程序地址 真是替换
启动方式 ：./sh文件名.sh config2.yaml

```agsl

#!/bin/bash

## 终止 Clash 进程
pkill -f "mihomo-linux-amd64-compatible-v1.19.3 -f"
echo "Clash 已停止"


## ## 等待进程完全关闭
sleep 2
#
CONF=$1
LOGNAME=$(basename "$CONF" .yaml)
## ## 删除旧日志~ root
 rm -rf ~/sd/clash.log 
 echo "日志已清理"
#
 echo "正在重新启动 Clash"
#
## ## 重新启动 Clash，并记录日志
 nohup /root/class-v/mihomo-linux-amd64-compatible-v1.19.3 -f /root/class-v/"$CONF" > /root/class-v/clash.log 2>&1 & 
 echo "Clash 已重新启动，日志保存在 ~/sd/clash.log"
#
## ## 等待 Clash 先启动
 sleep 5

## ## 显示正在运行的进程
 echo "当前正在运行的进程："
 ps aux | grep -E 'mihomo-linux' | grep -v grep
```

## 无页面操作postman
```agsl
get：
http://192.168.30.30:9090/proxies

选择 put

http://192.168.30.30:9090/proxies/♻️ 自动选择
{"name":"🇭🇰 香港 08 TR"}
```


## 有页面操作yacd
```agsl
https://yacd.haishan.me/
浏览器切换https 到不安全  允许不安全访问
https://yacd.haishan.me/#/proxies

第二个：

https://metacubex.github.io/metacubexd/#/proxies
```

## 使用代理
```agsl



export http_proxy=http://192.168.30.30:7890
export https_proxy=http://192.168.30.30:7890
export no_proxy="localhost,127.0.0.1"

配置全局
~/.bashrc
或 
~/.bash_profile

export http_proxy=http://192.168.30.30:7890
export https_proxy=http://192.168.30.30:7890
export no_proxy="localhost,127.0.0.1"


-----------或--------------
echo 'export http_proxy=http://192.168.30.30:7890' >> ~/.bashrc
echo 'export https_proxy=http://192.168.30.30:7890' >> ~/.bashrc
echo 'export no_proxy=localhost,127.0.0.1,::1' >> ~/.bashrc

source ~/.bashrc
```

## 自定义海外服务器xui
没有域名vemss 不通  使用vless

```
mixed-port: 7890
allow-lan: true
bind-address: '*'
mode: rule
log-level: info
external-controller: '192.168.30.33:9090'

dns:
  enable: true
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - https://doh.pub/dns-query
    - https://dns.alidns.com/dns-query
  fallback:
    - https://1.1.1.1/dns-query
    - https://dns.google/dns-query
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4
proxies:
  - name: mg
    type: vless
    server: 155.94.**.**
    port: 10094
    uuid: 4ca1467c-803e-4a85-fec3-4ae6bba6a973
    network: tcp
    udp: true

proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - mg

rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
```


## TCP Fast Open (TFO) 的配置问题可能会慢慢

查看内核是否支持 TFO

sysctl net.ipv4.tcp_fastopen

输出例子：
net.ipv4.tcp_fastopen = 0

0 = 未启用
启用 TFO
1 = 仅客户端启用
2 = 仅服务端启用
3 = 客户端+服务端都启用

sudo sysctl -w net.ipv4.tcp_fastopen=3

永久生效
在 /etc/sysctl.conf 或 /etc/sysctl.d/99-tfo.conf 加入：
net.ipv4.tcp_fastopen=3
然后：
sudo sysctl -p

