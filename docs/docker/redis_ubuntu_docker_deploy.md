# Ubuntu Docker 部署 Redis：单机、集群与调优

本文使用 Docker Compose 部署 Redis 7，包含单机实例、3 主 3 从 Redis Cluster，以及持久化、操作系统和客户端调优。单机版适合开发、测试及低重要性业务；Redis Cluster 适合需要数据分片和水平扩展的场景。

Redis 的数据结构、持久化原理、Java 使用和并发控制参考：[Redis 全面讲解](../java/redis.md)。

## 1. 环境要求

- Ubuntu 22.04 或更高版本。
- 已安装 Docker Engine 和 Docker Compose 插件。
- 当前用户有执行 Docker 命令的权限。
- 服务器磁盘有足够空间保存 RDB、AOF 和日志。

检查环境：

```bash
docker version
docker compose version
```

## 2. 单机版：创建目录

```bash
sudo mkdir -p /opt/redis/conf /opt/redis/data
sudo chown -R "$USER":"$USER" /opt/redis
cd /opt/redis
```

目录用途：

```text
/opt/redis/
├── conf/
│   └── redis.conf
├── data/
└── docker-compose.yml
```

- `conf/redis.conf`：Redis 配置文件。
- `data/`：RDB、AOF 等持久化数据。
- `docker-compose.yml`：容器编排配置。

## 3. 单机版：Redis 配置

创建 `/opt/redis/conf/redis.conf`：

```conf
bind 0.0.0.0
port 6379
protected-mode yes
requirepass ChangeThisStrongPassword

dir /data
dbfilename dump.rdb

# RDB 快照规则
save 3600 1
save 300 100
save 60 10000

# 开启 AOF，每秒刷盘
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec

# 限制最大内存，并为缓存选择淘汰策略
maxmemory 2gb
maxmemory-policy allkeys-lru

# 慢查询日志：执行时间超过 10 毫秒时记录
slowlog-log-slower-than 10000
slowlog-max-len 256
```

关键配置：

| 配置 | 说明 |
|---|---|
| `requirepass` | 客户端访问密码，部署前必须替换。 |
| `dir /data` | 持久化文件写入容器的 `/data`，该目录会挂载到宿主机。 |
| `appendonly yes` | 开启 AOF 持久化。 |
| `appendfsync everysec` | 每秒刷盘一次，异常时理论上可能丢失约 1 秒数据。 |
| `maxmemory` | Redis 可使用的最大内存，应为系统和持久化预留空间。 |
| `maxmemory-policy` | 达到内存上限后的淘汰策略，应根据实例用途选择。 |

示例密码只用于说明。生产环境应使用强密码或 ACL，并通过 Secret 管理密码，不能将真实凭据提交到仓库。

## 4. 单机版：Docker Compose 配置

创建 `/opt/redis/docker-compose.yml`：

```yaml
services:
  redis:
    image: redis:7.4-alpine
    container_name: redis
    restart: unless-stopped
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    ports:
      - "192.168.30.116:6379:6379"
    volumes:
      - ./conf/redis.conf:/usr/local/etc/redis/redis.conf:ro
      - ./data:/data
    healthcheck:
      test: ["CMD-SHELL", "redis-cli -a 'ChangeThisStrongPassword' ping | grep PONG"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 10s
    deploy:
      resources:
        limits:
          memory: 3g
```

这里将端口绑定到单机服务器的内网地址 `192.168.30.116`。只允许业务服务器通过防火墙访问，不要把 `6379` 暴露到公网。如果 Docker 提示无法绑定该地址，先用 `ip addr` 确认 `192.168.30.116` 已配置在本机网卡上。

根据实际业务服务器网段放行访问，例如仅允许 `192.168.30.0/24`：

```bash
sudo ufw allow from 192.168.30.0/24 to 192.168.30.116 port 6379 proto tcp
sudo ufw status
```

