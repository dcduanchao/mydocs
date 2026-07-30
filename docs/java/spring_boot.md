# Spring 与 Spring Boot 核心原理

## 1. Spring 与 Spring Boot 是什么

Spring Framework 提供 IoC、依赖注入、AOP、事务、Web MVC、数据访问等基础能力。Spring Boot 在 Spring Framework 之上提供自动配置、Starter、外部化配置、内嵌 Web 容器和生产运维能力，让应用能够快速启动并以统一方式交付。

```text
Spring Framework：应用容器和基础编程模型
Spring Boot：自动装配、依赖管理、启动方式和生产能力
```

Spring Boot 3 基于 Spring Framework 6，使用 `jakarta.*` 命名空间，并要求 Java 17 或更高版本。新项目通常直接使用当前受支持的 Spring Boot 3.x 版本，并让 Spring Boot 管理 Spring 组件的兼容版本。

Spring Boot 不是代码生成器，也没有绕过 Spring。自动配置最终仍然是向 IoC 容器注册 Bean，只是根据类路径、配置项和已有 Bean 自动决定注册哪些组件。

## 术语速览

| 名称 | 含义 |
|---|---|
| IoC | 控制反转，对象创建和依赖关系由容器管理。 |
| DI | 依赖注入，容器把依赖对象传给 Bean。 |
| Bean | 由 Spring 容器创建、配置和管理的对象。 |
| AOP | 面向切面编程，在方法调用周围增加事务、日志等行为。 |
| Proxy | 代理对象，拦截调用后执行增强逻辑。 |
| ApplicationContext | Spring 高级容器，包含 BeanFactory 和事件、资源等能力。 |
| Starter | 聚合某类功能所需依赖的启动依赖。 |
| Auto-configuration | 根据条件自动注册 Bean 的配置。 |
| Actuator | 健康检查、指标和管理端点。 |
| Environment | 保存配置属性、Profile 和属性源的抽象。 |

## 2. IoC 与依赖注入

### 2.1 BeanFactory 和 ApplicationContext

`BeanFactory` 是 IoC 容器的基础接口，负责 Bean 定义、创建和获取。`ApplicationContext` 在其基础上增加：

- 国际化消息。
- 应用事件发布。
- Resource 资源加载。
- Environment 和 Profile。
- 自动注册 BeanPostProcessor、BeanFactoryPostProcessor。
- 与 Spring AOP、Web 和其他模块集成。

实际业务应用通常使用 `ApplicationContext`，而不是直接创建 `BeanFactory`。

### 2.2 注册 Bean

组件扫描：

```java
@Service
public class OrderService {
}

@Repository
public class OrderRepository {
}
```

Java 配置：

```java
@Configuration(proxyBeanMethods = false)
public class ClientConfiguration {

    @Bean
    public PaymentClient paymentClient(PaymentProperties properties) {
        return new PaymentClient(properties.baseUrl(), properties.timeout());
    }
}
```

第三方类无法添加 `@Component` 时使用 `@Bean`。`proxyBeanMethods = false` 可以避免为配置类创建 CGLIB 代理，适合各 `@Bean` 方法不通过直接调用表达依赖的配置。

### 2.3 构造器注入

```java
@Service
public class OrderService {
    private final OrderRepository orderRepository;
    private final PaymentClient paymentClient;

    public OrderService(OrderRepository orderRepository,
                        PaymentClient paymentClient) {
        this.orderRepository = orderRepository;
        this.paymentClient = paymentClient;
    }
}
```

构造器注入的优点：

- 依赖明确，并且可以声明为 `final`。
- 对象创建完成后处于可用状态。
- 单元测试可以直接传入替身对象。
- 循环依赖会在启动时暴露，而不是隐藏设计问题。

只有一个构造器时不需要写 `@Autowired`。不推荐字段注入，因为它隐藏依赖、难以测试且不能使用 `final`。

### 2.4 多个候选 Bean

```java
public interface MessageSender {
    void send(String message);
}

@Primary
@Component
class SmsSender implements MessageSender {
    @Override
    public void send(String message) {
        // 调用短信服务
    }
}

@Component("emailSender")
class EmailSender implements MessageSender {
    @Override
    public void send(String message) {
        // 调用邮件服务
    }
}
```

使用 `@Primary` 指定默认实现，使用 `@Qualifier("emailSender")` 精确选择。需要全部实现时可以注入 `List<MessageSender>` 或 `Map<String, MessageSender>`，Spring 会收集匹配 Bean。

## 3. Bean 生命周期

单例 Bean 的典型生命周期：

```text
读取 BeanDefinition
  -> 实例化
  -> 属性填充
  -> Aware 回调
  -> BeanPostProcessor before initialization
  -> @PostConstruct
  -> InitializingBean.afterPropertiesSet
  -> 自定义 initMethod
  -> BeanPostProcessor after initialization
  -> Bean 可用
  -> @PreDestroy
  -> DisposableBean.destroy
  -> 自定义 destroyMethod
```

