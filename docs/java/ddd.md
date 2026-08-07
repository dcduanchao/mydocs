# DDD 领域驱动设计

## 1. DDD 是什么

领域驱动设计（Domain-Driven Design，DDD）是一套以业务领域模型为中心的软件设计方法。它帮助团队理解复杂业务、划分边界并把规则放进稳定的领域对象，而不是把所有逻辑堆在 Controller 或 Service 中。

DDD 不是必须使用微服务，也不是所有 CRUD 系统都需要完整引入。简单后台优先保持简单；业务规则复杂、多人协作和边界混乱时，DDD 的收益更明显。

```text
业务语言 -> 领域模型 -> 边界上下文 -> 模块/服务 -> 数据和事件
```

## 术语速览

| 名称 | 含义 |
|---|---|
| Domain | 业务问题和规则所在的领域。 |
| Subdomain | 领域中的子域，按业务价值和复杂度划分。 |
| Bounded Context | 统一模型和语言的边界上下文。 |
| Ubiquitous Language | 业务与技术团队共同使用的术语。 |
| Entity | 由身份连续性区分的对象。 |
| Value Object | 由属性值定义、通常不可变的对象。 |
| Aggregate | 事务一致性边界，包含聚合根。 |
| Repository | 以领域语言抽象聚合持久化。 |
| Domain Service | 不自然属于单个实体的领域规则。 |
| Domain Event | 领域中已经发生的业务事实。 |
| Application Service | 编排用例、事务和外部端口。 |
| Anti-Corruption Layer | 防止外部模型污染本领域的适配层。 |

## 2. 战略设计

### 2.1 核心域、支撑域和通用域

| 子域 | 特征 | 建议 |
|---|---|---|
| 核心域 | 形成竞争优势，规则复杂且变化快。 | 投入最强团队和最精细模型。 |
| 支撑域 | 业务需要但不是主要差异化。 | 适度建模，也可采购或复用。 |
| 通用域 | 多数系统都有的能力。 | 优先使用成熟组件或平台。 |

订单定价、风控策略可能是核心域；用户登录、通知、文件存储可能是支撑或通用域，具体取决于业务。

### 2.2 统一语言

同一个词在不同上下文可能含义不同。例如“用户”在认证上下文是身份主体，在营销上下文可能是会员，在支付上下文可能是付款人。不要强行维护一个跨全系统的万能 User 对象。

统一语言通过事件风暴、用例讨论、业务规则和代码命名持续演进。术语冲突是边界设计信号，不是简单的命名问题。

### 2.3 事件风暴

以业务事件为中心梳理流程：

```text
用户下单 -> 订单已创建 -> 库存已预占 -> 支付已完成
    命令          事件           事件          事件
```

过程：

1. 列出过去发生的领域事件。
2. 找到触发事件的命令和参与者。
3. 识别聚合、策略、外部系统和异常分支。
4. 按业务语言聚类，发现边界上下文。
5. 记录不同团队对同一词的定义。

事件风暴不是画完流程图就结束，必须沉淀为用例、状态机、API、事件契约和验收测试。

## 3. Bounded Context

Bounded Context 是模型有效的边界，而不是简单的 Java Package 或数据库 Schema。一个上下文内部的实体、状态和规则应该使用一致语言；跨上下文通过 API、事件或防腐层协作。

```text
订单上下文：Order = 购买意图和履约状态
支付上下文：Payment = 收款、退款和渠道状态
库存上下文：Inventory = 可售、预占和已扣减数量
```

上下文之间的关系：

- Customer/Supplier：一方提供契约，另一方依赖。
- Conformist：下游直接遵循上游模型，适用于上游稳定且自身不重要。
- Anti-Corruption Layer：适配外部模型，保护内部语言。
- Open Host Service：通过公开稳定协议提供能力。
- Published Language：使用双方共同理解的事件或协议。

### 3.1 防腐层

```java
// 外部支付 SDK 的模型不能直接进入订单领域
public final class PaymentGatewayAdapter
        implements PaymentPort {
    private final ExternalPaymentClient client;

    @Override
    public PaymentResult pay(PaymentCommand command) {
        ExternalResult result = client.charge(toExternal(command));
        return toDomain(result);
    }
}
```

适配器负责协议、字段和错误映射。不要把外部 SDK 的状态枚举、异常和 DTO 直接暴露给领域核心。

## 4. 实体与值对象

### 4.1 Entity

实体由稳定身份区分，即使属性变化仍是同一个业务对象。

```java
public class Order {
    private final OrderId id;
    private OrderStatus status;

    public void markPaid(PaymentId paymentId) {
        if (status != OrderStatus.CREATED) {
            throw new InvalidOrderStateException(status);
        }
        this.status = OrderStatus.PAID;
    }
}
```

