# Redis 全面讲解

## 1. Redis 是什么

Redis（Remote Dictionary Server）是一个以内存为主、支持持久化的高性能键值数据库。它不仅能保存字符串，还提供 Hash、List、Set、Sorted Set、Stream 等数据结构，以及过期、事务、Lua 脚本、发布订阅、主从复制、哨兵和集群能力。

一句话理解：

```text
Redis 用内存提供低延迟读写，通过持久化和复制降低数据丢失风险，并用丰富的数据结构解决缓存、计数、排行、队列和并发控制问题。
```

常见使用场景：

- 缓存热点数据，降低数据库压力。
- 保存登录会话、验证码和短期令牌。
- 计数器、访问频率统计和接口限流。
- 排行榜、点赞、关注关系和共同好友。
- 分布式锁、信号量和幂等标记。
- 延迟任务、简单队列和 Stream 消息队列。

Redis 很快，但不能简单理解为“永远不会丢数据的内存数据库”。是否会丢数据取决于持久化、复制、故障切换和客户端确认策略。缓存、数据库和消息队列也有不同的可靠性要求，设计时要先确定 Redis 在系统中的角色。

---

## 术语速览

| 名称 | 含义 |
|---|---|
| RDB | 某一时刻的数据快照，文件紧凑，恢复速度快。 |
| AOF | 追加写命令日志，可配置每次、每秒或由操作系统决定刷盘。 |
| Replication | 主节点向从节点复制数据，默认是异步复制。 |
| Sentinel | 哨兵，负责监控、通知和主从故障转移。 |
| Cluster | Redis Cluster，通过 16384 个哈希槽实现分片和故障转移。 |
| TTL | Key 的剩余生存时间，到期后由 Redis 删除。 |
| Eviction | 内存达到上限后，根据淘汰策略删除 Key。 |
| Hot Key | 访问量远高于其他 Key 的热点键。 |
| Big Key | Value 过大或集合元素过多的键。 |

## 2. 核心数据结构

### 2.1 String

String 是最基础的类型，可以保存字符串、整数、浮点数或二进制数据，单个 Value 最大为 512 MB，但生产环境不应保存过大的值。

```bash
SET user:1001:name "Zhang San"
GET user:1001:name

SET login:code:13800000000 "839201" EX 300
TTL login:code:13800000000

INCR article:1001:view
INCRBY account:1001:points 10
```

典型场景：缓存、验证码、计数器、分布式锁和幂等标记。

### 2.2 Hash

Hash 适合保存对象的多个字段，可以只读取或更新其中一个字段。

```bash
HSET user:1001 name "Zhang San" age 28 city "Shanghai"
HGET user:1001 name
HMGET user:1001 name age
HGETALL user:1001
HINCRBY user:1001 points 5
```

Hash 不等于关系数据库中的表。对象字段特别多或单个 Hash 元素过多时，也会形成 Big Key。

### 2.3 List

List 是有序字符串列表，支持从两端插入和弹出。

```bash
LPUSH task:ready task-1 task-2
RPOP task:ready
LRANGE task:ready 0 -1

# 没有元素时最多阻塞 10 秒
BRPOP task:ready 10
```

List 可以实现简单队列，但没有完善的消费者组、消息确认和失败重试。可靠消息场景优先使用 Redis Stream 或专业消息中间件。

### 2.4 Set

Set 是无序、不重复的字符串集合。

```bash
SADD article:1001:likes user-1 user-2
SISMEMBER article:1001:likes user-1
SCARD article:1001:likes
SINTER user:1:follows user:2:follows
```

典型场景：去重、标签、点赞用户、共同好友和抽奖。

### 2.5 Sorted Set

Sorted Set 为每个成员保存一个分数，成员唯一，按分数排序。

```bash
ZADD rank:daily 98.5 user-1 86 user-2
ZINCRBY rank:daily 5 user-2
ZREVRANGE rank:daily 0 9 WITHSCORES
ZRANK rank:daily user-1
```

典型场景：排行榜、按时间排序的数据、延迟任务和滑动窗口限流。

### 2.6 Bitmap、HyperLogLog 和 GEO

- Bitmap：按位记录状态，适合签到、在线状态和布尔统计。
- HyperLogLog：用很小内存估算基数，适合 UV 统计，结果存在误差。
- GEO：保存经纬度并计算附近位置，底层基于 Sorted Set。

### 2.7 Stream

Stream 是 Redis 5.0 引入的日志型数据结构，支持消息 ID、消费者组、消息确认和待处理列表。

```bash
XADD order:events * orderId 1001 status created
XGROUP CREATE order:events order-group 0 MKSTREAM
XREADGROUP GROUP order-group consumer-1 COUNT 10 BLOCK 5000 STREAMS order:events >
XACK order:events order-group 1710000000000-0
XPENDING order:events order-group
```

消费者处理成功后再执行 `XACK`。还要监控 Pending Entries List，并处理消费者宕机后长期未确认的消息。

