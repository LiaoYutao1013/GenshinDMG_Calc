# GenshinDMG_Calc 使用文档

## 1. 工程目标

本工程是一个基于 MATLAB 的《原神》伤害模拟工程，当前主要支持：

- 单角色循环伤害模拟
- 多角色配队伤害模拟
- 基于角色默认配置的统一入口调用
- 通过 `CSV + rotation token + MATLAB simulator` 的方式快速扩展新角色

当前工程已经形成了两条主要使用路径：

- 单人模拟：直接运行 `analysis/main<角色>Full.m`
- 队伍模拟：直接运行 `analysis/mainTeamFull.m`

---

## 2. 目录结构

工程核心目录如下：

```text
analysis/      入口脚本，面向“直接运行”
functions/     核心逻辑、统一调度、角色模拟器
data/          角色基础数据、天赋倍率表、默认配装、手法文件
optimization/  预留给后续优化分析
output/        结果导出目录
resources/     MATLAB 工程元数据
```

最常用的目录是：

- `analysis/`
- `functions/`
- `data/`

---

## 3. 使用前准备

### 3.1 打开方式

可以直接：

1. 用 MATLAB 打开工程根目录
2. 或打开 `GenshinDMG_Calc.prj`

### 3.2 路径初始化

大部分 `analysis/` 入口脚本都会自动调用：

```matlab
initProjectPaths();
```

如果你在 MATLAB 命令行里直接调函数，建议先执行：

```matlab
cd('c:/Users/ASUS/MATLAB/Projects/GenshinDMG_Calc');
addpath(genpath(fullfile(pwd, 'functions')));
initProjectPaths();
```

---

## 4. 当前统一入口支持的角色

当前已经接入统一入口的角色名包括：

- `Skirk`
- `Escoffier`
- `Arlecchino`
- `Furina`
- `Lauma`
- `Ineffa`
- `Linnea`
- `Nilou`
- `Nefer`

其中新接入的中文对应为：

- `Lauma` -> 菈乌玛
- `Ineffa` -> 伊涅芙
- `Linnea` -> 莉奈娅
- `Nilou` -> 妮露
- `Nefer` -> 奈芙尔

说明：

- 统一入口内部主要用英文键名
- `getDefaultCharacterConfig` 里也兼容部分中文名
- 写脚本时建议优先使用英文键名，最稳定

---

## 5. 单角色模拟

## 5.1 最简单的使用方法

直接运行对应入口脚本，例如：

- `analysis/mainSkirkFull.m`
- `analysis/mainNilouFull.m`
- `analysis/mainLaumaFull.m`

例如运行：

```matlab
mainNilouFull
```

这些脚本会自动：

1. 初始化路径
2. 设置默认敌人
3. 读取默认角色配置
4. 调用对应 `simulate<角色>DPS`
5. 输出总伤害、DPS、循环时长、分解表

---

## 5.2 修改命座

每个单角色入口脚本顶部都保留了命座变量，例如：

```matlab
constellation = 0;
cfg = getDefaultCharacterConfig('Nilou', struct('Constellation', constellation));
```

你只需要把：

```matlab
constellation = 0;
```

改成：

```matlab
constellation = 2;
```

即可测试 `C2`。

支持范围默认按 `0 ~ 6` 处理。

---

## 5.3 修改敌人参数

单角色脚本里通常有：

```matlab
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
```

可修改字段包括：

- `Level`：敌人等级
- `Res`：基础抗性
- `DefReduct`：敌人防御减免
- `DefIgnore`：部分函数支持防御忽视

例如测试高抗敌人：

```matlab
enemy = struct('Level', 90, 'Res', 0.40, 'DefReduct', 0);
```

---

## 5.4 直接从命令行调用角色模拟器

统一格式通常为：

```matlab
[totalDMG, dps, breakdown, rotationTime] = simulateNilouDPS( ...
    build, enemy, seqFile, talentLevel, constellation, teamContext);
```

常用参数说明：

- `build`：角色配装结构体
- `enemy`：敌人参数结构体
- `seqFile`：手法文件路径
- `talentLevel`：技能等级
- `constellation`：命座等级
- `teamContext`：队伍上下文，单人时通常可传 `[]`

如果你只是单人测试，最常见写法是：

```matlab
cfg = getDefaultCharacterConfig('Lauma', struct('Constellation', 2));
[totalDMG, dps, breakdown, rotationTime] = simulateLaumaDPS( ...
    cfg.Build, ...
    struct('Level', 90, 'Res', 0.10, 'DefReduct', 0), ...
    cfg.RotationFile, ...
    cfg.TalentLevel, ...
    cfg.Constellation, ...
    []);
```

