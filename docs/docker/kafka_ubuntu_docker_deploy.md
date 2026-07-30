# Ubuntu Docker 部署 Kafka

本文档按以下机器规划部署 Kafka：

| 机器 | 用途 | IP |
|---|---|---|
| Kafka 单机 | 单节点 Kafka | `192.168.30.116` |
| Kafka 集群节点 1 | Broker 1 + Controller 1 | `192.168.30.117` |
| Kafka 集群节点 2 | Broker 2 + Controller 2 | `192.168.30.118` |
| Kafka 集群节点 3 | Broker 3 + Controller 3 | `192.168.30.119` |
| Kafka 监控 | Kafka UI 可视化页面 | `192.168.30.115` |

部署方式：

- Kafka 使用 Docker Compose 部署。
- Kafka 使用 KRaft 模式，不依赖 ZooKeeper。
- Kafka 数据目录统一挂载到宿主机 `/data/kafka/data`。
- 监控页面使用 Kafka UI，可以查看 Broker、Topic、Partition、Consumer Group、消息内容等。

---

## 1. 部署前准备

### 1.1 关闭或放通防火墙

如果启用了 `ufw`，Kafka 节点需要放通：

```bash
sudo ufw allow 9092/tcp
sudo ufw allow 9093/tcp
```

监控节点 `192.168.30.115` 需要放通：

```bash
sudo ufw allow 8080/tcp
```

如果是云服务器，还要在安全组里放通这些端口。

### 1.2 创建目录

Kafka 节点执行：

```bash
sudo mkdir -p /data/kafka/data
sudo mkdir -p /opt/kafka
sudo chown -R 1000:1000 /data/kafka
```

监控节点执行：

```bash
sudo mkdir -p /opt/kafka-ui
```

说明：

- `/opt/kafka`：保存 `docker-compose.yml`。
- `/data/kafka/data`：Kafka 消息数据目录。
- Kafka 里的 `log.dirs` 不是普通应用日志，而是消息数据日志目录，所以必须持久化挂载。

---

## 2. 单机部署 Kafka

单机部署在：

```text
192.168.30.116
```

### 2.1 创建 Compose 文件

在 `192.168.30.116` 执行：

```bash
cd /opt/kafka
sudo vim docker-compose.yml
```

写入：

```yaml
services:
  kafka:
    image: apache/kafka:4.3.1
    container_name: kafka-single
    restart: always
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      CLUSTER_ID: "kafka-single-cluster-001"
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: "broker,controller"
      KAFKA_CONTROLLER_QUORUM_VOTERS: "1@192.168.30.116:9093"
      KAFKA_LISTENERS: "PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093"
      KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://192.168.30.116:9092"
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: "PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT"
      KAFKA_INTER_BROKER_LISTENER_NAME: "PLAINTEXT"
      KAFKA_CONTROLLER_LISTENER_NAMES: "CONTROLLER"
      KAFKA_LOG_DIRS: "/var/lib/kafka/data"
      KAFKA_NUM_PARTITIONS: 3
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"
    volumes:
      - /data/kafka/data:/var/lib/kafka/data
```

重点：

- 单机副本因子只能使用 `1`。
- `KAFKA_ADVERTISED_LISTENERS` 必须写客户端能访问的 IP，这里是 `192.168.30.116`。
- `/data/kafka/data` 是宿主机持久化数据目录。

### 2.2 启动单机 Kafka

```bash
cd /opt/kafka
sudo docker compose up -d
```

查看容器：

```bash
sudo docker compose ps
```

查看日志：

```bash
sudo docker logs -f kafka-single
```

### 2.3 创建测试 Topic

```bash
sudo docker exec -it kafka-single /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 192.168.30.116:9092 \
  --create \
  --topic order-create \
  --partitions 3 \
  --replication-factor 1
```

查看 Topic：

```bash
sudo docker exec -it kafka-single /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 192.168.30.116:9092 \
  --describe \
  --topic order-create
```

### 2.4 生产和消费测试

生产消息：

```bash
sudo docker exec -it kafka-single /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server 192.168.30.116:9092 \
  --topic order-create
```

输入：

```text
hello kafka
order-1001
```

新开一个终端消费：

```bash
sudo docker exec -it kafka-single /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server 192.168.30.116:9092 \
  --topic order-create \
  --from-beginning
```

Java 客户端连接：

```properties
bootstrap.servers=192.168.30.116:9092
```

---

## 3. 三节点 Kafka 集群部署

集群部署在：

```text
192.168.30.117
192.168.30.118
192.168.30.119
```

三台机器都使用同一个 KRaft 集群 ID：

```text
kafka-prod-cluster-001
```

注意：同一个集群的所有节点 `CLUSTER_ID` 必须一致。集群启动后不要随意修改 `CLUSTER_ID`，否则已有数据目录会和新集群 ID 不匹配。

### 3.1 Broker 1：192.168.30.117

在 `192.168.30.117` 执行：

```bash
cd /opt/kafka
sudo vim docker-compose.yml
```

写入：

```yaml
services:
  kafka:
    image: apache/kafka:4.3.1
    container_name: kafka-117
    restart: always
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      CLUSTER_ID: "kafka-prod-cluster-001"
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: "broker,controller"
      KAFKA_CONTROLLER_QUORUM_VOTERS: "1@192.168.30.117:9093,2@192.168.30.118:9093,3@192.168.30.119:9093"
      KAFKA_LISTENERS: "PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093"
      KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://192.168.30.117:9092"
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: "PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT"
      KAFKA_INTER_BROKER_LISTENER_NAME: "PLAINTEXT"
      KAFKA_CONTROLLER_LISTENER_NAMES: "CONTROLLER"
      KAFKA_LOG_DIRS: "/var/lib/kafka/data"
      KAFKA_NUM_PARTITIONS: 6
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 3
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"
      KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE: "false"
    volumes:
      - /data/kafka/data:/var/lib/kafka/data
```

启动：

```bash
sudo docker compose up -d
```

### 3.2 Broker 2：192.168.30.118

在 `192.168.30.118` 创建 `/opt/kafka/docker-compose.yml`：

