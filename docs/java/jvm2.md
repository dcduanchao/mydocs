# jvm 监控及调优

![neicun-jiegou-20240110195211.png](images/neicun-jiegou-20240110195211.png)![img_1.png](jvm.png![neicun-jiegou-20240110195211.png](images/neicun-jiegou-20240110195211.png))

# springboot 开启监控
```agsl
       <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>

        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>
        
  # 配置
  # http://192.168.90.161:5001/actuator/prometheus
management.endpoints.web.exposure.include=prometheus,health,info,metrics      
```

# 安装prometheus
配置监控器
```agsl
global:
  scrape_interval: 10s
scrape_configs:
  - job_name: 'manage-5001-local'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['192.168.90.161:5001','192.168.90.161:5002']
        labels:
          application: 'manage-5001'
  - job_name: 'wbimgbb'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['192.168.90.161:8080']
        labels:
          application: 'wbimgbb-1'

```

```agsl
docker run -d -p 3050:9090 \
-v /root/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
-v /root/prometheus/data:/prometheus \
--name prometheus prom/prometheus
```
http://192.168.30.33:3050/query 查看prometheus数据 status-tagget


cah

# 安装 grafana
```agsl
  docker run -d \
  --name=grafana \
  -p 3000:3000 \
  -v grafana-storage:/var/lib/grafana \
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
  grafana/grafana
```
http://192.168.30.33:3000/login  默认admin admin

## 添加prometheus
Connections ---- Data sources--Add data source--prometheus
配置url：http://192.168.30.33:3050

## 添加jvm监控
import Import dashboard
jvm 监控模板id
12856 或4601 自己找需要的
添加就可以

# jvm 调优
## jdk17
内存设置参数

| 参数                     | 作用                | 建议                             |
| ---------------------- | ----------------- | ------------------------------ |
| `-Xms<size>`           | 初始堆内存大小           | 与 `-Xmx` 设置一致，避免动态扩容带来的停顿      |
| `-Xmx<size>`           | 最大堆内存大小           | 根据系统总内存分配：一般为总内存的 50\~70%      |
| `-Xss<size>`           | 每个线程栈大小           | 默认 1M，建议设为 `256k~512k`，以支持更多线程 |
| `-XX:MetaspaceSize`    | 初始 Metaspace 分配大小 | `128m`，过小会触发频繁 Full GC         |
| `-XX:MaxMetaspaceSize` | 最大 Metaspace 大小   | `256m~512m`，根据类加载量决定           |



| 参数                        | 作用                                  | 建议/说明                   |
| ------------------------- | ----------------------------------- | ----------------------- |
| `-XX:ParallelGCThreads=8` | 设置并行 GC 线程数（控制 Stop-The-World 的并发度） | 一般设为 CPU 核心数的一半或略少      |
| `-XX:G1HeapRegionSize=4m` | 设置 G1 的 region 大小，影响 GC 粒度          | 默认自动计算，设为固定值仅在特殊调优场景下设置 |


垃圾回收相关

| 参数                            | 作用             | 建议                       |
| ----------------------------- | -------------- | ------------------------ |
| `-XX:+UseG1GC`                | 启用 G1 垃圾回收器    | ✅ 推荐（JDK 17 默认）          |
| `-XX:MaxGCPauseMillis`        | 设定最大 GC 停顿时间   | `200`（单位 ms，越小响应越快但吞吐降低） |
| `-XX:+UseStringDeduplication` | G1 中字符串去重，节省内存 | ✅ 建议开启（适用于大量相同字符串）       |
| `-XX:+ParallelRefProcEnabled` | 并行处理引用对象       | ✅ 默认开启，提高 GC 性能          |

GC 日志（调优分析用

| 参数                                     | 作用                   | 建议                        |
| -------------------------------------- | -------------------- | ------------------------- |
| `-Xlog:gc`                             | 开启 GC 日志（JDK 9+ 新语法） | ✅ 推荐                      |
| `-Xlog:gc:file=gc.log:time,level,tags` | 输出日志到文件，含时间戳         | ✅ 必须用于 GC 分析              |
| `-XX:+PrintGCDetails`                  | 详细 GC 信息             | ✅ 推荐（兼容旧系统）               |
| `-XX:+PrintGCDateStamps`               | 显示 GC 时间             | ✅ 和 `-PrintGCDetails` 搭配用 |


诊断与稳定性

