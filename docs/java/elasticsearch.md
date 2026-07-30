# Elasticsearch 全面讲解

## 1. Elasticsearch 是什么

Elasticsearch（简称 ES）是一个分布式搜索与分析引擎，基于 Apache Lucene 构建。它擅长全文检索、结构化过滤、聚合分析和近实时查询，常用于站内搜索、日志检索、指标分析和风控检索。

```text
业务数据 -> 写入 Elasticsearch -> 建立倒排索引 -> 搜索、过滤和聚合
```

常见场景：

- 商品、文章、用户和知识库搜索。
- 日志、链路和审计数据检索。
- 指标聚合、报表和实时看板。
- 地理位置搜索、自动补全和相似内容推荐。

ES 不应直接替代关系数据库。数据库通常仍是事实数据源，ES 是面向检索的派生存储。写入 ES 失败、数据同步延迟和索引重建都需要在系统设计中处理。

单机版、3 节点集群、TLS、安全认证和宿主机调优参见：[Elasticsearch 单机与集群 Docker 部署](../docker/elasticsearch_ubuntu_docker_deploy.md)。

## 术语速览

| 名称 | 含义 |
|---|---|
| Cluster | ES 集群，由一个或多个节点组成。 |
| Node | ES 进程实例，可承担主节点、数据、协调等角色。 |
| Index | 索引，一组结构相似文档的逻辑集合。 |
| Document | 文档，ES 中可被索引和查询的 JSON 数据。 |
| Mapping | 字段类型和索引方式定义，类似数据结构约束。 |
| Shard | 分片，索引在物理上的存储和计算单元。 |
| Replica | 副本分片，用于容灾并分担查询。 |
| Segment | Lucene 不可变索引段，后台会持续合并。 |
| Inverted Index | 倒排索引，从词项映射到包含该词项的文档。 |
| Analyzer | 分析器，由字符过滤器、分词器和词元过滤器组成。 |
| Refresh | 生成可搜索的新 Segment，使新数据对搜索可见。 |
| Translog | 事务日志，用于节点故障后的数据恢复。 |

## 2. 核心概念

### 2.1 Index、Document 和 Mapping

ES 8 中不再使用多 Type 模型，一个 Index 保存一类结构相近的 Document。文档必须是 JSON 对象，并通过 `_id` 唯一标识。

```json
{
  "id": 1001,
  "title": "Redis 入门与实战",
  "category": "java",
  "price": 69.00,
  "tags": ["redis", "cache"],
  "published": true,
  "created_at": "2026-07-30T10:00:00+08:00"
}
```

Mapping 一旦建立，字段类型通常不能直接修改。例如已经定义为 `keyword` 的字段不能原地改成 `date`，应创建新索引并执行 Reindex，再切换别名。

### 2.2 text 和 keyword

| 类型 | 是否分词 | 典型用途 |
|---|---|---|
| `text` | 是 | 标题、正文等全文检索字段 |
| `keyword` | 否 | ID、状态、标签、排序和聚合字段 |

字符串常使用多字段：同一份内容用 `text` 搜索，用 `keyword` 精确过滤、排序和聚合。

```json
"title": {
  "type": "text",
  "fields": {
    "keyword": {
      "type": "keyword",
      "ignore_above": 256
    }
  }
}
```

不要对 `text` 字段直接做排序或 Terms 聚合，也不要为了全文搜索将所有字符串都定义成 `keyword`。

### 2.3 分片和副本

主分片决定索引的数据分布和并行能力，索引创建后不能直接修改主分片数量；副本数量可以动态调整。

```text
index: product_v1
  primary shard 0 -> node-1
  replica shard 0 -> node-2
  primary shard 1 -> node-2
  replica shard 1 -> node-3
  primary shard 2 -> node-3
  replica shard 2 -> node-1
```

分片并非越多越好。过多小分片会增加堆内存、文件句柄、集群状态和调度开销；过大的分片会使恢复、迁移和合并变慢。应按数据量、保留周期、节点数量和查询并发设计，并持续观察实际分片大小。