## 3. Redis 为什么快

Redis 高性能的主要原因：

1. 数据主要保存在内存中，避免普通磁盘随机访问。
2. 核心命令执行路径主要是单线程，不需要为数据操作频繁加锁，也减少线程上下文切换。
3. 使用 I/O 多路复用，一个线程可以管理大量网络连接。
4. 数据结构针对常见操作做了专门优化。
5. 支持 Pipeline，将多条命令批量发送，减少网络往返。

“Redis 是单线程”并不完整。Redis 6 开始可以使用 I/O 线程处理网络读写，后台还有持久化、异步释放等线程；核心命令执行仍主要由单线程串行完成。因此，复杂度高的命令、Big Key 和 Lua 长脚本仍可能阻塞其他请求。

## 4. Redis 安装与部署

Redis 单机版、3 主 3 从 Cluster 的 Docker Compose 部署，以及持久化、配置调优、备份恢复、滚动升级和常见故障处理，统一参考：[Ubuntu Docker 部署 Redis](../docker/redis_ubuntu_docker_deploy.md)。

## 5. 持久化

### 5.1 RDB 快照

RDB 将某一时刻的数据生成紧凑的二进制快照。触发方式包括：

- 配置文件中的 `save` 规则自动触发。
- `BGSAVE` 在后台创建快照，生产环境通常使用它。
- `SAVE` 在主线程同步生成快照，会阻塞请求，不建议在线上执行。
- 正常关闭、主从全量复制等流程也可能触发快照。

优点：

- 文件紧凑，适合备份和灾难恢复。
- 加载速度通常比 AOF 快。
- 对正常请求的持续写入开销较小。

缺点：

- 两次快照之间宕机，会丢失这段时间的数据。
- `fork` 子进程和写时复制会造成 CPU、内存和磁盘 I/O 压力。

### 5.2 AOF 追加日志

AOF 记录会改变数据的写命令，重启时重放日志恢复数据。

```conf
appendonly yes
appendfsync everysec
```

`appendfsync` 三种常见策略：

| 策略 | 含义 | 性能与风险 |
|---|---|---|
| `always` | 每条写命令都刷盘 | 数据最安全，性能开销最大。 |
| `everysec` | 每秒刷盘一次 | 常用折中方案，异常时理论上可能丢失约 1 秒数据。 |
| `no` | 交给操作系统决定 | 性能较好，丢失窗口不可控。 |

AOF 会逐渐变大。Redis 通过 AOF Rewrite 将多条历史命令压缩为恢复当前数据集所需的最少命令：

```bash
BGREWRITEAOF
```

Redis 7 的 AOF 使用多文件结构，通常包括基础文件、增量文件和清单文件。备份时不要只随意复制其中一个文件，应按当前版本的 AOF 目录结构整体处理。

### 5.3 RDB 和 AOF 如何选择

| 需求 | 建议 |
|---|---|
| 纯缓存，数据可从数据库重建 | 可以只用 RDB，甚至关闭持久化。 |
| 允许最多丢失约 1 秒数据 | 开启 AOF，使用 `everysec`。 |
| 同时需要较快恢复和较小丢失窗口 | 同时开启 RDB 和 AOF。 |
| 极高数据可靠性 | 不能只依赖 Redis 持久化，还需要复制、备份和业务侧一致性设计。 |

RDB 与 AOF 同时开启时，Redis 重启通常优先使用 AOF 恢复，因为 AOF 一般包含更新的数据。

### 5.4 备份与恢复

备份不能等同于复制。主节点误删数据时，删除命令也会同步到从节点；独立备份才能应对误操作和逻辑损坏。

建议流程：

1. 定期生成并复制 RDB/AOF 到独立存储。
2. 备份文件按日期保留，并校验文件完整性。
3. 定期在隔离环境执行恢复演练。
4. 记录 Redis 版本、配置和恢复耗时。

恢复前应停止目标实例，确认数据目录和文件权限，再放入备份文件并启动。不要直接覆盖正在写入的生产数据文件。

### 5.5 持久化常见问题

- `MISCONF Redis is configured to save RDB snapshots`：检查磁盘是否已满、目录权限、`dir` 配置和 Redis 日志，不要只用 `CONFIG SET stop-writes-on-bgsave-error no` 掩盖故障。
- AOF 文件损坏：先保留原文件，再使用对应版本的 `redis-check-aof` 检查和修复。
- `fork` 耗时过长：检查内存规模、系统负载、透明大页和磁盘性能。
- 容器重建后数据消失：通常是 `/data` 没有正确挂载到持久化存储。

## 6. 常用命令

### 6.1 Key 管理

```bash
EXISTS user:1001
TYPE user:1001
EXPIRE user:1001 3600
TTL user:1001
PERSIST user:1001
DEL user:1001
UNLINK user:1001
```

`DEL` 同步释放内存，删除 Big Key 可能阻塞主线程；`UNLINK` 会先解除 Key，再由后台线程回收内存，通常更适合删除大对象。

