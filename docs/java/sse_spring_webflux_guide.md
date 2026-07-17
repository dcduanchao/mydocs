# SSE（Server-Sent Events）在 Spring WebFlux 中的使用文档

## 1. SSE 是什么

SSE，全称 Server-Sent Events，是一种服务端向浏览器持续推送数据的机制。

它的特点是：

- 基于 HTTP 长连接
- 服务端可以持续向客户端推送消息
- 通信方向主要是：服务端 -> 客户端
- 浏览器端可以使用 `EventSource` 接收消息
- 响应内容类型通常是 `text/event-stream`

适合的场景：

- 实时通知
- AI 流式输出
- 日志推送
- 任务进度推送
- 订单状态更新
- 消息提醒
- 轻量级实时数据推送

不太适合的场景：

- 客户端和服务端频繁双向通信
- 高并发双向实时游戏
- 需要浏览器不断向服务端主动发送消息的场景

这种场景更适合 WebSocket。

---

## 2. SSE 和 WebSocket 的区别

| 对比项 | SSE | WebSocket |
|---|---|---|
| 通信方向 | 服务端到客户端为主 | 双向通信 |
| 协议 | HTTP | WebSocket 协议 |
| 浏览器支持 | 原生 `EventSource` | 原生 `WebSocket` |
| 自动重连 | 浏览器 `EventSource` 默认支持 | 需要自己实现 |
| 使用复杂度 | 较低 | 较高 |
| 适合场景 | 服务端推送、通知、流式输出 | 聊天、游戏、双向实时通信 |

简单理解：

```text
只需要服务端推客户端：优先考虑 SSE
需要双方频繁互发消息：考虑 WebSocket
```

---

## 3. Spring WebFlux 中的 SSE 返回类型

在 Spring WebFlux 中，SSE 接口通常返回：

```java
Flux<ServerSentEvent<String>>
```

例如：

```java
@GetMapping(value = "/sse", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
public Flux<ServerSentEvent<String>> sse() {
    return Flux.interval(Duration.ofSeconds(1))
            .map(i -> ServerSentEvent.builder("hello " + i)
                    .event("message")
                    .build());
}
```

这里：

```java
Flux<ServerSentEvent<String>>
```

表示：

```text
持续返回多个 SSE 事件
```

`ServerSentEvent<String>` 表示每一条 SSE 消息。

---

## 4. ServerSentEvent 的常用字段

```java
ServerSentEvent.builder("hello")
        .event("message")
        .id("1")
        .comment("this is comment")
        .retry(Duration.ofSeconds(3))
        .build();
```

常用字段说明：

| 字段 | 说明 |
|---|---|
| `data` | 真正发送给客户端的数据 |
| `event` | 事件名称 |
| `id` | 事件 ID，可用于断线重连恢复 |
| `retry` | 客户端重连时间 |
| `comment` | 注释，一般可用于心跳 |

常见写法：

```java
ServerSentEvent<String> event = ServerSentEvent.builder("success")
        .event("connect")
        .build();
```

对应前端会收到：

```text
event: connect
data: success
```

---

## 5. 前端如何接收 SSE

浏览器端可以使用 `EventSource`：

```javascript
const eventSource = new EventSource('/sse/connect?sessionId=abc');

// 默认 message 事件
eventSource.onmessage = function (event) {
    console.log('默认消息:', event.data);
};

// 自定义 connect 事件
eventSource.addEventListener('connect', function (event) {
    console.log('连接成功:', event.data);
});

// 自定义 heartbeat 事件
eventSource.addEventListener('heartbeat', function (event) {
    console.log('心跳:', event.data);
});

// 自定义业务消息事件
eventSource.addEventListener('message', function (event) {
    console.log('业务消息:', event.data);
});

// 错误处理
eventSource.onerror = function (error) {
    console.error('SSE 连接异常:', error);
};

// 主动关闭
eventSource.close();
```

注意：

```javascript
new EventSource(url)
```

默认是 GET 请求。

如果需要传递参数，通常放在 query 参数中：

```javascript
const eventSource = new EventSource('/sse/connect?sessionId=abc&type=1');
```

---

## 6. Sinks 是什么

在 Reactor 中，`Sinks` 可以理解为：

```text
手动向响应式流中推送数据的入口
```

你可以把它理解成一个“消息发送器”。

比如：

```java
Sinks.Many<ServerSentEvent<String>> sink =
        Sinks.many().multicast().onBackpressureBuffer();
```

这个 `sink` 可以不断发送 SSE 消息：

