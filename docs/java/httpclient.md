# HttpClient 八股速刷

按 [AI 辅助面试回答提示词](../project/ai_interview_prompt.md) 整理，围绕客户端选型、连接池、超时、资源释放、重试和排障展开。每题先给 30 秒口述答案，再补案例、易错点和追问。

本文默认讨论 **Apache HttpClient 5 Classic（阻塞式、HTTP/1.1）**，示例使用 5.4.x API；JDK HttpClient 会单独标明。

## 1. HttpClient 是什么？和 JDK HttpClient、RestClient、WebClient 有什么区别？

### 面试精简回答

HttpClient 用来在 Java 程序里调用 HTTP 接口，常见实现有 Apache HttpClient 和 JDK HttpClient。Apache 的优势是连接池、代理和认证等配置比较丰富，JDK 11 起则内置了支持同步、异步和 HTTP/2 的客户端。Spring 的 RestClient 是同步调用门面，WebClient 是响应式调用门面，它们还需要底层 HTTP 实现。选型时我主要看调用模型、框架版本，以及是否需要流式处理或精细配置连接池。

### 展开补充

| 客户端 | 定位 | 面试记忆点 |
|---|---|---|
| Apache HttpClient 5 | HTTP 客户端实现，有 Classic 和 Async API | Classic 阻塞调用；HTTP/2 使用合适的 Async API |
| JDK HttpClient | Java 11 起内置的客户端实现 | `send()` 同步，`sendAsync()` 异步，支持 HTTP/2 |
| Spring RestClient | Spring Framework 6.1 起提供的同步门面 | 可以配置 Apache 等底层实现 |
| Spring WebClient | 响应式调用门面 | 常见底层实现是 Reactor Netty；调用 `.block()` 仍会阻塞 |

### 经典案例

面试场景：Spring MVC 服务调用普通 JSON 接口，可以使用 RestClient 配合 Apache 连接池；WebFlux 服务需要流式处理时，可以使用 WebClient。简单独立程序希望减少依赖，也可以直接使用 JDK HttpClient。

### 高频坑

- Apache HttpClient 5 和 JDK HttpClient 是不同实现，不能混用导包和配置方法。
- 使用 Apache 5.x 不代表 Classic 调用自动支持 HTTP/2。
- `sendAsync()` 不会消除连接、并发和内存限制，仍需控制在途请求数。
- WebClient 调用 `.block()` 会阻塞当前线程，不能因此宣称整条调用链非阻塞。

### 面试追问

- **RestTemplate 和 Apache HttpClient 是什么关系？** RestTemplate 是 Spring 的调用门面，可以通过请求工厂使用 Apache HttpClient，不是同一层的替代品。
- **4.x 迁移到 5.x 只改导包就行吗？** 不行，坐标从 `org.apache.httpcomponents:httpclient` 变成 `org.apache.httpcomponents.client5:httpclient5`，包名从 `org.apache.http.*` 变成 `org.apache.hc.*`，还要检查超时、重试和 Spring 适配版本。

## 2. 为什么使用连接池？连接数怎么配置？

### 面试精简回答

连接池复用已经建立的连接，减少重复 TCP 建连和 TLS 握手的开销。Apache 里我会同时配置总连接数和单路由连接数，因为请求集中到一个上游时，往往先碰到单路由上限。连接数可以先按请求速率乘平均连接占用时间估算，再根据峰值和长尾延迟压测调整。池满后请求会排队，所以还要限制租借连接的等待时间，避免线程一直阻塞。

### 展开补充

- `maxConnTotal` 限制整个连接池，`maxConnPerRoute` 限制单条路由；Route 通常与协议、主机、端口及代理有关。
- Classic HTTP/1.1 场景下，可以用“该实例请求速率 × 平均连接占用时间”估算平均在途请求数，不应直接当成最终容量。
- 连接池限制的是应用向外请求的连接，与 Tomcat 接收入站请求的连接数、业务线程数不同。

### 经典案例

