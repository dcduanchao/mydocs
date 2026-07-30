# Java 并发编程

## 1. 并发基础

并发是多个任务在同一时间段内推进，并行是多个任务在同一时刻真正执行。单核 CPU 可以并发，多核 CPU 才能提供硬件并行。

Java 并发编程主要解决四类问题：

- **可见性**：一个线程修改的数据，其他线程何时能够看到。
- **原子性**：一个操作是否会被其他线程从中间打断。
- **有序性**：编译器、CPU 和运行时重排序后，结果是否仍然正确。
- **活跃性**：程序是否会发生死锁、活锁、饥饿或长期阻塞。

线程安全不能只靠“测试没出错”判断。并发问题依赖执行时序，必须通过 Java 内存模型、同步规则和共享状态边界证明。

## 术语速览

| 名称 | 含义 |
|---|---|
| JMM | Java Memory Model，定义线程间内存可见性和有序性。 |
| Happens-Before | 判断一个操作结果是否对另一个操作可见的规则。 |
| CAS | Compare And Set，比较期望值后原子更新。 |
| AQS | AbstractQueuedSynchronizer，锁和同步器的基础框架。 |
| Monitor | `synchronized` 使用的对象监视器。 |
| Platform Thread | 平台线程，通常与操作系统线程近似一一对应。 |
| Virtual Thread | 虚拟线程，由 JVM 调度的大量轻量线程。 |
| Carrier Thread | 承载虚拟线程运行的平台线程。 |
| Thread Pool | 复用有限工作线程执行任务的资源池。 |
| Context Switch | 线程切换，需要保存和恢复执行上下文。 |

## 2. 线程创建与生命周期

### 2.1 创建平台线程

优先提交任务给 Executor，不要让业务代码到处直接创建线程。

```java
Runnable task = () -> System.out.println(Thread.currentThread().getName());

Thread thread = new Thread(task, "order-worker");
thread.start();
```

调用 `start()` 才会启动新线程；直接调用 `run()` 只是在当前线程执行普通方法。

### 2.2 线程状态

| 状态 | 说明 |
|---|---|
| `NEW` | 已创建但未启动。 |
| `RUNNABLE` | 可运行，包括正在使用 CPU 和等待 CPU 时间片。 |
| `BLOCKED` | 等待进入 `synchronized` 临界区。 |
| `WAITING` | 无限期等待其他线程唤醒。 |
| `TIMED_WAITING` | 在规定时间内等待。 |
| `TERMINATED` | 执行结束。 |

`BLOCKED` 专指等待 Monitor Lock；等待 `ReentrantLock`、队列或 `Future` 时通常显示为 `WAITING` 或 `TIMED_WAITING`。

### 2.3 中断

中断是一种协作式取消信号，不等于强制停止线程。

```java
public void runTask() {
    while (!Thread.currentThread().isInterrupted()) {
        try {
            processOneBatch();
            Thread.sleep(100);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return;
        }
    }
}
```

捕获 `InterruptedException` 后，如果不能继续向上抛出，应恢复中断标记并尽快结束。吞掉中断会让线程池关闭、请求取消和超时失效。

不要使用已经废弃且不安全的 `Thread.stop()`、`suspend()` 和 `resume()`。

## 3. Java 内存模型

### 3.1 Happens-Before

常用规则：

- 解锁 Happens-Before 后续对同一把锁的加锁。
- 对 `volatile` 变量的写 Happens-Before 后续对它的读。
- `Thread.start()` 前的操作对新线程可见。
- 线程内的操作 Happens-Before 其他线程从 `Thread.join()` 成功返回。
- 规则具有传递性。

Happens-Before 不是物理时间顺序，而是内存可见性保证。

### 3.2 volatile

`volatile` 保证可见性和一定的有序性，但不保证复合操作的原子性。

```java
private volatile boolean stopped;

public void stop() {
    stopped = true;
}

public void run() {
    while (!stopped) {
        doWork();
    }
}
```

下面的代码仍然不安全：

```java
private volatile int count;

public void increment() {
    count++; // 读取、加一、写回，不是原子操作
}
```

