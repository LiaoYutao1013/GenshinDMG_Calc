% ========================================================
% customArtifact_Furina.m
% 芙宁娜圣遗物 + 武器自定义脚本
%
% 执行方式：
%   build = customArtifact_Furina();
%   会自动生成 data/artifacts_Furina.csv
%   simulateFurinaDPS.m 可直接读取此 CSV
% ========================================================

function build = customArtifact_Furina()
    % Furina keeps a slightly richer build schema because her simulator
    % mixes direct Hydro damage, summon behavior, and team HP interactions.
    % Central place for Furina's default build assumptions. The returned
    % struct is mirrored to CSV to match the rest of the project.
    % ================== 在这里修改你的实际配置 ==================
    % 武器（必须与 weapons.csv 中的 Name 完全一致）
    selectedWeapon = '静水流涌之辉';          
    
    % 圣遗物总词条（最常用数值，直接填小数或百分比）
    build = struct(...
        'Weapon',           selectedWeapon, ...
        'HPBonus',          1.458, ...      % 总生命值加成（花+沙+杯+副詞條）
        'CritRate',         0.702, ...      % 暴击率（小數形式 70.2% = 0.702）
        'CritDMG',          2.156, ...      % 暴击伤害（小數形式 215.6% = 2.156）
        'HydroDMGBonus',    0.466, ...      % 水伤加成（46.6% = 0.466）
        'EM',               120, ...        % 精通
        'Set4_MoonPromote', 0.25, ...       % 4件套加成
        'PromoteBonus',     0.15, ...       % 其他突破/天賦加成
        'ResShred',         0.30 ...        % 抗性削減
    );
    
    % ================== 自動寫入 CSV ==================
    % 转成 table 并保存（simulateFurinaDPS.m 会读取此档案）
    buildTable = struct2table(build);
    % Keep the output path relative to the project layout expected by the
    % rest of the analysis scripts.
    outputPath = '../../data/Furina/artifacts_Furina.csv';
    outputFolder = fileparts(outputPath);
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
        fprintf('已自动创建文件夹：%s\n', outputFolder);
    end
    writetable(buildTable, outputPath);
    
    fprintf('✅ 芙宁娜圣遗物配置已生成！\n');
    fprintf('   武器: %s\n', selectedWeapon);
    fprintf('   生命加成: %.1f%%\n', build.HPBonus*100);
    fprintf('   暴击率: %.1f%% | 暴击伤害: %.1f%%\n', build.CritRate*100, build.CritDMG*100);
    fprintf('   已保存至: %s\n\n', outputPath);
    
    % 返回 struct，方便 mainFurinaFull.m 直接使用
end
