# RabbitMQ 与 RocketMQ

## 1. 消息队列解决什么问题

消息队列把生产者和消费者从时间、吞吐和部署上解耦：

```text
Producer -> Broker 持久化/路由 -> Consumer
```

常见作用：

- 异步化非核心操作，降低接口延迟。
- 削峰填谷，保护数据库和下游服务。
- 发布订阅，让多个系统消费同一事件。
- 延迟任务、重试和死信处理。
- 跨服务最终一致性。

消息队列不是免费缓存。它会引入重复、乱序、积压、消息契约、消费失败和运维成本。业务必须定义消息丢失边界、最大延迟和重放方式。

## 术语速览

| 名称 | RabbitMQ | RocketMQ |
|---|---|---|
| 路由单位 | Exchange -> Queue | Topic -> Message Queue |
| 消费组织 | Consumer + Queue | Consumer Group + Queue |
| 确认 | Ack/Nack、Publisher Confirm | Offset、重试状态 |
| 顺序 | 单 Queue 内顺序 | 单 MessageQueue 内顺序 |
| 延迟 | TTL + DLX 等 | 延迟/定时消息能力 |
| 事务消息 | 应用自行实现 | 原生事务消息机制 |
| 适合 | 灵活路由、低延迟工作队列 | 高吞吐、日志和业务事件流 |

## 2. 消息可靠性模型

### 2.1 至少一次

```text
生产者发送成功
  -> Broker 持久化
  -> 消费者处理业务
  -> 消费确认/提交 Offset
```

消费者在业务处理成功前崩溃，消息会再次投递。因此生产和消费都应按至少一次设计，幂等是必需能力。

### 2.2 最多一次

先确认消息再执行业务，故障时可能丢消息。只适合允许丢失的指标、日志或采样数据。

### 2.3 Exactly Once

中间件可能在限定边界提供 Exactly Once，但“消息 + 数据库 + 外部 API”全链路不会自动只执行一次。生产系统通常采用：

```text
至少一次投递 + 幂等生产/消费 + 对账补偿
```

## 3. RabbitMQ 核心概念

```text
Producer -> Exchange --binding--> Queue -> Consumer
```

- Exchange 接收消息并按规则路由。
- Queue 保存待消费消息。
- Binding 连接 Exchange 与 Queue，通常带 Routing Key。
- Consumer 从 Queue 获取消息。
- Virtual Host 隔离资源和权限。

Exchange 类型：

| 类型 | 路由规则 |
|---|---|
| Direct | Routing Key 精确匹配。 |
| Topic | `*` 匹配一段，`#` 匹配零到多段。 |
| Fanout | 广播到所有绑定 Queue，忽略 Key。 |
| Headers | 按消息 Header 匹配，使用较少。 |

同一 Queue 的多个 Consumer 竞争消费，消息通常只交给其中一个；不同 Queue 可分别获得同一事件副本。

## 4. RabbitMQ 生产者

### 4.1 发布确认

开启 Publisher Confirm 后，Broker 确认已接受消息。Confirm 不代表消费者已经处理，也不等于业务数据库提交成功。

```java
CorrelationData correlation = new CorrelationData(messageId);
rabbitTemplate.convertAndSend(
        "order.events", "order.created", payload, correlation);
```

配置 Confirm、Return 回调并记录失败消息。交换机不存在、Routing Key 无匹配 Queue 或 Broker 拒绝都必须被业务感知。

### 4.2 持久化

- Durable Exchange/Queue：Broker 重启后拓扑仍存在。
- Persistent Message：消息标记为持久化。
- Publisher Confirm：确认 Broker 接收。
- 磁盘和集群副本：降低节点故障风险。

四者缺一不可。持久化会增加磁盘和延迟，应根据 RPO 选择。

### 4.3 Outbox

