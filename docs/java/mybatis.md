# MyBatis 与 MyBatis-Plus

## 1. MyBatis 是什么

MyBatis 是一个半自动 ORM/SQL Mapping 框架。开发者负责 SQL，MyBatis 负责参数绑定、执行、结果映射、缓存和与 Spring 事务集成。

```text
Mapper 方法 -> MyBatis Proxy -> MappedStatement -> Executor
            -> JDBC PreparedStatement -> MySQL -> 结果映射
```

与全自动 ORM 相比，MyBatis 更容易精确控制 SQL；代价是开发者必须理解数据库、索引、事务和查询计划。MyBatis-Plus（简称 MP）在 MyBatis 之上提供通用 CRUD、条件构造器、分页、乐观锁和逻辑删除等能力，但不会自动优化错误 SQL。

## 术语速览

| 名称 | 含义 |
|---|---|
| SqlSessionFactory | 创建 SqlSession，应用中通常一份。 |
| SqlSession | 执行 SQL 的会话，非线程安全。 |
| Mapper Proxy | Mapper 接口的动态代理对象。 |
| MappedStatement | 一条 Mapper SQL 的完整配置。 |
| Executor | 执行查询、更新和缓存管理。 |
| StatementHandler | 创建和操作 JDBC Statement。 |
| ParameterHandler | 将 Java 参数绑定到 SQL 占位符。 |
| ResultSetHandler | 将 JDBC ResultSet 映射为 Java 对象。 |
| TypeHandler | Java 类型与 JDBC 类型之间转换。 |

## 2. Spring Boot 集成

```xml
<dependency>
    <groupId>org.mybatis.spring.boot</groupId>
    <artifactId>mybatis-spring-boot-starter</artifactId>
</dependency>

<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
    <scope>runtime</scope>
</dependency>
```

版本交给 Spring Boot 和 Starter 的兼容矩阵管理。Spring Boot 3 项目应使用兼容 Jakarta 与当前 Java 版本的 Starter。

使用 MyBatis-Plus 时，用 Boot 3 Starter 替换上面的 MyBatis Starter，不要同时引入两套 Starter：

```xml
<dependency>
    <groupId>com.baomidou</groupId>
    <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
</dependency>
```

```yaml
spring:
  datasource:
    url: jdbc:mysql://db:3306/app?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai
    username: app_user
    password: ${DB_PASSWORD}

mybatis:
  mapper-locations: classpath*:mapper/**/*.xml
  type-aliases-package: com.example.order.persistence.entity
  configuration:
    map-underscore-to-camel-case: true
    local-cache-scope: statement
```

Mapper 扫描：

```java
@SpringBootApplication
@MapperScan("com.example.order.persistence.mapper")
public class Application {
}
```

不要同时到处使用 `@Mapper` 和多个重叠的 `@MapperScan`，容易造成重复注册或扫描边界混乱。

## 3. Mapper 接口为什么没有实现类

```java
public interface OrderMapper {
    OrderEntity findById(@Param("id") long id);
}
```

启动时，MyBatis-Spring 为 Mapper 接口注册 FactoryBean。容器获取 Mapper 时创建动态代理；调用方法后，代理使用“接口全限定名 + 方法名”找到 MappedStatement。

```text
com.example.OrderMapper.findById
      = namespace + statement id
```

```xml
<mapper namespace="com.example.order.persistence.mapper.OrderMapper">
    <select id="findById" resultMap="orderResultMap">
        SELECT id, order_no, user_id, status, amount, created_at
        FROM orders
        WHERE id = #{id}
    </select>
</mapper>
```

接口重载方法容易让 Statement 定位和参数表达变复杂，Mapper 方法应使用清晰且唯一的方法名。

## 4. 一条 SQL 的执行流程

1. MapperProxy 接收接口方法调用。
2. 根据方法定位 MappedStatement。
3. SqlSession 把请求交给 Executor。
4. Executor 处理一级缓存并创建 StatementHandler。
5. ParameterHandler 通过 TypeHandler 绑定参数。
6. JDBC Driver 将 SQL 发送给数据库。
7. ResultSetHandler 将结果映射为对象。
8. Executor 返回结果并维护缓存。

插件可以拦截 Executor、StatementHandler、ParameterHandler 和 ResultSetHandler 的指定方法。分页、审计和 SQL 改写通常基于插件，但拦截器过多会增加复杂度和执行成本。

## 5. 参数绑定：#{} 与 ${}

### 5.1 #{}

```xml
WHERE user_id = #{userId}
  AND status = #{status}
```