生产环境不要使用 `KEYS *` 扫描全库，应使用渐进式 `SCAN`：

```bash
SCAN 0 MATCH user:* COUNT 100
```

`SCAN` 每次返回新的游标，直到游标再次为 `0` 才算完成；遍历期间数据变化时，结果可能重复，也不能保证完整快照语义。

### 6.2 服务信息和诊断

```bash
INFO
INFO memory
INFO persistence
INFO replication
DBSIZE
CLIENT LIST
SLOWLOG GET 20
LATENCY DOCTOR
MEMORY USAGE user:1001
```

### 6.3 Pipeline

Pipeline 将多条命令一次发送，减少网络往返，但它不保证事务原子性：

```bash
redis-cli -a 'ChangeThisStrongPassword' --pipe < commands.txt
```

批次不能无限增大，否则客户端和 Redis 都需要缓存大量请求与响应。应根据单条命令大小、网络和延迟目标设置合理批次。

## 7. Java 与 Spring Boot 使用

### 7.1 Spring Boot 依赖

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```

Spring Data Redis 默认使用 Lettuce 客户端。Lettuce 基于 Netty，连接线程安全，支持同步、异步和响应式调用；Jedis 的连接通常不能被多个线程直接共享，需要使用连接池。

### 7.2 连接配置

```yaml
spring:
  data:
    redis:
      host: 192.168.30.116
      port: 6379
      password: ${REDIS_PASSWORD}
      database: 0
      connect-timeout: 2s
      timeout: 1s
      lettuce:
        pool:
          max-active: 32
          max-idle: 16
          min-idle: 4
          max-wait: 500ms
```

连接池大小不应盲目增加。Redis 核心命令串行执行，过多连接只会制造排队、放大超时和资源占用。应结合实例 QPS、命令耗时和应用实例数量压测。

### 7.3 RedisTemplate

```java
import java.time.Duration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

@Service
public class VerificationCodeService {
    private final StringRedisTemplate redisTemplate;

    public VerificationCodeService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public void save(String phone, String code) {
        redisTemplate.opsForValue().set(
                "login:code:" + phone,
                code,
                Duration.ofMinutes(5));
    }

    public boolean verify(String phone, String code) {
        String key = "login:code:" + phone;
        String cached = redisTemplate.opsForValue().get(key);
        return code.equals(cached);
    }
}
```

不要依赖 JDK 默认序列化保存业务对象，它可读性差、体积大且存在版本兼容问题。常见做法是明确使用 String/JSON，并为 JSON 的字段演进制定兼容规则。

### 7.4 Spring Cache

```java
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

@Service
public class UserService {

    @Cacheable(cacheNames = "user", key = "#userId", unless = "#result == null")
    public User findById(Long userId) {
        return loadFromDatabase(userId);
    }

    @CacheEvict(cacheNames = "user", key = "#user.id")
    public void update(User user) {
        updateDatabase(user);
    }
}
```

实际项目还要统一配置缓存 TTL 和序列化器。没有 TTL 的缓存会持续占用内存；更新数据库后缓存删除失败时，则需要重试、消息通知或订阅数据库变更来最终修复。

## 8. 缓存设计

### 8.1 Cache Aside

最常见的旁路缓存流程：

```text
读：先读缓存 -> 未命中则读数据库 -> 回写缓存
写：先更新数据库 -> 再删除缓存
```

写操作通常选择“更新数据库后删除缓存”，而不是同时更新缓存。删除可以让下一次读取从数据库加载最新数据，也避免复杂对象的多处更新逻辑。

严格一致性场景不能仅靠 Cache Aside。数据库更新成功而缓存删除失败时会产生旧数据，应使用重试、延迟双删、消息队列或 Binlog 订阅等方式缩短不一致窗口。

缓存异常对比速记：

| 问题 | 原因 | 现象 | 解决方案 |
|---|---|---|---|
| 缓存穿透 | 查询的数据不存在 | 请求持续访问 DB | 空值缓存、布隆过滤器 |
| 缓存击穿 | 热点 Key 过期 | 瞬间大量请求访问 DB | 分布式锁、热点 Key 不过期 |
| 缓存雪崩 | 大量 Key 同时过期或 Redis 不可用 | DB 瞬间压力巨大 | 随机过期、多级缓存、限流降级 |

### 8.2 缓存穿透

缓存穿透是客户端持续查询数据库中不存在的数据。由于 Redis 和数据库都查不到结果，如果不缓存空结果，后续相同请求仍会绕过缓存访问数据库。攻击者还可能使用随机 ID 制造大量不同请求，导致数据库连接和 CPU 被耗尽。

```text
请求不存在的商品 ID
        -> Redis 未命中
        -> 查询数据库仍不存在
        -> 不写缓存
        -> 下一次请求继续访问数据库
