# Java I/O、NIO 与 Netty

## 1. I/O 模型概览

I/O 是应用与文件、网络、终端等外部设备交换数据的过程。Java 常见选择：

| 模型 | 核心抽象 | 适用场景 |
|---|---|---|
| BIO | InputStream、Reader、Socket | 简单阻塞式读写、虚拟线程服务端 |
| NIO | Buffer、Channel、Selector | 大量连接、事件驱动网络程序 |
| AIO/NIO.2 | AsynchronousChannel、CompletionHandler | 操作系统支持的异步文件或网络操作 |
| Netty | EventLoop、ChannelPipeline、ByteBuf | 生产级高性能网络协议和 RPC |

阻塞、非阻塞描述调用线程是否等待；同步、异步描述完成结果由谁推进和通知。不要把 NIO 简单等同于“异步”。Java Selector 模型通常是同步非阻塞 I/O。

## 2. 字节流与字符流

### 2.1 InputStream 与 OutputStream

```java
Path source = Path.of("source.bin");
Path target = Path.of("target.bin");

try (InputStream input = new BufferedInputStream(Files.newInputStream(source));
     OutputStream output = new BufferedOutputStream(Files.newOutputStream(target))) {
    byte[] buffer = new byte[8192];
    int length;
    while ((length = input.read(buffer)) != -1) {
        output.write(buffer, 0, length);
    }
}
```

`read()` 返回实际读取长度，不能假设一次填满 Buffer。`try-with-resources` 按声明相反顺序关闭资源，并保留关闭阶段的 Suppressed Exception。

### 2.2 Reader 与 Writer

```java
try (BufferedReader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8)) {
    String line;
    while ((line = reader.readLine()) != null) {
        process(line);
    }
}
```

文本必须显式指定 Charset。不要依赖操作系统默认编码，否则开发机与服务器可能出现乱码。

```text
字节 --Charset Decoder--> 字符
字符 --Charset Encoder--> 字节
```

网络协议通常以字节为边界，只有确定完整消息后再按协议 Charset 解码，避免多字节字符被分包截断。

## 3. Files 与 Path

```java
Path path = Path.of("data", "orders.csv").toAbsolutePath().normalize();

if (Files.isRegularFile(path)) {
    long size = Files.size(path);
}

Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING);
Files.move(temp, target,
        StandardCopyOption.ATOMIC_MOVE,
        StandardCopyOption.REPLACE_EXISTING);
```

文件上传必须限制大小、扩展名、真实类型和保存目录。用户文件名不能直接拼接到服务器路径；规范化后还要确认最终路径仍位于允许目录内，防止路径穿越。

`Files.lines()` 和 `Files.walk()` 返回持有资源的 Stream，必须关闭：

```java
try (Stream<Path> paths = Files.walk(root)) {
    paths.filter(Files::isRegularFile).forEach(this::process);
}
```

## 4. Buffer

NIO Buffer 的关键属性：

```text
0 <= mark <= position <= limit <= capacity
```

- `capacity`：底层存储容量。
- `position`：下一次读写位置。
- `limit`：当前允许读写的边界。
- `flip()`：从写模式切换到读模式。
- `clear()`：准备重新写入，不会清零已有字节。
- `compact()`：保留未读数据并移动到开头，继续写入。

```java
ByteBuffer buffer = ByteBuffer.allocate(8192);
while (channel.read(buffer) != -1) {
    buffer.flip();
    while (buffer.hasRemaining()) {
        consume(buffer.get());
    }
    buffer.clear();
}
```

### 4.1 Heap 与 Direct Buffer

| 类型 | 特点 |
|---|---|
| Heap Buffer | 在 Java Heap，创建便宜，可直接访问数组。 |
| Direct Buffer | Off-Heap，减少部分本地 I/O 拷贝，分配释放成本更高。 |

Direct Buffer 仍受进程内存限制，泄漏可能造成 `OutOfMemoryError: Direct buffer memory`，但普通 Heap Dump 不一定直接显示全部内容。应监控 Native Memory 和 BufferPool 指标。

## 5. Channel

Channel 可以双向读写并配合 Buffer：

```java
try (FileChannel input = FileChannel.open(source, StandardOpenOption.READ);
     FileChannel output = FileChannel.open(target,
             StandardOpenOption.CREATE,
             StandardOpenOption.WRITE,
             StandardOpenOption.TRUNCATE_EXISTING)) {
    long position = 0;
    while (position < input.size()) {
        long transferred = input.transferTo(position, input.size() - position, output);
        if (transferred <= 0) {
            break;
        }
        position += transferred;
    }
}
```

`transferTo`/`transferFrom` 可能使用零拷贝优化，减少数据在用户态与内核态之间复制。但一次传输可能小于请求长度，必须循环处理。

