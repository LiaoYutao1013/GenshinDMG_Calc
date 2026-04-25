# GenshinDMG_Calc 开发文档

## 1. 文档目标

本文档面向维护者，说明：

- 工程架构
- 代码运行链路
- 新角色接入方法
- 统一配队入口的维护方式
- 常见修改点与注意事项

---

## 2. 总体架构

当前工程可以按四层理解。

## 2.1 第一层：分析入口层

目录：

```text
analysis/
```

职责：

- 作为“可直接运行”的脚本入口
- 初始化路径
- 设置敌人参数
- 选择角色或队伍
- 输出结果

典型文件：

- `analysis/mainSkirkFull.m`
- `analysis/mainNilouFull.m`
- `analysis/mainTeamFull.m`

这层尽量薄，不放核心伤害逻辑。

---

## 2.2 第二层：统一调度层

目录：

```text
functions/
```

核心文件：

- `initProjectPaths.m`
- `getDefaultCharacterConfig.m`
- `simulateTeamDPS.m`
- `simulateCharacterDPS.m`
- `buildTeamContext.m`

职责：

- 统一角色默认配置
- 统一队伍成员解析
- 统一队伍上下文构建
- 统一角色模拟器分发

可以把这一层理解成“编排层”。

---

## 2.3 第三层：角色实现层

目录：

```text
functions/<Character>/
```

典型文件：

- `customArtifact_<Character>.m`
- `simulate<Character>DPS.m`

职责：

- 维护该角色默认配装
- 实现该角色专属状态机和伤害逻辑
- 读入该角色的数据文件
- 生成该角色动作分解表

这层是每个角色的核心实现层。

---

## 2.4 第四层：数据层

目录：

```text
data/<Character>/
```

典型文件：

- `characters_<Character>.csv`
- `talents_<Character>.csv`
- `artifacts_<Character>.csv`
- `rotation_<Character>.txt`

职责：

- 存储角色静态数据
- 存储默认天赋倍率
- 存储默认构筑导出
- 存储动作序列

这层的目标是让角色模拟器尽量“数据驱动”。

---

## 3. 运行链路

这里用“队伍模拟”说明完整调用路径。

## 3.1 入口脚本启动

例如运行：

```matlab
mainTeamFull
```

入口脚本会做几件事：

1. `addpath(genpath(...))`
2. `initProjectPaths()`
3. 构造 `enemy`
4. 构造 `teamMembers`
5. 调用 `simulateTeamDPS`

---

## 3.2 `simulateTeamDPS` 解析成员

文件：

```text
functions/simulateTeamDPS.m
```

职责：

- 接收 `teamSpec`
- 识别它是“名字列表”还是“完整 struct”
- 将每个成员统一转换成完整配置结构体

关键点：

- 支持纯名字，例如 `'Nilou'`
- 支持覆盖结构体，例如 `struct('Name','Nilou','Constellation',2)`

解析逻辑在：

```matlab
localResolveMemberSpec(...)
```

---

## 3.3 `getDefaultCharacterConfig` 生成完整角色配置

文件：

```text
functions/getDefaultCharacterConfig.m
```

职责：

- 根据角色名返回标准配置结构体

统一配置格式大致为：

```matlab
cfg = struct( ...
    'Name', 'Nilou', ...
    'DisplayName', "妮露", ...
    'TalentLevel', 10, ...
    'Constellation', 0, ...
    'Build', customArtifact_Nilou(), ...
    'RotationFile', '.../rotation_Nilou.txt');
```

注意：

- 这是统一入口里所有角色共享的配置契约
- 新角色想接进统一入口，必须先在这里注册

覆盖逻辑通过：

```matlab
localApplyConfigOverrides(...)
applyStructOverrides(...)
```

来实现。

---

## 3.4 `buildTeamContext` 构造共享上下文

文件：

```text
functions/buildTeamContext.m
```

职责：

- 统计队伍成员元素
- 计算共享 buff / shred / 反应标记
- 为多个角色提供队友态条件

例如当前会构造：

- `AllDMGBonus`
- `HydroResShred`
- `CryoResShred`
- `DendroResShred`
- `ElectroResShred`
- `GeoResShred`
- `HydroCount`
- `DendroCount`
- `LunarBloomEnabled`
- `NilouPureBloomTeam`
- `ReactionCritRate`

设计原则：

- 队伍共用状态尽量在这里集中计算
- 角色模拟器只消费结果，不在每个角色里重复推导

---

## 3.5 `simulateCharacterDPS` 做统一分发

文件：

```text
functions/simulateCharacterDPS.m
```

职责：

- 根据 `memberCfg.Name` 选择对应角色模拟器

例如：

```matlab
case 'nilou'
    [totalDMG, dps, breakdown, rotationTime] = simulateNilouDPS(...)
```

这是新角色接入时必须修改的第二个关键点。

---

## 3.6 角色模拟器执行专属逻辑

文件示例：

- `functions/Nilou/simulateNilouDPS.m`
- `functions/Ineffa/simulateIneffaDPS.m`
- `functions/Lauma/simulateLaumaDPS.m`

