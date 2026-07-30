# MySQL 核心原理与性能优化

## 1. MySQL 是什么

MySQL 是常用的关系数据库管理系统。生产业务通常使用 InnoDB 存储引擎，获得事务、行级锁、MVCC、崩溃恢复和外键等能力。

```text
客户端 -> 连接层 -> SQL 解析与优化 -> 执行器 -> InnoDB -> 数据与日志
```

MySQL 适合作为事实数据源，保存需要事务约束和持久化的业务数据。Redis、Elasticsearch 等通常是缓存或检索副本，不能替代数据库中的唯一约束和事务校验。

单机、主从复制、Docker、备份恢复和参数调优参见：[MySQL 单机与主从 Docker 部署](../docker/mysql_ubuntu_docker_deploy.md)。

## 术语速览

| 名称 | 含义 |
|---|---|
| InnoDB | MySQL 默认事务型存储引擎。 |
| Page | InnoDB 读写磁盘的基本单位，默认通常为 16 KB。 |
| Clustered Index | 聚簇索引，叶子节点保存完整行数据。 |
| Secondary Index | 二级索引，叶子节点通常保存索引列和主键。 |
| MVCC | 多版本并发控制，通过版本链和 Read View 支持快照读。 |
| Redo Log | 记录页修改，用于崩溃恢复。 |
| Undo Log | 保存旧版本，用于回滚和 MVCC。 |
| Binlog | Server 层逻辑日志，用于复制和数据恢复。 |
| Buffer Pool | InnoDB 缓存数据页和索引页的主要内存区域。 |
| GTID | 标识已提交事务，用于简化复制定位和故障切换。 |

## 2. MySQL 架构与执行流程

一条 SQL 的主要执行过程：

1. 客户端从连接池获取连接并完成认证。
2. Server 层解析 SQL，检查语法和对象权限。
3. 优化器根据统计信息生成执行计划。
4. 执行器调用存储引擎接口读取或修改数据。
5. InnoDB 处理 Buffer Pool、索引、锁、事务和 Redo/Undo。
6. 结果通过连接返回客户端。

MySQL 8 已移除 Query Cache。应用查询变快通常来自正确索引、Buffer Pool、操作系统缓存或业务缓存，不应再用旧的 Query Cache 解释。

### 2.1 Server 层与 InnoDB

| Server 层 | InnoDB 层 |
|---|---|
| 连接、认证、SQL 解析、优化器 | 数据页、索引、事务、行锁、MVCC |
| Binlog | Redo Log、Undo Log |
| 函数、视图、存储过程 | Buffer Pool、Change Buffer、Doublewrite |

同一条 SQL 的最终性能由两层共同决定。例如优化器选择哪个索引属于 Server 层决策，实际访问 B+Tree、加锁和读取数据页由 InnoDB 完成。

## 3. InnoDB 存储结构

### 3.1 Page、Extent 和 Tablespace

InnoDB 以 Page 为基本 I/O 单位，多个连续 Page 组成 Extent，数据最终保存在 Tablespace 中。一次只查一行也可能需要从磁盘加载整页，因此相邻数据和缓存命中对性能很重要。

```text
Tablespace
  -> Extent
      -> Page
          -> Row Record
```

### 3.2 聚簇索引

InnoDB 表按主键组织，主键 B+Tree 的叶子节点保存完整行数据。一张表只有一个聚簇索引。

没有显式主键时，InnoDB 会选择合适的非空唯一索引；仍不存在时会生成隐藏行 ID。生产表应显式定义稳定、短小的主键。

主键过长会被所有二级索引叶子节点保存，放大索引体积。随机主键还可能造成页分裂和缓存局部性下降。常用选择是有序数值 ID；如果业务必须使用 UUID，可评估有序 UUID 或将业务 ID 与内部主键分离。

### 3.3 二级索引与回表

```text
二级索引叶子节点：(category, created_at, 主键 id)
        -> 得到主键
        -> 回到聚簇索引读取其他列
```

使用二级索引查到主键后，再访问聚簇索引获取完整行称为回表。查询需要的字段全部存在于二级索引时形成覆盖索引，可以避免回表。

## 4. B+Tree 与索引设计

### 4.1 为什么使用 B+Tree