### 2.4 节点角色

- **Master-eligible**：参与选举，管理集群状态，不负责所有业务请求。
- **Data**：保存分片并执行查询、聚合和写入。
- **Ingest**：执行写入 Pipeline，例如字段转换和解析。
- **Coordinating**：接收请求、分发到相关分片并合并结果；所有节点都具有协调能力。

生产集群通常配置 3 个符合主节点资格的节点，避免脑裂并保证多数派选举。大型集群可将主节点、数据节点和协调节点分离。

## 3. Elasticsearch 为什么搜索快

### 3.1 倒排索引

传统查询通常从文档出发查找词，倒排索引则提前建立“词 -> 文档”的映射。

```text
文档 1：Redis 缓存设计
文档 2：Redis 集群部署

Redis -> [1, 2]
缓存  -> [1]
集群  -> [2]
```

查询时无需扫描全部文档，而是查找词项对应的 Posting List，再计算交集、并集和相关性分数。

### 3.2 分词和分析器

索引和查询应使用兼容的分析器。中文文本不能简单依赖默认 Standard Analyzer，实际项目常使用经评估的中文分词插件、自定义词典或业务侧切词。

```http
POST /_analyze
{
  "analyzer": "standard",
  "text": "Elasticsearch搜索实战"
}
```

分词效果会直接影响召回率和准确率。上线前应准备真实搜索词和期望结果，验证分词、同义词、停用词和相关性，而不是只看少量演示数据。

### 3.3 近实时搜索

文档写入成功不代表立即可被 Search API 搜索到。写入先进入内存缓冲区和 Translog，Refresh 后新 Segment 才对搜索可见，默认通常约 1 秒自动 Refresh。

精确按 ID 获取文档属于实时读取；搜索属于近实时读取。测试或强制读后可见时可以使用 `refresh=wait_for`，但高并发写入不应对每条数据执行强制 Refresh。

## 4. Mapping 与索引设计

### 4.1 显式创建 Mapping

```http
PUT /product_v1
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "refresh_interval": "1s"
  },
  "mappings": {
    "dynamic": "strict",
    "properties": {
      "id":         { "type": "long" },
      "title":      { "type": "text" },
      "category":   { "type": "keyword" },
      "price":      { "type": "scaled_float", "scaling_factor": 100 },
      "tags":       { "type": "keyword" },
      "published":  { "type": "boolean" },
      "created_at": { "type": "date" }
    }
  }
}
```

核心业务索引建议显式 Mapping。完全依赖 Dynamic Mapping 可能把日期识别成文本、数值识别成错误类型，还可能因异常字段名造成 Mapping Explosion。

### 4.2 object 和 nested

普通对象数组会被扁平化，数组内部字段之间的对应关系可能丢失。需要保证同一个数组元素内字段匹配时使用 `nested`。

```json
"variants": {
  "type": "nested",
  "properties": {
    "color": { "type": "keyword" },
    "stock": { "type": "integer" }
  }
}
```

`nested` 会在内部创建额外 Lucene 文档，查询和存储成本更高。数据结构固定且规模较小时再使用，不要无差别定义为 `nested`。

### 4.3 索引别名

应用应访问稳定别名，而不是绑定带版本号的物理索引。

```http
POST /_aliases
{
  "actions": [
    { "remove": { "index": "product_v1", "alias": "product_read" }},
    { "add":    { "index": "product_v2", "alias": "product_read" }}
  ]
}
```

别名切换是原子操作，适合 Mapping 变更、全量重建和无停机迁移。写别名应保证只有一个索引设置 `is_write_index: true`。

## 5. 文档写入与更新

### 5.1 CRUD

```http
# 指定 ID，重复执行会覆盖文档
PUT /product_v1/_doc/1001
{
  "id": 1001,
  "title": "Redis 入门与实战",
  "category": "java",
  "price": 69.00,
  "published": true,
  "created_at": "2026-07-30T10:00:00+08:00"
}

GET /product_v1/_doc/1001

POST /product_v1/_update/1001
{
  "doc": { "price": 59.00 }
}

DELETE /product_v1/_doc/1001
```

