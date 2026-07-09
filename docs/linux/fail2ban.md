# 安装Fail2ban 防止暴力破解
```agsl
#安装 EPEL 仓库（必要）
sudo dnf install epel-release -y
#安装完成后可验证：
dnf repolist | grep epel

# 安装 fail2ban（自动封 IP）
sudo dnf install -y fail2ban

# 启用 fail2ban 服务
sudo systemctl enable --now fail2ban

# 配置 fail2ban 只需一条命令
cat <<EOF | sudo tee /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/secure
filter = sshd
maxretry = 3
bantime = 1d
findtime = 5m
EOF

#超过 3 次登录失败，IP 自动封禁 1 天（可改时间）
#避免攻击者无限尝试不同用户名、密码
#不影响你自己使用 SSH（建议用普通用户 + 密钥登录）


# 重启 fail2ban 生效
sudo systemctl restart fail2ban

# 查看当前已封锁的 IP
sudo fail2ban-client status sshd
# 开机自启
sudo systemctl enable --now fail2ban
```

# 查看移除封禁
```agsl

# 查看封禁
sudo fail2ban-client status sshd

# 移除
 sudo fail2ban-client set sshd unbanip 111.198.26.14

```