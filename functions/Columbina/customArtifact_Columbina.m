function build = customArtifact_Columbina(selectedWeapon)
    % ====================== 在这里修改配置 ======================
    artifactSet = '黄金剧团';       % ← 4件套
    
    % 读取武器数据库
    weapons = readtable('../data/weapons.csv');
    w = weapons(contains(weapons.Name, selectedWeapon), :);
    if isempty(w), w = weapons(1,:); end   % 默认第一把
    
    % ====================== 圣遗物乘区字段（全部可自定义） ======================
    build = struct(...
    'Weapon',           w.Name{1}, ...
    'WeaponATK',        w.BaseATK, ...                    % 武器基础攻击
    'WeaponSubType',    w.SubstatType{1}, ...             % 副词条类型
    'WeaponSubValue',   w.SubstatValue, ...               % 副词条数值
    'HPBonus',          0.466 + 0.466 + 0.496, ...        % 花/沙/杯 HP%（穹境示现之夜主词条建议）
    'CritRate',         0.70 + 0.311, ...                 % 总暴击率（头/副词条）
    'CritDMG',          1.80 + 1.20 + (w.SubstatValue * strcmp(w.SubstatType{1}, 'CD')), ...  
    'HydroDMGBonus',    0.00, ...                         % 水伤杯（穹境示现之夜可叠加）
    'SkillDMGBonus',    0.60, ...                         % 战技伤害加成（2件套）
    'BurstDMGBonus',    0.00, ...                         % 爆发伤害加成
    'NormalDMGBonus',   0.00, ...                         % 普攻伤害加成
    'ReactionDMGBonus', 0.00, ...                         % 月曜反应伤害提升（擢升/月兆）
    'EM',               120, ...                          % 元素精通（月感电/绽放关键）
    'ResShred',         0.90, ...                         % 元素抗性削减（队友或套装）
    'Set4_MoonPromote',     0.00, ...                     % 擢升（月曜反应伤害提升）
    'Set4_GravityBonus',    0.00, ...                     % 引力值积攒速度/矩波干涉加成
    'Set4_InterfereBonus',  0.00, ...                     % 矩波干涉额外伤害倍率
    'PromoteBonus',         0.00, ...                    % 通用擢升（天赋/命座）
    'TeamHPAbove50Mult',    0.00 ...                      % 队友>50%HP乘区（芙宁娜类似机制）
    );

    % 保存配置
    writetable(struct2table(build), '../data/artifacts_Furina.csv');
    fprintf('✅ 配置已保存！武器【%s】 + 圣遗物【%s】\n', build.Weapon, artifactSet);
    disp('所有乘区字段已拆开，可直接在上面修改数值');
end