ES 的“局部更新”本质上仍会读取旧文档、合并字段并重新索引新文档，旧版本等待 Segment 合并时清理。因此频繁更新同一个大文档成本较高。

### 5.2 Bulk 批量写入

```http
POST /_bulk
{"index":{"_index":"product_v1","_id":"1001"}}
{"id":1001,"title":"Redis 入门","category":"java"}
{"index":{"_index":"product_v1","_id":"1002"}}
{"id":1002,"title":"Kafka 实战","category":"java"}
```

Bulk 使用 NDJSON，每行一个 JSON，最后必须有换行。批量请求可能部分成功，不能只检查 HTTP 状态码，必须遍历 `items` 并对失败项分类重试。批次大小应通过压测确定，过大会占用协调节点和客户端内存。

### 5.3 乐观并发控制

使用 `_seq_no` 和 `_primary_term` 防止并发更新覆盖。

```http
PUT /product_v1/_doc/1001?if_seq_no=7&if_primary_term=1
{
  "id": 1001,
  "title": "Redis 高并发实战"
}
```

版本不匹配时返回 `409 Conflict`，调用方应重新读取、合并或放弃更新，而不是无上限重试。

## 6. Query DSL

### 6.1 match 和 term

`match` 会分析查询文本，适合 `text` 全文检索；`term` 不分词，适合 `keyword`、数值、布尔和日期的精确匹配。

```http
GET /product_read/_search
{
  "query": {
    "match": { "title": "Redis 实战" }
  }
}
```

```http
GET /product_read/_search
{
  "query": {
    "term": { "category": "java" }
  }
}
```

不要对 `text` 字段直接使用 `term` 查询用户输入，否则查询词与索引词项不一致时容易得到空结果。

### 6.2 bool 组合查询

```http
GET /product_read/_search
{
  "query": {
    "bool": {
      "must": [
        { "match": { "title": "Redis" }}
      ],
      "filter": [
        { "term":  { "published": true }},
        { "range": { "price": { "gte": 20, "lte": 100 }}}
      ],
      "must_not": [
        { "term": { "category": "deprecated" }}
      ]
    }
  }
}
```

| 子句 | 是否必须匹配 | 是否参与评分 |
|---|---|---|
| `must` | 是 | 是 |
| `filter` | 是 | 否，适合精确过滤并可能缓存 |
| `should` | 视组合条件而定 | 是 |
| `must_not` | 否 | 否 |

能放在 `filter` 的状态、范围和权限条件不要放入 `must`，避免不必要的评分计算。

### 6.3 常用查询

```http
GET /product_read/_search
{
  "query": {
    "range": {
      "created_at": {
        "gte": "now-7d/d",
        "lt": "now"
      }
    }
  },
  "sort": [
    { "created_at": "desc" },
    { "id": "asc" }
  ],
  "_source": ["id", "title", "created_at"]
}
```

前缀、通配符和正则查询要谨慎使用，尤其避免以 `*` 开头扫描大量词项。搜索框自动补全可使用 `search_as_you_type`、Completion Suggester 或经过设计的 Edge N-gram。

## 7. 聚合分析

聚合用于分组、统计和指标计算，类似 SQL 的 `GROUP BY`。

```http
GET /product_read/_search
{
  "size": 0,
  "query": {
    "term": { "published": true }
  },
  "aggs": {
    "by_category": {
      "terms": { "field": "category", "size": 20 },
      "aggs": {
        "avg_price": { "avg": { "field": "price" }}
      }
    }
  }
}
```

常见聚合：

- Bucket：`terms`、`date_histogram`、`range`。
- Metric：`avg`、`sum`、`min`、`max`、`cardinality`。
- Pipeline：对其他聚合结果继续计算，例如移动平均。