调用方不能直接修改 `status`，状态迁移必须经过领域方法，才能集中校验规则和发布事件。

### 4.2 Value Object

值对象由属性定义，通常不可变并具有值相等性：

```java
public record Money(BigDecimal amount, Currency currency) {
    public Money {
        if (amount.signum() < 0) {
            throw new IllegalArgumentException("amount must be non-negative");
        }
        amount = amount.setScale(2, RoundingMode.HALF_UP);
    }

    public Money add(Money other) {
        if (!currency.equals(other.currency)) {
            throw new IllegalArgumentException("currency mismatch");
        }
        return new Money(amount.add(other.amount), currency);
    }
}
```

Email、Money、Address、OrderId、TimeRange 等适合值对象。它们把格式、范围、单位和相等性约束放在一个地方，减少散落的字符串和数字。

## 5. 聚合与聚合根

聚合是事务一致性边界，外部只能通过聚合根访问内部对象。

```text
Order（聚合根）
  -> OrderItem
  -> ShippingAddress
```

```java
public class Order {
    private final List<OrderItem> items = new ArrayList<>();

    public void addItem(ProductId productId, int quantity, Money price) {
        if (quantity <= 0) {
            throw new IllegalArgumentException("quantity must be positive");
        }
        items.add(new OrderItem(productId, quantity, price));
    }

    public List<OrderItem> items() {
        return List.copyOf(items);
    }
}
```

### 5.1 聚合设计原则

- 一个事务尽量只修改一个聚合。
- 聚合根保护不变量，内部集合不直接暴露可变引用。
- 聚合之间通过 ID 引用，而不是对象嵌套。
- 聚合大小由一致性规则决定，不是按数据库表关系决定。
- 高并发场景下避免把所有资源放进一个超级聚合。

库存和订单可以分别是聚合。下单时订单创建与库存预占通过事件或 Saga 协调，而不是在一个巨大对象和跨库事务中强行完成。

### 5.2 聚合并发控制

```sql
UPDATE orders
SET status = ?, version = version + 1
WHERE id = ? AND version = ?;
```

版本不匹配时返回冲突，应用决定重读、合并、重试或拒绝。聚合内不变量可以使用乐观锁；极高冲突场景需要队列串行化或数据库锁。

## 6. 领域服务与应用服务

### 6.1 Domain Service

领域服务承载重要业务规则，但该规则无法自然归属于单一实体或值对象：

```java
public class PricingService {
    public Money quote(Order order, Customer customer, Campaign campaign) {
        // 组合会员、活动、商品和订单规则
        return calculate(order, customer, campaign);
    }
}
```

领域服务应保持领域语言，不直接依赖 Controller、HTTP、ORM Session 或消息 Broker。需要外部数据时通过领域端口注入。

### 6.2 Application Service

应用服务编排用例，不应该承载所有业务判断：

```java
@ApplicationService
public class CreateOrderHandler {
    private final OrderRepository orders;
    private final InventoryPort inventory;
    private final UnitOfWork unitOfWork;

    @Transactional
    public OrderId handle(CreateOrderCommand command) {
        Order order = Order.create(command.orderId(), command.customerId());
        order.addItem(command.productId(), command.quantity(), command.price());
        orders.save(order);
        order.recordEvent(new OrderCreated(order.id()));
        return order.id();
    }
}
```

应用服务可以管理事务、权限、幂等和端口调用，但复杂规则应委托给聚合或领域服务。

## 7. Repository 与持久化

领域层只依赖接口：

```java
public interface OrderRepository {
    Optional<Order> findById(OrderId id);
    void save(Order order);
}
```

基础设施层实现：

```java
@Repository
class MyBatisOrderRepository implements OrderRepository {
    private final OrderMapper mapper;
}
```

Repository 以聚合为单位提供持久化，不应变成暴露任意 SQL 的通用 DAO。查询报表和复杂列表可以使用专门的 Query Service，不必强行还原为领域聚合。

### 7.1 ORM 映射边界

领域对象和数据库 Entity 不一定必须是同一个类。规则复杂、生命周期不同或需要防止 ORM 侵入时，使用 Mapper 在两者之间转换。简单 CRUD 可以共享部分模型，但要评估懒加载、可变字段和持久化代理对领域行为的影响。

## 8. 领域事件

领域事件描述已经发生的事实，使用过去时命名：

```java
public record OrderCreated(
        OrderId orderId,
        CustomerId customerId,
        Instant occurredAt) {
}
```

事件设计：

- 事件不可随意修改历史语义。
- 包含消费者完成工作所需的最小稳定数据。
- 带事件 ID、聚合 ID、版本和发生时间。
- 不把数据库 Entity 或内部堆栈直接序列化。
- 事件消费者必须幂等并能处理重复。