```java
sink.tryEmitNext(ServerSentEvent.builder("hello")
        .event("message")
        .build());
```

---

## 7. sink 和 sink.asFlux() 的区别

这是理解 SSE 推送的重点。

### 7.1 sink 是发送端

```java
sink.tryEmitNext(event);
```

表示：

```text
服务端主动往这个 sink 里面推一条消息
```

### 7.2 sink.asFlux() 是接收端流

```java
Flux<ServerSentEvent<String>> flux = sink.asFlux();
```

表示：

```text
把 sink 转成一个可以被订阅、可以返回给前端的 Flux 数据流
```

### 7.3 类比理解

```text
sink         = 水龙头
tryEmitNext  = 往外放水
sink.asFlux  = 连接出去的水管
前端 SSE     = 接水的人
```

所以：

```java
return sink.asFlux();
```

就是把这条响应式数据流返回给客户端。

以后服务端调用：

```java
sink.tryEmitNext(event);
```

客户端就能收到消息。

---

## 8. Sinks 的几种常见类型

### 8.1 Sinks.one()

只发送一个值，对应 `Mono`。

```java
Sinks.One<String> sink = Sinks.one();
Mono<String> mono = sink.asMono();

sink.tryEmitValue("hello");
```

适合：

```text
一次性结果
```

---

### 8.2 Sinks.empty()

只发送完成或错误信号，不发送具体数据。

```java
Sinks.Empty<String> sink = Sinks.empty();
Mono<String> mono = sink.asMono();

sink.tryEmitEmpty();
```

适合：

```text
只关心操作是否完成，不关心返回值
```

---

### 8.3 Sinks.many().unicast()

多个数据，但只能有一个订阅者。

```java
Sinks.Many<String> sink = Sinks.many()
        .unicast()
        .onBackpressureBuffer();
```

特点：

```text
一个 sink 只能被一个订阅者消费
```

适合：

```text
一个生产者 -> 一个消费者
```

---

### 8.4 Sinks.many().multicast()

多个数据，多个订阅者，只接收订阅后的新消息。

```java
Sinks.Many<String> sink = Sinks.many()
        .multicast()
        .onBackpressureBuffer();
```

特点：

```text
多个订阅者
只接收订阅之后的新消息
不回放历史消息
```

适合：

```text
实时 SSE 推送
实时通知
实时日志
```

你的代码中使用的是：

```java
Sinks.many().multicast().onBackpressureBuffer()
```

这表示：

```text
创建一个可以向多个订阅者实时推送消息的 sink
```

---

### 8.5 Sinks.many().replay()

多个数据，多个订阅者，可以回放历史消息。

```java
Sinks.Many<String> sink = Sinks.many()
        .replay()
        .limit(100);
```

特点：

```text
新订阅者连接后，可以收到历史消息
```

常见写法：

```java
Sinks.many().replay().all();        // 回放全部历史
Sinks.many().replay().limit(100);   // 回放最近 100 条
Sinks.many().replay().latest();     // 回放最新一条
```

适合：

```text
客户端重连后需要补历史消息
最近消息缓存
AI 对话历史补发
```

---

## 9. SSE 连接方法示例

下面是一个典型的 SSE 连接方法：

```java
public Flux<ServerSentEvent<String>> connect(String sessionId, String ip, int type) {

    Sinks.Many<ServerSentEvent<String>> sink =
            Sinks.many().multicast().onBackpressureBuffer();

    sessions.compute(sessionId, (k, list) -> {
        if (list == null) {
            list = new ArrayList<>();
        }
        list.add(new SessionInfo(sessionId, ip, sink));
        return list;
    });

    Flux<ServerSentEvent<String>> endpoint;
    if (type == 1) {
        endpoint = Flux.just(ServerSentEvent.builder("/aimcp/mcp1/" + sessionId)
                .event("endpoint")
                .build());
    } else {
        endpoint = Flux.just(ServerSentEvent.builder("/aimcp/mcp")
                .event("endpoint")
                .build());
    }

    return Flux.merge(
            sink.asFlux(),

            Flux.interval(Duration.ofSeconds(30))
                    .map(i -> ServerSentEvent.builder(
                                    "{\"time\":" + System.currentTimeMillis() + "}")
                            .event("heartbeat")
                            .build()),

            endpoint,

            Flux.just(ServerSentEvent.builder("success")
                    .event("connect")
                    .build())
    ).doFinally(signal -> {
        sessions.computeIfPresent(sessionId, (k, list) -> {
            int before = list.size();
            list.removeIf(s -> s.getSink() == sink);
            int after = list.size();
            log.info("sessionId={} removed {} session(s)", sessionId, before - after);
            return list.isEmpty() ? null : list;
        });
    });
}
```

