# 阿里云 AI：百炼、DashScope 与通义千问

## 1. 产品与术语

阿里云百炼是企业级大模型开发与应用平台，DashScope 是模型服务 API/SDK 体系，通义千问（Qwen）是模型家族。实际账号、区域、模型和计费能力以阿里云控制台当前开通结果为准。

```text
Java 应用
  -> Spring AI Alibaba / DashScope SDK / OpenAI 兼容 API
  -> 阿里云百炼模型服务
  -> Qwen Chat、Embedding、Rerank、多模态等模型
```

不要把“百炼应用 ID”“模型名称”“API Key”混为一谈：

- 模型名称决定调用哪个基础或部署模型。
- API Key/凭据用于鉴权和配额归属。
- 百炼应用可能封装 Prompt、知识库、插件和流程，通过应用 ID 调用。

## 2. 接入方式选择

| 方式 | 适用场景 | 注意事项 |
|---|---|---|
| Spring AI Alibaba | Spring Boot 项目，需要统一 Chat/RAG/Tool API | 检查 Spring AI 与 Alibaba Starter 兼容矩阵。 |
| DashScope Java SDK | 需要阿里云特有模型能力和参数 | 代码与供应商 API 耦合更强。 |
| OpenAI 兼容接口 | 已有 OpenAI Client，希望快速切换 | 并非所有特有能力都完全兼容。 |
| 百炼应用 API | 使用平台编排的知识库、插件和工作流 | 应用版本、发布和权限由平台管理。 |

## 3. Spring AI Alibaba

依赖名称和版本会随项目发布变化，应通过官方 BOM 和兼容说明管理：

```xml
<dependency>
    <groupId>com.alibaba.cloud.ai</groupId>
    <artifactId>spring-ai-alibaba-starter-dashscope</artifactId>
</dependency>
```

```yaml
spring:
  ai:
    dashscope:
      api-key: ${DASHSCOPE_API_KEY}
      chat:
        options:
          model: ${DASHSCOPE_CHAT_MODEL:qwen-plus}
          temperature: 0.2
```

```java
@Service
public class QwenAssistant {
    private final ChatClient chatClient;

    public QwenAssistant(ChatClient.Builder builder) {
        this.chatClient = builder.build();
    }

    public String answer(String question) {
        return chatClient.prompt()
                .system("使用简洁中文回答；无法确认的信息明确拒答")
                .user(question)
                .call()
                .content();
    }
}
```

Starter 让代码符合 Spring AI 抽象，但阿里云模型的模型名、思考模式、多模态输入、缓存和限流规则仍需按当前模型文档配置。

## 4. OpenAI 兼容接口

已有 Spring AI OpenAI 适配器时，可以将 Base URL 指向 DashScope 兼容模式：

```yaml
spring:
  ai:
    openai:
      api-key: ${DASHSCOPE_API_KEY}
      base-url: https://dashscope.aliyuncs.com/compatible-mode
      chat:
        options:
          model: qwen-plus
```

兼容接口主要复用请求协议，不代表所有字段、错误码、流式行为、工具调用和 Token 统计都与 OpenAI 完全一致。上线前对使用的每项能力做 Contract Test。

## 5. DashScope SDK

使用 SDK 时将模型访问封装成应用端口，避免业务 Service 到处创建客户端：

```java
public interface EnterpriseChatModel {
    ChatResult chat(ChatRequest request);
}

@Component
class DashScopeChatAdapter implements EnterpriseChatModel {
    @Override
    public ChatResult chat(ChatRequest request) {
        // 调用 DashScope SDK，转换请求、响应和错误
        throw new UnsupportedOperationException("adapter implementation");
    }
}
```

适配器统一处理：

- API Key 和 Endpoint。
- 模型名和默认参数。
- 超时、429/5xx 重试和限流。
- Request ID、Token 用量和错误转换。
- 流式取消、连接池和资源释放。
- 敏感字段脱敏。

## 6. 模型选择

模型不是越大越好。按任务选择：

| 任务 | 关注指标 |
|---|---|
| 简单分类/提取 | 结构化准确率、延迟、成本 |
| 复杂推理 | 正确率、推理时间、输出稳定性 |
| 长文档 | 上下文长度、注意力质量、成本 |
| Tool Calling | 工具选择和参数准确率 |
| Embedding | 中文召回、维度、向量库成本 |
| Rerank | Top-K 排序提升和请求长度 |
| 多模态 | 图片大小、OCR、布局理解和隐私 |

建立自己的脱敏业务评估集，不只使用公开 Benchmark。模型版本升级可能改变输出格式和工具选择，必须灰度。

## 7. Chat 与流式响应

同步适合结构化提取和后台任务；流式适合聊天体验。流式链路：

```text
Qwen Stream -> Java Flux/Callback -> SSE -> Browser
```

需要处理：

- 首 Token 超时与总超时。
- 客户端取消后停止上游生成。
- 输出安全检测和 Markdown/XSS。
- 网络中断后的状态和重试提示。
- Token 用量可能在流结束时才完整返回。

流式响应未完成时，不要提前执行模型输出中的业务命令。

## 8. Embedding 与 Rerank

Embedding 将文档和问题映射到同一向量空间；Rerank 对初步召回结果重新排序：

```text
问题 -> Query Embedding -> Vector Top 50
     -> 关键词召回 -> 合并去重
     -> Rerank Top 8
     -> Qwen 生成引用回答
```

