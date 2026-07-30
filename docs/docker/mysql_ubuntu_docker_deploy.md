# Ubuntu Docker 部署 MySQL：单机、主从与调优

本文以 MySQL 8.4 和 InnoDB 为基准，介绍单机部署及 1 Primary、2 Replica 的 GTID 复制。版本号是示例，生产环境应固定团队验证过的补丁版本，不能使用 `latest`。

## 1. 环境与端口

- Ubuntu 已安装 Docker Engine 和 Docker Compose Plugin。
- MySQL 默认端口为 `3306`。
- 主从节点之间网络稳定并启用时间同步。
- 数据目录使用本地 SSD，备份保存到独立存储。

```bash
docker version
docker compose version
timedatectl status
```

防火墙仅允许业务服务器和数据库节点访问 3306，不要暴露公网。

## 2. 单机版目录

```bash
sudo mkdir -p /opt/mysql-single/{conf,data,logs,backup}
sudo chown -R 999:999 /opt/mysql-single/data /opt/mysql-single/logs
cd /opt/mysql-single
```

创建 `.env`：

```dotenv
MYSQL_VERSION=8.4.6
MYSQL_ROOT_PASSWORD=请替换为高强度Root密码
MYSQL_DATABASE=app_db
MYSQL_USER=app_user
MYSQL_PASSWORD=请替换为高强度业务密码
MYSQL_PORT=3306
```

`.env` 只适合演示。生产环境优先使用 Docker Secret 或密钥管理系统，并限制文件权限：

```bash
chmod 600 .env
```

## 3. 单机配置

创建 `conf/my.cnf`：

```ini
[mysqld]
default-time-zone = +08:00
character-set-server = utf8mb4
collation-server = utf8mb4_0900_ai_ci

skip-name-resolve = ON
max_connections = 300
max_connect_errors = 1000

innodb_buffer_pool_size = 2G
innodb_redo_log_capacity = 1G
innodb_flush_log_at_trx_commit = 1
sync_binlog = 1

log_bin = mysql-bin
binlog_format = ROW
binlog_expire_logs_seconds = 604800

slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1
log_queries_not_using_indexes = OFF

performance_schema = ON
```

`innodb_buffer_pool_size` 必须按宿主机实际内存调整。专用数据库宿主机常从可用内存的 60%～70% 起步，容器与其他服务共用宿主机时必须更保守。

## 4. 单机 Docker Compose

创建 `compose.yml`：

```yaml
services:
  mysql:
    image: mysql:${MYSQL_VERSION}
    container_name: mysql-single
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      TZ: Asia/Shanghai
    ports:
      - "${MYSQL_PORT}:3306"
    volumes:
      - ./conf/my.cnf:/etc/mysql/conf.d/my.cnf:ro
      - ./data:/var/lib/mysql
      - ./logs:/var/log/mysql
      - ./backup:/backup
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -uroot -p$${MYSQL_ROOT_PASSWORD} --silent"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 60s
```

启动和验证：

```bash
docker compose up -d
docker compose ps
docker compose logs -f --tail=200 mysql

docker exec mysql-single mysql \
  -uroot -p"${MYSQL_ROOT_PASSWORD}" \
  -e "SELECT VERSION(), @@character_set_server, @@transaction_isolation;"
```

`MYSQL_DATABASE`、`MYSQL_USER` 等初始化变量只在 Data Directory 为空时生效。修改 `.env` 后重启已有实例不会重新创建账号或修改密码。

## 5. 1 主 2 从规划

| 节点 | 环境变量 | 端口 | server-id | 用途 |
|---|---|---:|---:|---|
| mysql-primary | `MYSQL_PRIMARY_IP` | 3306 | 1 | 业务写入 |
| mysql-replica-1 | `MYSQL_REPLICA_1_IP` | 3306 | 2 | 只读、容灾 |
| mysql-replica-2 | `MYSQL_REPLICA_2_IP` | 3306 | 3 | 只读、备份 |