```

解决方案：

- **入口校验**：校验 ID 格式、取值范围、权限和请求频率，明显非法的请求直接拒绝。
- **缓存空值**：数据库确认数据不存在后，将空结果写入 Redis，并设置较短 TTL，例如 1～5 分钟。适合 Key 数量可控、数据可能稍后创建的场景。
- **布隆过滤器**：请求先判断 ID 是否可能存在；确认不存在时直接返回。适合数据量大、查询入口集中的场景。
- **限流和风控**：按用户、IP 或接口限流，防止攻击者用随机 Key 绕过空值缓存。

空值缓存示例：

```text
key:   cache:product:999999
value: __NULL__
ttl:   120 秒
```

空值 TTL 不宜过长，否则数据新建后可能仍返回不存在。写入新数据时，应主动删除对应空值缓存。布隆过滤器存在误判：它可能把不存在的数据判断为“可能存在”，但不能把已存在的数据判断为不存在；数据新增、删除时还要考虑过滤器同步和重建。

### 8.3 缓存击穿

缓存击穿是某个高并发热点 Key 突然失效或被删除，大量请求在同一时刻发现缓存未命中，并发访问数据库。它通常只影响少数热点 Key，但瞬时回源流量很大，也称“热点 Key 重建问题”。

```text
热点 Key 过期
    -> 请求 A、B、C 同时未命中
    -> A、B、C 同时查询数据库
    -> 数据库瞬时压力升高
```

解决方案：

- **互斥重建**：缓存未命中后竞争分布式锁，只允许一个请求查询数据库并重建缓存；其他请求短暂等待后重试缓存，或直接返回降级结果。
- **逻辑过期**：Value 中保存业务数据和逻辑过期时间，Redis Key 本身不过期。数据逻辑过期后先返回旧值，再由获得锁的线程异步刷新，适用于允许短时间旧数据的热点查询。
- **热点 Key 不过期**：对极少数稳定热点不设置 TTL，由后台任务或数据变更事件主动更新，但必须解决长期占用内存和数据一致性问题。
- **提前刷新**：在热点 Key 到期前异步续期或重建，避免流量高峰期失效。

互斥重建流程：

```text
查询缓存
  ├─ 命中：直接返回
  └─ 未命中：尝试获取短期互斥锁
       ├─ 成功：再次检查缓存 -> 查询数据库 -> 写缓存 -> 释放锁
       └─ 失败：短暂等待 -> 重试缓存，超过上限后降级
```

获得锁后必须再次检查缓存，防止等待期间其他线程已经完成重建。锁需要唯一令牌和过期时间，释放时使用 Lua 比较令牌后删除。等待必须设置超时和重试上限，不能让业务线程无限阻塞。

### 8.4 缓存雪崩

缓存雪崩是大量缓存同时失效，使原本由 Redis 承担的请求在短时间内集中访问数据库，进而引发连接池耗尽、接口超时和服务级联故障。

常见原因分为两类：

- **大量 Key 集中过期**：批量导入或缓存预热时给 Key 设置了相同 TTL，到期后请求同时回源。
- **Redis 整体不可用**：节点宕机、网络故障、内存耗尽、慢命令或错误配置导致大面积缓存请求失败。

解决方案：

- **打散过期时间**：基础 TTL 加随机值，例如 `30 分钟 + 0～5 分钟`，避免同批 Key 同时失效。
- **提前刷新和缓存预热**：热点 Key 到期前异步刷新；发布或流量高峰前预先加载热点数据。
- **高可用部署**：使用主从、Sentinel 或 Redis Cluster，配置合理的故障转移和客户端超时，降低 Redis 整体不可用概率。
- **多级缓存**：使用本地缓存承接部分热点读流量，但要设置容量上限和一致性策略。
- **限流、熔断和降级**：限制回源并发量；数据库压力超过阈值时快速失败、返回旧缓存或默认值，防止故障扩散。
- **数据库保护**：隔离连接池、限制慢查询和回源线程数，避免缓存故障拖垮核心数据库。

```text
正常：请求 -> Redis -> 少量未命中 -> 数据库
雪崩：请求 -> 大量缓存失效 -> 限流/降级 -> 有上限地回源数据库
```

仅设置随机 TTL 只能解决“集中到期”，不能解决 Redis 整体故障。生产方案需要同时覆盖缓存过期、高可用和数据库保护。

### 8.5 热 Key 和 Big Key

热 Key 会使单个 Redis 节点或网络连接成为瓶颈。可以通过本地缓存、只读副本、Key 拆分和请求合并降低压力。

Big Key 会造成网络延迟、阻塞删除、主从复制抖动和 Cluster 迁移困难。治理方式包括拆分对象、分页读取、限制集合长度，并使用 `MEMORY USAGE`、`redis-cli --bigkeys` 或采样工具识别。

## 9. 事务和 Lua 脚本

### 9.1 MULTI/EXEC

```bash
MULTI
INCR account:1001:points
SADD activity:joined user-1001
EXEC
```

Redis 事务保证 `EXEC` 中的命令连续执行，不会被其他客户端命令插入，但不提供关系数据库式回滚。某条命令运行时失败，不会自动撤销已经成功的其他命令。

`WATCH` 可以实现乐观锁：被监视的 Key 在 `EXEC` 前发生变化时，事务执行失败，客户端需要重新读取并重试。

### 9.2 Lua 原子操作

判断值相等后删除 Key 的 Lua 脚本：

```lua
if redis.call('GET', KEYS[1]) == ARGV[1] then
    return redis.call('DEL', KEYS[1])
