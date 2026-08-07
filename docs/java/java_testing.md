# JUnit 5 与 Java 测试体系

## 1. 为什么需要分层测试

测试的目标不是追求数字化覆盖率，而是用合理成本保护业务行为、接口契约和故障恢复能力。

```text
单元测试：快、隔离、定位业务规则
切片测试：验证一个 Spring 技术边界
集成测试：验证真实数据库/消息/缓存协作
端到端测试：验证关键用户旅程
```

测试越接近真实系统，信心通常越高但执行越慢、定位越难。不同层次需要覆盖不同风险，不能用大量 Controller 测试替代数据库和消息集成测试。

## 2. JUnit 5 组成

| 模块 | 作用 |
|---|---|
| JUnit Platform | 启动和发现测试的基础平台。 |
| JUnit Jupiter | JUnit 5 编程模型、注解和扩展。 |
| JUnit Vintage | 兼容 JUnit 3/4，迁移期使用。 |

Maven 依赖通常由 Spring Boot Test 或 JUnit BOM 管理版本：

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
```

## 3. 基础测试

```java
class PriceCalculatorTest {

    private final PriceCalculator calculator = new PriceCalculator();

    @Test
    void shouldApplyDiscount() {
        BigDecimal result = calculator.calculate(
                new BigDecimal("100"), new BigDecimal("0.9"));

        assertEquals(new BigDecimal("90.00"), result);
    }
}
```

常用断言：

```java
assertEquals(expected, actual);
assertTrue(condition);
assertNull(value);
assertInstanceOf(OrderCreated.class, event);

IllegalArgumentException error = assertThrows(
        IllegalArgumentException.class,
        () -> service.create(invalidCommand));
assertEquals("invalid amount", error.getMessage());
```

断言消息应说明业务意图。不要只写 `assertTrue(result != null)`，应断言状态、金额、事件和副作用。

### 3.1 生命周期

```java
class OrderServiceTest {
    @BeforeAll
    static void beforeAll() {
    }

    @BeforeEach
    void setUp() {
    }

    @AfterEach
    void tearDown() {
    }

    @AfterAll
    static void afterAll() {
    }
}
```

测试之间不应共享可变状态。`@TestInstance(PER_CLASS)` 可以减少初始化成本，但要特别注意状态污染。

### 3.2 参数化测试

```java
@ParameterizedTest
@CsvSource({
        "100, 0.9, 90.00",
        "0, 0.9, 0.00"
})
void shouldCalculate(String amount, String rate, String expected) {
    assertEquals(new BigDecimal(expected),
            calculator.calculate(new BigDecimal(amount), new BigDecimal(rate)));
}
```

复杂输入使用 `@MethodSource` 或 `@ArgumentsSource`，把边界场景明确列出：空值、最大值、精度、非法状态和时区。

### 3.3 Nested 与 DisplayName

```java
@DisplayName("订单金额计算")
class OrderAmountTest {
    @Nested
    @DisplayName("折扣")
    class Discount {
        @Test
        @DisplayName("满减后金额不能小于零")
        void shouldNotBeNegative() {
        }
    }
}
```

测试名称应表达业务行为和结果，而不是实现方法名。

## 4. Mockito

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    OrderRepository orderRepository;

    @Mock
    PaymentClient paymentClient;

    @InjectMocks
    OrderService orderService;

    @Test
    void shouldCreateOrder() {
        when(orderRepository.save(any())).thenAnswer(invocation ->
                invocation.getArgument(0));

        Order result = orderService.create(command());

        assertEquals(OrderStatus.CREATED, result.status());
        verify(orderRepository).save(any(Order.class));
        verifyNoMoreInteractions(orderRepository, paymentClient);
    }
}
```

Mock 的目标是隔离不属于当前测试的依赖，不是把所有对象都 Mock。领域规则、简单值对象和纯函数应使用真实对象。

### 4.1 Stub 与 Verify

- `when(...).thenReturn(...)`：定义依赖返回值。
- `thenThrow(...)`：模拟故障。
- `verify(...)`：验证重要副作用。
- `ArgumentCaptor`：检查传给依赖的关键对象。