容器内存上限要大于 Redis 的 `maxmemory`。Redis 除数据之外，还需要内存处理复制缓冲、客户端缓冲、AOF Rewrite、RDB 快照和内存碎片。

如果修改了示例密码，必须同时修改 `redis.conf` 和健康检查命令中的密码。更稳妥的生产方案是使用 ACL 和 Secret，避免密码直接出现在 Compose 文件和进程参数中。

## 5. 单机版：启动和验证

启动 Redis：

```bash
cd /opt/redis
docker compose config
docker compose up -d
docker compose ps
```

查看日志：

```bash
docker compose logs --tail=100 redis
docker compose logs -f redis
```

进入 Redis CLI：

```bash
docker exec -it redis redis-cli -a 'ChangeThisStrongPassword'
```

执行基础检查：

```redis
PING
SET hello redis
GET hello
INFO server
INFO memory
INFO persistence
```

预期结果：

```text
PING              -> PONG
GET hello         -> redis
aof_enabled       -> 1
rdb_last_bgsave_status -> ok
```

也可以在宿主机安装 `redis-tools` 后连接：

```bash
sudo apt update
sudo apt install -y redis-tools
redis-cli -h 192.168.30.116 -p 6379 -a 'ChangeThisStrongPassword' PING
```

## 6. 单机版：验证持久化

写入测试数据：

```bash
docker exec redis redis-cli -a 'ChangeThisStrongPassword' \
  SET deploy:persistence:test success
```

重启容器：

```bash
docker compose restart redis
```

再次读取：

```bash
docker exec redis redis-cli -a 'ChangeThisStrongPassword' \
  GET deploy:persistence:test
```

返回 `success` 表示容器重启后数据仍然存在。检查宿主机数据目录：

```bash
find /opt/redis/data -maxdepth 2 -type f -ls
```

Redis 7 的 AOF 通常使用多文件结构，文件可能位于 `appendonlydir` 子目录。备份时应整体处理当前 AOF 目录，不要只复制其中一个增量文件。