---

## 10. 这段代码的整体流程

```text
前端建立 SSE 连接
        ↓
后端创建 Sinks.Many sink
        ↓
把 sink 保存到 sessions 中
        ↓
返回 Flux.merge(...)
        ↓
前端收到 connect 事件
        ↓
前端收到 endpoint 事件
        ↓
每 30 秒收到 heartbeat 心跳
        ↓
后端通过 sink.tryEmitNext(...) 主动推送业务消息
        ↓
前端接收业务消息
        ↓
连接断开后 doFinally 清理 sessions 中的 sink
```

---

## 11. Flux.merge 在这里的作用

你的代码中：

```java
return Flux.merge(
        sink.asFlux(),
        heartbeatFlux,
        endpoint,
        connectFlux
);
```

意思是：

```text
把多个 Flux 合并成一个 Flux 返回给前端
```

这几个流分别是：

| 流 | 作用 |
|---|---|
| `sink.asFlux()` | 后端主动推送的业务消息 |
| `Flux.interval(...)` | 心跳消息 |
| `endpoint` | 告诉前端 endpoint 地址 |
| `Flux.just(connect)` | 告诉前端连接成功 |

最终前端看到的是同一个 SSE 连接中的不同事件。

---

## 12. 如何主动向某个 session 推送消息

假设你把每个连接的 `sink` 存到了 `sessions` 中：

```java
private final Map<String, List<SessionInfo>> sessions = new ConcurrentHashMap<>();
```

可以这样发送消息：

```java
public void sendMessage(String sessionId, String message) {
    List<SessionInfo> list = sessions.get(sessionId);
    if (list == null || list.isEmpty()) {
        return;
    }

    ServerSentEvent<String> event = ServerSentEvent.builder(message)
            .event("message")
            .build();

    for (SessionInfo session : list) {
        Sinks.EmitResult result = session.getSink().tryEmitNext(event);

        if (result.isFailure()) {
            log.warn("send message failed, sessionId={}, result={}", sessionId, result);
        }
    }
}
```

核心代码是：

```java
session.getSink().tryEmitNext(event);
```

意思是：

```text
通过指定 session 的 sink 往前端推送一条 SSE 消息
```

---

## 13. 广播给所有连接

如果你想给所有在线连接推送消息：

```java
public void broadcast(String message) {
    ServerSentEvent<String> event = ServerSentEvent.builder(message)
            .event("broadcast")
            .build();

    sessions.forEach((sessionId, list) -> {
        for (SessionInfo session : list) {
            Sinks.EmitResult result = session.getSink().tryEmitNext(event);
            if (result.isFailure()) {
                log.warn("broadcast failed, sessionId={}, result={}", sessionId, result);
            }
        }
    });
}
```

---

## 14. 关闭某个连接

可以使用：

```java
sink.tryEmitComplete();
```

例如：

```java
public void closeSession(String sessionId) {
    List<SessionInfo> list = sessions.get(sessionId);
    if (list == null) {
        return;
    }

    for (SessionInfo session : list) {
        session.getSink().tryEmitComplete();
    }
}
```

这样客户端 SSE 连接会结束。

---

## 15. 推送异常

可以使用：

```java
sink.tryEmitError(new RuntimeException("error"));
```

例如：

```java
public void sendError(String sessionId, Throwable error) {
    List<SessionInfo> list = sessions.get(sessionId);
    if (list == null) {
        return;
    }

    for (SessionInfo session : list) {
        session.getSink().tryEmitError(error);
    }
}
```

注意：

```text
tryEmitError 会结束当前 Flux 流
```

也就是说，发出 error 后，这个 SSE 连接通常就结束了。

如果只是想告诉前端业务失败，不建议直接 `tryEmitError`，而是发送一个普通事件：

```java
ServerSentEvent<String> event = ServerSentEvent.builder("业务失败")
        .event("error-message")
        .build();

sink.tryEmitNext(event);
```

---

## 16. 心跳 heartbeat 的作用

SSE 是长连接，如果长时间没有数据，中间代理、网关、浏览器、服务器都有可能断开连接。

所以通常会定时发送心跳：

```java
Flux.interval(Duration.ofSeconds(30))
        .map(i -> ServerSentEvent.builder(
                        "{\"time\":" + System.currentTimeMillis() + "}")
                .event("heartbeat")
                .build())
```