---

## 6. 队伍模拟

## 6.1 最简单的使用方法

直接运行：

```matlab
mainTeamFull
```

对应脚本：

- `analysis/mainTeamFull.m`

它会：

1. 设置统一敌人
2. 在一个入口里定义队伍成员
3. 调用 `simulateTeamDPS`
4. 输出队伍总伤害、队伍 DPS、各成员贡献、动作分解表

---

## 6.2 在统一入口里选择角色和命座

当前推荐用法是直接编辑：

```matlab
teamMembers = { ...
    struct('Name', 'Lauma', 'Constellation', 2), ...
    struct('Name', 'Nilou', 'Constellation', 2), ...
    struct('Name', 'Nefer', 'Constellation', 1), ...
    struct('Name', 'Ineffa', 'Constellation', 0) ...
};
```

这就是当前工程推荐的统一配队入口。

优点是：

- 角色选择集中在一个地方
- 命座控制集中在一个地方
- 不需要再分散修改每个角色脚本

---

## 6.3 队伍成员可写成什么形式

### 形式 1：只写名字

```matlab
teamMembers = {'Skirk', 'Escoffier', 'Furina', 'Arlecchino'};
```

含义：

- 使用每个角色的默认配装
- 使用默认天赋等级
- 使用默认命座

### 形式 2：写结构体覆盖默认值

```matlab
teamMembers = { ...
    struct('Name', 'Nilou', 'Constellation', 2), ...
    struct('Name', 'Lauma', 'Constellation', 0, 'TalentLevel', 10), ...
    struct('Name', 'Nefer', 'Constellation', 1), ...
    struct('Name', 'Furina', 'Constellation', 1) ...
};
```

可覆盖的字段常见有：

- `Name`
- `Constellation`
- `TalentLevel`
- `RotationFile`
- `Build`

例如只改某个词条：

```matlab
teamMembers = { ...
    struct( ...
        'Name', 'Ineffa', ...
        'Constellation', 2, ...
        'Build', struct('CritRate', 0.90, 'CritDMG', 2.20) ...
    ), ...
    'Furina', ...
    'Nilou', ...
    'Lauma' ...
};
```

这里 `Build` 中只会覆盖你写出来的字段，其余默认字段保留不变。

---

## 6.4 直接调用 `simulateTeamDPS`

可以在 MATLAB 命令行中直接这样使用：

```matlab
teamMembers = { ...
    struct('Name', 'Lauma', 'Constellation', 2), ...
    struct('Name', 'Nilou', 'Constellation', 2), ...
    struct('Name', 'Nefer', 'Constellation', 1), ...
    struct('Name', 'Ineffa', 'Constellation', 0) ...
};

enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
[teamResult, memberResults] = simulateTeamDPS(teamMembers, enemy);
```

---

## 6.5 传入完整 `teamSpec`

如果你想额外设置循环时长和共享 Buff，可以写成：

```matlab
teamSpec = struct( ...
    'Members', { ...
        { ...
            struct('Name', 'Lauma', 'Constellation', 2), ...
            struct('Name', 'Nilou', 'Constellation', 2), ...
            struct('Name', 'Nefer', 'Constellation', 1), ...
            struct('Name', 'Ineffa', 'Constellation', 0) ...
        } ...
    }, ...
    'RotationDuration', 20, ...
    'SharedBuffs', struct( ...
        'AllDMGBonus', 0.20, ...
        'EMBonus', 100 ...
    ) ...
);

[teamResult, memberResults] = simulateTeamDPS(teamSpec, enemy);
```

`SharedBuffs` 常见字段包括：

- `AllDMGBonus`
- `FlatATK`
- `ATKBonus`
- `EMBonus`
- `HydroResShred`
- `CryoResShred`
- `PyroResShred`
- `DendroResShred`
- `ElectroResShred`
- `GeoResShred`

---

## 7. 输出结果怎么看

## 7.1 单角色输出

单角色模拟器统一返回：

```matlab
[totalDMG, dps, breakdown, rotationTime]
```

含义：

- `totalDMG`：这一轮手法总伤害
- `dps`：按该角色本轮动作时长计算的单角色 DPS
- `breakdown`：动作分解表
- `rotationTime`：该角色本轮动作耗时

`breakdown` 常见列：

- `Action`
- `Damage`
- `Note`

---

## 7.2 队伍输出

队伍模拟返回：

```matlab
[teamResult, memberResults] = simulateTeamDPS(...)
```

其中：