`#{}` 生成 JDBC `?` 占位符，通过 PreparedStatement 绑定参数，可以正确处理类型和转义，是普通值参数的默认选择。

### 5.2 ${}

```xml
ORDER BY ${sortColumn} ${sortDirection}
```

`${}` 是原样字符串替换，不会生成占位符。用户输入直接进入 `${}` 会产生 SQL 注入。

动态表名、列名和排序方向不能使用 `#{}`，必须先映射到服务端白名单：

```java
String sortColumn = switch (request.sort()) {
    case CREATED_AT -> "created_at";
    case AMOUNT -> "amount";
};
```

不要用正则“过滤危险字符”代替白名单，也不要把前端传入字段名直接交给 Wrapper 或 XML。

### 5.3 多参数

```java
List<OrderEntity> findByUserAndStatus(
        @Param("userId") long userId,
        @Param("status") String status);
```

复杂查询优先使用明确的 Query Object，避免十几个参数和 `Map<String, Object>` 失去类型约束。

## 6. resultMap 与类型映射

```xml
<resultMap id="orderResultMap" type="OrderEntity">
    <id property="id" column="id"/>
    <result property="orderNo" column="order_no"/>
    <result property="userId" column="user_id"/>
    <result property="status" column="status"
            typeHandler="com.example.OrderStatusTypeHandler"/>
    <result property="amount" column="amount"/>
    <result property="createdAt" column="created_at"/>
</resultMap>
```

`resultType` 适合简单字段映射；字段别名、构造器、嵌套对象、枚举和集合映射使用 `resultMap` 更明确。

TypeHandler 示例：

```java
@MappedTypes(OrderStatus.class)
public class OrderStatusTypeHandler
        extends BaseTypeHandler<OrderStatus> {

    @Override
    public void setNonNullParameter(
            PreparedStatement ps, int i, OrderStatus value, JdbcType jdbcType)
            throws SQLException {
        ps.setString(i, value.code());
    }

    @Override
    public OrderStatus getNullableResult(ResultSet rs, String column)
            throws SQLException {
        return fromNullable(rs.getString(column));
    }

    @Override
    public OrderStatus getNullableResult(ResultSet rs, int columnIndex)
            throws SQLException {
        return fromNullable(rs.getString(columnIndex));
    }

    @Override
    public OrderStatus getNullableResult(CallableStatement cs, int columnIndex)
            throws SQLException {
        return fromNullable(cs.getString(columnIndex));
    }

    private OrderStatus fromNullable(String value) {
        return value == null ? null : OrderStatus.fromCode(value);
    }
}
```

生产 TypeHandler 必须正确处理 NULL、未知枚举值和所有读取重载，避免数据新增值后应用直接崩溃。

## 7. 动态 SQL

```xml
<select id="search" resultMap="orderResultMap">
    SELECT id, order_no, user_id, status, amount, created_at
    FROM orders
    <where>
        <if test="userId != null">
            AND user_id = #{userId}
        </if>
        <if test="status != null and status != ''">
            AND status = #{status}
        </if>
        <if test="createdFrom != null">
            AND created_at &gt;= #{createdFrom}
        </if>
    </where>
    ORDER BY created_at DESC, id DESC
    LIMIT #{limit}
</select>
```

常用标签：

- `<where>`：有条件时添加 WHERE，并移除开头 AND/OR。
- `<set>`：生成 UPDATE SET 并处理多余逗号。
- `<foreach>`：处理 IN、批量 Values。
- `<choose>`：类似 switch，只选择一个分支。
- `<trim>`：自定义前后缀处理。

```xml
<if test="ids != null and !ids.isEmpty()">
    AND id IN
    <foreach collection="ids" item="id" open="(" separator="," close=")">
        #{id}
    </foreach>
</if>
```

空集合必须在 Java 层或 XML 中明确处理。大 IN 列表会增加 SQL 解析、网络和执行成本，应拆批、使用临时表或重新设计查询。

## 8. 一级缓存与二级缓存

### 8.1 一级缓存

一级缓存默认属于 SqlSession。同一 SqlSession 中完全相同的查询可能直接返回缓存；执行更新、提交或回滚会清理相关缓存。

MyBatis-Spring 将 SqlSession 与当前事务绑定，开发者通常不应手动长期保存 SqlSession。一级缓存可能让同一事务看不到其他途径刚更新的数据，因此生产项目常配置：

```yaml
mybatis:
  configuration:
    local-cache-scope: statement
```

`STATEMENT` 将一级缓存限制在单条语句范围，行为更容易理解，但要根据项目兼容性与性能测试决定。