B+Tree 层级低、扇出高，内部节点只保存索引键和子页指针，叶子节点有序并相互连接，适合等值、范围、排序和前缀查询。

与二叉树相比，B+Tree 每个节点能保存更多键，访问相同数据通常需要更少的磁盘页。与 Hash 相比，它支持范围扫描和有序遍历。

### 4.2 联合索引与最左匹配

```sql
CREATE INDEX idx_order_user_status_created
ON orders(user_id, status, created_at);
```

索引按照 `(user_id, status, created_at)` 排序，因此通常能高效支持：

```sql
WHERE user_id = ?
WHERE user_id = ? AND status = ?
WHERE user_id = ? AND status = ? AND created_at >= ?
```

不能通常依赖它高效支持：

```sql
WHERE status = ?
WHERE created_at >= ?
```

MySQL 某些版本和数据分布下可能使用 Skip Scan 等优化，但不能把它当成稳定替代方案。索引顺序应根据等值条件、范围条件、排序、选择性和核心查询共同设计。

联合索引遇到范围条件后，后续列通常难以继续缩小索引扫描范围，但仍可能通过 Index Condition Pushdown 在存储引擎层过滤，或者用于覆盖查询。不能简单表述为“范围后的列完全失效”。

### 4.3 常见索引未被使用场景

- 对索引列执行不支持索引定位的函数或计算。
- 隐式类型转换，例如字符串列与数值常量比较。
- `LIKE '%keyword'` 前导通配符。
- 联合索引没有可用的前导列。
- `OR` 分支中部分条件无合适索引。
- 返回数据比例过高，优化器认为全表扫描成本更低。
- 统计信息过旧或数据分布极不均匀。

“索引失效”不是固定语法清单。是否使用索引由成本优化器决定，应使用 `EXPLAIN ANALYZE` 验证实际计划和行数。

```sql
-- 不利于普通 created_at 索引定位
WHERE DATE(created_at) = '2026-07-30'

-- 改为范围
WHERE created_at >= '2026-07-30 00:00:00'
  AND created_at <  '2026-07-31 00:00:00'
```

### 4.4 索引设计原则

- 优先服务高频、耗时和核心链路查询。
- 联合索引优于大量重复的单列索引。
- 将过滤、排序和覆盖需求一起考虑。
- 控制索引数量，索引会增加写入、内存和磁盘成本。
- 低选择性字段不代表绝对不能索引，应结合联合条件和查询比例。
- 大文本通常不直接建立普通完整索引，全文搜索可使用专用搜索引擎。

## 5. EXPLAIN 与执行计划

```sql
EXPLAIN FORMAT=TREE
SELECT id, status, created_at
FROM orders
WHERE user_id = 1001
  AND status = 'PAID'
ORDER BY created_at DESC
LIMIT 20;
```

```sql
EXPLAIN ANALYZE
SELECT id, status
FROM orders
WHERE user_id = 1001;
```

`EXPLAIN ANALYZE` 会真正执行查询并返回实际耗时。不要对生产环境中的大范围更新、删除或不可控查询随意执行。

重点观察：

| 字段/信息 | 说明 |
|---|---|
| `type` | 访问方式，如 const、ref、range、index、ALL。 |
| `key` | 实际选择的索引。 |
| `rows` | 预计扫描行数，不是精确值。 |
| `filtered` | 经过条件过滤后预计保留比例。 |
| `Using index` | 使用覆盖索引。 |
| `Using index condition` | 使用 Index Condition Pushdown。 |
| `Using temporary` | 可能使用临时表。 |
| `Using filesort` | 需要额外排序，不等于一定写磁盘文件。 |

不要只看到 `type=ALL` 就立即加索引。小表扫描可能是最优方案，也要判断总耗时、实际行数、执行频率和业务目标。

## 6. 事务与 ACID

| 特性 | 含义 | 主要实现 |
|---|---|---|
| Atomicity | 事务操作全部成功或全部回滚 | Undo Log |
| Consistency | 事务前后满足业务和数据约束 | 应用规则、约束、事务机制 |
| Isolation | 并发事务相互隔离 | 锁、MVCC |
| Durability | 提交后数据能够持久保存 | Redo Log、刷盘、复制、备份 |

```sql
START TRANSACTION;

UPDATE account
SET balance = balance - 100
WHERE id = 1 AND balance >= 100;

UPDATE account
SET balance = balance + 100
WHERE id = 2;

COMMIT;
```

