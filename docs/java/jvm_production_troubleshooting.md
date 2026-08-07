# JVM 生产故障排查

## 1. 排障原则

JVM 故障排查的目标不是“先重启恢复”，而是在尽量保留现场的前提下回答：

```text
什么资源耗尽 -> 哪个线程/请求消耗 -> 为什么没有被限制 -> 如何恢复和避免复发
```

常见资源：CPU、Java Heap、Metaspace、Direct Memory、线程、文件句柄、连接池、磁盘和网络。

生产排障顺序：

1. 确认影响范围、开始时间、版本和发布变更。
2. 检查实例健康、流量、错误率和依赖状态。
3. 保留线程、GC、JFR、日志和系统指标现场。
4. 采取最小恢复动作，例如摘流、限流、扩容或回滚。
5. 用证据定位根因，修复后验证并补充监控和测试。

不要在没有采样和备份的情况下连续重启、强制 Full GC、删除日志或生成多个 Heap Dump。

## 2. JVM 内存区域

| 区域 | 内容 | 常见问题 |
|---|---|---|
| Heap | 对象实例和数组 | OOM、频繁 GC、内存泄漏。 |
| Metaspace | 类元数据 | 动态类生成、类加载器泄漏。 |
| Code Cache | JIT 编译代码 | 过小导致编译受限。 |
| Thread Stack | 每线程栈帧 | 线程过多、StackOverflow。 |
| Direct Memory | 堆外 Buffer | Netty/JDBC 泄漏、容量耗尽。 |
| Native Memory | JVM、库和线程本地内存 | 容器 OOM 但 Heap 正常。 |

`-Xmx` 只限制 Java Heap，不等于进程总内存。容器限制应覆盖 Heap、Metaspace、线程栈、Direct Memory、Code Cache 和 Native Memory。

## 3. 现场信息

```bash
jcmd -l
jcmd <pid> VM.command_line
jcmd <pid> VM.flags
jcmd <pid> VM.info
jcmd <pid> GC.heap_info
jcmd <pid> Thread.print -l
jcmd <pid> GC.class_histogram
```

JDK 版本、启动参数和进程 PID 必须一并记录。容器环境先确认 PID 命名空间和时区，宿主机 PID 不一定等于容器内 PID。

系统层面：

```bash
top -H -p <pid>
ps -o pid,ppid,%cpu,%mem,nlwp,cmd -p <pid>
free -m
df -h
ulimit -n
ss -s
```

多次采样比单次快照更可靠。线程转储和指标要与同一时间窗口的请求日志、GC 日志和依赖监控对齐。

## 4. CPU 飙高

### 4.1 排查流程

1. `top -H -p PID` 找到持续高 CPU 的线程 ID。
2. 将线程 ID 转为十六进制。
3. 连续获取 3～5 次线程转储。
4. 根据 `nid=0x...` 定位 Java 栈。
5. 区分业务死循环、锁自旋、GC、JIT、正则、序列化和日志。

```bash
printf '%x\n' <thread_id>
jstack <pid> > /tmp/thread-1.txt
jstack <pid> > /tmp/thread-2.txt
```

Windows 可使用 `jcmd`、JFR 或任务管理器配合线程转储，命令名称和 PID 规则不同。

### 4.2 常见根因

- 无界循环、错误重试或异常日志风暴。
- 大量正则回溯、JSON 序列化和压缩。
- 高竞争 CAS 自旋或锁自旋。
- Full GC、类加载和 JIT 编译。
- SQL 变慢后大量业务线程同时计算或重试。
- Netty EventLoop 中执行重 CPU 任务。

只提高 CPU 配额可能掩盖算法或流量控制问题。修复应同时考虑入口限流、下游保护和线程池隔离。

## 5. Java Heap 与 OOM

### 5.1 常见 OOM

| 异常 | 可能原因 |
|---|---|
| `Java heap space` | Heap 中无法分配对象，泄漏或瞬时大对象。 |
| `GC overhead limit exceeded` | 大部分时间在 GC，回收效果很差。 |
| `OutOfMemoryError: Metaspace` | 类元数据持续增长。 |
| `Direct buffer memory` | 堆外 Buffer 超限或未释放。 |
| `unable to create native thread` | 线程数量、栈内存或系统限制不足。 |
| `Killed`/容器 OOM | 进程总内存超过 cgroup 限制，JVM 未必抛 Java 异常。 |

### 5.2 Heap Dump

```bash
jcmd <pid> GC.heap_dump /safe/path/heap-$(date +%s).hprof
```

Heap Dump 可能等于数 GB 并造成停顿，先确认磁盘、敏感数据和暂停预算。优先使用故障时自动转储：

```text
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/log/jvm
```

分析重点：

- Dominator Tree 中占用最大的对象。
- GC Roots 到对象的引用链。
- Map、缓存、队列和 ThreadLocal 是否无界。
- 是否存在重复字符串、过大数组和请求体。
- ClassLoader 是否持有大量类。