### 8.1 领域事件与集成事件

领域事件是内部模型概念；集成事件是跨上下文公开的契约。两者可以相同，但复杂系统通常通过转换和版本化隔离内部变化。

```text
OrderCreated（领域事件）
  -> Outbox Mapper
  -> order.v1.created（集成事件）
```

事务提交后的事件发送使用 Outbox 或可靠消息机制，不能只在内存中发布后就认为下游一定收到。

## 9. CQRS

CQRS 将写模型和读模型分开：

```text
Command -> 聚合/写库 -> 领域事件 -> 查询投影
Query   -> 读模型/搜索索引
```

适合写规则复杂、读模型差异大、需要独立扩展的场景。CQRS 不等于必须拆数据库或使用消息队列，简单系统也可以只在代码层区分 Command 和 Query。

读模型通常最终一致，界面需要展示“数据同步中”或在写后读关键路径短暂读取写库。投影必须可重放、可重建并记录消费位点。

## 10. Event Sourcing

Event Sourcing 以事件序列作为事实数据源，通过重放事件得到当前状态：

```text
OrderCreated -> ItemAdded -> PaymentConfirmed
             -> 重放 -> 当前 Order 状态
```

优点是完整历史和可重放；代价是事件 Schema 演进、查询投影、重放速度、隐私删除和运维复杂度。使用领域事件不等于使用 Event Sourcing，大多数系统只需要普通状态表 + Outbox。

## 11. 领域异常与规则

领域异常表达业务规则失败：

```java
public void cancel() {
    if (!status.canCancel()) {
        throw new OrderCannotBeCancelledException(id, status);
    }
    status = OrderStatus.CANCELLED;
}
```

异常应携带稳定错误码和必要业务上下文。不要把数据库异常、HTTP 状态码和 JSON 格式直接放进领域层。应用层负责把领域异常转换成 API 错误或消息重试策略。

## 12. 分层架构

```text
interfaces
  -> application
      -> domain
  -> infrastructure
```

- Interfaces：HTTP、消息、CLI、DTO 和协议转换。
- Application：用例、事务、权限、幂等和端口编排。
- Domain：实体、值对象、聚合、领域服务和事件。
- Infrastructure：数据库、缓存、消息、远程客户端和框架实现。

依赖方向指向 Domain。Domain 不依赖 Spring、MyBatis、Redis、HTTP 和数据库。小项目不必机械拆成多个 Maven 模块，但要保持依赖边界。

## 13. 依赖倒置与端口适配器

```java
public interface PaymentPort {
    PaymentResult charge(PaymentCommand command);
}

@Component
class PaymentHttpAdapter implements PaymentPort {
    private final WebClient client;
}
```

领域或应用层依赖 `PaymentPort`，基础设施层提供 HTTP、消息或测试 Fake 实现。端口不是为了增加接口数量，而是为了隔离变化和支持替换、测试。

## 14. 状态机

订单状态迁移应显式定义：

```text
CREATED -> PAID -> SHIPPED -> COMPLETED
   |         |
   v         v
CANCELLED  REFUNDING -> REFUNDED
```

```java
public boolean canTransitionTo(OrderStatus target) {
    return switch (this) {
        case CREATED -> target == PAID || target == CANCELLED;
        case PAID -> target == SHIPPED || target == REFUNDING;
        case SHIPPED -> target == COMPLETED;
        case COMPLETED, CANCELLED, REFUNDED -> false;
        case REFUNDING -> target == REFUNDED;
    };
}
```

事件重复或乱序时，按版本、状态和幂等记录校验。不要用一堆 `if` 让每个调用方自行判断迁移规则。

## 15. DDD 与微服务

Bounded Context 可以映射为模块，也可以映射为服务；不是一一对应。拆成服务前确认：

- 是否需要独立发布和扩缩容。
- 是否拥有独立数据和团队。
- 网络调用的延迟与失败是否可接受。
- 最终一致和运维成本是否值得。

共享数据库表会弱化边界，跨服务分布式事务会放大复杂度。优先用领域事件、Outbox、Saga 和对账建立可接受的一致性。

## 16. DDD 与 Spring 实现

Spring 注解可以作为技术适配，但不应成为领域模型的全部：

```java
public final class Order {
    // 不依赖 Spring 的核心业务行为
}

@Service
class CreateOrderApplicationService {
    // 事务与用例编排
}

@RestController
class OrderController {
    // HTTP DTO 与应用服务转换
}
```

领域对象需要持久化时，可使用构造器、Factory、Mapper 或专门的 ORM 映射，不要为了让框架反射而开放所有 Setter。

## 17. DDD 测试

### 17.1 领域单元测试

领域测试不启动 Spring、不连接数据库：