`FileChannel.force(true)` 请求将数据和元数据刷到稳定存储，但最终保证仍受文件系统、磁盘缓存和硬件影响。

## 6. Socket 与 TCP

TCP 提供有序可靠字节流，不保留应用消息边界。发送两次不代表接收两次：

```text
发送：[ABC][DEF]
接收可能：[ABCDEF]、[A][BCDE][F] 或其他组合
```

协议必须定义 Frame：

- 固定长度。
- 分隔符。
- Length Field + Payload。
- 自描述协议，例如正确限制长度的 HTTP。

任何 Frame Decoder 都要设置最大消息长度，防止恶意长度字段导致内存耗尽。

### 6.1 常见 TCP 参数

- Connect Timeout：建立连接等待上限。
- Read Timeout：等待业务响应上限。
- Keepalive：检测长期空闲连接，不替代应用心跳。
- Backlog：尚未被应用 Accept 的连接队列相关参数。
- `TCP_NODELAY`：控制 Nagle，低延迟小包协议常开启。

网络超时不代表请求未被服务端执行。非幂等写操作重试必须使用业务幂等键。

## 7. Selector

Selector 让一个线程监听多个非阻塞 Channel 的就绪事件：

```text
多个 SocketChannel
       -> Selector
       -> OP_ACCEPT / OP_CONNECT / OP_READ / OP_WRITE
       -> 单个 Event Loop 分发处理
```

简化示例：

```java
try (Selector selector = Selector.open();
     ServerSocketChannel server = ServerSocketChannel.open()) {
    server.configureBlocking(false);
    server.bind(new InetSocketAddress(8080));
    server.register(selector, SelectionKey.OP_ACCEPT);

    while (!Thread.currentThread().isInterrupted()) {
        selector.select();
        Iterator<SelectionKey> iterator = selector.selectedKeys().iterator();
        while (iterator.hasNext()) {
            SelectionKey key = iterator.next();
            iterator.remove();
            handle(key, selector);
        }
    }
}
```

处理后必须从 Selected Key Set 移除。`OP_WRITE` 几乎总是就绪，不能长期注册；仅在发送缓冲区有积压时关注，写完后取消，否则可能造成 CPU 空转。

手写 Selector 还要处理半包、连接状态、部分写、背压、空轮询、资源释放和异常隔离。生产协议通常使用 Netty，而不是重复实现这些细节。

## 8. AIO

```java
AsynchronousFileChannel channel = AsynchronousFileChannel.open(
        path, StandardOpenOption.READ);

ByteBuffer buffer = ByteBuffer.allocate(4096);
channel.read(buffer, 0, null, new CompletionHandler<>() {
    @Override
    public void completed(Integer count, Object attachment) {
        buffer.flip();
    }

    @Override
    public void failed(Throwable error, Object attachment) {
        // 记录并关闭资源
    }
});
```

不同操作系统和 JDK 实现的底层机制不同。AIO API 并不保证所有操作都由内核原生异步完成，应以目标平台压测结果选择。

## 9. Netty 架构

```text
Boss EventLoopGroup
  -> Accept Channel
  -> Worker EventLoopGroup
      -> Channel
          -> ChannelPipeline
              -> Inbound Handler
              -> Business Handler
              -> Outbound Handler
```

- EventLoop：单线程处理一组 Channel 的事件和任务。
- Channel：连接或 I/O 资源抽象。
- ChannelPipeline：Handler 组成的双向处理链。
- ChannelHandlerContext：Handler 与 Pipeline 的交互上下文。
- ByteBuf：Netty 字节容器。

一个 Channel 通常始终绑定同一个 EventLoop，因此 Channel 内事件天然串行。不要在 EventLoop 上执行慢 SQL、阻塞 HTTP、文件操作或重 CPU 计算，否则该 EventLoop 上的其他连接一起延迟。

## 10. Netty 服务端

```java
EventLoopGroup boss = new NioEventLoopGroup(1);
EventLoopGroup worker = new NioEventLoopGroup();

try {
    ServerBootstrap bootstrap = new ServerBootstrap();
    bootstrap.group(boss, worker)
            .channel(NioServerSocketChannel.class)
            .childOption(ChannelOption.TCP_NODELAY, true)
            .childOption(ChannelOption.SO_KEEPALIVE, true)
            .childHandler(new ChannelInitializer<SocketChannel>() {
                @Override
                protected void initChannel(SocketChannel channel) {
                    ChannelPipeline pipeline = channel.pipeline();
                    pipeline.addLast(new LengthFieldBasedFrameDecoder(
                            1024 * 1024, 0, 4, 0, 4));
                    pipeline.addLast(new LengthFieldPrepender(4));
                    pipeline.addLast(new BusinessHandler());
                }
            });

    Channel channel = bootstrap.bind(8080).sync().channel();
    channel.closeFuture().sync();
} finally {
    boss.shutdownGracefully().sync();
    worker.shutdownGracefully().sync();
}
```