end
return 0
```

Lua 脚本在 Redis 中原子执行，适合把“读取、判断、修改”组合成一个不可分割的操作。但脚本执行期间会阻塞其他命令，所以脚本必须短小，不应包含大范围扫描或复杂循环。

## 10. 并发限制与等待

并发控制首先要分清需求：

| 需求 | 合适工具 |
|---|---|
| 同一资源同一时刻只允许一个执行者 | 分布式互斥锁 |
| 同一资源最多允许 N 个执行者 | 分布式信号量 |
| 每秒或每分钟最多允许 N 个请求 | 限流器 |
| 没有任务时等待新任务 | 阻塞队列或 Stream 的 `BLOCK` |

### 10.1 基础分布式锁

加锁必须由一条原子命令同时完成“仅不存在时写入”和“设置过期时间”：

```bash
SET lock:order:1001 6f4d7c9e NX PX 30000
```

- `NX`：只有 Key 不存在时才写入。
- `PX 30000`：30 秒后自动过期，避免进程崩溃后永久死锁。
- Value：当前持有者的唯一令牌，不能只写固定值。

释放时必须先校验令牌再删除，并使用 Lua 保证原子性：

```lua
if redis.call('GET', KEYS[1]) == ARGV[1] then
    return redis.call('DEL', KEYS[1])
end
return 0
```

不能直接执行 `DEL lock:order:1001`。如果业务执行超过锁 TTL，原锁已经过期并被其他线程获得，旧线程直接删除会误删新持有者的锁。

### 10.2 为什么推荐 Redisson

手写锁还要处理等待重试、可重入、续期、中断和异常释放。Java 项目通常使用成熟的 Redisson：

```xml
<dependency>
    <groupId>org.redisson</groupId>
    <artifactId>redisson-spring-boot-starter</artifactId>
    <version>3.47.0</version>
</dependency>
```

带最大等待时间和租约时间的加锁示例：

```java
import java.util.concurrent.TimeUnit;
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;

public class OrderService {
    private final RedissonClient redissonClient;

    public OrderService(RedissonClient redissonClient) {
        this.redissonClient = redissonClient;
    }