测试只能证明挂载和当前持久化配置生效，不能证明数据绝对不会丢失。RDB、AOF、复制和备份策略的区别参考主篇的[持久化章节](../java/redis.md#5-持久化)。

## 7. 集群版：3 主 3 从 Redis Cluster

### 7.1 集群拓扑

Redis Cluster 把 16384 个哈希槽分配到多个主节点。生产环境至少需要 3 个主节点；每个主节点再配置一个从节点后，可以在单个节点故障时自动切换。

集群使用 3 台 Ubuntu 服务器，每台运行两个 Redis 容器：

| 服务器 | 节点端口 | 预期用途 |
|---|---|---|
| `192.168.30.117` | 6379、7379 | 6379 作为主节点候选，7379 作为跨主机副本候选 |
| `192.168.30.118` | 6379、7379 | 6379 作为主节点候选，7379 作为跨主机副本候选 |
| `192.168.30.119` | 6379、7379 | 6379 作为主节点候选，7379 作为跨主机副本候选 |

目标拓扑如下，主节点和自己的从节点位于不同服务器：

```text
192.168.30.117:6379 (Master) -> 192.168.30.118:7379 (Replica)
192.168.30.118:6379 (Master) -> 192.168.30.119:7379 (Replica)
192.168.30.119:6379 (Master) -> 192.168.30.117:7379 (Replica)
```

`redis-cli --cluster create` 会根据节点地址自动安排副本，实际对应关系以执行前显示的分配计划和 `CLUSTER NODES` 为准。必须确认每个主节点的副本位于另一台服务器；如果不满足，不要确认建群。

集群节点需要互相访问服务端口和 Cluster Bus 端口。Bus 端口默认是服务端口加 `10000`，因此主节点 `6379` 的 Bus 端口是 `16379`，从节点 `7379` 的 Bus 端口是 `17379`。

### 7.2 创建集群目录

```bash
sudo mkdir -p /opt/redis-cluster/conf
sudo mkdir -p /opt/redis-cluster/data/{node-a,node-b}
sudo chown -R "$USER":"$USER" /opt/redis-cluster
cd /opt/redis-cluster
```

目录结构：

```text
/opt/redis-cluster/
├── conf/
│   ├── common.conf
│   ├── node-a.conf
│   └── node-b.conf
├── data/
│   ├── node-a/
│   └── node-b/
├── .env
└── docker-compose.yml
```

以上目录创建命令需要在 `.117`、`.118` 和 `.119` 三台服务器上分别执行。

### 7.3 创建公共配置

创建 `/opt/redis-cluster/conf/common.conf`：

```conf
bind 0.0.0.0
protected-mode yes
requirepass ChangeThisStrongPassword
masterauth ChangeThisStrongPassword

cluster-enabled yes
cluster-node-timeout 15000
cluster-require-full-coverage yes

appendonly yes
appendfsync everysec
save 3600 1
save 300 100
save 60 10000

maxmemory 1gb
maxmemory-policy noeviction

slowlog-log-slower-than 10000
slowlog-max-len 256
```

`masterauth` 用于从节点连接主节点，必须和节点认证配置匹配。示例使用 `requirepass` 便于演示，生产环境建议使用 ACL，并让集群节点间认证和业务客户端权限相互隔离。

### 7.4 创建节点配置

先在每台服务器创建自己的 `/opt/redis-cluster/.env`。

在 `192.168.30.117` 执行：

```bash
cat > /opt/redis-cluster/.env <<'EOF'
REDIS_ANNOUNCE_IP=192.168.30.117
NODE_A_PORT=6379
NODE_B_PORT=7379
EOF
```

在 `192.168.30.118` 执行：

```bash
cat > /opt/redis-cluster/.env <<'EOF'
REDIS_ANNOUNCE_IP=192.168.30.118
NODE_A_PORT=6379
NODE_B_PORT=7379
EOF
```

在 `192.168.30.119` 执行：

```bash
cat > /opt/redis-cluster/.env <<'EOF'
REDIS_ANNOUNCE_IP=192.168.30.119
NODE_A_PORT=6379
NODE_B_PORT=7379
EOF
```

然后在每台服务器执行相同的配置生成命令：

```bash
cd /opt/redis-cluster
set -a
source .env
set +a

for node in node-a node-b; do
  if [ "$node" = "node-a" ]; then
    port="$NODE_A_PORT"
  else
    port="$NODE_B_PORT"
  fi
  bus_port=$((port + 10000))

  cat > "conf/${node}.conf" <<EOF
include /usr/local/etc/redis/common.conf
port ${port}
dir /data
cluster-config-file nodes.conf
cluster-announce-ip ${REDIS_ANNOUNCE_IP}
cluster-announce-port ${port}
cluster-announce-bus-port ${bus_port}
EOF
done
```

`cluster-announce-ip` 不能填写 `127.0.0.1`，也不能填写其他主机无法访问的容器内部地址。配置错误时，客户端虽然能连接入口节点，却会在重定向到其他槽时失败。

生成后检查两个配置文件中的 IP 和端口，不能把一台服务器的 `.env` 复制到另外两台直接使用：

```bash
grep -E '^(port|cluster-announce)' conf/node-a.conf conf/node-b.conf
```

### 7.5 创建集群 Compose 文件

创建 `/opt/redis-cluster/docker-compose.yml`：

```yaml
x-redis-common: &redis-common
  image: redis:7.4-alpine
  restart: unless-stopped
  network_mode: host

services:
  redis-node-a:
    <<: *redis-common
    container_name: redis-${NODE_A_PORT}
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    volumes:
      - ./conf/common.conf:/usr/local/etc/redis/common.conf:ro
      - ./conf/node-a.conf:/usr/local/etc/redis/redis.conf:ro
      - ./data/node-a:/data

  redis-node-b:
    <<: *redis-common
    container_name: redis-${NODE_B_PORT}
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    volumes:
      - ./conf/common.conf:/usr/local/etc/redis/common.conf:ro
      - ./conf/node-b.conf:/usr/local/etc/redis/redis.conf:ro
      - ./data/node-b:/data
```

三台服务器使用同一份 Compose 模板，Compose 会读取各自 `.env` 中的端口生成容器名称。这里使用 `network_mode: host`，避免 Docker 端口映射和 Cluster 对外宣告地址不一致。Host 网络只适用于 Linux，并且同一服务器上的节点必须使用不同端口。

### 7.6 开放集群端口

只允许业务服务器和 Redis 集群节点的内网网段访问，不要向公网开放：

```bash
sudo ufw allow from 192.168.30.0/24 to any port 6379 proto tcp
sudo ufw allow from 192.168.30.0/24 to any port 7379 proto tcp
sudo ufw allow from 192.168.30.0/24 to any port 16379 proto tcp
sudo ufw allow from 192.168.30.0/24 to any port 17379 proto tcp
sudo ufw status
```

- `6379`、`7379`：客户端命令端口。
- `16379`、`17379`：节点发现、故障检测和配置传播使用的 Cluster Bus 端口。

多服务器部署还要检查云安全组、宿主机防火墙和跨服务器路由。

### 7.7 启动并创建集群

在 `.117`、`.118`、`.119` 三台服务器上分别启动本机的两个节点：

```bash
cd /opt/redis-cluster
docker compose config
docker compose up -d
docker compose ps
```

确认所有节点都能响应后，只执行一次集群创建命令：

```bash
docker exec -it redis-6379 redis-cli \
  -a 'ChangeThisStrongPassword' \
  --cluster create \
  192.168.30.117:6379 \
  192.168.30.118:6379 \
  192.168.30.119:6379 \
  192.168.30.117:7379 \
  192.168.30.118:7379 \
  192.168.30.119:7379 \
  --cluster-replicas 1
```

该命令在 `192.168.30.117` 上执行。输入 `yes` 前检查输出的主从分配，确保每个 Replica 与自己的 Master 不在同一 IP；确认无误后再建群。

不要在已经保存业务数据或带有旧 `nodes.conf` 的节点上直接重新执行建群命令。重新组建集群前必须先确认数据迁移和备份方案。

### 7.8 验证集群

```bash
docker exec redis-6379 redis-cli \
  -a 'ChangeThisStrongPassword' -p 6379 CLUSTER INFO

docker exec redis-6379 redis-cli \
  -a 'ChangeThisStrongPassword' -p 6379 CLUSTER NODES

docker exec redis-6379 redis-cli \
  -a 'ChangeThisStrongPassword' \
  --cluster check 192.168.30.117:6379
```

关键结果：

```text
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_known_nodes:6
```

使用 `-c` 让 `redis-cli` 自动跟随 `MOVED` 和 `ASK` 重定向：

```bash
docker exec -it redis-6379 redis-cli \
  -a 'ChangeThisStrongPassword' -c -p 6379
```

```redis
SET order:{1001}:status created
GET order:{1001}:status
CLUSTER KEYSLOT order:{1001}:status
```

Java 客户端必须启用 Redis Cluster 模式并至少配置多个节点地址。Cluster 只支持数据库 `0`；多 Key 命令、事务和 Lua 脚本涉及的 Key 通常必须位于同一槽，可以使用 `{1001}` 这样的 Hash Tag 控制槽位。

Spring Boot Cluster 连接示例：

```yaml
spring:
  data:
    redis:
      password: ${REDIS_PASSWORD}
      connect-timeout: 2s
      timeout: 1s
      cluster:
        nodes:
          - 192.168.30.117:6379
          - 192.168.30.117:7379
          - 192.168.30.118:6379
          - 192.168.30.118:7379
          - 192.168.30.119:6379
          - 192.168.30.119:7379
        max-redirects: 5
      lettuce:
        cluster:
          refresh:
            adaptive: true
            period: 30s
```

业务客户端需要能访问六个服务端口。只配置一个入口节点虽然可以获取初始拓扑，但该节点不可用时会影响应用启动和拓扑刷新。

### 7.9 多服务器生产部署要点

- 至少 3 台服务器或故障域，主节点和自己的从节点不能位于同一台服务器。
- 每个容器的 `cluster-announce-ip` 必须是其他节点和客户端可达的内网 IP。
- 客户端端口与 Cluster Bus 端口都必须双向连通。
- 单节点 `maxmemory` 按所在服务器内存计算，不能把同一主机上多个节点都配置到接近整机内存。
- 为每个节点使用独立数据目录、监控指标和持久化磁盘。
- 扩缩容使用 `redis-cli --cluster add-node`、`reshard` 和 `del-node` 等受控流程，不能只增加或删除容器。
- 定期演练主节点故障切换，并验证副本是否分布在不同故障域。

## 8. 配置与性能调优

调优前先明确实例角色、数据量、读写比例、允许丢失窗口和延迟目标。没有压测与监控数据时，盲目修改参数通常只会把问题转移到其他资源。

### 8.1 内存与淘汰策略

`maxmemory` 不能等于容器或服务器的全部内存。持久化、复制、客户端缓冲、内存碎片以及 `fork` 后的写时复制都需要额外空间。

建议起点：

| 场景 | `maxmemory` 建议 | 淘汰策略 |
|---|---|---|
| 纯缓存实例 | 容器内存的 70% 至 80% | `allkeys-lfu` 或 `allkeys-lru` |
| 缓存且只有部分 Key 有 TTL | 容器内存的 70% 至 80% | 优先评估 `allkeys-lfu`，避免无 TTL Key 挤满内存 |
| 不允许自动丢数据 | 根据峰值数据量预留充足空间 | `noeviction`，写满后让写命令失败并告警 |
| 开启 RDB/AOF 且写入量大 | 通常不超过容器内存的 60% 至 70% | 根据数据角色选择 |

```conf
maxmemory 8gb
maxmemory-policy allkeys-lfu
maxmemory-samples 10
```

生产中不要在同一个实例混放“可淘汰缓存”和“不可丢业务数据”，否则很难选择正确的淘汰策略。

### 8.2 持久化调优

通用折中配置：

```conf
appendonly yes
appendfsync everysec
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 256mb
no-appendfsync-on-rewrite no

save 3600 1
save 300 100
save 60 10000
rdbcompression yes
rdbchecksum yes
```

- `appendfsync everysec`：通常最多承担约 1 秒数据丢失窗口，性能明显好于 `always`。
- `no-appendfsync-on-rewrite no`：Rewrite 期间仍刷盘，数据更安全，但磁盘压力较大。改为 `yes` 可以降低延迟抖动，也会扩大故障时的数据丢失窗口。
- AOF Rewrite 与 RDB 都会产生 `fork`、写时复制和磁盘 I/O，应监控 `latest_fork_usec`、磁盘延迟和内存峰值。
- 纯缓存且数据可从数据库完全重建时，可以降低快照频率或关闭持久化，但必须经过业务确认。

### 8.3 网络与客户端连接

```conf
tcp-backlog 511
tcp-keepalive 300
timeout 0
maxclients 10000
```

- `maxclients` 必须结合 Linux 文件描述符上限设置，不能只修改 Redis 配置。
- 客户端要设置连接超时、命令超时和连接池最大等待时间，禁止无限等待和无限重试。
- 连接池不是越大越好。总连接数等于单实例连接池乘以应用实例数，过多连接会增加缓冲内存和故障恢复压力。
- 批量读写使用 `MGET`、`MSET` 或 Pipeline 减少网络往返，但每批应限制命令数和数据量。
- Cluster 客户端至少配置 3 个种子节点，并启用拓扑刷新，避免单个入口地址故障导致无法发现新拓扑。

Spring Boot 可以从以下连接池参数开始压测，再根据 P99 延迟和池等待时间调整：

```yaml
spring:
  data:
    redis:
      connect-timeout: 2s
      timeout: 1s
      lettuce:
        pool:
          max-active: 32
          max-idle: 16
          min-idle: 4
          max-wait: 500ms
```

### 8.4 慢命令与异步释放

```conf
slowlog-log-slower-than 10000
slowlog-max-len 1024
latency-monitor-threshold 100

lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
replica-lazy-flush yes
```

异步释放可以降低删除 Big Key 时阻塞主线程的风险，但后台释放仍会消耗 CPU 和内存。业务侧仍应拆分 Big Key，并优先使用 `UNLINK` 而不是对大对象执行 `DEL`。

避免在线执行：

- `KEYS *`。
- 对超大集合执行 `HGETALL`、`SMEMBERS`、`LRANGE 0 -1`。
- 大范围 Lua 循环。
- 一次提交几十万条命令的 Pipeline。

### 8.5 Cluster 专项参数

```conf
cluster-node-timeout 15000
cluster-require-full-coverage yes
cluster-migration-barrier 1
```

- `cluster-node-timeout` 太小容易因短暂网络抖动发生误判，太大则延长故障发现时间。可从 15 秒开始，结合网络质量和恢复目标压测。
- `cluster-require-full-coverage yes` 在部分槽不可用时将集群标记为不可用，相关数据命令返回 `CLUSTERDOWN`；改为 `no` 可让健康槽继续服务，但应用必须能处理部分 Key 可用、部分 Key 不可用。
- 槽位应尽量均衡，但还要结合每个槽的内存和 QPS，不能只看槽数量。
- 热 Key 即使在 Cluster 中也只落在一个主节点，需要通过本地缓存、Key 拆分或请求合并治理。

### 8.6 Linux 系统调优

创建 `/etc/sysctl.d/99-redis.conf`：

```conf
vm.overcommit_memory = 1
net.core.somaxconn = 1024
```

加载配置：

```bash
sudo sysctl --system
```

关闭透明大页可以减少延迟抖动。先临时验证：

```bash
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/enabled
```

临时设置会在重启后失效，生产环境应通过 systemd 服务在开机时设置，并验证操作系统版本对应的 THP 路径。

文件描述符上限应大于 Redis `maxclients`，还要为持久化文件、复制连接和系统其他进程预留空间。容器环境需要同时检查宿主机和容器限制：

```bash
ulimit -n
docker exec redis sh -c 'ulimit -n'
```

尽量避免 Redis 使用 Swap。Swap 会造成明显延迟，但也不应在不了解整机工作负载时简单关闭；应通过合理 `maxmemory`、容器限制和内存告警防止进入交换。

### 8.7 CPU 与部署调优

Redis 核心命令执行主要受单核性能影响。单实例 CPU 已经持续接近一个核心瓶颈时，给同一实例增加更多核心不一定能线性提高命令吞吐，应考虑：

- 删除慢命令并拆分 Big Key。
- 使用 Pipeline 降低网络成本。
- 将读请求按一致性要求分散到只读副本。
- 使用 Redis Cluster 增加主分片数量。
- 将高 QPS 热 Key 拆分或增加应用本地缓存。

Redis 6 及以上可以使用 I/O 线程分担网络读写。只有在网络读写已经成为明确瓶颈、机器有足够 CPU 核心时才考虑开启：

```conf
io-threads 4
io-threads-do-reads yes
```

I/O 线程不会让命令执行本身变成多线程。线程数应明显小于 CPU 核心数，并通过压测验证；在低负载或 CPU 核心较少的机器上开启，反而可能增加调度成本。

不要让多个高负载 Redis 容器无约束地争抢同一组 CPU、内存和磁盘。生产节点应设置资源限制，并持续观察 CPU steal、磁盘延迟和网络吞吐。

### 8.8 调优后的验证指标

每次只修改少量参数，并用相同流量模型对比：

| 指标 | 关注点 |
|---|---|
| P50、P95、P99 延迟 | 尾延迟是否改善，是否出现周期性尖峰。 |
| `instantaneous_ops_per_sec` | 吞吐是否达到目标。 |
| `used_memory`、`used_memory_rss` | 数据内存、碎片和额外内存是否在预算内。 |
| `evicted_keys`、`rejected_connections` | 是否发生淘汰或连接拒绝。 |
| `blocked_clients` | 是否存在异常阻塞等待。 |
| `latest_fork_usec` | RDB/AOF Rewrite 的 fork 是否造成延迟。 |
| 主从复制偏移和延迟 | 副本是否及时跟上主节点。 |
| Cluster 槽位、内存和 QPS 分布 | 是否存在分片倾斜。 |

## 9. 日常管理

```bash
# 查看状态
docker compose ps

# 查看资源使用
docker stats redis

# 重启
docker compose restart redis

# 停止但保留容器和数据
docker compose stop

# 启动已停止的容器
docker compose start

# 删除容器和网络，但保留宿主机 data 目录
docker compose down
```

不要使用 `docker compose down -v` 删除生产数据卷。本文使用宿主机目录挂载，但养成区分“删除容器”和“删除数据”的习惯仍然很重要。

集群版常用检查：

```bash
cd /opt/redis-cluster
set -a
source .env
set +a

docker compose ps
docker stats "redis-${NODE_A_PORT}" "redis-${NODE_B_PORT}"

# 以下集群命令在 192.168.30.117 上执行
docker exec redis-6379 redis-cli \
  -a 'ChangeThisStrongPassword' -p 6379 CLUSTER INFO

docker exec redis-6379 redis-cli \
  -a 'ChangeThisStrongPassword' \
  --cluster check 192.168.30.117:6379
```

不要同时重启全部集群节点。维护时一次只处理一个从节点或主节点，等待它重新加入并完成复制后再继续下一个节点。

## 10. 备份与恢复

### 10.1 生成 RDB 快照

```bash
docker exec redis redis-cli -a 'ChangeThisStrongPassword' BGSAVE
docker exec redis redis-cli -a 'ChangeThisStrongPassword' LASTSAVE
```

等待 `BGSAVE` 完成后，将 `/opt/redis/data` 中的持久化文件复制到独立备份存储。备份不能只保存在同一块服务器磁盘上。

### 10.2 恢复注意事项

恢复前应：

1. 确认备份对应的 Redis 版本和持久化模式。
2. 停止目标 Redis，保留当前数据目录的副本。
3. 将完整备份放入数据目录，并确认文件属主和权限。
4. 启动 Redis，检查日志和 `INFO persistence`。
5. 验证关键 Key、TTL 和业务读写。

不要直接覆盖正在运行实例的数据文件。生产环境应定期在隔离环境执行恢复演练，仅有备份文件但从未验证恢复流程并不可靠。

### 10.3 Cluster 备份

Redis Cluster 的每个主节点只保存一部分槽和数据，因此必须备份所有主分片。只备份入口节点不能恢复完整集群。

建议流程：

1. 记录 `CLUSTER NODES`、槽位分布、节点 ID 和 Redis 版本。
2. 对每个主节点触发 `BGSAVE`，确认 `rdb_bgsave_in_progress:0` 和 `rdb_last_bgsave_status:ok`。
3. 分别复制每个主节点的数据目录，并保留节点与备份文件的对应关系。
4. 将备份保存到集群之外的独立存储并校验完整性。
5. 在隔离环境创建目标集群，按槽位和业务方案导入数据，验证 Key 数量、TTL 和抽样业务数据。

各主节点分别生成的 RDB 不具备跨分片的同一时刻事务快照。如果业务要求全局一致备份，应在应用层暂停或协调写入，或使用支持一致性备份的托管方案和专用工具。

## 11. 升级 Redis

### 11.1 单机版升级

升级前先阅读目标版本发布说明，并完成备份和恢复验证：

```bash
cd /opt/redis
docker compose pull redis
docker compose up -d redis
docker compose ps
docker compose logs --tail=100 redis
```

不要长期使用浮动的 `latest` 标签。修改镜像版本后，应检查数据格式、配置项、客户端兼容性和模块兼容性。

### 11.2 Cluster 滚动升级

Cluster 不能直接同时执行全部节点的 `docker compose up -d`。建议按以下顺序滚动处理：

1. 完整备份，确认集群状态为 `ok`，所有主节点都有健康从节点。
2. 先升级一个从节点，等待它重新加入并追平主节点复制偏移。
3. 对对应主节点执行受控故障转移，让已升级从节点成为主节点。
4. 升级原主节点，等待它作为从节点追平数据。
5. 逐个主从组重复操作，每一步都检查槽位、复制和业务读写。

在目标从节点上执行手动故障转移：

```bash
docker exec redis-7379 redis-cli \
  -a 'ChangeThisStrongPassword' -p 7379 CLUSTER FAILOVER
```

执行前必须通过 `CLUSTER NODES` 确认 `redis-7379` 确实是目标主节点的健康从节点。升级期间应有足够容量承受节点离线，并设置业务变更窗口和回滚方案。

## 12. 常见问题

### 12.1 容器启动后不断重启

```bash
docker compose ps
docker compose logs --tail=200 redis
docker compose config
```

重点检查配置文件语法、挂载路径、数据目录权限以及容器内存限制。

### 12.2 容器重建后数据消失

检查挂载是否存在：

```bash
docker inspect redis --format '{{json .Mounts}}'
ls -la /opt/redis/data
```

常见原因是 `/data` 没有挂载到持久化目录，或 Compose 在错误目录启动，导致相对路径指向其他位置。

### 12.3 出现 MISCONF 错误

如果提示无法保存 RDB：

```bash
df -h
df -i
ls -ld /opt/redis/data
docker compose logs --tail=200 redis
```

检查磁盘空间、inode、目录权限和 Redis 日志。不要直接关闭 `stop-writes-on-bgsave-error` 来掩盖故障。

### 12.4 外部应用无法连接

依次检查：

- Compose 是否只绑定了 `127.0.0.1`。
- Redis 的 `bind`、`protected-mode` 和 ACL 配置。
- Ubuntu 防火墙、云安全组和网络路由。
- 应用使用的密码、端口及连接超时。

需要远程访问时，将端口映射改为内网 IP，例如：

```yaml
ports:
  - "192.168.30.116:6379:6379"
```

### 12.5 Cluster 状态不是 ok

```bash
docker exec redis-6379 redis-cli \
  -a 'ChangeThisStrongPassword' -p 6379 CLUSTER INFO
docker exec redis-6379 redis-cli \
  -a 'ChangeThisStrongPassword' -p 6379 CLUSTER NODES
```

重点检查：

- 16384 个槽是否全部分配。
- 服务端口和 Cluster Bus 端口是否双向连通。
- `cluster-announce-ip` 是否可被所有节点和客户端访问。
- 节点的 `nodes.conf` 是否来自旧集群。
- 主从认证密码是否一致，系统时间和网络是否正常。

## 13. 生产环境检查清单

- 镜像使用明确版本，没有使用 `latest`。
- `6379` 未暴露到公网，并配置了安全组和防火墙。
- 使用强密码或 ACL，真实凭据不在仓库和日志中。
- `/data` 已挂载到可靠的持久化磁盘。
- `maxmemory` 小于容器或主机内存上限，并预留后台任务空间。
- 根据业务要求配置 RDB、AOF、独立备份和恢复演练。
- 已监控内存、延迟、慢查询、淘汰、持久化和磁盘空间。
- 关键业务不依赖单机实例，已评估 Sentinel、Cluster 或托管服务。
- Cluster 主从副本分布在不同服务器或故障域，服务端口和 Bus 端口均已受控开放。
- 参数修改经过容量评估和压测，并记录了修改前后的 P99 延迟、吞吐和内存峰值。