| 参数                                  | 作用                  | 建议                |
| ----------------------------------- | ------------------- | ----------------- |
| `-XX:+HeapDumpOnOutOfMemoryError`   | OOM 时自动生成堆转储文件      | ✅ 推荐              |
| `-XX:HeapDumpPath=/path/heap.hprof` | 设置 HeapDump 路径      | ✅ 与上面搭配           |
| `-XX:+ExitOnOutOfMemoryError`       | OOM 后直接退出进程         | ✅ 推荐，便于容器重启       |
| `-XX:+DisableExplicitGC`            | 禁用 `System.gc()` 调用 | ✅ 防止被频繁触发 Full GC |

| 参数                                      | 作用                   | 建议/说明                          |
| --------------------------------------- | -------------------- | ------------------------------ |
| `-XX:InitiatingHeapOccupancyPercent=40` | 触发并发 GC 周期的堆使用率阈值（%） | 默认 45，调低可更早回收，减少老年代压力          |
| `-XX:+UseStringDeduplication`           | 启用 G1 的字符串去重功能       | 减少内存重复字符串，通常收益明显（低 CPU 负担）     |
| `-XX:-UseLargePages`                    | 禁用大页内存               | 默认关闭，如开启需内核配置 HugePages        |
| `-XX:-OmitStackTraceInFastThrow`        | 保留快速抛出异常的堆栈（如频繁抛异常）  | 建议保留为 `false`（即 `-` 开头），便于排查问题 |
| `-XX:+DisableExplicitGC`                | 禁用 `System.gc()`     | 防止代码中强制 Full GC，推荐线上开启         |


其他常用参数

| 参数                         | 作用                   | 建议        |
| -------------------------- | -------------------- | --------- |
| `-XX:+AlwaysPreTouch`      | 启动时预分配堆空间（降低运行时内存抖动） | ✅ 推荐容器中使用 |
| `-XX:+UseContainerSupport` | 让 JVM 识别容器资源限制       | ✅ 容器中部署必须 |
| `-Duser.timezone=UTC`      | 设置 JVM 时区            | 视业务需要调整   |


### -XX:MaxDirectMemorySize
作用： 设置 Java 进程可用的**最大直接内存（Direct Memory）**大小，主要用于 NIO、Netty、Zero-Copy、ByteBuffer 等场景中的 DirectByteBuffer。

💡 默认值：
若不显式设置，JDK 17 默认大小为：与堆大小（-Xmx）一致。

示例：-Xmx1024m → 默认 Direct Memory 也为 1024m。

🛠️ 使用场景建议：
场景	建议值
无使用 Netty/NIO 或少量	可忽略或 256m
Netty / 文件上传下载频繁 / gRPC / Kafka 等	显式设置为 512m ~ 2g，避免 OutOfMemoryError: Direct buffer memory

⚠️ 注意事项：
超出限制会抛出 java.lang.OutOfMemoryError: Direct buffer memory。

该内存不在 heap 中，不能被 GC 控制，需合理规划。

###  -XX:G1HeapRegionSize
作用： 设置 G1 垃圾回收器划分的堆 Region 的大小（每块 Region 的大小，影响 GC 粒度和效率）。

💡 默认值： JVM 会根据堆大小自动设置（通常为 1M ~ 32M），保证总 Region 不超过 2048 个。

示例：
堆 <= 4GB：1M

堆 ~ 8~16GB：4M 或 8M

堆 > 32GB：32M

🛠️ 使用建议：
场景	建议值
小堆（1~2GB）	保持默认（JVM 自动计算）
中型堆（4~8GB）	可固定为 4M
大堆（>16GB）	考虑 8M 或 16M，减少 Region 数，降低管理开销

⚠️ 注意事项：
Region 太小：GC 次数多，管理开销大。

Region 太大：内存浪费、并发度下降。

不建议随意固定，除非监控中发现 Region 过多影响性能。

### -XX:InitiatingHeapOccupancyPercent
 作用： G1 垃圾收集器中，设置触发并发标记周期（Concurrent Marking）的堆使用率阈值（百分比）。即堆占用了多少时开始 GC。

💡 默认值： 45（即堆使用超过 45% 时开始并发 GC）

🛠️ 使用建议：
场景	建议值
普通业务应用	默认即可（45）
希望更早回收，降低 Full GC 风险	调小为 30~40
低延迟业务	可设为 25~35，防止堆逼近满

⚠️ 注意事项：
设置越低：更早 GC，避免老年代满，但会增加并发 GC 频率。

若老年代频繁爆满（Full GC），建议减小这个值。

示例组合推荐（内存 2G，容器部署，G1 GC）


```agsl



-Xms128m
-Xmx128m
-XX:MetaspaceSize=64m
-XX:MaxMetaspaceSize=256m
-XX:G1HeapRegionSize=2M
-XX:+AlwaysPreTouch
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=F:\work\my\study-note\dc-manage\logs\heap.hprof
-Xlog:gc*:file=F:\work\my\study-note\dc-manage\logs\gc.log:time,level,tags

```
filecount=5：最多保留5个日志文件（轮转文件）