计数应使用锁、`AtomicInteger` 或高竞争场景下的 `LongAdder`。

### 3.3 final 和安全发布

对象构造完成后，通过以下方式发布通常是安全的：

- 静态初始化。
- 正确加锁保护的字段。
- `volatile` 或原子引用。
- 并发容器。
- 在线程启动前完成赋值。

不要在构造方法中把 `this` 注册到回调、启动线程或放入全局集合，这会造成对象逸出，其他线程可能看到未初始化完成的状态。

## 4. synchronized

`synchronized` 同时提供互斥、可见性和可重入能力。

```java
public class Account {
    private long balance;

    public synchronized void deposit(long amount) {
        balance += amount;
    }

    public synchronized long balance() {
        return balance;
    }
}
```

同步实例方法锁的是当前对象；同步静态方法锁的是 `Class` 对象；同步代码块锁的是括号中的对象。

```java
synchronized (lock) {
    // 只保护必要的共享状态
}
```

锁对象应为 `private final`，不要使用字符串常量、包装类型或可被外部代码获取的对象，避免无关代码意外竞争同一把锁。

### 4.1 wait、notify 和 notifyAll

它们必须在持有同一对象 Monitor 时调用。等待条件要用 `while` 重新检查，防止虚假唤醒和条件被其他线程抢先改变。

```java
synchronized (lock) {
    while (queue.isEmpty()) {
        lock.wait();
    }
    Task task = queue.removeFirst();
}
```

工程代码优先使用 `BlockingQueue`、`CountDownLatch`、`Condition` 等高级工具，减少手写等待协议。

## 5. Lock 与 AQS

### 5.1 ReentrantLock

`ReentrantLock` 支持可中断获取、限时等待、公平锁和多个 Condition。

```java
private final ReentrantLock lock = new ReentrantLock();

public void update() {
    lock.lock();
    try {
        updateState();
    } finally {
        lock.unlock();
    }
}
```

使用 `lock()` 后必须在 `finally` 中释放。需要避免无限等待时使用：

```java
if (lock.tryLock(500, TimeUnit.MILLISECONDS)) {
    try {
        updateState();
    } finally {
        lock.unlock();
    }
} else {
    throw new BusyException("system busy");
}
```

公平锁能降低长期饥饿概率，但通常吞吐量更低。除非业务明确要求，不要默认开启公平模式。

### 5.2 ReadWriteLock 和 StampedLock

`ReentrantReadWriteLock` 适合读多写少且临界区较重的场景。读操作极短时，锁管理成本可能高于普通互斥锁。

`StampedLock` 支持乐观读，但不可重入，使用复杂，忘记校验 Stamp 会得到错误数据。一般业务代码先使用不可变对象、普通锁或并发容器。

### 5.3 AQS

AQS 使用一个同步状态和等待队列构建锁与同步器。`ReentrantLock`、`Semaphore`、`CountDownLatch` 等都基于它实现。

面试时不必背全部源码，但应理解：

```text
尝试修改 state
  -> 成功：获得资源
  -> 失败：进入等待队列
  -> 前驱释放资源
  -> 唤醒后再次竞争
```

## 6. CAS 与原子类

```java
AtomicInteger counter = new AtomicInteger();
counter.incrementAndGet();

AtomicReference<State> state = new AtomicReference<>(initialState);
state.compareAndSet(initialState, newState);
```

CAS 避免了阻塞锁，但不等于没有成本。高竞争下线程会不断失败重试，造成 CPU 消耗。

常见问题：

- **ABA**：值从 A 变成 B 又变回 A，单纯比较值无法感知过程；可使用 `AtomicStampedReference` 携带版本。
- **复合约束**：多个变量需要共同保持不变量时，单个原子类难以保证一致性，通常应使用锁或不可变快照。
- **高竞争计数**：统计型计数可使用 `LongAdder` 分散竞争，但它的 `sum()` 不是并发时刻的强一致快照。

## 7. 并发容器

### 7.1 ConcurrentHashMap

```java
ConcurrentHashMap<String, LongAdder> counters = new ConcurrentHashMap<>();
counters.computeIfAbsent("success", key -> new LongAdder()).increment();
```