角色模拟器通常会做这些事情：

1. 处理默认参数
2. 读取 `characters_*.csv`
3. 读取 `talents_*.csv`
4. 读取 `rotation_*.txt`
5. 初始化角色状态
6. 遍历动作 token
7. 按动作修改状态并计算伤害
8. 累加 `totalDMG`
9. 记录 `breakdown`
10. 返回统一输出

---

## 4. 统一的模拟器接口约定

所有角色模拟器建议统一签名：

```matlab
function [totalDMG, dps, breakdown, rotationTime] = simulateXxxDPS( ...
    build, enemy, seqFile, talentLevel, constellation, teamContext)
```

约定含义：

- `build`：配装参数
- `enemy`：敌人参数
- `seqFile`：手法文件
- `talentLevel`：技能等级
- `constellation`：命座
- `teamContext`：队伍上下文

统一输出：

- `totalDMG`
- `dps`
- `breakdown`
- `rotationTime`

为什么要统一：

- 统一调度层可以不关心具体角色实现
- 配队模拟器可以通用聚合
- 新角色接入成本低

---

## 5. 工具函数职责

## 5.1 `readRotationTokens.m`

职责：

- 从 `rotation_*.txt` 读取动作 token

特点：

- 忽略空行
- 忽略 `#` 注释行
- 每行只取第一个 token

---

## 5.2 `getTalentValue.m`

职责：

- 从天赋表中按 `Skill + Param + talentLevel` 查倍率

注意：

- 先从目标等级往下回退找最近可用值
- 如果表里没有完整 `Level1 ~ Level15`，也能运行

当前它已经支持：

- 先按等级向下回退
- 如果该等级列不存在，再按表里已有的 `Level*` 列找最近可用值

这就是为什么新接入的简化角色可以只写 `Level10`。

---

## 5.3 `calcDamageMultiplier.m`

职责：

- 统一处理防御乘区和抗性乘区

这让角色模拟器不必重复写敌人结算逻辑。

---

## 5.4 `calcExpectedCritMultiplier.m`

职责：

- 按暴击率和暴伤输出期望暴击乘区

---

## 5.5 `calcReactionDamage.m`

职责：

- 提供一个简化的反应伤害帮助函数

当前主要用于：

- Bloom / Lunar-Bloom 类
- Lunar-Charged 类
- Lunar-Crystallize 类

设计目的：

- 避免每个角色重复写一遍 EM 反应公式

---

## 5.6 `applyStructOverrides.m`

职责：

- 将覆盖字段合并到默认 struct

主要服务于：

- `getDefaultCharacterConfig`
- 队伍入口里的成员覆盖

---

## 6. 新角色接入方法

这里是当前工程最重要的维护流程。

## 6.1 第一步：建立角色目录

创建：

```text
functions/<Character>/
data/<Character>/
```

---

## 6.2 第二步：补数据文件

至少需要：

```text
data/<Character>/characters_<Character>.csv
data/<Character>/talents_<Character>.csv
data/<Character>/rotation_<Character>.txt
```

通常还要有：

```text
data/<Character>/artifacts_<Character>.csv
```

但这个文件通常由 `customArtifact_<Character>.m` 自动写出。

---

## 6.3 第三步：补角色函数

创建：

```text
functions/<Character>/customArtifact_<Character>.m
functions/<Character>/simulate<Character>DPS.m
```

其中：

- `customArtifact` 负责默认配装
- `simulate` 负责实际伤害模拟

---

## 6.4 第四步：补单角色入口

创建：

```text
analysis/main<Character>Full.m
```

作用：

- 快速单跑
- 快速验证
- 快速对命座做 smoke test

---

## 6.5 第五步：注册统一入口

至少要改这些地方：

### `functions/initProjectPaths.m`

把新角色目录加到路径里。

### `functions/getDefaultCharacterConfig.m`

注册默认配置。

### `functions/simulateCharacterDPS.m`

注册角色分发。

### `functions/buildTeamContext.m`

补元素映射。

如果该角色有特殊队伍机制，也要在这里补队伍上下文字段。

---

## 7. 维护现有角色时应该改哪里

## 7.1 改默认配装

改：

```text
functions/<Character>/customArtifact_<Character>.m
```

如果希望默认 CSV 也同步更新，重新运行该函数即可。

---

## 7.2 改倍率

改：

```text
data/<Character>/talents_<Character>.csv
```

如果要提高模型精度，推荐：

- 增加更多 `Level*` 列
- 把原本合并的参数拆细

---

## 7.3 改手法

改：

```text
data/<Character>/rotation_<Character>.txt
```

如果增加了新的动作 token，要同步修改：

```text
functions/<Character>/simulate<Character>DPS.m
```

否则动作会被当作未知动作或被跳过。

---

## 7.4 改角色机制

改：

```text
functions/<Character>/simulate<Character>DPS.m
```

例如：

- 姿态切换
- 资源计数
- 命座追加段
- 召唤物行为
- 后台协同

---

## 7.5 改队伍机制

优先改：

```text
functions/buildTeamContext.m
```

适合放在这里的逻辑：