```java
ArgumentCaptor<PaymentRequest> captor =
        ArgumentCaptor.forClass(PaymentRequest.class);
verify(paymentClient).pay(captor.capture());
assertEquals(order.id(), captor.getValue().orderId());
```

不要对所有内部调用都 Verify，否则重构实现就会大面积修改测试。优先验证业务可观察行为、重要外部命令和事务边界。

### 4.2 Strict Stubbing

未使用的 Stub 往往说明测试准备错误或实现已经变化。保持 Mockito Strictness，避免大量 `lenient()` 掩盖问题。

不要 Mock 私有方法、静态方法和内部实现来绕过设计问题。需要可测试性时优先拆分职责、注入 Clock/ID Generator/Client 接口。

## 5. Spring Boot 测试

### 5.1 @SpringBootTest

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class OrderApplicationTest {
    @Autowired
    TestRestTemplate restTemplate;
}
```

它加载完整 ApplicationContext，适合验证自动配置、Bean 装配、事务和真实 Web 流程，但启动慢。避免所有测试都使用它。

### 5.2 WebMvcTest

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockBean
    OrderService orderService;

    @Test
    void shouldReturnOrder() throws Exception {
        when(orderService.get(1001L)).thenReturn(response());

        mockMvc.perform(get("/orders/1001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1001));
    }
}
```

验证 Controller、参数校验、异常映射、序列化和 Security 配置。业务 Service 不在切片中自动加载，应通过 Mock 或 Import 提供。

### 5.3 DataJpaTest 与 JsonTest

```java
@DataJpaTest
class OrderRepositoryTest {
    @Autowired
    OrderRepository repository;
}
```

```java
@JsonTest
class OrderJsonTest {
    @Autowired
    JacksonTester<OrderResponse> json;
}
```

`@DataJpaTest` 默认可能使用嵌入数据库和事务回滚。若生产使用 MySQL 特有 SQL、锁或 JSON 类型，应使用真实 MySQL 容器验证。

### 5.4 TestConfiguration

测试替身可以使用：

```java
@TestConfiguration(proxyBeanMethods = false)
static class StubConfiguration {
    @Bean
    PaymentClient paymentClient() {
        return new FakePaymentClient();
    }
}
```

测试配置应位于测试范围，不要让 fake Bean 进入生产包。避免全局 `@MockBean` 隐藏真实自动配置问题。

## 6. Testcontainers

真实依赖集成测试：

```java
@Testcontainers
class OrderDatabaseTest {

    @Container
    static final MySQLContainer<?> mysql =
            new MySQLContainer<>("mysql:8.4.6")
                    .withDatabaseName("test_db")
                    .withUsername("test")
                    .withPassword("test");

    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", mysql::getJdbcUrl);
        registry.add("spring.datasource.username", mysql::getUsername);
        registry.add("spring.datasource.password", mysql::getPassword);
    }
}
```

Testcontainers 适合 MySQL、Redis、Kafka、RabbitMQ 和 Elasticsearch 等真实依赖。版本应和生产兼容，镜像要固定并在 CI 预热或缓存。

容器测试注意：

- 测试结束后可靠清理资源。
- 初始化脚本可重复执行或每测试隔离数据库。
- 不依赖宿主机固定端口。
- 不把线上密钥放入容器配置。
- 需要控制并发和总运行时间。

## 7. 事务测试

```java
@SpringBootTest
@Transactional
class OrderTransactionTest {
    @Test
    void shouldRollbackOnFailure() {
        // 测试结束后默认回滚
    }
}
```

测试事务回滚不等于生产事务一定正确。应额外覆盖：

- 受检异常和运行时异常。
- 自调用事务边界。
- `REQUIRES_NEW` 独立提交。
- 唯一约束和并发冲突。
- 真实数据库隔离级别和锁行为。

测试完成后的自动回滚可能让异步线程或外部系统看到已提交数据，异步集成测试要明确清理策略。

## 8. 集成测试设计

