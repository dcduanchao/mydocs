# Ubuntu Docker 部署 Elasticsearch：单机、集群与调优

本文使用 Elasticsearch 8.x 官方镜像，介绍单机开发环境和 3 节点生产集群。命令默认在 Ubuntu 上执行，版本通过 `.env` 固定，升级前应阅读目标版本的 Breaking Changes。

> 单机示例为了便于本地开发关闭 HTTP TLS，但仍启用账号认证。3 节点集群示例同时启用 HTTP 和 Transport TLS。

## 1. 环境要求

- 已安装 Docker Engine 和 Docker Compose Plugin。
- 生产集群至少 3 台服务器，节点之间网络稳定、时间同步。
- 开放业务端口 `9200` 和节点通信端口 `9300`，仅允许可信网段访问。
- 数据目录使用本地 SSD，不使用网络共享目录保存 ES Data Path。
- 为 Elasticsearch 预留内存，避免与数据库等高 I/O 服务争抢资源。

所有宿主机先设置：

```bash
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-elasticsearch.conf
sudo sysctl --system
```

验证：

```bash
sysctl vm.max_map_count
docker version
docker compose version
```

## 2. 单机版部署

### 2.1 创建目录和环境变量

```bash
sudo mkdir -p /opt/elasticsearch-single/data
sudo chown -R 1000:0 /opt/elasticsearch-single/data
cd /opt/elasticsearch-single
```

创建 `.env`：

```dotenv
ES_VERSION=8.15.5
ES_PASSWORD=请替换为高强度密码
ES_JAVA_OPTS=-Xms2g -Xmx2g
```

版本号只是示例，部署时应选择团队验证过的 8.x 补丁版本。密码不要提交到 Git。

### 2.2 Docker Compose

创建 `compose.yml`：

```yaml
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:${ES_VERSION}
    container_name: elasticsearch-single
    restart: unless-stopped
    environment:
      - node.name=es-single
      - cluster.name=es-single-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=false
      - ELASTIC_PASSWORD=${ES_PASSWORD}
      - ES_JAVA_OPTS=${ES_JAVA_OPTS}
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65535
        hard: 65535
    ports:
      - "9200:9200"
    volumes:
      - ./data:/usr/share/elasticsearch/data
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS -u elastic:${ES_PASSWORD} http://localhost:9200/_cluster/health >/dev/null || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 60s
```

启动并验证：

```bash
docker compose up -d
docker compose ps
docker compose logs -f --tail=200 elasticsearch
curl -u "elastic:${ES_PASSWORD}" http://127.0.0.1:9200
curl -u "elastic:${ES_PASSWORD}" http://127.0.0.1:9200/_cluster/health?pretty
```

单节点无法分配 Replica。开发索引可将副本数设为 0：

```bash
curl -u "elastic:${ES_PASSWORD}" \
  -H 'Content-Type: application/json' \
  -X PUT http://127.0.0.1:9200/_index_template/dev-default \
  -d '{
    "index_patterns": ["dev-*"],
    "template": {
      "settings": { "number_of_replicas": 0 }
    }
  }'
```

该单机配置的 HTTP 是明文，只允许本机或受控内网访问，不能暴露到公网。

## 3. 三节点集群规划

示例使用 3 台服务器，每台运行一个 Master-eligible Data Node：

| 节点 | 地址变量 | HTTP | Transport | 角色 |
|---|---|---:|---:|---|
| es-node-1 | `ES_NODE_1_IP` | 9200 | 9300 | master、data、ingest |
| es-node-2 | `ES_NODE_2_IP` | 9200 | 9300 | master、data、ingest |
| es-node-3 | `ES_NODE_3_IP` | 9200 | 9300 | master、data、ingest |

部署前确认：

```bash
ping -c 3 <其他节点IP>
nc -vz <其他节点IP> 9300
timedatectl status
```

防火墙只对业务服务器开放 9200，对 ES 节点互相开放 9300。例如使用 UFW：

```bash
sudo ufw allow from <ES集群网段> to any port 9300 proto tcp
sudo ufw allow from <业务服务器网段> to any port 9200 proto tcp
```

## 4. 生成集群证书

只在第一台服务器执行。创建证书描述文件 `instances.yml`，将 IP 替换为实际地址：

