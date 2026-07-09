# v2rayA 部署

https://github.com/v2rayA/v2rayA/releases

installer_debian_x64_2.4.7.deb


## 安装
```
sudo dpkg -i installer_debian_x64_2.4.7.deb
如果提示依赖：

sudo apt --fix-broken install


sudo systemctl enable v2raya
sudo systemctl start v2raya

查看状态：

systemctl status v2raya
```
## 局域网

```
sudo systemctl edit v2raya

[Service]
Environment="V2RAYA_ADDRESS=0.0.0.0:2017"



然后
sudo systemctl daemon-reload
sudo systemctl restart v2raya
ss -lntp | grep 2017


访问：
http://这台Ubuntu的IP:2017
```
### 测试

```
默认端口20171  socket 20170
curl -x http://127.0.0.1:20171 https://www.google.com
```

### 修改密码
```
第一次创建账号时密码输错了，最简单的方法就是重置。

先停止服务：

sudo systemctl stop v2raya

然后执行：

sudo v2raya --reset-password

如果成功，一般会看到类似：

Config directory: /etc/v2raya
Resetting password...
Succeed.

然后重新启动：

sudo systemctl start v2raya
```


## 页面开启局域网访问