每个节点部署在独立服务器。复制端口只允许数据库节点网段访问，业务端口只允许应用网段访问。

```bash
nc -vz <其他数据库节点IP> 3306
```

以下步骤适用于全新空集群。已有数据的实例必须先取得一致性全量备份，再基于该备份建立 Replica，不能让空 Replica 直接追增量日志。

## 6. 主从公共配置

三台服务器创建 `/opt/mysql-cluster/{conf,data,logs,backup}`，并将以下内容保存为 `conf/my.cnf`：

```ini
[mysqld]
default-time-zone = +08:00
character-set-server = utf8mb4
collation-server = utf8mb4_0900_ai_ci
skip-name-resolve = ON

log_bin = mysql-bin
binlog_format = ROW
binlog_row_image = FULL
binlog_expire_logs_seconds = 604800
gtid_mode = ON
enforce_gtid_consistency = ON

relay_log = relay-bin
relay_log_recovery = ON
log_replica_updates = ON
replica_parallel_workers = 4

innodb_buffer_pool_size = 4G
innodb_redo_log_capacity = 2G
innodb_flush_log_at_trx_commit = 1
sync_binlog = 1

max_connections = 500
slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1
performance_schema = ON
```

三台服务器的 MySQL 大版本、字符集、时区和关键复制配置保持一致。Heap/Buffer 等参数应按各机器容量单独评估。

## 7. 主从 Compose

三台服务器都创建 `compose.yml`：

```yaml
services:
  mysql:
    image: mysql:${MYSQL_VERSION}
    container_name: ${NODE_NAME}
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      TZ: Asia/Shanghai
    command:
      - --server-id=${SERVER_ID}
      - --report-host=${NODE_NAME}
      - --read-only=${READ_ONLY}
      - --super-read-only=${SUPER_READ_ONLY}
    ports:
      - "3306:3306"
    volumes:
      - ./conf/my.cnf:/etc/mysql/conf.d/my.cnf:ro
      - ./data:/var/lib/mysql
      - ./logs:/var/log/mysql
      - ./backup:/backup
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -uroot -p$${MYSQL_ROOT_PASSWORD} --silent"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 60s
```

每台服务器的 `.env` 公共部分：

```dotenv
MYSQL_VERSION=8.4.6
MYSQL_ROOT_PASSWORD=三台保持相同的高强度Root密码
MYSQL_PRIMARY_IP=请填写Primary地址
REPLICATION_USER=repl_user
REPLICATION_PASSWORD=请填写复制专用密码
```

Primary 追加：

```dotenv
NODE_NAME=mysql-primary
SERVER_ID=1
READ_ONLY=OFF
SUPER_READ_ONLY=OFF
```

Replica 1 追加：

```dotenv
NODE_NAME=mysql-replica-1
SERVER_ID=2
READ_ONLY=ON
SUPER_READ_ONLY=ON
```

Replica 2 追加：

```dotenv
NODE_NAME=mysql-replica-2
SERVER_ID=3
READ_ONLY=ON
SUPER_READ_ONLY=ON
```

设置目录权限并启动：

```bash
cd /opt/mysql-cluster
sudo chown -R 999:999 data logs
chmod 600 .env
docker compose up -d
docker compose ps
docker compose logs --tail=200 mysql
```

## 8. 建立 GTID 复制

全新集群建立复制前不要写入业务数据。先在 Primary 创建复制账号，仅允许数据库节点网段连接：

```bash
docker exec -it mysql-primary mysql -uroot -p
```

```sql
CREATE USER 'repl_user'@'数据库节点网段通配规则'
IDENTIFIED BY '请填写复制专用密码';

GRANT REPLICATION SLAVE ON *.*
TO 'repl_user'@'数据库节点网段通配规则';

SHOW BINARY LOG STATUS;
SELECT @@gtid_mode, @@server_id;
```

例如三个节点位于受控的 `192.168.30.0/24`，Host 可以按实际网络与 MySQL Host 匹配规则配置。不要在公网或不可信网络使用 `'%'` 放开复制账号。