单次 `get`、`put`、`compute` 等操作是线程安全的，但多个独立操作组合后不一定原子。优先使用 `compute`、`merge`、`putIfAbsent` 等复合 API。

`computeIfAbsent` 的计算函数应快速、无阻塞且避免递归修改同一个 Map，否则可能扩大锁竞争或引发异常。

### 7.2 CopyOnWriteArrayList

适合读非常多、写非常少、集合规模较小的监听器或配置快照。每次写入都会复制底层数组，不适合频繁更新或大集合。

### 7.3 BlockingQueue

```java
BlockingQueue<Task> queue = new ArrayBlockingQueue<>(1000);

boolean accepted = queue.offer(task, 200, TimeUnit.MILLISECONDS);
Task next = queue.take();
```

有界队列能形成背压。无界队列在消费者变慢时可能持续占用内存，最终 OOM。

常用选择：

| 容器 | 场景 |
|---|---|
| `ArrayBlockingQueue` | 有界、容量固定的生产消费模型。 |
| `LinkedBlockingQueue` | 可设置容量，节点对象开销较大。 |
| `SynchronousQueue` | 不保存元素，生产者直接交给消费者。 |
| `DelayQueue` | 基于到期时间获取延迟任务。 |
| `ConcurrentLinkedQueue` | 非阻塞无界队列，不提供等待能力。 |

## 8. 线程池

### 8.1 ThreadPoolExecutor

```java
ThreadPoolExecutor executor = new ThreadPoolExecutor(
        8,
        16,
        60,
        TimeUnit.SECONDS,
        new ArrayBlockingQueue<>(500),
        runnable -> {
            Thread thread = new Thread(runnable);
            thread.setName("order-worker-" + thread.threadId());
            return thread;
        },
        new ThreadPoolExecutor.CallerRunsPolicy());
```

执行流程：

```text
任务到达
  -> 未达到 corePoolSize：创建核心线程
  -> 核心线程已满：进入工作队列
  -> 队列已满且未达到 maximumPoolSize：创建非核心线程
  -> 线程数和队列都达到上限：执行拒绝策略
```

线程池核心参数必须根据任务特征、下游容量和服务延迟设计，不能只抄固定公式。

### 8.2 拒绝策略

| 策略 | 行为 |
|---|---|
| `AbortPolicy` | 抛出异常，默认策略。 |
| `CallerRunsPolicy` | 由提交线程执行，形成一定背压。 |
| `DiscardPolicy` | 静默丢弃，不适合不能丢任务的业务。 |
| `DiscardOldestPolicy` | 丢弃队列头任务后重试。 |

自定义拒绝策略至少要记录指标、任务类型和拒绝原因。`CallerRunsPolicy` 可能让 HTTP 请求线程执行耗时任务，必须评估超时链路。

### 8.3 线程数量

- CPU 密集：线程数通常接近可用 CPU 核数。
- I/O 密集：可适当增加线程，但必须受连接池、内存和下游容量限制。
- 混合任务：拆分独立线程池，避免慢 I/O 占满 CPU 任务的线程。

不同业务不要无差别共用一个线程池。导出、通知、核心交易和定时任务应根据隔离需求分别配置。

### 8.4 关闭线程池

```java
executor.shutdown();
try {
    if (!executor.awaitTermination(30, TimeUnit.SECONDS)) {
        executor.shutdownNow();
    }
} catch (InterruptedException e) {
    executor.shutdownNow();
    Thread.currentThread().interrupt();
}
```

`shutdownNow()` 只是发送中断并返回尚未开始的任务，不能保证正在运行的任务立即结束。

## 9. CompletableFuture

```java
CompletableFuture<User> userFuture = CompletableFuture.supplyAsync(
        () -> userService.get(userId), ioExecutor);

CompletableFuture<List<Order>> orderFuture = CompletableFuture.supplyAsync(
        () -> orderService.list(userId), ioExecutor);

UserOverview overview = userFuture
        .thenCombine(orderFuture, UserOverview::new)
        .orTimeout(2, TimeUnit.SECONDS)
        .exceptionally(ex -> fallback(userId, ex))
        .join();
```

注意事项：