数据库提交和 RabbitMQ 发布不是一个本地事务。可靠发布可以使用 Transactional Outbox：业务表和 Outbox 同事务写入，再由 Publisher 发送，失败重试。

## 5. RabbitMQ 消费者

### 5.1 Ack

```java
@RabbitListener(queues = "order.created.queue")
public void consume(OrderCreated event) {
    orderProjection.applyIdempotently(event);
}
```

手动 Ack 流程：

```text
收到消息 -> 执行业务 -> 成功 ack
                    -> 可重试异常 nack/requeue
                    -> 不可恢复异常转死信
```

不要在业务成功前 Ack，也不要对格式错误和永久失败消息无限 requeue。

### 5.2 Prefetch

Prefetch 决定 Consumer 未确认消息上限。过大提高吞吐但增加内存、处理不公平和故障重复量；过小降低并行度。按处理时延、消息大小和消费者数量压测设置。

### 5.3 重试与死信

```text
业务 Queue -> 失败 -> Retry Queue/TTL -> Dead Letter Exchange
                                     -> 原 Queue 或死信 Queue
```

重试要有次数和退避。RabbitMQ TTL + DLX 的延迟实现可能让 Queue 头部消息阻塞其他消息；复杂延迟场景应评估插件、分层重试队列或专用延迟服务。

死信消息必须保存原消息、失败原因、次数、异常摘要和首次失败时间，并提供人工重放工具。

### 5.4 Quorum Queue

生产可靠队列优先评估 Quorum Queue，通过 Raft 复制提高容灾能力。它比经典镜像队列有不同的内存、磁盘和吞吐特征，不能仅修改类型后无压测迁移。

## 6. RocketMQ 核心概念

```text
Producer -> Topic -> MessageQueue -> ConsumerGroup
```

- NameServer：提供路由发现。
- Broker：存储、投递和管理消息。
- Topic：消息类别。
- MessageQueue：Topic 的并行分片和顺序单元。
- Consumer Group：同组消费者共同消费；不同组各自获得消息。

RocketMQ 的 Topic 通常拥有多个 MessageQueue，消费者实例会分配 Queue。增加消费者超过 Queue 数量时，超出的实例没有实际消费分片。

## 7. RocketMQ 生产者

```java
Message message = MessageBuilder
        .withPayload(payload)
        .setHeader(RocketMQHeaders.TOPIC, "order-events")
        .setHeader(RocketMQHeaders.KEYS, orderId)
        .build();

rocketTemplate.syncSend("order-events", message);
```

消息 Key 用于检索和幂等关联，不等于分区键。同步发送适合必须知道发送结果的业务；异步发送需要回调、超时和失败补偿；单向发送允许丢失，不适合订单和支付。

发送结果成功只表示 Broker 接受，不表示下游业务完成。生产者应设置发送超时、重试上限和消息大小上限。

## 8. RocketMQ 消费者

```java
@RocketMQMessageListener(
        topic = "order-events",
        consumerGroup = "order-projection")
public class OrderConsumer implements RocketMQListener<OrderCreated> {
    @Override
    public void onMessage(OrderCreated event) {
        projectionService.applyIdempotently(event);
    }
}
```

消费成功后提交 Offset。抛出异常通常会触发重试，超过阈值进入死信队列。重试不是无限等待，业务应监控重试次数、最老消息时间和死信数量。

消费模式：

- Clustering：同组内负载均衡，每条消息由组内一个实例处理。
- Broadcasting：每个实例都收到消息，适合本地刷新但要控制实例数量。

## 9. RocketMQ 顺序消息

### 9.1 顺序生产

同一业务 Key 固定发送到同一 MessageQueue：

```java
rocketTemplate.syncSendOrderly(
        "order-events", message, orderId.toString());
```

### 9.2 顺序消费

顺序只在同一 Queue 内成立。消费者处理慢或失败可能阻塞该 Queue 后续消息，不能同时追求严格顺序和无限并行。

适合顺序的状态机：