长度字段协议必须统一字节序、字段位置、是否包含自身长度、最大 Frame 和错误关闭策略。

## 11. ChannelPipeline

Inbound 事件通常从 Pipeline 头向尾传播，Outbound 操作从尾向头传播。

```java
public final class BusinessHandler
        extends SimpleChannelInboundHandler<ByteBuf> {

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, ByteBuf message) {
        ByteBuf response = ctx.alloc().buffer();
        response.writeBytes(message, message.readerIndex(), message.readableBytes());
        ctx.writeAndFlush(response);
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        ctx.close();
    }
}
```

`SimpleChannelInboundHandler` 会自动释放已消费消息。使用普通 `ChannelInboundHandlerAdapter` 时需要明确 Reference Count 所有权，防止泄漏或重复释放。

`@Sharable` 只能用于无状态或线程安全 Handler。一个可变 Handler 实例被多个 Channel 共享会产生并发问题。

## 12. ByteBuf 与引用计数

ByteBuf 使用独立 Reader/Writer Index，无需像 ByteBuffer 一样频繁 `flip()`：

```text
0 <= readerIndex <= writerIndex <= capacity
```

Netty 常使用池化 Direct ByteBuf，并通过 Reference Count 管理生命周期：

```java
ByteBuf retained = input.retainedDuplicate();
try {
    process(retained);
} finally {
    retained.release();
}
```

只有明确拥有引用的一方负责释放。将 ByteBuf 异步传到其他线程前需要 `retain()` 或复制，并在完成后释放。

开发或压测环境可以提高泄漏检测级别：

```bash
-Dio.netty.leakDetection.level=advanced
```

高检测级别有性能成本，不应未经评估长期用于全量生产流量。

## 13. 编解码与协议设计

一个生产协议至少定义：

```text
Magic | Version | Flags | MessageType | RequestId | BodyLength | Body | Checksum
```

- Magic 快速识别错误协议。
- Version 支持兼容演进。
- RequestId 关联请求响应和幂等。
- Length 防止粘包拆包。
- 最大长度保护内存。
- Checksum 检测传输或存储损坏。

反序列化不可信数据时限制类型、深度、集合长度和总字节数。不要使用 Java 原生序列化处理外部输入。

## 14. 背压与流量控制

当生产速度超过网络发送速度时，Channel Outbound Buffer 会积压。持续写入会造成 Direct Memory 增长。

```java
if (!ctx.channel().isWritable()) {
    pauseUpstream();
}
```

通过 `WriteBufferWaterMark`、`channelWritabilityChanged`、有界业务队列和上游限流实现背压。不能只依靠扩大 Buffer。

读取侧可在处理能力不足时临时关闭 `AUTO_READ`，完成后再调用 `read()`，但要设计恢复逻辑，避免连接永久停止读取。

## 15. TLS 与安全

Netty 使用 `SslHandler`：

```java
SslContext sslContext = SslContextBuilder
        .forServer(certificate, privateKey)
        .protocols("TLSv1.3", "TLSv1.2")
        .build();

pipeline.addFirst("ssl", sslContext.newHandler(channel.alloc()));
```

- 私钥放入 Secret/KMS，不写入镜像。
- 校验客户端证书时配置可信 CA 和 mTLS。
- 限制协议与密码套件，并支持证书轮换。
- TLS Handshake 有 CPU 成本，应监控失败率和耗时。
- 应用层仍需认证、授权、防重放和长度限制。

## 16. 虚拟线程与 Netty

Java 21 虚拟线程让阻塞式 Socket/JDBC 编程支持大量并发等待。两种模型：

| 虚拟线程 | Netty |
|---|---|
| 每请求一个轻量线程 | 少量 EventLoop 处理大量连接 |
| 同步代码直观 | 事件驱动、状态机更复杂 |
| 适合普通阻塞业务 | 适合协议、网关、RPC 和极致 I/O 控制 |

Netty EventLoop 本身不能替换成“随意阻塞的虚拟线程”。可以将明确的阻塞业务卸载到虚拟线程 Executor，但要保留并发上限、正确归还结果到 Channel，并压测线程切换和上下文传播成本。

## 17. 性能调优

- EventLoop 数量从默认配置起步，按 CPU 和实际负载压测。
- EventLoop 不执行阻塞或长 CPU 任务。
- 使用池化 ByteBuf，并正确管理引用计数。
- 减少不必要复制，但不要为零拷贝牺牲正确性。
- 批量 Flush 可减少系统调用，但会增加延迟。
- 调整 Socket Buffer 前先确认带宽、RTT 和积压位置。
- 连接数、文件句柄、Direct Memory 和队列必须有上限。
- 观察 P99，而不只看平均吞吐。