分别进入两个 Replica：

```bash
docker exec -it mysql-replica-1 mysql -uroot -p
docker exec -it mysql-replica-2 mysql -uroot -p
```

执行：

```sql
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST = 'PRIMARY实际IP',
  SOURCE_PORT = 3306,
  SOURCE_USER = 'repl_user',
  SOURCE_PASSWORD = '请填写复制专用密码',
  SOURCE_AUTO_POSITION = 1,
  GET_SOURCE_PUBLIC_KEY = 1;

START REPLICA;
SHOW REPLICA STATUS\G
```

重点确认：

```text
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Last_IO_Error: 空
Last_SQL_Error: 空
```

`GET_SOURCE_PUBLIC_KEY=1` 解决未启用 TLS 时 `caching_sha2_password` 的密钥交换，但生产复制链路仍应启用 MySQL TLS，并配置 CA 和节点证书。

## 9. 验证复制

在 Primary 创建测试数据：

```sql
CREATE DATABASE replication_test;
CREATE TABLE replication_test.health_check (
    id BIGINT PRIMARY KEY,
    created_at DATETIME(3) NOT NULL
) ENGINE=InnoDB;

INSERT INTO replication_test.health_check
VALUES (1, NOW(3));
```

在两个 Replica 验证：

```sql
SELECT * FROM replication_test.health_check;
SHOW REPLICA STATUS\G
```

同时测试 Replica 拒绝普通账号写入。Root 等高权限账号可能绕过部分只读限制，日常业务严禁使用 Root。

## 10. 应用连接

Primary 负责写入和强一致读取，Replica 只承担读取允许短暂延迟的查询。

```text
写请求、关键写后读 -> Primary
报表、列表、可容忍延迟的读 -> Replica
```

应用不能只靠 JDBC URL 自动获得可靠故障切换。生产环境可使用 ProxySQL、MySQL Router、InnoDB Cluster、Orchestrator 或云数据库代理，并验证主节点选举、Fence、DNS/连接刷新和数据丢失边界。

本教程的异步 Primary/Replica 复制不会自动选主。直接把 Replica 改成可写可能形成双主和数据分叉，故障切换必须由经过验证的高可用流程完成。

## 11. 参数调优

### 11.1 Buffer Pool

`innodb_buffer_pool_size` 是最重要的内存参数之一。专用数据库机器可从可用内存 60%～70% 评估，容器共享宿主机时必须为操作系统、连接、Performance Schema 和其他进程留足空间。

观察：

```sql
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool%';
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
```

命中率高不代表 SQL 一定健康，大量扫描也可能把无效数据持续装入 Buffer Pool。

### 11.2 连接数

```text
数据库总连接 = 所有应用实例连接池之和 + 运维 + 复制 + 其他任务
```

`max_connections` 不能仅因为出现连接耗尽就增大。先检查慢查询、长事务、连接泄漏和应用扩容。每个连接都会消耗内存，过多活跃连接还会增加 CPU 调度和锁竞争。

### 11.3 Redo 与刷盘

- `innodb_flush_log_at_trx_commit=1`：事务提交时刷新 Redo，单机持久性最强。
- `sync_binlog=1`：每次事务提交同步 Binlog，降低机器故障时日志丢失风险。
- `innodb_redo_log_capacity`：过小会频繁 Checkpoint，过大会增加恢复时间和磁盘占用。

修改持久性参数必须先明确可接受 RPO，不能只为跑分降低刷盘保证。

### 11.4 慢查询

```sql
SHOW VARIABLES LIKE 'slow_query_log%';
SHOW VARIABLES LIKE 'long_query_time';
```

不建议长期启用 `log_queries_not_using_indexes`，小表或合理扫描也会产生大量噪声。慢日志应按总耗时、频率和扫描行数聚合分析。

### 11.5 Replica 并行重放

`replica_parallel_workers` 可提高可并行事务的重放吞吐，但单个超大事务仍可能造成延迟。调优前观察 Replica CPU、磁盘、Relay Log 和事务依赖，优先从写入端拆分超大批次。