```text
CREATED -> PAID -> SHIPPED -> COMPLETED
```

消费者应校验事件版本，乱序到达时暂存、重试或触发对账，不要盲目覆盖新状态。

## 10. 延迟与定时消息

延迟消息用于“未来某时执行”，例如订单超时关闭、支付超时提醒。它不是精确实时定时器，实际触发受 Broker、积压和调度精度影响。

```text
发送消息 -> delay level/定时时间 -> 消费者收到 -> 检查业务状态 -> 执行
```

消费者必须重新查询业务状态。订单已经支付时，延迟关闭消息应被幂等忽略。

大量精确时间任务可以使用时间轮、任务表或专用调度服务，避免生成海量延迟消息。

## 11. RocketMQ 事务消息

事务消息典型流程：

```text
发送 Half Message
  -> 执行本地事务
  -> Commit / Rollback
  -> Broker 对未知状态回查
```

本地事务状态必须能从数据库查询，回查操作幂等且有超时策略。事务消息仍需要消费者幂等、死信和对账，不能保证外部支付系统也一起原子提交。

## 12. 重复消费与幂等

使用事件 ID、业务单号或幂等键：

```sql
CREATE TABLE consumed_event (
    consumer_group VARCHAR(100) NOT NULL,
    event_id       VARCHAR(100) NOT NULL,
    consumed_at    DATETIME(3) NOT NULL,
    PRIMARY KEY (consumer_group, event_id)
);
```

在同一本地事务中写去重记录和业务结果，成功后再 Ack/提交 Offset。重复消息遇到唯一键冲突时，要判断是否已完成，而不是简单当成系统错误。

天然幂等操作更好：

- 使用 `UPDATE ... WHERE version = ?`。
- 以业务单号做唯一键。
- 状态机只允许合法迁移。
- 余额、库存使用条件更新而不是重复加减。

## 13. 消息顺序、积压与扩容

### 13.1 积压指标

- 消息数量不是唯一指标，要看最老消息年龄。
- 生产速率、消费速率、失败率和重试速率一起观察。
- 检查分区/Queue 是否倾斜和单条毒消息阻塞。
- 扩容消费者前确认 Queue 数量、数据库和下游容量。

### 13.2 扩容风险

增加消费者提高并行度，但可能破坏本地缓存顺序、放大数据库连接和产生更多锁冲突。扩容应配合限流、批量、连接池和下游保护。

### 13.3 消息大小

消息只携带必要事件数据和业务 ID。大对象放对象存储或数据库，消息传引用。消息体过大会增加网络、磁盘、复制和 GC 压力。

## 14. RabbitMQ 与 RocketMQ 选择

| 维度 | RabbitMQ | RocketMQ |
|---|---|---|
| 核心模型 | Exchange/Queue 灵活路由 | Topic/Queue 高吞吐日志模型 |
| 路由复杂度 | 强，适合多种绑定 | 以 Topic 和 Key 为主 |
| 顺序 | Queue 内顺序 | MessageQueue 内顺序 |
| 延迟消息 | 常需 TTL/DLX 或插件 | 原生延迟/定时能力更丰富 |
| 事务消息 | 应用模式实现 | 原生事务消息回查 |
| 运维重点 | Queue、连接、Ack、内存水位 | Broker 磁盘、CommitLog、消费位点 |
| 选择建议 | 中小规模、复杂路由、低延迟工作队列 | 高吞吐、顺序、延迟和事件流 |

不要只按 benchmark 选型。团队运维能力、云平台支持、消息规模、顺序和延迟需求更重要。

## 15. 监控与排障

### RabbitMQ

- Ready、Unacked 和 Total 消息数。
- Consumer 数、Channel/Connection 数。
- Publish、Deliver、Ack、Redeliver 速率。
- Confirm 延迟、未路由消息和死信。
- 内存水位、磁盘水位、队列类型和节点状态。