文档向量必须记录模型名、版本、维度和切分策略。更换 Embedding 模型通常需要新建向量索引并重新嵌入，不能把不同模型向量混在同一空间直接比较。

## 9. 百炼知识库与应用

平台知识库适合快速构建和运营，应用侧自建 RAG 适合精确控制切分、检索、权限和观测。

选择前评估：

- 文档更新和删除是否及时生效。
- 是否支持租户、部门和文档级 ACL。
- Chunk、Embedding、召回和 Rerank 是否可调。
- 是否返回引用和分数。
- 应用发布、版本、灰度和回滚机制。
- 数据区域、存储、保留和合规要求。

平台控制台的 Prompt 或知识库变更也属于生产变更，需要版本和审计。

## 10. Tool Calling 与 Agent

Qwen 可根据模型能力输出工具调用请求。真实工具始终由应用执行：

```text
模型：调用 query_order(orderNo=1001)
应用：校验用户和订单归属 -> 查询数据库 -> 返回最小结果
模型：组织自然语言回答
```

不要将阿里云平台插件或 Java Tool 直接授权为超级账号。工具使用专用最小权限凭据，并限制调用域名、SQL、文件路径和执行次数。

更完整的循环、状态和安全策略参见 [Agent](agent.md)。

## 11. API Key 与网络安全

- 开发、测试和生产使用不同 Key 与配额。
- Key 通过环境 Secret、KMS 或凭据服务注入。
- Key 不写入前端、移动端、Git、镜像和日志。
- 使用网关限制来源、租户、QPS、并发和 Token 预算。
- 记录调用的业务主体、模型、Request ID 和费用，不记录完整隐私 Prompt。
- 定期轮换 Key，并具备双 Key 过渡能力。

浏览器不能直接调用携带长期 DashScope Key 的接口，应由后端代理并执行认证授权。

## 12. 超时、限流与重试

```text
连接超时 < 首 Token 超时 < 总生成超时 < 上游业务 Deadline
```

只对连接失败、明确 429 和可恢复 5xx 做有限退避重试。模型已生成但响应丢失时，重试会重复计费；Tool Calling 场景还可能重复副作用，必须使用幂等键和工具执行记录。

限流维度：用户、租户、模型、接口、并发、每分钟 Token 和每日费用。队列必须有界，超过预算时返回明确降级结果。

## 13. 内容安全与合规

- 输入进行恶意指令、隐私、内容类别和大小检查。
- 输出经过业务规则、安全策略和前端 XSS 处理。
- 企业文档根据用户 ACL 过滤后才能进入 Prompt。
- Prompt 日志脱敏并设置保留期。
- 明确数据是否用于训练、存储区域和跨境要求。
- 高风险行业保留人工复核和拒答机制。

内容安全模型不是唯一防线。工具权限、数据访问和业务交易必须由确定性代码控制。

## 14. 观测与评估

关键指标：

- 请求成功率、429、5xx、超时和取消。
- 首 Token、总响应、检索和工具耗时。
- 输入/输出 Token、缓存命中和费用。
- 模型、Prompt、知识库和应用版本。
- RAG 命中、引用正确、拒答和幻觉率。
- Tool Calling 参数准确率、失败和越权拦截。

模型升级先离线评估，再影子流量或小比例灰度，最后逐步切换。保存可回滚的模型和 Prompt 配置。

## 15. 常见问题

### 15.1 401/403

检查 Key 是否有效、区域/Endpoint、账号权限、模型是否开通以及服务端时间。不要把完整 Key 打入日志。

### 15.2 429

区分 QPS、并发、Token 或账户配额限制，使用带抖动退避、入口限流和模型路由。无限立即重试会扩大故障。

### 15.3 模型名不可用

模型可能受区域、账号和开通状态限制。模型名使用配置项并在启动或健康检查中验证，不要散落在代码中。

### 15.4 SDK 与兼容接口结果不同

比较请求参数、System Message、Tool Schema、流式选项和默认值。兼容接口可能不暴露全部模型特性。

## 16. 面试高频问题

### 16.1 百炼、DashScope 和 Qwen 的关系

> 百炼是大模型开发与应用平台，DashScope 提供模型 API/SDK，Qwen 是模型家族。应用可通过 Spring AI Alibaba、DashScope SDK、兼容 API 或百炼应用接入。

### 16.2 Spring AI Alibaba 与 DashScope SDK 怎么选

> Spring AI Alibaba 适合 Spring Boot 统一抽象、RAG 和工具调用；DashScope SDK 更容易使用阿里云特有能力。可以在应用端口后封装，两者按任务组合，但要避免业务代码耦合供应商对象。

### 16.3 更换 Embedding 模型要注意什么

> 向量维度和语义空间可能变化，应新建向量索引、重新嵌入全量文档、离线评估和灰度切换，不能把新旧向量混合比较。

## 17. 生产检查清单

- [ ] 接入方式、模型、区域和兼容版本固定。
- [ ] Key 使用 Secret/KMS，按环境隔离并可轮换。
- [ ] 请求有超时、限流、Token/费用预算和重试上限。
- [ ] 模型输出、Tool 参数和业务权限均有校验。
- [ ] Embedding 模型、维度、文档版本可追踪。
- [ ] 百炼应用、Prompt 和知识库变更有版本和审计。
- [ ] 监控请求、Token、费用、RAG 和工具质量。
- [ ] 模型升级经过离线评估、灰度和回滚验证。