```yaml
services:
  kafka:
    image: apache/kafka:4.3.1
    container_name: kafka-118
    restart: always
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      CLUSTER_ID: "kafka-prod-cluster-001"
      KAFKA_NODE_ID: 2
      KAFKA_PROCESS_ROLES: "broker,controller"
      KAFKA_CONTROLLER_QUORUM_VOTERS: "1@192.168.30.117:9093,2@192.168.30.118:9093,3@192.168.30.119:9093"
      KAFKA_LISTENERS: "PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093"
      KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://192.168.30.118:9092"
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: "PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT"
      KAFKA_INTER_BROKER_LISTENER_NAME: "PLAINTEXT"
      KAFKA_CONTROLLER_LISTENER_NAMES: "CONTROLLER"
      KAFKA_LOG_DIRS: "/var/lib/kafka/data"
      KAFKA_NUM_PARTITIONS: 6
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 3
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"
      KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE: "false"
    volumes:
      - /data/kafka/data:/var/lib/kafka/data
```

启动：

```bash
cd /opt/kafka
sudo docker compose up -d
```

### 3.3 Broker 3：192.168.30.119

在 `192.168.30.119` 创建 `/opt/kafka/docker-compose.yml`：

```yaml
services:
  kafka:
    image: apache/kafka:4.3.1
    container_name: kafka-119
    restart: always
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      CLUSTER_ID: "kafka-prod-cluster-001"
      KAFKA_NODE_ID: 3
      KAFKA_PROCESS_ROLES: "broker,controller"
      KAFKA_CONTROLLER_QUORUM_VOTERS: "1@192.168.30.117:9093,2@192.168.30.118:9093,3@192.168.30.119:9093"
      KAFKA_LISTENERS: "PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093"
      KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://192.168.30.119:9092"
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: "PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT"
      KAFKA_INTER_BROKER_LISTENER_NAME: "PLAINTEXT"
      KAFKA_CONTROLLER_LISTENER_NAMES: "CONTROLLER"
      KAFKA_LOG_DIRS: "/var/lib/kafka/data"
      KAFKA_NUM_PARTITIONS: 6
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 3
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 2
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"
      KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE: "false"
    volumes:
      - /data/kafka/data:/var/lib/kafka/data
```

启动：

```bash
cd /opt/kafka
sudo docker compose up -d
```

查询状态
```
  docker exec kafka-119 \
    /opt/kafka/bin/kafka-metadata-quorum.sh \
    --bootstrap-controller localhost:9093 \
    describe --status

```

失误重建
```

  docker compose down

  mv /data/kafka/data /data/kafka/data-node1-backup
  mkdir -p /data/kafka/data
  sudo chown -R 1000:1000 /data/kafka

[//]: # (  chown --reference=/data/kafka/data-node1-backup /data/kafka/data)

  docker compose up -d
  docker logs -f kafka-119


```

### 3.4 检查集群

任意 Kafka 节点执行：

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-broker-api-versions.sh \
  --bootstrap-server 192.168.30.117:9092
```

如果在 `192.168.30.118` 或 `192.168.30.119` 上执行，要把容器名改成当前机器的容器名：

```text
192.168.30.118 -> kafka-118
192.168.30.119 -> kafka-119
```

创建 6 分区 3 副本 Topic：

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 192.168.30.117:9092,192.168.30.118:9092,192.168.30.119:9092 \
  --create \
  --topic order-create \
  --partitions 6 \
  --replication-factor 3 \
  --config min.insync.replicas=2
```

查看 Topic 分区和副本：

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 192.168.30.117:9092 \
  --describe \
  --topic order-create
```

正常会看到类似：

```text
Topic: order-create  PartitionCount: 6  ReplicationFactor: 3
Partition: 0  Leader: 1  Replicas: 1,2,3  Isr: 1,2,3
Partition: 1  Leader: 2  Replicas: 2,3,1  Isr: 2,3,1
Partition: 2  Leader: 3  Replicas: 3,1,2  Isr: 3,1,2
```

重点看：

- `Leader`：每个分区当前负责读写的 Broker。
- `Replicas`：该分区的全部副本。
- `Isr`：当前同步正常的副本集合。

### 3.5 生产和消费测试

生产消息：

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server 192.168.30.117:9092,192.168.30.118:9092,192.168.30.119:9092 \
  --topic order-create
```

消费消息：

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server 192.168.30.117:9092,192.168.30.118:9092,192.168.30.119:9092 \
  --topic order-create \
  --group order-service \
  --from-beginning
```

查看消费组：

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server 192.168.30.117:9092 \
  --describe \
  --group order-service
```

Java 客户端连接：

```properties
bootstrap.servers=192.168.30.117:9092,192.168.30.118:9092,192.168.30.119:9092
```

生产者建议配置：

```properties
acks=all
enable.idempotence=true
retries=3
```

---

## 4. Kafka UI 监控部署

监控部署在：

```text
192.168.30.115
```

访问地址：

```text
http://192.168.30.115:8080
```

Kafka UI 可以查看：

- Kafka 集群状态。
- Broker 列表。
- Topic 列表。
- Partition、Leader、Replica、ISR。
- Consumer Group 和 Lag。
- Topic 消息内容。
- 创建、删除 Topic。

### 4.1 创建 Compose 文件

在 `192.168.30.115` 执行：

```bash
cd /opt/kafka-ui
sudo vim docker-compose.yml
```

写入：

```yaml
services:
  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    restart: always
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: kafka-single-116
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: 192.168.30.116:9092

      KAFKA_CLUSTERS_1_NAME: kafka-cluster-117-119
      KAFKA_CLUSTERS_1_BOOTSTRAPSERVERS: 192.168.30.117:9092,192.168.30.118:9092,192.168.30.119:9092
```

这个配置会在 Kafka UI 里显示两个集群：

- `kafka-single-116`：单机 Kafka。
- `kafka-cluster-117-119`：三节点 Kafka 集群。

### 4.2 启动 Kafka UI

```bash
cd /opt/kafka-ui
sudo docker compose up -d
```

查看容器：

```bash
sudo docker compose ps
```

查看日志：

```bash
sudo docker logs -f kafka-ui
```

