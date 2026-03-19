function rotTable = buildRotation_Columbina()
    % 自动生成哥伦比娅标准循环（30秒 E+Q+普攻+月曜反应触发）
    rotTable = table(...
        [1;  3;  12;  5;   1;   8;   3], ...   % Hits
        [0.1672; 0.0936; 0.111; 0.20; 0.325; 0.0936; 0.20], ... % MV (%MaxHP)
        [1.5;  0.5;  0.3;  0.4;  1.0;  0.5;  1.0], ...   % Time(s)
        {'E_Initial'; 'MoonWheel_Cont'; 'Normal'; 'GrassDew_Charged'; 'Q'; 'MoonInterfere_MoonBloom'; 'ReactionTrigger'}, ...
        {'Hydro'; 'Hydro'; 'Hydro'; 'Grass'; 'Hydro'; 'Grass'; 'MoonBloom'}, ...
        {'None'; 'None'; 'None'; 'Bloom'; 'None'; 'Interfere'; 'BuildGravity'}, ...
        'VariableNames', {'Hits','TalentMV','Time','Action','Element','Reaction'});
    
    writetable(rotTable, 'data/rotation_Columbina.csv');
    disp('✅ 战斗循环已自动生成！（已包含月曜反应、引力积攒、草露重击）');
end