高基数字段的 Terms 聚合可能消耗大量内存。需要遍历全部分组时使用 Composite Aggregation 分页，不要无限增大 `size`。

## 8. 分页、排序和高亮

### 8.1 from/size

```http
GET /product_read/_search
{
  "from": 0,
  "size": 20,
  "sort": [
    { "created_at": "desc" },
    { "id": "asc" }
  ],
  "query": { "match_all": {} }
}
```

`from + size` 越大，各分片需要收集并返回给协调节点的候选结果越多。默认 `index.max_result_window` 通常限制为 10000，不应通过无限调大窗口解决深分页。

### 8.2 search_after 和 PIT

面向用户连续翻页时使用稳定排序、Point In Time（PIT）和 `search_after`。

```http
POST /product_read/_pit?keep_alive=1m
```

```http
GET /_search
{
  "size": 20,
  "pit": { "id": "PIT_ID", "keep_alive": "1m" },
  "sort": [
    { "created_at": "desc" },
    { "id": "asc" }
  ],
  "search_after": ["2026-07-30T10:00:00+08:00", 1001],
  "query": { "match_all": {} }
}
```

排序字段组合必须稳定且最好包含唯一字段。批量导出大量结果也应分批处理，并限制 PIT 保留时间。

### 8.3 高亮

```http
GET /product_read/_search
{
  "query": { "match": { "title": "Redis" }},
  "highlight": {
    "fields": { "title": {} },
    "pre_tags": ["<em>"],
    "post_tags": ["</em>"]
  }
}
```

高亮结果属于外部输入，前端渲染时必须限制允许的标签并防止 XSS。

## 9. Java 与 Spring Boot 使用

### 9.1 依赖与配置

Spring Boot 项目优先使用 Spring Data Elasticsearch，并让 Spring Boot 管理兼容的客户端版本。

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-elasticsearch</artifactId>
</dependency>
```

```yaml
spring:
  elasticsearch:
    uris:
      - https://es-node-1:9200
      - https://es-node-2:9200
      - https://es-node-3:9200
    username: elastic
    password: ${ES_PASSWORD}
    connection-timeout: 3s
    socket-timeout: 10s
```

密码和证书不要提交到仓库。生产环境应启用 TLS，并将 CA 证书加入客户端信任配置。

### 9.2 文档实体和 Repository

```java
@Document(indexName = "product_read", createIndex = false)
public class ProductDocument {
    @Id
    private Long id;

    @Field(type = FieldType.Text)
    private String title;

    @Field(type = FieldType.Keyword)
    private String category;

    @Field(type = FieldType.Double)
    private BigDecimal price;
}
```

```java
public interface ProductSearchRepository
        extends ElasticsearchRepository<ProductDocument, Long> {

    Page<ProductDocument> findByTitleAndCategory(
            String title, String category, Pageable pageable);
}
```

简单 CRUD 可以使用 Repository，复杂查询建议使用 `ElasticsearchOperations` 或官方 Java API Client，显式控制查询、分页和返回字段。

### 9.3 ElasticsearchOperations

```java
NativeQuery query = NativeQuery.builder()
        .withQuery(q -> q.bool(b -> b
                .must(m -> m.match(v -> v
                        .field("title")
                        .query(keyword)))
                .filter(f -> f.term(v -> v
                        .field("category")
                        .value(category)))))
        .withPageable(PageRequest.of(0, 20))
        .withSort(Sort.by(Sort.Direction.DESC, "created_at"))
        .build();

SearchHits<ProductDocument> hits = elasticsearchOperations.search(
        query, ProductDocument.class);
```

客户端 API 会随 Spring Data Elasticsearch 版本变化，升级时以当前依赖版本的 API 为准，不要混用旧的 RestHighLevelClient 示例。

### 9.4 数据同步

推荐链路：

```text
业务事务写数据库
    -> Outbox/Binlog/消息队列
    -> 消费者幂等写 Elasticsearch
    -> 失败重试和死信处理
    -> 定时核对与补偿
