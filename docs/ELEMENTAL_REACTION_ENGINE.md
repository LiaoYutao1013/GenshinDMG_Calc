# 元素反应引擎设计与落地说明

## 1. 文档目的

本文档说明当前工程中统一元素反应结算层的设计目标、数据结构、计算流程和维护方式。

本次重构的核心目标是把过去分散在：

- `simulateSimpleCharacterDPS.m`
- `applyElementalHitToEnemy.m`
- 各角色自定义脚本

中的反应判定逻辑，整理成统一的“命中描述 -> 怪物附着状态 -> 反应判定 -> 伤害结算 -> 状态回写”链路。

---

## 2. 现状问题

重构前，工程中已经有轻量敌人附着状态，但存在几个明显问题：

1. 增幅、激化、剧变反应分别走不同逻辑分支，不是统一入口。
2. 激化更多依赖“队伍里有没有草/雷”这类静态条件，而不是怪物当前附着状态。
3. 扩散、超载、感电、燃烧、结晶等反应没有统一使用当前怪物附着来决定。
4. 剧变/绽放类反应伤害此前复用了直伤乘区口径，误吃了防御乘区，不够准确。
5. 角色脚本只能通过 `AllowAmplify / AllowCatalyze / AllowTransformative` 这类松散开关表达意图，信息量不够。

---

## 3. 方案总览

当前版本采用两层设计：

### 3.1 命中描述层

每一次可造成伤害的命中，统一抽象成一个 `hitDescriptor`，至少包含：

- `HitElement`：本次直伤元素类型
- `ApplyElement`：本次命中向怪物施加的元素类型
- `ApplyGauge`：施加的元素量，默认按 1U 近似
- `CanApplyAura`：本次命中是否会留下元素附着
- `AllowAmplify`
- `AllowCatalyze`
- `AllowTransformative`
- `PreferredAura`
- `ForceReactionName`
- `ReactionBaseDamage`
- `ReactionElement`

这样做比单纯的布尔开关更稳妥，因为它把“造成什么属性伤害”和“给怪物挂什么元素”拆开了。

### 3.2 怪物状态层

敌人状态统一放在 `enemyState` 中，当前版本建模：

- 常规元素附着列表 `Auras`
- `Quicken`
- `ElectroCharged`
- `Burning`
- `DendroCores`
- `LastReaction`

其中：

- 常规附着负责蒸发、融化、冻结、超载、超导、绽放、扩散、结晶等即时判定
- `Quicken` 负责激化底态
- `ElectroCharged / Burning / DendroCores` 负责持续性或延迟型反应

---

## 4. 统一结算流程

统一入口为：

- `resolveReactionForHit.m`

每次命中的结算顺序为：

1. 读取当前 `enemyState`
2. 根据 `hitDescriptor` 解析本次命中的最终元素信息
3. 结合怪物当前附着，判定本次触发的反应类型
4. 计算增幅倍率、激化附加值、即时剧变伤害或生成持续态
5. 更新怪物附着、激化态、持续反应状态
6. 返回本次命中的反应结果包

返回结果统一包含：

- `AmplifyMultiplier`
- `CatalyzeFlatDamage`
- `ReactionDamage`
- `PrimaryReaction`
- `TriggeredReactions`
- 更新后的 `EnemyState`

---

## 5. 为什么“给技能命中打标签”的思路是合理的

这个思路是合理的，而且是当前工程最适合的做法。

原因有三点：

1. 当前工程本质是离散动作模拟，不是逐帧战斗引擎。
2. 角色技能、命座、附魔、转化规则差异很大，必须允许命中自带机制标签。
3. 只有把标签落到“每一次命中”，程序才能知道这次命中究竟能否挂元素、能否吃增幅、能否触发激化或剧变。

但建议把“标签”升级成结构化命中描述，而不是继续堆零散字段。

---

## 6. 动态附魔与不可覆盖附魔

高精度模拟建议把最终命中元素分成三层：

1. 基础动作元素
2. 外部赋魔
3. 自身锁定附魔

推荐规则：

- 若命中声明 `InfusionLocked = true`，则无视外部附魔覆盖。
- 若命中仅声明 `InfusionElement`，则允许被更高优先级机制改写。
- 若角色脚本已经在动作级直接给出 `ActionElement`，则视为“本次命中元素已解析完成”。