作用：

```text
告诉客户端：连接还活着
防止中间网络设备断开空闲连接
方便前端判断连接状态
```

前端监听：

```javascript
eventSource.addEventListener('heartbeat', function (event) {
    console.log('heartbeat:', event.data);
});
```

---

## 17. doFinally 的作用

```java
.doFinally(signal -> {
    sessions.computeIfPresent(sessionId, (k, list) -> {
        list.removeIf(s -> s.getSink() == sink);
        return list.isEmpty() ? null : list;
    });
});
```

`doFinally` 会在 Flux 结束时执行。

常见结束情况：

- 前端关闭页面
- 浏览器刷新
- 网络断开
- 服务端主动 complete
- 服务端异常 error
- 客户端取消订阅

它的作用是：

```text
连接断开后，从 sessions 中删除当前 sink，避免内存泄漏
```

这是 SSE 长连接代码中非常重要的一步。

---

## 18. 为什么 sessions 里要存 List

你的代码：

```java
sessions.compute(sessionId, (k, list) -> {
    if (list == null) list = new ArrayList<>();
    list.add(new SessionInfo(sessionId, ip, sink));
    return list;
});
```

说明一个 `sessionId` 下面可能有多个 SSE 连接。

例如：

```text
同一个用户打开多个浏览器标签页
同一个用户刷新后旧连接还没释放
同一个账号多端登录
```

所以使用：

```java
Map<String, List<SessionInfo>> sessions
```

而不是：

```java
Map<String, SessionInfo> sessions
```

---

## 19. multicast 和 replay 在 SSE 中怎么选

### 19.1 multicast

```java
Sinks.many().multicast().onBackpressureBuffer()
```

特点：

```text
只接收连接之后的新消息
不补发历史
```

适合：

```text
实时通知
在线消息
心跳
实时日志
```

### 19.2 replay

```java
Sinks.many().replay().limit(100)
```

特点：

```text
新连接进来可以收到最近 100 条历史消息
```

适合：

```text
AI 流式输出中途重连
任务日志重连后补发
消息历史补偿
```

你的注释代码：

```java
// Sinks.Many<ServerSentEvent<String>> sink = Sinks.many().replay().limit(100);
```

表示你之前考虑过：

```text
给新订阅者回放最近 100 条消息
```

---

## 20. tryEmitNext 和 emitNext 的区别

### 20.1 tryEmitNext

```java
Sinks.EmitResult result = sink.tryEmitNext(event);
```

特点：

```text
尝试发送
不会阻塞
不会自动重试
返回发送结果
```

推荐在业务代码里使用，并判断结果：

```java
Sinks.EmitResult result = sink.tryEmitNext(event);
if (result.isFailure()) {
    log.warn("emit failed: {}", result);
}
```

### 20.2 emitNext

```java
sink.emitNext(event, Sinks.EmitFailureHandler.FAIL_FAST);
```

特点：

```text
可以指定失败处理策略
```

例如：

```java
sink.emitNext(event, Sinks.EmitFailureHandler.FAIL_FAST);
```

如果并发发送比较多，可以考虑自定义失败处理。

---

## 21. 常见 EmitResult

`tryEmitNext` 会返回 `Sinks.EmitResult`。

常见结果：

| 结果 | 含义 |
|---|---|
| `OK` | 发送成功 |
| `FAIL_ZERO_SUBSCRIBER` | 没有订阅者 |
| `FAIL_OVERFLOW` | 背压缓存溢出 |
| `FAIL_CANCELLED` | 订阅已取消 |
| `FAIL_TERMINATED` | sink 已经结束 |
| `FAIL_NON_SERIALIZED` | 多线程并发发送冲突 |

建议：

```java
Sinks.EmitResult result = sink.tryEmitNext(event);
if (result.isFailure()) {
    log.warn("SSE push failed, result={}", result);
}
```

---

## 22. SessionInfo 示例

```java
@Data
@AllArgsConstructor
@NoArgsConstructor
public class SessionInfo {
    private String sessionId;
    private String ip;
    private Sinks.Many<ServerSentEvent<String>> sink;
}
```

如果不用 Lombok，可以写成：

```java
public class SessionInfo {
    private String sessionId;
    private String ip;
    private Sinks.Many<ServerSentEvent<String>> sink;

    public SessionInfo(String sessionId, String ip,
                       Sinks.Many<ServerSentEvent<String>> sink) {
        this.sessionId = sessionId;
        this.ip = ip;
        this.sink = sink;
    }

    public String getSessionId() {
        return sessionId;
    }

    public String getIp() {
        return ip;
    }

    public Sinks.Many<ServerSentEvent<String>> getSink() {
        return sink;
    }
}
```