浏览器访问：

```text
http://192.168.30.115:8080
```

### 4.3 页面检查项

进入页面后检查：

```text
Clusters
  kafka-single-116
  kafka-cluster-117-119
```

在集群页面重点看：

- Brokers 是否正常显示。
- Topics 是否能列出。
- `order-create` Topic 的分区和副本是否正常。
- Consumer Groups 是否能看到 `order-service`。
- Messages 页面是否能查看消息。

如果 Kafka UI 连接不上 Kafka，优先检查：

- `192.168.30.115` 是否能访问 Kafka 节点 `9092`。
- Kafka 节点的 `KAFKA_ADVERTISED_LISTENERS` 是否写成了真实 IP。
- 防火墙或安全组是否放通。
- Kafka 容器是否正常启动。

在监控节点测试端口：

```bash
nc -vz 192.168.30.116 9092
nc -vz 192.168.30.117 9092
nc -vz 192.168.30.118 9092
nc -vz 192.168.30.119 9092
```

如果没有 `nc`：

```bash
sudo apt install -y netcat-openbsd
```

---

## 5. 常用运维命令

### 5.1 查看容器

```bash
sudo docker ps
```

### 5.2 查看 Kafka 日志

单机：

```bash
sudo docker logs -f kafka-single
```

集群：

```bash
sudo docker logs -f kafka-117
sudo docker logs -f kafka-118
sudo docker logs -f kafka-119
```

### 5.3 重启 Kafka

```bash
cd /opt/kafka
sudo docker compose restart
```

### 5.4 停止 Kafka

```bash
cd /opt/kafka
sudo docker compose down
```

注意：这个命令不会删除 `/data/kafka/data`，数据仍然保留。

不要在生产环境随意执行：

```bash
sudo docker compose down -v
```

因为 `-v` 会删除 Docker volume。如果你使用的是宿主机目录挂载，仍然不要养成随意删除数据目录的习惯。

### 5.5 查看 Topic

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 192.168.30.117:9092 \
  --list
```

### 5.6 查看 Topic 详情

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 192.168.30.117:9092 \
  --describe \
  --topic order-create
```

### 5.7 查看消费者组 Lag

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server 192.168.30.117:9092 \
  --describe \
  --group order-service
```

重点字段：

- `CURRENT-OFFSET`：消费者当前提交的 offset。
- `LOG-END-OFFSET`：分区最新 offset。
- `LAG`：堆积数量。

---

## 6. 目录规划

每台 Kafka 节点：

```text
/opt/kafka/
  docker-compose.yml

/data/kafka/
  data/
```

监控节点：

```text
/opt/kafka-ui/
  docker-compose.yml
```

Kafka 数据会在宿主机目录中持久化：

```text
/data/kafka/data
```

即使容器重启，Topic、消息、offset 等数据仍然存在。

---

## 7. Kafka 配置说明与调优

本章节解释前面 Docker Compose 里出现的 Kafka 配置，以及常见调优方向。

### 7.1 KRaft 集群身份配置

| 配置 | 示例 | 含义 |
|---|---|---|
| `CLUSTER_ID` | `kafka-prod-cluster-001` | Kafka 集群 ID，同一个集群所有节点必须一致 |
| `KAFKA_NODE_ID` | `1`、`2`、`3` | 当前 Broker/Controller 节点 ID，集群内必须唯一 |
| `KAFKA_PROCESS_ROLES` | `broker,controller` | 当前节点角色，既存数据也参与元数据管理 |
| `KAFKA_CONTROLLER_QUORUM_VOTERS` | `1@192.168.30.117:9093,2@192.168.30.118:9093,3@192.168.30.119:9093` | KRaft Controller 投票节点列表 |

调优建议：

- 三节点小集群可以使用 `broker,controller` 混合角色。
- 更大规模生产集群可以把 Controller 和 Broker 分离，降低互相影响。
- `CLUSTER_ID` 写入数据目录后不要修改，除非你明确要重建集群。
- `KAFKA_NODE_ID` 不要重复，否则节点无法正常加入集群。

### 7.2 网络监听配置

| 配置 | 示例 | 含义 |
|---|---|---|
| `KAFKA_LISTENERS` | `PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093` | Kafka 容器内部实际监听地址 |
| `KAFKA_ADVERTISED_LISTENERS` | `PLAINTEXT://192.168.30.117:9092` | Kafka 告诉客户端应该连接的地址 |
| `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` | `PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT` | listener 名称和安全协议映射 |
| `KAFKA_INTER_BROKER_LISTENER_NAME` | `PLAINTEXT` | Broker 之间通信使用哪个 listener |
| `KAFKA_CONTROLLER_LISTENER_NAMES` | `CONTROLLER` | Controller 通信使用哪个 listener |

最容易踩坑的是：

```yaml
KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://localhost:9092"
```

如果 Kafka 部署在服务器上，客户端在其他机器访问，不能写 `localhost`。应该写服务器真实 IP：

```yaml
KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://192.168.30.117:9092"
```

否则客户端第一次连上 bootstrap server 后，会拿到 `localhost:9092` 这个错误地址，后续访问 Broker 失败。

调优建议：

- 内网部署优先使用内网 IP。
- 如果有公网访问，建议单独配置外部 listener，并做好安全控制。
- 生产环境不要裸露 PLAINTEXT 到公网，至少通过内网、VPN、防火墙或 SASL/SSL 保护。

### 7.3 分区和副本配置

| 配置 | 单机值 | 集群值 | 含义 |
|---|---:|---:|---|
| `KAFKA_NUM_PARTITIONS` | `3` | `6` | 自动创建 Topic 时的默认分区数 |
| `KAFKA_DEFAULT_REPLICATION_FACTOR` | 不建议设置为 3 | `3` | 默认副本因子 |
| `KAFKA_MIN_INSYNC_REPLICAS` | `1` | `2` | 最少同步副本数 |
| `KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR` | `1` | `3` | 消费者 offset 内部 Topic 的副本数 |
| `KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR` | `1` | `3` | 事务状态内部 Topic 的副本数 |
| `KAFKA_TRANSACTION_STATE_LOG_MIN_ISR` | `1` | `2` | 事务状态内部 Topic 的最少 ISR |