示例：

```java
@Component
public class RuleCache {

    @PostConstruct
    public void load() {
        // 初始化轻量、可失败且可观测的资源
    }

    @PreDestroy
    public void close() {
        // 停止任务并释放资源
    }
}
```

Spring Boot 3 使用 `jakarta.annotation.PostConstruct` 和 `jakarta.annotation.PreDestroy`。

不要在构造器或 `@PostConstruct` 中执行不可控的长时间远程调用。它会阻塞应用启动，也可能在依赖服务短暂不可用时让整个应用无法启动。必要时使用带超时的初始化、`ApplicationRunner`、应用就绪事件或后台预热，并明确失败策略。

### 3.1 BeanPostProcessor

BeanPostProcessor 可以在 Bean 初始化前后修改或包装 Bean。AOP 自动代理就是重要应用之一：容器在初始化后返回代理对象，调用者实际拿到的可能不再是原始对象。

```text
原始 OrderService
  -> BeanPostProcessor 判断是否需要增强
  -> 创建代理对象
  -> 容器对外提供 OrderService Proxy
```

这解释了为什么事务、缓存和 `@Async` 依赖代理调用，也解释了为什么类内部的 `this.method()` 经常绕过增强。

### 3.2 Bean Scope

| Scope | 含义 |
|---|---|
| `singleton` | 每个 ApplicationContext 一份实例，默认。 |
| `prototype` | 每次从容器获取时创建新实例。 |
| `request` | 每个 HTTP 请求一个实例。 |
| `session` | 每个 HTTP Session 一个实例。 |
| `application` | 每个 ServletContext 一个实例。 |

Spring 单例不等于进程级单例，多 ApplicationContext 会各自创建实例。Spring 也不会自动保证单例 Bean 线程安全；单例 Service 应尽量无状态，避免将请求数据保存到成员变量。

Prototype Bean 的销毁生命周期不由容器完整管理，持有外部资源时需要调用方负责释放。

## 4. 循环依赖

```text
OrderService -> PaymentService -> OrderService
```

构造器循环依赖无法创建对象。部分单例 Setter/字段循环依赖在 Spring Framework 内部可以借助提前引用处理，但这不是推荐设计，并且 Spring Boot 默认禁止循环引用。

所谓“三级缓存”是 DefaultSingletonBeanRegistry 在创建单例时保存成品对象、早期对象和对象工厂的内部机制。对象工厂使 Spring 有机会提前暴露与最终代理一致的引用。它只解决特定单例创建场景，不能解决：

- 构造器循环依赖。
- Prototype 循环依赖。
- 跨 ApplicationContext 的循环。
- 所有涉及复杂代理和初始化顺序的循环。

解决循环依赖的正确方向：

- 提取双方共同依赖的第三个服务。
- 重新划分职责，避免双向调用。
- 使用领域事件解除同步依赖。
- 确有延迟获取需求时使用 `ObjectProvider<T>`。

`@Lazy` 可能推迟问题，但也可能把启动期错误变成运行期错误，不应作为默认解决方案。开启 `spring.main.allow-circular-references=true` 只能作为遗留系统短期过渡。

## 5. AOP 与动态代理

### 5.1 AOP 概念

| 概念 | 含义 |
|---|---|
| Aspect | 切面，例如日志或权限检查。 |
| Join Point | 可被增强的连接点，Spring AOP 主要是方法执行。 |
| Pointcut | 选择哪些方法需要增强。 |
| Advice | 在方法之前、之后或周围执行的逻辑。 |
| Target | 被代理的原始对象。 |
| Proxy | 对外提供的增强对象。 |

```java
@Aspect
@Component
public class TimingAspect {

    @Around("@annotation(Monitored)")
    public Object measure(ProceedingJoinPoint point) throws Throwable {
        long start = System.nanoTime();
        try {
            return point.proceed();
        } finally {
            long elapsed = System.nanoTime() - start;
            // 写入指标，不记录敏感参数
        }
    }
}
```

### 5.2 JDK Proxy 和 CGLIB

| 方式 | 原理 | 主要限制 |
|---|---|---|
| JDK Dynamic Proxy | 实现目标接口 | 通过接口类型代理。 |
| CGLIB | 生成目标类子类 | `final` 类和 `final/private` 方法不能被覆盖增强。 |

Spring Boot 通常默认使用基于类的代理。无论哪种代理，只有经过代理对象的调用才能触发 Advice。

### 5.3 自调用失效

```java
@Service
public class OrderService {

    public void createOrder() {
        this.saveOrder(); // 直接调用当前对象，没有经过代理
    }

    @Transactional
    public void saveOrder() {
    }
}
```