---

## 23. 完整 Controller 示例

```java
@RestController
@RequestMapping("/sse")
public class SseController {

    private final SseService sseService;

    public SseController(SseService sseService) {
        this.sseService = sseService;
    }

    @GetMapping(value = "/connect", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<String>> connect(@RequestParam String sessionId,
                                                  @RequestParam(defaultValue = "0") int type,
                                                  HttpServletRequest request) {
        String ip = request.getRemoteAddr();
        return sseService.connect(sessionId, ip, type);
    }

    @PostMapping("/send")
    public String send(@RequestParam String sessionId,
                       @RequestParam String message) {
        sseService.sendMessage(sessionId, message);
        return "ok";
    }
}
```

如果是纯 WebFlux 环境，也可以使用 `ServerHttpRequest`：

```java
@GetMapping(value = "/connect", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
public Flux<ServerSentEvent<String>> connect(@RequestParam String sessionId,
                                              @RequestParam(defaultValue = "0") int type,
                                              ServerHttpRequest request) {
    String ip = request.getRemoteAddress() == null
            ? "unknown"
            : request.getRemoteAddress().getAddress().getHostAddress();

    return sseService.connect(sessionId, ip, type);
}
```

---

## 24. 完整 Service 示例

```java
@Service
public class SseService {

    private static final Logger log = LoggerFactory.getLogger(SseService.class);

    private final Map<String, List<SessionInfo>> sessions = new ConcurrentHashMap<>();

    public Flux<ServerSentEvent<String>> connect(String sessionId, String ip, int type) {
        Sinks.Many<ServerSentEvent<String>> sink =
                Sinks.many().multicast().onBackpressureBuffer();

        sessions.compute(sessionId, (k, list) -> {
            if (list == null) {
                list = new ArrayList<>();
            }
            list.add(new SessionInfo(sessionId, ip, sink));
            return list;
        });

        Flux<ServerSentEvent<String>> endpoint = buildEndpoint(sessionId, type);

        Flux<ServerSentEvent<String>> heartbeat = Flux.interval(Duration.ofSeconds(30))
                .map(i -> ServerSentEvent.builder(
                                "{\"time\":" + System.currentTimeMillis() + "}")
                        .event("heartbeat")
                        .build());

        Flux<ServerSentEvent<String>> connect = Flux.just(
                ServerSentEvent.builder("success")
                        .event("connect")
                        .build()
        );

        return Flux.merge(
                sink.asFlux(),
                heartbeat,
                endpoint,
                connect
        ).doFinally(signal -> removeSession(sessionId, sink));
    }

    private Flux<ServerSentEvent<String>> buildEndpoint(String sessionId, int type) {
        String endpoint;
        if (type == 1) {
            endpoint = "/aimcp/mcp1/" + sessionId;
        } else {
            endpoint = "/aimcp/mcp";
        }

        return Flux.just(ServerSentEvent.builder(endpoint)
                .event("endpoint")
                .build());
    }

    public void sendMessage(String sessionId, String message) {
        List<SessionInfo> list = sessions.get(sessionId);
        if (list == null || list.isEmpty()) {
            log.warn("sessionId={} not connected", sessionId);
            return;
        }

        ServerSentEvent<String> event = ServerSentEvent.builder(message)
                .event("message")
                .build();

        for (SessionInfo session : list) {
            Sinks.EmitResult result = session.getSink().tryEmitNext(event);
            if (result.isFailure()) {
                log.warn("send failed, sessionId={}, result={}", sessionId, result);
            }
        }
    }

    public void broadcast(String message) {
        ServerSentEvent<String> event = ServerSentEvent.builder(message)
                .event("broadcast")
                .build();

        sessions.forEach((sessionId, list) -> {
            for (SessionInfo session : list) {
                Sinks.EmitResult result = session.getSink().tryEmitNext(event);
                if (result.isFailure()) {
                    log.warn("broadcast failed, sessionId={}, result={}", sessionId, result);
                }
            }
        });
    }

    public void closeSession(String sessionId) {
        List<SessionInfo> list = sessions.get(sessionId);
        if (list == null) {
            return;
        }

        for (SessionInfo session : list) {
            session.getSink().tryEmitComplete();
        }
    }

    private void removeSession(String sessionId,
                               Sinks.Many<ServerSentEvent<String>> sink) {
        sessions.computeIfPresent(sessionId, (k, list) -> {
            int before = list.size();
            list.removeIf(s -> s.getSink() == sink);
            int after = list.size();
            log.info("sessionId={} removed {} session(s)", sessionId, before - after);
            return list.isEmpty() ? null : list;
        });
    }
}
```