- 显式指定业务线程池，避免阻塞任务占满公共 `ForkJoinPool`。
- 每个外部调用都设置超时，不能只给最终 `join()` 设置业务超时。
- 异常可能包装在 `CompletionException` 中，需要保留原始原因。
- 任务取消不一定能终止底层 HTTP 或数据库调用。
- 异步链路仍要传递日志上下文、Trace 和安全上下文。

`thenApply` 用于同步转换，`thenCompose` 用于串联另一个异步任务，`thenCombine` 用于合并两个独立结果。

## 10. 虚拟线程

### 10.1 什么是虚拟线程

虚拟线程在 Java 21 正式发布。它由 JVM 调度，执行时挂载到少量 Carrier Thread 上；遇到大多数阻塞 I/O 时会卸载，让 Carrier Thread 执行其他虚拟线程。

```text
大量 Virtual Thread
        -> JVM Scheduler
        -> 少量 Carrier Platform Thread
        -> CPU
```

虚拟线程降低的是“线程等待”的成本，让同步阻塞代码也能支持大量并发 I/O。它不会让 CPU 计算变快，也不会增加数据库连接、HTTP 连接或下游服务容量。

### 10.2 创建虚拟线程

```java
Thread.startVirtualThread(() -> handleRequest());
```

```java
Thread thread = Thread.ofVirtual()
        .name("order-query-", 0)
        .start(() -> handleRequest());
```

每个任务一个虚拟线程：

```java
try (ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor()) {
    Future<User> user = executor.submit(() -> userService.get(userId));
    Future<List<Order>> orders = executor.submit(() -> orderService.list(userId));

    return new UserOverview(user.get(), orders.get());
}
```

`newVirtualThreadPerTaskExecutor()` 不复用虚拟线程，而是为每个任务创建新虚拟线程。虚拟线程足够轻量，通常不需要池化。

### 10.3 Spring Boot 开启虚拟线程

Spring Boot 3.2+ 配合 Java 21+ 可以开启：

```yaml
spring:
  threads:
    virtual:
      enabled: true
```

开启后，Spring Boot 支持的 Web 容器和任务执行器会使用虚拟线程。上线前仍应验证当前 Spring Boot 版本、Web 容器、数据库驱动、HTTP 客户端和监控组件是否兼容。

虚拟线程属于守护线程，不会单独阻止 JVM 退出。非 Web 应用如果只有虚拟线程工作，可以配置：

```yaml
spring:
  main:
    keep-alive: true
```

### 10.4 适用场景

适合：

- HTTP/RPC 请求中包含较多阻塞 I/O。
- JDBC、文件和网络调用并发量高。
- 希望保留顺序清晰的同步编程模型。
- 平台线程大量阻塞，线程池和上下文切换成本明显。

不一定适合：

- 纯 CPU 密集计算。
- 已经使用成熟非阻塞事件循环且没有线程阻塞问题。
- 大量任务长期占用本地内存或 `ThreadLocal` 大对象。
- 依赖库在关键路径执行不可卸载的阻塞操作。

### 10.5 虚拟线程仍要限流

不能因为可以创建百万级虚拟线程，就同时向数据库发出百万个请求。外部资源必须单独限制并发。

```java
private final Semaphore databasePermits = new Semaphore(100);

public Product loadProduct(long id) throws InterruptedException {
    if (!databasePermits.tryAcquire(500, TimeUnit.MILLISECONDS)) {
        throw new BusyException("database concurrency limit reached");
    }
    try {
        return productRepository.findById(id);
    } finally {
        databasePermits.release();
    }
}
```

JDBC 还受连接池大小约束。虚拟线程在等待连接时成本更低，但连接池过小仍会增加延迟，连接池过大仍会压垮数据库。

### 10.6 Pinning

虚拟线程执行某些操作时可能无法从 Carrier Thread 卸载，这称为 Pinning。长时间 Pinning 会降低扩展性。

- JDK 21～23 中，在 `synchronized` 内执行阻塞操作可能造成 Pinning。
- JDK 24+ 已改进 `synchronized` 对虚拟线程的支持，普通 Monitor 阻塞通常不再造成这类 Pinning。
- 本地方法、外部函数调用或部分底层库仍可能造成 Pinning，应通过 JFR 和压测确认。