余额扣减应检查第一条 SQL 的影响行数。事务只保证 SQL 原子提交，不会自动理解“余额不能为负”等业务含义，仍需条件更新、唯一约束和业务校验。

### 6.1 隔离级别

| 隔离级别 | 脏读 | 不可重复读 | 幻读 |
|---|---|---|---|
| READ UNCOMMITTED | 可能 | 可能 | 可能 |
| READ COMMITTED | 避免 | 可能 | 可能 |
| REPEATABLE READ | 避免 | 避免 | 通过 MVCC 和锁处理大部分场景 |
| SERIALIZABLE | 避免 | 避免 | 避免，并发成本最高 |

InnoDB 默认通常为 REPEATABLE READ。隔离级别的实际行为要结合快照读、当前读、索引和锁分析，不能只背表格。

## 7. MVCC

InnoDB 行记录包含事务版本信息，通过 Undo Log 形成历史版本链。快照读根据 Read View 判断哪个版本对当前事务可见。

```text
最新记录 -> Undo 版本 1 -> Undo 版本 2 -> 更旧版本
              + Read View 判断可见性
```

### 7.1 Read Committed 与 Repeatable Read

- READ COMMITTED 通常每条快照读语句创建新的 Read View，因此同一事务两次查询可能看到其他事务已经提交的更新。
- REPEATABLE READ 通常在事务第一次一致性读取时创建 Read View，后续快照读复用，因此结果更稳定。

事务开始不一定立即创建 Read View。使用 `START TRANSACTION WITH CONSISTENT SNAPSHOT` 可以明确创建一致性快照。

### 7.2 快照读与当前读

普通 `SELECT` 通常是快照读：

```sql
SELECT * FROM orders WHERE id = 1001;
```

以下操作需要读取最新可用版本并加锁，属于当前读：

```sql
SELECT * FROM orders WHERE id = 1001 FOR UPDATE;
SELECT * FROM orders WHERE id = 1001 FOR SHARE;
UPDATE orders SET status = 'PAID' WHERE id = 1001;
DELETE FROM orders WHERE id = 1001;
```

同一事务中，快照读和当前读可能观察到不同数据版本，这是理解“幻读”讨论的关键。

### 7.3 长事务危害

长事务会长期保留 Undo 版本，阻碍 Purge，增加锁持有时间、复制延迟和故障恢复成本。应监控长事务，并避免事务中等待用户输入、远程服务或大批量处理。

## 8. InnoDB 锁

### 8.1 常见锁

| 锁 | 作用 |
|---|---|
| Shared Lock | 共享锁，允许其他共享读。 |
| Exclusive Lock | 排他锁，用于修改。 |
| Record Lock | 锁住索引记录。 |
| Gap Lock | 锁住索引记录之间的间隙。 |
| Next-Key Lock | Record Lock 与 Gap Lock 的组合。 |
| Intention Lock | 表级意向锁，表示事务准备获取行锁。 |

InnoDB 行锁实际锁定索引记录。更新条件没有合适索引时可能扫描并锁住大量记录，造成严重并发阻塞。

REPEATABLE READ 下，范围当前读通常使用 Next-Key Lock 防止范围内插入。READ COMMITTED 会减少 Gap Lock 使用，但唯一性检查和外键检查等场景仍可能使用。

### 8.2 悲观锁与乐观锁

悲观锁：

```sql
SELECT stock
FROM product_stock
WHERE product_id = 1001
FOR UPDATE;
```

乐观锁：

```sql
UPDATE product_stock
SET stock = stock - 1,
    version = version + 1
WHERE product_id = 1001
  AND stock > 0
  AND version = 7;
```

乐观锁冲突时影响行数为 0，调用方应有限重试或返回冲突。高竞争热点上无限重试会放大数据库压力。

### 8.3 死锁

两个事务以不同顺序获取资源可能死锁：

```text
事务 A：锁订单 1 -> 等订单 2
事务 B：锁订单 2 -> 等订单 1
```

InnoDB 检测到死锁后会回滚其中一个事务。应用必须捕获死锁错误并对幂等事务进行有限次数、带抖动的重试。

降低死锁：

