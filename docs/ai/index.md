# AI 技术专题

本目录整理 Java 应用中的大模型应用开发，重点覆盖 Spring AI、阿里云百炼/通义千问、RAG 和 Agent。这里的 `RGA` 通常指 `RAG`（Retrieval-Augmented Generation，检索增强生成）。

## 1. 技术分类

```text
AI 基础与模型
  -> Prompt、Token、Embedding、上下文窗口、结构化输出

模型接入
  -> Spring AI
  -> 阿里云百炼 / DashScope / 通义千问

知识库应用
  -> RAG：切分、向量化、检索、重排、引用

自动化应用
  -> Agent：工具调用、记忆、规划、状态机、权限和护栏

工程化
  -> 评估、观测、成本、限流、缓存、安全和部署
```

## 2. 按优先级分类

### 基础与 Prompt

| 优先级 | 页面 | 重点 |
|---:|---|---|
| 1 | [大模型基础](01_llm_fundamentals.md) | Token、上下文、采样、模型能力和幻觉。 |
| 2 | [Prompt 工程](02_prompt_engineering.md) | 模板、结构化输出、注入防护和版本。 |

### 评估与工程化

| 优先级 | 页面 | 重点 |
|---:|---|---|
| 3 | [AI 评估体系](03_ai_evaluation.md) | 数据集、RAG/Agent 评估、红队和灰度。 |
| 4 | [LLMOps](04_llmops.md) | 版本、Trace、成本、路由和事故治理。 |

### 检索与模型基础设施

| 优先级 | 页面 | 重点 |
|---:|---|---|
| 5 | [向量数据库](05_vector_database.md) | ANN、Metadata、混合检索和权限。 |
| 6 | [模型网关](06_model_gateway.md) | 多模型路由、限流、预算和降级。 |
| 7 | [本地模型部署](07_local_model_deployment.md) | Ollama、vLLM、GPU、量化和服务化。 |

### 多模态与工具协议

| 优先级 | 页面 | 重点 |
|---:|---|---|
| 8 | [多模态 AI](08_multimodal.md) | 图片、文档、OCR、语音和多模态 RAG。 |
| 9 | [MCP](09_mcp.md) | Tool、Resource、Server、权限和审计。 |

### 安全、数据与训练

| 优先级 | 页面 | 重点 |
|---:|---|---|
| 10 | [AI 安全](10_ai_security.md) | 注入、越权、隐私、供应链和沙箱。 |
| 11 | [AI 数据工程](11_ai_data_engineering.md) | 采集、解析、版本、脱敏和增量同步。 |
| 12 | [模型微调](12_ai_finetuning.md) | SFT、LoRA、数据集、评估和发布。 |

### 产品与实战

| 优先级 | 页面 | 重点 |
|---:|---|---|
| 13 | [AI 前端体验](13_ai_frontend.md) | SSE、流式消息、引用、取消和上传。 |
| 14 | [AI 工作流](14_ai_workflow.md) | 状态机、Checkpoint、审批、恢复和补偿。 |
| 15 | [AI 项目实战](15_ai_projects.md) | 知识库、客服、SQL、代码和运维助手。 |

## 3. 已有技术专题

| 页面 | 解决的问题 |
|---|---|
| [Spring AI](spring_ai.md) | 使用 Spring Boot 统一接入 Chat、Embedding、结构化输出和工具调用。 |
| [阿里云 AI](alibaba_ai.md) | 接入阿里云百炼、DashScope、通义千问和企业级模型服务。 |
| [RAG](rag.md) | 让模型基于企业文档检索后回答，降低幻觉并提供引用。 |
| [Agent](agent.md) | 让模型在权限约束下调用工具、执行多步任务并保存状态。 |

## 4. 先理解的概念

| 概念 | 说明 |
|---|---|
| Prompt | 发送给模型的指令、上下文和输出约束。 |
| Token | 模型处理文本的基本计量单位，影响上下文和费用。 |
| Temperature | 采样随机性参数，不是“智能程度”开关。 |
| Embedding | 将文本映射为向量，用于相似度检索。 |
| Rerank | 对初步召回结果重新排序，提高相关性。 |
| Tool Calling | 模型输出结构化工具调用请求，由应用执行真实操作。 |
| Grounding | 用外部可信资料约束模型回答。 |
| Guardrail | 对输入、工具参数和输出进行安全与业务校验。 |

## 5. 推荐学习顺序

1. 先使用 Spring AI 或阿里云 SDK 完成单轮问答和流式输出。
2. 增加结构化输出、超时、重试、限流和日志。
3. 学习 Embedding、向量库和 RAG，构建可引用知识库。
4. 再引入 Agent，先做单 Agent + 少量只读工具。
5. 最后补评估集、权限、成本预算、审计和故障恢复。

## 6. 生产边界

- 模型输出永远是不可信输入，必须经过 JSON Schema、业务规则和权限校验。
- API Key、用户隐私和企业文档不能写入 Prompt 日志。
- RAG 不能保证绝对正确，需要引用、拒答和离线评估。
- Agent 不应直接拥有无限制 Shell、数据库写入或网络访问权限。
- 超时、重试、并发、Token 上限和费用都要设置硬限制。