对仍运行 JDK 21～23 的系统，不要在长时间 `synchronized` 临界区中执行网络或文件 I/O；可缩小临界区，或在确有需要时改用 `ReentrantLock`。

不要为了虚拟线程机械地把所有 `synchronized` 替换成 `ReentrantLock`。锁语义、JDK 版本和实际 Pinning 数据才是修改依据。

### 10.7 ThreadLocal

虚拟线程支持 `ThreadLocal`，但每个请求一个虚拟线程时，巨量线程上的大对象会显著增加内存占用。

- `ThreadLocal` 中只保存必要的小型上下文。
- 使用完调用 `remove()`，特别是平台线程池场景。
- 不要在线程本地缓存昂贵对象或连接。
- 新项目可评估当前 JDK 的 `ScopedValue`，用于只读上下文传递。

### 10.8 虚拟线程与线程池对比

| 对比项 | 平台线程池 | 虚拟线程 |
|---|---|---|
| 调度者 | 操作系统为主 | JVM 调度到 Carrier Thread |
| 创建成本 | 较高 | 很低 |
| 常用模型 | 固定线程处理大量任务 | 每个任务一个虚拟线程 |
| 阻塞 I/O | 占用平台线程 | 多数情况可卸载 |
| CPU 密集任务 | 线程数接近 CPU 核数 | 不会获得额外算力 |
| 并发控制 | 线程池大小和队列 | Semaphore、连接池、限流器 |

虚拟线程主要提升吞吐和代码可读性，不保证单个请求延迟更低。迁移前后应对吞吐、P95/P99 延迟、CPU、内存、数据库连接等待和下游错误率做对比压测。

## 11. 并发协调工具

### 11.1 CountDownLatch

等待一组任务完成，一次性使用：

```java
CountDownLatch latch = new CountDownLatch(3);

executor.execute(() -> {
    try {
        loadData();
    } finally {
        latch.countDown();
    }
});

if (!latch.await(2, TimeUnit.SECONDS)) {
    throw new TimeoutException("load timeout");
}
```

### 11.2 Semaphore

控制同时访问稀缺资源的任务数量。必须在 `finally` 中释放，并注意只有成功获取后才能释放。

### 11.3 CyclicBarrier 和 Phaser

- `CyclicBarrier`：一组线程互相等待到达同一屏障，可以重复使用。
- `Phaser`：支持多阶段和动态注册参与者，适合复杂分阶段任务。

### 11.4 Exchanger

允许两个线程在同步点交换数据，使用场景较少。普通生产消费模型通常优先使用 `BlockingQueue`。

## 12. ThreadLocal

```java
private static final ThreadLocal<String> TRACE_ID = new ThreadLocal<>();

public void handle(String traceId) {
    TRACE_ID.set(traceId);
    try {
        process();
    } finally {
        TRACE_ID.remove();
    }
}
```

线程池会复用平台线程。如果不清理 ThreadLocal，下一个请求可能读到上一个请求的数据，也可能因 Value 长期被线程引用导致内存泄漏。

`InheritableThreadLocal` 只在线程创建时复制值，在线程池中通常不符合请求上下文传播需求。跨线程传播应使用框架提供的 Context Propagation 或显式参数。

## 13. 常见并发设计

### 13.1 不可变对象

不可变对象不需要同步，是并发设计的首选。字段使用 `final`，构造完成后不暴露可变内部集合。

```java
public record UserSnapshot(long id, String name, List<String> roles) {
    public UserSnapshot {
        roles = List.copyOf(roles);
    }
}
```

### 13.2 减少共享状态

- 方法局部变量优于共享字段。
- 消息传递优于多个线程共同修改复杂对象。
- 按 Key 分片处理可以把并发写转换为分区内串行写。
- 必须共享时，明确由哪一把锁或哪个并发容器保护。

### 13.3 双重检查单例

```java
public final class ClientHolder {
    private static volatile Client instance;

    public static Client getInstance() {
        Client result = instance;
        if (result == null) {
            synchronized (ClientHolder.class) {
                result = instance;
                if (result == null) {
                    result = new Client();
                    instance = result;
                }
            }
        }
        return result;
    }
}
```