---

## 25. 常见问题

### 25.1 为什么前端收不到消息

检查点：

1. Controller 是否设置了：

```java
produces = MediaType.TEXT_EVENT_STREAM_VALUE
```

2. 前端是否使用 `EventSource` 连接。

3. 后端是否调用了：

```java
sink.tryEmitNext(event)
```

4. 对应的 `sessionId` 是否存在。

5. `tryEmitNext` 的返回值是否是 `OK`。

6. 连接是否已经断开并触发了 `doFinally`。

---

### 25.2 为什么刷新页面后收不到历史消息

如果使用：

```java
Sinks.many().multicast().onBackpressureBuffer()
```

新连接只能收到订阅之后的新消息。

如果希望回放历史，需要使用：

```java
Sinks.many().replay().limit(100)
```

---

### 25.3 为什么 sink.tryEmitNext 失败

可能原因：

- 没有订阅者
- 连接已经断开
- sink 已经 complete
- sink 已经 error
- 多线程并发发送导致冲突
- 背压缓存满了

建议记录日志：

```java
Sinks.EmitResult result = sink.tryEmitNext(event);
if (result.isFailure()) {
    log.warn("emit failed: {}", result);
}
```

---

### 25.4 为什么需要心跳

因为 SSE 是长连接，如果长时间没有数据，连接可能被代理、网关、浏览器或服务端断开。

建议每 15 到 30 秒发送一次心跳。

---

### 25.5 为什么 doFinally 很重要

如果不清理 `sessions`，断开的连接对应的 `sink` 会一直留在内存里。

结果可能是：

```text
内存泄漏
重复推送
无效连接越来越多
```

所以 SSE 连接必须在结束时清理。

---

## 26. 推荐实践

### 26.1 每个连接一个 sink

你的写法：

```java
Sinks.Many<ServerSentEvent<String>> sink =
        Sinks.many().multicast().onBackpressureBuffer();
```

每次连接创建一个新的 sink，然后保存到 `sessions` 中。

适合：

```text
按 sessionId 精准推送
```

---

### 26.2 每次发送都检查 EmitResult

不要只写：

```java
sink.tryEmitNext(event);
```

推荐：

```java
Sinks.EmitResult result = sink.tryEmitNext(event);
if (result.isFailure()) {
    log.warn("send failed: {}", result);
}
```

---

### 26.3 业务错误不要轻易 tryEmitError

`tryEmitError` 会结束当前流。

如果只是业务失败，建议发送普通事件：

```java
ServerSentEvent<String> event = ServerSentEvent.builder("业务失败")
        .event("business-error")
        .build();

sink.tryEmitNext(event);
```

---

### 26.4 长连接必须有心跳

建议：

```java
Flux.interval(Duration.ofSeconds(30))
```

---

### 26.5 断开必须清理

必须使用：

```java
doFinally(...)
```

清理 `sessions` 中的连接信息。

---

## 27. 核心记忆总结

### 27.1 SSE

```text
SSE 是服务端通过 HTTP 长连接持续向客户端推送消息。
```

### 27.2 Flux

```text
Flux 表示 0 到 N 个数据组成的异步流。
```

### 27.3 ServerSentEvent

```text
ServerSentEvent 表示一条 SSE 消息。
```

### 27.4 Sinks.Many

```text
Sinks.Many 是服务端手动推送多个数据的入口。
```

### 27.5 sink.asFlux()

```text
把 sink 转成可以返回给前端订阅的 Flux。
```

### 27.6 sink.tryEmitNext(...)

```text
服务端主动向前端推送一条消息。
```

### 27.7 doFinally

```text
连接结束后清理资源，避免内存泄漏。
```

---

## 28. 最重要的一张图

```text
前端 EventSource
      ↑
      │ 接收 SSE 事件
      │
Flux<ServerSentEvent<String>>
      ↑
      │ sink.asFlux()
      │
Sinks.Many<ServerSentEvent<String>> sink
      ↑
      │ tryEmitNext(event)
      │
后端业务代码主动推送消息
```

一句话：

```text
sink 是后端推消息的入口，sink.asFlux() 是前端接收消息的流。
```

