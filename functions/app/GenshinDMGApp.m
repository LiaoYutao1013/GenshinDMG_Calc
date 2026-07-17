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
        LastComparisonMode = ""
        LastComparisonResults
        LastSimulationMode = "未运行"
    end

    properties (Access = private)
        SlotPanels
        SlotCharacterDropdowns
        SlotPresetDropdowns
        SlotWeaponDropdowns
        SlotArtifactDropdowns
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
        ArtifactSetDropdown
        SelectedWeaponDropdown
        SelectedConstellationSpinner
        SelectedTalentSpinner
        SelectedRefinementSpinner
        BuildTable
        RotationTextArea
        BuildHintLabel

        TeamDurationField
        EnemyLevelField
        EnemyResField
        EnemyDefField
        StatusLabel
        LastStatusMessage
        LastResultMetrics
        LastResultReport = ""

        RunSingleButton
        RunTeamButton
        ResetSlotButton
        RefreshTimelineButton

        ResultConsole
        ComparisonModeDropdown
        ComparisonLimitSpinner
        ComparisonImplementedOnlyCheckbox
        ComparisonRunButton
        ComparisonApplyBestButton
        ComparisonStatusLabel
        ComparisonTable
        ComparisonAxes
        ComparisonTabGroup
        ComparisonPages
        EditorFigure
    end

    methods
        function obj = GenshinDMGApp()
            % 构造函数负责初始化路径、默认状态并创建全部 UI。
            initProjectPaths();
            obj.Registry = getCharacterRegistry();
            obj.Enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
            appFolder = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(fileparts(appFolder));
            obj.PortraitCacheDir = fullfile(projectRoot, 'art', 'portraits');
            obj.TempRotationDir = fullfile(tempdir, 'genshin_dmg_calc_rotations');
            obj.LastStatusMessage = "界面已加载，等待模拟。";
            obj.LastComparisonResults = table();
            obj.LastResultMetrics = struct( ...
                'HasResult', false, ...
                'TotalDamage', NaN, ...
                'DPS', NaN, ...
                'RotationTime', NaN);

            obj.initializeSlots();
            obj.createUI();
            obj.refreshAllSlotCards();
            obj.selectSlot(1);
            obj.refreshTimelinePreview();
        end

        function delete(obj)
            % 关闭 APP 时安全释放窗口句柄。
            if ~isempty(obj.EditorFigure) && isvalid(obj.EditorFigure)
                delete(obj.EditorFigure);
            end
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end

        function runSingle(obj)
            % 公开包装方法，便于脚本或自动化测试直接触发单人模拟。
            obj.runSingleSimulation();
        end

        function runTeam(obj)
            % 公开包装方法，便于脚本或自动化测试直接触发整队模拟。
            obj.runTeamSimulation();
        end

        function refreshTimeline(obj)
            % 公开包装方法，便于脚本或自动化测试刷新输出轴预览。
            obj.refreshTimelinePreview();
        end

        function runComparison(obj, mode)
            %#ok<INUSD>
            obj.setStatus('Comparison charts are not available in the native UI result workflow.');
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
                'ArtifactSet1', "None", ...
                'ArtifactSet1Pieces', 0, ...
                'ArtifactSet2', "None", ...
                'ArtifactSet2Pieces', 0, ...
                'ArtifactSet4Active', 1, ...
                'RotationEdited', false, ...
                'StartTime', 0, ...
                'Enabled', true, ...
                'PortraitPath', "");
        end

        function createUI(obj)
            % 构建主界面布局。
            obj.Figure = uifigure( ...
                'Name', 'Genshin DMG Calc Visual App', ...
                'Position', [80 40 1440 980], ...
                'Color', [0.95 0.96 0.98], ...
                'AutoResizeChildren', 'off');

            mainGrid = uigridlayout(obj.Figure, [1 2]);
            mainGrid.ColumnWidth = {380, '1x'};
            mainGrid.RowHeight = {'1x'};
            mainGrid.Padding = [14 14 14 14];
            mainGrid.ColumnSpacing = 14;

            obj.createTeamPanel(mainGrid);
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

            teamRootGrid = uigridlayout(teamPanel, [5 1]);
            teamRootGrid.RowHeight = {28, '1x', '1x', '1x', '1x'};
            teamRootGrid.ColumnWidth = {'1x'};
            teamRootGrid.RowSpacing = 10;
            teamRootGrid.Padding = [10 10 10 10];
            teamGrid = teamRootGrid;

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
            obj.SlotArtifactDropdowns = cell(1, slotCount);
            obj.SlotConstellationSpinners = cell(1, slotCount);
            obj.SlotTalentSpinners = cell(1, slotCount);
            obj.SlotRefinementSpinners = cell(1, slotCount);
            obj.SlotStartTimeFields = cell(1, slotCount);
            obj.SlotEnableCheckboxes = cell(1, slotCount);
            obj.SlotEditButtons = cell(1, slotCount);
            obj.SlotPortraits = cell(1, slotCount);
            obj.SlotFooters = cell(1, slotCount);
            [artifactLabels, artifactIds] = getArtifactSetChoices();

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

                slotGrid = uigridlayout(slotPanel, [7 4]);
                slotGrid.ColumnWidth = {70, 48, '1x', 76};
                slotGrid.RowHeight = {22, 26, 26, 26, 26, 42, 20};
                slotGrid.ColumnSpacing = 6;
                slotGrid.RowSpacing = 4;
                slotGrid.Padding = [8 8 8 8];
                slotGrid.BackgroundColor = [1.00 1.00 1.00];

                avatar = uiimage(slotGrid, 'ScaleMethod', 'fill');
                avatar.Layout.Row = [1 7];
                avatar.Layout.Column = 1;
                obj.SlotPortraits{i} = avatar;

                headerLabel = uilabel(slotGrid, ...
                    'Text', sprintf('槽位 %d', i), ...
                    'FontWeight', 'bold', ...
                    'FontColor', [0.18 0.24 0.34]);
                headerLabel.Layout.Row = 1;
                headerLabel.Layout.Column = [2 3];

                editButton = uibutton(slotGrid, 'push', ...
                    'Text', '编辑', ...
                    'BackgroundColor', [0.90 0.76 0.48], ...
                    'FontColor', [0.16 0.13 0.08], ...
                    'ButtonPushedFcn', @(~, ~) obj.openEditorForSlot(i));
                editButton.Layout.Row = 1;
                editButton.Layout.Column = 4;
                obj.SlotEditButtons{i} = editButton;

                characterDropdown = uidropdown(slotGrid, ...
                    'Items', characterLabels, ...
                    'ItemsData', characterKeys, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotCharacterChanged(i, src.Value));
                characterDropdown.Layout.Row = 2;
                characterDropdown.Layout.Column = [2 4];
                obj.SlotCharacterDropdowns{i} = characterDropdown;

                artifactLabel = uilabel(slotGrid, ...
                    'Text', '套装', ...
                    'FontSize', 11, ...
                    'FontColor', [0.42 0.46 0.54]);
                artifactLabel.Layout.Row = 3;
                artifactLabel.Layout.Column = 2;

                artifactDropdown = uidropdown(slotGrid, ...
                    'Items', artifactLabels, ...
                    'ItemsData', artifactIds, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotArtifactSetChanged(i, src.Value));
                artifactDropdown.Layout.Row = 3;
                artifactDropdown.Layout.Column = [3 4];
                obj.SlotArtifactDropdowns{i} = artifactDropdown;

                weaponLabel = uilabel(slotGrid, ...
                    'Text', '武器', ...
                    'FontSize', 11, ...
                    'FontColor', [0.42 0.46 0.54]);
                weaponLabel.Layout.Row = 4;
                weaponLabel.Layout.Column = 2;

                weaponDropdown = uidropdown(slotGrid, ...
                    'Items', {''}, ...
                    'ItemsData', {''}, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotWeaponChanged(i, src.Value));
                weaponDropdown.Layout.Row = 4;
                weaponDropdown.Layout.Column = [3 4];
                obj.SlotWeaponDropdowns{i} = weaponDropdown;

                presetDropdown = uidropdown(slotGrid, ...
                    'Items', {'默认构筑'}, ...
                    'ItemsData', {'default'}, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotPresetChanged(i, src.Value));
                presetDropdown.Layout.Row = 5;
                presetDropdown.Layout.Column = [2 4];
                obj.SlotPresetDropdowns{i} = presetDropdown;

                controlGrid = uigridlayout(slotGrid, [2 4]);
                controlGrid.Layout.Row = 6;
                controlGrid.Layout.Column = [2 4];
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
                enableCheckbox.Layout.Row = 7;
                enableCheckbox.Layout.Column = [2 3];
                obj.SlotEnableCheckboxes{i} = enableCheckbox;

                footer = uilabel(slotGrid, ...
                    'Text', '', ...
                    'HorizontalAlignment', 'right', ...
                    'FontSize', 11, ...
                    'FontColor', [0.44 0.48 0.56]);
                footer.Layout.Row = 7;
                footer.Layout.Column = 4;
                obj.SlotFooters{i} = footer;
            end
        end

        function createEditorWindow(obj)
            if ~isempty(obj.EditorFigure) && isvalid(obj.EditorFigure)
                obj.EditorFigure.Visible = 'on';
                drawnow limitrate;
                return;
            end

            mainPos = obj.Figure.Position;
            screenSize = get(groot, 'ScreenSize');
            editorWidth = 620;
            editorHeight = min(980, max(720, screenSize(4) - 80));
            editorX = min(mainPos(1) + mainPos(3) + 20, screenSize(3) - editorWidth - 20);
            editorX = max(20, editorX);
            editorY = min(max(40, mainPos(2)), screenSize(4) - editorHeight - 60);
            obj.EditorFigure = uifigure( ...
                'Name', '角色详情编辑', ...
                'Position', [editorX editorY editorWidth editorHeight], ...
                'Color', [0.95 0.96 0.98], ...
                'AutoResizeChildren', 'off', ...
                'CloseRequestFcn', @(src, ~) obj.hideEditorWindow(src));

            editorRoot = uigridlayout(obj.EditorFigure, [1 1]);
            editorRoot.RowHeight = {'1x'};
            editorRoot.ColumnWidth = {'1x'};
            editorRoot.Padding = [10 10 10 10];
            obj.createEditorPanel(editorRoot, 1);
        end

        function hideEditorWindow(obj, src)
            if nargin < 2 || isempty(src) || ~isvalid(src)
                return;
            end
            obj.saveSelectedSlotState();
            src.Visible = 'off';
        end

        function createEditorPanel(obj, parent, layoutColumn)
            if nargin < 3 || isempty(layoutColumn)
                layoutColumn = 1;
            end
            % 中间角色编辑区域。
            editorPanel = uipanel(parent, ...
                'Title', '当前角色编辑', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.99 0.99 1.00], ...
                'ForegroundColor', [0.18 0.23 0.33]);
            editorPanel.Layout.Row = 1;
            editorPanel.Layout.Column = layoutColumn;

            editorGrid = uigridlayout(editorPanel, [4 1]);
            editorGrid.RowHeight = {34, 250, '1x', 240};
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

            heroGrid = uigridlayout(heroCard, [3 2]);
            heroGrid.ColumnWidth = {140, '1x'};
            heroGrid.RowHeight = {60, 50, '1x'};
            heroGrid.ColumnSpacing = 10;
            heroGrid.Padding = [10 10 10 10];
            heroGrid.BackgroundColor = [0.96 0.97 0.99];

            obj.SelectedPortrait = uiimage(heroGrid, 'ScaleMethod', 'fit');
            obj.SelectedPortrait.Layout.Row = [1 3];
            obj.SelectedPortrait.Layout.Column = 1;

            badgeGrid = uigridlayout(heroGrid, [2 1]);
            badgeGrid.Layout.Row = 1;
            badgeGrid.Layout.Column = 2;
            badgeGrid.RowHeight = {20, 28};
            badgeGrid.ColumnWidth = {'1x'};
            badgeGrid.ColumnSpacing = 0;
            badgeGrid.RowSpacing = 4;
            badgeGrid.Padding = [0 0 0 0];
            badgeGrid.BackgroundColor = [0.96 0.97 0.99];

            artifactLabel = uilabel(badgeGrid, 'Text', '圣遗物套装', 'FontWeight', 'bold', 'FontColor', [0.18 0.24 0.34]);
            artifactLabel.Layout.Row = 1;
            artifactLabel.Layout.Column = 1;

            [artifactLabels, artifactIds] = getArtifactSetChoices();
            obj.ArtifactSetDropdown = uidropdown(badgeGrid, ...
                'Items', artifactLabels, ...
                'ItemsData', artifactIds, ...
                'ValueChangedFcn', @(src, ~) obj.onSelectedArtifactSetChanged(src.Value));
            obj.ArtifactSetDropdown.Layout.Row = 2;
            obj.ArtifactSetDropdown.Layout.Column = 1;

            detailCtrlGrid = uigridlayout(heroGrid, [2 4]);
            detailCtrlGrid.Layout.Row = 2;
            detailCtrlGrid.Layout.Column = 2;
            detailCtrlGrid.RowHeight = {16, 28};
            detailCtrlGrid.ColumnWidth = {'1.8x', '1x', '1x', '1x'};
            detailCtrlGrid.ColumnSpacing = 8;
            detailCtrlGrid.RowSpacing = 2;
            detailCtrlGrid.Padding = [0 0 0 0];
            detailCtrlGrid.BackgroundColor = [0.96 0.97 0.99];

            detailLabels = {'武器', '命座', '天赋', '精炼'};
            for detailIndex = 1:numel(detailLabels)
                label = uilabel(detailCtrlGrid, ...
                    'Text', detailLabels{detailIndex}, ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 11, ...
                    'FontColor', [0.42 0.46 0.54]);
                label.Layout.Row = 1;
                label.Layout.Column = detailIndex;
            end

            obj.SelectedWeaponDropdown = uidropdown(detailCtrlGrid, ...
                'Items', {''}, ...
                'ItemsData', {''}, ...
                'ValueChangedFcn', @(src, ~) obj.onSelectedWeaponChanged(src.Value));
            obj.SelectedWeaponDropdown.Layout.Row = 2;
            obj.SelectedWeaponDropdown.Layout.Column = 1;

            obj.SelectedConstellationSpinner = uispinner(detailCtrlGrid, ...
                'Limits', [0 6], ...
                'RoundFractionalValues', 'on', ...
                'Step', 1, ...
                'ValueChangedFcn', @(src, ~) obj.onSelectedConstellationChanged(src.Value));
            obj.SelectedConstellationSpinner.Layout.Row = 2;
            obj.SelectedConstellationSpinner.Layout.Column = 2;

            obj.SelectedTalentSpinner = uispinner(detailCtrlGrid, ...
                'Limits', [1 15], ...
                'RoundFractionalValues', 'on', ...
                'Step', 1, ...
                'ValueChangedFcn', @(src, ~) obj.onSelectedTalentChanged(src.Value));
            obj.SelectedTalentSpinner.Layout.Row = 2;
            obj.SelectedTalentSpinner.Layout.Column = 3;

            obj.SelectedRefinementSpinner = uispinner(detailCtrlGrid, ...
                'Limits', [1 5], ...
                'RoundFractionalValues', 'on', ...
                'Step', 1, ...
                'ValueChangedFcn', @(src, ~) obj.onSelectedRefinementChanged(src.Value));
            obj.SelectedRefinementSpinner.Layout.Row = 2;
            obj.SelectedRefinementSpinner.Layout.Column = 4;

            obj.SelectedSummaryText = uitextarea(heroGrid, ...
                'Editable', 'off', ...
                'FontSize', 12, ...
                'BackgroundColor', [0.99 0.99 1.00], ...
                'Value', {'当前角色信息会显示在这里。'});
            obj.SelectedSummaryText.Layout.Row = 3;
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
            % 右侧模拟参数与命令窗口式结果输出。
            resultPanel = uipanel(parent, ...
                'Title', '模拟结果', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.99 0.99 1.00], ...
                'ForegroundColor', [0.18 0.23 0.33]);
            resultPanel.Layout.Row = 1;
            resultPanel.Layout.Column = 2;

            resultGrid = uigridlayout(resultPanel, [2 1]);
            resultGrid.RowHeight = {156, '1x'};
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

            outputPanel = uipanel(resultGrid, ...
                'Title', '命令窗口式模拟输出', ...
                'BackgroundColor', [0.08 0.10 0.14], ...
                'ForegroundColor', [0.87 0.91 0.96]);
            outputPanel.Layout.Row = 2;
            outputPanel.Layout.Column = 1;

            outputGrid = uigridlayout(outputPanel, [1 1]);
            outputGrid.RowHeight = {'1x'};
            outputGrid.ColumnWidth = {'1x'};
            outputGrid.Padding = [8 8 8 8];

            obj.ResultConsole = uitextarea(outputGrid, ...
                'Editable', 'off', ...
                'FontName', 'Consolas', ...
                'FontSize', 12, ...
                'FontColor', [0.90 0.94 0.98], ...
                'BackgroundColor', [0.06 0.08 0.12], ...
                'Value', {'>> 等待运行模拟。'});
            obj.ResultConsole.Layout.Row = 1;
            obj.ResultConsole.Layout.Column = 1;
        end

        function syncDashboard(obj)
            obj.updateResultConsole(false);
        end

        function updateResultConsole(obj, printToCommandWindow)
            if nargin < 2
                printToCommandWindow = false;
            end

            lines = obj.buildResultReportLines();
            obj.LastResultReport = strjoin(lines, newline);

            if ~isempty(obj.ResultConsole) && isvalid(obj.ResultConsole)
                obj.ResultConsole.Value = cellstr(lines);
            end

            if printToCommandWindow
                fprintf('%s\n', char(obj.LastResultReport));
            end
        end

        function lines = buildResultReportLines(obj)
            lines = strings(0, 1);
            lines(end + 1, 1) = ">> Genshin DMG Calc simulation report";
            lines(end + 1, 1) = "   Generated: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            lines(end + 1, 1) = "   Status: " + string(obj.LastStatusMessage);
            lines(end + 1, 1) = "";
            lines(end + 1, 1) = "[Simulation inputs]";
            lines(end + 1, 1) = sprintf('Rotation duration: %.2f s | Enemy Lv.%g | RES %.2f | DEF reduction %.2f', ...
                obj.TeamDurationField.Value, obj.EnemyLevelField.Value, obj.EnemyResField.Value, obj.EnemyDefField.Value);

            hasResult = isstruct(obj.LastResultMetrics) && isfield(obj.LastResultMetrics, 'HasResult') ...
                && logical(obj.LastResultMetrics.HasResult);
            if hasResult && isstruct(obj.LastTeamResult) && isfield(obj.LastTeamResult, 'TotalDMG')
                lines = obj.appendTeamResultReport(lines);
            elseif hasResult && ~isempty(obj.LastMemberResults)
                lines = obj.appendSingleResultReport(lines);
            else
                lines(end + 1, 1) = "";
                lines(end + 1, 1) = "[Rotation preview]";
                lines = obj.appendPreviewTimelineLines(lines);
            end
        end

        function lines = appendSingleResultReport(obj, lines)
            result = obj.LastMemberResults(1);
            slot = obj.Slots(obj.SelectedSlot);
            lines(end + 1, 1) = "";
            lines(end + 1, 1) = "[Single character result]";
            lines(end + 1, 1) = sprintf('Character: %s | Total damage: %.0f | DPS: %.2f | Rotation: %.2f s', ...
                char(string(getFieldOrDefault(result, 'DisplayName', slot.DisplayName))), ...
                double(getFieldOrDefault(result, 'TotalDMG', 0)), ...
                double(getFieldOrDefault(result, 'DPS', 0)), ...
                double(getFieldOrDefault(result, 'RotationTime', 0)));
            lines = obj.appendBuildPanelLines(lines, obj.SelectedSlot);
            lines(end + 1, 1) = "";
            lines(end + 1, 1) = "[Estimated action timeline]";
            lines = obj.appendPreviewTimelineLines(lines, obj.SelectedSlot, ...
                double(getFieldOrDefault(result, 'RotationTime', 0)));
            lines = obj.appendDamageBreakdownWithBuffs(lines, ...
                getFieldOrDefault(result, 'Breakdown', table()), table(), table(), struct());
        end

        function lines = appendTeamResultReport(obj, lines)
            result = obj.LastTeamResult;
            totalDamage = double(getFieldOrDefault(result, 'TotalDMG', 0));
            rotationDuration = double(getFieldOrDefault(result, 'RotationDuration', obj.TeamDurationField.Value));
            lines(end + 1, 1) = "";
            lines(end + 1, 1) = "[Team result]";
            lines(end + 1, 1) = sprintf('Total damage: %.0f | Team DPS: %.2f | Rotation: %.2f s | Next cycle: %s | Readiness: %.2f', ...
                totalDamage, double(getFieldOrDefault(result, 'DPS', 0)), rotationDuration, ...
                char(obj.localOnOff(logical(getFieldOrDefault(result, 'CanLoopNextCycle', false)))), ...
                double(getFieldOrDefault(result, 'LoopReadiness', 0)));

            summary = getFieldOrDefault(result, 'Summary', table());
            if istable(summary) && height(summary) > 0
                lines(end + 1, 1) = "";
                lines(end + 1, 1) = "[Member damage and contribution]";
                for i = 1:height(summary)
                    character = obj.reportTableValue(summary, i, 'Character');
                    damage = obj.reportTableNumber(summary, i, 'TotalDMG');
                    teamDps = obj.reportTableNumber(summary, i, 'TeamCycleDPS');
                    standaloneDps = obj.reportTableNumber(summary, i, 'StandaloneDPS');
                    share = 0;
                    if totalDamage > 0
                        share = 100 * damage / totalDamage;
                    end
                    lines(end + 1, 1) = sprintf('%s | Damage %.0f | Share %.2f%% | Team-cycle DPS %.2f | Standalone DPS %.2f', ...
                        char(character), damage, share, teamDps, standaloneDps);
                end
            end

            lines(end + 1, 1) = "";
            lines(end + 1, 1) = "[Character build panels]";
            for i = find([obj.Slots.Enabled])
                lines = obj.appendBuildPanelLines(lines, i);
            end

            teamContext = getFieldOrDefault(result, 'TeamContext', struct());
            lines = obj.appendTeamContextBuffLines(lines, teamContext);
            lines = obj.appendReportTable(lines, "Rotation plan", getFieldOrDefault(result, 'ExecutionTable', table()));
            lines = obj.appendReportTable(lines, "Complete execution timeline", getFieldOrDefault(result, 'TimelineTable', table()));
            lines = obj.appendReportTable(lines, "Energy summary", getFieldOrDefault(result, 'EnergySummary', table()));
            lines = obj.appendReportTable(lines, "Energy events", getFieldOrDefault(result, 'EnergyTimeline', table()));
            lines = obj.appendReportTable(lines, "Active effects and buffs", getFieldOrDefault(result, 'ActiveEffectsTable', table()));
            lines = obj.appendDamageBreakdownWithBuffs(lines, ...
                getFieldOrDefault(result, 'Breakdown', table()), ...
                getFieldOrDefault(result, 'TimelineTable', table()), ...
                getFieldOrDefault(result, 'ActiveEffectsTable', table()), teamContext);

            warnings = string(getFieldOrDefault(result, 'PlanningWarnings', strings(0, 1)));
            lines(end + 1, 1) = "";
            lines(end + 1, 1) = "[Planning warnings]";
            if isempty(warnings)
                lines(end + 1, 1) = "(none)";
            else
                for i = 1:numel(warnings)
                    lines(end + 1, 1) = "- " + warnings(i);
                end
            end
        end

        function lines = appendBuildPanelLines(obj, lines, slotIndex)
            slot = obj.Slots(slotIndex);
            lines(end + 1, 1) = sprintf('%s | Weapon: %s R%d | Artifact: %s (%d pc) | Constellation: C%d | Talent %d | Start %.2f s', ...
                char(slot.DisplayName), char(string(slot.WeaponName)), round(slot.WeaponRefinement), ...
                char(string(slot.ArtifactSet1)), round(slot.ArtifactSet1Pieces), round(slot.Constellation), ...
                round(slot.TalentLevel), slot.StartTime);

            if ~isstruct(slot.Build) || isempty(fieldnames(slot.Build))
                lines(end + 1, 1) = "  Panel: (no build values)";
                return;
            end

            fields = fieldnames(slot.Build);
            values = strings(0, 1);
            for i = 1:numel(fields)
                value = slot.Build.(fields{i});
                if (isnumeric(value) || islogical(value) || isstring(value) || ischar(value)) && numel(value) <= 12
                    values(end + 1, 1) = string(fields{i}) + "=" + obj.formatReportValue(value); %#ok<AGROW>
                end
            end
            if isempty(values)
                lines(end + 1, 1) = "  Panel: (no scalar build values)";
            else
                lines(end + 1, 1) = "  Panel: " + strjoin(values, " | ");
            end
        end

        function lines = appendTeamContextBuffLines(obj, lines, teamContext) %#ok<INUSD>
            lines(end + 1, 1) = "";
            lines(end + 1, 1) = "[Current team buffs]";
            if ~isstruct(teamContext) || isempty(fieldnames(teamContext))
                lines(end + 1, 1) = "(none)";
                return;
            end

            buffLines = obj.collectTeamBuffValues(teamContext);
            if isempty(buffLines)
                lines(end + 1, 1) = "(no non-zero scalar team buff fields)";
            else
                lines = [lines; "  " + buffLines]; %#ok<AGROW>
            end
        end

        function buffLines = collectTeamBuffValues(obj, teamContext)
            buffLines = strings(0, 1);
            if ~isstruct(teamContext) || isempty(fieldnames(teamContext))
                return;
            end

            fields = fieldnames(teamContext);
            for i = 1:numel(fields)
                fieldName = fields{i};
                value = teamContext.(fieldName);
                isBuffField = any(contains(fieldName, {'Bonus', 'Buff', 'Shred', 'Crit', 'EM', 'Amplify'}, 'IgnoreCase', true));
                if isBuffField && (isnumeric(value) || islogical(value)) && isscalar(value) ...
                        && isfinite(double(value)) && double(value) ~= 0
                    buffLines(end + 1, 1) = string(fieldName) + "=" + obj.formatReportValue(value); %#ok<AGROW>
                end
            end
        end

        function lines = appendDamageBreakdownWithBuffs(obj, lines, breakdown, timeline, activeEffects, teamContext)
            lines(end + 1, 1) = "";
            lines(end + 1, 1) = "[Damage breakdown with active buffs]";
            if ~istable(breakdown) || height(breakdown) == 0
                lines(end + 1, 1) = "(none)";
                return;
            end

            staticBuffs = obj.collectTeamBuffValues(teamContext);
            variableNames = string(breakdown.Properties.VariableNames);
            for rowIndex = 1:height(breakdown)
                values = strings(1, numel(variableNames));
                for columnIndex = 1:numel(variableNames)
                    raw = breakdown{rowIndex, char(variableNames(columnIndex))};
                    if iscell(raw) && numel(raw) == 1
                        raw = raw{1};
                    end
                    values(columnIndex) = variableNames(columnIndex) + "=" + obj.formatReportValue(raw);
                end

                character = obj.reportTableValue(breakdown, rowIndex, 'Character');
                action = obj.reportTableValue(breakdown, rowIndex, 'Action');
                occurrence = obj.damageActionOccurrence(breakdown, rowIndex, character, action);
                [damageTime, timeText] = obj.lookupDamageTime(timeline, character, action, occurrence);
                timedBuffs = obj.activeBuffsAtTime(activeEffects, damageTime);
                allBuffs = [staticBuffs; timedBuffs];
                if isempty(allBuffs)
                    buffText = "none";
                else
                    buffText = strjoin(unique(allBuffs, 'stable'), ", ");
                end
                lines(end + 1, 1) = sprintf('%4d | %s | Time=%s | ActiveBuffs=%s', ...
                    rowIndex, char(strjoin(values, " | ")), char(timeText), char(buffText));
            end
        end

        function occurrence = damageActionOccurrence(obj, breakdown, rowIndex, character, action) %#ok<INUSD>
            occurrence = 1;
            if rowIndex <= 1 || strlength(action) == 0
                return;
            end
            for i = 1:rowIndex - 1
                previousCharacter = obj.reportTableValue(breakdown, i, 'Character');
                previousAction = obj.reportTableValue(breakdown, i, 'Action');
                if strcmpi(char(previousCharacter), char(character)) && strcmpi(char(previousAction), char(action))
                    occurrence = occurrence + 1;
                end
            end
        end

        function [damageTime, timeText] = lookupDamageTime(obj, timeline, character, action, occurrence) %#ok<INUSD>
            damageTime = NaN;
            timeText = "unresolved";
            requiredColumns = {'Character', 'Action', 'EndTime'};
            if ~istable(timeline) || ~all(ismember(requiredColumns, timeline.Properties.VariableNames)) ...
                    || strlength(action) == 0
                return;
            end

            matches = strcmpi(string(timeline.Action), action);
            if strlength(character) > 0
                matches = matches & strcmpi(string(timeline.Character), character);
            end
            indices = find(matches);
            if numel(indices) < occurrence
                return;
            end

            damageTime = double(timeline.EndTime(indices(occurrence)));
            timeText = string(sprintf('%.2f s', damageTime));
        end

        function buffLines = activeBuffsAtTime(obj, activeEffects, damageTime) %#ok<INUSD>
            buffLines = strings(0, 1);
            requiredColumns = {'EffectTag', 'StartTime', 'EndTime'};
            if ~isfinite(damageTime) || ~istable(activeEffects) ...
                    || ~all(ismember(requiredColumns, activeEffects.Properties.VariableNames))
                return;
            end

            isActive = double(activeEffects.StartTime) <= damageTime + 1e-9 ...
                & double(activeEffects.EndTime) >= damageTime - 1e-9;
            effectTags = strtrim(string(activeEffects.EffectTag(isActive)));
            effectTags = effectTags(strlength(effectTags) > 0);
            buffLines = unique(effectTags, 'stable');
        end

        function lines = appendPreviewTimelineLines(obj, lines, slotIndices, rotationTime)
            if nargin < 3 || isempty(slotIndices)
                slotIndices = find([obj.Slots.Enabled]);
            end
            if nargin < 4
                rotationTime = [];
            end
            if isempty(slotIndices)
                lines(end + 1, 1) = "(no enabled character)";
                return;
            end

            for i = 1:numel(slotIndices)
                slot = obj.Slots(slotIndices(i));
                actions = parseRotationTextTokens(slot.RotationText);
                memberRotationTime = [];
                if isscalar(slotIndices) && ~isempty(rotationTime) && rotationTime > 0
                    memberRotationTime = rotationTime;
                end
                [durations, labels] = obj.estimateTimelineBlocks(slot, actions, memberRotationTime);
                currentTime = slot.StartTime;
                for j = 1:numel(durations)
                    lines(end + 1, 1) = sprintf('[%6.2f, %6.2f] %s | %s', ...
                        currentTime, currentTime + durations(j), char(slot.DisplayName), char(string(labels{j})));
                    currentTime = currentTime + durations(j);
                end
            end
        end

        function lines = appendReportTable(obj, lines, titleText, sourceTable)
            lines(end + 1, 1) = "";
            lines(end + 1, 1) = "[" + string(titleText) + "]";
            if ~istable(sourceTable) || height(sourceTable) == 0
                lines(end + 1, 1) = "(none)";
                return;
            end

            variableNames = string(sourceTable.Properties.VariableNames);
            for rowIndex = 1:height(sourceTable)
                values = strings(1, numel(variableNames));
                for columnIndex = 1:numel(variableNames)
                    raw = sourceTable{rowIndex, char(variableNames(columnIndex))};
                    if iscell(raw) && numel(raw) == 1
                        raw = raw{1};
                    end
                    values(columnIndex) = variableNames(columnIndex) + "=" + obj.formatReportValue(raw);
                end
                lines(end + 1, 1) = sprintf('%4d | %s', rowIndex, char(strjoin(values, " | ")));
            end
        end

        function value = reportTableValue(obj, sourceTable, rowIndex, variableName) %#ok<INUSD>
            value = "";
            if ~ismember(variableName, sourceTable.Properties.VariableNames)
                return;
            end
            raw = sourceTable{rowIndex, variableName};
            if iscell(raw) && numel(raw) == 1
                raw = raw{1};
            end
            value = string(raw);
        end

        function value = reportTableNumber(obj, sourceTable, rowIndex, variableName) %#ok<INUSD>
            value = 0;
            if ~ismember(variableName, sourceTable.Properties.VariableNames)
                return;
            end
            raw = sourceTable{rowIndex, variableName};
            if iscell(raw) && numel(raw) == 1
                raw = raw{1};
            end
            if isnumeric(raw) || islogical(raw)
                value = double(raw(1));
            else
                parsed = str2double(string(raw));
                if ~isnan(parsed)
                    value = parsed;
                end
            end
        end

        function value = formatReportValue(obj, raw) %#ok<INUSD>
            if isempty(raw)
                value = "[]";
            elseif iscell(raw)
                parts = strings(0, 1);
                for i = 1:numel(raw)
                    parts(end + 1, 1) = obj.formatReportValue(raw{i}); %#ok<AGROW>
                end
                value = "{" + strjoin(parts, ", ") + "}";
            elseif isstring(raw) || ischar(raw) || iscategorical(raw)
                value = string(raw);
            elseif isnumeric(raw)
                if isscalar(raw)
                    value = string(sprintf('%.6g', double(raw)));
                else
                    value = string(mat2str(raw));
                end
            elseif islogical(raw)
                value = string(mat2str(raw));
            elseif isstruct(raw)
                fields = fieldnames(raw);
                parts = strings(0, 1);
                for i = 1:min(numel(fields), 8)
                    parts(end + 1, 1) = string(fields{i}) + "=" + obj.formatReportValue(raw.(fields{i})); %#ok<AGROW>
                end
                value = "{" + strjoin(parts, ", ") + "}";
            else
                value = string(raw);
            end
            value = replace(value, [newline, sprintf('\r')], " ");
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
            slot.RotationEdited = false;
            slot.Constellation = getFieldOrDefault(cfg, 'Constellation', 0);
            slot.TalentLevel = getFieldOrDefault(cfg, 'TalentLevel', 10);
            slot.WeaponList = listWeaponsForCharacter(cfg.Name);
            slot.WeaponName = string(getFieldOrDefault(slot.Build, 'Weapon', ""));
            slot.WeaponRefinement = max(1, min(5, getFieldOrDefault(slot.Build, 'WeaponRefinement', 1)));
            slot.ArtifactSet1 = string(getFieldOrDefault(slot.Build, 'ArtifactSet1', "None"));
            slot.ArtifactSet1Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet1Pieces', 0);
            slot.ArtifactSet2 = string(getFieldOrDefault(slot.Build, 'ArtifactSet2', "None"));
            slot.ArtifactSet2Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet2Pieces', 0);
            slot.ArtifactSet4Active = getFieldOrDefault(slot.Build, 'ArtifactSet4Active', 1);
            slot.Enabled = true;
            slot.PortraitPath = string(getPortraitForCharacter(cfg.Name, obj.PortraitCacheDir));

            if preserveSlotTiming
                slot.StartTime = oldSlot.StartTime;
                slot.Enabled = oldSlot.Enabled;
            else
                slot.StartTime = 0;
            end

            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
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

            obj.updateCharacterDropdown(slotIndex);
            obj.updatePresetDropdown(slotIndex);
            obj.updateWeaponDropdown(slotIndex);
            obj.updateArtifactDropdown(slotIndex);

            obj.SlotConstellationSpinners{slotIndex}.Value = slot.Constellation;
            obj.SlotTalentSpinners{slotIndex}.Value = slot.TalentLevel;
            obj.SlotRefinementSpinners{slotIndex}.Value = slot.WeaponRefinement;
            obj.SlotStartTimeFields{slotIndex}.Value = slot.StartTime;
            obj.SlotEnableCheckboxes{slotIndex}.Value = slot.Enabled;

            footerText = sprintf('%s | %s', char(slot.DisplayName), char(slot.ArtifactSet1));
            obj.SlotFooters{slotIndex}.Text = footerText;

            if strlength(slot.PortraitPath) > 0 && isfile(slot.PortraitPath)
                obj.SlotPortraits{slotIndex}.ImageSource = char(slot.PortraitPath);
            end
            obj.syncDashboard();
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
            obj.SelectedSlot = max(1, min(numel(obj.Slots), round(slotIndex)));
            obj.refreshSelectionVisuals();
            obj.refreshEditorForSelectedSlot();
        end

        function openEditorForSlot(obj, slotIndex)
            if nargin < 2 || isempty(slotIndex)
                slotIndex = obj.SelectedSlot;
            end
            obj.selectSlot(slotIndex);
            obj.createEditorWindow();
            obj.refreshEditorForSelectedSlot();
        end

        function refreshEditorForSelectedSlot(obj)
            if isempty(obj.SelectedSlotLabel) || ~isvalid(obj.SelectedSlotLabel)
                return;
            end
            % 将当前队伍槽的内容加载到中间编辑区。
            slot = obj.Slots(obj.SelectedSlot);

            obj.SelectedSlotLabel.Text = sprintf('当前编辑：队伍槽 %d | %s (%s)', ...
                obj.SelectedSlot, char(slot.DisplayName), char(slot.CharacterKey));

            if strlength(slot.PortraitPath) > 0 && isfile(slot.PortraitPath)
                obj.SelectedPortrait.ImageSource = char(slot.PortraitPath);
            end

            obj.assignDropdownItems(obj.ArtifactSetDropdown, obj.ArtifactSetDropdown.Items, obj.ArtifactSetDropdown.ItemsData, char(slot.ArtifactSet1));
            obj.SelectedConstellationSpinner.Value = slot.Constellation;
            obj.SelectedTalentSpinner.Value = slot.TalentLevel;
            obj.SelectedRefinementSpinner.Value = slot.WeaponRefinement;
            obj.updateSelectedWeaponDropdown();

            summaryLines = { ...
                sprintf('角色：%s | 英文键：%s', char(slot.DisplayName), char(slot.CharacterKey)), ...
                sprintf('构筑预设：%s', char(obj.lookupPresetLabel(slot))), ...
                sprintf('武器：%s | 精炼 %d', char(slot.WeaponName), slot.WeaponRefinement), ...
                sprintf('圣遗物：%s (%s)', char(slot.ArtifactSet1), char(obj.resolveArtifactModeLabel(slot))), ...
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
            obj.syncDashboard();
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
            if isempty(obj.BuildTable) || isempty(obj.RotationTextArea) || isempty(obj.Slots) ...
                    || ~isvalid(obj.BuildTable) || ~isvalid(obj.RotationTextArea)
                return;
            end
            if obj.SelectedSlot < 1 || obj.SelectedSlot > numel(obj.Slots)
                return;
            end

            slot = obj.Slots(obj.SelectedSlot);
            if ~isempty(obj.BuildTable.Data)
                slot.Build = tableDataToBuildStruct(obj.BuildTable.Data);
                slot.Build = materializeArtifactPieceModel(slot.CharacterKey, slot.Build, struct());
            end
            slot.RotationText = obj.getRotationTextValue();
            slot.RotationEdited = obj.isCustomRotationText(slot.CharacterKey, slot.RotationText);
            slot.WeaponName = string(getFieldOrDefault(slot.Build, 'Weapon', slot.WeaponName));
            slot.WeaponRefinement = max(1, min(5, getFieldOrDefault(slot.Build, 'WeaponRefinement', slot.WeaponRefinement)));
            slot.ArtifactSet1 = string(getFieldOrDefault(slot.Build, 'ArtifactSet1', slot.ArtifactSet1));
            slot.ArtifactSet1Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet1Pieces', slot.ArtifactSet1Pieces);
            slot.ArtifactSet2 = string(getFieldOrDefault(slot.Build, 'ArtifactSet2', slot.ArtifactSet2));
            slot.ArtifactSet2Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet2Pieces', slot.ArtifactSet2Pieces);
            slot.ArtifactSet4Active = getFieldOrDefault(slot.Build, 'ArtifactSet4Active', slot.ArtifactSet4Active);
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

        function normalized = normalizeRotationText(obj, rotationText) %#ok<MANU>
            lines = splitlines(string(rotationText));
            lines = strip(lines(:));
            lines = lines(strlength(lines) > 0);
            normalized = join(lines, newline);
        end

        function tf = isCustomRotationText(obj, characterKey, rotationText)
            defaultText = getCharacterDefaultRotationText(characterKey);
            tf = ~strcmp(char(obj.normalizeRotationText(rotationText)), ...
                char(obj.normalizeRotationText(defaultText)));
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

        function updateCharacterDropdown(obj, slotIndex)
            dropdown = obj.SlotCharacterDropdowns{slotIndex};
            slot = obj.Slots(slotIndex);
            labels = obj.getCharacterDropdownLabels();
            itemData = cellstr(string({obj.Registry.Key}));
            currentValue = char(slot.CharacterKey);

            if isempty(itemData)
                itemData = {currentValue};
                labels = {currentValue};
            else
                itemData = itemData(:);
                labels = labels(:);
                if ~isempty(currentValue) && ~any(strcmp(itemData, currentValue))
                    itemData = [{currentValue}; itemData];
                    labels = [{currentValue}; labels];
                end
            end

            obj.assignDropdownItems(dropdown, labels, itemData, currentValue);
        end

        function updateWeaponDropdown(obj, slotIndex)
            % 刷新武器下拉框，并确保当前 build 中的武器仍可选。
            slot = obj.Slots(slotIndex);
            dropdown = obj.SlotWeaponDropdowns{slotIndex};

            itemData = {};
            if ~isempty(slot.WeaponList)
                itemData = cellstr(string(slot.WeaponList.Name));
                itemData = itemData(:);
            end
            currentWeapon = char(slot.WeaponName);
            if ~isempty(currentWeapon) && ~any(strcmp(itemData, currentWeapon))
                itemData = [{currentWeapon}; itemData];
            end
            if isempty(itemData)
                itemData = {''};
            end

            obj.assignDropdownItems(dropdown, itemData, itemData, currentWeapon);
        end

        function updateSelectedWeaponDropdown(obj)
            % 刷新中间编辑区武器下拉框，并与当前槽位保持一致。
            if isempty(obj.SelectedWeaponDropdown) || obj.SelectedSlot < 1 || obj.SelectedSlot > numel(obj.Slots)
                return;
            end

            slot = obj.Slots(obj.SelectedSlot);
            itemData = {};
            if ~isempty(slot.WeaponList)
                itemData = cellstr(string(slot.WeaponList.Name));
                itemData = itemData(:);
            end
            currentWeapon = char(slot.WeaponName);
            if ~isempty(currentWeapon) && ~any(strcmp(itemData, currentWeapon))
                itemData = [{currentWeapon}; itemData];
            end
            if isempty(itemData)
                itemData = {''};
            end

            obj.assignDropdownItems(obj.SelectedWeaponDropdown, itemData, itemData, currentWeapon);
        end

        function updateArtifactDropdown(obj, slotIndex)
            % 刷新圣遗物套装下拉框。
            [labels, ids] = getArtifactSetChoices();
            dropdown = obj.SlotArtifactDropdowns{slotIndex};
            currentValue = char(obj.Slots(slotIndex).ArtifactSet1);
            if ~any(strcmp(ids, currentValue))
                currentValue = 'None';
            end
            obj.assignDropdownItems(dropdown, labels, ids, currentValue);
        end

        function assignDropdownItems(obj, dropdown, labels, itemData, currentValue) %#ok<INUSL>
            if isempty(labels)
                labels = {''};
            end
            if isempty(itemData)
                itemData = {''};
            end

            labels = labels(:);
            itemData = itemData(:);
            dropdown.Items = labels;
            dropdown.ItemsData = itemData;

            if nargin < 5 || isempty(currentValue)
                dropdown.Value = itemData{1};
            elseif any(strcmp(itemData, currentValue))
                dropdown.Value = currentValue;
            else
                dropdown.Value = itemData{1};
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

        function build = applyArtifactSelectionToBuild(obj, build, slot) %#ok<MANU>
            % 将当前槽位中的套装选择同步回 build 元数据字段。
            build = materializeArtifactPieceModel(slot.CharacterKey, build, struct());
            build.ArtifactSet1 = char(slot.ArtifactSet1);
            build.ArtifactSet1Pieces = slot.ArtifactSet1Pieces;
            build.ArtifactSet2 = char(slot.ArtifactSet2);
            build.ArtifactSet2Pieces = slot.ArtifactSet2Pieces;
            build.ArtifactSet4Active = slot.ArtifactSet4Active;
            build = obj.syncArtifactPieceFields(build, slot);
        end

        function build = syncArtifactPieceFields(obj, build, slot) %#ok<INUSL>
            slotNames = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
            if slot.ArtifactSet1Pieces >= 4
                setLayout = {char(slot.ArtifactSet1), char(slot.ArtifactSet1), char(slot.ArtifactSet1), char(slot.ArtifactSet1), 'None'};
            elseif slot.ArtifactSet1Pieces == 2 && slot.ArtifactSet2Pieces >= 2
                setLayout = {char(slot.ArtifactSet1), char(slot.ArtifactSet1), char(slot.ArtifactSet2), char(slot.ArtifactSet2), 'None'};
            elseif slot.ArtifactSet1Pieces == 2
                setLayout = {char(slot.ArtifactSet1), char(slot.ArtifactSet1), 'None', 'None', 'None'};
            else
                setLayout = {'None', 'None', 'None', 'None', 'None'};
            end

            for i = 1:numel(slotNames)
                build.(sprintf('Artifact%sSet', slotNames{i})) = setLayout{i};
            end
            build = materializeArtifactPieceModel(slot.CharacterKey, build, struct());
        end

        function modeValue = resolveArtifactMode(obj, slot) %#ok<MANU>
            if slot.ArtifactSet1Pieces >= 4
                modeValue = '4pc';
            elseif slot.ArtifactSet1Pieces == 2 && slot.ArtifactSet2Pieces == 2
                modeValue = '2p2p';
            elseif slot.ArtifactSet1Pieces == 2
                modeValue = '2pc';
            else
                modeValue = '0pc';
            end
        end

        function modeLabel = resolveArtifactModeLabel(obj, slot) %#ok<MANU>
            switch obj.resolveArtifactMode(slot)
                case '4pc'
                    modeLabel = '4件套';
                case '2p2p'
                    modeLabel = '2+2';
                case '2pc'
                    modeLabel = '2件套';
                otherwise
                    modeLabel = '无套装';
            end
        end

        function memberCfg = buildMemberConfig(obj, slotIndex, respectTeamAutoPlan)
            % 将 GUI 队伍槽状态转换成统一模拟入口需要的角色配置。
            if nargin < 3
                respectTeamAutoPlan = false;
            end
            slot = obj.Slots(slotIndex);
            rotationText = slot.RotationText;
            if strlength(strtrim(rotationText)) == 0
                rotationText = getCharacterDefaultRotationText(slot.CharacterKey);
            end
            hasCustomRotation = logical(getFieldOrDefault(slot, 'RotationEdited', false)) ...
                || obj.isCustomRotationText(slot.CharacterKey, rotationText);
            useExplicitRotationSeed = ~respectTeamAutoPlan || hasCustomRotation;

            overrides = struct( ...
                'Constellation', slot.Constellation, ...
                'TalentLevel', slot.TalentLevel, ...
                'Build', slot.Build, ...
                'StartTime', slot.StartTime, ...
                'HasExplicitRotationSeed', useExplicitRotationSeed);
            if useExplicitRotationSeed
                tempRotationPath = writeTempRotationFile( ...
                    obj.TempRotationDir, slot.CharacterKey, slotIndex, rotationText);
                overrides.RotationFile = tempRotationPath;
            end
            memberCfg = getDefaultCharacterConfig(char(slot.CharacterKey), overrides);
        end

        function memberCfg = buildComparisonMemberConfig(obj, slotIndex, slot, respectTeamAutoPlan)
            if nargin < 4
                respectTeamAutoPlan = false;
            end
            rotationText = slot.RotationText;
            if strlength(strtrim(rotationText)) == 0
                rotationText = getCharacterDefaultRotationText(slot.CharacterKey);
            end
            hasCustomRotation = logical(getFieldOrDefault(slot, 'RotationEdited', false)) ...
                || obj.isCustomRotationText(slot.CharacterKey, rotationText);
            useExplicitRotationSeed = ~respectTeamAutoPlan || hasCustomRotation;

            overrides = struct( ...
                'Constellation', slot.Constellation, ...
                'TalentLevel', slot.TalentLevel, ...
                'Build', slot.Build, ...
                'StartTime', slot.StartTime, ...
                'HasExplicitRotationSeed', useExplicitRotationSeed);
            if useExplicitRotationSeed
                tempRotationPath = writeTempRotationFile( ...
                    obj.TempRotationDir, slot.CharacterKey, slotIndex, rotationText);
                overrides.RotationFile = tempRotationPath;
            end
            memberCfg = getDefaultCharacterConfig(char(slot.CharacterKey), overrides);
        end

        function enemy = buildEnemy(obj)
            % 由右侧参数区构造敌人配置。
            enemy = struct( ...
                'Level', obj.EnemyLevelField.Value, ...
                'Res', obj.EnemyResField.Value, ...
                'DefReduct', obj.EnemyDefField.Value, ...
                'ReactionMode', "Realistic", ...
                'AutoSupportAura', false, ...
                'EnemyCount', 1, ...
                'TargetCount', 1);
        end

        function [members, slotIndices] = buildEnabledMembers(obj)
            % 收集所有启用的队伍成员配置。
            members = {};
            slotIndices = [];
            for i = 1:numel(obj.Slots)
                if obj.Slots(i).Enabled
                    members{end + 1} = obj.buildMemberConfig(i, true); %#ok<AGROW>
                    slotIndices(end + 1) = i; %#ok<AGROW>
                end
            end
        end

        function [members, slotIndices] = buildEnabledMembersFromSlotCopies(obj, slots)
            members = {};
            slotIndices = [];
            for i = 1:numel(slots)
                if slots(i).Enabled
                    members{end + 1} = obj.buildComparisonMemberConfig(i, slots(i), true); %#ok<AGROW>
                    slotIndices(end + 1) = i; %#ok<AGROW>
                end
            end
        end

        function runSingleSimulation(obj)
            % 按当前选中角色执行单人模拟。
            obj.saveSelectedSlotState();
            try
                memberCfg = obj.buildMemberConfig(obj.SelectedSlot, false);
                result = simulateCharacterDPS(memberCfg, obj.buildEnemy());
                obj.LastTeamResult = struct();
                obj.LastMemberResults = result;
                obj.LastSimulationMode = "单人";
                obj.LastResultMetrics = struct( ...
                    'HasResult', true, ...
                    'TotalDamage', result.TotalDMG, ...
                    'DPS', result.DPS, ...
                    'RotationTime', result.RotationTime);

                obj.setStatus(sprintf('已完成单人模拟：%s。', char(result.DisplayName)));
                obj.updateResultConsole(true);
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
                obj.LastResultMetrics = struct( ...
                    'HasResult', true, ...
                    'TotalDamage', teamResult.TotalDMG, ...
                    'DPS', teamResult.DPS, ...
                    'RotationTime', teamResult.RotationDuration);

                obj.setStatus(obj.localBuildTeamStatus(teamResult, numel(slotIndices)));
                obj.updateResultConsole(true);
                obj.showTeamPlanningNotice(teamResult);
            catch ME
                obj.showSimulationError(ME);
            end
        end

        function runComparisonAnalysis(obj, mode)
            obj.saveSelectedSlotState();
            if nargin < 2 || isempty(mode)
                mode = obj.currentComparisonMode();
            end
            obj.runComparisonAnalysisForMode(mode);
        end

        function runComparisonAnalysisForMode(obj, mode)
            mode = string(mode);
            obj.setComparisonMode(mode);
            page = obj.getComparisonPage(mode);
            obj.LastComparisonMode = mode;
            obj.ComparisonStatusLabel.Text = sprintf('Running: %s...', char(obj.comparisonModeTitle(mode)));
            if ~isempty(page)
                page.StatusLabel.Text = sprintf('Running %s...', char(obj.comparisonCharacterLabel()));
                page.RoleLabel.Text = char(obj.comparisonCharacterLabel());
                obj.updateComparisonPage(mode, page);
            end
            drawnow limitrate;

            try
                switch char(mode)
                    case 'weapon_single'
                        resultTable = obj.evaluateWeaponRanking();
                    case 'artifact_single'
                        resultTable = obj.evaluateArtifactRanking(false);
                    case 'artifact_team'
                        resultTable = obj.evaluateArtifactRanking(true);
                    case 'artifact_constellation'
                        resultTable = obj.evaluateConstellationRanking(false);
                    case 'constellation_team_gain'
                        resultTable = obj.evaluateConstellationRanking(true);
                    otherwise
                        error('Unknown comparison mode: %s', char(mode));
                end

                obj.LastComparisonResults = resultTable;
                page = obj.getComparisonPage(mode);
                if ~isempty(page)
                    page.Table.Data = obj.displayComparisonTable(resultTable);
                    page.Table.UserData = resultTable;
                    obj.renderComparisonChart(page.Axes, resultTable, mode);
                    page.StatusLabel.Text = obj.buildComparisonStatus(resultTable, mode);
                    page.RoleLabel.Text = char(obj.comparisonCharacterLabel());
                    obj.updateComparisonPage(mode, page);
                    obj.ComparisonTable = page.Table;
                    obj.ComparisonAxes = page.Axes;
                end
                obj.ComparisonStatusLabel.Text = sprintf('Done: %d candidates.', height(resultTable));
                obj.setStatus(sprintf('Comparison done: %s, %d candidates.', char(mode), height(resultTable)));
            catch ME
                obj.ComparisonStatusLabel.Text = 'Comparison failed.';
                if ~isempty(page)
                    page.StatusLabel.Text = 'Comparison failed.';
                    obj.updateComparisonPage(mode, page);
                end
                obj.showSimulationError(ME);
            end
        end

        function mode = currentComparisonMode(obj)
            mode = "weapon_single";
            if ~isempty(obj.LastComparisonMode) && strlength(string(obj.LastComparisonMode)) > 0
                mode = string(obj.LastComparisonMode);
                return;
            end
            if ~isempty(obj.ComparisonTabGroup) && isvalid(obj.ComparisonTabGroup) ...
                    && ~isempty(obj.ComparisonTabGroup.SelectedTab)
                mode = string(obj.ComparisonTabGroup.SelectedTab.UserData);
            end
        end

        function setComparisonMode(obj, mode)
            mode = string(mode);
            obj.LastComparisonMode = mode;
            page = obj.getComparisonPage(mode);
            if ~isempty(page)
                if ~isempty(obj.ComparisonTabGroup) && isvalid(obj.ComparisonTabGroup)
                    obj.ComparisonTabGroup.SelectedTab = page.Tab;
                end
                obj.ComparisonTable = page.Table;
                obj.ComparisonAxes = page.Axes;
                page.RoleLabel.Text = char(obj.comparisonCharacterLabel());
                obj.updateComparisonPage(mode, page);
            end
        end

        function page = getComparisonPage(obj, mode)
            page = [];
            if isempty(obj.ComparisonPages) || ~isstruct(obj.ComparisonPages)
                return;
            end
            fieldName = char(string(mode));
            if isfield(obj.ComparisonPages, fieldName)
                page = obj.ComparisonPages.(fieldName);
            end
        end

        function updateComparisonPage(obj, mode, page)
            fieldName = char(string(mode));
            if isempty(fieldName)
                return;
            end
            obj.ComparisonPages.(fieldName) = page;
        end

        function titleText = comparisonModeTitle(obj, mode) %#ok<INUSL>
            switch char(string(mode))
                case 'weapon_single'
                    titleText = "武器排名";
                case 'artifact_single'
                    titleText = "圣遗物排名";
                case 'artifact_team'
                    titleText = "圣遗物进队";
                case 'artifact_constellation'
                    titleText = "套装命座";
                case 'constellation_team_gain'
                    titleText = "命座团队提升";
                otherwise
                    titleText = string(mode);
            end
        end

        function label = comparisonCharacterLabel(obj)
            slot = obj.Slots(obj.SelectedSlot);
            signatureWeapon = obj.getSignatureWeaponName(slot);
            label = sprintf('当前角色：%s (%s) | 当前武器：%s | 百分比基准：%s', ...
                char(slot.DisplayName), char(slot.CharacterKey), char(slot.WeaponName), char(signatureWeapon));
        end

        function weaponName = getSignatureWeaponName(obj, slot) %#ok<INUSL>
            weaponName = string(getFieldOrDefault(slot.Build, 'Weapon', slot.WeaponName));
            try
                cfg = getDefaultCharacterConfig(char(slot.CharacterKey));
                weaponName = string(getFieldOrDefault(cfg.Build, 'Weapon', weaponName));
            catch
            end
            if strlength(weaponName) == 0
                weaponName = string(slot.WeaponName);
            end
        end

        function slot = applySignatureWeaponToSlot(obj, slot)
            cfg = struct();
            try
                cfg = getDefaultCharacterConfig(char(slot.CharacterKey));
            catch
            end

            weaponName = obj.getSignatureWeaponName(slot);
            slot.WeaponName = weaponName;
            slot.Build.Weapon = char(weaponName);
            slot.Build.WeaponRefinement = slot.WeaponRefinement;

            if isempty(slot.WeaponList)
                slot.WeaponList = listWeaponsForCharacter(slot.CharacterKey);
            end
            if ~isempty(slot.WeaponList) && any(string(slot.WeaponList.Name) == weaponName)
                slot.Build = obj.applyWeaponStatsToBuild( ...
                    slot.Build, slot.WeaponList, weaponName, slot.WeaponRefinement);
                return;
            end

            if isstruct(cfg) && isfield(cfg, 'Build')
                slot.Build.WeaponATK = getFieldOrDefault(cfg.Build, 'WeaponATK', getFieldOrDefault(slot.Build, 'WeaponATK', 0));
                slot.Build.WeaponSubStatType = getFieldOrDefault(cfg.Build, 'WeaponSubStatType', getFieldOrDefault(slot.Build, 'WeaponSubStatType', ""));
                slot.Build.WeaponSubStatValue = getFieldOrDefault(cfg.Build, 'WeaponSubStatValue', getFieldOrDefault(slot.Build, 'WeaponSubStatValue', 0));
            end
        end

        function slot = applyConstellationToSlot(obj, slot, constellation)
            slot.Constellation = constellation;
            try
                cfg = getDefaultCharacterConfig(char(slot.CharacterKey));
                defaultBuild = getFieldOrDefault(cfg, 'Build', struct());
                currentBuild = slot.Build;
                currentBuild.Constellation = constellation;
                currentBuild.CharacterConstellation = constellation;
                slot.Build = obj.copyMatchingBuildFields(defaultBuild, currentBuild, "C" + string(constellation));
            catch
                slot.Build.Constellation = constellation;
                slot.Build.CharacterConstellation = constellation;
            end
        end

        function target = copyMatchingBuildFields(obj, source, target, suffix) %#ok<INUSL>
            if ~isstruct(source) || ~isstruct(target)
                return;
            end

            sourceFields = string(fieldnames(source));
            targetFields = string(fieldnames(target));
            suffix = string(suffix);
            for i = 1:numel(targetFields)
                fieldName = targetFields(i);
                sourceName = fieldName + suffix;
                if any(sourceFields == sourceName)
                    target.(char(fieldName)) = source.(char(sourceName));
                end
            end
        end

        function resultTable = evaluateWeaponRanking(obj)
            slot = obj.Slots(obj.SelectedSlot);
            if isempty(slot.WeaponList)
                slot.WeaponList = listWeaponsForCharacter(slot.CharacterKey);
            end
            if isempty(slot.WeaponList) || height(slot.WeaponList) == 0
                error('No weapons are available for %s.', char(slot.CharacterKey));
            end

            baselineSlot = obj.applySignatureWeaponToSlot(slot);
            baseline = obj.simulateSingleSlotCandidate(baselineSlot);
            baselineDPS = baseline.DPS;
            baselineWeapon = obj.getSignatureWeaponName(slot);
            rows = repmat(obj.emptyComparisonRow(), 0, 1);
            weapons = slot.WeaponList;

            for i = 1:height(weapons)
                candidateSlot = slot;
                weaponName = string(weapons.Name(i));
                candidateSlot.WeaponName = weaponName;
                candidateSlot.Build = obj.applyWeaponStatsToBuild( ...
                    candidateSlot.Build, candidateSlot.WeaponList, weaponName, candidateSlot.WeaponRefinement);

                row = obj.emptyComparisonRow();
                row.Character = string(slot.DisplayName);
                row.CharacterKey = string(slot.CharacterKey);
                row.Candidate = weaponName;
                row.CandidateType = "Weapon";
                row.Weapon = weaponName;
                row.BaselineWeapon = baselineWeapon;
                row.ArtifactSet1 = string(candidateSlot.ArtifactSet1);
                row.ArtifactSet2 = string(candidateSlot.ArtifactSet2);
                row.ArtifactMode = string(obj.resolveArtifactMode(candidateSlot));
                row.Constellation = candidateSlot.Constellation;
                try
                    result = obj.simulateSingleSlotCandidate(candidateSlot);
                    row.TotalDMG = result.TotalDMG;
                    row.DPS = result.DPS;
                    row.MemberTotalDMG = result.TotalDMG;
                    row.MemberDPS = result.DPS;
                    row.MetricTotalDMG = result.TotalDMG;
                    row.MetricDPS = result.DPS;
                    row.ExpectedDMG = result.TotalDMG;
                    row.ExpectedDPS = result.DPS;
                    row.BaselineDPS = baselineDPS;
                    row.GainPct = obj.safePercentGain(result.DPS, baselineDPS);
                catch ME
                    row.Message = string(ME.message);
                end
                rows(end + 1) = row; %#ok<AGROW>
            end

            resultTable = obj.rankComparisonRows(rows, false);
        end

        function resultTable = evaluateArtifactRanking(obj, useTeam)
            slot = obj.Slots(obj.SelectedSlot);
            registry = getArtifactSetRegistry();
            keep = string({registry.Id}) ~= "None";
            if obj.ComparisonImplementedOnlyCheckbox.Value
                keep = keep & logical([registry.IsImplemented]);
            end
            registry = registry(keep);
            if isempty(registry)
                error('No artifact sets are available for comparison.');
            end

            rows = repmat(obj.emptyComparisonRow(), 0, 1);
            baselineSlot = obj.applySignatureWeaponToSlot(slot);
            baselineWeapon = obj.getSignatureWeaponName(slot);
            if useTeam
                baselineSlots = obj.Slots;
                baselineSlots(obj.SelectedSlot) = baselineSlot;
                baselineSlots(obj.SelectedSlot).Enabled = true;
                [baselineTeam, baselineMembers, baselineSlotIndices] = obj.simulateTeamForSlotCopies(baselineSlots);
                baselineDPS = baselineTeam.DPS;
                [baselineMemberTotal, baselineMemberDPS] = obj.lookupSelectedMemberMetrics( ...
                    baselineMembers, baselineSlotIndices, baselineTeam.RotationDuration);
            else
                baseline = obj.simulateSingleSlotCandidate(baselineSlot);
                baselineDPS = baseline.DPS;
                baselineMemberTotal = baseline.TotalDMG;
                baselineMemberDPS = baseline.DPS;
            end

            for i = 1:numel(registry)
                candidateSlot = obj.applyArtifactCandidateToSlot(baselineSlot, registry(i).Id);

                row = obj.emptyComparisonRow();
                row.Character = string(slot.DisplayName);
                row.CharacterKey = string(slot.CharacterKey);
                row.Candidate = string(registry(i).DisplayName) + " | " + string(registry(i).Id);
                row.CandidateType = "Artifact4pc";
                row.Weapon = string(candidateSlot.WeaponName);
                row.BaselineWeapon = baselineWeapon;
                row.ArtifactSet1 = string(candidateSlot.ArtifactSet1);
                row.ArtifactSet2 = string(candidateSlot.ArtifactSet2);
                row.ArtifactMode = string(obj.resolveArtifactMode(candidateSlot));
                row.Constellation = candidateSlot.Constellation;
                row.BaselineDPS = baselineDPS;

                try
                    if useTeam
                        candidateSlots = obj.Slots;
                        candidateSlots(obj.SelectedSlot) = candidateSlot;
                        candidateSlots(obj.SelectedSlot).Enabled = true;
                        [teamResult, memberResults, slotIndices] = obj.simulateTeamForSlotCopies(candidateSlots);
                        [memberTotal, memberDPS] = obj.lookupSelectedMemberMetrics( ...
                            memberResults, slotIndices, teamResult.RotationDuration);
                        row.TotalDMG = teamResult.TotalDMG;
                        row.DPS = teamResult.DPS;
                        row.TeamTotalDMG = teamResult.TotalDMG;
                        row.TeamDPS = teamResult.DPS;
                        row.MemberTotalDMG = memberTotal;
                        row.MemberDPS = memberDPS;
                        row.MetricTotalDMG = teamResult.TotalDMG;
                        row.MetricDPS = teamResult.DPS;
                        row.ExpectedDMG = teamResult.TotalDMG;
                        row.ExpectedDPS = teamResult.DPS;
                        row.GainPct = obj.safePercentGain(teamResult.DPS, baselineDPS);
                    else
                        result = obj.simulateSingleSlotCandidate(candidateSlot);
                        row.TotalDMG = result.TotalDMG;
                        row.DPS = result.DPS;
                        row.MemberTotalDMG = result.TotalDMG;
                        row.MemberDPS = result.DPS;
                        row.MetricTotalDMG = result.TotalDMG;
                        row.MetricDPS = result.DPS;
                        row.ExpectedDMG = result.TotalDMG;
                        row.ExpectedDPS = result.DPS;
                        row.GainPct = obj.safePercentGain(result.DPS, baselineDPS);
                    end
                catch ME
                    row.Message = string(ME.message);
                    if useTeam
                        row.MemberTotalDMG = baselineMemberTotal;
                        row.MemberDPS = baselineMemberDPS;
                    end
                end
                rows(end + 1) = row; %#ok<AGROW>
            end

            resultTable = obj.rankComparisonRows(rows, false);
        end

        function resultTable = evaluateConstellationRanking(obj, useTeam)
            slot = obj.Slots(obj.SelectedSlot);
            rows = repmat(obj.emptyComparisonRow(), 0, 1);
            grade = obj.lookupCharacterGrade(slot.CharacterKey);
            if useTeam
                if grade == 4
                    baselineConstellation = 6;
                else
                    baselineConstellation = 0;
                end
            else
                baselineConstellation = 0;
            end

            baselineSlot = obj.applySignatureWeaponToSlot(slot);
            baselineSlot = obj.applyConstellationToSlot(baselineSlot, baselineConstellation);
            baselineWeapon = obj.getSignatureWeaponName(slot);
            if useTeam
                baselineSlots = obj.Slots;
                baselineSlots(obj.SelectedSlot) = baselineSlot;
                baselineSlots(obj.SelectedSlot).Enabled = true;
                [baselineTeam, ~, ~] = obj.simulateTeamForSlotCopies(baselineSlots);
                baselineDPS = baselineTeam.DPS;
            else
                baseline = obj.simulateSingleSlotCandidate(baselineSlot);
                baselineDPS = baseline.DPS;
            end

            for constellation = 0:6
                candidateSlot = obj.applySignatureWeaponToSlot(slot);
                candidateSlot = obj.applyConstellationToSlot(candidateSlot, constellation);

                row = obj.emptyComparisonRow();
                row.Character = string(slot.DisplayName);
                row.CharacterKey = string(slot.CharacterKey);
                row.Candidate = "C" + string(constellation);
                row.CandidateType = "Constellation";
                row.Weapon = string(candidateSlot.WeaponName);
                row.BaselineWeapon = baselineWeapon;
                row.ArtifactSet1 = string(candidateSlot.ArtifactSet1);
                row.ArtifactSet2 = string(candidateSlot.ArtifactSet2);
                row.ArtifactMode = string(obj.resolveArtifactMode(candidateSlot));
                row.Constellation = constellation;
                row.BaselineConstellation = baselineConstellation;
                row.BaselineDPS = baselineDPS;

                try
                    if useTeam
                        candidateSlots = obj.Slots;
                        candidateSlots(obj.SelectedSlot) = candidateSlot;
                        candidateSlots(obj.SelectedSlot).Enabled = true;
                        [teamResult, memberResults, slotIndices] = obj.simulateTeamForSlotCopies(candidateSlots);
                        [memberTotal, memberDPS] = obj.lookupSelectedMemberMetrics( ...
                            memberResults, slotIndices, teamResult.RotationDuration);
                        row.TotalDMG = teamResult.TotalDMG;
                        row.DPS = teamResult.DPS;
                        row.TeamTotalDMG = teamResult.TotalDMG;
                        row.TeamDPS = teamResult.DPS;
                        row.MemberTotalDMG = memberTotal;
                        row.MemberDPS = memberDPS;
                        row.MetricTotalDMG = teamResult.TotalDMG;
                        row.MetricDPS = teamResult.DPS;
                        row.ExpectedDMG = teamResult.TotalDMG;
                        row.ExpectedDPS = teamResult.DPS;
                        row.GainPct = obj.safePercentGain(teamResult.DPS, baselineDPS);
                    else
                        result = obj.simulateSingleSlotCandidate(candidateSlot);
                        row.TotalDMG = result.TotalDMG;
                        row.DPS = result.DPS;
                        row.MemberTotalDMG = result.TotalDMG;
                        row.MemberDPS = result.DPS;
                        row.MetricTotalDMG = result.TotalDMG;
                        row.MetricDPS = result.DPS;
                        row.ExpectedDMG = result.TotalDMG;
                        row.ExpectedDPS = result.DPS;
                        row.GainPct = obj.safePercentGain(result.DPS, baselineDPS);
                    end
                catch ME
                    row.Message = string(ME.message);
                end
                rows(end + 1) = row; %#ok<AGROW>
            end

            resultTable = obj.rankComparisonRows(rows, useTeam);
            if useTeam
                resultTable = sortrows(resultTable, 'Constellation', 'ascend');
            end
        end

        function result = simulateSingleSlotCandidate(obj, slot)
            memberCfg = obj.buildComparisonMemberConfig(obj.SelectedSlot, slot);
            result = simulateCharacterDPS(memberCfg, obj.buildEnemy());
        end

        function [teamResult, memberResults, slotIndices] = simulateTeamForSlotCopies(obj, slots)
            [members, slotIndices] = obj.buildEnabledMembersFromSlotCopies(slots);
            if isempty(members)
                error('Team comparison requires at least one enabled slot.');
            end

            teamSpec = struct( ...
                'Members', {members}, ...
                'RotationDuration', obj.TeamDurationField.Value, ...
                'SharedBuffs', struct());
            [teamResult, memberResults] = simulateTeamDPS(teamSpec, obj.buildEnemy());
        end

        function slot = applyArtifactCandidateToSlot(obj, slot, artifactSetId)
            slot.ArtifactSet1 = string(artifactSetId);
            slot.ArtifactSet1Pieces = 4;
            slot.ArtifactSet2 = "None";
            slot.ArtifactSet2Pieces = 0;
            slot.ArtifactSet4Active = 1;
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
        end

        function row = emptyComparisonRow(obj) %#ok<MANU>
            row = struct( ...
                'Rank', NaN, ...
                'Character', "", ...
                'CharacterKey', "", ...
                'Candidate', "", ...
                'CandidateType', "", ...
                'Weapon', "", ...
                'BaselineWeapon', "", ...
                'ArtifactSet1', "", ...
                'ArtifactSet2', "", ...
                'ArtifactMode', "", ...
                'Constellation', NaN, ...
                'BaselineConstellation', NaN, ...
                'TotalDMG', NaN, ...
                'DPS', NaN, ...
                'TeamTotalDMG', NaN, ...
                'TeamDPS', NaN, ...
                'MemberTotalDMG', NaN, ...
                'MemberDPS', NaN, ...
                'MetricTotalDMG', NaN, ...
                'MetricDPS', NaN, ...
                'ExpectedDMG', NaN, ...
                'ExpectedDPS', NaN, ...
                'BaselineDPS', NaN, ...
                'GainPct', NaN, ...
                'Message', "");
        end

        function resultTable = rankComparisonRows(obj, rows, keepDistributionOrder) %#ok<INUSL>
            if isempty(rows)
                resultTable = struct2table(repmat(obj.emptyComparisonRow(), 0, 1));
                return;
            end

            resultTable = struct2table(rows);
            valid = ~isnan(resultTable.MetricDPS);
            validTable = resultTable(valid, :);
            invalidTable = resultTable(~valid, :);
            if ~isempty(validTable)
                validTable = sortrows(validTable, 'MetricDPS', 'descend');
                validTable.Rank = (1:height(validTable)).';
            end
            if ~isempty(invalidTable)
                invalidTable.Rank = NaN(height(invalidTable), 1);
            end
            resultTable = [validTable; invalidTable];
            if keepDistributionOrder && ismember('Constellation', resultTable.Properties.VariableNames)
                rankByConstellation = resultTable(:, {'Constellation', 'Rank'});
                resultTable = sortrows(resultTable, 'Constellation', 'ascend');
                [~, loc] = ismember(resultTable.Constellation, rankByConstellation.Constellation);
                resultTable.Rank = rankByConstellation.Rank(loc);
            end
        end

        function [memberTotal, memberDPS] = lookupSelectedMemberMetrics(obj, memberResults, slotIndices, rotationDuration)
            memberTotal = NaN;
            memberDPS = NaN;
            idx = find(slotIndices == obj.SelectedSlot, 1, 'first');
            if isempty(idx) || isempty(memberResults) || numel(memberResults) < idx
                return;
            end
            memberTotal = memberResults(idx).TotalDMG;
            memberDPS = memberTotal / rotationDuration;
        end

        function gainPct = safePercentGain(obj, value, baseline) %#ok<INUSL>
            if isnan(value) || isnan(baseline) || baseline == 0
                gainPct = NaN;
            else
                gainPct = (value - baseline) ./ abs(baseline) .* 100;
            end
        end

        function grade = lookupCharacterGrade(obj, characterKey)
            grade = NaN;
            if isempty(obj.Registry) || ~isfield(obj.Registry, 'Grade')
                return;
            end
            idx = find(string({obj.Registry.Key}) == string(characterKey), 1, 'first');
            if ~isempty(idx)
                grade = obj.Registry(idx).Grade;
            end
        end

        function displayTable = displayComparisonTable(obj, resultTable) %#ok<INUSL>
            if isempty(resultTable) || height(resultTable) == 0
                displayTable = table();
                return;
            end

            displayTable = resultTable(:, {'Rank', 'Character', 'Candidate', 'ExpectedDMG', ...
                'ExpectedDPS', 'GainPct', 'BaselineWeapon', 'Weapon', 'ArtifactSet1', ...
                'Constellation', 'Message'});
            displayTable.Properties.VariableNames = {'排名', '角色', '候选方案', '期望总伤害', ...
                '期望DPS', '相对专武%', '基准武器', '候选武器', '圣遗物套装', '命座', '备注'};
        end

        function statusText = buildComparisonStatus(obj, resultTable, mode)
            if isempty(resultTable) || height(resultTable) == 0
                statusText = '无可展示结果。';
                return;
            end

            if string(mode) == "constellation_team_gain"
                bestRow = resultTable(find(~isnan(resultTable.MetricDPS), 1, 'first'), :);
                if isempty(bestRow)
                    statusText = sprintf('已完成 %d 条命座分布。', height(resultTable));
                    return;
                end
                statusText = sprintf('已完成 %d 条命座分布；最高为 C%d，队伍期望 DPS %.0f，相对基线 %+0.1f%%。', ...
                    height(resultTable), bestRow.Constellation, bestRow.MetricDPS, bestRow.GainPct);
                return;
            end

            bestIdx = find(resultTable.Rank == 1, 1, 'first');
            if isempty(bestIdx)
                statusText = sprintf('已完成 %d 个候选方案，无有效排名。', height(resultTable));
                return;
            end

            bestRow = resultTable(bestIdx, :);
            statusText = sprintf('已完成 %d 个候选方案；第 1 名：%s，期望 DPS %.0f，相对 %s %+0.1f%%。', ...
                height(resultTable), char(string(bestRow.Candidate)), bestRow.ExpectedDPS, ...
                char(string(bestRow.BaselineWeapon)), bestRow.GainPct);
        end

        function renderComparisonChart(obj, axesHandle, resultTable, mode)
            cla(axesHandle);
            if isempty(resultTable) || height(resultTable) == 0
                title(axesHandle, '暂无对比结果');
                xlabel(axesHandle, '候选方案');
                ylabel(axesHandle, '期望 DPS');
                grid(axesHandle, 'on');
                return;
            end

            topN = min(height(resultTable), round(obj.ComparisonLimitSpinner.Value));
            if string(mode) == "constellation_team_gain"
                chartTable = sortrows(resultTable, 'Constellation', 'ascend');
                labels = "C" + string(chartTable.Constellation);
                values = chartTable.MetricDPS;
                pctValues = chartTable.GainPct;
                chartTitle = sprintf('%s | %s', char(obj.comparisonModeTitle(mode)), char(obj.comparisonCharacterLabel()));
                yLabelText = '队伍期望 DPS';
            else
                chartTable = resultTable(1:topN, :);
                labels = string(chartTable.Candidate);
                values = chartTable.ExpectedDPS;
                pctValues = chartTable.GainPct;
                chartTitle = sprintf('%s | %s', char(obj.comparisonModeTitle(mode)), char(obj.comparisonCharacterLabel()));
                yLabelText = '期望 DPS';
            end

            x = 1:numel(values);
            bar(axesHandle, x, values, 'FaceColor', [0.35 0.63 0.76], 'EdgeColor', [0.24 0.46 0.60]);
            axesHandle.XTick = x;
            axesHandle.XTickLabel = cellstr(obj.shortenComparisonLabels(labels, 24));
            axesHandle.XTickLabelRotation = 35;
            xlabel(axesHandle, '候选方案');
            ylabel(axesHandle, yLabelText);
            title(axesHandle, chartTitle);
            grid(axesHandle, 'on');

            yMax = max(values, [], 'omitnan');
            if isempty(yMax) || isnan(yMax) || yMax <= 0
                yMax = 1;
            end
            ylim(axesHandle, [0, yMax * 1.18]);

            for i = 1:numel(values)
                if isnan(values(i))
                    continue;
                end
                text(axesHandle, x(i), values(i), sprintf('%.0f\n%+.1f%%', values(i), pctValues(i)), ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                    'FontSize', 8, 'Color', [0.20 0.24 0.30]);
            end
        end

        function labels = shortenComparisonLabels(obj, labels, limit) %#ok<INUSL>
            labels = string(labels);
            for i = 1:numel(labels)
                if strlength(labels(i)) > limit
                    labels(i) = extractBefore(labels(i), limit) + "...";
                end
            end
        end

        function applyBestComparisonCandidate(obj, mode)
            if nargin < 2 || isempty(mode)
                resultTable = obj.LastComparisonResults;
            else
                page = obj.getComparisonPage(mode);
                resultTable = table();
                if ~isempty(page)
                    resultTable = page.Table.UserData;
                end
                if isempty(resultTable)
                    resultTable = obj.LastComparisonResults;
                end
            end

            if isempty(resultTable) || height(resultTable) == 0
                uialert(obj.Figure, 'Run a comparison first.', 'No comparison result');
                return;
            end

            idx = find(resultTable.Rank == 1, 1, 'first');
            if isempty(idx)
                uialert(obj.Figure, 'No valid ranked candidate is available.', 'No valid candidate');
                return;
            end

            row = resultTable(idx, :);
            slot = obj.Slots(obj.SelectedSlot);
            switch char(string(row.CandidateType))
                case 'Weapon'
                    slot.WeaponName = string(row.Weapon);
                    slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
                case {'Artifact4pc'}
                    slot = obj.applyArtifactCandidateToSlot(slot, string(row.ArtifactSet1));
                case 'Constellation'
                    slot.Constellation = round(row.Constellation);
                otherwise
                    uialert(obj.Figure, 'This comparison result cannot be applied automatically.', 'Apply candidate');
                    return;
            end

            obj.Slots(obj.SelectedSlot) = slot;
            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
            obj.refreshTimelinePreview();
            obj.setStatus(sprintf('Applied ranked candidate: %s.', char(string(row.Candidate))));
        end

        function updateKpi(obj, totalDamage, dps, rotationTime)
            % 更新右侧 KPI 数字卡。
            obj.LastResultMetrics = struct( ...
                'HasResult', true, ...
                'TotalDamage', totalDamage, ...
                'DPS', dps, ...
                'RotationTime', rotationTime);
            obj.syncDashboard();
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

        function message = localBuildTeamStatus(obj, teamResult, slotCount) %#ok<INUSD>
            archetype = string(getFieldOrDefault(getFieldOrDefault(teamResult, 'ArchetypeInfo', struct()), ...
                'PrimaryArchetype', ""));
            secondary = string(getFieldOrDefault(getFieldOrDefault(teamResult, 'ArchetypeInfo', struct()), ...
                'SecondaryArchetype', ""));
            if strlength(secondary) > 0
                archetype = archetype + "/" + secondary;
            end

            if strlength(archetype) == 0
                archetype = "Unknown";
            end

            canLoop = logical(getFieldOrDefault(teamResult, 'CanLoopNextCycle', false));
            readiness = double(getFieldOrDefault(teamResult, 'LoopReadiness', 0));
            timelineSummary = getFieldOrDefault(teamResult, 'TimelineSummary', struct());
            overlapTime = double(getFieldOrDefault(timelineSummary, 'OverlapTime', 0));
            idleTime = double(getFieldOrDefault(timelineSummary, 'IdleTime', 0));
            warnings = string(getFieldOrDefault(teamResult, 'PlanningWarnings', strings(0, 1)));

            message = sprintf('Team simulation done: %s | Slots %d | Loop %s | Readiness %.2f | Overlap %.2fs | Idle %.2fs', ...
                char(archetype), slotCount, obj.localOnOff(canLoop), readiness, overlapTime, idleTime);
            if ~isempty(warnings)
                message = sprintf('%s | Warnings %d | %s', ...
                    message, numel(warnings), char(warnings(1)));
            end
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
            obj.LastSimulationMode = "预览";
            obj.LastResultMetrics.HasResult = false;
            obj.setStatus('已刷新输出轴预览。');
        end

        function setStatus(obj, message)
            obj.LastStatusMessage = string(message);
            obj.StatusLabel.Text = obj.shortenText(message, 48);
            obj.StatusLabel.Tooltip = char(message);
            obj.syncDashboard();
        end

        function showSimulationError(obj, ME)
            obj.LastResultMetrics = struct( ...
                'HasResult', false, ...
                'TotalDamage', NaN, ...
                'DPS', NaN, ...
                'RotationTime', NaN);
            obj.setStatus('模拟失败，请检查输入。');
            detail = obj.buildSimulationErrorDialog(ME);
            uialert(obj.Figure, detail, '模拟失败', 'Icon', 'error');
        end

        function showTeamPlanningNotice(obj, teamResult)
            warnings = string(getFieldOrDefault(teamResult, 'PlanningWarnings', strings(0, 1)));
            selectionMode = string(getFieldOrDefault(getFieldOrDefault(teamResult, 'PlannedRotation', struct()), 'SelectionMode', ""));
            selectionSummary = string(getFieldOrDefault(getFieldOrDefault(teamResult, 'PlannedRotation', struct()), 'SelectionSummary', ""));
            candidateCount = double(getFieldOrDefault(getFieldOrDefault(teamResult, 'PlannedRotation', struct()), 'CandidateCount', 0));

            if ~isempty(warnings)
                warningText = strtrim(warnings);
                structuralMask = ~startsWith(warningText, "Loop energy missing:", 'IgnoreCase', true);
                warnings = warnings(structuralMask);
            end

            if isempty(warnings)
                return;
            end

            detailLines = strings(0, 1);
            if strlength(selectionMode) > 0
                detailLines(end + 1, 1) = sprintf('自动排轴已启用团队候选评分。当前方案：%s', char(selectionMode)); %#ok<AGROW>
            end
            if candidateCount > 0
                detailLines(end + 1, 1) = sprintf('已评估候选方案数量：%d', candidateCount); %#ok<AGROW>
            end
            if strlength(selectionSummary) > 0
                detailLines(end + 1, 1) = sprintf('方案摘要：%s', char(selectionSummary)); %#ok<AGROW>
            end
            if ~isempty(warnings)
                detailLines(end + 1, 1) = "本次模拟仍存在以下可读警告："; %#ok<AGROW>
                for i = 1:min(numel(warnings), 6)
                    detailLines(end + 1, 1) = "- " + warnings(i); %#ok<AGROW>
                end
            end

            uialert(obj.Figure, char(join(detailLines, newline)), '团队排轴提示', 'Icon', 'info');
        end

        function detail = buildSimulationErrorDialog(obj, ME)
            summary = string(ME.message);
            if strlength(summary) == 0
                summary = "未返回具体错误信息。";
            end

            location = "未知位置";
            if ~isempty(ME.stack)
                location = sprintf('%s (line %d)', ME.stack(1).name, ME.stack(1).line);
            end

            hints = obj.buildSimulationErrorHints(ME);
            hintText = join("- " + hints(:), newline);
            detail = sprintf(['错误摘要：%s\n\n' ...
                '发生位置：%s\n\n' ...
                '模拟时常见可能原因：\n%s\n\n' ...
                '建议：先恢复默认轮转/默认构筑后重试；若队伍含 Furina，请优先检查组队轮转与起手顺序。'], ...
                char(summary), char(location), char(hintText));
        end

        function hints = buildSimulationErrorHints(obj, ME)
            %#ok<INUSD>
            hints = [ ...
                "轮转文本包含未知 token、空行格式异常，或角色切换后仍保留了旧角色轮转"; ...
                "构筑表中存在空值、非数值字段，或武器/圣遗物/精炼配置与当前角色不匹配"; ...
                "队伍自动排轴、时间线、能量循环或元素附着推导失败"; ...
                "角色专用脚本暂未覆盖当前命座/天赋/动作组合" ...
            ];

            enabledNames = strings(0, 1);
            if ~isempty(obj.Slots)
                enabledNames = string({obj.Slots([obj.Slots.Enabled]).CharacterKey}).';
            end
            loweredMessage = lower(char(string(ME.message)));
            if any(strcmpi(enabledNames, 'Furina')) || contains(loweredMessage, 'furina')
                hints(end + 1, 1) = "Furina 组队会额外推导共享增伤与队伍时间线；如果报错，常见触发点是组队轮转、队友起手顺序或临时轮转文件异常";
            end
            if contains(loweredMessage, 'rotation') || contains(loweredMessage, 'token')
                hints(end + 1, 1) = "当前报错已经命中轮转/动作解析链路，请优先检查轮转文本是否仍适配当前角色";
            end
            if contains(loweredMessage, 'artifact') || contains(loweredMessage, 'weapon') || contains(loweredMessage, 'build')
                hints(end + 1, 1) = "当前报错已经命中构筑链路，请优先检查 build 表格和武器、圣遗物下拉项";
            end
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
            slot.ArtifactSet1 = string(getFieldOrDefault(slot.Build, 'ArtifactSet1', slot.ArtifactSet1));
            slot.ArtifactSet1Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet1Pieces', slot.ArtifactSet1Pieces);
            slot.ArtifactSet2 = string(getFieldOrDefault(slot.Build, 'ArtifactSet2', slot.ArtifactSet2));
            slot.ArtifactSet2Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet2Pieces', slot.ArtifactSet2Pieces);
            slot.ArtifactSet4Active = getFieldOrDefault(slot.Build, 'ArtifactSet4Active', slot.ArtifactSet4Active);
            slot.WeaponList = listWeaponsForCharacter(slot.CharacterKey);
            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
            obj.Slots(slotIndex) = slot;
            obj.refreshSlotCard(slotIndex);
            if obj.SelectedSlot == slotIndex
                obj.refreshEditorForSelectedSlot();
            end
        end

        function onSlotArtifactSetChanged(obj, slotIndex, artifactSetId)
            % 更换当前角色套装。
            obj.saveSelectedSlotState();
            slot = obj.Slots(slotIndex);
            slot.ArtifactSet1 = string(artifactSetId);
            slot = obj.applyArtifactModeToSlot(slot, '4pc');
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
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

        function onSelectedWeaponChanged(obj, weaponName)
            % 中间编辑区武器下拉回写。
            slot = obj.Slots(obj.SelectedSlot);
            slot.WeaponName = string(weaponName);
            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            obj.Slots(obj.SelectedSlot) = slot;
            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
        end

        function onSlotConstellationChanged(obj, slotIndex, value)
            % 命座修改回写。
            obj.Slots(slotIndex).Constellation = round(value);
            if obj.SelectedSlot == slotIndex
                obj.refreshEditorForSelectedSlot();
            end
        end

        function onSelectedConstellationChanged(obj, value)
            obj.Slots(obj.SelectedSlot).Constellation = round(value);
            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
        end

        function onSlotTalentChanged(obj, slotIndex, value)
            % 天赋等级修改回写。
            obj.Slots(slotIndex).TalentLevel = round(value);
            if obj.SelectedSlot == slotIndex
                obj.refreshEditorForSelectedSlot();
            end
        end

        function onSelectedTalentChanged(obj, value)
            obj.Slots(obj.SelectedSlot).TalentLevel = round(value);
            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
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

        function onSelectedRefinementChanged(obj, value)
            slot = obj.Slots(obj.SelectedSlot);
            slot.WeaponRefinement = round(value);
            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            obj.Slots(obj.SelectedSlot) = slot;
            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
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
            slot.Build = materializeArtifactPieceModel(slot.CharacterKey, slot.Build, struct());
            slot.WeaponName = string(getFieldOrDefault(slot.Build, 'Weapon', slot.WeaponName));
            slot.WeaponRefinement = max(1, min(5, getFieldOrDefault(slot.Build, 'WeaponRefinement', slot.WeaponRefinement)));
            slot.ArtifactSet1 = string(getFieldOrDefault(slot.Build, 'ArtifactSet1', slot.ArtifactSet1));
            slot.ArtifactSet1Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet1Pieces', slot.ArtifactSet1Pieces);
            slot.ArtifactSet2 = string(getFieldOrDefault(slot.Build, 'ArtifactSet2', slot.ArtifactSet2));
            slot.ArtifactSet2Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet2Pieces', slot.ArtifactSet2Pieces);
            slot.ArtifactSet4Active = getFieldOrDefault(slot.Build, 'ArtifactSet4Active', slot.ArtifactSet4Active);
            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
            obj.Slots(obj.SelectedSlot) = slot;

            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
        end

        function onRotationTextEdited(obj)
            % 用户编辑轮转文本后的回写逻辑。
            slot = obj.Slots(obj.SelectedSlot);
            slot.RotationText = obj.getRotationTextValue();
            slot.RotationEdited = obj.isCustomRotationText(slot.CharacterKey, slot.RotationText);
            obj.Slots(obj.SelectedSlot) = slot;
            obj.refreshTimelinePreview();
        end

        function onRestoreDefaultRotation(obj)
            % 恢复当前角色默认轮转文本。
            slot = obj.Slots(obj.SelectedSlot);
            slot.RotationText = getCharacterDefaultRotationText(slot.CharacterKey);
            slot.RotationEdited = false;
            obj.Slots(obj.SelectedSlot) = slot;
            obj.RotationTextArea.Value = obj.rotationStringToTextAreaValue(slot.RotationText);
            obj.refreshTimelinePreview();
        end

        function onSelectedArtifactSetChanged(obj, setId)
            % 中间编辑区的套装选择回写。
            slot = obj.Slots(obj.SelectedSlot);
            slot.ArtifactSet1 = string(setId);
            slot = obj.applyArtifactModeToSlot(slot, '4pc');
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
            obj.Slots(obj.SelectedSlot) = slot;
            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
        end

        function slot = applyArtifactModeToSlot(obj, slot, modeValue) %#ok<MANU>
            % 按 GUI 模式将件数分配回槽位状态。
            if string(slot.ArtifactSet1) == "None"
                slot.ArtifactSet1Pieces = 0;
                slot.ArtifactSet2 = "None";
                slot.ArtifactSet2Pieces = 0;
                slot.ArtifactSet4Active = 0;
                return;
            end

            switch char(string(modeValue))
                case '4pc'
                    slot.ArtifactSet1Pieces = 4;
                    slot.ArtifactSet2 = "None";
                    slot.ArtifactSet2Pieces = 0;
                    slot.ArtifactSet4Active = 1;
                case '2p2p'
                    slot.ArtifactSet1Pieces = 2;
                    if slot.ArtifactSet2 == "None"
                        slot.ArtifactSet2 = obj.resolveDefaultArtifactSet2(slot);
                    end
                    slot.ArtifactSet2Pieces = 2;
                    slot.ArtifactSet4Active = 0;
                case '2pc'
                    slot.ArtifactSet1Pieces = 2;
                    slot.ArtifactSet2 = "None";
                    slot.ArtifactSet2Pieces = 0;
                    slot.ArtifactSet4Active = 0;
                otherwise
                    slot.ArtifactSet1Pieces = 0;
                    slot.ArtifactSet2 = "None";
                    slot.ArtifactSet2Pieces = 0;
                    slot.ArtifactSet4Active = 0;
            end
        end

        function setId = resolveDefaultArtifactSet2(obj, slot) %#ok<MANU>
            % 为 2+2 混搭模式选择默认第二套。
            primarySet = string(slot.ArtifactSet1);
            element = string(getCharacterElement(slot.CharacterKey));

            if any(primarySet == ["GoldenTroupe", "MarechausseeHunter", "FragmentOfHarmonicWhimsy", "ObsidianCodex"])
                switch lower(char(element))
                    case 'pyro'
                        setId = "Pyro15";
                    case 'hydro'
                        setId = "Hydro15";
                    case 'cryo'
                        setId = "Cryo15";
                    case 'electro'
                        setId = "Electro15";
                    case 'anemo'
                        setId = "Anemo15";
                    case 'geo'
                        setId = "Geo15";
                    case 'dendro'
                        setId = "Dendro15";
                    otherwise
                        setId = "ATK18";
                end
            elseif primarySet == "HuskOfOpulentDreams"
                setId = "Geo15";
            elseif primarySet == "DeepwoodMemories"
                setId = "EM80";
            else
                setId = "ATK18";
            end
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

        function text = shortenText(obj, value, limit) %#ok<INUSD>
            if nargin < 3
                limit = 48;
            end

            textValue = string(value);
            if strlength(textValue) > limit
                textValue = extractBefore(textValue, limit) + "...";
            end
            text = char(textValue);
        end
    end
end