更简单的单例通常使用静态内部类或枚举。双重检查中的 `volatile` 不能省略，否则可能看到尚未完成初始化的对象。

### 13.4 缓存重建

热点缓存失效后只允许一个线程回源，其余线程短暂等待或返回旧值。等待必须有超时，锁内再次检查缓存，释放锁必须确认锁的所有者。跨进程场景不能使用本地 `synchronized` 代替分布式协调。

## 14. 死锁与活跃性

### 14.1 死锁条件

死锁通常同时满足：

1. 互斥。
2. 持有并等待。
3. 不可抢占。
4. 循环等待。

通过固定加锁顺序、减少嵌套锁、使用 `tryLock` 超时和缩小临界区降低风险。

```java
Account first = left.id() < right.id() ? left : right;
Account second = left.id() < right.id() ? right : left;

synchronized (first) {
    synchronized (second) {
        transfer(left, right, amount);
    }
}
```

### 14.2 活锁和饥饿

- **活锁**：线程不断响应彼此变化，但始终无法完成工作，例如双方持续同时退让。
- **饥饿**：某些线程长期得不到 CPU、锁或队列处理机会。

随机退避、公平调度、限制高优先级任务和缩短锁持有时间可以改善这些问题。

## 15. 监控与排障

常用工具：

```bash
# 查看 Java 进程
jcmd -l

# 传统线程转储
jstack <pid> > threads.txt

# JDK 21+，适合包含大量虚拟线程的线程转储
jcmd <pid> Thread.dump_to_file -format=json threads.json

# 查看 JVM 运行信息
jcmd <pid> VM.info

# 启动 60 秒 JFR
jcmd <pid> JFR.start name=concurrency settings=profile duration=60s filename=concurrency.jfr
```

### 15.1 CPU 飙高

1. 使用操作系统工具找到高 CPU Java 进程和线程。
2. 将线程 ID 转为十六进制，在线程转储中定位 `nid`。
3. 多次采样，确认线程持续运行而不是瞬时尖峰。
4. 检查死循环、CAS 自旋、正则、序列化、GC 和过量日志。

### 15.2 接口大量等待

检查线程转储中的共同等待点：数据库连接池、HTTP 连接池、锁、队列、`Future.get()` 或下游调用。增加线程数可能让更多请求一起阻塞，必须先确认真正瓶颈。

### 15.3 死锁

`jstack` 通常会报告 Java Monitor Deadlock。保留完整线程转储，找到持有锁与等待锁的循环关系，再统一加锁顺序或消除嵌套锁。

### 15.4 虚拟线程排查

- 使用 JFR 观察 Virtual Thread Pinning、启动和提交失败等事件。
- 监控 Carrier Thread 利用率、CPU、内存和外部连接池等待。
- 大量虚拟线程时使用 JSON Thread Dump，避免传统转储难以阅读。
- Pinning 是性能信号，不等于数据正确性问题，应定位长时间阻塞的调用栈。

## 16. 面试高频问题

### 16.1 synchronized 和 ReentrantLock 有什么区别

> 两者都提供互斥、可见性和可重入。`synchronized` 语法简单，由 JVM 自动释放；`ReentrantLock` 支持可中断获取、限时等待、公平模式和多个 Condition，但必须在 `finally` 中手动释放。选择依据是功能需求，不应简单认为其中一个性能一定更高。

### 16.2 volatile 能保证线程安全吗

> `volatile` 保证可见性并限制相关重排序，但不能让 `count++` 这样的读改写复合操作原子化。状态标记和单次读写适合使用 `volatile`，计数或多个字段的一致性通常需要原子类或锁。

### 16.3 CAS 有什么问题

> CAS 在低竞争时避免阻塞，但高竞争会频繁失败和自旋，消耗 CPU；还存在 ABA 问题，并且难以维护多个变量的复合约束。可使用版本戳、分段计数，或在复杂临界区使用锁。

### 16.4 为什么不建议直接使用 Executors 创建固定线程池