    public void process(Long orderId) throws InterruptedException {
        RLock lock = redissonClient.getLock("lock:order:" + orderId);

        // 最多等待 3 秒；获得锁后 30 秒自动释放
        boolean acquired = lock.tryLock(3, 30, TimeUnit.SECONDS);
        if (!acquired) {
            throw new IllegalStateException("订单正在处理中，请稍后重试");
        }

        try {
            processOrder(orderId);
        } finally {
            if (lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }
}
```

等待策略应有明确上限：

- HTTP 请求一般只等待很短时间，超时后快速失败或返回“处理中”。
- 后台任务可进行有限次数重试，并使用指数退避和随机抖动。
- 不要用无休止的 `while` 循环频繁执行 `SET NX`，这会增加 Redis 压力并造成惊群。
- 线程等待锁时仍占用应用资源，应同时限制线程池队列和请求超时。

如果调用 `lock.lock()` 时不指定租约，Redisson 的看门狗会在客户端仍存活时为锁续期；指定租约后通常按固定时间自动释放。无论哪种方式，业务执行都应有超时边界。

### 10.3 最多允许 N 个并发

例如第三方接口最多允许 10 个并发调用，可以使用 Redisson 信号量：

```java
import java.util.concurrent.TimeUnit;
import org.redisson.api.RPermitExpirableSemaphore;

RPermitExpirableSemaphore semaphore =
        redissonClient.getPermitExpirableSemaphore("semaphore:partner-api");
semaphore.trySetPermits(10);

// 最多等待 500 毫秒，许可 10 秒后自动回收
String permitId = semaphore.tryAcquire(500, 10_000, TimeUnit.MILLISECONDS);
if (permitId == null) {
    throw new IllegalStateException("系统繁忙，请稍后重试");
}

try {
    callPartnerApi();
} finally {
    semaphore.release(permitId);
}
```

使用带过期时间的许可，可以降低客户端崩溃导致许可永久泄漏的风险。许可时长应略大于业务调用超时，并监控获取失败率和当前可用许可数。

### 10.4 接口限流

并发限制控制“同时执行多少个”，限流控制“单位时间允许多少个”，二者不能互相替代。

Redisson 限流示例：

```java
import java.time.Duration;
import org.redisson.api.RRateLimiter;
import org.redisson.api.RateIntervalUnit;
import org.redisson.api.RateType;

RRateLimiter limiter = redissonClient.getRateLimiter("rate:user:" + userId);
limiter.trySetRate(RateType.OVERALL, 100, 1, RateIntervalUnit.MINUTES);

if (!limiter.tryAcquire(1, Duration.ofMillis(100))) {
    throw new IllegalStateException("请求过于频繁");
}
```

严格业务规则可使用 Lua 实现固定窗口、滑动窗口或令牌桶。限流 Key 必须设置过期时间，否则会因用户维度不断增长而占满内存。

### 10.5 阻塞等待任务

简单队列可以使用 `BRPOP`，避免没有数据时频繁轮询：

```bash
BRPOP task:ready 5
```

Stream 消费者组可以使用阻塞读取：

```bash
XREADGROUP GROUP workers worker-1 COUNT 10 BLOCK 5000 STREAMS task:stream >
```

`BLOCK 5000` 最多等待 5 秒，超时后客户端可以检查关闭信号、刷新心跳或重新读取。一般不建议永久阻塞，因为应用需要具备优雅停机和故障检测能力。

### 10.6 分布式锁的边界

- Redis 主从复制默认异步。主节点加锁成功但锁尚未复制时宕机，从节点晋升后另一个客户端可能再次获得锁。
- 进程暂停、网络分区或锁过期后，旧持有者仍可能继续操作共享资源。
- 对资金、库存最终扣减等强一致场景，除锁之外还应使用数据库唯一约束、版本号、幂等键或 fencing token。
- 锁粒度应尽可能细，例如按 `orderId` 加锁，不要用一个全局锁串行化全部订单。

分布式锁的目标通常是减少并发冲突，不应把它当作数据正确性的唯一防线。

## 11. 过期与内存淘汰

### 11.1 Key 如何过期

Redis 结合两种策略删除过期 Key：

- 惰性删除：访问 Key 时检查，过期则删除。
- 定期删除：周期性抽样检查并删除过期 Key。

因此，Key 到期不代表内存会在同一毫秒立即释放。

### 11.2 淘汰策略

当内存超过 `maxmemory`，Redis 根据 `maxmemory-policy` 处理新写入：

| 策略 | 含义 |
|---|---|
| `noeviction` | 不淘汰，写命令返回错误。 |
| `allkeys-lru` | 从所有 Key 中近似淘汰最近最少使用的 Key。 |
| `allkeys-lfu` | 从所有 Key 中近似淘汰访问频率最低的 Key。 |
| `allkeys-random` | 从所有 Key 中随机淘汰。 |
| `volatile-lru` | 仅从设置了 TTL 的 Key 中按 LRU 淘汰。 |
| `volatile-lfu` | 仅从设置了 TTL 的 Key 中按 LFU 淘汰。 |
| `volatile-ttl` | 优先淘汰剩余 TTL 较短的 Key。 |

纯缓存常用 `allkeys-lru` 或 `allkeys-lfu`。Redis 同时保存缓存和不可丢数据时，淘汰策略很难兼顾，最好拆分不同实例。

## 12. 高可用与集群

### 12.1 主从复制

从节点通过复制主节点数据提供冗余和只读能力。复制默认异步，因此主节点返回写成功不代表从节点一定已经收到数据。

```conf
replicaof 192.168.30.116 6379
masterauth ChangeThisStrongPassword
```

可以使用 `WAIT` 要求当前连接之前的写入在指定时间内被一定数量的副本确认：

```bash
WAIT 1 1000
```

它能缩小数据丢失窗口，但不等于强一致事务，也不能替代持久化和业务幂等。

### 12.2 Sentinel

Sentinel 适合不需要数据分片、但需要自动故障转移的场景。它负责：

- 监控主从节点是否正常。
- 多个 Sentinel 达成主节点客观下线判断。
- 选举并提升一个从节点为新主节点。
- 通知客户端新的主节点地址。

生产环境通常部署至少 3 个独立 Sentinel，并让客户端连接 Sentinel 获取当前主节点，不要把固定主节点 IP 写死。

### 12.3 Redis Cluster

Redis Cluster 将 Key 映射到 16384 个哈希槽，槽分布在多个主节点上。每个主节点可以有从节点，主节点故障时进行切换。

```text
slot = CRC16(key) mod 16384
```

多 Key 命令、事务和 Lua 脚本通常要求相关 Key 位于同一槽。可以使用 Hash Tag 控制：

```text
order:{1001}:detail
order:{1001}:items
```

花括号中的 `1001` 用于计算槽，因此两个 Key 会落入同一槽。Hash Tag 不应过度集中，否则会造成槽和节点负载不均衡。

## 13. 一致性和可靠性

### 13.1 Redis 能保证数据不丢吗

不能绝对保证。常见丢失窗口包括：

- AOF `everysec` 尚未刷盘时机器宕机。
- 主从异步复制尚未完成时主节点故障切换。
- 应用收到超时，但服务端实际已经执行，重试造成重复操作。
- 运维误删、错误脚本和数据过期配置。

需要通过幂等、数据库约束、复制、持久化、备份和恢复演练共同降低风险。

### 13.2 命令超时不代表未执行

客户端超时只表示没有及时收到响应。命令可能尚未执行、正在执行或已经执行但响应丢失。对于扣减、创建任务等操作，应携带业务幂等号，并保证重试不会造成重复结果。

## 14. 性能调优

### 14.1 客户端

- 设置连接超时、命令超时和有限的连接池等待时间。
- 避免无限重试，使用有限重试、退避和随机抖动。
- 批量操作优先使用 `MGET`、`MSET` 或 Pipeline，但限制批次大小。
- 避免序列化超大对象，关注请求和响应字节数。

### 14.2 服务端

- 设置 `maxmemory`，为操作系统、复制缓冲和持久化预留内存。
- 避免 `KEYS`、超大集合全量读取、长 Lua 脚本等阻塞命令。
- 监控慢查询、命中率、内存碎片、过期和淘汰数量。
- Linux 环境通常应按 Redis 官方建议检查 `vm.overcommit_memory`、透明大页和 TCP backlog。
- 持久化磁盘优先使用低延迟 SSD，并与其他高 I/O 服务隔离。

### 14.3 不要只看 QPS

同样的 QPS 下，`GET` 小字符串和读取百万元素集合的成本完全不同。容量评估应同时关注：

- 命令类型和时间复杂度。
- Key/Value 大小和网络吞吐。
- P50、P95、P99 延迟。
- 持久化和复制产生的额外 I/O。
- 热 Key 导致的单节点负载偏斜。

## 15. 监控与排障

建议重点监控：

| 指标 | 说明 |
|---|---|
| `used_memory` | Redis 已使用内存。 |
| `used_memory_rss` | 操作系统看到的常驻内存。 |
| `mem_fragmentation_ratio` | 内存碎片参考指标，需要结合绝对值判断。 |
| `connected_clients` | 当前客户端连接数。 |
| `blocked_clients` | 正在执行阻塞命令的客户端数。 |
| `instantaneous_ops_per_sec` | 每秒处理命令数。 |
| `keyspace_hits/misses` | 缓存命中和未命中次数。 |
| `evicted_keys` | 因内存不足被淘汰的 Key 数。 |
| `expired_keys` | 已过期 Key 数。 |
| `master_repl_offset` | 主节点复制偏移量。 |
| `latest_fork_usec` | 最近一次 fork 耗时。 |

### 15.1 延迟突然升高

排查顺序：

1. 查看 `SLOWLOG GET` 和 `LATENCY DOCTOR`。
2. 检查是否出现 Big Key、热 Key、长 Lua 脚本或大范围扫描。
3. 检查 AOF Rewrite、RDB 快照和 `fork` 耗时。
4. 检查 CPU、内存交换、网络丢包和磁盘延迟。
5. 检查客户端连接池是否耗尽，是否发生大量超时重试。

### 15.2 内存持续增长

- 使用 `INFO memory` 和 `MEMORY STATS` 查看内存构成。
- 检查 Key 是否遗漏 TTL。
- 对不同前缀采样，识别增长最快的业务。
- 检查 Stream Pending、List、Set 和 Sorted Set 是否无限增长。
- 不要在生产高峰直接运行成本不可控的全量分析命令。

### 15.3 缓存命中率低

```text
hit rate = keyspace_hits / (keyspace_hits + keyspace_misses)
```

命中率低不一定是故障。要结合业务读写比例、TTL、数据是否适合缓存、Key 设计和预热情况判断。

## 16. 安全建议

- Redis 只监听内网地址，通过防火墙限制来源。
- Redis 6 及以上优先使用 ACL，为不同应用分配不同用户和命令权限。
- 禁止业务账号执行 `FLUSHALL`、`CONFIG`、`SHUTDOWN` 等管理命令。
- 密码和证书通过 Secret 管理，不写入仓库和日志。
- 跨不可信网络访问时启用 TLS 或使用受控的安全隧道。
- 定期升级受支持版本，关注安全公告。

ACL 示例：

```bash
ACL SETUSER order-service on >StrongPassword ~order:* +get +set +del +expire
ACL LIST
```

## 17. 面试高频问题

### 17.1 Redis 为什么快

> Redis 数据主要在内存中，核心命令执行路径采用单线程，避免了频繁加锁和上下文切换；网络层使用 I/O 多路复用，并针对不同场景实现了高效数据结构。它还有 Pipeline、I/O 线程等能力减少网络开销。但 Big Key、慢命令和长 Lua 脚本仍会阻塞核心执行线程。

### 17.2 RDB 和 AOF 有什么区别

> RDB 保存某一时刻的数据快照，文件紧凑、恢复快，但两次快照之间可能丢失较多数据。AOF 记录写命令，数据更完整但文件和持续写入成本更高。常用 AOF `everysec` 在性能和可靠性之间折中，关键实例也可以同时开启 RDB 和 AOF，并配合复制与独立备份。

### 17.3 缓存穿透、击穿和雪崩有什么区别

> 穿透是持续查询不存在的数据，可用参数校验、缓存空值和布隆过滤器；击穿是单个热点 Key 失效后大量请求回源，可用互斥重建或逻辑过期；雪崩是大量 Key 同时失效或 Redis 整体不可用，可用随机 TTL、高可用、限流降级和多级缓存。

### 17.4 Redis 分布式锁如何实现

> 加锁使用 `SET key uniqueValue NX PX ttl`，将互斥写入和过期设置放在一条原子命令中；释放锁用 Lua 比较唯一令牌后删除，防止误删其他客户端的锁。工程上通常使用 Redisson处理可重入、等待和续期。对强一致业务还要配合数据库约束、幂等或 fencing token，因为主从切换和锁过期仍存在并发边界。

### 17.5 过期 Key 是立即删除的吗

> 不是。Redis 同时使用惰性删除和定期抽样删除。访问过期 Key 时会删除，后台也会周期性清理，因此到期时间和实际释放内存的时间可能存在差异。

### 17.6 Redis 的事务支持回滚吗

> 不支持关系数据库式回滚。`MULTI/EXEC` 保证队列中的命令连续执行，但某条命令运行失败时，其他已成功命令不会撤销。需要组合原子逻辑时可以使用 Lua，复杂数据一致性仍应交给数据库事务或业务补偿。

### 17.7 如何保证缓存和数据库一致

> 常见方案是 Cache Aside：读取先查缓存，未命中查数据库并回填；写入先更新数据库，再删除缓存。删除失败要重试或通过消息、Binlog 订阅最终修复。该方案通常只能保证最终一致，强一致场景需要重新评估是否应直接读取数据库。

### 17.8 Redis Cluster 如何定位 Key

> Redis Cluster 将 Key 的 CRC16 结果对 16384 取模，得到哈希槽，再由负责该槽的节点处理。多 Key 操作要求 Key 在同一槽时，可以使用 `{...}` Hash Tag，但需要避免大量 Key 集中到少数槽。

### 17.9 如何处理热 Key 和 Big Key

> 热 Key 重点解决单点访问压力，可以使用本地缓存、请求合并、只读副本或 Key 拆分。Big Key 重点解决传输和阻塞问题，需要拆分 Value、限制集合长度、分页处理，并优先使用渐进式扫描和异步删除。

### 17.10 Redis 可以作为消息队列吗

> List 可实现简单队列，Stream 支持消费者组、确认和 Pending，功能更完整。但复杂的可靠投递、长期堆积、跨地域容灾和成熟运维通常更适合 Kafka、RocketMQ 等专业消息中间件。是否使用 Redis 要根据可靠性和吞吐需求决定。

### 17.11 `SET NX` 成功后业务超时怎么办

> 锁必须设置合理 TTL，并在 `finally` 中只释放自己持有的锁。若业务可能超过 TTL，可以使用 Redisson 看门狗续期，但业务本身仍要设置超时。对不可重复执行的操作还要增加业务幂等和数据库约束，因为客户端超时并不代表服务端没有执行。

### 17.12 并发限制和限流有什么区别

> 并发限制约束同一时刻正在执行的数量，通常用信号量；限流约束单位时间内通过的请求数量，通常用令牌桶或滑动窗口。一个接口可能同时需要两者：限流保护入口流量，信号量保护下游并发连接数。

## 18. 生产环境检查清单

- 明确 Redis 是缓存、临时状态还是关键数据存储。
- 配置 `maxmemory`、淘汰策略和关键 Key 的 TTL。
- 根据丢失容忍度选择 RDB、AOF 和复制方案。
- 不暴露公网，使用 ACL 和最小权限账号。
- 客户端设置连接、命令、等待超时和有限重试。
- 禁止 `KEYS *`、超大批次和不受控的 Lua 脚本。
- 监控内存、延迟、慢查询、命中率、淘汰、复制和持久化。
- 定期识别热 Key、Big Key 和无 TTL Key。
- 分布式锁设置唯一令牌、TTL、等待上限，并提供业务幂等兜底。
- 定期做备份恢复和主从故障切换演练。

## 19. 学习路线

1. 本地部署 Redis，练习 String、Hash、List、Set 和 Sorted Set。
2. 理解 TTL、淘汰策略、Pipeline、事务和 Lua。
3. 使用 Spring Data Redis 完成缓存、计数和幂等功能。
4. 掌握 RDB、AOF、备份与恢复。
5. 实践 Redisson 锁、信号量和限流器，验证等待与超时行为。
6. 学习主从复制、Sentinel 和 Redis Cluster。
7. 结合监控排查慢查询、热 Key、Big Key 和内存问题。

Redis 的学习重点不是记住全部命令，而是理解数据结构、持久化和并发边界，并能根据数据可靠性要求选择正确方案。