推荐组合：

```text
单机：
replication.factor=1
min.insync.replicas=1

三节点集群：
replication.factor=3
min.insync.replicas=2
producer acks=all
```

这组配置的含义：

```text
每个分区有 3 份副本
至少 2 个同步副本正常
生产者才认为消息写入成功
```

调优建议：

- 分区数决定同一个消费者组的最大消费并发。
- 副本数决定数据冗余和容灾能力。
- 副本因子不能大于 Broker 数，3 台 Broker 最多 3 副本。
- 分区不是越多越好，分区太多会增加文件句柄、内存、Controller 管理和 Rebalance 成本。

分区数粗略估算：

```text
目标分区数 >= 消费服务节点数 × 每节点 concurrency
```

例如：

```text
3 个消费节点
每个节点 concurrency=4
建议 Topic 至少 12 个分区
```

### 7.4 可靠性配置

| 配置 | 推荐值 | 含义 |
|---|---|---|
| `KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE` | `false` | 禁止不同步副本被选为 Leader |
| `KAFKA_MIN_INSYNC_REPLICAS` | `2` | 至少 2 个同步副本 |
| 生产者 `acks` | `all` | 等待 ISR 确认 |
| 生产者 `enable.idempotence` | `true` | 开启幂等生产 |

如果设置：

```yaml
KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE: "true"
```

当 Leader 挂掉且 ISR 不足时，Kafka 可能选择一个落后的 Follower 成为新 Leader。这样可用性提高，但可能丢消息。

生产环境建议：

```yaml
KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE: "false"
KAFKA_MIN_INSYNC_REPLICAS: 2
```

生产者配置：

```properties
acks=all
enable.idempotence=true
retries=3
```

含义：

```text
宁愿写入失败并让业务重试，也不要为了强行可用而接受数据丢失。
```

### 7.5 Topic 自动创建配置

| 配置 | 推荐值 | 含义 |
|---|---|---|
| `KAFKA_AUTO_CREATE_TOPICS_ENABLE` | `false` | 禁止自动创建 Topic |

如果开启自动创建：

```yaml
KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
```

应用写错 Topic 名也可能自动创建一个新 Topic，导致问题不容易发现。

生产环境建议关闭：

```yaml
KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"
```

Topic 由脚本或管理平台创建：

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 192.168.30.117:9092 \
  --create \
  --topic order-create \
  --partitions 6 \
  --replication-factor 3 \
  --config min.insync.replicas=2
```

### 7.6 数据目录和保留策略

| 配置 | 示例 | 含义 |
|---|---|---|
| `KAFKA_LOG_DIRS` | `/var/lib/kafka/data` | Kafka 消息数据目录 |
| `volumes` | `/data/kafka/data:/var/lib/kafka/data` | 把容器数据目录挂载到宿主机 |
| `log.retention.hours` | `168` | 消息保留小时数 |
| `log.retention.bytes` | `107374182400` | 每个分区最大保留大小 |
| `log.segment.bytes` | `1073741824` | 单个日志段大小 |

可以在 Compose 中补充：

```yaml
KAFKA_LOG_RETENTION_HOURS: 168
KAFKA_LOG_RETENTION_BYTES: 107374182400
KAFKA_LOG_SEGMENT_BYTES: 1073741824
```

含义：

```text
消息默认保留 7 天
单个分区最多保留约 100GB
单个日志段约 1GB
```

调优建议：

- 磁盘空间紧张时，缩短 `KAFKA_LOG_RETENTION_HOURS`。
- 消息量很大时，要同时设置时间和大小保留策略。
- Kafka 消息不会因为被消费就删除，而是按保留策略删除。
- 生产环境建议单独挂载数据盘，不要和系统盘混用。
- 重点监控 `/data/kafka/data` 磁盘使用率。

### 7.7 Producer 调优

重要生产者建议：

```properties
bootstrap.servers=192.168.30.117:9092,192.168.30.118:9092,192.168.30.119:9092
acks=all
enable.idempotence=true
retries=3
compression.type=lz4
linger.ms=10
batch.size=32768
buffer.memory=67108864
```

参数说明：

| 参数 | 含义 |
|---|---|
| `acks=all` | ISR 副本确认后才算成功 |
| `enable.idempotence=true` | 避免生产者重试导致同分区重复写入 |
| `compression.type=lz4` | 压缩消息，降低网络和磁盘压力 |
| `linger.ms=10` | 等待短时间凑批，提高吞吐 |
| `batch.size=32768` | 批次大小 |
| `buffer.memory=67108864` | 生产者本地缓冲区 |

调优方向：

- 追求吞吐：适当增大 `batch.size` 和 `linger.ms`，开启压缩。
- 追求低延迟：减小 `linger.ms`，但吞吐可能下降。
- 重要业务：优先可靠性，使用 `acks=all` 和幂等。

### 7.8 Consumer 调优

消费者常用配置：

```properties
enable.auto.commit=false
auto.offset.reset=earliest
max.poll.records=500
fetch.min.bytes=1048576
fetch.max.wait.ms=500
max.partition.fetch.bytes=1048576
```

参数说明：

| 参数 | 含义 |
|---|---|
| `enable.auto.commit=false` | 关闭自动提交 offset |
| `auto.offset.reset=earliest` | 没有 offset 时从最早消息开始消费 |
| `max.poll.records=500` | 每次 poll 最多返回多少条 |
| `fetch.min.bytes` | Broker 返回前尽量凑够的数据量 |
| `fetch.max.wait.ms` | Broker 最多等待多久返回 |
| `max.partition.fetch.bytes` | 单分区单次拉取最大数据量 |

Spring Kafka 并发建议：

```java
@KafkaListener(
        topics = "order-create",
        groupId = "order-service",
        concurrency = "6"
)
public void listen(String message) {
    // 处理消息
}
```

并发计算：

```text
总消费线程 = 消费服务节点数 × 每节点 concurrency
总消费线程不要明显大于 Topic 分区数
```

例如：

```text
Topic 有 6 个分区
消费服务有 3 个节点
建议每个节点 concurrency=2
```

否则多余线程会空闲。

### 7.9 Broker 资源调优

Kafka 依赖磁盘、网络和 Page Cache。

建议：

- 数据盘优先使用 SSD。
- `/data/kafka/data` 单独挂载数据盘。
- Kafka Broker 尽量不要和数据库、ES 等重 IO 服务混部。
- 预留足够内存给操作系统 Page Cache。
- 不要把 JVM 堆设置得过大。

Docker 容器可以增加资源限制，例如：

```yaml
services:
  kafka:
    deploy:
      resources:
        limits:
          cpus: "4"
          memory: 8G