```yaml
instances:
  - name: es-node-1
    dns: [es-node-1]
    ip: [ES_NODE_1_IP]
  - name: es-node-2
    dns: [es-node-2]
    ip: [ES_NODE_2_IP]
  - name: es-node-3
    dns: [es-node-3]
    ip: [ES_NODE_3_IP]
```

生成 PEM 证书：

```bash
cd /opt
sudo mkdir -p elasticsearch-cluster/certs
sudo chown -R "$USER":"$USER" elasticsearch-cluster
cd elasticsearch-cluster

docker run --rm \
  -v "$PWD:/work" \
  docker.elastic.co/elasticsearch/elasticsearch:8.15.5 \
  bash -c 'bin/elasticsearch-certutil cert --silent --pem --in /work/instances.yml --out /work/certs.zip'

unzip certs.zip -d certs
chmod 750 certs
find certs -type d -exec chmod 750 {} \;
find certs -type f -name '*.key' -exec chmod 640 {} \;
find certs -type f -name '*.crt' -exec chmod 644 {} \;
```

将完整 `certs` 目录安全复制到另外两台服务器的 `/opt/elasticsearch-cluster/certs`。私钥不得通过公开渠道传输，也不要提交到仓库。

```bash
scp -r certs user@<ES_NODE_2_IP>:/opt/elasticsearch-cluster/
scp -r certs user@<ES_NODE_3_IP>:/opt/elasticsearch-cluster/
```

## 5. 集群 Compose 配置

三台服务器都创建 `/opt/elasticsearch-cluster/compose.yml`：

```yaml
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:${ES_VERSION}
    container_name: ${NODE_NAME}
    restart: unless-stopped
    environment:
      - node.name=${NODE_NAME}
      - cluster.name=${CLUSTER_NAME}
      - node.roles=master,data,ingest
      - network.host=0.0.0.0
      - network.publish_host=${NODE_IP}
      - discovery.seed_hosts=${ES_NODE_1_IP}:9300,${ES_NODE_2_IP}:9300,${ES_NODE_3_IP}:9300
      - cluster.initial_master_nodes=es-node-1,es-node-2,es-node-3
      - bootstrap.memory_lock=true
      - xpack.security.enabled=true
      - xpack.security.transport.ssl.enabled=true
      - xpack.security.transport.ssl.verification_mode=certificate
      - xpack.security.transport.ssl.key=certs/${NODE_NAME}/${NODE_NAME}.key
      - xpack.security.transport.ssl.certificate=certs/${NODE_NAME}/${NODE_NAME}.crt
      - xpack.security.transport.ssl.certificate_authorities=certs/ca/ca.crt
      - xpack.security.http.ssl.enabled=true
      - xpack.security.http.ssl.key=certs/${NODE_NAME}/${NODE_NAME}.key
      - xpack.security.http.ssl.certificate=certs/${NODE_NAME}/${NODE_NAME}.crt
      - xpack.security.http.ssl.certificate_authorities=certs/ca/ca.crt
      - ELASTIC_PASSWORD=${ES_PASSWORD}
      - ES_JAVA_OPTS=${ES_JAVA_OPTS}
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65535
        hard: 65535
    ports:
      - "9200:9200"
      - "9300:9300"
    volumes:
      - ./data:/usr/share/elasticsearch/data
      - ./certs:/usr/share/elasticsearch/config/certs:ro
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS --cacert config/certs/ca/ca.crt -u elastic:${ES_PASSWORD} https://localhost:9200/_cluster/health >/dev/null || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 90s
```

每台服务器创建 `.env`。公共变量相同：

```dotenv
ES_VERSION=8.15.5
CLUSTER_NAME=search-prod
ES_NODE_1_IP=请填写节点1地址
ES_NODE_2_IP=请填写节点2地址
ES_NODE_3_IP=请填写节点3地址
ES_PASSWORD=请填写相同的高强度密码
ES_JAVA_OPTS=-Xms4g -Xmx4g
```

每台服务器再分别追加自己的节点信息：

```dotenv
# 第一台
NODE_NAME=es-node-1
NODE_IP=请填写节点1地址

# 第二台
NODE_NAME=es-node-2
NODE_IP=请填写节点2地址

# 第三台
NODE_NAME=es-node-3
NODE_IP=请填写节点3地址
```