### 8.2 二级缓存

二级缓存属于 Mapper Namespace，可跨 SqlSession。它需要处理：

- 多实例缓存不一致。
- 其他服务或直接 SQL 更新数据库。
- 对象序列化和容量。
- 事务提交前后的可见性。

在 Redis、消息同步和多服务共享数据库的系统中，MyBatis 二级缓存通常弊大于利。不要仅因为“提高性能”就开启，应先优化 SQL、索引和明确的业务缓存。

## 9. Association、Collection 与 N+1

嵌套查询：

```xml
<collection property="items"
            column="id"
            select="findItemsByOrderId"/>
```

查询 100 个订单后，再为每个订单查询一次明细，会产生 1 + 100 次 SQL，即 N+1 问题。

解决方式：

- 使用 JOIN 一次查询，并通过 `resultMap` 合并。
- 先查主表，再用 `WHERE order_id IN (...)` 批量查询子表并在内存分组。
- 列表接口不加载全部明细，详情接口按需查询。

JOIN 一对多会重复主表列并放大结果集，也不一定永远更快。应根据数据规模、分页方式和网络成本选择。

## 10. 分页

MyBatis-Plus 分页插件：

```java
@Bean
MybatisPlusInterceptor mybatisPlusInterceptor() {
    MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
    interceptor.addInnerInterceptor(new OptimisticLockerInnerInterceptor());
    // 分页插件放在其他 SQL 改写插件之后
    interceptor.addInnerInterceptor(
            new PaginationInnerInterceptor(DbType.MYSQL));
    return interceptor;
}
```

```java
Page<OrderEntity> page = new Page<>(request.page(), request.size(), true);
IPage<OrderEntity> result = orderMapper.selectPage(
        page,
        Wrappers.<OrderEntity>lambdaQuery()
                .eq(OrderEntity::getUserId, request.userId())
                .orderByDesc(OrderEntity::getCreatedAt)
                .orderByDesc(OrderEntity::getId));
```

分页插件通常生成分页 SQL 和 Count SQL。复杂 JOIN 的自动 Count 可能很慢或语义不正确，应检查实际 SQL并提供专用统计查询。

深分页使用 Keyset Pagination：

```sql
SELECT id, order_no, created_at
FROM orders
WHERE user_id = #{userId}
  AND (created_at, id) < (#{lastCreatedAt}, #{lastId})
ORDER BY created_at DESC, id DESC
LIMIT #{size}
```

排序必须稳定，并建立匹配的联合索引。不要通过无限增大 Page Size 或 Offset 解决导出。

## 11. 批量操作

```java
try (SqlSession session = sqlSessionFactory.openSession(ExecutorType.BATCH, false)) {
    OrderMapper mapper = session.getMapper(OrderMapper.class);
    for (int i = 0; i < orders.size(); i++) {
        mapper.insert(orders.get(i));
        if ((i + 1) % 500 == 0) {
            session.flushStatements();
            session.clearCache();
        }
    }
    session.commit();
}
```

Batch Executor 会暂存 Statement 和参数，必须定期 Flush，否则大量对象占用内存。Flush 结果中可能包含批次级失败，不能只检查最后是否抛异常。

更高吞吐可使用单条 Multi-values Insert。无论哪种方式，都要控制事务大小、Redo、Binlog、锁和复制延迟。不要对巨大列表一次性 `saveBatch` 后假设框架会自动处理所有容量问题。

## 12. Spring 事务与 SqlSession

MyBatis-Spring 通过 `SqlSessionTemplate` 获取与当前 Spring 事务绑定的 SqlSession。同一数据源和 TransactionManager 下，Mapper 操作参与当前事务。

```java
@Transactional
public void createOrder(CreateOrderCommand command) {
    orderMapper.insert(command.toOrder());
    orderItemMapper.insertBatch(command.toItems());
}
```

常见问题：

- 自调用绕过 `@Transactional` 代理。
- Mapper 使用的数据源与事务管理器不匹配。
- 手动创建 SqlSession，脱离 Spring 管理。
- 异常被吞掉，事务正常提交。
- 在 `@Async` 或新线程中误以为继承事务。
- 一个方法操作多个数据源，却只配置一个本地事务管理器。

不要在数据库事务中执行长时间 HTTP 调用或无限批处理。事务超时、SQL 超时和连接池等待是不同层次，需要分别配置和监控。

## 13. MyBatis 插件原理