`this.saveOrder()` 不经过 Spring Proxy，因此事务不会按预期创建。推荐将事务方法移动到另一个职责明确的 Bean，通过依赖注入调用。不要默认使用 `AopContext.currentProxy()`，它增加耦合并让调用关系难以测试。

Spring AOP 是代理式方法拦截，不等于完整 AspectJ 字节码织入。构造器、普通字段访问和对象内部调用不会自动被 Spring AOP 增强。

## 6. Spring 事务

### 6.1 基本使用

```java
@Service
public class OrderApplicationService {
    private final OrderRepository orderRepository;
    private final OutboxRepository outboxRepository;

    @Transactional
    public long create(CreateOrderCommand command) {
        Order order = Order.create(command);
        orderRepository.save(order);
        outboxRepository.save(OrderCreatedEvent.from(order));
        return order.id();
    }
}
```

事务边界通常放在应用服务的公开业务方法上，使一次业务操作中的多个数据库写入共同提交或回滚。

### 6.2 传播行为

| Propagation | 行为 |
|---|---|
| `REQUIRED` | 有事务就加入，没有就新建，默认。 |
| `REQUIRES_NEW` | 挂起外层事务，始终创建独立事务。 |
| `NESTED` | 使用保存点嵌套执行，需要数据库和事务管理器支持。 |
| `SUPPORTS` | 有事务就加入，没有则非事务执行。 |
| `MANDATORY` | 必须在现有事务中执行，否则抛错。 |
| `NOT_SUPPORTED` | 挂起现有事务，以非事务方式执行。 |
| `NEVER` | 存在事务时抛错。 |

`REQUIRES_NEW` 会额外占用数据库连接。外层事务持有连接并等待内层事务取新连接时，连接池过小可能耗尽。它也不能保证外层和内层同时成功，只适合确实需要独立提交的操作。

`NESTED` 不等于 `REQUIRES_NEW`，它通常依赖同一物理事务中的保存点，外层整体回滚时嵌套结果也会回滚。

### 6.3 隔离级别

Spring 的 Isolation 最终由数据库实现。常见级别：

- `READ_UNCOMMITTED`：可能脏读。
- `READ_COMMITTED`：避免脏读。
- `REPEATABLE_READ`：同一事务中重复读取结果更稳定。
- `SERIALIZABLE`：隔离最强，并发代价最高。
- `DEFAULT`：使用数据库默认级别。

不能只看注解名称判断幻读、锁和 MVCC 行为，必须结合具体数据库版本、索引和 SQL。

### 6.4 回滚规则

默认情况下，运行时异常和 Error 触发回滚，受检异常不会自动回滚。

```java
@Transactional(rollbackFor = Exception.class)
public void importData() throws IOException {
}
```

不要为了省事在所有方法上机械添加 `rollbackFor = Exception.class`。应明确业务异常体系和事务语义。

### 6.5 常见事务失效

| 场景 | 原因 |
|---|---|
| 同类方法使用 `this` 调用 | 绕过代理。 |
| `private` 或 `static` 方法 | 代理无法拦截。 |
| CGLIB 目标方法为 `final` | 子类代理无法覆盖。 |
| 异常被捕获后未重新抛出 | 代理看到方法正常返回。 |
| 抛出受检异常但未配置回滚 | 不符合默认回滚规则。 |
| 对象由 `new` 创建 | 对象不在 Spring 容器中。 |
| 在新线程或 `@Async` 中执行 | 事务上下文绑定当前线程，不会自动传播。 |
| 使用错误的 TransactionManager | 数据源与事务管理器不匹配。 |

JDK Dynamic Proxy 只能代理接口公开方法。Spring 6 的类代理可以拦截 `public`、`protected` 和包可见方法，但不能拦截 `private`、`static` 或 `final` 方法。为了让事务边界清晰且不依赖代理实现，业务事务方法通常仍设计为 `public`。

```java
@Transactional
public void create() {
    try {
        repository.save(entity);
    } catch (RuntimeException e) {
        log.warn("save failed", e);
        // 未重新抛出，事务可能提交
    }
}
```

如果内部方法把事务标记为 Rollback Only，而外层捕获异常后继续正常返回，提交时可能得到 `UnexpectedRollbackException`。这不是 Spring 随机失败，而是调用方试图提交一个已经决定回滚的事务。

### 6.6 事务边界

- 事务内避免长时间 HTTP/RPC 调用，防止长期占用连接和数据库锁。
- 不要在数据库事务提交前发送无法撤回的消息。
- 数据库和 Kafka、Redis、ES 之间不是同一个本地事务。
- 跨系统一致性优先使用 Outbox、消息重试、幂等和补偿。
- 事务完成后的动作可使用 `@TransactionalEventListener(phase = AFTER_COMMIT)`，但仍要处理进程崩溃导致事件未执行的问题。