每台服务器创建数据目录：

```bash
cd /opt/elasticsearch-cluster
mkdir -p data
sudo chown -R 1000:0 data certs
sudo chmod -R g+rX certs
```

## 6. 启动和验证集群

第一次启动时，三台服务器依次执行：

```bash
cd /opt/elasticsearch-cluster
docker compose up -d
docker compose ps
docker compose logs --tail=200 elasticsearch
```

任一节点验证：

```bash
curl --cacert certs/ca/ca.crt \
  -u "elastic:${ES_PASSWORD}" \
  "https://${NODE_IP}:9200/_cluster/health?pretty"

curl --cacert certs/ca/ca.crt \
  -u "elastic:${ES_PASSWORD}" \
  "https://${NODE_IP}:9200/_cat/nodes?v"

curl --cacert certs/ca/ca.crt \
  -u "elastic:${ES_PASSWORD}" \
  "https://${NODE_IP}:9200/_cat/shards?v"
```

预期集群节点数为 3，创建带一个 Replica 的索引后状态应为 Green。

`cluster.initial_master_nodes` 只用于全新集群首次引导。集群成功形成后应从 Compose 中删除这一行，再逐台重建容器，防止未来误引导出新集群。不要同时重启全部节点。

## 7. 创建业务账号

业务应用不应使用 `elastic` 超级用户。创建最小权限角色和账号：

```bash
curl --cacert certs/ca/ca.crt -u "elastic:${ES_PASSWORD}" \
  -H 'Content-Type: application/json' \
  -X POST "https://${NODE_IP}:9200/_security/role/product_app" \
  -d '{
    "cluster": ["monitor"],
    "indices": [{
      "names": ["product-*"],
      "privileges": ["read", "write", "create_index"]
    }]
  }'

curl --cacert certs/ca/ca.crt -u "elastic:${ES_PASSWORD}" \
  -H 'Content-Type: application/json' \
  -X POST "https://${NODE_IP}:9200/_security/user/product_app" \
  -d '{
    "password": "请替换为业务账号密码",
    "roles": ["product_app"]
  }'
```

按实际职责继续拆分读账号、写账号和运维账号。

## 8. 配置与性能调优

### 8.1 JVM Heap

- Heap 初始值和最大值保持一致，例如 `-Xms4g -Xmx4g`。
- Heap 通常不超过宿主机可用内存的一半，其余内存留给文件系统缓存。
- 容器内存上限要高于 Heap，并为 Native Memory 和文件缓存留出空间。
- 不要仅因 OOM 不断增大 Heap，应检查字段爆炸、分片、聚合和请求并发。

### 8.2 分片与副本

```http
PUT /_index_template/product-template
{
  "index_patterns": ["product-*"],
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "refresh_interval": "1s"
    }
  }
}
```

分片数不能只按节点数机械设置。根据索引总量、保留周期、查询扇出和恢复时间压测，避免大量小分片。Replica 至少为 1 才能承受单节点故障，但 Replica 也会增加写入与磁盘成本。

### 8.3 写入调优

- 使用 Bulk 并检查每个 Item 的结果。
- 以压测确定批次大小和客户端并发，遇到 `429` 使用指数退避。
- 全量导入时可以临时增大 `refresh_interval`，结束后恢复。
- 可重建数据初次导入时可临时将 Replica 设为 0，完成后恢复并等待 Green。
- 不要把线程池 Queue 调得很大来隐藏过载，应从写入端限速。

### 8.4 磁盘与水位

ES 在磁盘达到水位后会限制分片分配，严重时将索引设为只读。持续监控：

```bash
df -h
curl --cacert certs/ca/ca.crt -u "elastic:${ES_PASSWORD}" \
  "https://${NODE_IP}:9200/_cat/allocation?v"
```

不要等磁盘接近 100% 才扩容。清理数据应通过 ILM 或 Delete Index API，不能直接删除宿主机 Data Path 下的文件。

### 8.5 Linux 和容器

```bash
sysctl vm.max_map_count
ulimit -n
docker stats
```