```

如果不是 Docker Swarm，`deploy.resources` 对普通 `docker compose` 的限制支持有限，可以改用：

```yaml
services:
  kafka:
    mem_limit: 8g
    cpus: 4
```

JVM 堆可以通过环境变量设置：

```yaml
KAFKA_HEAP_OPTS: "-Xms2g -Xmx2g"
```

经验建议：

```text
普通 8G 内存机器：Kafka heap 1G-2G
16G-32G 内存机器：Kafka heap 2G-4G
剩余内存留给 Page Cache
```

### 7.10 监控指标调优

Kafka UI 适合查看状态和消息，但正式监控还应关注指标：

| 指标 | 含义 |
|---|---|
| Consumer Lag | 消费堆积 |
| Under Replicated Partitions | 副本不足 |
| Offline Partitions | 离线分区 |
| Request Latency | 请求延迟 |
| Bytes In/Out | 生产和消费流量 |
| Disk Usage | 磁盘使用率 |
| ISR Shrink/Expand | ISR 变化 |

告警建议：

- Consumer Lag 持续增长。
- `UnderReplicatedPartitions > 0`。
- `OfflinePartitionsCount > 0`。
- 磁盘使用率超过 80%。
- Broker 容器重启。
- 生产或消费请求延迟明显升高。

### 7.11 常见配置组合

开发单机：

```text
Broker 数：1
replication.factor=1
min.insync.replicas=1
acks=1 或 all
```

生产三节点：

```text
Broker 数：3
replication.factor=3
min.insync.replicas=2
acks=all
enable.idempotence=true
unclean.leader.election.enable=false
```

高吞吐 Topic：

```text
分区数适当增加
producer compression.type=lz4
producer linger.ms=10-50
producer batch.size=32768 或更高
consumer 批量处理
```

强顺序 Topic：

```text
同一业务 key 写入同一分区
消费端不要对同一 key 并发乱序处理
如果要全局有序，只能使用 1 个分区
```

---

## 8. Kafka 扩容操作

Kafka 扩容分两种：

```text
新增 Broker：提升消息存储、生产消费吞吐、分区承载能力
新增 Controller：提升 KRaft 元数据管理 quorum 的规模
```

大多数业务扩容都是 **新增 Broker**，不需要新增 Controller。

### 8.1 新增 Broker，不新增 Controller

例如当前集群是：

```text
192.168.30.117  node.id=1  broker,controller
192.168.30.118  node.id=2  broker,controller
192.168.30.119  node.id=3  broker,controller
```

现在新增一台 Broker：

```text
192.168.30.120  node.id=4  broker
```

这种方式：

- 不需要修改现有 `192.168.30.117-119` 的配置。
- 不需要重启现有 Controller。
- 新节点只作为 Broker 存储数据，不参与 Controller 投票。
- 启动后旧 Topic 的历史分区不会自动迁移到新 Broker，需要执行分区重分配。
- 新建 Topic 时，Kafka 可以把新 Topic 的分区分配到新 Broker 上。

在 `192.168.30.120` 创建目录：

```bash
sudo mkdir -p /data/kafka/data
sudo mkdir -p /opt/kafka
sudo chown -R 1000:1000 /data/kafka
```

创建 `/opt/kafka/docker-compose.yml`：

```yaml
services:
  kafka:
    image: apache/kafka:4.3.1
    container_name: kafka-120
    restart: always
    ports:
      - "9092:9092"
    environment:
      CLUSTER_ID: "kafka-prod-cluster-001"
      KAFKA_NODE_ID: 4
      KAFKA_PROCESS_ROLES: "broker"
      KAFKA_CONTROLLER_QUORUM_VOTERS: "1@192.168.30.117:9093,2@192.168.30.118:9093,3@192.168.30.119:9093"
      KAFKA_LISTENERS: "PLAINTEXT://0.0.0.0:9092"
      KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://192.168.30.120:9092"
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: "PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT"
      KAFKA_INTER_BROKER_LISTENER_NAME: "PLAINTEXT"
      KAFKA_CONTROLLER_LISTENER_NAMES: "CONTROLLER"
      KAFKA_LOG_DIRS: "/var/lib/kafka/data"
      KAFKA_NUM_PARTITIONS: 6
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"
      KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE: "false"
    volumes:
      - /data/kafka/data:/var/lib/kafka/data
```

启动：

```bash
cd /opt/kafka
sudo docker compose up -d
```

检查 Broker 是否加入：

```bash
sudo docker exec -it kafka-120 /opt/kafka/bin/kafka-broker-api-versions.sh \
  --bootstrap-server 192.168.30.117:9092,192.168.30.118:9092,192.168.30.119:9092,192.168.30.120:9092
```

查看 Topic 分布：

```bash
sudo docker exec -it kafka-120 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 192.168.30.117:9092 \
  --describe \
  --topic order-create
```

如果旧 Topic 仍然只分布在 Broker `1,2,3`，这是正常的。新增 Broker 不会自动搬迁旧分区。

### 8.2 扩容后迁移旧 Topic 分区

新增 Broker 后，如果要让旧 Topic 使用 `node.id=4`，需要做分区重分配。

先创建 Topic 列表文件：

```bash
cat > /tmp/topics-to-move.json <<EOF
{
  "topics": [
    {"topic": "order-create"}
  ],
  "version": 1
}
EOF
```

生成迁移方案：

```bash
sudo docker exec -i kafka-120 /opt/kafka/bin/kafka-reassign-partitions.sh \
  --bootstrap-server 192.168.30.117:9092 \
  --topics-to-move-json-file /dev/stdin \
  --broker-list "1,2,3,4" \
  --generate < /tmp/topics-to-move.json