强可靠事件不能只依赖内存中的 Spring Event，应该落库后再异步投递。

## 7. Spring Boot 自动配置

### 7.1 @SpringBootApplication

```java
@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

它主要组合了：

- `@SpringBootConfiguration`：标识 Boot 配置类。
- `@EnableAutoConfiguration`：启用自动配置。
- `@ComponentScan`：从启动类所在包向下扫描组件。

启动类应放在业务根包，避免漏扫组件。不要无边界扫描整个公司包或第三方包，会拖慢启动并引入意外 Bean。

### 7.2 自动配置加载

Spring Boot 3 的自动配置类通常通过以下文件声明：

```text
META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
```

自动配置类使用条件注解决定是否生效：

```java
@AutoConfiguration
@ConditionalOnClass(PaymentClient.class)
@ConditionalOnProperty(
        prefix = "payment",
        name = "enabled",
        havingValue = "true")
public class PaymentAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    PaymentClient paymentClient(PaymentProperties properties) {
        return new PaymentClient(properties.baseUrl());
    }
}
```

常用条件：

| 注解 | 条件 |
|---|---|
| `@ConditionalOnClass` | 类路径存在指定类。 |
| `@ConditionalOnMissingClass` | 类路径不存在指定类。 |
| `@ConditionalOnBean` | 容器中存在指定 Bean。 |
| `@ConditionalOnMissingBean` | 用户没有自定义指定 Bean。 |
| `@ConditionalOnProperty` | 配置项满足条件。 |
| `@ConditionalOnWebApplication` | 当前是指定类型的 Web 应用。 |

`@ConditionalOnMissingBean` 是“用户配置优先”的关键：业务方自己提供 Bean 后，默认自动配置会后退。

### 7.3 排查自动配置

启动时添加 `--debug` 或配置：

```yaml
debug: true
```

Condition Evaluation Report 会显示哪些自动配置匹配、哪些未匹配以及原因。排查“为什么没有创建 Bean”时，应先看条件报告和 Bean 列表，而不是反复添加扫描路径。

## 8. 外部化配置

### 8.1 ConfigurationProperties

```java
@ConfigurationProperties(prefix = "payment")
@Validated
public record PaymentProperties(
        @NotBlank String baseUrl,
        @NotNull Duration timeout,
        @Min(1) int maxConnections) {
}
```

```yaml
payment:
  base-url: https://payment.internal
  timeout: 2s
  max-connections: 100
```

与大量分散的 `@Value` 相比，`@ConfigurationProperties` 支持类型转换、校验、元数据和集中管理，更适合一组相关配置。

配置类可通过 `@ConfigurationPropertiesScan` 扫描，或使用 `@EnableConfigurationProperties(PaymentProperties.class)` 注册。

### 8.2 Profile

```yaml
# application.yml
spring:
  application:
    name: order-service

---
spring:
  config:
    activate:
      on-profile: dev
logging:
  level:
    com.example.order: debug
```

Profile 用于环境差异，不应承载复杂业务开关。生产密码、Token 和证书放入密钥管理系统或受控环境变量，不要写入 `application-prod.yml` 后提交。

### 8.3 配置优先级

Spring Boot 有多种 PropertySource，命令行、系统属性、环境变量、外部配置文件和包内配置文件之间存在优先级。排查配置未生效时检查：

- 实际激活的 Profile。
- 环境变量名称转换。
- 配置文件加载位置。
- 配置中心是否覆盖本地值。
- Actuator `env` 和 `configprops` 端点，但必须保护敏感数据。

不要依赖记忆解决所有优先级问题，应从启动日志和 Environment 实际值验证。

## 9. Spring MVC 请求流程

```text
客户端
  -> Servlet Filter
  -> DispatcherServlet
  -> HandlerMapping
  -> HandlerInterceptor.preHandle
  -> HandlerAdapter
  -> Controller
  -> Service
  -> 返回值处理与 HttpMessageConverter
  -> HandlerInterceptor.afterCompletion
  -> Servlet Filter
  -> 客户端
```

### 9.1 Filter、Interceptor 和 AOP

| 机制 | 所在层次 | 典型用途 |
|---|---|---|
| Filter | Servlet 容器 | 请求包装、CORS、Trace、基础安全。 |
| HandlerInterceptor | Spring MVC | 登录上下文、接口权限、控制器耗时。 |
| AOP | Spring Bean 方法 | 事务、业务审计、方法级指标。 |

Filter 可以处理尚未进入 DispatcherServlet 的请求；Interceptor 能获取 Handler 信息；AOP 不应该替代 HTTP 层协议处理。

### 9.2 参数校验

```java
public record CreateOrderRequest(
        @NotNull Long userId,
        @NotEmpty List<@Valid OrderItemRequest> items) {
}