```java
PoolingHttpClientConnectionManager manager =
        PoolingHttpClientConnectionManagerBuilder.create()
                .setMaxConnTotal(100)
                .setMaxConnPerRoute(20)
                .build();
```

假设单实例访问一个上游，每秒 200 次请求，平均占用连接 100 毫秒，平均在途请求约为 `200 × 0.1 = 20`。配置总连接数 100、单路由 20 时，该上游仍受 20 限制，需要结合峰值与上游承载能力调整。

### 高频坑

- 只调大 `maxConnTotal`，忽略 `maxConnPerRoute`，单个上游的并发仍上不去。
- 用平均耗时估算后不做压测，遇到长尾请求就出现排队。
- 上游变慢时只增大连接池，可能进一步压垮上游。
- 忽略实例数量，10 个实例每个允许 100 条连接，整体可能达到约 1000 条。

### 面试追问

- **连接池大，吞吐量就一定高吗？** 不一定，还受上游处理能力、线程、带宽和响应耗时限制，连接过多可能放大拥塞。
- **HTTP Keep-Alive 和连接池是什么关系？** Keep-Alive 允许复用连接，连接池管理这些连接的分配、上限和生命周期。

## 3. HttpClient 有哪些超时？为什么设了超时还会慢？

### 面试精简回答

我会把超时拆成取连接、建立连接、TLS 握手和等待响应几个阶段。连接池租借超时说明本地没有及时拿到连接，不等于上游 TCP 建连超时。响应或读超时也不等于整个调用的总耗时上限，持续缓慢返回数据的请求仍可能占用很久。所以业务层还要有总时间预算，把排队、建连和重试一起算进去，并确保超时时取消底层调用。

### 展开补充

| 配置 | 主要限制 | 所属配置 |
|---|---|---|
| `connectionRequestTimeout` | 等待从连接池租借连接 | `RequestConfig` |
| `connectTimeout` | 新连接建立阶段的等待 | `ConnectionConfig` |
| `handshakeTimeout` | TLS 握手等待 | `TlsConfig` |
| `responseTimeout` | 请求的响应等待；Classic 下影响相关 socket 读取等待 | `RequestConfig` |
| `socketTimeout` | 连接级 socket 读等待默认值 | `ConnectionConfig` |

### 经典案例

```java
ConnectionConfig connectionConfig = ConnectionConfig.custom()
        .setConnectTimeout(Timeout.ofSeconds(2))
        .setSocketTimeout(Timeout.ofSeconds(3))
        .build();

RequestConfig requestConfig = RequestConfig.custom()
        .setConnectionRequestTimeout(Timeout.ofMilliseconds(200))
        .setResponseTimeout(Timeout.ofSeconds(3))
        .build();
```

这两个配置分别应用到连接管理器和客户端。若业务总预算只有 2 秒，就不能把这里的 3 秒响应超时再叠加多次重试，必须按剩余预算分配时间。

### 高频坑

- 把“从池中取连接”误解成“与上游建立连接”。
- 认为设置 3 秒读超时，整个调用就一定在 3 秒内结束。
- 忽略 DNS 解析、排队、重定向和重试带来的额外耗时。
- 外层 Future 超时后只是不再等待，底层 HTTP 请求仍继续执行。

### 面试追问

- **复用连接时，connectTimeout 还管用吗？** 已有可复用连接不需要重新建连，所以它无法限制所有慢请求。
- **JDK 的请求 timeout 和 Apache responseTimeout 一样吗？** 不一样，尤其流式响应存在正文消费边界差异，需要分别确认语义。

## 4. HttpClient 线程安全吗？怎么避免连接泄漏？

### 面试精简回答

配置池化连接管理器的 CloseableHttpClient 通常可以被多个线程共享，但每次调用应该新建请求对象。最容易出问题的是响应没关闭或正文没处理完，导致连接迟迟不能归还。我优先使用带响应处理器的 execute，让客户端在回调结束后清理响应资源。共享客户端和连接池由应用管理生命周期，在应用退出时统一关闭。

### 展开补充