### RocketMQ

- Topic 写入和消费 TPS。
- Consumer Offset 与 Broker Offset 差值。
- 最老消息时间、重试和死信 Topic。
- Broker 磁盘、CommitLog、PageCache 和网络。
- Queue 分配、消费者实例和 Rebalance。

排查“消息丢失”时按链路查：生产调用结果、Broker 持久化、路由绑定、消费拉取、业务执行、Ack/Offset 和死信，不要只看应用日志中的“发送成功”。

## 16. 测试与发布

- 使用 Testcontainers 启动真实 Broker 做集成测试。
- 测试重复、乱序、重试、超时、Broker 重启和死信。
- 事件 Schema 向后兼容，新增字段设置默认值。
- 消费者先兼容新旧事件，再发布生产者变更。
- 大规模重放前限制速率，避免冲击数据库和下游。
- Broker、客户端和序列化组件版本通过兼容矩阵验证。

## 17. 面试高频问题

### 17.1 消息如何保证不丢

> 生产者使用 Confirm/发送结果和失败重试，Broker 配置持久化与副本，消费者业务成功后再 Ack 或提交 Offset。数据库与消息发布通过 Outbox 或事务消息连接，消费端使用幂等、死信和对账。任何单个开关都不能独立保证端到端不丢。

### 17.2 如何保证不重复消费

> 不应假设完全不重复，而是使用事件 ID/业务单号做数据库唯一约束，在本地事务内记录消费和业务结果，成功后确认消息。状态机和条件更新可以进一步让操作天然幂等。

### 17.3 RabbitMQ Ack 和 RocketMQ Offset 有什么区别

> RabbitMQ 通过消费者 Ack/Nack 确认 Queue 消息；RocketMQ 通过消费位点和消费结果决定重试与提交。语义不同，但都应在业务成功后确认，失败时进入受控重试或死信。

### 17.4 如何处理消息积压

> 先确认生产速率、消费耗时、失败重试、Queue/分区倾斜和下游容量；再通过批量、扩消费者、限流生产、隔离毒消息和临时降级处理。不能只盲目增加消费者，否则可能压垮数据库。

### 17.5 如何保证顺序消息

> 把同一业务 Key 固定路由到同一 Queue/MessageQueue，并让同一消费链路串行处理；消费者使用版本校验和合法状态迁移。顺序范围通常是一个分片，不是全局顺序。

### 17.6 延迟消息能否精确到秒

> 延迟消息受 Broker 调度粒度、积压和资源影响，只能提供近似时间。消费者必须重新检查业务状态；严格定时或大规模任务应选择任务调度系统。

### 17.7 为什么发送成功但业务没收到

> 发送成功可能只表示 Broker 接收，还要检查 Exchange/Topic 路由、Queue/MessageQueue、消费组、权限、Offset、重试和死信。不同消费组是否订阅同一 Topic 也会影响结果。

### 17.8 RabbitMQ 和 RocketMQ 怎么选

> RabbitMQ 路由灵活、适合工作队列和中小规模低延迟场景；RocketMQ 更强调高吞吐、顺序、延迟和事务消息。最终按消息规模、顺序、延迟、团队运维与云平台能力压测选择。

## 18. 生产检查清单

- [ ] 生产、Broker 持久化、消费确认和失败补偿链路明确。
- [ ] 生产与消费具备幂等，消息 ID 可追踪。
- [ ] 重试有次数、退避和死信，不无限 requeue。
- [ ] 顺序 Key、分区/Queue 数和扩容策略明确。
- [ ] 消息大小、TTL、积压和连接数有限制。
- [ ] 数据库与消息发布使用 Outbox 或可靠事务消息。
- [ ] Broker 磁盘、内存、复制和故障转移有监控。
- [ ] 消费延迟、最老消息和死信有告警。
- [ ] Schema、版本兼容和重放工具经过测试。