Shallow Size 只是对象本身大小，Retained Size 才更接近释放该对象后可以回收的总量。

### 5.3 内存泄漏模式

- 静态 Map 或缓存没有容量和 TTL。
- 线程池线程中的 ThreadLocal 未清理。
- 监听器、回调和 ClassLoader 未注销。
- 连接、文件和 ByteBuf 未释放。
- 队列生产速度长期超过消费速度。
- ThreadLocal Value 持有大对象，线程又长期存活。

## 6. GC 排查

### 6.1 观察指标

```bash
jstat -gcutil <pid> 1000 10
jcmd <pid> GC.heap_info
jcmd <pid> VM.native_memory summary
```

关注 Young GC 频率、Pause 时间、Old 区增长、晋升失败、Full GC 和分配速率。平均停顿不代表用户体验，重点看 P99 和请求超时窗口。

### 6.2 GC 日志

JDK 9+ 常用：

```text
-Xlog:gc*,safepoint:file=/var/log/jvm/gc.log:time,uptime,level,tags:filecount=10,filesize=100M
```

不要只通过调整堆大小解决 GC。需要区分：

- 短命对象分配过快。
- 大对象直接进入老年代。
- 缓存或集合长期持有对象。
- 老年代空间不足。
- GC 线程被 CPU 争抢。
- Safepoint 到达或退出耗时。

生产使用 G1、ZGC 等收集器应以 JDK 版本、Heap 大小和延迟目标为依据。切换收集器必须压测，不要根据单次测试结论全量修改。

### 6.3 Safepoint

Safepoint 是 JVM 能安全暂停或执行某些操作的点。停顿长但 GC 时间短时，检查应用线程到达 Safepoint 的时间、JNI、反优化和锁状态。

```bash
jcmd <pid> VM.flags | findstr Safepoint
```

## 7. 线程与死锁

### 7.1 线程数

进程线程内存大致受以下因素影响：

```text
线程数量 × Xss + Native Thread 元数据 + 业务栈对象
```

检查线程总数、线程状态和线程名：

```bash
jcmd <pid> Thread.print > threads.txt
grep -c '^"' threads.txt
```

线程池不要无界创建；平台线程、虚拟线程、数据库连接和外部服务并发分别设置上限。

### 7.2 死锁

`jstack` 或 `jcmd Thread.print -l` 可能直接报告 Java Monitor Deadlock。重点寻找：

```text
线程 A 持有锁 1，等待锁 2
线程 B 持有锁 2，等待锁 1
```

`ReentrantLock`、数据库锁和分布式锁不一定显示为 JVM Monitor Deadlock，需要结合应用指标、数据库锁表和分布式锁日志。

修复方式：统一加锁顺序、减少嵌套锁、使用限时 `tryLock`、缩短临界区和消除共享状态。

### 7.3 线程状态解释

- `RUNNABLE` 不一定正在使用 CPU，可能在本地调用或等待内核。
- `BLOCKED` 通常等待进入 `synchronized`。
- `WAITING` 可能等待队列、Future、Condition 或 join。
- 大量 `TIMED_WAITING` 需要进一步看调用栈，可能是正常线程池等待，也可能是超时堆积。

## 8. JFR

JFR 是低开销的 JVM 事件记录工具，适合生产短时间诊断：

```bash
jcmd <pid> JFR.start name=incident settings=profile \
    duration=120s filename=/safe/path/incident.jfr
```

重点事件：

- CPU Hot Methods、Execution Sample。
- Garbage Collection、Heap Summary 和 Allocation。
- Java Monitor Blocked、Thread Park。
- Socket Read/Write、File Read/Write。
- Exception、Class Loading 和 Safepoint。
- 虚拟线程提交、启动和 Pinning。

JFR 文件可能包含 URL、类名、参数摘要和业务路径，传输和存储需要脱敏与权限控制。

## 9. Arthas

Arthas 适合不重启进程查看调用栈、参数和方法耗时：

```bash
java -jar arthas-boot.jar <pid>
```

常用命令：

```text
dashboard       查看 CPU、内存、线程
thread -n 5     查看最忙线程
thread -b       查看阻塞线程
stack Class method   查看调用路径
trace Class method   查看耗时分解
watch Class method '{params,returnObj,throwExp}' -x 2
sc -d ClassName     查看类加载信息
```

生产执行 `watch`、`trace` 和 `tt` 要限制次数、条件和输出深度，避免诊断工具本身产生额外负载或泄露敏感数据。动态改变代码或类必须有审批、回滚和记录。

## 10. Metaspace 与类加载器泄漏

动态代理、脚本、热部署和重复创建 ClassLoader 可能导致 Metaspace 持续增长。

```bash
jcmd <pid> VM.classloader_stats
jcmd <pid> GC.class_histogram
```

检查：

- 每次部署是否创建未释放的 WebAppClassLoader。
- ThreadLocal、线程、Timer、监听器是否持有旧 ClassLoader。
- CGLIB、Byte Buddy 和脚本动态生成的类是否无界。
- JDBC Driver、日志 Handler 和 SPI 是否注销。