```

命令会输出两段 JSON：

```text
Current partition replica assignment
Proposed partition reassignment configuration
```

把 `Proposed partition reassignment configuration` 后面的 JSON 保存为 `/tmp/reassignment.json`。

执行迁移：

```bash
sudo docker exec -i kafka-120 /opt/kafka/bin/kafka-reassign-partitions.sh \
  --bootstrap-server 192.168.30.117:9092 \
  --reassignment-json-file /dev/stdin \
  --execute < /tmp/reassignment.json
```

查看迁移状态：

```bash
sudo docker exec -i kafka-120 /opt/kafka/bin/kafka-reassign-partitions.sh \
  --bootstrap-server 192.168.30.117:9092 \
  --reassignment-json-file /dev/stdin \
  --verify < /tmp/reassignment.json
```

迁移注意事项：

- 分区迁移会产生大量网络和磁盘 IO。
- 不要在业务高峰期迁移大量 Topic。
- 迁移前确认新 Broker 磁盘容量足够。
- 迁移后再查看 `kafka-topics --describe`，确认 `Replicas` 中出现 `4`。
- Kafka UI 或 Cruise Control 也可以辅助做分区重分配。

### 8.3 新增 Broker 后客户端配置

Java 客户端 `bootstrap.servers` 不要求写全所有 Broker，但建议写多个可用节点：

```properties
bootstrap.servers=192.168.30.117:9092,192.168.30.118:9092,192.168.30.119:9092,192.168.30.120:9092
```

客户端连接任意一个 bootstrap server 后，会自动拉取完整集群元数据。

### 8.4 新增 Controller 是否要全部重启

结论：

```text
只新增 Broker，不新增 Controller：
不需要重启现有节点。

新增 Controller：
取决于 Kafka 版本和 KRaft quorum 配置方式。
静态 controller.quorum.voters 配置下，通常需要滚动更新相关节点配置。
```

当前文档使用的是静态配置：

```yaml
KAFKA_CONTROLLER_QUORUM_VOTERS: "1@192.168.30.117:9093,2@192.168.30.118:9093,3@192.168.30.119:9093"
```

如果要新增 Controller，例如：

```text
192.168.30.121  node.id=5  controller
```

新的 voters 应该变成：

```text
1@192.168.30.117:9093,2@192.168.30.118:9093,3@192.168.30.119:9093,5@192.168.30.121:9093
```

在静态配置模式下，现有 Controller 节点也需要知道新的 voter 列表，所以需要滚动更新：

1. 准备 `192.168.30.121` 的 Controller 配置。
2. 更新 `192.168.30.117` 的 `KAFKA_CONTROLLER_QUORUM_VOTERS`，重启 `kafka-117`。
3. 更新 `192.168.30.118` 的 `KAFKA_CONTROLLER_QUORUM_VOTERS`，重启 `kafka-118`。
4. 更新 `192.168.30.119` 的 `KAFKA_CONTROLLER_QUORUM_VOTERS`，重启 `kafka-119`。
5. 启动 `192.168.30.121` 的 Controller。
6. 检查 Controller quorum 状态。

滚动重启命令：

```bash
cd /opt/kafka
sudo docker compose restart
```

Controller-only 节点示例：

```yaml
services:
  kafka:
    image: apache/kafka:4.3.1
    container_name: kafka-controller-121
    restart: always
    ports:
      - "9093:9093"
    environment:
      CLUSTER_ID: "kafka-prod-cluster-001"
      KAFKA_NODE_ID: 5
      KAFKA_PROCESS_ROLES: "controller"
      KAFKA_CONTROLLER_QUORUM_VOTERS: "1@192.168.30.117:9093,2@192.168.30.118:9093,3@192.168.30.119:9093,5@192.168.30.121:9093"
      KAFKA_LISTENERS: "CONTROLLER://0.0.0.0:9093"
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: "CONTROLLER:PLAINTEXT"
      KAFKA_CONTROLLER_LISTENER_NAMES: "CONTROLLER"
      KAFKA_LOG_DIRS: "/var/lib/kafka/data"
    volumes:
      - /data/kafka/data:/var/lib/kafka/data
```

检查 quorum：

```bash
sudo docker exec -it kafka-117 /opt/kafka/bin/kafka-metadata-quorum.sh \
  --bootstrap-server 192.168.30.117:9092 \
  describe --status
```

注意：

- Controller 数量通常使用奇数，例如 3、5。
- 3 个 Controller 已经能容忍 1 个 Controller 故障。
- 5 个 Controller 能容忍 2 个 Controller 故障，但元数据提交链路也会更重。
- 小规模集群通常保持 3 个 Controller 就够了，扩容优先新增 Broker。
- 如果 Kafka 版本支持动态 KRaft quorum 变更，可以使用官方 quorum 管理命令减少重启；但在静态 `controller.quorum.voters` 写法下，应按滚动更新处理。

---

## 9. Prometheus 和 Grafana 监控

Prometheus 和 Grafana 已安装时，只需要部署 Exporter、配置 Prometheus 抓取目标，并在 Grafana 中添加 Prometheus 数据源。

本文使用的实际监控拓扑：

| 地址 | 角色 |
|---|---|
| `192.168.30.33` | Prometheus、Grafana |
| `192.168.30.115` | Exporter 部署节点 |
| `192.168.30.116` | 单机 Kafka |
| `192.168.30.117-192.168.30.119` | 三节点 Kafka 集群 |

各组件的职责如下：

```text
Kafka Exporter -> Topic、Consumer Group、消费 Lag
JMX Exporter   -> JVM、GC、网络请求、副本同步、Controller
Node Exporter  -> CPU、内存、磁盘、网络、系统负载
Prometheus     -> 定时采集和保存指标、执行告警规则
Grafana        -> 查询 Prometheus 并展示监控面板
```

部署数量建议：

| 组件 | 部署数量 | 默认端口 |
|---|---:|---:|
| Kafka Exporter | 每个 Kafka 集群 1 个 | 9308 |
| JMX Exporter | 每个 Kafka Broker 1 个 Java Agent | 7071 |
| Node Exporter | 每台 Kafka 服务器 1 个 | 9100 |

### 9.1 部署 Kafka Exporter

Kafka Exporter 可以部署在任意一台能够访问所有 Broker 的服务器上。每个 Kafka 集群需要一个独立的 Exporter，因此在 `192.168.30.115` 部署两个容器：

- `kafka-exporter-single` 采集 `192.168.30.116` 单机 Kafka，对外端口为 `9308`。
- `kafka-exporter-cluster` 采集 `192.168.30.117-192.168.30.119` 三节点集群，对外端口为 `9309`。

```bash
sudo mkdir -p /opt/kafka-exporter
cd /opt/kafka-exporter
sudo vim docker-compose.yml
```

```yaml
services:
  kafka-exporter-single:
    image: danielqsj/kafka-exporter:v1.9.0
    container_name: kafka-exporter-single
    restart: always
    command:
      - "--kafka.server=192.168.30.116:9092"
      - "--web.listen-address=:9308"
      - "--log.level=info"
    ports:
      - "9308:9308"

  kafka-exporter-cluster:
    image: danielqsj/kafka-exporter:v1.9.0
    container_name: kafka-exporter-cluster
    restart: always
    command:
      - "--kafka.server=192.168.30.117:9092"
      - "--kafka.server=192.168.30.118:9092"
      - "--kafka.server=192.168.30.119:9092"
      - "--web.listen-address=:9308"
      - "--log.level=info"
    ports:
      - "9309:9308"
