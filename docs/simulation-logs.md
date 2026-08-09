# 模拟日志接口

每次 GUI 整队模拟会在 `output/logs` 生成一份 MAT 记录，并更新
`simulation_log_index.mat`。记录包含角色配置、排轴、Buff、DPS 口径、
角色结果和原始时间线表。

统一查询入口：

```matlab
[summary, records] = querySimulationLogs(criteria);
```

`criteria` 可选字段：`LogId`、`Mode`、`Character`、`Since`、`Until`、
`Limit`、`LoadRecords`、`LogDirectory`。默认按时间倒序返回最近 50 条并加载完整记录。

`summary` 是供列表、筛选和后续可视化直接使用的轻量索引；`records` 中每一项为
完整结构化日志。GUI 也提供 `app.queryLogs(criteria)` 作为同一规则的包装入口。

主展示 DPS 为所有角色单人 DPS 的合计，日志中的 `MemberDPSSum` 与 `TeamDPS`
保持相同。`CycleDPS` 为总伤害按单轮周期归一化后的诊断数据，不作为主展示值。