filesize=20M：单个日志文件达到20MB后轮转

-Xlog:gc*:file=F:\work\my\study-note\dc-manage\logs\gc.log:time,level,tags:filecount=5,filesize=20M


## prometheus 参数

| 指标                                             | 含义                                |
| ---------------------------------------------- | --------------------------------- |
| `jvm_buffer_count_buffers{id="direct"}`        | 当前 JVM 中 DirectBuffer 数量（NIO直接内存） |
| `jvm_buffer_memory_used_bytes{id="direct"}`    | 实际使用的直接内存字节数                      |
| `jvm_buffer_total_capacity_bytes{id="direct"}` | 直接内存总容量（可能包含未使用空间）                |

Direct Memory 使用默认值时，最大值受限于 -XX:MaxDirectMemorySize（默认等于堆大小）。

DirectBuffer 过多、内存泄漏可能导致 OOM，Prometheus 指标是提前发现的关键。

如果你用了 Netty、Kafka、Zero-Copy 等技术，DirectMemory 占用会更高，需重点监控。

| 类别  | 指标名称                                 | 含义             | 当前值    | 建议        |
| --- | ------------------------------------ | -------------- | ------ | --------- |
| 类加载 | `jvm_classes_loaded_classes`         | 当前已加载的类数量      | 14,575 | 正常，无需关注   |
| 类卸载 | `jvm_classes_unloaded_classes_total` | JVM 启动以来卸载的类总数 | 0      | 无动态类加载，正常 |
| 编译耗时 | `jvm_compilation_time_ms_total` | JIT 编译累计耗时（毫秒） | 3404 ms | 正常，注意热点方法可优化 |


| 类别      | 指标名称                                  | 含义                  | 当前值     | 建议                  |
| ------- | ------------------------------------- | ------------------- | ------- | ------------------- |
| 老年代使用   | `jvm_gc_live_data_size_bytes`         | 最近一次 GC 后老年代对象使用大小  | 0 B     | 程序刚启动或老年代压力小        |
| 老年代最大   | `jvm_gc_max_data_size_bytes`          | 老年代最大容量             | 1.07 GB | 与 JVM 堆设置有关-Xmx 或 MaxHeapSize 相关     |
| Eden 分配 | `jvm_gc_memory_allocated_bytes_total` | 年轻代分配总量             | 240 MB  | 程序对象创建活跃，需结合 YGC 频率 |
| 晋升大小    | `jvm_gc_memory_promoted_bytes_total`  | 晋升至老年代的对象总大小        | 23 MB   | 正常，晋升不频繁            |
| GC 占用   | `jvm_gc_overhead`                     | GC 占用 CPU 的比例（0-1）  | 0.0     | 非常好，几乎无 GC 压力       |
| GC 次数   | `jvm_gc_pause_seconds_count`          | GC 发生次数（仅 Young GC） | 3       | 很少，说明当前压力较小         |
| GC 总耗时  | `jvm_gc_pause_seconds_sum`            | GC 总耗时              | 0.035 秒 | 非常短，无需优化            |
| GC 最大耗时 | `jvm_gc_pause_seconds_max`            | 最大一次 GC 耗时          | 0 秒     | 没有明显的长停顿            |


| 指标名称                         | 说明                                     | 数值示例                | 含义总结                     |
| ---------------------------- | -------------------------------------- | ------------------- | ------------------------ |
| `jvm_memory_committed_bytes` | JVM 已向操作系统申请、但未必使用的内存大小（单位字节），包括堆和非堆区域 | `6.5E8 (650MB)`     | JVM 保留给各内存区的空间，实际可用但未必用满 |
| `jvm_memory_max_bytes`       | JVM 允许该内存区使用的最大内存（单位字节），`-1` 表示无上限     | `1.0737E9 (1024MB)` | 内存区最大可用空间                |
| `jvm_memory_used_bytes`      | JVM 当前真正使用的内存大小（单位字节）                  | `4.8E8 (480MB)`     | 该内存区域当前实际分配并使用的内存        |
| `jvm_memory_usage_after_gc`  | 长生命周期内存区（如老年代）GC后内存使用率，范围 \[0..1]      | `0.00469 (0.469%)`  | GC后老年代内存使用率，反映内存回收效果     |