```

启动并检查：

```bash
sudo docker compose up -d
sudo docker logs --tail 100 kafka-exporter-single
sudo docker logs --tail 100 kafka-exporter-cluster
curl http://127.0.0.1:9308/metrics
curl http://127.0.0.1:9309/metrics
```

检查 Exporter 发现的 Broker 数量：

```bash
curl -s http://127.0.0.1:9308/metrics | grep '^kafka_brokers'
curl -s http://127.0.0.1:9309/metrics | grep '^kafka_brokers'
```

正常结果应分别为：

```text
192.168.30.115:9308 -> kafka_brokers 1
192.168.30.115:9309 -> kafka_brokers 3
```

如果 Kafka 的 `advertised.listeners` 使用域名，Kafka Exporter 容器也必须能够解析每个 Broker 的域名。生产环境建议使用内部 DNS，也可以通过 Compose 的 `extra_hosts` 临时配置。

### 9.2 部署 JMX Exporter

JMX Exporter 以 Java Agent 方式运行在 Kafka JVM 中，因此不能集中部署在 `192.168.30.115`。下面操作需要分别在单机 Kafka `192.168.30.116` 和集群 Broker `192.168.30.117-192.168.30.119` 上执行。

准备 JMX Exporter 文件：

```bash
sudo mkdir -p /opt/kafka/jmx-exporter
cd /opt/kafka/jmx-exporter

sudo curl -L \
  -o jmx_prometheus_javaagent-1.2.0.jar \
  https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/1.2.0/jmx_prometheus_javaagent-1.2.0.jar

sudo curl -L \
  -o kafka.yml \
  https://raw.githubusercontent.com/prometheus/jmx_exporter/1.2.0/examples/kafka-2_0_0.yml
```

在每个 Broker 的 Kafka Compose 服务中增加端口、Java Agent 参数和文件挂载：

```yaml
services:
  kafka:
    ports:
      - "9092:9092"
      - "9093:9093"
      - "7071:7071"
    environment:
      KAFKA_OPTS: "-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=7071:/opt/jmx-exporter/kafka.yml"
    volumes:
      - /data/kafka/data:/var/lib/kafka/data
      - /opt/kafka/jmx-exporter/jmx_prometheus_javaagent-1.2.0.jar:/opt/jmx-exporter/jmx_prometheus_javaagent.jar:ro
      - /opt/kafka/jmx-exporter/kafka.yml:/opt/jmx-exporter/kafka.yml:ro
```

如果原配置已经存在 `KAFKA_OPTS`，需要把 Java Agent 参数合并到原值中，不能直接覆盖其他 JVM 参数。

逐台重启 Broker，上一台恢复正常后再重启下一台：

```bash
cd /opt/kafka
sudo docker compose up -d
sudo docker logs --tail 100 kafka-117
curl http://127.0.0.1:7071/metrics
```

`kafka-117` 要替换为当前节点的实际容器名。检查常见 Kafka 指标：

```bash
curl -s http://127.0.0.1:7071/metrics | grep -Ei 'underreplicated|isr|controller|request' | head
```

不同 Kafka 和 JMX Exporter 版本生成的指标名称可能不同，应以当前 `/metrics` 实际输出为准。

### 9.3 部署 Node Exporter

Node Exporter 采集所在服务器的系统指标，也不能集中代替其他节点采集。建议在 `192.168.30.115-192.168.30.119` 每台服务器分别部署，其中 `116-119` 是 Kafka 主机，`115` 是 Exporter 主机。

```bash
sudo mkdir -p /opt/node-exporter
cd /opt/node-exporter
sudo vim docker-compose.yml
```

```yaml
services:
  node-exporter:
    image: prom/node-exporter:v1.8.2
    container_name: node-exporter
    restart: always
    network_mode: host
    pid: host
    command:
      - "--path.rootfs=/host"
      - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
    volumes:
      - /:/host:ro,rslave
```

启动并检查：

```bash
sudo docker compose up -d
curl http://127.0.0.1:9100/metrics
```

### 9.4 配置 Prometheus

在 `192.168.30.33` 上编辑 Prometheus 的 `prometheus.yml`，增加以下抓取任务。通过 `cluster` 标签区分单机 Kafka 和三节点集群：

```yaml
scrape_configs:
  - job_name: kafka-exporter
    static_configs:
      - targets:
          - "192.168.30.115:9308"
        labels:
          cluster: "kafka-single-116"
      - targets:
          - "192.168.30.115:9309"
        labels:
          cluster: "kafka-cluster-117-119"

  - job_name: kafka-jmx
    static_configs:
      - targets:
          - "192.168.30.116:7071"
        labels:
          cluster: "kafka-single-116"
      - targets:
          - "192.168.30.117:7071"
          - "192.168.30.118:7071"
          - "192.168.30.119:7071"
        labels:
          cluster: "kafka-cluster-117-119"

  - job_name: kafka-node
    static_configs:
      - targets:
          - "192.168.30.115:9100"
          - "192.168.30.116:9100"
          - "192.168.30.117:9100"
          - "192.168.30.118:9100"
          - "192.168.30.119:9100"