@RestController
@RequestMapping("/orders")
public class OrderController {

    @PostMapping
    public OrderResponse create(@Valid @RequestBody CreateOrderRequest request) {
        return orderService.create(request);
    }
}
```

方法参数校验可使用 Spring Framework 的方法校验能力。校验只保证输入格式和局部约束，库存、权限和状态流转仍属于业务规则。

### 9.3 统一异常处理

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(OrderNotFoundException.class)
    ResponseEntity<ProblemDetail> handleNotFound(OrderNotFoundException ex) {
        ProblemDetail detail = ProblemDetail.forStatus(HttpStatus.NOT_FOUND);
        detail.setTitle("Order not found");
        detail.setDetail(ex.getMessage());
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(detail);
    }
}
```

不要把所有异常都返回 HTTP 200，也不要将堆栈、SQL、内部主机名直接暴露给客户端。响应中使用稳定错误码和 Trace ID，详细异常只记录在服务端。

### 9.4 HttpMessageConverter

`@RequestBody` 和响应对象通常由 Jackson Converter 在 JSON 与 Java 对象之间转换。应统一日期、时区、枚举和未知字段策略，避免每个接口自行格式化。

不要直接将 JPA Entity 或持久化对象作为外部 API 响应，防止懒加载、循环引用和内部字段泄露。使用明确的 Request/Response DTO。

## 10. MVC 与 WebFlux

| 对比项 | Spring MVC | Spring WebFlux |
|---|---|---|
| 模型 | Servlet，一请求一执行线程为主 | Reactive、事件循环和非阻塞流 |
| 常用客户端 | JDBC、阻塞 HTTP Client | R2DBC、WebClient 等非阻塞组件 |
| 适合场景 | 普通业务、阻塞式依赖 | 高并发流式处理、端到端非阻塞 |
| 编程复杂度 | 较低 | 需要理解 Reactor、背压和上下文 |

WebFlux 中混入阻塞 JDBC 或文件 I/O 会阻塞事件循环。需要临时兼容时应切换到有界调度器，但长期方案是端到端非阻塞或直接使用 MVC 配合虚拟线程。

不要仅因为“并发高”就选择 WebFlux。团队能力、依赖驱动、调用链和延迟目标比框架名称更重要。

## 11. 异步任务与线程池

### 11.1 @Async

```java
@Configuration(proxyBeanMethods = false)
@EnableAsync
public class AsyncConfiguration {

    @Bean("notificationExecutor")
    public ThreadPoolTaskExecutor notificationExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);
        executor.setMaxPoolSize(16);
        executor.setQueueCapacity(500);
        executor.setThreadNamePrefix("notification-");
        executor.setRejectedExecutionHandler(
                new ThreadPoolExecutor.CallerRunsPolicy());
        return executor;
    }
}
```

```java
@Async("notificationExecutor")
public CompletableFuture<Void> sendNotification(long orderId) {
    notificationClient.send(orderId);
    return CompletableFuture.completedFuture(null);
}
```

常见问题：

- 同类 `this` 调用绕过代理，`@Async` 不生效。
- 新线程不继承调用线程的事务上下文。
- `void` 返回值的异常无法由调用方接收，需要配置异常处理器。
- MDC、Trace、安全上下文和租户信息不会自动完整传播。
- 无界队列会积压任务，应配置容量、拒绝策略和指标。

需要可靠执行的任务不能只依赖进程内 `@Async`。进程重启会丢失尚未持久化的任务，应使用消息队列或任务表。

### 11.2 定时任务

```java
@Scheduled(cron = "0 */5 * * * *", zone = "Asia/Shanghai")
public void reconcile() {
}
```

多实例部署时每个实例都会执行 `@Scheduled`。只允许一个实例运行时，需要数据库锁、Redis 锁、调度平台或分片任务机制。任务必须幂等，并设置超时、批次上限和执行指标。

## 12. Spring Boot 虚拟线程

Java 21+ 和 Spring Boot 3.2+ 可以启用虚拟线程：

```yaml
spring:
  threads:
    virtual:
      enabled: true
```

启用后，Spring Boot 支持的 Web 请求执行器和任务执行器会使用虚拟线程。它适合 Spring MVC + JDBC + 阻塞 HTTP Client 这类高并发 I/O 应用，可以保留易读的同步代码。

```text
HTTP 请求
  -> 一个请求一个虚拟线程
  -> JDBC/HTTP 阻塞时卸载 Carrier Thread
  -> I/O 就绪后继续执行
```

虚拟线程不会扩大数据库和下游容量，仍需：

- 数据库连接池上限。
- HTTP 客户端连接池和请求超时。
- `Semaphore` 或限流器控制昂贵调用并发。
- 熔断、隔离和降级。
- 对吞吐、P99、内存和连接等待进行压测。

