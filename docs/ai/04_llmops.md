# 04 LLMOps 与可观测性

## 1. LLMOps 是什么

LLMOps 管理 AI 应用从开发、评估、发布到运行的完整生命周期，关注模型、Prompt、知识库、工具、质量、成本和安全。

```text
开发 -> 评估 -> Registry -> 灰度发布 -> 在线观测
   ^                                      |
   |----------- 失败样本与反馈 ------------|
```

## 2. 需要版本化的资产

- 模型供应商、模型名和参数。
- System/User Prompt 模板。
- Tool Schema 与权限策略。
- Embedding、Rerank 和 Vector Index。
- 文档解析、切分和知识库版本。
- 输出 Schema 和业务校验规则。
- 评估集、评分器和阈值。

只记录代码 Git Commit 不够，控制台 Prompt 和知识库变更同样需要版本、操作者和回滚点。

## 3. Trace 模型

```text
AI Request
  -> Query Rewrite
  -> Embedding
  -> Vector/Keyword Search
  -> Rerank
  -> Chat Model
  -> Tool Call
  -> Tool Result
  -> Final Output
```

每个 Span 记录耗时、状态、模型、Token、候选数和版本。Prompt/Response 默认不记录全文，只保存脱敏摘要、哈希或经过授权的采样。

## 4. 核心指标

| 维度 | 指标 |
|---|---|
| 可用性 | 成功率、429、5xx、超时、取消。 |
| 延迟 | 排队、首 Token、总生成、检索、工具 P95/P99。 |
| 用量 | 输入/输出 Token、请求数、缓存命中。 |
| 成本 | 用户、租户、模型、功能和每日预算。 |
| 质量 | 评估得分、引用、拒答、工具成功率。 |
| 安全 | 注入、越权、内容拦截和敏感数据事件。 |

只监控 HTTP 200 会漏掉模型返回低质量内容、错误引用和费用异常。

## 5. Prompt 与模型 Registry

Registry 保存：名称、版本、模板、变量 Schema、适用模型、负责人、评估结果和发布状态。

```text
draft -> evaluated -> canary -> production -> retired
```

生产请求只能引用已发布版本。在线回滚切换版本指针，不临时手工修改 Prompt。

## 6. 模型网关

统一网关负责认证、路由、限流、预算、重试、日志和供应商适配：

```text
业务应用 -> AI Gateway -> Provider A / Provider B / Local Model
```

网关不能强行抹平所有模型能力。结构化输出、工具调用、多模态和上下文限制需要 Capability Matrix。

详细设计参见 [06 模型网关](06_model_gateway.md)。

## 7. 缓存

- Exact Cache：请求和配置完全相同。
- Semantic Cache：语义相似问题复用结果，需谨慎校验。
- Embedding Cache：文本 + 模型版本复用向量。
- RAG Cache：Query + ACL + Index Version。
- Prefix/Provider Cache：利用供应商前缀缓存能力。

缓存必须包含租户、权限、模型、Prompt 和知识版本。高变化数据、个性化回答和副作用工具不能简单缓存。

## 8. 成本治理

```text
请求成本 = 输入 Token + 输出 Token + Embedding + Rerank + Tool/基础设施
```

- 按用户、租户和功能设置日/月预算。
- 超预算时切小模型、减少上下文或拒绝非核心请求。
- 限制并发、最大 Token 和 Agent 步数。
- 识别异常循环、重复请求和无效长 Prompt。
- 成本告警与业务价值指标关联。

## 9. 发布策略

- 离线评估通过后进入影子流量。
- Canary 按用户/租户稳定分流。
- 同时观察质量、费用、延迟和安全。
- 模型与 Prompt 分别可回滚。
- 知识库索引使用版本别名原子切换。
- Tool Schema 变更保持旧 Agent 任务可恢复。

## 10. 数据与隐私

对 Prompt、响应、文档和 Trace 分类：公开、内部、机密、受监管。按分类决定是否允许发送到外部模型、存储时长、脱敏方式和人员访问。

日志禁止保存 API Key、Authorization Header、完整身份证和跨租户文档。调试采样要有用户授权、审计和自动过期。

## 11. 事故处理

### 费用突增

按模型、租户、Prompt 版本、Agent 步数和重试拆分，立即收紧预算或关闭非核心路由，保留 Trace 分析循环和上下文膨胀。

### 质量下降

检查模型版本、Prompt、知识库、Embedding/Rerank、工具和输出解析的变更时间线，使用固定评估集重放。

### 供应商不可用

按 Capability Matrix 路由备用模型。副作用请求不自动重复 Tool，结构化输出和安全策略必须保持。

### 数据泄露

停止相关路由、撤销凭据、保留审计、确认数据范围并按合规流程响应。仅删除日志不能完成事故处理。

## 12. OpenTelemetry

可以使用 OpenTelemetry Span 表达模型、检索和工具调用，并通过 Micrometer/OpenTelemetry 输出指标。属性中避免高基数完整 Prompt 和用户 ID，使用受控业务分类和哈希。

异步 Agent 使用 Task ID、Trace ID、Tool Call ID 关联跨进程步骤。

## 13. 生产检查清单

- [ ] 模型、Prompt、工具、知识库和评估集全部版本化。
- [ ] Trace 能拆分检索、模型、工具和输出阶段。
- [ ] 质量、成本、延迟、安全和用量均有监控。
- [ ] 按租户预算、限流和异常费用告警。
- [ ] 缓存包含模型、知识和权限维度。
- [ ] 发布经过评估、影子、灰度并可独立回滚。
- [ ] 日志、采样、数据保留和访问满足隐私要求。
- [ ] 具有供应商故障、质量下降、费用异常和泄露预案。