```

如果 `prometheus.yml` 已有 `scrape_configs`，只追加其中的三个 `job_name`，不要重复声明顶层 `scrape_configs`。

检查配置并重新加载 Prometheus：

```bash
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl reload prometheus
```

如果 Prometheus 使用 Docker 部署，需要在容器内执行 `promtool`，并按照现有部署方式重启或向 `/-/reload` 发送请求。

打开 Prometheus 的 `Status -> Targets`，确认以下任务均为 `UP`：

```text
kafka-exporter  2/2 UP
kafka-jmx       4/4 UP
kafka-node      5/5 UP
```

### 9.5 配置基础告警规则

在 Prometheus 配置目录创建 `kafka_rules.yml`：

```yaml
groups:
  - name: kafka
    rules:
      - alert: KafkaExporterDown
        expr: up{job="kafka-exporter"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Kafka Exporter 不可用"

      - alert: KafkaBrokerMissing
        expr: kafka_brokers{cluster="kafka-single-116"} != 1 or kafka_brokers{cluster="kafka-cluster-117-119"} != 3
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Kafka Broker 数量不足"
          description: "集群 {{ $labels.cluster }} 当前 Broker 数量为 {{ $value }}。"

      - alert: KafkaConsumerLagHigh
        expr: sum by (cluster, consumergroup, topic) (kafka_consumergroup_lag) > 10000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Kafka 消费积压过高"
          description: "集群 {{ $labels.cluster }} 的消费者组 {{ $labels.consumergroup }}、Topic {{ $labels.topic }} 积压超过 10000。"

      - alert: KafkaJmxExporterDown
        expr: up{job="kafka-jmx"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Kafka JMX Exporter 不可用"

      - alert: KafkaNodeExporterDown
        expr: up{job="kafka-node"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Kafka Node Exporter 不可用"
```

在 `prometheus.yml` 中加载规则：

```yaml
rule_files:
  - /etc/prometheus/kafka_rules.yml
```

再次执行 `promtool check config` 并重新加载 Prometheus。Prometheus 负责计算告警规则；如果需要发送到邮件、企业微信或钉钉，还需要配置 Alertmanager。

### 9.6 配置 Grafana

在已安装的 Grafana 中添加 Prometheus 数据源：

1. 进入 `Connections -> Data sources -> Add data source`。
2. 选择 `Prometheus`。
3. URL 填写本机 Prometheus 地址 `http://192.168.30.33:9090`。
4. 点击 `Save & test`，确认连接成功。

推荐分别建立 Kafka 集群、消费者积压和服务器资源三个 Dashboard。常用 PromQL：

```promql
# Broker 数量
kafka_brokers

# 三节点 Kafka 集群的 Broker 数量
kafka_brokers{cluster="kafka-cluster-117-119"}

# 按消费者组和 Topic 汇总 Lag
sum by (cluster, consumergroup, topic) (kafka_consumergroup_lag)

# 每个分区的 Lag
kafka_consumergroup_lag

# JMX Exporter 在线状态
up{job="kafka-jmx"}

# Kafka 节点 CPU 使用率
100 - avg by (instance) (rate(node_cpu_seconds_total{job="kafka-node",mode="idle"}[5m])) * 100

# Kafka 节点可用内存百分比
node_memory_MemAvailable_bytes{job="kafka-node"}
  / node_memory_MemTotal_bytes{job="kafka-node"} * 100

# Kafka 数据盘使用率，mountpoint 按实际目录调整
100 - node_filesystem_avail_bytes{job="kafka-node",mountpoint="/data"}
  / node_filesystem_size_bytes{job="kafka-node",mountpoint="/data"} * 100
```

也可以在 Grafana Dashboard 市场导入模板：

- Node Exporter Full：Dashboard ID `1860`。
- Kafka Exporter：可搜索 `Kafka Exporter`，选择与当前指标名称匹配的模板。

导入后必须检查每个面板使用的 `job`、数据源和指标名称。模板与 Exporter 版本不匹配时，面板可能显示 `No data`，此时应按照 Prometheus 中的实际指标调整查询。

### 9.7 监控验收

部署完成后依次确认：

- `192.168.30.115:9308` 的 `kafka_brokers` 等于 `1`。
- `192.168.30.115:9309` 的 `kafka_brokers` 等于 `3`。
- Kafka Exporter 能看到业务 Consumer Group 和 Lag。
- 每个 Broker 的 `7071/metrics` 可以访问。
- 每台服务器的 `9100/metrics` 可以访问。
- Prometheus Targets 全部为 `UP`。
- Grafana 能查询 `kafka_brokers` 和 `kafka_consumergroup_lag`。
- 停止一个测试消费者后，Grafana 中的 Lag 会持续增长；恢复消费者后 Lag 会下降。

监控端口 `9308`、`9309`、`7071` 和 `9100` 应只允许 Prometheus 服务器 `192.168.30.33` 访问，不应直接暴露到公网。

---

## 10. 生产注意事项

- 单机 Kafka 只适合开发、测试或低重要性业务。
- 生产环境建议使用 `192.168.30.117-192.168.30.119` 三节点集群。
- 重要 Topic 建议 `replication.factor=3`。
- 重要生产者建议 `acks=all`。
- 建议配置 `min.insync.replicas=2`。
- 不要把 `KAFKA_ADVERTISED_LISTENERS` 写成 `localhost`。
- 不要让普通业务服务依赖自动创建 Topic，建议关闭 `auto.create.topics.enable`。
- Kafka UI 能管理 Topic 和查看消息，生产环境应放在内网并增加访问控制。
- 如果需要正式监控告警，建议再接入 Prometheus、Grafana 和 JMX Exporter。