```java
@Intercepts({
    @Signature(
        type = Executor.class,
        method = "update",
        args = {MappedStatement.class, Object.class})
})
public class AuditInterceptor implements Interceptor {
    @Override
    public Object intercept(Invocation invocation) throws Throwable {
        return invocation.proceed();
    }
}
```

插件通过动态代理包裹四类核心组件。多个插件的顺序会影响 SQL 改写和结果，升级 MyBatis 时还要验证方法签名兼容。

审计、数据权限、多租户等关键约束不能只相信字符串改写结果，应覆盖 SELECT、UPDATE、DELETE、子查询、UNION 和批量 SQL 的测试。

## 14. MyBatis-Plus 核心功能

### 14.1 BaseMapper

```java
public interface OrderMapper extends BaseMapper<OrderEntity> {
}
```

```java
@TableName("orders")
public class OrderEntity {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    @Version
    private Integer version;

    @TableLogic
    private Boolean deleted;
}
```

通用 CRUD 适合单表操作，复杂查询仍应编写明确 Mapper SQL。不要为了使用 Wrapper 把复杂统计拼成难以维护的 Java 链。

### 14.2 LambdaQueryWrapper

```java
LambdaQueryWrapper<OrderEntity> wrapper = Wrappers.lambdaQuery();
wrapper.eq(OrderEntity::getUserId, userId)
       .eq(status != null, OrderEntity::getStatus, status)
       .ge(from != null, OrderEntity::getCreatedAt, from)
       .orderByDesc(OrderEntity::getCreatedAt)
       .last("LIMIT 100");
```

Lambda 列引用可以降低字段重命名风险，但 `last()`、`apply()`、`inSql()` 等接受 SQL 片段的 API 仍可能注入。只允许服务端常量或白名单内容进入这些方法。

### 14.3 乐观锁

在第 10 节的同一个 `MybatisPlusInterceptor` Bean 中、分页插件之前加入：

```java
interceptor.addInnerInterceptor(new OptimisticLockerInnerInterceptor());
```

应用中只定义一个统一的 `MybatisPlusInterceptor` Bean，并明确各 InnerInterceptor 的顺序。

更新生成类似：

```sql
UPDATE orders
SET status = ?, version = version + 1
WHERE id = ? AND version = ?;
```

影响行数为 0 表示版本冲突或数据不存在，业务必须处理。乐观锁适合冲突较少的短事务；热点库存更适合条件更新、队列串行化或其他并发控制。

### 14.4 逻辑删除

逻辑删除会自动为部分查询和更新添加删除标记条件，但它不是数据安全机制：

- 唯一索引可能与已删除记录冲突。
- 表数据和索引持续增长。
- 自定义 SQL 可能遗漏过滤条件。
- 合规数据仍需真正清理或归档。

需要保留历史时，可以使用状态字段、归档表或审计表，不要给所有表机械添加 `deleted`。

### 14.5 自动填充

```java
@Component
public class AuditMetaObjectHandler implements MetaObjectHandler {
    @Override
    public void insertFill(MetaObject metaObject) {
        strictInsertFill(metaObject, "createdAt", LocalDateTime.class,
                LocalDateTime.now());
    }

    @Override
    public void updateFill(MetaObject metaObject) {
        strictUpdateFill(metaObject, "updatedAt", LocalDateTime.class,
                LocalDateTime.now());
    }
}
```

数据库默认值、应用填充和触发器不要重复负责同一字段，否则不同写入途径会产生不一致。

### 14.6 多租户

Tenant 插件可以自动增加租户条件，但必须明确：

- 租户 ID 来自可信认证上下文，不来自可篡改请求参数。
- 管理员跨租户访问经过单独授权。
- 唯一索引包含租户维度。
- 异步任务正确传播并清理租户上下文。
- 原生 SQL、子查询和插件忽略规则经过安全测试。

强隔离需求应评估分 Schema、分库或独立实例，SQL 自动改写不能等同于物理隔离。

## 15. 性能与安全检查

- 日志只在开发环境输出完整 SQL，生产避免记录敏感参数。
- 使用 P6Spy 等代理时评估性能，防止日志量拖垮应用。
- Mapper 查询只返回需要字段，不滥用 `SELECT *`。
- 为核心 SQL 建立执行计划和慢查询监控。
- 动态排序、表名和 SQL 片段使用白名单。
- 批量和 IN 查询设置元素上限。
- Wrapper 由服务端构造，不接受客户端序列化对象。
- 更新和删除必须验证条件，防止全表操作。
- 数据权限同时使用数据库约束、接口权限和审计兜底。

## 16. 常见故障

### 16.1 Invalid bound statement

