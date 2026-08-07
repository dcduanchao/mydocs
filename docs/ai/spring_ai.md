# Spring AI

## 1. Spring AI 是什么

Spring AI 为 Spring Boot 应用提供统一的模型访问抽象，覆盖 Chat、Embedding、Image、Audio、Vector Store、Structured Output 和 Tool Calling。它并不把不同模型变成完全相同的能力，模型特有参数、上下文窗口和工具格式仍需查阅对应适配器文档。

```text
Controller -> ChatClient -> ChatModel -> 模型服务
                         -> Advisor / Memory / RAG
```

## 2. 依赖与配置

Spring Boot、Spring AI 和模型适配器版本必须按兼容矩阵选择。不要把示例中的版本号直接升级到最新而跳过兼容验证。

```xml
<dependency>
    <groupId>org.springframework.ai</groupId>
    <artifactId>spring-ai-starter-model-openai</artifactId>
</dependency>
```

```yaml
spring:
  ai:
    openai:
      api-key: ${AI_API_KEY}
      chat:
        options:
          model: ${AI_MODEL}
          temperature: 0.2
          max-tokens: 1200
```

API Key 使用环境变量、Secret 或 KMS 注入，不提交到配置文件和日志。

## 3. ChatClient

```java
@Service
public class AssistantService {
    private final ChatClient chatClient;

    public AssistantService(ChatClient.Builder builder) {
        this.chatClient = builder
                .defaultSystem("你是严谨的 Java 技术助手，不确定时明确说明")
                .build();
    }

    public String answer(String question) {
        return chatClient.prompt()
                .user(question)
                .call()
                .content();
    }
}
```

System Prompt 负责稳定角色和边界，用户输入属于不可信数据，不能让用户通过文本覆盖系统安全规则。生产 Prompt 应版本化、评审并有回归测试。

### 3.1 消息与上下文

```java
String answer = chatClient.prompt()
        .messages(
                new SystemMessage("只回答产品文档中的内容"),
                new UserMessage(question))
        .call()
        .content();
```

对话历史会占用上下文窗口和费用。不要无限追加历史，按 Token 预算摘要、裁剪或使用外部记忆。

### 3.2 流式输出

```java
Flux<String> stream(String question) {
    return chatClient.prompt()
            .user(question)
            .stream()
            .content();
}
```

使用 SSE 或 WebSocket 推送时处理客户端断开、模型超时、半截 JSON 和取消请求。流式输出完成前不能把结果当作完整业务指令执行。

## 4. 结构化输出

自然语言结果不适合作为业务接口协议。定义 DTO 并要求模型输出结构化数据：

```java
public record OrderIntent(
        String orderNo,
        String action,
        String reason) {
}

OrderIntent intent = chatClient.prompt()
        .user("从下面文本中提取订单意图：" + text)
        .call()
        .entity(OrderIntent.class);
```

解析后仍要使用 Bean Validation 和业务白名单校验。模型可能缺字段、类型错误或输出超出允许枚举，解析失败应进入可重试或人工处理路径。

## 5. Advisor、记忆与 RAG

Advisor 可以统一处理 Prompt 模板、日志、对话记忆和检索上下文。记忆不是事实数据库，用户历史、权限和订单状态仍应从可信系统读取。

```text
用户问题
  -> 历史摘要
  -> 检索相关文档
  -> Prompt 模板
  -> ChatModel
```

RAG 的切分、Embedding、向量库和引用策略参见 [RAG](rag.md)。

## 6. Tool Calling

工具调用流程：

```text
用户问题 -> 模型选择工具和参数
         -> 应用校验权限与参数
         -> 执行真实工具
         -> 工具结果返回模型
         -> 模型生成最终回答
```

```java
@Component
public class OrderTools {
    @Tool(description = "查询当前用户的订单状态")
    public OrderStatusResult queryOrder(
            @ToolParam(description = "订单号") String orderNo) {
        return orderService.queryForCurrentUser(orderNo);
    }
}
```