```

直接在一个业务请求中先写数据库再写 ES 不能形成跨系统事务。数据库成功而 ES 失败时必须允许重放，使用业务主键作为 `_id` 能让重复写入更容易幂等。

## 10. 写入和查询流程

### 10.1 写入流程

1. 协调节点根据 `_id` 和 Routing 计算目标主分片。
2. 请求转发到主分片，主分片校验并执行写入。
3. 主分片将操作复制到副本分片。
4. 满足写入确认条件后向客户端返回结果。
5. Refresh 后文档才可被搜索。

副本复制并不等于独立备份。误删除、错误更新和程序缺陷可能同步到所有副本，仍需 Snapshot。

### 10.2 查询流程

搜索通常分为 Query 和 Fetch 两个阶段：

```text
Query：协调节点 -> 各相关分片查询并返回文档 ID、排序值和分数
Fetch：协调节点 -> 获取最终命中文档的 _source -> 合并并返回
```

一个搜索请求会访问索引的每个相关分片。分片过多、聚合过重或返回字段过大都会放大协调成本。

### 10.3 Routing

默认 Routing 使用 `_id`。已知租户或业务分区时可以自定义 Routing，使相关数据落在同一分片并减少查询扇出。

```http
PUT /order_v1/_doc/1001?routing=tenant-88
GET /order_v1/_search?routing=tenant-88
```

写入和查询必须使用相同 Routing。还要防止少数大租户造成分片热点，不应只为减少查询分片而忽略数据倾斜。

## 11. 一致性和可靠性

### 11.1 近实时与读后可见

- `GET /index/_doc/id` 可以实时读取最新版本。
- `_search` 要等待 Refresh 后才能看到最新文档。
- `refresh=wait_for` 等待下一次 Refresh，通常比 `refresh=true` 更温和。

不要把搜索未命中直接判断为写入失败，也不要在生产写入路径频繁手动执行 `_refresh`。

### 11.2 写入确认

`wait_for_active_shards` 可以要求指定数量的活跃分片副本后再开始写入，但它不能把 ES 变成强一致数据库。节点故障、超时重试、主分片切换和跨系统同步仍需幂等设计。

客户端收到超时不代表服务端一定未执行。重试写入应使用稳定 `_id`，并设置有限次数、指数退避和随机抖动。

### 11.3 Snapshot 备份

Snapshot 是集群级备份方式，应保存到集群外部的共享仓库或对象存储，并定期验证恢复流程。复制数据目录或虚拟机磁盘快照不能替代 ES Snapshot，可能得到不一致的 Lucene 文件。

## 12. 索引生命周期

日志和指标等时序数据建议使用 Data Stream 与 Index Lifecycle Management（ILM）：

```text
写别名/Data Stream
    -> rollover 创建新索引
    -> warm/cold 阶段降低成本
    -> 到期删除