- 客户端和连接池可以共享；请求对象、响应流以及可变上下文不要被多个并发调用随意复用。
- 响应完整消费且连接仍有效时才适合复用；释放响应资源不等于该连接一定能再次使用。
- Cookie、认证上下文要按用户或会话隔离，防止共享客户端造成状态串用。

### 经典案例

以下 `httpClient` 是应用级共享实例，示例用于大小受控的文本响应：

```java
HttpGet request = new HttpGet("https://api.example.com/users/42");

String body = httpClient.execute(request, response -> {
    int statusCode = response.getCode();
    if (statusCode < 200 || statusCode >= 300) {
        throw new IOException("上游 HTTP 状态异常：" + statusCode);
    }

    HttpEntity entity = response.getEntity();
    return entity == null ? "" :
            EntityUtils.toString(entity, StandardCharsets.UTF_8);
});
```

### 高频坑

- 每次调用都创建、关闭客户端，连接池失去跨请求复用价值。
- 手动持有原始响应却忘记关闭，连接池逐渐耗尽。
- 把响应输入流返回到处理器外，回调结束后继续读取已经释放的资源。
- 对大文件使用 `toString()` 或 `toByteArray()`，导致堆内存明显增长。

### 面试追问

- **必须自己读取原始响应怎么办？** 使用 `executeOpen(...)` 并由调用方确保响应关闭，普通 JSON 调用优先使用响应处理器。
- **大文件怎么处理？** 在响应处理器内分块写入临时文件，限制大小，成功后移动文件，失败时清理临时文件。

## 5. 请求失败可以直接重试吗？怎么保证幂等？

### 面试精简回答

不能看到异常就直接重试，因为客户端超时不代表服务端没有执行成功。查询类请求可以在剩余时间预算内有限重试，创建订单、支付这类操作要先有业务幂等机制。我一般结合幂等键、查单和去重控制重复执行，再配置有限次数、退避和随机抖动。还会检查网关、SDK 和业务层是否重复重试，避免放大流量。

### 展开补充

- 重试同时要求业务语义允许重复调用、请求体可以重放，并且还有剩余时间预算。
- 429 需要遵守限流协议及 `Retry-After`；502、503、504 也要结合业务语义判断，不能无脑重试。
- JSON 字符串可以再次发送，不代表 POST 业务幂等；一次性输入流则可能连请求体都无法再次发送。

### 经典案例

```text
客户端提交订单
  → 服务端创建成功
  → 响应在网络中丢失
  → 客户端超时后重试
  → 没有业务去重时，可能重复创建订单
```

正确思路是多次尝试使用同一个业务幂等键，由服务端按协议去重或返回已有结果；结果不确定时先查单，必要时对账补偿。仅添加一个请求头，不能让不支持该协议的服务端自动幂等。

### 高频坑

- 认为超时表示服务端没有收到请求或没有完成业务。
- 每次重试生成新幂等键，导致去重失效。
- 网关、客户端和业务层分别重试，实际调用次数倍增。
- 连接池已经拥塞时立即重试，让本地排队更加严重。

### 面试追问

- **GET 可以无限重试吗？** 不可以，仍受总预算、限流和上游容量约束，重试也会增加系统负载。
- **怎么关闭自动重试？** Apache 可以在构建器上调用 `disableAutomaticRetries()`，再由业务层统一制定策略；自带策略需按实际版本核对。

## 6. GET、POST 调用中有哪些常见细节？

### 面试精简回答

我会先按接口契约处理参数编码和 Content-Type，再显式检查 HTTP 状态码与业务结果。查询参数用 URIBuilder，JSON 对象用序列化库，避免手工拼接字符串。HTTP 500 通常也是一次正常收到的响应，不一定自动抛网络异常。响应体还要限制大小，大文件走流式处理，不能直接全部读进内存。

### 展开补充

- `application/json`、`application/x-www-form-urlencoded` 和 `multipart/form-data` 是不同编码方式。
- Multipart 需要 boundary，应由实体生成完整 Content-Type，避免手工覆盖丢失 boundary。
- 即使 HTTP 200，也可能需要继续判断响应 JSON 中的业务错误码。

### 经典案例