- 多行更新使用稳定的主键顺序。
- 缩短事务和锁持有时间。
- 为条件建立合适索引，减少扫描与锁范围。
- 大批量操作拆成可控批次。
- 不同业务保持一致的表访问顺序。

排查：

```sql
SHOW ENGINE INNODB STATUS\G

SELECT *
FROM performance_schema.data_lock_waits;
```

生产环境应开启死锁日志并采集到日志平台，单次 `SHOW ENGINE INNODB STATUS` 通常只保留最近一次信息。

## 9. Redo、Undo 与 Binlog

| 日志 | 所在层 | 内容 | 用途 |
|---|---|---|---|
| Redo Log | InnoDB | 物理页修改相关记录 | 崩溃恢复、持久性 |
| Undo Log | InnoDB | 修改前的逻辑旧版本 | 事务回滚、MVCC |
| Binlog | Server | 逻辑变更事件 | 主从复制、时间点恢复、CDC |

### 9.1 WAL

InnoDB 修改数据时通常先修改 Buffer Pool 中的数据页并写 Redo，再异步刷脏页。先写日志再写数据页称为 Write-Ahead Logging，避免每次提交都随机写完整数据页。

`innodb_flush_log_at_trx_commit=1` 通常提供最强的单机提交持久性；其他设置可能提高吞吐，但操作系统或机器故障时可能丢失最近事务。

### 9.2 两阶段提交

开启 Binlog 时，MySQL 需要协调 InnoDB Redo 与 Server Binlog，避免一个提交而另一个缺失。典型过程包含 Redo Prepare、写 Binlog、Redo Commit，崩溃恢复时通过事务标识判断最终状态。

```text
Redo Prepare -> 写 Binlog -> Redo Commit
```

数据库事务的两阶段提交不是分布式业务事务。它解决同一 MySQL 实例内部 Redo 与 Binlog 一致性，不会自动保证 MySQL 与 Kafka、Redis 或远程服务共同提交。

### 9.3 Binlog 格式

- `ROW`：记录行变更，复制更可靠，日志可能较大，生产常用。
- `STATEMENT`：记录 SQL，体积可能较小，但某些非确定性语句有风险。
- `MIXED`：由 MySQL 选择两种格式。

MySQL 8.4 默认以 ROW 为主。CDC 和数据恢复应基于经过验证的 Binlog 配置与保留周期。

## 10. SQL 性能优化

### 10.1 优化流程

```text
慢查询日志/监控发现
  -> 确认业务调用频率和延迟
  -> EXPLAIN ANALYZE
  -> 检查扫描行、索引、回表、排序和锁等待
  -> 修改 SQL/索引/模型
  -> 使用真实数据压测
  -> 上线观察回归
```

不要只在空表或少量测试数据上判断索引。优化器选择与数据量、分布、参数值和统计信息有关。

### 10.2 深分页

```sql
-- offset 很大时，需要扫描并丢弃大量记录
SELECT id, created_at
FROM orders
ORDER BY id
LIMIT 1000000, 20;
```

使用 Seek/Keyset Pagination：

```sql
SELECT id, created_at
FROM orders
WHERE id > :last_id
ORDER BY id
LIMIT 20;
```

多列排序时使用稳定、唯一的游标条件：