```java
@Bean
Semaphore paymentConcurrencyLimit() {
    return new Semaphore(100);
}
```

JDK 21～23 中，在长时间 `synchronized` 临界区执行阻塞 I/O 可能 Pin 住 Carrier Thread；JDK 24+ 已显著改进 Monitor 场景。仍应使用 JFR 检查本地方法或依赖库造成的 Pinning。

虚拟线程通常不需要池化，每个任务创建一个即可。不要通过固定大小虚拟线程池限制数据库并发，应直接限制数据库资源。大量虚拟线程也不适合保存庞大的 ThreadLocal 对象。

非 Web 应用只剩虚拟线程工作时，可让 Spring Boot 保持 JVM 存活：

```yaml
spring:
  main:
    keep-alive: true
```

## 13. 应用事件

```java
public record OrderCreatedEvent(long orderId) {
}

applicationEventPublisher.publishEvent(new OrderCreatedEvent(order.id()));
```

默认 Spring Event 是同步调用，监听器异常可能影响发布者。加上 `@Async` 后变为进程内异步，但仍不具备持久化、重试和跨实例消费能力。

```java
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
public void afterOrderCommitted(OrderCreatedEvent event) {
}
```

它适合事务提交后执行进程内动作，但在数据库提交后、监听器执行前进程崩溃时事件会丢失。发送关键消息、同步 ES 等场景使用 Transactional Outbox 更可靠。

## 14. Actuator 与可观测性

依赖：

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

配置示例：

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      probes:
        enabled: true
      show-details: when_authorized
```

常用端点：

| 端点 | 作用 |
|---|---|
| `/actuator/health` | 应用和依赖健康状态。 |
| `/actuator/metrics` | JVM、HTTP、连接池等指标。 |
| `/actuator/prometheus` | Prometheus 格式指标。 |
| `/actuator/loggers` | 查看或调整日志级别。 |
| `/actuator/threaddump` | 线程转储。 |
| `/actuator/httpexchanges` | 最近 HTTP 交换，需要额外存储实现。 |

不要无认证暴露 `env`、`configprops`、`heapdump`、`loggers` 等敏感端点。管理端口应限制在运维网络，并配置认证和访问审计。

### 14.1 健康检查

- **Liveness**：进程是否需要重启，不应依赖短暂不可用的外部服务。
- **Readiness**：实例是否能够接收流量，可以反映必要依赖是否就绪。

把数据库短暂超时直接作为 Liveness 失败可能造成所有实例同时重启，加重故障。探针语义必须与容器平台的动作匹配。

### 14.2 指标与 Trace

Micrometer Observation 为指标和链路追踪提供统一观察模型。关键指标包括：

- HTTP QPS、错误率和 P50/P95/P99。
- JVM Heap、GC、线程和 CPU。
- 数据库连接池活跃数、等待数和超时。
- HTTP Client 延迟、连接池和错误码。
- 线程池活跃线程、队列长度和拒绝数。
- 消息积压、消费失败和重试次数。

日志中保留 Trace ID 和稳定业务标识，但不要记录密码、Token、身份证或完整支付数据。

## 15. 优雅停机

```yaml
server:
  shutdown: graceful

spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```

优雅停机时，Web 容器停止接收新请求并等待正在处理的请求完成。应用还应处理：

- 从注册中心或负载均衡摘除后的传播时间。
- 消息消费者停止拉取并提交已完成 Offset。
- 自定义线程池停止接收任务并等待结束。
- 定时任务和长轮询中断。
- 数据库事务和文件写入完成。

容器平台的终止宽限时间必须大于 Spring 的停机等待时间。强制结束前仍未完成的任务需要幂等重试或补偿。

## 16. 测试

### 16.1 单元测试

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    OrderRepository orderRepository;

    @Mock
    PaymentClient paymentClient;

    @Test
    void shouldCreateOrder() {
        OrderService service = new OrderService(orderRepository, paymentClient);
        // 直接测试业务逻辑，不启动 Spring 容器
    }
}
```

纯业务逻辑优先使用快速单元测试。只有需要验证 Bean 装配、事务、序列化或 Web 协议时才启动 Spring Context。

### 16.2 Slice Test

- `@WebMvcTest`：测试 MVC Controller、校验和异常映射。
- `@DataJpaTest`：测试 JPA Repository 和数据库映射。
- `@JsonTest`：测试 JSON 序列化。
- `@RestClientTest`：测试 HTTP Client 交互。

Slice Test 只加载相关组件，通常比 `@SpringBootTest` 更快、更容易定位问题。