当前落地版本里，`simulateSimpleCharacterDPS.m` 仍以动作级 `ActionElement` 作为最终元素来源。
这已经能兼容现在的大部分角色脚本；后续如需更强的附魔系统，可以在命中描述层继续补 `InfusionLocked / ExternalInfusionElement` 等字段。

---

## 7. 反应分类与当前实现口径

### 7.1 增幅反应

- 蒸发
- 融化

当前统一入口会基于当前附着元素决定是否触发，并按元素精通与反应增伤计算倍率。

### 7.2 激化链

- 原激化 `Quicken`
- 蔓激化 `Spread`
- 超激化 `Aggravate`

当前实现已改成基于敌人实际激化态，而不是单纯看队伍元素计数。

### 7.3 剧变反应

- 感电
- 超载
- 超导
- 燃烧
- 扩散
- 结晶

其中：

- `ElectroCharged / Burning / Bloom` 支持建成持续态或延迟态
- `Swirl / Overload / Superconduct` 走即时伤害
- `Crystallize` 当前主要作为状态与标签保留，不单独计算护盾量

### 7.4 绽放链

- Bloom
- 后续可扩展 Burgeon / Hyperbloom

当前基础设施已经为“种子生成 -> 延迟爆炸”留出了状态位。

### 7.5 月系反应

工程内的“月感电 / 月结晶 / 月绽放”属于项目自定义反应家族，不是原神基础反应。

因此当前建议是：

- 判定逻辑仍纳入统一反应引擎
- 数值底数优先使用角色或数据表给定值
- 团队加成继续走 `teamContext.Lunar*Bonus`

本次重构先把统一入口和标准反应主干补齐，月系角色的细化迁移可以在后续分角色收口。

---

## 8. 附着量与衰减

### 8.1 当前落地策略

当前版本把每次命中的元素附着量统一抽象为 `ApplyGauge`，默认近似 1U。

常规元素附着存入：

- `enemyState.Auras(i).Gauge`
- `enemyState.Auras(i).DecayPerSecond`

这样就可以在 `advanceEnemyStateTime.m` 中按时间推进做衰减。

### 8.2 当前精度边界

为了先把统一链路打通，当前版本采用：

- 90 级角色为主
- 默认 1U 附着
- 默认附着衰减秒数采用统一近似

这比旧版固定线性扣减更稳定，但仍不是完整元素量论。

### 8.3 后续建议

如果要继续向更高精度推进，下一步应补：

1. 每个动作真实挂元素量
2. 每个动作独立 ICD 组与命中计数
3. 不同元素或不同强弱附着的真实持续时长
4. 双元素共存时的多反应优先级
5. 前台/后台不同角色触发持续反应时的归属规则

---

## 9. 当前版本已经落地的改进点

本次重构的落地点包括：

1. 新增统一反应入口 `resolveReactionForHit.m`
2. `simulateSimpleCharacterDPS.m` 改为走统一反应入口
3. `advanceEnemyStateTime.m` 可推进持续反应状态
4. `calcReactionDamage.m` 改为按剧变/绽放口径计算，不再误吃防御乘区
5. `applyElementalHitToEnemy.m` 退化为兼容包装层

---

## 10. 当前版本仍保留的限制

当前版本还不是完整逐帧战斗引擎，主要限制有：

1. 队伍模拟仍是“角色分开模拟 + 共用队伍上下文”，不是全队统一时间轴。
2. 双附着共存后的复杂多段连锁反应，当前仍采用近似优先级。
3. 月系反应的全量迁移尚未全部收口到统一入口。
4. 动态赋魔系统目前仍以角色脚本预先决定 `ActionElement` 为主。

这些限制不影响当前统一反应主干落地，但会影响极限高精度配队轮转的最终上限。

---

## 11. 维护建议

以后维护反应相关功能时，优先顺序建议如下：

1. 先补 `hitDescriptor` 字段，不要直接在角色脚本里硬写新分支
2. 反应类型判定统一改 `resolveReactionForHit.m`
3. 持续反应、延迟爆炸统一改 `advanceEnemyStateTime.m`
4. 反应基础倍率统一改 `getReactionBaseDamage.m`
5. 只有角色独占机制，才放回对应 `simulate<Character>DPS.m`

这样可以避免元素反应逻辑重新分散回各个角色脚本。