- 保持 `vm.max_map_count >= 262144`。
- 文件句柄至少 65535。
- 禁用 Swap 或确保 ES 内存不被换出。
- 数据盘优先使用 SSD，监控 IOPS、吞吐和延迟。
- 不要将三个生产节点都部署在同一台宿主机上伪装容灾。

## 9. 日常管理

```bash
# 查看状态和日志
docker compose ps
docker compose logs -f --tail=200 elasticsearch
docker stats

# 重启当前节点
docker compose restart elasticsearch

# 停止并保留数据
docker compose down

# 启动
docker compose up -d
```

集群维护必须逐台执行：确认集群恢复 Green 后再处理下一台。节点长期离线、升级或扩容前，应评估分片迁移产生的网络与磁盘压力。

## 10. Snapshot 备份

Replica 不能替代备份。生产环境应注册 S3、兼容对象存储或共享文件系统 Snapshot Repository，并验证恢复。

```http
PUT /_snapshot/prod_backup
{
  "type": "fs",
  "settings": {
    "location": "/mnt/es-backup",
    "compress": true
  }
}
```

文件系统仓库需要所有 Master/Data 节点挂载同一位置，并在 `path.repo` 中声明。对象存储通常更适合跨机器备份。不要通过复制 `data` 目录做在线备份。

## 11. 滚动升级

1. 阅读目标版本的升级说明，确认插件和客户端兼容性。
2. 创建 Snapshot 并验证仓库状态。
3. 先升级非 Master 节点，再升级符合主节点资格的节点；混合角色集群按官方目标版本顺序执行。
4. 每次只停止一个节点，修改 `.env` 中 `ES_VERSION` 后拉取镜像并重建。
5. 等待节点重新加入且集群恢复稳定，再处理下一节点。

```bash
docker compose pull elasticsearch
docker compose up -d --no-deps elasticsearch
docker compose logs -f --tail=200 elasticsearch
```

Elasticsearch 通常不支持降级。升级前必须保留可恢复 Snapshot，并先在测试环境完成演练。

## 12. 常见问题

### 12.1 `vm.max_map_count` 太低

日志出现 `max virtual memory areas vm.max_map_count ... is too low` 时，按第 1 节修改宿主机参数。只修改容器内参数不会持久生效。

### 12.2 数据目录无权限

```bash
sudo chown -R 1000:0 /opt/elasticsearch-cluster/data
```

确认挂载目录、SELinux/AppArmor 和只读挂载配置，不要直接给目录 `chmod 777`。

### 12.3 集群状态 Yellow

先查看未分配原因：

```http
GET /_cluster/allocation/explain
```

常见原因是节点数不足以放置 Replica、磁盘水位过高或 Allocation Filter 限制。不要在不清楚数据版本时强制分配 Stale Primary。

### 12.4 节点无法加入集群

检查集群名称、节点名称、9300 连通性、证书、系统时间和 `network.publish_host`。Transport 日志中的证书 SAN、未知 CA 或握手失败通常说明各节点证书不匹配。

### 12.5 忘记密码

进入任一正常节点容器重置内置用户密码：

```bash
docker exec -it es-node-1 bin/elasticsearch-reset-password -u elastic -i
```

重置后同步更新密钥管理系统和所有客户端，不要把新密码写入脚本或 Shell 历史。

### 12.6 磁盘水位后索引只读

先释放空间或扩容，等待磁盘回到安全水位，再确认只读 Block 是否自动解除。不要只删除 Block 而不处理磁盘根因，否则很快再次触发。

## 13. 生产环境检查清单

- [ ] 版本固定并经过兼容性验证，不使用浮动 `latest`。
- [ ] 3 个符合主节点资格的节点分布在独立故障域。
- [ ] 9200 和 9300 仅允许可信网络访问。
- [ ] HTTP、Transport TLS 和最小权限账号已启用。
- [ ] Heap、容器内存和宿主机文件缓存合理分配。
- [ ] `vm.max_map_count`、文件句柄、Swap 和磁盘满足要求。
- [ ] 分片、Replica、Mapping、ILM 经过容量评估。
- [ ] 监控 Heap、GC、磁盘水位、延迟、拒绝和未分配分片。
- [ ] Snapshot 位于集群外，并完成过恢复演练。
- [ ] 滚动维护和升级每次只操作一个节点。