```java
URI uri = new URIBuilder("https://api.example.com/search")
        .addParameter("keyword", "Java 连接池")
        .addParameter("page", "1")
        .build();

HttpGet getRequest = new HttpGet(uri);

HttpPost postRequest = new HttpPost("https://api.example.com/users");
postRequest.setEntity(new StringEntity(
        "{\"name\":\"张三\"}", ContentType.APPLICATION_JSON));
```

### 高频坑

- 参数先手动编码，再交给 URIBuilder，造成重复编码。
- 把 Token、密码放进 URL，泄露到访问日志或代理记录。
- 把非 2xx 状态码和网络异常混为一谈，漏掉失败分支。
- 只判断 HTTP 200，忽略业务错误码或响应格式不符合预期。

### 面试追问

- **收到 401 要原样重试吗？** 通常应先检查凭证；协议允许时受控刷新凭证，避免无限刷新或重试。
- **为什么不直接拼 JSON？** 动态字段涉及引号、换行等转义问题，应使用 Jackson 等序列化库。

## 7. Spring 中怎么管理 HttpClient？

### 面试精简回答

我会把 HttpClient 注册为单例 Bean，通过构造器注入业务服务，并在容器关闭时释放资源。连接池、超时和重试策略集中配置，避免业务方法每次新建客户端。不同上游的认证、超时或容量要求差异明显时，可以配置独立客户端隔离资源。还要确认业务真正使用了这个客户端，单独注册一个 Bean 不会自动替换所有 Spring HTTP 调用的底层实现。

### 展开补充

- 连接管理器默认由关联客户端负责关闭；设置 `setConnectionManagerShared(true)` 后，需要另外管理共享池的生命周期。
- 连接清理机制可以处理过期和空闲连接，但仍可能遇到上游主动断连。
- Spring Boot 已通过 BOM 管理依赖时，优先遵循版本管理，并核对 Spring 与 Apache 的兼容性。

### 经典案例

以下 Bean 方法放在 `@Configuration` 类中，连接数与超时仅为示例：

```java
@Bean(destroyMethod = "close")
public CloseableHttpClient httpClient() {
    ConnectionConfig connectionConfig = ConnectionConfig.custom()
            .setConnectTimeout(Timeout.ofSeconds(2))
            .setSocketTimeout(Timeout.ofSeconds(3))
            .build();

    PoolingHttpClientConnectionManager manager =
            PoolingHttpClientConnectionManagerBuilder.create()
                    .setMaxConnTotal(100)
                    .setMaxConnPerRoute(20)
                    .setDefaultConnectionConfig(connectionConfig)
                    .build();

    RequestConfig requestConfig = RequestConfig.custom()
            .setConnectionRequestTimeout(Timeout.ofMilliseconds(200))
            .setResponseTimeout(Timeout.ofSeconds(3))
            .build();

    return HttpClients.custom()
            .setConnectionManager(manager)
            .setDefaultRequestConfig(requestConfig)
            .disableAutomaticRetries()
            .evictExpiredConnections()
            .evictIdleConnections(TimeValue.ofSeconds(30))
            .build();
}
```

### 高频坑

- 每次业务请求都创建 Bean 外的新客户端，实际没有使用共享池。
- 注册 Apache 客户端 Bean 后，误以为所有 RestClient、RestTemplate、WebClient 都自动使用它。
- 多个客户端共用连接池，却没有明确谁负责最终关闭。
- 将示例中的容量和超时直接用于生产，没有结合上游与业务预算调整。

### 面试追问

- **RestClient 怎么接入 Apache？** 为它配置使用该客户端的 `HttpComponentsClientHttpRequestFactory`，并核对对应框架版本。
- **JDK HttpClient 也能这样配置 close 吗？** 要看 JDK 版本，Java 11/17 的该类没有 `close()`，Java 21 起提供 `AutoCloseable` 等生命周期方法。

## 8. 线上调用变慢、连接池耗尽怎么排查？

### 面试精简回答

