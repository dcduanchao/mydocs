# 05 向量数据库

## 1. 向量数据库是什么

向量数据库保存 Embedding 和 Metadata，并通过近似最近邻（ANN）查找语义相似内容。RAG 中它只负责召回候选，权限、重排、上下文和最终答案仍由应用负责。

```text
Embedding -> Vector Index
                    + Metadata Filter
Query Vector -> ANN Top K -> Rerank
```

## 2. 选择方案

| 方案 | 优势 | 注意事项 |
|---|---|---|
| PostgreSQL + pgvector | SQL、事务、数据关系复用。 | 超大规模 ANN 和扩展需评估。 |
| Elasticsearch/OpenSearch | BM25、向量、过滤和聚合统一。 | 分片、Heap 和索引调优复杂。 |
| Milvus/Qdrant | 专用向量索引和规模能力。 | 需要独立运维和数据同步。 |
| 云向量服务 | 托管、弹性和模型集成。 | 成本、区域和供应商绑定。 |

选型以真实数据、过滤条件、QPS、P99、Recall、备份恢复和租户隔离压测为准。

## 3. Collection 与 Metadata

一条向量记录至少包含：

```json
{
  "id": "manual-42:v3:chunk-8",
  "vector": [0.01, -0.20],
  "text": "退款规则......",
  "document_id": "manual-42",
  "version": 3,
  "tenant_id": "tenant-a",
  "department": "finance",
  "title": "退款规则",
  "page": 8,
  "updated_at": "2026-08-05T10:00:00Z"
}
```

Metadata 负责过滤和引用，不能把所有大文本重复塞入向量库。原文可以放对象存储，检索结果只返回必要片段和文档位置。

## 4. ANN 索引

### HNSW

图结构，查询质量和延迟较好，内存成本较高，适合在线检索。常见参数包括连接数 `M`、构建 `efConstruction` 和查询 `efSearch`。

### IVF

先聚类，再只搜索部分桶，内存/延迟可控但需要训练和调参。数据分布变化时需要重新构建。

索引参数不是越大越好：Recall 提升会带来内存、构建时间和查询延迟成本。使用标注 Query 选择参数。

## 5. 距离与维度

- Cosine：关注方向，常用于文本语义向量。
- Dot Product：依赖向量归一化和模型定义。
- Euclidean：关注空间距离。

查询向量和文档向量必须使用同一模型、维度、归一化和距离定义。更换模型时新建 Collection/Index，完成重建和灰度切换。

## 6. Metadata Filter 与权限

权限在召回阶段执行：

```text
认证身份 -> tenant/department/document ACL
        -> Vector Filter
        -> Top K
```

不能先检索全部文档再让模型“记住不能泄露”。缓存 Key 必须包含租户和权限版本，引用下载再次鉴权。

高隔离租户可以使用独立 Collection 或 Index；共享索引时严格测试 Filter、删除和索引重建。

## 7. 混合检索

```text
BM25 Top 50 + Vector Top 50
    -> RRF/分数归一化
    -> 去重
    -> Rerank Top 10
```

精确 ID、错误码和专有名词通常依赖关键词，语义问法依赖向量。混合检索的权重和候选数使用真实 Query 评估，不要直接比较两个系统原始分数。

## 8. 数据生命周期

文档更新使用新版本写入后原子切换：

```text
采集 -> 解析 -> 嵌入 -> 校验 Chunk 数和版本
     -> 切换 current_version -> 异步清理旧版本
```

删除必须同时处理向量、关键词、缓存、原文和引用。定期对账源系统文档数、版本、向量数和孤儿记录。

## 9. 备份与恢复

向量库需要备份索引、Metadata、Schema、Embedding 模型版本和切分代码。只备份向量而没有原文和版本信息，无法可靠重建和解释引用。

定期执行：

- 全量 Snapshot。
- 增量或变更记录。
- 新环境恢复演练。
- 随机 Query Recall 对比。
- 删除和权限恢复验证。

## 10. 性能调优

- 批量写入和异步 Embedding，限制并发。
- 控制 `Top K`、Rerank 候选和 Metadata 字段。
- 过滤字段建立适当索引。
- HNSW/IVF 参数通过 Recall-P99 曲线选择。
- 避免每个小文档独立 Collection，减少碎片。
- 监控内存、GC、磁盘、Segment、索引构建和拒绝。
- 读写分离或副本扩展查询，但验证一致性窗口。

## 11. 常见故障

### 召回率低

检查解析质量、Chunk 语义完整性、Embedding 模型、Query Rewrite、Filter 和距离定义。

### 查询很慢

检查高 `Top K`、过滤不命中、索引内存不足、Rerank 候选过大和磁盘/GC。不要只增加客户端超时。

### 向量维度错误

确认模型版本和 Collection Schema，禁止把不同维度向量强行补零或截断。

### 越权召回

检查索引 Filter、缓存 Key、租户传播和原文下载鉴权，立即停止共享缓存并保留审计。

## 12. 生产检查清单

- [ ] 模型、维度、距离、索引参数和 Schema 固定。
- [ ] 文档、Chunk、Metadata、权限和版本可追踪。
- [ ] 召回阶段执行租户和文档 ACL。
- [ ] 混合检索和 Rerank 有真实标注评估。
- [ ] 更新、删除、对账、Snapshot 和重建流程完整。
- [ ] 监控 Recall、P99、内存、磁盘和索引任务。