```sql
WHERE created_at < :last_created_at
   OR (created_at = :last_created_at AND id < :last_id)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

### 10.3 count

InnoDB 不保存满足任意条件的精确总行数，`COUNT(*)` 通常需要扫描合适索引。`COUNT(*)`、`COUNT(1)` 在现代 MySQL 中通常都会被优化，性能重点是过滤条件、索引和扫描量，而不是机械替换写法。

`COUNT(column)` 不统计 NULL，与 `COUNT(*)` 语义不同。超大数据实时精确统计成本高时，可使用汇总表、异步统计或只返回“是否还有下一页”。

### 10.4 JOIN

- 连接列类型、长度和字符集保持一致。
- 为被驱动表连接条件建立索引。
- 尽早过滤数据，只返回需要列。
- 避免一对多 JOIN 导致结果集爆炸后再去重。
- 使用执行计划判断实际连接顺序，不要只凭 SQL 书写顺序猜测。

### 10.5 批量写入

批量 Insert 比逐行往返效率高，但单批过大会增加事务、Redo、锁和复制压力。

```sql
INSERT INTO order_item(order_id, product_id, quantity)
VALUES (?, ?, ?), (?, ?, ?), (?, ?, ?);
```

批次大小通过压测确定。批处理失败要明确整批回滚、逐项重试和幂等策略。

### 10.6 避免 SELECT *

只查询需要字段可以降低网络、序列化和 Buffer Pool 压力，并更容易形成覆盖索引。`SELECT *` 还会让接口在表结构新增大字段后发生不可预期性能下降。

## 11. 表结构设计

- 每张核心表定义主键、必要唯一约束和时间字段。
- 金额使用 `DECIMAL` 或最小货币单位整数，不使用浮点数。
- 时间语义和时区统一；跨地区系统可统一保存 UTC。
- 状态字段建立明确枚举与状态迁移规则。
- 大字段与高频小字段根据访问模式评估垂直拆分。
- 不为“未来可能查询”无限增加索引。
- 业务唯一性由数据库 Unique Key 兜底，不能只依赖先查询后插入。

```sql
CREATE TABLE orders (
    id            BIGINT       NOT NULL,
    order_no      VARCHAR(32)  NOT NULL,
    user_id       BIGINT       NOT NULL,
    status        VARCHAR(20)  NOT NULL,
    amount        DECIMAL(18,2) NOT NULL,
    version       INT          NOT NULL DEFAULT 0,
    created_at    DATETIME(3)  NOT NULL,
    updated_at    DATETIME(3)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_no (order_no),
    KEY idx_user_created (user_id, created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

MySQL 8 的 `utf8mb4` 能完整保存 Unicode。旧的 `utf8` 最多三个字节，不适合作为现代系统默认字符集。

## 12. Spring 事务与连接池

```java
@Transactional(
        isolation = Isolation.READ_COMMITTED,
        timeout = 5,
        rollbackFor = Exception.class)
public void createOrder(CreateOrderCommand command) {
    orderRepository.insert(command);
    outboxRepository.insert(command.toEvent());
}
```

Spring 隔离级别最终映射到数据库连接。事务通常绑定当前线程，因此新线程、`@Async` 和虚拟线程任务不会自动继承调用方事务。

常见事务失效：

- 同类 `this` 调用绕过 Spring Proxy。
- 异常被捕获后未重新抛出。
- 受检异常未配置回滚规则。
- 对象由 `new` 创建，不属于容器。
- 使用的 TransactionManager 与数据源不匹配。
- 在异步线程中误以为继承原事务。

### 12.1 HikariCP

连接池不是越大越好。过多并发连接会增加数据库线程调度、锁竞争和内存压力。

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 30
      minimum-idle: 10
      connection-timeout: 3000
      validation-timeout: 1000
      max-lifetime: 1700000
```

`max-lifetime` 应短于数据库、代理和网络设备的连接回收时间，并加入合理抖动。连接池大小需要结合应用实例数计算总连接数：

```text
总连接上限 = 单实例连接池 × 应用实例数 + 管理与其他业务连接
```

虚拟线程可以降低等待连接的线程成本，但不会增加数据库容量。仍要限制查询并发、设置 SQL 超时，并监控连接池等待数和等待时间。

## 13. 主从复制

典型异步复制流程：

```text
Primary 提交事务并写 Binlog
  -> Replica I/O 线程接收日志
  -> Relay Log
  -> Replica SQL/Applier 线程重放
```

主从复制常用于容灾、只读查询和备份，但默认可能存在复制延迟。刚写入 Primary 后立即读取 Replica，可能读不到最新数据。

处理读写一致性：

- 写后一定时间内固定读 Primary。
- 关键读取始终走 Primary。
- 携带 GTID/位点并等待 Replica 追上，但会增加延迟。
- 允许业务展示最终一致结果。

Replica 不是独立备份。误删除和错误更新同样会被复制，需要 Binlog 归档、全量备份和恢复演练。

MySQL 异步主从不会自动完成可靠故障切换。生产高可用可评估 InnoDB Cluster、Orchestrator、ProxySQL 或云数据库能力，并重点验证脑裂防护、数据丢失边界和客户端切换。

## 14. 分区与分库分表

### 14.1 分区表

分区把一张逻辑表的数据放到多个物理分区。查询包含分区键时可以进行 Partition Pruning，但分区不是提升所有查询性能的通用方案。

分区适合生命周期清理和按时间管理大表。分区键、唯一索引约束、分区数量和运维操作都有额外限制，上线前应验证当前 MySQL 版本行为。

### 14.2 分库分表

只有单实例容量、写入、备份恢复或隔离确实达到瓶颈时再考虑分库分表。它会引入：

- 全局 ID。
- 跨分片查询和排序。
- 分布式事务。
- 扩容迁移和数据核对。
- 聚合报表和运维复杂度。

优先完成索引优化、历史归档、读写分离、缓存和垂直拆分。分片键应匹配主要查询和写入路径，避免热点分片。

## 15. 监控与排障

常用 SQL：

```sql
SHOW GLOBAL STATUS;
SHOW ENGINE INNODB STATUS\G
SHOW PROCESSLIST;

SELECT * FROM performance_schema.data_lock_waits;

SELECT *
FROM sys.statement_analysis
ORDER BY total_latency DESC
LIMIT 20;
```

重点指标：

- QPS、TPS、P95/P99 延迟和错误率。
- 活跃连接、连接等待和拒绝。
- Buffer Pool 命中、脏页和刷盘。
- Redo 写入、Checkpoint 压力和磁盘延迟。
- 行锁等待、死锁和长事务。
- 慢查询数量与扫描行数。
- Binlog 体积和 Replica 延迟。
- CPU、内存、磁盘容量、IOPS 和吞吐。

### 15.1 慢 SQL

开启有控制的慢查询日志，通过 `pt-query-digest` 或日志平台聚合。优先优化总耗时高的 SQL，而不是只看单次最慢 SQL：一个 20 ms 但每秒执行数万次的查询可能比偶发 2 秒查询消耗更多资源。

### 15.2 CPU 飙高

检查高频 SQL、扫描行数、排序聚合、执行计划变化、并发量和统计信息。不要直接重启掩盖现场，先保留 Processlist、Performance Schema、慢日志和系统指标。

### 15.3 连接数耗尽

检查连接泄漏、慢事务、数据库响应、应用实例扩容和连接池总量。提高 `max_connections` 会增加内存与调度压力，必须同时处理连接长期占用的原因。

### 15.4 复制延迟

检查 Primary 大事务、Replica 磁盘与 CPU、并行复制配置、网络和表结构。单条超大事务无法被简单拆开并行重放，应从写入端控制批次。

## 16. 安全建议

- 数据库不直接暴露公网，只允许业务和运维网段访问。
- 应用使用独立最小权限账号，不使用 Root。
- 开启 TLS，密码和证书交给密钥管理系统。
- 区分读、写、迁移、备份和监控账号。
- 禁止业务账号执行 `DROP`、授权和全局管理命令。
- 审计高风险 DDL、批量更新和敏感数据访问。
- 备份加密，并限制下载、恢复和删除权限。
- 定期升级受支持版本并验证客户端兼容性。

## 17. 面试高频问题

### 17.1 为什么 InnoDB 使用 B+Tree

> B+Tree 扇出高、层级低，访问数据需要的磁盘页较少；叶子节点有序且相连，既支持等值查询，也支持范围、排序和前缀扫描。Hash 不擅长范围查询，普通二叉树在磁盘上层级通常更深。

### 17.2 聚簇索引和二级索引有什么区别

> 聚簇索引叶子节点保存完整行，一张 InnoDB 表只有一个，通常是主键；二级索引叶子节点保存索引列和主键，通过主键回到聚簇索引获取其他列。查询字段都在二级索引中时可以形成覆盖索引。

### 17.3 最左匹配原则是什么

> 联合索引按定义列顺序排序，查询通常需要从最左前导列开始利用有序性。范围条件后的列往往不能继续缩小扫描区间，但仍可能用于 ICP 或覆盖索引，不能简单说后续列完全失效。

### 17.4 MVCC 如何实现

> InnoDB 通过记录中的事务版本信息、Undo Log 版本链和 Read View 判断数据可见性，使普通 SELECT 可以读取一致性快照而不阻塞写入。RC 通常每条语句创建 Read View，RR 通常复用事务中的 Read View。

### 17.5 快照读和当前读有什么区别

> 普通 SELECT 通常按 Read View 读取历史可见版本，属于快照读；`SELECT ... FOR UPDATE`、UPDATE 和 DELETE 读取最新可用版本并加锁，属于当前读。同一事务中两者可能看到不同版本。

### 17.6 Record、Gap 和 Next-Key Lock 是什么

> Record Lock 锁索引记录，Gap Lock 锁索引记录之间的间隙，Next-Key Lock 是二者组合。RR 下范围当前读使用 Next-Key Lock 防止其他事务在范围内插入，从而处理幻读。

### 17.7 Redo、Undo 和 Binlog 有什么区别

> Redo 是 InnoDB 的页修改日志，用于崩溃恢复；Undo 保存旧版本，用于回滚和 MVCC；Binlog 是 Server 层逻辑变更日志，用于复制、CDC 和时间点恢复。开启 Binlog 时通过内部两阶段提交协调 Redo 和 Binlog。

### 17.8 为什么索引存在却没有使用

> 成本优化器认为全表扫描更便宜、条件返回比例过高、函数或隐式转换破坏索引定位、联合索引缺少前导列、统计信息不准等都可能导致不用索引。应通过 EXPLAIN ANALYZE 和真实数据确认，不能只靠语法判断。

### 17.9 如何优化深分页

> 大 Offset 会扫描并丢弃大量记录。连续翻页应使用基于稳定排序键的 Keyset Pagination，例如 `WHERE id > lastId ORDER BY id LIMIT n`；需要随机跳页时可以先通过覆盖索引定位 ID，再回表查询详情。

### 17.10 如何处理死锁

> InnoDB 会选择一个事务回滚。应用对幂等操作进行有限退避重试，同时通过死锁日志找出锁顺序，统一多行更新顺序、缩短事务、补充索引并控制批次，不能只依赖无限重试。

### 17.11 主从复制为什么会延迟

> Binlog 传输和 Replica 重放都是异步过程，大事务、Replica CPU/磁盘较慢、并行度不足和网络延迟都会造成落后。写后立刻读的关键业务应读 Primary 或等待指定复制位点。

### 17.12 MySQL 如何保证提交后不丢数据

> 单机持久性依赖 Redo 刷盘策略，复制提高节点故障容忍度，Binlog 和全量备份用于恢复。但任何单一机制都不等于绝对不丢，需要正确的刷盘、半同步或高可用策略、独立备份和恢复演练共同保证目标 RPO/RTO。

### 17.13 count(*) 和 count(1) 哪个快

> 在现代 MySQL/InnoDB 中，优化器通常会选择成本较低的索引完成 `COUNT(*)` 或 `COUNT(1)`，两者通常没有值得依赖的性能差异。`COUNT(column)` 不统计 NULL，语义不同。真正影响性能的是过滤条件、索引和扫描数据量。

### 17.14 为什么不建议长事务

> 长事务长时间占用连接和锁，保留 Undo 版本、阻碍 Purge，增加复制延迟与崩溃恢复成本。事务内不应等待远程调用、用户输入或处理无界批量数据。

## 18. 生产环境检查清单

- [ ] 核心表有主键、唯一约束和符合查询的联合索引。
- [ ] 使用 `utf8mb4`，金额、时间和状态字段类型明确。
- [ ] 慢 SQL 使用真实数据和 `EXPLAIN ANALYZE` 验证。
- [ ] 事务短小，不在事务中执行长时间远程调用。
- [ ] 锁等待、死锁和长事务有监控与重试策略。
- [ ] 连接池总量不超过数据库容量，并设置获取超时。
- [ ] Redo、Binlog、刷盘和复制参数符合 RPO/RTO。
- [ ] Replica 延迟被监控，关键写后读具有一致性策略。
- [ ] 数据库账号最小权限，网络、TLS 和审计已配置。
- [ ] 全量备份、Binlog 归档和恢复演练完整。

## 19. 学习路线

1. 理解 Server 层、InnoDB、Page 和 Buffer Pool。
2. 掌握 B+Tree、聚簇索引、联合索引和执行计划。
3. 掌握事务隔离、MVCC、当前读和锁。
4. 理解 Redo、Undo、Binlog 和崩溃恢复。
5. 学习慢 SQL、分页、Join 和批量写入优化。
6. 掌握 Spring 事务、连接池和读写一致性。
7. 学习复制、备份恢复、高可用和容量规划。