重启只能释放泄漏的旧 ClassLoader，不能替代修复引用链。

## 11. Direct Memory 与容器 OOM

Netty、NIO、压缩、TLS 和 JDBC 可能使用堆外内存。Heap 正常但容器被 OOM Kill 时，检查：

```bash
jcmd <pid> VM.native_memory summary
jcmd <pid> PerfCounter.print
```

JVM 启动参数可以限制：

```text
-XX:MaxDirectMemorySize=1G
-Xss512k
```

限制值必须与连接数、Buffer 大小、请求并发和容器内存一起计算。只调大 `MaxDirectMemorySize` 可能让进程更接近 cgroup 上限。

## 12. 连接池与线程池排查

接口超时不一定是 JVM 慢，常见等待链：

```text
HTTP 请求线程
  -> 等待业务线程池
  -> 等待数据库连接池
  -> 等待数据库锁
  -> 等待下游 HTTP 连接
```

监控每个池的活跃数、空闲数、队列、获取耗时、超时和拒绝数。不要所有业务共用一个无界线程池，也不要通过无限扩大池大小掩盖下游容量不足。

## 13. 线上参数原则

- Heap 初始值与最大值是否相同取决于容器和收集器策略，不能机械照抄。
- `-Xms`、`-Xmx`、Direct Memory、Metaspace 和线程栈总量必须小于容器限制并留出安全余量。
- 生产开启 GC 日志滚动、OOM Dump 和 JFR 预配置。
- 不在线上临时删除 OOM 文件、GC 日志或 Heap Dump 之前的唯一证据。
- 变更 JVM 参数需经过压测、灰度和回滚验证。

## 14. 典型事故流程

### 14.1 OOM

```text
保留错误日志和指标
 -> 确认 Heap/Native/Direct/容器类型
 -> 取得 Dump 或 JFR
 -> 限流、摘流或扩容
 -> 分析 Retained Size 和引用链
 -> 修复无界缓存/队列/资源泄漏
```

### 14.2 Full GC 延迟

先确认是否持续分配、Old 区泄漏、晋升过快、堆过小或大对象。临时扩容只能恢复服务，应在低峰完成 Dump 和分配分析。

### 14.3 请求超时

关联入口 P99、线程池、连接池、GC Pause、锁等待、下游延迟和网络错误。不要只通过增加 HTTP 超时把失败推迟到更深层。

## 15. 面试高频问题

### 15.1 Java Heap 之外还有什么内存

> 还有 Metaspace、Code Cache、线程栈、Direct Memory 和 JVM/本地库使用的 Native Memory。容器 OOM 不能只看 `-Xmx` 和 Heap Dump。

### 15.2 如何排查 CPU 飙高

> 先用 top -H 找高 CPU 线程，记录多次采样，把线程 ID 转为十六进制后在线程转储中定位调用栈；再结合 JFR 判断死循环、GC、锁自旋、序列化或重试风暴，并保留现场后采取限流或摘流。

### 15.3 如何排查内存泄漏

> 比较多次 Heap Dump 的对象增长，使用 Dominator Tree 和 GC Roots 找出长期持有对象，重点检查静态集合、缓存、队列、ThreadLocal、监听器和 ClassLoader。区分真正泄漏与业务高峰的正常短期增长。

### 15.4 Full GC 的常见原因

> 老年代空间不足、对象晋升过快、显式 GC、Metaspace 压力、分配失败或堆过小都可能触发。要结合 GC 日志、Old 区曲线、分配速率和对象存活情况判断，不能只调大堆。

### 15.5 为什么 Heap 正常但容器 OOM

> 进程总内存还包括 Direct Memory、线程栈、Metaspace、Code Cache、JNI 和本地库。容器按 cgroup 总量杀进程，因此要使用 Native Memory Tracking、BufferPool 指标和系统监控分析。

### 15.6 jstack、jcmd、JFR 和 Arthas 如何选择

> jstack/jcmd 适合快速获取线程、堆和 JVM 状态；JFR 适合低开销记录一段时间的 CPU、GC、锁和 I/O 事件；Arthas 适合在线查看特定类方法调用，但需要限制诊断命令的频率和输出。

## 16. 生产检查清单

- [ ] 记录 Java、JVM、容器和启动参数版本。
- [ ] GC 日志、OOM Dump、线程转储和 JFR 能够获取。
- [ ] Heap、Metaspace、Direct Memory、线程和 Native Memory 有监控。
- [ ] 线程池、连接池、队列和缓存有界并有告警。
- [ ] CPU、GC、锁、I/O 和下游延迟可关联到同一 Trace/时间线。
- [ ] 诊断工具使用有审批、采样和敏感数据保护。
- [ ] 事故恢复动作不删除唯一现场证据。
- [ ] JVM 参数经过压测、灰度和回滚验证。