> 某些快捷工厂使用无界队列或可无限创建线程，持续堆积任务可能导致 OOM。生产环境应显式配置核心线程、最大线程、有界队列、线程工厂和拒绝策略，并监控活跃线程、队列和拒绝数。

### 16.5 ThreadLocal 为什么可能内存泄漏

> ThreadLocalMap 的 Key 是弱引用，但 Value 仍被线程强引用。线程池中的线程长期存活，如果业务不调用 `remove()`，Value 可能一直无法回收，还会污染后续请求。因此应在 `finally` 中清理。

### 16.6 虚拟线程和平台线程有什么区别

> 平台线程主要由操作系统调度，创建和上下文切换成本较高；虚拟线程由 JVM 调度到少量 Carrier Thread，创建成本低，大多数阻塞 I/O 时可以卸载。虚拟线程适合高并发阻塞 I/O，但不会提升 CPU 密集计算能力。

### 16.7 虚拟线程是否还需要线程池

> 通常不需要池化虚拟线程，应采用每任务一个虚拟线程。线程池原本既复用昂贵平台线程，也限制并发；使用虚拟线程后，外部资源的并发限制应交给 Semaphore、连接池或限流器，而不是通过减少虚拟线程数量间接控制。

### 16.8 虚拟线程能否解决数据库性能问题

> 不能。虚拟线程只降低等待线程的成本，数据库连接数、锁、CPU 和 I/O 能力没有增加。如果不限制并发，反而可能更快压垮数据库。必须保留连接池、超时、限流和降级策略。

### 16.9 什么是虚拟线程 Pinning

> Pinning 是虚拟线程阻塞时无法从 Carrier Thread 卸载。JDK 21～23 中常见原因是在 `synchronized` 内阻塞；JDK 24+ 已显著改进 Monitor 场景，但本地方法等仍可能 Pin。应通过 JFR 和压测定位，而不是机械替换全部锁。

### 16.10 sleep 和 wait 有什么区别

> `Thread.sleep()` 不要求持有锁，等待期间不会释放已持有的 Monitor；`Object.wait()` 必须在持有目标 Monitor 时调用，调用后会释放该 Monitor，并等待通知或超时后重新竞争锁。

### 16.11 如何设置线程池大小

> CPU 密集任务通常接近 CPU 核数；I/O 密集任务可以更多，但上限受连接池、下游容量、内存和延迟目标约束。实际值应通过压测并观察 CPU、队列等待、拒绝数和 P99 延迟确定，而不是只套公式。

### 16.12 CompletableFuture 有哪些常见问题

> 默认公共线程池可能被阻塞任务占满；异常经常被包装；超时和取消不一定终止底层调用；ThreadLocal 上下文也不会自动传播。工程上应指定隔离线程池、设置调用级超时、处理异常并接入上下文传播。

## 17. 生产环境检查清单

- [ ] 共享状态有明确的锁、原子变量或并发容器保护。
- [ ] 锁对象不暴露，锁内不执行不必要的慢 I/O。
- [ ] 线程池使用有界队列、命名线程、拒绝策略和监控。
- [ ] 异步任务有超时、取消、异常处理和上下文传播。
- [ ] 捕获 `InterruptedException` 后正确传播或恢复中断。
- [ ] ThreadLocal 在 `finally` 中清理，不保存大对象。
- [ ] 数据库、HTTP 和消息系统调用都有并发上限。
- [ ] 虚拟线程迁移经过驱动兼容性与真实流量压测。
- [ ] 监控活跃线程、队列、拒绝、锁等待、连接池和 P99 延迟。
- [ ] 具备线程转储、JFR 和死锁排查流程。

## 18. 学习路线

1. 掌握线程状态、中断、JMM 和 Happens-Before。
2. 理解 `synchronized`、`volatile`、CAS 和原子类。
3. 使用 Lock、AQS 同步器和并发容器。
4. 掌握 ThreadPoolExecutor 和 CompletableFuture。
5. 学习 Java 21+ 虚拟线程并完成阻塞 I/O 压测。
6. 理解不可变对象、任务隔离、背压和并发限流。
7. 使用线程转储、JFR 和监控数据排查生产问题。
