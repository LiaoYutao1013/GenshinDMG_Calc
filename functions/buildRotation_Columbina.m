function rotTable = buildRotation_Columbina()
    % 自动生成哥伦比娅标准循环（带精确 Param 匹配）
    rotTable = table(...
        [1;  3;  12;  5;   1;   8;   3], ...                    % Hits
        [0.1672; 0.0936; 0.111; 0.20; 0.325; 0.0936; 0.20], ... % TalentMV (仅供参考)
        [1.5;  0.5;  0.3;  0.4;  1.0;  0.5;  1.0], ...         % Time(s)
        {'月露泼降'; '万古潮汐'; '月露泼降'; '月露泼降'; '她的乡愁'; '万古潮汐'; '万古潮汐'}, ... % Skill
        {'Hydro'; 'Hydro'; 'Hydro'; 'Grass'; 'Hydro'; 'Grass'; 'MoonBloom'}, ...
        {'None'; 'None'; 'None'; 'Bloom'; 'None'; 'Interfere'; 'BuildGravity'}, ...
        {'一段伤害'; '引力涟漪·持续伤害'; '三段伤害'; '重击伤害'; '技能伤害'; '引力干涉·月绽放伤害'; '引力涟漪·持续伤害'}, ... % ← 新增：精确 Param
        'VariableNames', {'Hits','TalentMV','Time','Action','Element','Reaction','Param'});
    
    thisFolder = fileparts(mfilename('fullpath'));
    writetable(rotTable, fullfile(thisFolder, '..', 'data', 'rotation_Columbina.csv'));
    
    disp('✅ 战斗循环已自动生成！（新增 Param 列，可精确匹配 talent 表）');
    disp('   文件路径：../data/rotation_Columbina.csv');
end