## 18. 排障

### 18.1 CPU 飙高

检查 Selector 空轮询、长期 OP_WRITE、EventLoop 业务死循环、编解码异常重试和日志风暴。使用 JFR、线程转储和 EventLoop Pending Task 指标定位。

### 18.2 Direct Memory OOM

检查 ByteBuf 泄漏、发送积压、过大的 Frame、未限制连接和 Direct Memory 上限。启用 Netty Leak Detector 采样，并结合 Native Memory Tracking 与 BufferPool 指标。

### 18.3 连接大量断开

检查 TLS Handshake、Idle Timeout、网关/NAT 超时、心跳、进程 Stop-The-World 和网络丢包。TCP Reset 只是现象，需要关联两端日志与抓包时间线。

### 18.4 消息解析错乱

检查 Length Field 参数、字节序、版本、压缩、字符集和最大长度。TCP 不提供消息边界，不能假设一次 Read 对应一次 Write。

常用工具：

```bash
jcmd <pid> Thread.print
jcmd <pid> VM.native_memory summary
ss -s
ss -antp
lsof -p <pid> | wc -l
```

## 19. 面试高频问题

### 19.1 BIO、NIO 和 AIO 有什么区别

> BIO 调用线程通常阻塞等待 I/O；NIO 使用非阻塞 Channel 和 Selector，由线程主动处理就绪事件；AIO 提交操作后通过 Future 或 Callback 获知完成。具体性能取决于操作系统、协议和实现，不是 API 名称决定一切。

### 19.2 ByteBuffer 的 flip、clear、compact 有什么区别

> `flip` 把写入后的 Position 设为 Limit，并把 Position 归零准备读；`clear` 重置 Position/Limit 准备覆盖写；`compact` 保留未读字节并移动到开头，适合半包后继续读取。

### 19.3 什么是零拷贝

> 零拷贝是减少数据在内核态和用户态之间的复制与上下文切换，例如 FileChannel.transferTo 可能使用 sendfile。它并非真正零次硬件复制，也受操作系统和协议限制。

### 19.4 TCP 为什么有粘包和拆包

> TCP 是有序字节流，没有应用消息边界。发送端缓冲、网络分段和接收端读取大小会让多条消息合并或一条消息拆开，必须通过长度字段、分隔符或固定长度定义 Frame。

### 19.5 Netty 为什么性能高

> Netty 基于事件循环和 I/O 多路复用，用少量线程处理大量连接；提供池化 ByteBuf、批量写、零拷贝能力和成熟协议 Pipeline。但阻塞 EventLoop、内存泄漏或无界队列仍会使性能恶化。

### 19.6 EventLoop 为什么不能执行阻塞操作

> 一个 EventLoop 负责多个 Channel。某个 Handler 阻塞时，同一 EventLoop 上的其他连接都无法及时处理，形成队头阻塞。慢任务应卸载到受控业务 Executor。

### 19.7 ByteBuf 为什么需要引用计数

> 池化 Direct Buffer 不完全依赖 GC 回收，通过引用计数明确复用时机。跨异步边界需要 retain，所有者处理完成后 release；少释放会泄漏，多释放会访问已回收内存。

### 19.8 Netty 与虚拟线程如何选择

> 普通阻塞业务和 JDBC 调用可优先虚拟线程保持同步模型；自定义协议、网关、RPC 和需要精细控制 Buffer/背压时 Netty 更成熟。选择应基于依赖模型、团队能力和压测，而不是并发数字。

## 20. 生产检查清单

- [ ] 文本编码明确，所有资源可靠关闭。
- [ ] 网络协议具有消息边界、版本和最大长度。
- [ ] EventLoop 内没有阻塞 I/O 和长 CPU 任务。
- [ ] ByteBuf 所有权清晰，异步传递正确 retain/release。
- [ ] 读写队列、Frame、连接和 Direct Memory 有上限。
- [ ] 超时、心跳、背压和优雅关闭已实现。
- [ ] TLS、认证、授权和反序列化限制完整。
- [ ] 监控 EventLoop 延迟、队列、连接、流量和内存。
- [ ] 使用 JFR、线程转储和抓包完成过故障演练。

## 21. 学习路线

1. 掌握字节流、字符流、Files 和资源关闭。
2. 理解 Buffer、Channel、Selector 和 TCP 字节流。
3. 使用 Netty Pipeline、Codec 和 ByteBuf 实现协议。
4. 掌握引用计数、背压、超时和 TLS。
5. 对比虚拟线程与事件循环，并通过压测选型。
