# 元素反应引擎设计与维护说明

## 1. 文档目标

本文档说明当前工程中统一元素反应结算层的设计目标、数据结构、计算流程、已落地范围与后续扩展方向。

本次重构的核心目标是把过去分散在以下位置的反应逻辑统一起来：

- `functions/simulateSimpleCharacterDPS.m`
- `functions/applyElementalHitToEnemy.m`
- 各角色的自定义模拟脚本

统一成一条明确链路：

`命中描述 -> 怪物元素状态 -> 反应判定 -> 反应伤害结算 -> 状态回写`

---

## 2. 为什么需要统一入口

重构前存在几个明显问题：

1. 增幅、激化、剧变分别走不同分支，不是统一入口。
2. 激化更多依赖“队伍里是否有草/雷”这种静态条件，而不是敌人当前实际的激化底状态。
3. 扩散、超载、感电、燃烧、结晶、绽放没有统一按敌人当前附着来判定。
4. 剧变/绽放类伤害错误复用了直伤乘区，误吃防御区。
5. 角色脚本只能靠 `AllowAmplify / AllowCatalyze / AllowTransformative` 这类松散开关表达意图，信息不够完整。

---

## 3. 当前方案总览

当前统一反应方案分成两层。

### 3.1 命中描述层

每一次会造成伤害或可能触发反应的命中，都抽象成一个 `hitDescriptor`。

当前通用字段包括：

- `HitElement`
- `ApplyElement`
- `ApplyGauge`
- `CanApplyAura`
- `AllowAmplify`
- `AllowCatalyze`
- `AllowTransformative`
- `PreferredAura`
- `ForceReactionName`
- `ReactionElement`
- `ReactionBonus`
- `ReactionBaseDamage`
- `ReactionATKWeight / HPWeight / DEFWeight / EMWeight`
- `ReactionCritRate / ReactionCritDMG`
- `ResolveReactionAsDamage`

额外地，通用模拟器现在会把完整面板值一并塞进命中描述里：

- `ATKValue`
- `HPValue`
- `DEFValue`
- `EMValue`

这样旧字段 `ReactionATKWeight` 之类不再错误地只吃平面板，而是吃完整结算面板。

### 3.2 怪物状态层

敌人状态统一收敛到 `enemyState`：

- `Auras`：常规元素附着列表
- `Quicken`：原激化底状态
- `ElectroCharged`：感电持续状态
- `Burning`：燃烧持续状态
- `DendroCores`：绽放种子列表
- `LastReaction`

---

## 4. 统一结算入口

统一入口为：

- `functions/resolveReactionForHit.m`

每次命中的处理顺序如下：

1. 先推进敌人状态时间。
2. 结算时间推进期间产生的持续反应包。
3. 读取当前命中的元素、挂元素、挂元素量与反应标签。
4. 基于敌人当前附着与激化底状态判定本次主反应。
5. 分别计算：
   - 增幅倍率 `AmplifyMultiplier`
   - 激化附加值 `CatalyzeFlatDamage`
   - 独立反应伤害 `ReactionDamage`
6. 回写附着、耗量、激化状态、持续状态与种子状态。

返回结果统一包含：

- `EnemyState`
- `AmplifyMultiplier`
- `CatalyzeFlatDamage`
- `ReactionDamage`
- `PrimaryReaction`
- `TriggeredReactions`

---

## 5. 当前已落地的反应分类

### 5.1 增幅反应

- 蒸发 `Vaporize`
- 融化 `Melt`

特点：

- 直接乘在本次直伤上。
- 按元素精通与反应增伤计算增幅倍率。
- 会消耗当前怪物附着量。

### 5.2 激化链

- 原激化 `Quicken`
- 蔓激化 `Spread`
- 超激化 `Aggravate`

特点：

- 现在基于敌人当前 `Quicken` 状态判定，不再只看队伍元素计数。
- 蔓激化/超激化作为附加直伤返回，由上层继续走角色对应元素的直伤口径。

### 5.3 剧变与独立反应伤害

已统一到 `calcReactionDamage.m` 的包括：

- 感电 `ElectroCharged`
- 超载 `Overload`
- 超导 `Superconduct`
- 燃烧 `Burning`
- 扩散 `Swirl`
- 结晶 `Crystallize`
- 绽放 `Bloom`
- 项目内月系反应：
  - `LunarCharged`
  - `LunarCrystallize`
  - `LunarBloom`

当前口径：

- 吃基础反应值
- 吃精通
- 吃反应增伤
- 吃抗性区
- 不吃防御区
- 若上层显式传入反应暴击，则额外吃期望暴击区

---

## 6. 持续反应与延迟反应

`functions/advanceEnemyStateTime.m` 当前负责：

- 常规 aura 衰减
- `Quicken` 衰减
- 感电 tick
- 燃烧 tick
- 绽放种子倒计时与爆炸

它会返回 `reactionPackets`，统一由 `resolveReactionForHit.m` 在每次命中开始时回收结算。

这意味着：