```

Rollover 可以按索引大小、文档数或时间滚动。相较每天固定创建索引，它更容易控制分片大小。生命周期策略应结合磁盘水位、查询时效和合规保留期设计。

## 13. 性能调优

### 13.1 索引设计

- 明确 Mapping，禁用不需要索引的字段。
- 只对确实需要的字段建立多字段、分词和 Doc Values。
- 控制分片数量，避免大量小分片和超大分片。
- 不需要评分的条件使用 `filter`。
- 限制字段总数、Nested 数量和动态字段。

### 13.2 写入调优

- 使用 Bulk，基于延迟、吞吐和拒绝率调整批次大小与并发数。
- 大批量导入时可临时调大 `refresh_interval`，导入结束后恢复。
- 初次全量导入可临时将副本数设为 0，完成后恢复副本并等待集群变绿；仅适用于能够重新导入的数据。
- 避免频繁更新同一个大文档和过度使用 Ingest Pipeline 脚本。

### 13.3 查询调优

- 限制 `size`、聚合桶数、返回字段和超时时间。
- 避免深分页、前导通配符和高基数大聚合。
- 使用 Slow Log 和 Profile API 定位慢查询，Profile API 本身开销较高，只用于诊断。
- 不要依赖“加缓存”掩盖错误 Mapping、分片设计或查询 DSL。

### 13.4 JVM 和操作系统

- 堆内存通常不超过可用内存的一半，为文件系统缓存保留空间。
- 避免堆超过压缩对象指针适用范围，具体阈值以 JVM 实际输出为准。
- 禁用 Swap 或确保 ES 进程内存不会被换出。
- 提高文件句柄和虚拟内存映射限制，使用 SSD 并监控磁盘延迟。
- 容器必须同时配置容器内存上限和 JVM Heap，避免宿主机 OOM。

调优应以压测和监控数据为依据。CPU、Heap、GC、磁盘、查询延迟、写入拒绝和 Segment Merge 要一起观察。

## 14. 监控与排障

常用命令：

```http
GET /_cluster/health
GET /_cat/nodes?v
GET /_cat/indices?v&s=store.size:desc
GET /_cat/shards?v
GET /_cluster/allocation/explain
GET /_nodes/stats
GET /_nodes/hot_threads
GET /_cat/thread_pool/search?v
GET /_cat/thread_pool/write?v
```

### 14.1 集群状态

| 状态 | 含义 |
|---|---|
| Green | 主分片和副本分片都已分配。 |
| Yellow | 主分片正常，部分副本未分配，数据可用但容灾下降。 |
| Red | 至少一个主分片未分配，部分数据不可用。 |

单节点配置一个副本时通常为 Yellow，因为副本不能与主分片放在同一节点。开发单机可以设副本为 0，生产环境则应增加节点。

### 14.2 常见问题

- **分片未分配**：检查节点数量、磁盘水位、分配规则、版本和 Allocation Explain。
- **查询变慢**：检查慢查询、GC、磁盘延迟、分片数、聚合桶和并发量。
- **写入被拒绝**：检查写线程池、Bulk 并发、Merge、Refresh 和磁盘性能。
- **Heap 持续升高**：检查高基数聚合、字段爆炸、过多分片和缓存占用。
- **磁盘突然增长**：检查写入量、删除文档、Segment Merge、Replica 和 ILM。

不要在未确认原因时直接清理数据目录、强制分配陈旧主分片或无限提高队列容量，这些操作可能导致数据丢失或把拥塞推迟到更危险的位置。

## 15. 安全建议

- 开启身份认证和节点间、客户端 TLS。
- 使用最小权限角色，不让业务账号拥有集群管理权限。
- 不将 9200、9300 直接暴露到公网。
- 密码、API Key 和证书通过密钥管理系统注入。
- 限制脚本、通配符索引操作和批量删除权限。
- 开启必要的审计日志，并定期轮换凭据。
- Snapshot 仓库也要配置访问控制、加密和保留策略。

## 16. 面试高频问题

### 16.1 Elasticsearch 为什么快

> ES 使用 Lucene 倒排索引把词项映射到文档，避免全文扫描；Keyword、数值和日期等字段使用适合过滤、排序和聚合的数据结构；同时通过分片并行查询。但速度仍取决于 Mapping、分片数量、查询 DSL、磁盘和缓存，复杂聚合或前导通配符依然可能很慢。

### 16.2 text 和 keyword 有什么区别

> `text` 会经过分析器分词，用于全文检索；`keyword` 保存完整词项，用于精确匹配、排序和聚合。同一字段需要两种能力时可以使用 Multi-fields。

### 16.3 match 和 term 有什么区别

> `match` 会分析查询文本，通常查询 `text` 字段；`term` 不分析输入，按精确词项匹配，通常查询 `keyword`、数值、日期和布尔字段。对 `text` 字段误用 `term` 是搜索无结果的常见原因。

### 16.4 分片是不是越多越好

> 不是。分片能提高分布式并行和容量，但每个分片都会消耗堆内存、文件句柄和集群状态资源。过多小分片会增加查询扇出和管理开销，过大分片又会减慢恢复与迁移，需要结合数据量、节点数和查询模型压测。

### 16.5 ES 写入成功后为什么搜索不到

> ES 是近实时搜索。写入成功后文档已经进入主副分片，但要等 Refresh 生成可搜索 Segment 后才能被 Search API 查到。可以使用 `refresh=wait_for` 等待下一次 Refresh，不应对每条写入强制 Refresh。

### 16.6 如何解决深分页

> 浅分页使用 `from/size`；深分页或连续翻页使用 PIT 加 `search_after` 和稳定排序；批量导出分批处理。无限增大 `max_result_window` 会放大各分片和协调节点的内存与排序开销。

### 16.7 ES 如何保证数据不丢

> 写入通过主分片、Replica 和 Translog 降低节点故障的数据风险，但副本不是备份。生产环境还要配置合理的写确认、幂等重试和集群外 Snapshot，并定期演练恢复。ES 与数据库之间通常是最终一致，需要消息重试和数据核对。

### 16.8 Refresh、Flush 和 Merge 有什么区别

> Refresh 让内存中的新数据生成可搜索 Segment；Flush 执行 Lucene Commit 并开启新的 Translog generation；Merge 把多个不可变 Segment 合并并清理已删除文档。三者目的不同，频繁手动调用都可能影响性能。

### 16.9 为什么删除文档后磁盘没有立即下降

> Lucene Segment 不可变，删除只是标记文档，磁盘空间通常要等后台 Segment Merge 后才回收。对仍持续写入的索引随意执行 Force Merge 会产生大量 I/O，一般只对只读索引谨慎使用。

### 16.10 如何修改已有字段类型

> 大多数已建立索引的字段类型不能原地修改。应创建带正确 Mapping 的新索引，通过 Reindex 或重新同步写入数据，校验完成后原子切换别名，再按回滚窗口决定何时删除旧索引。

### 16.11 ES 和 MySQL 如何保持一致

> MySQL 作为事实数据源，事务内写业务表和 Outbox，或订阅 Binlog，把事件发送到消息队列；消费者以业务主键作为 ES `_id` 幂等写入，失败重试并进入死信队列，同时通过定时核对和全量重建补偿。它通常保证最终一致而不是跨系统强一致。

### 16.12 脑裂如何避免

> 现代 ES 使用基于多数派的集群协调机制。生产环境配置 3 个符合主节点资格的节点，保证稳定网络和唯一集群引导配置；不要在集群已经形成后反复设置初始主节点列表，也不要把强制分配陈旧主分片作为常规恢复手段。

## 17. 生产环境检查清单

- [ ] 数据库是事实数据源，ES 数据能够重新构建。
- [ ] Mapping、分词器、同义词和真实搜索效果经过验证。
- [ ] 主分片数、Replica、Routing 和 ILM 有容量依据。
- [ ] 应用通过别名或 Data Stream 访问索引。
- [ ] Bulk 处理部分失败，重试有退避、上限和死信记录。
- [ ] 禁止无限深分页、无限聚合桶和无限通配符查询。
- [ ] 开启认证、TLS、最小权限和网络访问控制。
- [ ] 监控 Heap、GC、磁盘水位、分片、延迟和拒绝数。
- [ ] Snapshot 位于集群外部，并完成恢复演练。
- [ ] 索引变更具有重建、校验、切换和回滚流程。

## 18. 学习路线

1. 理解 Index、Document、Mapping、Shard 和 Replica。
2. 掌握 `text`、`keyword`、分析器和倒排索引。
3. 熟悉 CRUD、Bulk、Query DSL、聚合和分页。
4. 使用 Spring Data Elasticsearch 完成查询和数据同步。
5. 理解 Refresh、Translog、Segment、Merge 和并发控制。
6. 学习别名、Reindex、ILM、Snapshot 和集群运维。
7. 通过真实数据压测分片、查询相关性和故障恢复。