### 8.1 数据隔离

- 每个测试使用唯一业务前缀或独立 Schema。
- 仅依赖事务回滚无法清理异步消费者和外部系统。
- 测试失败时保留关键数据和日志，便于复现。
- 并行测试不能共享会产生冲突的固定 ID。

### 8.2 异步测试

不要固定 `Thread.sleep(1000)` 等待结果。使用 Awaitility 或事件探针：

```java
await().atMost(Duration.ofSeconds(10))
       .untilAsserted(() ->
               assertEquals(Status.COMPLETED, repository.status(id)));
```

等待必须有上限，失败信息要包含当前状态、队列和错误原因。

### 8.3 外部 HTTP

使用 WireMock、MockWebServer 或 Testcontainers 模拟真实 HTTP 行为，同时覆盖：

- 超时、连接拒绝和 5xx。
- 错误 JSON、空响应和慢响应。
- 重试、熔断和幂等。
- TLS、认证和请求 Header。

只 Mock 一个“永远成功”的 Client 会让测试失去故障价值。

## 9. Contract Test

服务提供者和消费者通过契约测试验证 API/事件兼容性：

```text
Provider 定义并验证契约
  -> 发布 Contract
Consumer 根据契约验证调用
  -> 发布前阻止破坏性变更
```

契约应覆盖字段类型、必填性、状态码、错误格式和兼容规则，不要把内部数据库结构当成 API 契约。消息事件也应测试新增字段、未知字段和版本策略。

## 10. 属性测试与边界测试

适合金额、日期、分页、状态机和解析器的属性：

- 金额计算不产生负数和非预期精度。
- 序列化后再反序列化保持等价。
- 分页游标不重复、不遗漏。
- 状态迁移只允许合法边。
- 同一幂等请求重复执行结果一致。

生成输入时限制规模和复杂度，避免测试本身生成无限数据或不稳定随机失败。失败种子必须可重放。

## 11. 并发与性能测试

JUnit 单元测试不等于压力测试。并发场景可以用 CountDownLatch 让线程同时进入关键代码：

```java
CountDownLatch ready = new CountDownLatch(threadCount);
CountDownLatch start = new CountDownLatch(1);
CountDownLatch done = new CountDownLatch(threadCount);

for (int i = 0; i < threadCount; i++) {
    executor.execute(() -> {
        ready.countDown();
        start.await();
        try {
            service.execute();
        } finally {
            done.countDown();
        }
    });
}
ready.await();
start.countDown();
done.await();
```

稳定性能基准使用 JMH，端到端吞吐和延迟使用 Gatling、JMeter、k6 等工具。报告必须包含数据规模、并发、预热、环境、P95/P99 和错误率。

## 12. 测试替身选择

| 替身 | 作用 |
|---|---|
| Dummy | 仅为满足参数，不参与验证。 |
| Stub | 预设返回值或异常。 |
| Fake | 可运行的简化实现，如内存仓储。 |
| Mock | 验证交互和调用。 |
| Spy | 包装真实对象，部分替换行为。 |

Fake 适合测试领域服务，Mock 适合外部边界。对内部实现过度 Verify 会制造脆弱测试。

## 13. 测试数据与时间

不要在业务代码中直接调用 `LocalDateTime.now()`、`UUID.randomUUID()` 和静态随机函数，注入 Clock、IdGenerator 或随机源：

```java
class OrderService {
    private final Clock clock;
    private final IdGenerator idGenerator;
}
```

测试可以固定时间和 ID，稳定验证过期、时区、夏令时和排序逻辑。生产默认使用 UTC 或统一时区，测试覆盖边界时区。

## 14. Maven 与 CI

```bash
mvn test
mvn verify
mvn -DskipTests=false verify
```

CI 分层执行：

1. 编译和快速单元测试。
2. 静态检查、依赖漏洞扫描和测试覆盖率。
3. 数据库、消息和缓存集成测试。
4. 契约测试和关键端到端测试。
5. 性能和故障测试按计划执行。