检查 Mapper XML 路径、Namespace、Statement ID、打包结果和扫描配置。多模块项目尤其要确认 XML 已进入最终 Jar。

### 16.2 参数不存在

多参数方法使用 `@Param` 或 Query Object，并核对 XML 名称。不要依赖编译器是否保留参数名。

### 16.3 查询字段为 null

检查列别名、驼峰映射、resultMap、构造器、TypeHandler 和数据库 NULL。打开 MyBatis 日志只能看到 SQL 与参数，仍需直接验证数据库结果。

### 16.4 事务未回滚

确认调用经过 Spring Proxy、异常符合回滚规则、SqlSession 属于 Spring、数据源和事务管理器匹配，并检查是否在异步线程执行。

### 16.5 分页失效或重复

检查分页插件是否注册、插件顺序、方言和 SQL 是否稳定排序。只按非唯一时间字段排序会在相同时间值或并发写入时出现重复、遗漏。

## 17. 面试高频问题

### 17.1 #{} 和 ${} 有什么区别

> `#{}` 使用 PreparedStatement 占位符并通过 TypeHandler 绑定参数，能正确转义普通值；`${}` 是原样字符串替换，直接使用用户输入会 SQL 注入。动态列名等场景必须使用服务端白名单后才能进入 `${}`。

### 17.2 Mapper 为什么不需要实现类

> MyBatis 为 Mapper 接口创建动态代理。代理根据接口全限定名和方法名定位 MappedStatement，再通过 SqlSession、Executor、StatementHandler 和 JDBC 执行 SQL 并映射结果。

### 17.3 一级缓存和二级缓存有什么区别

> 一级缓存属于 SqlSession，默认开启；二级缓存属于 Mapper Namespace，可跨 SqlSession。多实例和外部写数据库时二级缓存很难保持一致，通常更适合使用明确的业务缓存。

### 17.4 MyBatis 如何与 Spring 事务结合

> MyBatis-Spring 使用 SqlSessionTemplate 获取绑定到当前 Spring 事务的 SqlSession，Mapper 共享同一连接并在事务结束时提交或回滚。手动 SqlSession、新线程或错误事务管理器可能脱离该事务。

### 17.5 MyBatis 插件原理是什么

> 插件使用动态代理拦截 Executor、StatementHandler、ParameterHandler 和 ResultSetHandler 的指定方法。分页等插件通过拦截执行流程改写 SQL 或参数，多个插件顺序和版本兼容性需要测试。

### 17.6 MyBatis-Plus 会自动防止 SQL 注入吗

> 普通参数绑定能降低注入风险，但 `last`、`apply`、`inSql` 等 SQL 片段 API 仍然危险。排序字段、列名、表名和自定义 SQL 必须使用白名单，不能把客户端 Wrapper 直接用于查询。

### 17.7 如何解决 N+1

> 可使用 JOIN 一次查询，或先查主表再批量按外键查询子表并分组；列表接口也可以不加载明细。应结合分页和结果集大小选择，不能简单认为 JOIN 永远最好。

### 17.8 Batch Executor 有什么风险

> 它会暂存 Statement 和参数，长时间不 Flush 会占用大量内存；错误可能到 Flush 时才出现；超大事务还会增加锁、Redo、Binlog 和复制延迟。因此要分批 Flush、检查批次结果并控制事务大小。

## 18. 生产环境检查清单

- [ ] Mapper 扫描、XML 路径和 Namespace 统一。
- [ ] 普通参数使用 `#{}`，动态标识符使用白名单。
- [ ] resultMap、TypeHandler 和枚举未知值有测试。
- [ ] 一级缓存行为明确，未随意启用二级缓存。
- [ ] 列表查询不存在 N+1 和无界结果集。
- [ ] 分页使用稳定排序，深分页采用游标方式。
- [ ] 批量操作分批 Flush，并处理部分失败。
- [ ] SqlSession、数据源和 Spring 事务管理器一致。
- [ ] MP 逻辑删除、乐观锁和多租户边界经过验证。
- [ ] 核心 SQL 接入慢查询、执行计划和数据权限审计。

## 19. 学习路线

1. 理解 Mapper Proxy、MappedStatement、SqlSession 和 Executor。
2. 掌握 XML、参数绑定、resultMap、TypeHandler 和动态 SQL。
3. 理解一级缓存、二级缓存和 Spring 事务集成。
4. 掌握分页、批量、关联查询和插件机制。
5. 使用 MyBatis-Plus CRUD、Wrapper、乐观锁和逻辑删除。
6. 通过真实 MySQL 数据验证索引、事务和性能。