| 内存区域 `id`                      | 说明                      | 类型 |
| ------------------------------ | ----------------------- | -- |
| `G1 Eden Space`                | 新生代中 Eden 区域（GC对象主要分配区） | 堆  |
| `G1 Survivor Space`            | 新生代中Survivor区（对象短暂存活区）  | 堆  |
| `G1 Old Gen`                   | 老年代（长生命周期对象存储区）         | 堆  |
| `Metaspace`                    | 元空间，存放类元数据              | 非堆 |
| `Compressed Class Space`       | 压缩类空间，存放类的元数据指针         | 非堆 |
| `CodeHeap 'non-nmethods'`      | JIT 编译器存放非方法代码区域        | 非堆 |
| `CodeHeap 'profiled nmethods'` | JIT 编译器存放经过优化的方法代码      | 非堆 |


这个指标 jvm_memory_max_bytes 显示的是 JVM 中某块内存区域的最大可用大小。

当值是 -1，通常代表 JVM 没有为该内存区域设置硬性最大限制。

对于 G1 Eden Space 来说，JVM 会动态调整大小（弹性分配），它的最大值并不是固定的，而是根据堆整体大小和当前 GC 策略动态变化，所以这里显示 -1

# dump 分析

## jvm 命令

```agsl
查看所有 Java 进程及其完整类路径。
jps -l 


jinfo <pid>
jinfo -flags <pid>  # 查看所有 JVM 参数


查看线程栈信息，适合分析线程死锁、阻塞、CPU 高等问题
jstack <pid>  > thread.txt


jmap -heap <pid>              # 查看堆内存结构
jmap -histo:live <pid>        # 查看对象实例统计（live）
jmap -dump:live,format=b,file=heap.hprof <pid>  # 导出 live 对象堆快照


jcmd <pid> VM.flags                          # 查看 JVM 参数
jcmd <pid> GC.class_histogram                # 类实例统计（比 jmap 更快）
jcmd <pid> GC.heap_info                      # 查看堆基本信息
jcmd <pid> Thread.print                      # 相当于 jstack
jcmd <pid> GC.run                            # 手动触发 GC
jcmd <pid> VM.native_memory summary          # 原生内存（Direct、Metaspace）分析
jcmd <pid> VM.log list                       # 查看日志选项

每 1 秒打印一次 GC 信息，持续 10 次。
jstat -gc <pid> 1000 10

百分比查看
jstat -gcutil <pid> 1000 10


```

| 列名     | 含义                              | 单位 | 说明                          |
| ------ | ------------------------------- | -- | --------------------------- |
| `S0C`  | Survivor 0 区的容量                 | KB | Survivor 区用于 Minor GC 时对象转移 |
| `S1C`  | Survivor 1 区的容量                 | KB | JVM 使用两块 Survivor 区轮换使用     |
| `S0U`  | Survivor 0 区当前使用                | KB |                             |
| `S1U`  | Survivor 1 区当前使用                | KB |                             |
| `EC`   | Eden 区的容量                       | KB | Eden 区属于新生代，分配新对象           |
| `EU`   | Eden 区当前使用                      | KB |                             |
| `OC`   | Old 区的容量                        | KB | 老年代，用于晋升后的对象                |
| `OU`   | Old 区当前使用                       | KB |                             |
| `MC`   | Metaspace（类元空间）容量               | KB | 类加载元数据空间，JDK8+ 替代永久代        |
| `MU`   | Metaspace 当前使用                  | KB |                             |
| `CCSC` | 压缩类空间容量（Compressed Class Space） | KB | 存放类结构信息（在 Metaspace 中）      |
| `CCSU` | 压缩类空间当前使用                       | KB |                             |
| `YGC`  | Young GC 次数                     | 次数 | 新生代 GC 发生的次数                |
| `YGCT` | Young GC 总耗时                    | 秒  | 新生代 GC 总时间                  |
| `FGC`  | Full GC 次数                      | 次数 | 完整 GC 的次数（清理整个堆）            |
| `FGCT` | Full GC 总耗时                     | 秒  | Full GC 总时间                 |
| `GCT`  | GC 总时间                          | 秒  | = YGCT + FGCT               |


分析步骤
1. 找到对用的进程ID
    jps -l  或ps -ef | grep java 
2. jstat 查看大概Gc 信息
3. top 查看 cpu 内存比较高pid  
     top -H -p 18359
4. printf "0x%x\n" <高线程pid> 导出jstack 
5. jstack <pid>  > thread.txt  或 jstack -l <Java进程PID> > /tmp/threaddump.txt
   6. grep "nid=0xXXXX" -A 20 m.txt  查看线程信息
      你可以从这段输出中看出：
   哪段代码导致线程一直运行？
   是死循环？网络阻塞？数据库慢？加锁冲突？
   是哪个服务模块出问题？（比如哪个 Controller、Service）
--------------------------------
jstat -gcutil <pid> 1s
jcmd 48 VM.flags | jcmd 48 VM.command_line  jvm 配置
# jvm 结构



# 垃圾处理器