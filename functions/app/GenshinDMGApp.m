classdef GenshinDMGApp < handle
    % 原神伤害模拟可视化 APP。
    % 该 APP 不重写任何角色模拟逻辑，而是围绕工程现有的统一入口：
    % 1. getDefaultCharacterConfig
    % 2. simulateCharacterDPS
    % 3. simulateTeamDPS
    % 4. buildTeamContext
    % 搭建一个可交互的图形界面，用于：
    % - 配置角色、构筑、武器、精炼、命座、天赋等级
    % - 编辑各角色轮转文本
    % - 规划队伍成员与输出轴
    % - 可视化单人/整队伤害结果

    properties
        Figure
        Registry
        Enemy
        PortraitCacheDir
        TempRotationDir
        Slots
        SelectedSlot = 1
        LastTeamResult = struct()
        LastMemberResults = struct([])
        LastSimulationMode = "未运行"
    end

    properties (Access = private)
        SlotPanels
        SlotCharacterDropdowns
        SlotPresetDropdowns
        SlotWeaponDropdowns
        SlotConstellationSpinners
        SlotTalentSpinners
        SlotRefinementSpinners
        SlotStartTimeFields
        SlotEnableCheckboxes
        SlotEditButtons
        SlotPortraits
        SlotFooters

        SelectedSlotLabel
        SelectedPortrait
        SelectedSummaryText
        BuildTable
        RotationTextArea
        BuildHintLabel

        TeamDurationField
        EnemyLevelField
        EnemyResField
        EnemyDefField
        StatusLabel

        RunSingleButton
        RunTeamButton
        ResetSlotButton
        RefreshTimelineButton

        TotalDamageValueLabel
        TeamDPSValueLabel
        RotationValueLabel

        SummaryTable
        BreakdownTable
        TimelineAxes
        BarAxes
    end

    methods
        function obj = GenshinDMGApp()
            % 构造函数负责初始化路径、默认状态并创建全部 UI。
            initProjectPaths();
            obj.Registry = getCharacterRegistry();
            obj.Enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
            obj.PortraitCacheDir = fullfile(tempdir, 'genshin_dmg_calc_portraits');
            obj.TempRotationDir = fullfile(tempdir, 'genshin_dmg_calc_rotations');

            obj.initializeSlots();
            obj.createUI();
            obj.refreshAllSlotCards();
            obj.selectSlot(1);
            obj.refreshTimelinePreview();
        end

        function delete(obj)
            % 关闭 APP 时安全释放窗口句柄。
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end
    end

    methods (Access = private)
        function initializeSlots(obj)
            % 初始化 4 个默认队伍槽。
            defaultCharacters = ["Skirk", "Escoffier", "Furina", "Citlali"];
            slotTemplate = obj.makeEmptySlot();
            obj.Slots = repmat(slotTemplate, 1, 4);

            for i = 1:4
                obj.loadCharacterIntoSlot(i, defaultCharacters(i), true);
                obj.Slots(i).StartTime = (i - 1) * 2.5;
            end
        end

        function slot = makeEmptySlot(obj) %#ok<MANU>
            % 队伍槽内部状态模板。
            slot = struct( ...
                'CharacterKey', "Skirk", ...
                'DisplayName', "丝柯克", ...
                'BuildPresets', struct('Id', {}, 'DisplayName', {}, 'SourceType', {}, 'Path', {}), ...
                'BuildPresetId', "default", ...
                'Build', struct(), ...
                'RotationText', "", ...
                'Constellation', 0, ...
                'TalentLevel', 10, ...
                'WeaponName', "", ...
                'WeaponList', table(), ...
                'WeaponRefinement', 1, ...
                'StartTime', 0, ...
                'Enabled', true, ...
                'PortraitPath', "");
        end

        function createUI(obj)
            % 构建主界面布局。
            obj.Figure = uifigure( ...
                'Name', 'Genshin DMG Calc Visual App', ...
                'Position', [80 40 1720 980], ...
                'Color', [0.95 0.96 0.98], ...
                'AutoResizeChildren', 'off');

            mainGrid = uigridlayout(obj.Figure, [1 3]);
            mainGrid.ColumnWidth = {360, 560, '1x'};
            mainGrid.RowHeight = {'1x'};
            mainGrid.Padding = [14 14 14 14];
            mainGrid.ColumnSpacing = 14;

            obj.createTeamPanel(mainGrid);
            obj.createEditorPanel(mainGrid);
            obj.createResultPanel(mainGrid);
        end

        function createTeamPanel(obj, parent)
            % 左侧队伍槽区域。
            teamPanel = uipanel(parent, ...
                'Title', '队伍编组', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.99 0.99 1.00], ...
                'ForegroundColor', [0.18 0.23 0.33]);
            teamPanel.Layout.Row = 1;
            teamPanel.Layout.Column = 1;

            teamGrid = uigridlayout(teamPanel, [5 1]);
            teamGrid.RowHeight = {28, '1x', '1x', '1x', '1x'};
            teamGrid.ColumnWidth = {'1x'};
            teamGrid.RowSpacing = 10;
            teamGrid.Padding = [10 10 10 10];

            header = uilabel(teamGrid, ...
                'Text', '选择 4 名角色，分别配置构筑、武器、命座与起轴时间。', ...
                'FontSize', 12, ...
                'FontColor', [0.32 0.36 0.45]);
            header.Layout.Row = 1;
            header.Layout.Column = 1;

            slotCount = numel(obj.Slots);
            obj.SlotPanels = cell(1, slotCount);
            obj.SlotCharacterDropdowns = cell(1, slotCount);
            obj.SlotPresetDropdowns = cell(1, slotCount);
            obj.SlotWeaponDropdowns = cell(1, slotCount);
            obj.SlotConstellationSpinners = cell(1, slotCount);
            obj.SlotTalentSpinners = cell(1, slotCount);
            obj.SlotRefinementSpinners = cell(1, slotCount);
            obj.SlotStartTimeFields = cell(1, slotCount);
            obj.SlotEnableCheckboxes = cell(1, slotCount);
            obj.SlotEditButtons = cell(1, slotCount);
            obj.SlotPortraits = cell(1, slotCount);
            obj.SlotFooters = cell(1, slotCount);

            characterLabels = obj.getCharacterDropdownLabels();
            characterKeys = cellstr(string({obj.Registry.Key}));

            for i = 1:slotCount
                slotPanel = uipanel(teamGrid, ...
                    'Title', sprintf('队伍槽 %d', i), ...
                    'FontWeight', 'bold', ...
                    'BackgroundColor', [1.00 1.00 1.00], ...
                    'ForegroundColor', [0.20 0.26 0.36]);
                slotPanel.Layout.Row = i + 1;
                slotPanel.Layout.Column = 1;
                obj.SlotPanels{i} = slotPanel;

                slotGrid = uigridlayout(slotPanel, [6 3]);
                slotGrid.ColumnWidth = {100, '1x', 92};
                slotGrid.RowHeight = {24, 28, 28, 28, 48, 22};
                slotGrid.ColumnSpacing = 8;
                slotGrid.RowSpacing = 6;
                slotGrid.Padding = [10 10 10 10];
                slotGrid.BackgroundColor = [1.00 1.00 1.00];

                avatar = uiimage(slotGrid, 'ScaleMethod', 'fill');
                avatar.Layout.Row = [1 6];
                avatar.Layout.Column = 1;
                obj.SlotPortraits{i} = avatar;

                headerLabel = uilabel(slotGrid, ...
                    'Text', sprintf('槽位 %d', i), ...
                    'FontWeight', 'bold', ...
                    'FontColor', [0.18 0.24 0.34]);
                headerLabel.Layout.Row = 1;
                headerLabel.Layout.Column = 2;

                editButton = uibutton(slotGrid, 'push', ...
                    'Text', '编辑', ...
                    'BackgroundColor', [0.90 0.76 0.48], ...
                    'FontColor', [0.16 0.13 0.08], ...
                    'ButtonPushedFcn', @(~, ~) obj.selectSlot(i));
                editButton.Layout.Row = 1;
                editButton.Layout.Column = 3;
                obj.SlotEditButtons{i} = editButton;

                characterDropdown = uidropdown(slotGrid, ...
                    'Items', characterLabels, ...
                    'ItemsData', characterKeys, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotCharacterChanged(i, src.Value));
                characterDropdown.Layout.Row = 2;
                characterDropdown.Layout.Column = [2 3];
                obj.SlotCharacterDropdowns{i} = characterDropdown;

                presetDropdown = uidropdown(slotGrid, ...
                    'Items', {'默认构筑'}, ...
                    'ItemsData', {'default'}, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotPresetChanged(i, src.Value));
                presetDropdown.Layout.Row = 3;
                presetDropdown.Layout.Column = [2 3];
                obj.SlotPresetDropdowns{i} = presetDropdown;

                weaponDropdown = uidropdown(slotGrid, ...
                    'Items', {''}, ...
                    'ItemsData', {''}, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotWeaponChanged(i, src.Value));
                weaponDropdown.Layout.Row = 4;
                weaponDropdown.Layout.Column = [2 3];
                obj.SlotWeaponDropdowns{i} = weaponDropdown;

                controlGrid = uigridlayout(slotGrid, [2 4]);
                controlGrid.Layout.Row = 5;
                controlGrid.Layout.Column = [2 3];
                controlGrid.RowHeight = {16, 28};
                controlGrid.ColumnWidth = {'1x', '1x', '1x', '1x'};
                controlGrid.ColumnSpacing = 6;
                controlGrid.RowSpacing = 2;
                controlGrid.Padding = [0 0 0 0];
                controlGrid.BackgroundColor = [1.00 1.00 1.00];

                labelNames = {'命座', '天赋', '精炼', '起轴'};
                for j = 1:4
                    label = uilabel(controlGrid, ...
                        'Text', labelNames{j}, ...
                        'HorizontalAlignment', 'center', ...
                        'FontSize', 11, ...
                        'FontColor', [0.42 0.46 0.54]);
                    label.Layout.Row = 1;
                    label.Layout.Column = j;
                end

                constellationSpinner = uispinner(controlGrid, ...
                    'Limits', [0 6], ...
                    'RoundFractionalValues', 'on', ...
                    'Step', 1, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotConstellationChanged(i, src.Value));
                constellationSpinner.Layout.Row = 2;
                constellationSpinner.Layout.Column = 1;
                obj.SlotConstellationSpinners{i} = constellationSpinner;

                talentSpinner = uispinner(controlGrid, ...
                    'Limits', [1 15], ...
                    'RoundFractionalValues', 'on', ...
                    'Step', 1, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotTalentChanged(i, src.Value));
                talentSpinner.Layout.Row = 2;
                talentSpinner.Layout.Column = 2;
                obj.SlotTalentSpinners{i} = talentSpinner;

                refinementSpinner = uispinner(controlGrid, ...
                    'Limits', [1 5], ...
                    'RoundFractionalValues', 'on', ...
                    'Step', 1, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotRefinementChanged(i, src.Value));
                refinementSpinner.Layout.Row = 2;
                refinementSpinner.Layout.Column = 3;
                obj.SlotRefinementSpinners{i} = refinementSpinner;

                startField = uieditfield(controlGrid, 'numeric', ...
                    'Limits', [0 120], ...
                    'LowerLimitInclusive', 'on', ...
                    'ValueDisplayFormat', '%.1f s', ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotStartTimeChanged(i, src.Value));
                startField.Layout.Row = 2;
                startField.Layout.Column = 4;
                obj.SlotStartTimeFields{i} = startField;

                enableCheckbox = uicheckbox(slotGrid, ...
                    'Text', '参与队伍计算', ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotEnabledChanged(i, logical(src.Value)));
                enableCheckbox.Layout.Row = 6;
                enableCheckbox.Layout.Column = 2;
                obj.SlotEnableCheckboxes{i} = enableCheckbox;

                footer = uilabel(slotGrid, ...
                    'Text', '', ...
                    'HorizontalAlignment', 'right', ...
                    'FontSize', 11, ...
                    'FontColor', [0.44 0.48 0.56]);
                footer.Layout.Row = 6;
                footer.Layout.Column = 3;
                obj.SlotFooters{i} = footer;
            end
        end

        function createEditorPanel(obj, parent)
            % 中间角色编辑区域。
            editorPanel = uipanel(parent, ...
                'Title', '当前角色编辑', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.99 0.99 1.00], ...
                'ForegroundColor', [0.18 0.23 0.33]);
            editorPanel.Layout.Row = 1;
            editorPanel.Layout.Column = 2;

            editorGrid = uigridlayout(editorPanel, [4 1]);
            editorGrid.RowHeight = {34, 192, '1x', 240};
            editorGrid.ColumnWidth = {'1x'};
            editorGrid.RowSpacing = 12;
            editorGrid.Padding = [12 12 12 12];

            obj.SelectedSlotLabel = uilabel(editorGrid, ...
                'Text', '当前编辑：', ...
                'FontSize', 15, ...
                'FontWeight', 'bold', ...
                'FontColor', [0.15 0.21 0.31]);
            obj.SelectedSlotLabel.Layout.Row = 1;
            obj.SelectedSlotLabel.Layout.Column = 1;

            heroCard = uipanel(editorGrid, ...
                'Title', '角色概览', ...
                'BackgroundColor', [0.96 0.97 0.99], ...
                'ForegroundColor', [0.28 0.34 0.44]);
            heroCard.Layout.Row = 2;
            heroCard.Layout.Column = 1;

            heroGrid = uigridlayout(heroCard, [1 2]);
            heroGrid.ColumnWidth = {180, '1x'};
            heroGrid.RowHeight = {'1x'};
            heroGrid.ColumnSpacing = 14;
            heroGrid.Padding = [10 10 10 10];
            heroGrid.BackgroundColor = [0.96 0.97 0.99];

            obj.SelectedPortrait = uiimage(heroGrid, 'ScaleMethod', 'fit');
            obj.SelectedPortrait.Layout.Row = 1;
            obj.SelectedPortrait.Layout.Column = 1;

            obj.SelectedSummaryText = uitextarea(heroGrid, ...
                'Editable', 'off', ...
                'FontSize', 12, ...
                'BackgroundColor', [0.99 0.99 1.00], ...
                'Value', {'当前角色信息会显示在这里。'});
            obj.SelectedSummaryText.Layout.Row = 1;
            obj.SelectedSummaryText.Layout.Column = 2;

            buildPanel = uipanel(editorGrid, ...
                'Title', '构筑面板参数', ...
                'BackgroundColor', [1.00 1.00 1.00], ...
                'ForegroundColor', [0.28 0.34 0.44]);
            buildPanel.Layout.Row = 3;
            buildPanel.Layout.Column = 1;

            buildGrid = uigridlayout(buildPanel, [2 1]);
            buildGrid.RowHeight = {24, '1x'};
            buildGrid.ColumnWidth = {'1x'};
            buildGrid.RowSpacing = 6;
            buildGrid.Padding = [10 10 10 10];

            obj.BuildHintLabel = uilabel(buildGrid, ...
                'Text', '说明：当前工程的“圣遗物”数据本质上是角色面板/构筑参数，表中字段均可直接编辑。', ...
                'FontSize', 12, ...
                'FontColor', [0.35 0.39 0.47]);
            obj.BuildHintLabel.Layout.Row = 1;
            obj.BuildHintLabel.Layout.Column = 1;

            obj.BuildTable = uitable(buildGrid, ...
                'ColumnName', {'字段', '值'}, ...
                'ColumnEditable', [false true], ...
                'ColumnWidth', {190, 'auto'}, ...
                'RowName', {}, ...
                'CellEditCallback', @(~, ~) obj.onBuildTableEdited());
            obj.BuildTable.Layout.Row = 2;
            obj.BuildTable.Layout.Column = 1;

            rotationPanel = uipanel(editorGrid, ...
                'Title', '轮转脚本 / 输出轴文本', ...
                'BackgroundColor', [1.00 1.00 1.00], ...
                'ForegroundColor', [0.28 0.34 0.44]);
            rotationPanel.Layout.Row = 4;
            rotationPanel.Layout.Column = 1;

            rotationGrid = uigridlayout(rotationPanel, [3 2]);
            rotationGrid.RowHeight = {24, '1x', 34};
            rotationGrid.ColumnWidth = {'1x', 140};
            rotationGrid.RowSpacing = 8;
            rotationGrid.ColumnSpacing = 10;
            rotationGrid.Padding = [10 10 10 10];

            tipLabel = uilabel(rotationGrid, ...
                'Text', '支持逐行动作 token；空行与 # 注释会被忽略。若默认轮转为 AUTO，也可手动改写为更细时间轴。', ...
                'FontSize', 12, ...
                'FontColor', [0.35 0.39 0.47]);
            tipLabel.Layout.Row = 1;
            tipLabel.Layout.Column = [1 2];

            obj.RotationTextArea = uitextarea(rotationGrid, ...
                'FontName', 'Consolas', ...
                'FontSize', 12, ...
                'ValueChangedFcn', @(~, ~) obj.onRotationTextEdited());
            obj.RotationTextArea.Layout.Row = 2;
            obj.RotationTextArea.Layout.Column = [1 2];

            restoreButton = uibutton(rotationGrid, 'push', ...
                'Text', '恢复默认轮转', ...
                'ButtonPushedFcn', @(~, ~) obj.onRestoreDefaultRotation());
            restoreButton.Layout.Row = 3;
            restoreButton.Layout.Column = 2;
        end

        function createResultPanel(obj, parent)
            % 右侧结果与图表区域。
            resultPanel = uipanel(parent, ...
                'Title', '计算结果与可视化', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.99 0.99 1.00], ...
                'ForegroundColor', [0.18 0.23 0.33]);
            resultPanel.Layout.Row = 1;
            resultPanel.Layout.Column = 3;

            resultGrid = uigridlayout(resultPanel, [3 1]);
            resultGrid.RowHeight = {156, 90, '1x'};
            resultGrid.ColumnWidth = {'1x'};
            resultGrid.RowSpacing = 12;
            resultGrid.Padding = [12 12 12 12];

            configPanel = uipanel(resultGrid, ...
                'Title', '模拟参数', ...
                'BackgroundColor', [0.96 0.97 0.99], ...
                'ForegroundColor', [0.28 0.34 0.44]);
            configPanel.Layout.Row = 1;
            configPanel.Layout.Column = 1;

            configGrid = uigridlayout(configPanel, [3 6]);
            configGrid.RowHeight = {30, 30, 32};
            configGrid.ColumnWidth = {72, 92, 72, 92, '1x', 120};
            configGrid.ColumnSpacing = 8;
            configGrid.RowSpacing = 8;
            configGrid.Padding = [10 10 10 10];
            configGrid.BackgroundColor = [0.96 0.97 0.99];

            durationLabel = uilabel(configGrid, 'Text', '轴长(s)', 'FontColor', [0.30 0.34 0.42]);
            durationLabel.Layout.Row = 1;
            durationLabel.Layout.Column = 1;
            obj.TeamDurationField = uieditfield(configGrid, 'numeric', ...
                'Limits', [1 180], ...
                'Value', 20, ...
                'ValueDisplayFormat', '%.1f');
            obj.TeamDurationField.Layout.Row = 1;
            obj.TeamDurationField.Layout.Column = 2;

            levelLabel = uilabel(configGrid, 'Text', '敌等级', 'FontColor', [0.30 0.34 0.42]);
            levelLabel.Layout.Row = 1;
            levelLabel.Layout.Column = 3;
            obj.EnemyLevelField = uieditfield(configGrid, 'numeric', ...
                'Limits', [1 200], ...
                'Value', obj.Enemy.Level);
            obj.EnemyLevelField.Layout.Row = 1;
            obj.EnemyLevelField.Layout.Column = 4;

            obj.StatusLabel = uilabel(configGrid, ...
                'Text', '等待运行模拟。', ...
                'FontSize', 12, ...
                'FontColor', [0.26 0.31 0.40]);
            obj.StatusLabel.Layout.Row = 1;
            obj.StatusLabel.Layout.Column = [5 6];

            resLabel = uilabel(configGrid, 'Text', '敌抗', 'FontColor', [0.30 0.34 0.42]);
            resLabel.Layout.Row = 2;
            resLabel.Layout.Column = 1;
            obj.EnemyResField = uieditfield(configGrid, 'numeric', ...
                'Limits', [-2 2], ...
                'Value', obj.Enemy.Res, ...
                'ValueDisplayFormat', '%.2f');
            obj.EnemyResField.Layout.Row = 2;
            obj.EnemyResField.Layout.Column = 2;

            defLabel = uilabel(configGrid, 'Text', '减防', 'FontColor', [0.30 0.34 0.42]);
            defLabel.Layout.Row = 2;
            defLabel.Layout.Column = 3;
            obj.EnemyDefField = uieditfield(configGrid, 'numeric', ...
                'Limits', [0 1], ...
                'Value', obj.Enemy.DefReduct, ...
                'ValueDisplayFormat', '%.2f');
            obj.EnemyDefField.Layout.Row = 2;
            obj.EnemyDefField.Layout.Column = 4;

            obj.RunSingleButton = uibutton(configGrid, 'push', ...
                'Text', '单人模拟', ...
                'BackgroundColor', [0.46 0.70 0.82], ...
                'FontColor', [0.08 0.12 0.16], ...
                'ButtonPushedFcn', @(~, ~) obj.runSingleSimulation());
            obj.RunSingleButton.Layout.Row = 2;
            obj.RunSingleButton.Layout.Column = 5;

            obj.RunTeamButton = uibutton(configGrid, 'push', ...
                'Text', '整队模拟', ...
                'BackgroundColor', [0.92 0.76 0.45], ...
                'FontColor', [0.16 0.12 0.08], ...
                'ButtonPushedFcn', @(~, ~) obj.runTeamSimulation());
            obj.RunTeamButton.Layout.Row = 2;
            obj.RunTeamButton.Layout.Column = 6;

            noteLabel = uilabel(configGrid, ...
                'Text', '注：GUI 中的“构筑面板参数”直接映射到底层 build struct，并非逐件圣遗物求解器。', ...
                'FontColor', [0.36 0.39 0.47], ...
                'FontSize', 12);
            noteLabel.Layout.Row = 3;
            noteLabel.Layout.Column = [1 4];

            obj.ResetSlotButton = uibutton(configGrid, 'push', ...
                'Text', '重置当前角色', ...
                'ButtonPushedFcn', @(~, ~) obj.onResetCurrentSlot());
            obj.ResetSlotButton.Layout.Row = 3;
            obj.ResetSlotButton.Layout.Column = 5;

            obj.RefreshTimelineButton = uibutton(configGrid, 'push', ...
                'Text', '刷新输出轴', ...
                'ButtonPushedFcn', @(~, ~) obj.refreshTimelinePreview());
            obj.RefreshTimelineButton.Layout.Row = 3;
            obj.RefreshTimelineButton.Layout.Column = 6;

            kpiGrid = uigridlayout(resultGrid, [1 3]);
            kpiGrid.Layout.Row = 2;
            kpiGrid.Layout.Column = 1;
            kpiGrid.ColumnWidth = {'1x', '1x', '1x'};
            kpiGrid.RowHeight = {'1x'};
            kpiGrid.ColumnSpacing = 10;
            kpiGrid.Padding = [0 0 0 0];
            kpiGrid.BackgroundColor = [0.99 0.99 1.00];

            [~, obj.TotalDamageValueLabel] = obj.createKpiCard(kpiGrid, 1, '总伤害', [0.89 0.68 0.36]);
            [~, obj.TeamDPSValueLabel] = obj.createKpiCard(kpiGrid, 2, 'DPS', [0.34 0.68 0.72]);
            [~, obj.RotationValueLabel] = obj.createKpiCard(kpiGrid, 3, '轮转时长', [0.74 0.57 0.76]);

            tabs = uitabgroup(resultGrid);
            tabs.Layout.Row = 3;
            tabs.Layout.Column = 1;

            summaryTab = uitab(tabs, 'Title', '成员汇总');
            breakdownTab = uitab(tabs, 'Title', '伤害明细');
            timelineTab = uitab(tabs, 'Title', '输出轴');
            chartTab = uitab(tabs, 'Title', '成员对比');

            obj.SummaryTable = uitable(summaryTab, ...
                'Position', [8 8 760 560], ...
                'RowName', {});

            obj.BreakdownTable = uitable(breakdownTab, ...
                'Position', [8 8 760 560], ...
                'RowName', {});

            obj.TimelineAxes = uiaxes(timelineTab, 'Position', [12 12 750 552]);
            title(obj.TimelineAxes, '输出轴预览');
            xlabel(obj.TimelineAxes, 'Time (s)');
            ylabel(obj.TimelineAxes, 'Character');
            grid(obj.TimelineAxes, 'on');

            obj.BarAxes = uiaxes(chartTab, 'Position', [12 12 750 552]);
            title(obj.BarAxes, '成员 DPS 对比');
            ylabel(obj.BarAxes, 'DPS');
            grid(obj.BarAxes, 'on');
        end

        function [panel, valueLabel] = createKpiCard(obj, parent, columnIndex, titleText, accentColor) %#ok<INUSD>
            % 生成顶部 KPI 卡片。
            panel = uipanel(parent, ...
                'BackgroundColor', [1.00 1.00 1.00], ...
                'ForegroundColor', accentColor);
            panel.Layout.Row = 1;
            panel.Layout.Column = columnIndex;

            grid = uigridlayout(panel, [2 1]);
            grid.RowHeight = {24, '1x'};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [10 10 10 10];
            grid.RowSpacing = 2;
            grid.BackgroundColor = [1.00 1.00 1.00];

            titleLabel = uilabel(grid, ...
                'Text', titleText, ...
                'FontWeight', 'bold', ...
                'FontColor', accentColor, ...
                'FontSize', 12);
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = 1;

            valueLabel = uilabel(grid, ...
                'Text', '--', ...
                'FontWeight', 'bold', ...
                'FontSize', 20, ...
                'FontColor', [0.18 0.22 0.30]);
            valueLabel.Layout.Row = 2;
            valueLabel.Layout.Column = 1;
        end

        function labels = getCharacterDropdownLabels(obj)
            % 生成角色下拉框显示文本。
            labels = cell(1, numel(obj.Registry));
            for i = 1:numel(obj.Registry)
                labels{i} = sprintf('%s | %s', obj.Registry(i).DisplayName, obj.Registry(i).Key);
            end
        end

        function loadCharacterIntoSlot(obj, slotIndex, characterKey, preserveSlotTiming)
            % 将指定角色完整加载到队伍槽中。
            if nargin < 4
                preserveSlotTiming = false;
            end

            oldSlot = obj.Slots(slotIndex);
            cfg = getDefaultCharacterConfig(char(characterKey));

            slot = obj.makeEmptySlot();
            slot.CharacterKey = string(cfg.Name);
            slot.DisplayName = obj.lookupDisplayName(cfg.Name);
            slot.BuildPresets = listBuildPresetsForCharacter(cfg.Name);
            slot.BuildPresetId = "default";
            slot.Build = cfg.Build;
            slot.RotationText = getCharacterDefaultRotationText(cfg.Name);
            slot.Constellation = getFieldOrDefault(cfg, 'Constellation', 0);
            slot.TalentLevel = getFieldOrDefault(cfg, 'TalentLevel', 10);
            slot.WeaponList = listWeaponsForCharacter(cfg.Name);
            slot.WeaponName = string(getFieldOrDefault(slot.Build, 'Weapon', ""));
            slot.WeaponRefinement = max(1, min(5, getFieldOrDefault(slot.Build, 'WeaponRefinement', 1)));
            slot.Enabled = true;
            slot.PortraitPath = string(getPortraitForCharacter(cfg.Name, obj.PortraitCacheDir));

            if preserveSlotTiming
                slot.StartTime = oldSlot.StartTime;
                slot.Enabled = oldSlot.Enabled;
            else
                slot.StartTime = 0;
            end

            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            obj.Slots(slotIndex) = slot;
        end

        function displayName = lookupDisplayName(obj, characterKey)
            % 由英文键查找角色显示名。
            displayName = string(characterKey);
            for i = 1:numel(obj.Registry)
                if string(obj.Registry(i).Key) == string(characterKey)
                    displayName = string(obj.Registry(i).DisplayName);
                    return;
                end
            end
        end

        function refreshAllSlotCards(obj)
            % 刷新全部队伍槽显示。
            for i = 1:numel(obj.Slots)
                obj.refreshSlotCard(i);
            end
            obj.refreshSelectionVisuals();
        end

        function refreshSlotCard(obj, slotIndex)
            % 将内部状态同步到左侧队伍槽控件。
            slot = obj.Slots(slotIndex);

            obj.SlotCharacterDropdowns{slotIndex}.Value = char(slot.CharacterKey);
            obj.updatePresetDropdown(slotIndex);
            obj.updateWeaponDropdown(slotIndex);

            obj.SlotConstellationSpinners{slotIndex}.Value = slot.Constellation;
            obj.SlotTalentSpinners{slotIndex}.Value = slot.TalentLevel;
            obj.SlotRefinementSpinners{slotIndex}.Value = slot.WeaponRefinement;
            obj.SlotStartTimeFields{slotIndex}.Value = slot.StartTime;
            obj.SlotEnableCheckboxes{slotIndex}.Value = slot.Enabled;

            footerText = sprintf('%s | %s', char(slot.DisplayName), char(slot.WeaponName));
            obj.SlotFooters{slotIndex}.Text = footerText;

            if strlength(slot.PortraitPath) > 0 && isfile(slot.PortraitPath)
                obj.SlotPortraits{slotIndex}.ImageSource = char(slot.PortraitPath);
            end
        end

        function refreshSelectionVisuals(obj)
            % 高亮当前选中的队伍槽。
            for i = 1:numel(obj.SlotPanels)
                if i == obj.SelectedSlot
                    obj.SlotPanels{i}.Title = sprintf('队伍槽 %d  [编辑中]', i);
                    obj.SlotPanels{i}.BackgroundColor = [1.00 0.98 0.93];
                else
                    obj.SlotPanels{i}.Title = sprintf('队伍槽 %d', i);
                    obj.SlotPanels{i}.BackgroundColor = [1.00 1.00 1.00];
                end
            end
        end

        function selectSlot(obj, slotIndex)
            % 切换当前编辑的角色槽。
            obj.saveSelectedSlotState();
            obj.SelectedSlot = slotIndex;
            obj.refreshSelectionVisuals();
            obj.refreshEditorForSelectedSlot();
        end

        function refreshEditorForSelectedSlot(obj)
            % 将当前队伍槽的内容加载到中间编辑区。
            slot = obj.Slots(obj.SelectedSlot);

            obj.SelectedSlotLabel.Text = sprintf('当前编辑：队伍槽 %d | %s (%s)', ...
                obj.SelectedSlot, char(slot.DisplayName), char(slot.CharacterKey));

            if strlength(slot.PortraitPath) > 0 && isfile(slot.PortraitPath)
                obj.SelectedPortrait.ImageSource = char(slot.PortraitPath);
            end

            summaryLines = { ...
                sprintf('角色：%s | 英文键：%s', char(slot.DisplayName), char(slot.CharacterKey)), ...
                sprintf('构筑预设：%s', char(obj.lookupPresetLabel(slot))), ...
                sprintf('武器：%s | 精炼 %d', char(slot.WeaponName), slot.WeaponRefinement), ...
                sprintf('命座：%d | 统一天赋等级：%d', slot.Constellation, slot.TalentLevel), ...
                sprintf('起轴时间：%.1f s | 参与队伍计算：%s', slot.StartTime, obj.localOnOff(slot.Enabled)), ...
                '', ...
                '维护提示：', ...
                '1. 构筑表字段会直接写入底层 build struct。', ...
                '2. 武器下拉会同步基础攻击、词条类型、词条数值与精炼等级。', ...
                '3. 轮转文本仅决定角色模拟脚本输入与输出轴可视化，不改动核心模拟器。'};
            obj.SelectedSummaryText.Value = summaryLines;

            obj.BuildTable.Data = buildStructToTableData(slot.Build);
            obj.RotationTextArea.Value = obj.rotationStringToTextAreaValue(slot.RotationText);
        end

        function label = lookupPresetLabel(obj, slot)
            % 返回当前构筑预设的显示名。
            label = slot.BuildPresetId;
            ids = string({slot.BuildPresets.Id});
            idx = find(ids == string(slot.BuildPresetId), 1, 'first');
            if ~isempty(idx)
                label = string(slot.BuildPresets(idx).DisplayName);
            end
        end

        function value = localOnOff(obj, tf) %#ok<MANU>
            if tf
                value = '是';
            else
                value = '否';
            end
        end

        function value = rotationStringToTextAreaValue(obj, rotationText) %#ok<MANU>
            % 将轮转字符串转为文本框 Value。
            lines = splitlines(string(rotationText));
            lines = cellstr(lines);
            if isempty(lines)
                value = {''};
            else
                value = lines;
            end
        end

        function saveSelectedSlotState(obj)
            % 将中间编辑区的构筑表和轮转文本写回当前选中槽位。
            if isempty(obj.BuildTable) || isempty(obj.RotationTextArea) || isempty(obj.Slots)
                return;
            end
            if obj.SelectedSlot < 1 || obj.SelectedSlot > numel(obj.Slots)
                return;
            end

            slot = obj.Slots(obj.SelectedSlot);
            if ~isempty(obj.BuildTable.Data)
                slot.Build = tableDataToBuildStruct(obj.BuildTable.Data);
            end
            slot.RotationText = obj.getRotationTextValue();
            slot.WeaponName = string(getFieldOrDefault(slot.Build, 'Weapon', slot.WeaponName));
            slot.WeaponRefinement = max(1, min(5, getFieldOrDefault(slot.Build, 'WeaponRefinement', slot.WeaponRefinement)));
            obj.Slots(obj.SelectedSlot) = slot;

            obj.refreshSlotCard(obj.SelectedSlot);
        end

        function rotationText = getRotationTextValue(obj)
            % 读取当前轮转文本框内容。
            rawValue = obj.RotationTextArea.Value;
            if iscell(rawValue)
                rotationText = string(strjoin(rawValue, newline));
            elseif isstring(rawValue)
                rotationText = string(strjoin(cellstr(rawValue), newline));
            else
                rotationText = string(rawValue);
            end
        end

        function updatePresetDropdown(obj, slotIndex)
            % 刷新构筑预设下拉框。
            slot = obj.Slots(slotIndex);
            presets = slot.BuildPresets;
            items = cellstr(string({presets.DisplayName}));
            itemData = cellstr(string({presets.Id}));
            if isempty(items)
                items = {'默认构筑'};
                itemData = {'default'};
            end

            dropdown = obj.SlotPresetDropdowns{slotIndex};
            dropdown.Items = items;
            dropdown.ItemsData = itemData;

            currentValue = char(slot.BuildPresetId);
            if ~any(strcmp(itemData, currentValue))
                currentValue = itemData{1};
                slot.BuildPresetId = string(currentValue);
                obj.Slots(slotIndex) = slot;
            end
            dropdown.Value = currentValue;
        end

        function updateWeaponDropdown(obj, slotIndex)
            % 刷新武器下拉框，并确保当前 build 中的武器仍可选。
            slot = obj.Slots(slotIndex);
            dropdown = obj.SlotWeaponDropdowns{slotIndex};

            itemData = {};
            if ~isempty(slot.WeaponList)
                itemData = cellstr(string(slot.WeaponList.Name));
            end
            currentWeapon = char(slot.WeaponName);
            if ~isempty(currentWeapon) && ~any(strcmp(itemData, currentWeapon))
                itemData = [{currentWeapon}, itemData];
            end
            if isempty(itemData)
                itemData = {''};
            end

            dropdown.Items = itemData;
            dropdown.ItemsData = itemData;
            dropdown.Value = itemData{1};

            if ~isempty(currentWeapon) && any(strcmp(itemData, currentWeapon))
                dropdown.Value = currentWeapon;
            end
        end

        function build = applyWeaponStatsToBuild(obj, build, weaponList, weaponName, refinement) %#ok<INUSD>
            % 将武器下拉选择同步到 build 字段。
            if nargin < 5 || isempty(refinement)
                refinement = 1;
            end

            weaponName = string(weaponName);
            if strlength(weaponName) == 0
                build.WeaponRefinement = refinement;
                return;
            end

            build.Weapon = char(weaponName);
            build.WeaponRefinement = refinement;

            if isempty(weaponList)
                return;
            end

            idx = find(string(weaponList.Name) == weaponName, 1, 'first');
            if isempty(idx)
                return;
            end

            build.WeaponATK = weaponList.BaseATK(idx);
            build.WeaponSubStatType = char(weaponList.SubstatType(idx));
            build.WeaponSubStatValue = weaponList.SubstatValue(idx);
        end

        function memberCfg = buildMemberConfig(obj, slotIndex)
            % 将 GUI 队伍槽状态转换成统一模拟入口需要的角色配置。
            slot = obj.Slots(slotIndex);
            rotationText = slot.RotationText;
            if strlength(strtrim(rotationText)) == 0
                rotationText = getCharacterDefaultRotationText(slot.CharacterKey);
            end

            tempRotationPath = writeTempRotationFile( ...
                obj.TempRotationDir, slot.CharacterKey, slotIndex, rotationText);

            overrides = struct( ...
                'Constellation', slot.Constellation, ...
                'TalentLevel', slot.TalentLevel, ...
                'Build', slot.Build, ...
                'RotationFile', tempRotationPath);
            memberCfg = getDefaultCharacterConfig(char(slot.CharacterKey), overrides);
        end

        function enemy = buildEnemy(obj)
            % 由右侧参数区构造敌人配置。
            enemy = struct( ...
                'Level', obj.EnemyLevelField.Value, ...
                'Res', obj.EnemyResField.Value, ...
                'DefReduct', obj.EnemyDefField.Value);
        end

        function [members, slotIndices] = buildEnabledMembers(obj)
            % 收集所有启用的队伍成员配置。
            members = {};
            slotIndices = [];
            for i = 1:numel(obj.Slots)
                if obj.Slots(i).Enabled
                    members{end + 1} = obj.buildMemberConfig(i); %#ok<AGROW>
                    slotIndices(end + 1) = i; %#ok<AGROW>
                end
            end
        end

        function summary = buildSingleSummaryTable(obj, result)
            % 将单人模拟结果转换成统一表格格式。
            summary = table( ...
                string(result.DisplayName), ...
                result.TotalDMG, ...
                result.DPS, ...
                result.RotationTime, ...
                result.DPS, ...
                'VariableNames', {'Character', 'TotalDMG', 'TeamCycleDPS', 'ActionTime', 'StandaloneDPS'});
        end

        function runSingleSimulation(obj)
            % 按当前选中角色执行单人模拟。
            obj.saveSelectedSlotState();
            try
                memberCfg = obj.buildMemberConfig(obj.SelectedSlot);
                result = simulateCharacterDPS(memberCfg, obj.buildEnemy());
                obj.LastTeamResult = struct();
                obj.LastMemberResults = result;
                obj.LastSimulationMode = "单人";

                summary = obj.buildSingleSummaryTable(result);
                obj.updateResultTables(summary, result.Breakdown);
                obj.updateKpi(result.TotalDMG, result.DPS, result.RotationTime);
                obj.renderBarChart(summary);
                obj.renderTimeline(obj.SelectedSlot, result);
                obj.setStatus(sprintf('已完成单人模拟：%s。', char(result.DisplayName)));
            catch ME
                obj.showSimulationError(ME);
            end
        end

        function runTeamSimulation(obj)
            % 按当前启用的全部角色执行整队模拟。
            obj.saveSelectedSlotState();
            try
                [members, slotIndices] = obj.buildEnabledMembers();
                if isempty(members)
                    uialert(obj.Figure, '请至少启用 1 个队伍槽。', '队伍为空');
                    return;
                end

                teamSpec = struct( ...
                    'Members', {members}, ...
                    'RotationDuration', obj.TeamDurationField.Value, ...
                    'SharedBuffs', struct());

                [teamResult, memberResults] = simulateTeamDPS(teamSpec, obj.buildEnemy());
                obj.LastTeamResult = teamResult;
                obj.LastMemberResults = memberResults;
                obj.LastSimulationMode = "整队";

                obj.updateResultTables(teamResult.Summary, teamResult.Breakdown);
                obj.updateKpi(teamResult.TotalDMG, teamResult.DPS, teamResult.RotationDuration);
                obj.renderBarChart(teamResult.Summary);
                obj.renderTimeline(slotIndices, memberResults);
                obj.setStatus(sprintf('已完成整队模拟，共 %d 名角色。', numel(slotIndices)));
            catch ME
                obj.showSimulationError(ME);
            end
        end

        function updateResultTables(obj, summaryTable, breakdownTable)
            % 更新右侧结果表格。
            obj.SummaryTable.Data = summaryTable;
            obj.BreakdownTable.Data = breakdownTable;
        end

        function updateKpi(obj, totalDamage, dps, rotationTime)
            % 更新右侧 KPI 数字卡。
            obj.TotalDamageValueLabel.Text = obj.formatLargeNumber(totalDamage);
            obj.TeamDPSValueLabel.Text = obj.formatLargeNumber(dps);
            obj.RotationValueLabel.Text = sprintf('%.2f s', rotationTime);
        end

        function text = formatLargeNumber(obj, value) %#ok<MANU>
            % 大数字格式化显示。
            if abs(value) >= 1e8
                text = sprintf('%.2f e8', value / 1e8);
            elseif abs(value) >= 1e4
                text = sprintf('%.2f 万', value / 1e4);
            else
                text = sprintf('%.0f', value);
            end
        end

        function renderBarChart(obj, summaryTable)
            % 绘制成员伤害柱状图。
            cla(obj.BarAxes);
            if isempty(summaryTable) || height(summaryTable) == 0
                title(obj.BarAxes, '成员 DPS 对比');
                return;
            end

            names = string(summaryTable.Character);
            values = summaryTable.StandaloneDPS;
            bar(obj.BarAxes, categorical(names), values, 'FaceColor', [0.35 0.63 0.76]);
            title(obj.BarAxes, sprintf('%s模式：成员 DPS 对比', char(obj.LastSimulationMode)));
            ylabel(obj.BarAxes, 'DPS');
            xlabel(obj.BarAxes, 'Character');
            grid(obj.BarAxes, 'on');
        end

        function renderTimeline(obj, slotIndexOrList, results)
            % 根据轮转文本绘制输出轴。
            cla(obj.TimelineAxes);
            hold(obj.TimelineAxes, 'on');

            if isempty(slotIndexOrList)
                title(obj.TimelineAxes, '输出轴预览');
                hold(obj.TimelineAxes, 'off');
                return;
            end

            slotIndices = slotIndexOrList;
            resultList = results;

            colors = lines(max(4, numel(slotIndices)));
            maxEndTime = obj.TeamDurationField.Value;

            for i = 1:numel(slotIndices)
                slotIndex = slotIndices(i);
                slot = obj.Slots(slotIndex);
                yCenter = i;
                actions = parseRotationTextTokens(slot.RotationText);

                resultRotationTime = [];
                if ~isempty(resultList)
                    if isstruct(resultList) && isscalar(resultList)
                        resultRotationTime = resultList.RotationTime;
                    elseif numel(resultList) >= i
                        resultRotationTime = resultList(i).RotationTime;
                    end
                end

                [durations, labels] = obj.estimateTimelineBlocks(slot, actions, resultRotationTime);
                currentTime = slot.StartTime;

                if isempty(durations)
                    durations = 1.0;
                    labels = {char(slot.CharacterKey)};
                end

                for j = 1:numel(durations)
                    duration = durations(j);
                    label = labels{j};
                    rectangle(obj.TimelineAxes, ...
                        'Position', [currentTime, yCenter - 0.34, duration, 0.68], ...
                        'FaceColor', colors(i, :) * 0.82 + 0.18, ...
                        'EdgeColor', colors(i, :), ...
                        'LineWidth', 1.2);

                    if duration >= 0.42
                        text(obj.TimelineAxes, currentTime + duration / 2, yCenter, label, ...
                            'HorizontalAlignment', 'center', ...
                            'VerticalAlignment', 'middle', ...
                            'FontSize', 10, ...
                            'Color', [0.08 0.10 0.14]);
                    end

                    currentTime = currentTime + duration;
                end

                maxEndTime = max(maxEndTime, currentTime);
            end

            xline(obj.TimelineAxes, obj.TeamDurationField.Value, '--', '团队轴长', ...
                'Color', [0.68 0.28 0.28], 'LabelVerticalAlignment', 'middle');
            ylim(obj.TimelineAxes, [0.4, numel(slotIndices) + 0.6]);
            xlim(obj.TimelineAxes, [0, max(1, maxEndTime + 0.5)]);
            yticks(obj.TimelineAxes, 1:numel(slotIndices));
            yticklabels(obj.TimelineAxes, cellstr(string({obj.Slots(slotIndices).DisplayName})));
            xlabel(obj.TimelineAxes, 'Time (s)');
            ylabel(obj.TimelineAxes, 'Character');
            title(obj.TimelineAxes, sprintf('%s模式：输出轴预览', char(obj.LastSimulationMode)));
            grid(obj.TimelineAxes, 'on');
            hold(obj.TimelineAxes, 'off');
        end

        function [durations, labels] = estimateTimelineBlocks(obj, slot, actions, resultRotationTime)
            % 为输出轴可视化估计每个动作的时长。
            durations = [];
            labels = {};

            if isempty(actions)
                if ~isempty(resultRotationTime)
                    durations = resultRotationTime;
                else
                    durations = 1.0;
                end
                labels = {char(slot.CharacterKey)};
                return;
            end

            if isscalar(actions) && strcmpi(actions{1}, 'AUTO')
                durations = max(0.80, obj.defaultIfEmpty(resultRotationTime, 2.0));
                labels = {'AUTO'};
                return;
            end

            estimated = zeros(1, numel(actions));
            labels = actions.';
            for i = 1:numel(actions)
                estimated(i) = estimateActionDuration(slot.CharacterKey, actions{i}, 0.60);
            end

            scale = 1.0;
            if ~isempty(resultRotationTime)
                estimatedTotal = sum(estimated);
                if estimatedTotal > 0
                    scale = resultRotationTime / estimatedTotal;
                end
            end
            durations = estimated * scale;
        end

        function value = defaultIfEmpty(obj, inputValue, fallback) %#ok<MANU>
            if isempty(inputValue)
                value = fallback;
            else
                value = inputValue;
            end
        end

        function refreshTimelinePreview(obj)
            % 在未运行模拟时，也允许用户预览当前编辑的输出轴。
            obj.saveSelectedSlotState();
            slotIndices = find([obj.Slots.Enabled]);
            if isempty(slotIndices)
                slotIndices = obj.SelectedSlot;
            end
            obj.LastSimulationMode = "预览";
            obj.renderTimeline(slotIndices, struct([]));
            obj.setStatus('已刷新输出轴预览。');
        end

        function setStatus(obj, message)
            % 更新状态栏文本。
            obj.StatusLabel.Text = char(message);
        end

        function showSimulationError(obj, ME)
            % 展示模拟错误，同时保留堆栈首条关键信息。
            obj.setStatus('模拟失败，请检查输入。');
            detail = ME.message;
            if ~isempty(ME.stack)
                detail = sprintf('%s\n\n发生位置：%s (line %d)', ...
                    ME.message, ME.stack(1).name, ME.stack(1).line);
            end
            uialert(obj.Figure, detail, '模拟失败');
        end

        function onSlotCharacterChanged(obj, slotIndex, newCharacter)
            % 更换队伍槽角色。
            obj.saveSelectedSlotState();
            obj.loadCharacterIntoSlot(slotIndex, string(newCharacter), true);
            obj.refreshSlotCard(slotIndex);
            if obj.SelectedSlot == slotIndex
                obj.refreshEditorForSelectedSlot();
            end
            obj.refreshTimelinePreview();
        end

        function onSlotPresetChanged(obj, slotIndex, presetId)
            % 更换当前角色构筑预设。
            obj.saveSelectedSlotState();
            slot = obj.Slots(slotIndex);
            slot.BuildPresetId = string(presetId);
            slot.Build = loadBuildPreset(slot.CharacterKey, slot.BuildPresetId);
            slot.WeaponName = string(getFieldOrDefault(slot.Build, 'Weapon', slot.WeaponName));
            slot.WeaponRefinement = max(1, min(5, getFieldOrDefault(slot.Build, 'WeaponRefinement', slot.WeaponRefinement)));
            slot.WeaponList = listWeaponsForCharacter(slot.CharacterKey);
            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            obj.Slots(slotIndex) = slot;
            obj.refreshSlotCard(slotIndex);
            if obj.SelectedSlot == slotIndex
                obj.refreshEditorForSelectedSlot();
            end
        end

        function onSlotWeaponChanged(obj, slotIndex, weaponName)
            % 更换当前角色武器。
            obj.saveSelectedSlotState();
            slot = obj.Slots(slotIndex);
            slot.WeaponName = string(weaponName);
            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            obj.Slots(slotIndex) = slot;
            obj.refreshSlotCard(slotIndex);
            if obj.SelectedSlot == slotIndex
                obj.refreshEditorForSelectedSlot();
            end
        end

        function onSlotConstellationChanged(obj, slotIndex, value)
            % 命座修改回写。
            obj.Slots(slotIndex).Constellation = round(value);
            if obj.SelectedSlot == slotIndex
                obj.refreshEditorForSelectedSlot();
            end
        end

        function onSlotTalentChanged(obj, slotIndex, value)
            % 天赋等级修改回写。
            obj.Slots(slotIndex).TalentLevel = round(value);
            if obj.SelectedSlot == slotIndex
                obj.refreshEditorForSelectedSlot();
            end
        end

        function onSlotRefinementChanged(obj, slotIndex, value)
            % 武器精炼修改回写并同步到 build。
            slot = obj.Slots(slotIndex);
            slot.WeaponRefinement = round(value);
            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            obj.Slots(slotIndex) = slot;
            obj.refreshSlotCard(slotIndex);
            if obj.SelectedSlot == slotIndex
                obj.refreshEditorForSelectedSlot();
            end
        end

        function onSlotStartTimeChanged(obj, slotIndex, value)
            % 起轴时间修改回写。
            obj.Slots(slotIndex).StartTime = value;
            obj.refreshTimelinePreview();
        end

        function onSlotEnabledChanged(obj, slotIndex, value)
            % 队伍槽启用状态修改回写。
            obj.Slots(slotIndex).Enabled = logical(value);
            obj.refreshTimelinePreview();
        end

        function onBuildTableEdited(obj)
            % 用户直接编辑 build 表格后的回写逻辑。
            slot = obj.Slots(obj.SelectedSlot);
            slot.Build = tableDataToBuildStruct(obj.BuildTable.Data);
            slot.WeaponName = string(getFieldOrDefault(slot.Build, 'Weapon', slot.WeaponName));
            slot.WeaponRefinement = max(1, min(5, getFieldOrDefault(slot.Build, 'WeaponRefinement', slot.WeaponRefinement)));
            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            obj.Slots(obj.SelectedSlot) = slot;

            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
        end

        function onRotationTextEdited(obj)
            % 用户编辑轮转文本后的回写逻辑。
            slot = obj.Slots(obj.SelectedSlot);
            slot.RotationText = obj.getRotationTextValue();
            obj.Slots(obj.SelectedSlot) = slot;
            obj.refreshTimelinePreview();
        end

        function onRestoreDefaultRotation(obj)
            % 恢复当前角色默认轮转文本。
            slot = obj.Slots(obj.SelectedSlot);
            slot.RotationText = getCharacterDefaultRotationText(slot.CharacterKey);
            obj.Slots(obj.SelectedSlot) = slot;
            obj.RotationTextArea.Value = obj.rotationStringToTextAreaValue(slot.RotationText);
            obj.refreshTimelinePreview();
        end

        function onResetCurrentSlot(obj)
            % 将当前角色重置为其默认构筑与默认轮转。
            currentCharacter = obj.Slots(obj.SelectedSlot).CharacterKey;
            startTime = obj.Slots(obj.SelectedSlot).StartTime;
            enabled = obj.Slots(obj.SelectedSlot).Enabled;

            obj.loadCharacterIntoSlot(obj.SelectedSlot, currentCharacter, false);
            obj.Slots(obj.SelectedSlot).StartTime = startTime;
            obj.Slots(obj.SelectedSlot).Enabled = enabled;

            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
            obj.refreshTimelinePreview();
            obj.setStatus('已重置当前角色为默认配置。');
        end
    end
end
