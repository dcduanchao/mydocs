# 虚拟内存
当ram不够时候虚拟磁盘作为内存 占时使用

## 步骤

```
1.选择磁盘
cd /home/aiuser/ssddc

2.创建 Swap 文件
sudo fallocate -l 64G swapfile

3. 设置权限（普通用户可读写）
sudo chown aiuser:aiuser swapfile
chmod 600 swapfile
所有权给你当前用户 aiuser
权限 600 → 只有你可读写


如果想 所有用户都可读写：
sudo chmod 666 swapfile

4. 格式化为 Swap 把文件标记为 Swap 类型
sudo mkswap swapfile

5. 激活 Swap
系统开始把这个文件当作内存使用 普通用户程序（ComfyUI、Python 等）都可以使用 Swap 空间

sudo swapon swapfile

6.查看 Swap 状态
swapon --show
free -h


7. 永久挂载（可选）
系统重启后仍然生效：

sudo nano /etc/fstab
添加一行：
/home/aiuser/ssddc/swapfile none swap sw 0 0
保存退出系统启动时自动挂载

8.调整 Swap 使用倾向（可选）
sudo sysctl vm.swappiness=10
10~20 → 优先使用 RAM，Swap 仅作缓冲

永久生效：
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
# 立即生效 选一个

sudo sysctl -w vm.swappiness=10

sudo sysctl -p

-w → 只修改当前运行时

sysctl -p → 修改当前运行时 + 从文件永久保存

查看当前值

cat /proc/sys/vm/swappiness
输出 10 → 当前生效值
输出 60 → 默认值（或未应用


```

## 关闭
```
临时关闭 swap（立即生效）

sudo swapoff -a

开启
sudo swapon -a

或
sudo sysctl vm.swappiness=1
```


## 清理
```
清理 / 删除 Swap 文件
如果你不想再用这个 Swap：

1️⃣ 关闭 Swap
sudo swapoff /home/aiuser/ssddc/swapfile

系统立即停止使用 Swap 文件

2️⃣ 删除文件
rm /home/aiuser/ssddc/swapfile

3️⃣ 移除 fstab 条目（如果添加了永久挂载）
sudo nano /etc/fstab
删除
 /home/aiuser/ssddc/swapfile none swap sw 0 0 这一行

4 .使用倾向
sudo nano /etc/sysctl.conf
找到你之前添加的那一行：
vm.swappiness=10
删除或注释（在行前加 #）：
# vm.swappiness=10
保存退出
立即应用修改：
sudo sysctl -p
✅ 完全清理完成，系统恢复到原状态。
```