```java
@Test
void shouldRejectPaymentAfterCancellation() {
    Order order = OrderFixture.cancelled();

    assertThrows(InvalidOrderStateException.class,
            () -> order.markPaid(new PaymentId("p-1")));
}
```

### 17.2 应用测试

Mock Repository、消息端口和外部服务，验证事务边界、幂等和命令编排。不要把所有领域规则重新测试一遍。

### 17.3 集成测试

使用真实数据库验证映射、唯一约束、锁和 Outbox；使用 Broker 验证事件契约、重复、重试和死信。

## 18. 迁移到 DDD

不要一次性重写整个系统：

1. 选择业务价值高且边界痛点明显的用例。
2. 通过事件风暴和规则梳理建立术语。
3. 在现有单体中增加模块边界和应用服务。
4. 抽出值对象和聚合不变量，减少贫血逻辑。
5. 以 Anti-Corruption Layer 连接旧模块。
6. 用 Outbox 和事件同步新旧模型。
7. 用指标验证发布速度、缺陷和变更影响，再决定是否拆服务。

DDD 的成功标准是业务规则更清晰、变更更可控，不是类数量或目录层级变多。

## 19. 常见误区

- 把所有表都建成一个实体，把 Getter/Setter 当领域模型。
- 一个聚合包含整个订单、库存、用户和支付，形成超级事务。
- 一个服务对应一个表，按技术层机械拆分。
- 领域层直接注入 Repository 实现、Mapper 和 HTTP Client。
- 领域事件直接当作可随意修改的内部 DTO。
- 为了“最终一致”给所有操作都加消息，忽略查询简单性。
- 用 `@Transactional` 包住跨服务 HTTP 调用假装获得分布式事务。
- 认为 CQRS 或 Event Sourcing 是 DDD 的必选项。

## 20. 面试高频问题

### 20.1 DDD 解决什么问题

> DDD 通过统一语言、领域模型和边界上下文处理复杂业务规则和团队协作问题。它让关键规则进入实体、值对象和聚合，而不是散落在 Controller、脚本和数据库触发器中。简单 CRUD 不必强行使用完整 DDD。

### 20.2 Entity 和 Value Object 区别

> Entity 由稳定身份和生命周期区分，属性可以变化；Value Object 由属性值定义，通常不可变并按值相等。订单是 Entity，金额、地址和邮箱更适合 Value Object。

### 20.3 聚合是什么

> 聚合是一致性和事务边界，聚合根对外提供操作并保护内部不变量。外部通过 ID 引用其他聚合，避免跨聚合大事务和对象图无限扩张。

### 20.4 聚合应该多大

> 由必须在同一事务中保持的不变量决定，而不是由表关系决定。聚合过大降低并发、增加锁和加载成本；过小则规则无法一起保证。高并发资源通常拆成独立聚合并通过事件或流程协调。

### 20.5 Domain Service 和 Application Service 区别

> Domain Service 表达不自然属于单一实体但属于领域的业务规则；Application Service 编排用例、事务、权限和外部端口，不应承载大量核心规则。

### 20.6 领域事件和集成事件有什么区别

> 领域事件是上下文内部已经发生的业务事实；集成事件是跨上下文公开的稳定契约。两者可以相同，但通过转换和版本化隔离内部模型变化更安全。

### 20.7 DDD 如何处理跨聚合一致性

> 一个聚合内用本地事务保证强一致，跨聚合通常通过领域事件、Outbox、Saga 或 TCC 实现最终一致。只有范围小、事务短且基础设施明确支持时才评估 XA。

### 20.8 DDD、微服务和 CQRS 是什么关系

> DDD 是建模和边界方法；微服务是部署和运行架构；CQRS 是读写模型分离模式。它们可以组合，但都不是 DDD 的必选项。

### 20.9 贫血模型有什么问题

> 贫血模型只有字段和 Getter/Setter，规则散落在多个 Service，容易重复和绕过约束。但对于简单数据查询并非错误。应把复杂不变量放进模型，把纯数据传输对象保持简单。

## 21. 生产检查清单

- [ ] 业务术语、子域和上下文边界有团队共识。
- [ ] 核心规则由聚合/值对象保护，而不是依赖调用方自觉。
- [ ] 聚合大小符合事务和并发边界。
- [ ] 领域层不依赖 Spring、数据库和远程协议。
- [ ] Repository 以聚合为单位，查询模型与写模型可分离。
- [ ] 领域事件、集成事件和 Schema 版本明确。
- [ ] Outbox、幂等、补偿和对账流程可执行。
- [ ] 跨上下文依赖通过 API、事件或防腐层隔离。
- [ ] 领域单元测试覆盖状态机和不变量。
- [ ] 不为追求 DDD 而引入不必要的微服务和分布式事务。