我会先区分是 HTTP 错误、网络异常，还是业务结果失败，再确认时间花在等连接、建连还是读响应。连接池耗尽时重点看 leased、available 和 pending，并检查单路由上限、响应释放及上游耗时。如果大量连接都在等待慢上游，优先限制并发、快速失败和熔断，不能只加连接。最后结合服务端日志与链路追踪，验证网络、TLS 和空闲连接策略。

### 展开补充

| 指标 | 含义 | 排查方向 |
|---|---|---|
| `leased` | 已租借、正在使用的连接数 | 持续偏高时检查长调用、正文消费与资源释放 |
| `available` | 池内当前空闲连接数 | 有空闲连接仍等待时，检查路由分布与单路由限制 |
| `pending` | 等待租借连接的请求数 | 持续增长说明有排队，需要结合前两项判断原因 |

### 经典案例

面试场景：线程数升高，出现连接池租借超时，`leased` 长期处于上限，`pending` 持续增长。

1. 先检查单路由池状态，确认是否只集中在某个上游。
2. 对照链路耗时与上游日志，判断连接被慢请求占用，还是响应没有释放。
3. 修复资源释放问题；若是上游变慢，则限制并发、设置时间预算并按策略熔断。
4. 恢复后再压测连接池容量，核对各实例连接总量与上游承载能力。

### 高频坑

- 把连接池租借超时全部归因于网络，忽略本地排队与资源泄漏。
- 只看平均耗时，漏掉 P95、P99 长尾以及大响应体的连接占用。
- 认为空闲连接检测能彻底避免 reset，忽略检测后仍可能被上游断开的竞争。
- 为解决 TLS 问题关闭证书或主机名校验，掩盖证书链与信任配置问题。

### 面试追问

- **TTL 能终止一个超长请求吗？** TTL 主要限制连接可复用的总寿命，不是单次请求的强制截止时间。
- **偶发 connection reset 先看什么？** 检查上游和负载均衡的空闲超时、连接清理策略，并根据幂等性决定是否有限重试。

## 示例依赖与导包速查

上述代码是用于解释考点的独立片段，需要放在相应类或方法中。Apache 示例基于 `httpclient5` 5.4.x API；独立项目可以用固定版本复现，Spring Boot 项目优先检查 BOM 管理的实际版本。

```xml
<dependency>
    <groupId>org.apache.httpcomponents.client5</groupId>
    <artifactId>httpclient5</artifactId>
    <version>5.4.4</version>
</dependency>
```

该版本仅为示例固定版本，不代表最新版本。所用 Apache 类型的常见导包如下，按具体片段选用：

```java
import java.io.IOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;

import org.apache.hc.client5.http.classic.methods.HttpGet;
import org.apache.hc.client5.http.classic.methods.HttpPost;
import org.apache.hc.client5.http.config.ConnectionConfig;
import org.apache.hc.client5.http.config.RequestConfig;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManager;
import org.apache.hc.client5.http.impl.io.PoolingHttpClientConnectionManagerBuilder;
import org.apache.hc.core5.http.ContentType;
import org.apache.hc.core5.http.HttpEntity;
import org.apache.hc.core5.http.io.entity.EntityUtils;
import org.apache.hc.core5.http.io.entity.StringEntity;
import org.apache.hc.core5.net.URIBuilder;
import org.apache.hc.core5.util.TimeValue;
import org.apache.hc.core5.util.Timeout;
import org.springframework.context.annotation.Bean;
```

## 相关文档与参考资料

- [Java I/O、NIO 与 Netty](java_io_nio_netty.md)：补充阻塞、非阻塞与网络模型。
- [Spring Boot 最大请求数问题](java服务最大请求连接.md)：区分入站连接、线程与出站连接池。
- [Apache HttpClient 5.4.x API](https://hc.apache.org/httpcomponents-client-5.4.x/current/httpclient5/apidocs/)
- [JDK 17 HttpClient API](https://docs.oracle.com/en/java/javase/17/docs/api/java.net.http/java/net/http/HttpClient.html)
- [Spring REST 客户端文档](https://docs.spring.io/spring-framework/reference/integration/rest-clients.html)
