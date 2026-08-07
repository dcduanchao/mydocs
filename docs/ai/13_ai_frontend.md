# 13 AI 前端体验

## 1. 流式聊天链路

```text
Browser -> SSE/WebSocket -> Backend -> Model Stream
                           -> RAG/Tool
```

后端负责 API Key、Prompt、权限、模型调用和审计；前端负责展示流、状态、引用、工具审批和取消。不要让浏览器直接持有供应商长期 Key。

## 2. SSE

SSE 适合服务端到浏览器的单向 Token 流：

```text
event: token
data: {"text":"你好"}

event: citation
data: {"documentId":"manual-1","page":2}

event: done
data: {"requestId":"r-1"}
```

协议应区分 token、引用、工具状态、错误、done 和心跳。客户端断开时后端取消上游模型请求，不能继续无限生成。

## 3. 前端状态机

```text
IDLE -> CONNECTING -> STREAMING -> DONE
                  -> ERROR
STREAMING -> CANCELLING -> CANCELLED
```

按钮、重试和输入框根据状态变化，避免用户重复提交。网络重连需要 Request ID 和幂等策略，不能把已完成回答重复插入消息列表。

## 4. Markdown 与安全

模型输出的 Markdown、HTML、链接、代码和表格都不可信：

- 使用安全 Markdown Renderer。
- 禁止危险 HTML、JavaScript URL 和事件属性。
- 代码高亮不执行代码。
- 链接域名可限制并使用 `rel="noopener"`。
- 引用链接由服务端生成并再次鉴权。

## 5. 体验设计

- 展示首 Token、生成中、工具执行和检索状态。
- 支持停止生成、重新生成、复制和反馈。
- 失败时说明是否可以重试，避免暴露内部异常。
- 长回答提供引用、目录和折叠工具详情。
- 高风险动作展示影响范围和确认参数。
- 移动端处理断网、页面刷新和长文本。

## 6. 文件与多模态上传

上传先取得后端临时凭证，后端执行大小、类型、病毒、权限和内容检查。前端显示解析进度和失败原因，不能把本地文件路径当成可信元数据。

## 7. 生产检查清单

- [ ] API Key 只在后端，SSE/WebSocket 有认证和权限。
- [ ] 流协议包含 Token、引用、工具、错误和结束事件。
- [ ] 取消、断开、重连和重复提交可控。
- [ ] Markdown、链接、文件和模型输出经过安全处理。
- [ ] 高风险 Tool 显示参数、审批和最终结果。