## 12. 备份与恢复

### 12.1 逻辑备份

```bash
docker exec mysql-single mysqldump \
  -uroot -p"${MYSQL_ROOT_PASSWORD}" \
  --single-transaction \
  --routines --events --triggers \
  --set-gtid-purged=OFF \
  app_db > backup/app_db_$(date +%F_%H%M%S).sql
```

`--single-transaction` 适合 InnoDB 一致性备份，备份期间仍应避免 DDL。命令行密码可能出现在进程或历史中，生产备份使用受限配置文件或 Secret。

恢复到测试实例验证：

```bash
docker exec -i mysql-single mysql \
  -uroot -p"${MYSQL_ROOT_PASSWORD}" \
  app_db < backup/app_db.sql
```

### 12.2 物理备份与时间点恢复

大库优先评估 MySQL Enterprise Backup、Percona XtraBackup 或云厂商物理备份。完整恢复通常需要：

```text
最近一次全量备份
  -> 恢复增量备份
  -> 按 Binlog 重放到目标时间点
  -> 校验数据
  -> 切换流量
```

不要直接复制正在运行实例的 `/var/lib/mysql` 目录作为一致性备份。Replica 也不是备份，因为误操作会同步传播。

## 13. 升级与滚动维护

1. 阅读目标版本升级说明，验证驱动、字符集和弃用参数。
2. 创建可恢复备份并在测试环境演练。
3. 先升级 Replica，观察复制与业务读取。
4. 完成受控切换后升级原 Primary。
5. 校验表、GTID、复制状态、延迟和应用错误率。

MySQL 数据目录通常不支持直接降级。升级不能只依赖修改镜像标签，必须保留独立备份和回滚方案。

## 14. 常见问题

### 14.1 容器不断重启

```bash
docker compose logs --tail=300 mysql
docker inspect mysql-single
```

检查内存、配置项是否被当前版本支持、数据目录权限以及旧 Data Directory 是否与镜像版本兼容。

### 14.2 修改初始化密码不生效

`MYSQL_ROOT_PASSWORD` 只在空数据目录初始化时应用。已有实例应登录后执行 `ALTER USER`，不能删除生产 Data Directory 重新初始化。

### 14.3 Replica IO 线程为 No

检查 Primary 地址、3306 防火墙、复制账号 Host、密码、TLS/公钥配置和 Binlog。查看 `Last_IO_Error`，不要只反复执行 `START REPLICA`。

### 14.4 Replica SQL 线程为 No

查看 `Last_SQL_Error` 定位重复键、缺表或数据不一致。跳过事务会永久制造数据分叉，生产环境应先保存现场、确认 GTID 和数据差异，再通过重建或受控修复解决。

### 14.5 磁盘持续增长

检查 Binlog 保留、慢日志、General Log、备份文件、临时文件和业务数据。不要手工删除 MySQL 管理的 Binlog 文件，应使用保留配置或 `PURGE BINARY LOGS`。

### 14.6 Too many connections

先查看 Processlist、连接池、慢查询和长事务。临时提高连接数只能缓解症状，数据库过载时还可能加速故障扩散。

## 15. 生产环境检查清单

- [ ] 固定经过验证的 MySQL 8.4 补丁版本，不使用 `latest`。
- [ ] 数据、日志和备份目录持久化且权限正确。
- [ ] Root 只用于受控管理，应用使用最小权限账号。
- [ ] 3306 仅对可信网段开放，业务和复制链路启用 TLS。
- [ ] Buffer Pool、连接数、Redo 和慢日志经过容量评估。
- [ ] Primary 与 Replica 的 `server-id` 唯一，GTID 和 ROW Binlog 已启用。
- [ ] 监控复制线程、延迟、错误、GTID 和磁盘容量。
- [ ] 明确写后读一致性和故障切换策略。
- [ ] 全量备份与 Binlog 位于独立存储，并完成恢复演练。
- [ ] 维护和升级具有校验、切换、Fence 与回滚流程。
