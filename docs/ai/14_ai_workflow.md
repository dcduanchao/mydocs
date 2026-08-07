# 14 AI 工作流

## 1. 为什么需要工作流

业务流程通常包含确定性校验、模型判断、工具执行、人工审批和补偿。用显式状态机编排，比让 Agent 自由循环更容易测试、审计和恢复。

```text
接收 -> 分类 -> 检索 -> 生成草稿 -> 校验
                         -> 人工审批 -> 执行 -> 完成
```

## 2. Workflow 与 Agent 的边界

- 条件、步骤和权限固定：Workflow。
- 需要选择工具、查询路径或计划：受限 Agent 节点。
- 金额、库存、权限、状态迁移：确定性代码。
- 语言理解、摘要、分类、候选方案：模型。

模型只负责适合概率判断的节点，不能替代事务、权限和状态机。

## 3. 状态设计

```java
enum TaskStatus {
    CREATED, RUNNING, WAITING_APPROVAL,
    RETRYING, SUCCEEDED, FAILED, CANCELLED
}
```

任务表保存：Task ID、业务幂等键、当前节点、版本、输入摘要、工具调用、审批、重试次数、Deadline 和错误。

状态转移使用乐观锁，避免两个 Worker 同时推进：

```sql
UPDATE ai_task
SET status = ?, current_node = ?, version = version + 1
WHERE task_id = ? AND version = ?;
```

## 4. Checkpoint 与恢复

每个副作用步骤前后写 Checkpoint：

```text
before_tool -> Tool Call ID -> result persisted -> next node
```

进程崩溃恢复时先查询 Tool Call ID 和业务状态，不要直接重新执行。无法确认结果时进入人工或查询补偿路径。

## 5. 人工审批

审批内容包括原始请求、模型建议、证据、工具、参数、影响范围、风险和版本。审批后执行前再次校验参数和权限，防止状态被替换。

审批超时进入明确状态，不要默认为同意。拒绝理由可用于后续评估，但不能无授权写入长期 Memory。

## 6. 重试与补偿

```text
临时网络失败 -> 指数退避
业务冲突 -> 重新读取状态
永久失败 -> 死信/人工
副作用未知 -> 查询结果后决定
```

每个节点定义最大重试、总 Deadline、补偿动作和人工入口。补偿不是数据库回滚，例如邮件已经发送后只能发送更正通知。

## 7. 定时与长任务

长任务使用队列和持久化状态，不占用 HTTP 请求线程。前端查询 Task 状态或通过 SSE/WebSocket 接收事件。

```text
POST /ai/tasks -> 202 + taskId
GET /ai/tasks/{id} -> 状态/进度/结果
```

Task ID 不能替代权限检查；用户只能查询自己的任务或具有管理权限的任务。

## 8. 任务幂等

同一业务请求生成稳定 Idempotency Key，创建任务使用唯一约束。每个 Tool Call 也有独立幂等键，避免恢复时重复扣款、发货或写入。

## 9. 观测

按 Task、Node、Tool 和 Model 记录 Trace，监控任务成功率、步骤数、人工接管、最长运行时间、重试、死信、费用和失败节点。

## 10. 生产检查清单

- [ ] 业务流程用显式状态机表达，模型只负责适合的节点。
- [ ] 任务、节点和 Tool Call 可持久化、恢复和审计。
- [ ] 重试、补偿、人工审批和超时状态明确。
- [ ] 副作用工具幂等，恢复前查询未知结果。
- [ ] 长任务异步化，API 返回 Task ID 并执行权限检查。
- [ ] 任务 Trace、费用、步骤和死信可观测。