### 16.3 集成测试

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class OrderApplicationTest {
}
```

数据库、Redis、Kafka 和 Elasticsearch 集成测试可使用 Testcontainers 启动真实依赖，减少 H2 等替代实现与生产行为不一致的问题。测试数据要隔离，容器版本应与生产兼容。

## 17. 安全基础

- 使用 Spring Security 统一认证和授权，不在每个 Controller 手写判断。
- 密码使用 BCrypt、Argon2 等自适应哈希算法，不可逆加密存储。
- JWT 必须校验签名、Issuer、Audience、过期时间和允许的算法。
- 浏览器 Cookie 会话设置 `HttpOnly`、`Secure` 和合适的 `SameSite`。
- 正确配置 CORS；CORS 不是服务端权限控制。
- 使用 Cookie 认证的状态变更请求需要考虑 CSRF。
- 方法权限用于业务边界的补充，不能只依赖前端隐藏按钮。
- 依赖版本由受支持的 Spring Boot BOM 管理，并持续修复安全漏洞。

安全体系会在独立的 Spring Security 篇中详细展开。

## 18. 常见故障与排查

### 18.1 Bean 找不到

检查顺序：

1. 类是否由组件扫描、`@Bean` 或 Import 注册。
2. 启动类包位置和扫描范围是否正确。
3. Profile 和 Conditional 是否匹配。
4. 类型、泛型、`@Qualifier` 是否一致。
5. 自动配置 Condition Evaluation Report。

不要遇到 Bean 找不到就添加全局 `@ComponentScan`，它可能引入更多冲突。

### 18.2 Bean 重复

使用 `@Qualifier` 或 `@Primary` 表达选择。自动配置 Bean 与业务 Bean 冲突时检查是否缺少 `@ConditionalOnMissingBean`。是否允许覆盖 Bean 不应作为常规解决方式。

### 18.3 应用启动慢

- 查看启动日志和 Application Startup 数据。
- 检查 `@PostConstruct`、Runner 和静态初始化中的远程调用。
- 检查过大的组件扫描范围和过多自动配置。
- 检查数据库迁移、DNS、配置中心和密钥服务延迟。
- 使用 JFR 分析 CPU、类加载和锁等待。

### 18.4 接口偶发超时

同时观察入口请求、数据库连接池、HTTP Client、线程池、GC 和下游延迟。只增加 Tomcat 线程或超时时间可能让更多请求堆积，扩大故障。

### 18.5 事务未回滚

确认对象来自 Spring 容器、调用经过代理、方法可代理、异常类型符合回滚规则、异常未被吞掉，并检查实际使用的 TransactionManager。打开事务 DEBUG 日志只用于短期诊断，避免生产长期输出大量细节。

### 18.6 CPU 或内存异常

```bash
jcmd -l
jcmd <pid> Thread.print
jcmd <pid> GC.heap_info
jcmd <pid> JFR.start name=diagnose settings=profile duration=60s filename=diagnose.jfr
```

使用线程转储和 JFR 定位高 CPU、锁竞争和阻塞；使用 Heap Dump 前评估磁盘、暂停时间和敏感数据风险。不要在磁盘不足时直接生成大文件。

## 19. 面试高频问题

### 19.1 Spring 和 Spring Boot 有什么区别

> Spring Framework 提供 IoC、AOP、事务、Web 等基础能力；Spring Boot 通过 Starter、自动配置、外部化配置、内嵌容器和 Actuator 简化 Spring 应用的创建与运行。Boot 没有替代 Spring，底层仍然是 Spring 容器和 Bean。

### 19.2 IoC 和 DI 有什么区别

> IoC 是设计思想：对象创建和控制权交给容器；DI 是实现 IoC 的主要方式：容器通过构造器、Setter 等把依赖传入对象。构造器注入依赖明确、可测试，也能尽早暴露循环依赖。

### 19.3 Bean 生命周期是什么

> 容器读取 BeanDefinition，实例化对象、填充属性、执行 Aware 回调和 BeanPostProcessor，随后执行 `@PostConstruct`、InitializingBean 和自定义初始化方法，再经过后置处理器成为可用 Bean。容器关闭时执行 `@PreDestroy` 等销毁回调。AOP 代理通常由 BeanPostProcessor 创建。

### 19.4 Spring 如何解决循环依赖

> Spring Framework 可以通过单例缓存和提前引用处理部分 Setter/字段注入的单例循环依赖，并通过对象工厂尽量保证提前暴露正确代理。它不能解决构造器和 Prototype 循环依赖，Spring Boot 也默认禁止循环引用。工程上应重构职责，而不是依赖三级缓存。

### 19.5 Spring AOP 为什么会失效

> Spring AOP 主要依靠代理拦截方法调用。同类 `this` 调用、自己 `new` 的对象、不可代理的方法或绕过容器的调用不会经过代理，因此事务、缓存、异步等 Advice 不生效。

### 19.6 @Transactional 为什么不回滚

> 常见原因包括自调用绕过代理、异常被捕获、抛出受检异常但未配置 `rollbackFor`、方法不可代理、对象不属于容器、在新线程执行或使用错误的事务管理器。应从代理调用、异常规则和事务日志逐项确认。

### 19.7 REQUIRED 和 REQUIRES_NEW 有什么区别

> `REQUIRED` 加入现有事务，没有时才创建；`REQUIRES_NEW` 挂起外层事务并创建独立事务，可以独立提交或回滚，但会额外占用连接。外层事务回滚不会撤销已提交的内层新事务。

### 19.8 Spring Boot 自动配置原理是什么

> `@EnableAutoConfiguration` 导入候选自动配置类，自动配置再使用 `@ConditionalOnClass`、`@ConditionalOnProperty`、`@ConditionalOnMissingBean` 等判断当前环境，只注册满足条件且用户没有自定义的 Bean。Spring Boot 3 的候选配置通常记录在 AutoConfiguration.imports 文件中。

### 19.9 Filter、Interceptor 和 AOP 有什么区别

> Filter 位于 Servlet 层，可以处理进入 Spring MVC 前后的请求；Interceptor 位于 MVC Handler 调用链，能够获取 Controller Handler；AOP 作用于 Spring Bean 方法，适合事务、业务审计等方法级横切逻辑。

### 19.10 Spring MVC 请求流程是什么

> 请求先经过 Filter 到达 DispatcherServlet，HandlerMapping 找到 Controller，HandlerAdapter 完成参数解析并调用方法；返回值经过 HandlerMethodReturnValueHandler 和 HttpMessageConverter 转为响应，过程中 Interceptor 执行前后回调，异常交给 HandlerExceptionResolver 处理。

### 19.11 @Async 有什么注意事项

> 它依赖代理，同类自调用不生效；异步线程不会自动继承事务和所有 ThreadLocal 上下文；线程池要有界并配置拒绝策略；需要可靠执行的任务不能只依赖内存中的 `@Async`，应落库或进入消息队列。

### 19.12 Spring Boot 如何开启虚拟线程

> Java 21+、Spring Boot 3.2+ 可配置 `spring.threads.virtual.enabled=true`。它适合阻塞 I/O 并发，但不会增加数据库和下游容量，仍需连接池、Semaphore、超时和限流。迁移前要验证驱动兼容性、Pinning 和 P99 延迟。

### 19.13 Spring MVC 和 WebFlux 如何选择

> 普通阻塞式业务优先 MVC，Java 21 后可结合虚拟线程提高阻塞 I/O 并发；端到端非阻塞、流式和背压需求可选择 WebFlux。WebFlux 中混入阻塞调用会破坏事件循环优势，选择应依据完整调用链和团队能力。

### 19.14 @ConfigurationProperties 和 @Value 有什么区别

> `@Value` 适合少量独立值；`@ConfigurationProperties` 适合一组结构化配置，支持类型绑定、校验、元数据和集中管理。连接地址、超时和连接数等配置对象通常优先使用后者。

### 19.15 Spring 单例 Bean 是线程安全的吗

> 不一定。Singleton 只表示一个 ApplicationContext 中只有一个实例，Spring 不会自动同步成员变量。Service 应尽量无状态；必须共享可变状态时使用正确的并发控制或外部存储。

## 20. 生产环境检查清单

- [ ] 使用受支持的 Spring Boot、Java 和依赖版本组合。
- [ ] 使用构造器注入，消除循环依赖和字段注入。
- [ ] Service 保持无状态，不在单例 Bean 保存请求数据。
- [ ] 事务边界清晰，已覆盖常见事务失效和跨系统一致性。
- [ ] 外部配置类型化并校验，密码和证书不进入仓库。
- [ ] HTTP、数据库和线程池都有超时、容量和拒绝策略。
- [ ] `@Async`、定时任务和事件明确可靠性与幂等要求。
- [ ] 虚拟线程经过连接池、Pinning 和真实负载压测。
- [ ] Actuator 只暴露必要端点并受认证与网络隔离保护。
- [ ] 日志、指标、Trace、健康检查和告警完整。
- [ ] 优雅停机覆盖 Web、消息、线程池和长任务。
- [ ] 单元测试、Slice Test 和真实依赖集成测试分层执行。

## 21. 学习路线

1. 理解 IoC、DI、ApplicationContext 和 Bean 生命周期。
2. 掌握 AOP 代理、自调用边界和循环依赖。
3. 掌握事务传播、隔离、回滚和失效场景。
4. 理解 Spring Boot 自动配置和外部化配置。
5. 掌握 MVC 请求链路、校验和统一异常处理。
6. 学习异步任务、虚拟线程、事件和优雅停机。
7. 使用 Actuator、Micrometer、JFR 和测试工具支撑生产应用。