失败测试应保留 Surefire/Failsafe 报告、容器日志、线程转储和测试数据上下文。不要通过重跑直到成功掩盖 Flaky Test，应分类、修复或明确隔离。

覆盖率是发现未测试代码的指标，不是质量证明。分支、异常、并发和数据边界往往比单纯行覆盖更重要。

## 15. 测试命名与结构

推荐 Given-When-Then：

```java
@Test
void shouldRejectDuplicatePaymentRequest() {
    // Given
    givenPaymentAlreadyExists();

    // When
    DuplicateRequestException exception = assertThrows(
            DuplicateRequestException.class,
            () -> paymentService.create(command()));

    // Then
    assertEquals("payment already exists", exception.getMessage());
}
```

每个测试聚焦一个行为。Setup 太长时抽取有业务含义的 Fixture Builder，不要隐藏关键条件。

## 16. 常见问题

### 16.1 测试偶发失败

检查时间、随机数、共享静态状态、线程竞争、外部服务、端口、时区和测试顺序。重复运行只用于确认，不是修复方案。

### 16.2 Spring Context 启动很慢

减少 `@SpringBootTest`，使用 Slice Test；拆分 Context；避免启动时远程调用；使用 Context 缓存；容器依赖在测试类之间复用但要隔离数据。

### 16.3 Mock 验证通过但生产失败

Mock 只验证被预设的行为。使用真实数据库、序列化器、HTTP 协议和消息 Broker 做集成测试，并测试超时和异常路径。

### 16.4 测试事务已回滚但数据还在

异步线程、独立连接、`REQUIRES_NEW`、消息消费者和外部系统不受测试方法事务回滚影响。测试要显式清理或为每次测试使用独立环境。

## 17. 面试高频问题

### 17.1 单元测试和集成测试有什么区别

> 单元测试隔离依赖、执行快、定位清晰；集成测试验证真实组件之间的契约和事务，但更慢。应按风险分层，而不是用一种测试覆盖所有问题。

### 17.2 @SpringBootTest 和 @WebMvcTest 区别

> `@SpringBootTest` 加载完整上下文，适合自动配置、事务和端到端流程；`@WebMvcTest` 只加载 MVC 相关组件，适合 Controller、校验和异常映射，依赖通常需要 Mock。

### 17.3 Mock 为什么不能替代真实数据库

> Mock 无法验证 SQL、索引、事务隔离、锁、序列化和数据库特性。核心 Repository、迁移和并发场景需要真实数据库集成测试，Testcontainers 可以提供可重复环境。

### 17.4 如何处理异步测试

> 不使用无上限 sleep，使用 Awaitility 等带超时的条件等待，并在失败时输出状态、队列和错误。异步资源需要显式关闭和清理。

### 17.5 什么是 Flaky Test

> 同一代码和输入有时通过、有时失败，常由时间、随机数、并发、外部依赖和共享状态引起。应保留失败样本和环境，修复确定性根因，而不是无限重跑。

### 17.6 测试覆盖率越高越好吗

> 覆盖率只能表示执行过哪些代码，不能证明断言正确或异常路径可靠。高质量测试还要覆盖业务边界、状态迁移、并发、幂等和故障恢复。

### 17.7 为什么需要 Contract Test

> 微服务不能只依赖提供者内部测试。契约测试让消费者需求成为可执行契约，在发布前发现字段、状态码和事件结构的破坏性变更。

## 18. 生产检查清单

- [ ] 单元、切片、集成和端到端测试职责清晰。
- [ ] 核心业务有正常、边界、异常、幂等和并发测试。
- [ ] 数据库、消息和缓存使用真实兼容版本集成测试。
- [ ] 测试数据、时间、随机数和外部服务可控。
- [ ] 异步测试有条件等待、超时和失败现场。
- [ ] Contract Test 覆盖 API 和事件兼容性。
- [ ] CI 保存报告、容器日志和失败上下文。
- [ ] Flaky Test 有跟踪和修复机制，不用重跑掩盖。
- [ ] 覆盖率与业务风险、分支和异常质量一起评估。