- 队伍成员数统计
- 元素统计
- 全队共享增伤
- 抗性削减
- 队伍反应开关

不适合放这里的逻辑：

- 只有单角色自身知道的内部状态机
- 需要逐动作消耗的个人资源

---

## 8. 当前代码的设计选择

## 8.1 为什么采用“CSV + simulator”模式

优点：

- 数据和逻辑分离
- 改倍率不一定要改 MATLAB 代码
- 适合快速补角色
- 适合后续导出和对比

缺点：

- 如果天赋表拆得不够细，模拟器里会出现“简化合并参数”
- 高精度帧级行为仍然需要写专门逻辑

---

## 8.2 为什么统一入口只吃标准配置结构体

这样做的好处是：

- 单人和队伍都可以复用同一套角色配置
- 角色默认值只维护一份
- 队伍里可以只覆盖少数字段

---

## 8.3 为什么 `breakdown` 统一用表格

表格适合：

- 直接 `disp`
- 后续导出 Excel
- 追加 `Character` 列后做队伍聚合

当前统一约定列是：

- `Action`
- `Damage`
- `Note`

队伍聚合后会追加：

- `Character`

---

## 8.4 为什么有些新角色只写了 `Level10`

因为当前工程支持“简化角色先接入统一体系，再逐步细化”。

`getTalentValue.m` 已经支持：

- 当完整等级列缺失时
- 回退到最近可用等级列

因此：

- 先接统一入口是可行的
- 后续再补完整等级列，不需要重构主架构

---

## 9. 当前特殊点

## 9.1 `Furina` 是一个历史特殊实现

`simulateCharacterDPS.m` 里对 `Furina` 有单独处理：

- 她当前更多通过修改 `Build` 吃队伍 buff
- 而不是完全依赖 `teamContext`

维护时要注意：

- 如果以后要重构统一风格，优先从 `Furina` 开始统一参数接口

---

## 9.2 新补的 5 个角色当前是“可运行简化版”

包括：

- `Lauma`
- `Ineffa`
- `Linnea`
- `Nilou`
- `Nefer`

当前特点：

- 已经支持单人模拟
- 已经支持配队模拟
- 已经支持命座切换
- 已经接入统一入口

但它们的精度还不是逐帧完整版本。

如果以后你拿到更完整的原始技能数据，建议优先完善：

1. `talents_*.csv`
2. `rotation_*.txt`
3. `simulate<Character>DPS.m`

---

## 10. 推荐的维护习惯

## 10.1 先改数据，再改逻辑

如果只是倍率变化，优先改 `CSV`，不要先改模拟器。

## 10.2 队伍共享逻辑集中到 `buildTeamContext`

不要在多个角色里分别计算同一个共享 Buff。

## 10.3 单角色和配队都要 smoke test

新增或重构后，建议至少跑：

- `main<Character>Full`
- `mainTeamFull`

## 10.4 不要破坏统一返回格式

所有角色模拟器尽量保持：

```matlab
[totalDMG, dps, breakdown, rotationTime]
```

否则统一调度层要开始分支特判，维护成本会上升。

---

## 11. 建议的验证命令

可以直接用 MATLAB batch 做 smoke test。

### 单角色

```powershell
& 'D:\Program Files\MATLAB\R2024b\bin\matlab.exe' -batch "cd('c:/Users/ASUS/MATLAB/Projects/GenshinDMG_Calc/analysis'); mainNilouFull"
```

### 队伍

```powershell
& 'D:\Program Files\MATLAB\R2024b\bin\matlab.exe' -batch "cd('c:/Users/ASUS/MATLAB/Projects/GenshinDMG_Calc/analysis'); mainTeamFull"
```

### 自定义队伍

```powershell
& 'D:\Program Files\MATLAB\R2024b\bin\matlab.exe' -batch "cd('c:/Users/ASUS/MATLAB/Projects/GenshinDMG_Calc'); addpath(genpath(fullfile(pwd, 'functions'))); initProjectPaths; teamMembers = {struct('Name','Lauma','Constellation',2), struct('Name','Nilou','Constellation',2), struct('Name','Nefer','Constellation',1), struct('Name','Ineffa','Constellation',0)}; [teamResult, memberResults] = simulateTeamDPS(teamMembers, struct('Level',90,'Res',0.10,'DefReduct',0)); disp(teamResult.Summary);"
```

---

## 12. 后续可继续优化的方向

建议优先级如下：

1. 统一 `Furina` 的 teamContext 接口
2. 把新角色的简化倍率表补成完整等级表
3. 继续细化反应模型
4. 为 `analysis/` 增加更多批量对比入口
5. 把结果导出封装成统一函数

---

## 13. 维护入口总结

如果你以后只记住一套最重要的文件，请记住这几个：

- `analysis/mainTeamFull.m`
- `functions/getDefaultCharacterConfig.m`
- `functions/simulateTeamDPS.m`
- `functions/buildTeamContext.m`
- `functions/simulateCharacterDPS.m`
- `functions/<Character>/simulate<Character>DPS.m`
- `data/<Character>/talents_<Character>.csv`

这是当前工程最核心的一条主链。