工具方法不是“模型可以直接执行的 Java 方法”。应用必须验证当前用户、租户、订单归属、参数范围、调用次数和写操作确认。删除、退款、发货等副作用操作应要求明确确认或二次校验。

## 7. 函数调用安全

- 工具参数使用 JSON Schema、Bean Validation 和枚举白名单。
- 工具执行设置超时、并发上限和幂等键。
- 只返回模型完成任务所需的最小字段。
- 记录 Tool Call ID、调用者、耗时和结果状态，不记录 Secret。
- 失败结果使用结构化错误，不把堆栈直接返回模型。
- 高风险工具采用人工审批或双重确认。

## 8. 模型路由与降级

模型调用应封装在应用服务后面，避免 Controller 直接依赖具体供应商：

```text
ChatGateway
  -> 主模型
  -> 超时/限流/配额失败
  -> 备用模型或模板降级
```

降级前确认模型能力兼容，例如 JSON Schema、工具调用、上下文长度和多模态能力可能不同。重试不能造成重复扣费或重复工具调用。

## 9. 观测、成本与评估

每次调用至少记录：模型、Token 用量、首 Token 延迟、总延迟、状态码、重试次数、Prompt 版本和业务 Trace ID。Prompt 和用户输入需脱敏。

成本控制：

- 设置单请求输入/输出 Token 上限。
- 限制历史消息和 RAG 上下文数量。
- 对重复问题做语义或结果缓存。
- 按租户、用户和接口设置预算。
- 对流式取消释放连接并记录未完成调用。

离线评估集应包含正常、拒答、越权、长文档、歧义和对抗输入，评估准确率、引用正确率、幻觉率、延迟和成本。

## 10. 测试

- 单元测试：Prompt 组装、工具参数校验、输出解析和权限。
- Contract Test：模型适配器返回结构、错误和 Token 统计。
- Mock 模型：测试业务流程，不验证模型智能。
- 录制样本：固定一批脱敏响应做回归，但要允许模型版本差异。
- 真实模型小流量测试：验证限流、超时、重试和费用。

## 11. 常见问题

### 11.1 模型输出不是合法 JSON

使用结构化输出能力、明确 Schema、限制温度，并对解析失败做有限重试。重试 Prompt 不能无限增长上下文。

### 11.2 流式响应中途断开

记录已发送 Token 和模型 Request ID，客户端可以显示重试提示。不要自动重复执行带副作用的工具调用。

### 11.3 生产延迟突然升高

区分排队、连接建立、首 Token、模型生成、RAG 检索和工具执行耗时；不能只看 Controller 总耗时。

## 12. 面试高频问题

### 12.1 Spring AI 解决了什么问题

> 它为 Spring Boot 提供 Chat、Embedding、Vector Store、结构化输出和工具调用的统一抽象，减少供应商适配代码。但模型能力、参数、上下文和错误仍需按具体模型验证。

### 12.2 Tool Calling 是模型直接执行代码吗

> 不是。模型只返回工具名称和参数，应用负责鉴权、校验、限流和执行，再把结果返回模型。模型输出和工具结果都属于不可信数据。

### 12.3 如何控制 AI 调用成本

> 限制 Token、裁剪历史、控制 RAG 上下文、缓存重复请求、按租户预算、选择合适模型，并监控每次调用的输入输出 Token、延迟和重试。

## 13. 生产检查清单

- [ ] API Key、Prompt、用户输入和模型响应不泄露敏感信息。
- [ ] 输入、输出和工具参数有大小、格式和权限校验。
- [ ] 模型调用设置超时、限流、重试上限和降级。
- [ ] 结构化输出解析失败有明确处理。
- [ ] 具有 Token、成本、延迟、错误和 Prompt 版本监控。
- [ ] 高风险工具需要确认、审批、幂等和审计。
- [ ] 评估集覆盖准确性、拒答、越权和对抗输入。