- 不再需要各个角色脚本自己单独处理感电/燃烧/种子 tick。
- 只要角色命中持续推进时间，持续反应伤害就会被自然带出。

---

## 7. 通用模拟器如何接入统一引擎

`functions/simulateSimpleCharacterDPS.m` 已经改为：

1. 每个动作按 `HitCount` 切成多个命中时间片。
2. 每个命中先算本体直伤。
3. 再构造 `hitDescriptor` 调用 `resolveReactionForHit(...)`。
4. 将返回结果应用到本次命中：
   - 直伤乘 `AmplifyMultiplier`
   - 加上 `CatalyzeFlatDamage`
   - 加上 `ReactionDamage`
5. 将 `TriggeredReactions` 写回备注。

同时补了两个兼容点：

1. 优先读取动作级 `PreferredAmplifyAura`，没有时才回退到角色级 `PreferredAmplifyAura`。
2. 对旧的“独立反应动作”做兼容：
   - 若动作满足 `AllowTransformative = 1`
   - 且带有 `ReactionBaseDamage` 或 `Reaction*Weight`
   - 且 `MVOverride = 0`
   - 则默认视为 `ResolveReactionAsDamage = true`

这能兼容当前工程里类似：

- Kaveh 的草原核爆炸
- Mizuki / Heizou / Prune 的扩散动作

---

## 8. 当前精度边界

当前版本虽然已经是统一入口，但还不是完整逐帧战斗引擎。主要边界如下：

1. `ApplyGauge` 当前默认仍常用 1U 近似，很多动作还没录入真实挂元素量。
2. 还没有完整 ICD 组与命中序列级挂元素次数控制。
3. 双 aura 共存与复杂多反应优先级仍是近似处理。
4. 冻结、碎冰、超绽放、烈绽放尚未完整迁入统一主干。
5. 月系反应已经纳入统一入口，但各角色特有机制还需要逐角色继续细抠。
6. 动态附魔系统目前仍以动作级 `ActionElement` 为主，没有完全抽象成“基础元素 + 外部附魔 + 锁定附魔”的三层系统。

---

## 9. 推荐的高精度扩展路线

如果要继续提升精度，建议按下面顺序推进。

### 第一阶段：补全命中描述

给动作补充：

- `ApplyGauge`
- `CanApplyAura`
- `ForceReactionName`
- `ResolveReactionAsDamage`
- 后续可加：
  - `ICDGroup`
  - `ICDHitRule`
  - `InfusionLocked`
  - `ExternalInfusionElement`

### 第二阶段：补真实附着与耗量

目标是让每个主要角色的关键动作都有真实挂元素量，而不是一律默认 1U。

### 第三阶段：补 ICD

同一动作多段命中时，需要区分：

- 哪些段造成伤害但不挂元素
- 哪些段既造成伤害又挂元素
- 哪些段共享同一 ICD 组

### 第四阶段：补完整反应族

继续接入：

- Frozen
- Shatter
- Burgeon
- Hyperbloom

并细化对应归属与反应元素判定。

### 第五阶段：补三层附魔系统

推荐把最终命中元素拆成三层：

1. 基础动作元素
2. 外部可覆盖附魔
3. 自身不可覆盖附魔

规则建议：

- 若 `InfusionLocked = true`，则忽略外部附魔覆盖。
- 若只有 `InfusionElement`，则允许被更高优先级附魔改写。
- 当前若动作已经显式写 `ActionElement`，仍视为已解析完成，优先兼容现有脚本。

---

## 10. 维护建议

以后维护反应逻辑时，建议遵守以下顺序：

1. 先补 `hitDescriptor` 字段，不要直接在角色脚本里硬写新的反应分支。
2. 反应判定统一改 `resolveReactionForHit.m`。
3. 持续反应与延迟反应统一改 `advanceEnemyStateTime.m`。
4. 基础反应系数统一改 `getReactionBaseDamage.m`。
5. 只有角色独占机制，才回写到对应 `simulate<Character>DPS.m`。

这样可以避免元素反应逻辑重新散回各个角色脚本。

---

## 11. 本轮已经完成的落地项

本轮已完成：

1. 新增统一入口 `resolveReactionForHit.m`。
2. 重构 `createEnemyState.m` 与 `advanceEnemyStateTime.m`，支持 aura、激化、感电、燃烧、种子。
3. `calcReactionDamage.m` 改为独立反应伤害口径，不再误吃防御区。
4. `simulateSimpleCharacterDPS.m` 接入统一反应入口。
5. 修正旧 `ReactionATKWeight / HPWeight / DEFWeight / EMWeight` 对完整面板值的兼容。
6. 补动作级 `PreferredAmplifyAura` 兼容。
7. 补旧“独立反应动作”兼容标记推断。

---

## 12. 下一步建议

下一步优先做三件事：

1. 给主要角色补真实 `ApplyGauge` 与关键动作的 ICD。
2. 把 Burgeon / Hyperbloom / Frozen / Shatter 接到统一入口。
3. 对已经接入通用模拟器的草、风、水、火体系角色做一轮逐角色校准。