- `teamResult.TotalDMG`：全队总伤害
- `teamResult.DPS`：按队伍循环时长计算的队伍 DPS
- `teamResult.Summary`：每个成员的贡献表
- `teamResult.Breakdown`：合并后的动作表
- `teamResult.TeamContext`：这次配队构建出的共享上下文

`teamResult.Summary` 常见列：

- `Character`
- `TotalDMG`
- `TeamCycleDPS`
- `ActionTime`
- `StandaloneDPS`

注意：

- `TeamCycleDPS` 是按整个队伍循环长度折算
- `StandaloneDPS` 是按角色自己动作耗时折算

两者都保留，是为了避免“短轴角色看起来虚高”或者“长轴角色看起来过低”。

---

## 8. 数据文件如何使用

每个角色通常对应：

```text
data/<Character>/
    characters_<Character>.csv
    talents_<Character>.csv
    artifacts_<Character>.csv
    rotation_<Character>.txt
```

作用分别是：

- `characters_*.csv`：基础属性、武器类型、元素
- `talents_*.csv`：倍率表
- `artifacts_*.csv`：默认配装导出
- `rotation_*.txt`：动作序列

---

## 8.1 修改默认配装

默认配装通常定义在：

```text
functions/<Character>/customArtifact_<Character>.m
```

例如：

- `functions/Nilou/customArtifact_Nilou.m`
- `functions/Ineffa/customArtifact_Ineffa.m`

运行这些函数时，会返回 `build`，并把默认配装写入：

```text
data/<Character>/artifacts_<Character>.csv
```

---

## 8.2 修改手法

手法文件通常是：

```text
data/<Character>/rotation_<Character>.txt
```

每行一个动作 token，例如：

```text
E
Dance1
Dance2
Dance3
Q
Bloom
```

解析由 `readRotationTokens.m` 负责。

规则：

- 空行会跳过
- 以 `#` 开头的行为注释
- 每一行只读取第一个 token

---

## 9. 常见使用场景

## 9.1 比较同角色不同命座

最简单的方法：

1. 打开 `analysis/main<角色>Full.m`
2. 修改 `constellation`
3. 连续运行多次对比输出

---

## 9.2 比较同一角色不同配装

可以直接覆盖默认 `Build`：

```matlab
cfg = getDefaultCharacterConfig('Nilou', struct( ...
    'Constellation', 2, ...
    'Build', struct('HPBonus', 2.10, 'EM', 450) ...
));
```

---

## 9.3 比较不同队伍

直接在 `mainTeamFull.m` 里替换 `teamMembers`。

例如：

```matlab
teamMembers = { ...
    struct('Name', 'Lauma', 'Constellation', 2), ...
    struct('Name', 'Nilou', 'Constellation', 2), ...
    struct('Name', 'Nefer', 'Constellation', 1), ...
    struct('Name', 'Furina', 'Constellation', 1) ...
};
```

---

## 10. 当前模型精度说明

当前工程不是所有角色都处于同一精细度。

大致可以分为两类：

- 相对更完整的角色模型
  - 如 `Skirk / Escoffier / Arlecchino / Furina`
- 为统一入口快速接入的简化模型
  - 如新补充的 `Lauma / Ineffa / Linnea / Nilou / Nefer`

这意味着：

- 统一入口、命座切换、配队联动已经可用
- 但部分新角色的具体动作细节、帧级行为、精确天赋拆分仍是简化表达

如果后续有更完整的倍率表或技能原始数据，可以继续细化。

---

## 11. 推荐的使用顺序

如果你第一次用这个工程，建议按下面顺序：

1. 先运行 `analysis/mainSkirkFull.m` 或 `analysis/mainNilouFull.m`
2. 看懂单角色返回的 `breakdown`
3. 再运行 `analysis/mainTeamFull.m`
4. 用 `teamMembers` 改队伍和命座
5. 最后再去修改 `Build / rotation / SharedBuffs`

---

## 12. 常见问题

## 12.1 报找不到函数

先确认已经执行：

```matlab
addpath(genpath(fullfile(pwd, 'functions')));
initProjectPaths();
```

## 12.2 改了倍率没生效

检查：

- 是否改的是正确角色目录下的 `talents_*.csv`
- 是否调用的还是旧的默认 `artifacts_*.csv`
- 是否入口脚本里用了别的 `RotationFile`

## 12.3 队伍里某些角色伤害为 0

先看 `breakdown.Note` 列。

很多角色在当前实现里会把“未满足条件”的原因写在 `Note` 里，例如：

- 没有进入对应姿态
- 没有反应前置条件
- 没有可消耗资源

---

## 13. 相关文档

如果你要维护工程或继续开发，请看：

- `docs/DEVELOPMENT.md`

