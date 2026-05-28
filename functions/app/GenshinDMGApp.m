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
        SlotWeaponBadges
        SlotArtifactBadges
        SlotFooters

        SelectedSlotLabel
        SelectedPortrait
        SelectedSummaryText
        SelectedWeaponBadge
        SelectedArtifactBadge
        ArtifactSetDropdown
        ArtifactSet2Dropdown
        ArtifactModeDropdown
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
        TeamHTML
        EditorHTML
        DashboardHTML
        LastStatusMessage
        LastResultMetrics

        RunSingleButton
        RunTeamButton
        ResetSlotButton
        RefreshTimelineButton

        TotalDamageValueLabel
        TeamDPSValueLabel
        RotationValueLabel

        SummaryTable
        EnergyTable
        BreakdownTable
        EffectsTable
        TimelineAxes
        BarAxes
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
            if nargin >= 2 && ~isempty(mode)
                obj.setComparisonMode(mode);
            end
            obj.runComparisonAnalysis();
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
                'StartTime', 0, ...
                'Enabled', true, ...
                'PortraitPath', "", ...
                'WeaponBadgePath', "", ...
                'ArtifactBadgePath', "");
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

            teamRootGrid = uigridlayout(teamPanel, [1 1]);
            teamRootGrid.RowHeight = {'1x'};
            teamRootGrid.ColumnWidth = {'1x'};
            teamRootGrid.Padding = [8 8 8 8];

            teamTabs = uitabgroup(teamRootGrid);
            teamTabs.Layout.Row = 1;
            teamTabs.Layout.Column = 1;
            overviewTab = uitab(teamTabs, 'Title', 'HTML 队伍');
            configTab = uitab(teamTabs, 'Title', '配置控件');
            teamTabs.SelectedTab = overviewTab;

            overviewGrid = uigridlayout(overviewTab, [1 1]);
            overviewGrid.RowHeight = {'1x'};
            overviewGrid.ColumnWidth = {'1x'};
            overviewGrid.Padding = [0 0 0 0];

            obj.TeamHTML = uihtml(overviewGrid, ...
                'HTMLSource', obj.buildUiHtmlSource('team'), ...
                'Tooltip', '队伍概览');
            obj.TeamHTML.Layout.Row = 1;
            obj.TeamHTML.Layout.Column = 1;
            obj.TeamHTML.HTMLEventReceivedFcn = @(~, event) obj.onHtmlEvent(event);
            obj.TeamHTML.Data = obj.buildAppShellData();

            teamGrid = uigridlayout(configTab, [5 1]);
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
            obj.SlotArtifactDropdowns = cell(1, slotCount);
            obj.SlotConstellationSpinners = cell(1, slotCount);
            obj.SlotTalentSpinners = cell(1, slotCount);
            obj.SlotRefinementSpinners = cell(1, slotCount);
            obj.SlotStartTimeFields = cell(1, slotCount);
            obj.SlotEnableCheckboxes = cell(1, slotCount);
            obj.SlotEditButtons = cell(1, slotCount);
            obj.SlotPortraits = cell(1, slotCount);
            obj.SlotWeaponBadges = cell(1, slotCount);
            obj.SlotArtifactBadges = cell(1, slotCount);
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
                slotGrid.ColumnWidth = {96, 52, '1x', 92};
                slotGrid.RowHeight = {24, 28, 52, 28, 28, 48, 22};
                slotGrid.ColumnSpacing = 8;
                slotGrid.RowSpacing = 6;
                slotGrid.Padding = [10 10 10 10];
                slotGrid.BackgroundColor = [1.00 1.00 1.00];

                avatar = uiimage(slotGrid, 'ScaleMethod', 'fill');
                avatar.Layout.Row = [1 7];
                avatar.Layout.Column = 1;
                obj.SlotPortraits{i} = avatar;

                artifactBadge = uiimage(slotGrid, 'ScaleMethod', 'fit');
                artifactBadge.Layout.Row = 3;
                artifactBadge.Layout.Column = 2;
                obj.SlotArtifactBadges{i} = artifactBadge;

                weaponBadge = uiimage(slotGrid, 'ScaleMethod', 'fit');
                weaponBadge.Layout.Row = 4;
                weaponBadge.Layout.Column = 2;
                obj.SlotWeaponBadges{i} = weaponBadge;

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
                    'ButtonPushedFcn', @(~, ~) obj.selectSlot(i));
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

                artifactDropdown = uidropdown(slotGrid, ...
                    'Items', artifactLabels, ...
                    'ItemsData', artifactIds, ...
                    'ValueChangedFcn', @(src, ~) obj.onSlotArtifactSetChanged(i, src.Value));
                artifactDropdown.Layout.Row = 3;
                artifactDropdown.Layout.Column = [3 4];
                obj.SlotArtifactDropdowns{i} = artifactDropdown;

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
            editorGrid.RowHeight = {34, 340, '1x', 240};
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

            editorTabs = uitabgroup(editorGrid);
            editorTabs.Layout.Row = 2;
            editorTabs.Layout.Column = 1;
            editorOverviewTab = uitab(editorTabs, 'Title', 'HTML 概览');
            editorConfigTab = uitab(editorTabs, 'Title', '配置控件');
            editorTabs.SelectedTab = editorOverviewTab;

            editorOverviewGrid = uigridlayout(editorOverviewTab, [1 1]);
            editorOverviewGrid.RowHeight = {'1x'};
            editorOverviewGrid.ColumnWidth = {'1x'};
            editorOverviewGrid.Padding = [0 0 0 0];

            obj.EditorHTML = uihtml(editorOverviewGrid, ...
                'HTMLSource', obj.buildUiHtmlSource('editor'), ...
                'Tooltip', '当前构筑概览');
            obj.EditorHTML.Layout.Row = 1;
            obj.EditorHTML.Layout.Column = 1;
            obj.EditorHTML.HTMLEventReceivedFcn = @(~, event) obj.onHtmlEvent(event);
            obj.EditorHTML.Data = obj.buildAppShellData();

            editorConfigGrid = uigridlayout(editorConfigTab, [1 1]);
            editorConfigGrid.RowHeight = {'1x'};
            editorConfigGrid.ColumnWidth = {'1x'};
            editorConfigGrid.Padding = [0 0 0 0];

            heroCard = uipanel(editorConfigGrid, ...
                'Title', '角色概览', ...
                'BackgroundColor', [0.96 0.97 0.99], ...
                'ForegroundColor', [0.28 0.34 0.44]);
            heroCard.Layout.Row = 1;
            heroCard.Layout.Column = 1;

            heroGrid = uigridlayout(heroCard, [3 2]);
            heroGrid.ColumnWidth = {180, '1x'};
            heroGrid.RowHeight = {132, 90, '1x'};
            heroGrid.ColumnSpacing = 14;
            heroGrid.Padding = [10 10 10 10];
            heroGrid.BackgroundColor = [0.96 0.97 0.99];

            obj.SelectedPortrait = uiimage(heroGrid, 'ScaleMethod', 'fit');
            obj.SelectedPortrait.Layout.Row = [1 3];
            obj.SelectedPortrait.Layout.Column = 1;

            badgeGrid = uigridlayout(heroGrid, [2 3]);
            badgeGrid.Layout.Row = 1;
            badgeGrid.Layout.Column = 2;
            badgeGrid.RowHeight = {20, '1x'};
            badgeGrid.ColumnWidth = {120, 120, '1x'};
            badgeGrid.ColumnSpacing = 8;
            badgeGrid.RowSpacing = 4;
            badgeGrid.Padding = [0 0 0 0];
            badgeGrid.BackgroundColor = [0.96 0.97 0.99];

            artifactLabel = uilabel(badgeGrid, 'Text', '圣遗物套装', 'FontWeight', 'bold', 'FontColor', [0.18 0.24 0.34]);
            artifactLabel.Layout.Row = 1;
            artifactLabel.Layout.Column = 1;

            weaponLabel = uilabel(badgeGrid, 'Text', '武器', 'FontWeight', 'bold', 'FontColor', [0.18 0.24 0.34]);
            weaponLabel.Layout.Row = 1;
            weaponLabel.Layout.Column = 2;

            obj.SelectedArtifactBadge = uiimage(badgeGrid, 'ScaleMethod', 'fit');
            obj.SelectedArtifactBadge.Layout.Row = 2;
            obj.SelectedArtifactBadge.Layout.Column = 1;

            obj.SelectedWeaponBadge = uiimage(badgeGrid, 'ScaleMethod', 'fit');
            obj.SelectedWeaponBadge.Layout.Row = 2;
            obj.SelectedWeaponBadge.Layout.Column = 2;

            artifactCtrlGrid = uigridlayout(badgeGrid, [3 1]);
            artifactCtrlGrid.Layout.Row = [1 2];
            artifactCtrlGrid.Layout.Column = 3;
            artifactCtrlGrid.RowHeight = {28, 28, 28};
            artifactCtrlGrid.ColumnWidth = {'1x'};
            artifactCtrlGrid.RowSpacing = 6;
            artifactCtrlGrid.Padding = [0 0 0 0];
            artifactCtrlGrid.BackgroundColor = [0.96 0.97 0.99];

            [artifactLabels, artifactIds] = getArtifactSetChoices();
            obj.ArtifactSetDropdown = uidropdown(artifactCtrlGrid, ...
                'Items', artifactLabels, ...
                'ItemsData', artifactIds, ...
                'ValueChangedFcn', @(src, ~) obj.onSelectedArtifactSetChanged(src.Value));
            obj.ArtifactSetDropdown.Layout.Row = 1;
            obj.ArtifactSetDropdown.Layout.Column = 1;
            obj.ArtifactSet2Dropdown = uidropdown(artifactCtrlGrid, ...
                'Items', artifactLabels, ...
                'ItemsData', artifactIds, ...
                'ValueChangedFcn', @(src, ~) obj.onSelectedArtifactSet2Changed(src.Value));
            obj.ArtifactSet2Dropdown.Layout.Row = 2;
            obj.ArtifactSet2Dropdown.Layout.Column = 1;

            obj.ArtifactModeDropdown = uidropdown(artifactCtrlGrid, ...
                'Items', {'4件套', '2+2 混搭', '2件套', '无套装'}, ...
                'ItemsData', {'4pc', '2p2p', '2pc', '0pc'}, ...
                'ValueChangedFcn', @(src, ~) obj.onSelectedArtifactModeChanged(src.Value));
            obj.ArtifactModeDropdown.Layout.Row = 3;
            obj.ArtifactModeDropdown.Layout.Column = 1;

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
            % 右侧结果与图表区域。
            resultPanel = uipanel(parent, ...
                'Title', '计算结果与可视化', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.99 0.99 1.00], ...
                'ForegroundColor', [0.18 0.23 0.33]);
            resultPanel.Layout.Row = 1;
            resultPanel.Layout.Column = 3;

            resultGrid = uigridlayout(resultPanel, [3 1]);
            resultGrid.RowHeight = {156, 230, '1x'};
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

            dashboardPath = obj.resolveDashboardHtmlSource();
            obj.DashboardHTML = uihtml(resultGrid, ...
                'HTMLSource', dashboardPath, ...
                'Tooltip', '伤害仪表盘');
            obj.DashboardHTML.Layout.Row = 2;
            obj.DashboardHTML.Layout.Column = 1;
            obj.DashboardHTML.HTMLEventReceivedFcn = @(~, event) obj.onHtmlEvent(event);
            obj.DashboardHTML.Data = obj.buildAppShellData();

            tabs = uitabgroup(resultGrid);
            tabs.Layout.Row = 3;
            tabs.Layout.Column = 1;

            summaryTab = uitab(tabs, 'Title', '成员汇总');
            energyTab = uitab(tabs, 'Title', '能量恢复过程');
            breakdownTab = uitab(tabs, 'Title', '伤害明细');
            effectsTab = uitab(tabs, 'Title', '持续效果');
            timelineTab = uitab(tabs, 'Title', '输出轴');
            chartTab = uitab(tabs, 'Title', '成员对比');

            comparisonTab = uitab(tabs, 'Title', '对比分析');

            obj.SummaryTable = uitable(summaryTab, ...
                'Position', [8 8 760 560], ...
                'RowName', {});

            obj.EnergyTable = uitable(energyTab, ...
                'Position', [8 8 760 560], ...
                'RowName', {});

            obj.BreakdownTable = uitable(breakdownTab, ...
                'Position', [8 8 760 560], ...
                'RowName', {});

            obj.EffectsTable = uitable(effectsTab, ...
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

            obj.createComparisonTab(comparisonTab);
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

        function createComparisonTab(obj, parent)
            compareGrid = uigridlayout(parent, [2 1]);
            compareGrid.RowHeight = {58, '1x'};
            compareGrid.ColumnWidth = {'1x'};
            compareGrid.RowSpacing = 8;
            compareGrid.Padding = [8 8 8 8];

            controlPanel = uipanel(compareGrid, ...
                'Title', '对比设置', ...
                'BackgroundColor', [0.96 0.97 0.99], ...
                'ForegroundColor', [0.28 0.34 0.44]);
            controlPanel.Layout.Row = 1;
            controlPanel.Layout.Column = 1;

            controlGrid = uigridlayout(controlPanel, [1 6]);
            controlGrid.RowHeight = {30};
            controlGrid.ColumnWidth = {64, 78, 132, 92, 92, '1x'};
            controlGrid.ColumnSpacing = 8;
            controlGrid.Padding = [8 6 8 6];
            controlGrid.BackgroundColor = [0.96 0.97 0.99];

            modeLabel = uilabel(controlGrid, 'Text', 'Top N', 'FontColor', [0.30 0.34 0.42]);
            modeLabel.Layout.Row = 1;
            modeLabel.Layout.Column = 1;

            obj.ComparisonLimitSpinner = uispinner(controlGrid, ...
                'Limits', [3 80], ...
                'RoundFractionalValues', 'on', ...
                'Step', 1, ...
                'Value', 20);
            obj.ComparisonLimitSpinner.Layout.Row = 1;
            obj.ComparisonLimitSpinner.Layout.Column = 2;

            obj.ComparisonImplementedOnlyCheckbox = uicheckbox(controlGrid, ...
                'Text', '仅已建模套装', ...
                'Value', true);
            obj.ComparisonImplementedOnlyCheckbox.Layout.Row = 1;
            obj.ComparisonImplementedOnlyCheckbox.Layout.Column = 3;

            obj.ComparisonStatusLabel = uilabel(controlGrid, ...
                'Text', '每个对比功能已拆分到下方独立标签页；百分比基准为该角色专武。', ...
                'FontSize', 12, ...
                'FontColor', [0.36 0.39 0.47]);
            obj.ComparisonStatusLabel.Layout.Row = 1;
            obj.ComparisonStatusLabel.Layout.Column = [4 6];

            obj.ComparisonTabGroup = uitabgroup(compareGrid, ...
                'SelectionChangedFcn', @(~, event) obj.setComparisonMode(event.NewValue.UserData));
            obj.ComparisonTabGroup.Layout.Row = 2;
            obj.ComparisonTabGroup.Layout.Column = 1;

            obj.ComparisonPages = struct();
            obj.ComparisonPages.weapon_single = obj.createComparisonPage( ...
                obj.ComparisonTabGroup, 'weapon_single', '武器排名', ...
                '当前角色分别装备同类型武器时的期望伤害排名。');
            obj.ComparisonPages.artifact_single = obj.createComparisonPage( ...
                obj.ComparisonTabGroup, 'artifact_single', '圣遗物排名', ...
                '当前角色分别装备各 4 件套时的期望伤害排名。');
            obj.ComparisonPages.artifact_team = obj.createComparisonPage( ...
                obj.ComparisonTabGroup, 'artifact_team', '圣遗物进队', ...
                '当前角色更换 4 件套后，在当前启用队伍中的总伤害排名。');
            obj.ComparisonPages.artifact_constellation = obj.createComparisonPage( ...
                obj.ComparisonTabGroup, 'artifact_constellation', '套装命座', ...
                '当前角色在同一套圣遗物下 C0-C6 的期望伤害排名。');
            obj.ComparisonPages.constellation_team_gain = obj.createComparisonPage( ...
                obj.ComparisonTabGroup, 'constellation_team_gain', '命座团队提升', ...
                '当前角色 C0-C6 对当前启用队伍总伤害的提升分布。');

            obj.setComparisonMode('weapon_single');
        end

        function page = createComparisonPage(obj, parent, mode, titleText, description)
            tab = uitab(parent, 'Title', titleText);
            tab.UserData = char(string(mode));

            pageGrid = uigridlayout(tab, [4 1]);
            pageGrid.RowHeight = {36, 28, 34, '1x'};
            pageGrid.ColumnWidth = {'1x'};
            pageGrid.RowSpacing = 8;
            pageGrid.Padding = [8 8 8 8];

            header = uilabel(pageGrid, ...
                'Text', description, ...
                'FontSize', 12, ...
                'FontWeight', 'bold', ...
                'FontColor', [0.18 0.23 0.33]);
            header.Layout.Row = 1;
            header.Layout.Column = 1;

            roleLabel = uilabel(pageGrid, ...
                'Text', '角色：--', ...
                'FontWeight', 'bold', ...
                'FontColor', [0.24 0.29 0.38]);
            roleLabel.Layout.Row = 2;
            roleLabel.Layout.Column = 1;

            actionGrid = uigridlayout(pageGrid, [1 3]);
            actionGrid.Layout.Row = 3;
            actionGrid.Layout.Column = 1;
            actionGrid.ColumnWidth = {104, 118, '1x'};
            actionGrid.RowHeight = {'1x'};
            actionGrid.ColumnSpacing = 8;
            actionGrid.Padding = [0 0 0 0];

            runButton = uibutton(actionGrid, 'push', ...
                'Text', '运行本页', ...
                'BackgroundColor', [0.46 0.70 0.82], ...
                'FontColor', [0.08 0.12 0.16], ...
                'ButtonPushedFcn', @(~, ~) obj.runComparisonAnalysis(mode));
            runButton.Layout.Row = 1;
            runButton.Layout.Column = 1;

            applyButton = uibutton(actionGrid, 'push', ...
                'Text', '应用第 1 名', ...
                'ButtonPushedFcn', @(~, ~) obj.applyBestComparisonCandidate(mode));
            applyButton.Layout.Row = 1;
            applyButton.Layout.Column = 2;

            statusLabel = uilabel(actionGrid, ...
                'Text', '等待计算。', ...
                'FontColor', [0.36 0.39 0.47]);
            statusLabel.Layout.Row = 1;
            statusLabel.Layout.Column = 3;

            contentGrid = uigridlayout(pageGrid, [1 2]);
            contentGrid.Layout.Row = 4;
            contentGrid.Layout.Column = 1;
            contentGrid.ColumnWidth = {'1.15x', '1x'};
            contentGrid.RowHeight = {'1x'};
            contentGrid.ColumnSpacing = 8;
            contentGrid.Padding = [0 0 0 0];

            resultTable = uitable(contentGrid, 'RowName', {});
            resultTable.Layout.Row = 1;
            resultTable.Layout.Column = 1;

            resultAxes = uiaxes(contentGrid);
            resultAxes.Layout.Row = 1;
            resultAxes.Layout.Column = 2;
            title(resultAxes, titleText);
            ylabel(resultAxes, '期望伤害');
            grid(resultAxes, 'on');

            page = struct( ...
                'Mode', string(mode), ...
                'Tab', tab, ...
                'Table', resultTable, ...
                'Axes', resultAxes, ...
                'HeaderLabel', header, ...
                'RoleLabel', roleLabel, ...
                'StatusLabel', statusLabel, ...
                'RunButton', runButton, ...
                'ApplyBestButton', applyButton);
        end

        function data = buildDashboardData(obj)
            slot = obj.Slots(obj.SelectedSlot);
            activeCount = nnz([obj.Slots.Enabled]);
            totalSlots = numel(obj.Slots);

            hasResult = false;
            totalDamageValue = '--';
            dpsValue = '--';
            rotationValue = '--';
            totalDamageNote = '尚未运行';
            dpsNote = sprintf('%d/%d 启用', activeCount, totalSlots);
            rotationNote = sprintf('起始 %.1f s', slot.StartTime);

            if isstruct(obj.LastResultMetrics) ...
                    && isfield(obj.LastResultMetrics, 'HasResult') ...
                    && logical(obj.LastResultMetrics.HasResult)
                hasResult = true;
                totalDamageValue = obj.formatLargeNumber(obj.LastResultMetrics.TotalDamage);
                dpsValue = obj.formatLargeNumber(obj.LastResultMetrics.DPS);
                rotationValue = sprintf('%.2f s', obj.LastResultMetrics.RotationTime);
                totalDamageNote = char(obj.LastSimulationMode);
            end

            statusMessage = string(obj.LastStatusMessage);
            if strlength(strtrim(statusMessage)) == 0
                statusMessage = "等待模拟。";
            end
            statusTone = obj.classifyStatusTone(statusMessage, hasResult);

            data = struct( ...
                'headline', '伤害仪表盘', ...
                'subtitle', char(statusMessage), ...
                'statusTone', char(statusTone), ...
                'statusLabel', char(obj.statusToneLabel(statusTone)), ...
                'totalDamageValue', totalDamageValue, ...
                'totalDamageNote', totalDamageNote, ...
                'dpsValue', dpsValue, ...
                'dpsNote', dpsNote, ...
                'rotationValue', rotationValue, ...
                'rotationNote', rotationNote, ...
                'slotValue', sprintf('槽位 %d', obj.SelectedSlot), ...
                'slotNote', sprintf('R%d · %.1f s · %s', slot.WeaponRefinement, slot.StartTime, char(obj.localOnOff(slot.Enabled))), ...
                'characterName', char(slot.DisplayName), ...
                'weaponName', char(slot.WeaponName), ...
                'artifactName', sprintf('%s · %s', char(slot.ArtifactSet1), char(obj.resolveArtifactModeLabel(slot))), ...
                'presetName', char(obj.lookupPresetLabel(slot)), ...
                'talentSummary', sprintf('C%d · Lv.%d · R%d', slot.Constellation, slot.TalentLevel, slot.WeaponRefinement), ...
                'modeSummary', sprintf('%s · %d/%d 启用', char(obj.LastSimulationMode), activeCount, totalSlots));
        end

        function data = buildAppShellData(obj)
            dashboard = obj.buildDashboardData();
            slotCards = obj.buildSlotCardData();
            selectedSlot = slotCards(obj.SelectedSlot);
            [durationValue, enemyLevel, enemyRes, enemyDef] = obj.currentSimulationInputs();

            data = dashboard;
            data.dashboard = dashboard;
            data.slots = slotCards;
            data.selectedSlot = selectedSlot;
            data.selectedSlotIndex = obj.SelectedSlot;
            data.activeCount = nnz([obj.Slots.Enabled]);
            data.totalSlots = numel(obj.Slots);
            data.teamDuration = sprintf('%.1f s', durationValue);
            data.enemySummary = sprintf('Lv.%d / 抗性 %.2f / 减防 %.2f', ...
                round(enemyLevel), enemyRes, enemyDef);
            data.statusMessage = char(obj.LastStatusMessage);
            data.lastMode = char(obj.LastSimulationMode);
        end

        function [durationValue, enemyLevel, enemyRes, enemyDef] = currentSimulationInputs(obj)
            durationValue = 20;
            enemyLevel = obj.Enemy.Level;
            enemyRes = obj.Enemy.Res;
            enemyDef = obj.Enemy.DefReduct;

            if ~isempty(obj.TeamDurationField) && isvalid(obj.TeamDurationField)
                durationValue = obj.TeamDurationField.Value;
            end
            if ~isempty(obj.EnemyLevelField) && isvalid(obj.EnemyLevelField)
                enemyLevel = obj.EnemyLevelField.Value;
            end
            if ~isempty(obj.EnemyResField) && isvalid(obj.EnemyResField)
                enemyRes = obj.EnemyResField.Value;
            end
            if ~isempty(obj.EnemyDefField) && isvalid(obj.EnemyDefField)
                enemyDef = obj.EnemyDefField.Value;
            end
        end

        function slotCards = buildSlotCardData(obj)
            slotTemplate = struct( ...
                'index', 0, ...
                'isSelected', false, ...
                'enabled', false, ...
                'displayName', '', ...
                'characterKey', '', ...
                'weaponName', '', ...
                'artifactName', '', ...
                'artifactMode', '', ...
                'presetName', '', ...
                'talentSummary', '', ...
                'startTime', '', ...
                'portraitUrl', '', ...
                'weaponBadgeUrl', '', ...
                'artifactBadgeUrl', '');
            slotCards = repmat(slotTemplate, 1, numel(obj.Slots));

            for i = 1:numel(obj.Slots)
                slot = obj.Slots(i);
                slotCards(i).index = i;
                slotCards(i).isSelected = i == obj.SelectedSlot;
                slotCards(i).enabled = logical(slot.Enabled);
                slotCards(i).displayName = char(slot.DisplayName);
                slotCards(i).characterKey = char(slot.CharacterKey);
                slotCards(i).weaponName = char(slot.WeaponName);
                slotCards(i).artifactName = char(slot.ArtifactSet1);
                slotCards(i).artifactMode = char(obj.resolveArtifactModeLabel(slot));
                slotCards(i).presetName = char(obj.lookupPresetLabel(slot));
                slotCards(i).talentSummary = sprintf('C%d / Lv.%d / R%d', ...
                    slot.Constellation, slot.TalentLevel, slot.WeaponRefinement);
                slotCards(i).startTime = sprintf('%.1f s', slot.StartTime);
                slotCards(i).portraitUrl = obj.localFileUrl(slot.PortraitPath);
                slotCards(i).weaponBadgeUrl = obj.localFileUrl(slot.WeaponBadgePath);
                slotCards(i).artifactBadgeUrl = obj.localFileUrl(slot.ArtifactBadgePath);
            end
        end

        function syncDashboard(obj)
            data = obj.buildAppShellData();
            htmlComponents = {obj.TeamHTML, obj.EditorHTML, obj.DashboardHTML};
            for i = 1:numel(htmlComponents)
                component = htmlComponents{i};
                if ~isempty(component) && isvalid(component)
                    component.Data = data;
                end
            end
        end

        function htmlSource = resolveDashboardHtmlSource(obj)
            htmlSource = obj.buildUiHtmlSource('dashboard');
        end

        function htmlSource = resolveUiHtmlSource(obj, htmlName) %#ok<INUSD>
            appFolder = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(fileparts(appFolder));
            candidates = { ...
                fullfile(appFolder, 'ui', 'html', htmlName), ...
                fullfile(projectRoot, 'functions', 'app', 'ui', 'html', htmlName), ...
                fullfile(projectRoot, 'app', 'ui', 'html', htmlName), ...
                fullfile(ctfroot, 'functions', 'app', 'ui', 'html', htmlName), ...
                fullfile(ctfroot, 'app', 'ui', 'html', htmlName), ...
                fullfile(appFolder, 'GenshinDMGDashboard.html')};

            for i = 1:numel(candidates)
                if isfile(candidates{i})
                    htmlSource = candidates{i};
                    return;
                end
            end

            htmlSource = ['<!doctype html><html><head><meta charset="utf-8">' ...
                '<style>html,body{margin:0;width:100%;height:100%;font-family:Segoe UI,Arial,sans-serif;' ...
                'background:#f6f8fb;color:#1f2937}.wrap{padding:14px}.card{background:#fff;border:1px solid #d9e1ec;' ...
                'border-radius:8px;padding:12px}.label{font-size:12px;color:#667085}.value{margin-top:6px;font-size:22px;' ...
                'font-weight:700}</style></head><body><div class="wrap"><div class="card">' ...
                '<div class="label">GenshinDMG Simulator</div><div class="value">Dashboard unavailable</div>' ...
                '<div class="label">The main simulator UI is still available.</div></div></div></body></html>'];
        end

        function htmlSource = buildUiHtmlSource(obj, viewName)
            cssSource = obj.readUiResourceText(fullfile('css', 'genshin-app.css'));
            jsSource = obj.readUiResourceText(fullfile('js', 'genshin-app.js'));
            jsSource = strrep(jsSource, '</script>', '<\/script>');
            viewName = char(string(viewName));

            htmlSource = sprintf([ ...
                '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">' ...
                '<meta name="viewport" content="width=device-width, initial-scale=1">' ...
                '<style>%s</style></head><body>' ...
                '<main id="app" class="ui-shell %s-shell" data-view="%s"></main>' ...
                '<script>%s</script>' ...
                '<script>function setup(htmlComponent){window.GenshinDMGUI.setup(htmlComponent);}</script>' ...
                '</body></html>'], ...
                cssSource, viewName, viewName, jsSource);
        end

        function text = readUiResourceText(obj, relativePath)
            resourcePath = obj.resolveUiResourcePath(relativePath);
            if strlength(resourcePath) == 0
                text = '';
                return;
            end
            text = fileread(resourcePath);
        end

        function resourcePath = resolveUiResourcePath(obj, relativePath) %#ok<INUSD>
            appFolder = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(fileparts(appFolder));
            candidates = { ...
                fullfile(appFolder, 'ui', relativePath), ...
                fullfile(projectRoot, 'functions', 'app', 'ui', relativePath), ...
                fullfile(projectRoot, 'app', 'ui', relativePath), ...
                fullfile(ctfroot, 'functions', 'app', 'ui', relativePath), ...
                fullfile(ctfroot, 'app', 'ui', relativePath)};

            resourcePath = "";
            for i = 1:numel(candidates)
                if isfile(candidates{i})
                    resourcePath = string(candidates{i});
                    return;
                end
            end
        end

        function fileUrl = localFileUrl(obj, filePath) %#ok<INUSD>
            fileUrl = '';
            if strlength(string(filePath)) == 0 || ~isfile(filePath)
                return;
            end

            normalizedPath = strrep(char(filePath), '\', '/');
            if ispc
                fileUrl = ['file:///' normalizedPath];
            else
                fileUrl = ['file://' normalizedPath];
            end
            fileUrl = strrep(fileUrl, ' ', '%20');
        end

        function onHtmlEvent(obj, event)
            eventName = string(event.HTMLEventName);
            eventData = event.HTMLEventData;

            try
                switch eventName
                    case "selectSlot"
                        slotIndex = obj.getHtmlEventNumber(eventData, 'slotIndex', obj.SelectedSlot);
                        obj.selectSlot(max(1, min(numel(obj.Slots), round(slotIndex))));
                    case "toggleSlot"
                        slotIndex = obj.getHtmlEventNumber(eventData, 'slotIndex', obj.SelectedSlot);
                        slotIndex = max(1, min(numel(obj.Slots), round(slotIndex)));
                        obj.Slots(slotIndex).Enabled = ~logical(obj.Slots(slotIndex).Enabled);
                        obj.refreshSlotCard(slotIndex);
                        if obj.SelectedSlot == slotIndex
                            obj.refreshEditorForSelectedSlot();
                        end
                        obj.refreshTimelinePreview();
                    case "runSingle"
                        obj.runSingleSimulation();
                    case "runTeam"
                        obj.runTeamSimulation();
                    case "refreshTimeline"
                        obj.refreshTimelinePreview();
                    case "resetSlot"
                        obj.onResetCurrentSlot();
                    case "restoreRotation"
                        obj.onRestoreDefaultRotation();
                end
            catch ME
                obj.setStatus(sprintf('HTML 事件处理失败：%s', ME.message));
            end
        end

        function value = getHtmlEventNumber(obj, eventData, fieldName, fallback) %#ok<INUSD>
            value = fallback;
            if isstruct(eventData) && isfield(eventData, fieldName)
                value = eventData.(fieldName);
            elseif isa(eventData, 'containers.Map') && isKey(eventData, fieldName)
                value = eventData(fieldName);
            end
            if isstring(value) || ischar(value)
                parsedValue = str2double(value);
                if ~isnan(parsedValue)
                    value = parsedValue;
                else
                    value = fallback;
                end
            end
            if ~isnumeric(value) || isempty(value) || isnan(value)
                value = fallback;
            end
        end

        function label = statusToneLabel(obj, tone) %#ok<INUSD>
            switch char(string(tone))
                case 'success'
                    label = '完成';
                case 'warn'
                    label = '警告';
                case 'error'
                    label = '失败';
                case 'ready'
                    label = '就绪';
                otherwise
                    label = '待机';
            end
        end

        function tone = classifyStatusTone(obj, message, hasResult) %#ok<INUSD>
            text = lower(char(string(message)));
            if contains(text, {'失败', '错误', 'error', 'exception'})
                tone = 'error';
            elseif contains(text, {'警告', 'warning', '注意'})
                tone = 'warn';
            elseif hasResult
                tone = 'success';
            elseif contains(text, {'预览', '刷新', '等待', '已加载', 'ready'})
                tone = 'ready';
            else
                tone = 'idle';
            end
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
            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
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
            if strlength(slot.WeaponBadgePath) > 0 && isfile(slot.WeaponBadgePath)
                obj.SlotWeaponBadges{slotIndex}.ImageSource = char(slot.WeaponBadgePath);
            end
            if strlength(slot.ArtifactBadgePath) > 0 && isfile(slot.ArtifactBadgePath)
                obj.SlotArtifactBadges{slotIndex}.ImageSource = char(slot.ArtifactBadgePath);
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
            if strlength(slot.WeaponBadgePath) > 0 && isfile(slot.WeaponBadgePath)
                obj.SelectedWeaponBadge.ImageSource = char(slot.WeaponBadgePath);
            end
            if strlength(slot.ArtifactBadgePath) > 0 && isfile(slot.ArtifactBadgePath)
                obj.SelectedArtifactBadge.ImageSource = char(slot.ArtifactBadgePath);
            end

            obj.assignDropdownItems(obj.ArtifactSetDropdown, obj.ArtifactSetDropdown.Items, obj.ArtifactSetDropdown.ItemsData, char(slot.ArtifactSet1));
            obj.assignDropdownItems(obj.ArtifactSet2Dropdown, obj.ArtifactSet2Dropdown.Items, obj.ArtifactSet2Dropdown.ItemsData, char(slot.ArtifactSet2));
            obj.assignDropdownItems(obj.ArtifactModeDropdown, obj.ArtifactModeDropdown.Items, obj.ArtifactModeDropdown.ItemsData, obj.resolveArtifactMode(slot));
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
            if isempty(obj.BuildTable) || isempty(obj.RotationTextArea) || isempty(obj.Slots)
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
            slot.WeaponName = string(getFieldOrDefault(slot.Build, 'Weapon', slot.WeaponName));
            slot.WeaponRefinement = max(1, min(5, getFieldOrDefault(slot.Build, 'WeaponRefinement', slot.WeaponRefinement)));
            slot.ArtifactSet1 = string(getFieldOrDefault(slot.Build, 'ArtifactSet1', slot.ArtifactSet1));
            slot.ArtifactSet1Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet1Pieces', slot.ArtifactSet1Pieces);
            slot.ArtifactSet2 = string(getFieldOrDefault(slot.Build, 'ArtifactSet2', slot.ArtifactSet2));
            slot.ArtifactSet2Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet2Pieces', slot.ArtifactSet2Pieces);
            slot.ArtifactSet4Active = getFieldOrDefault(slot.Build, 'ArtifactSet4Active', slot.ArtifactSet4Active);
            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
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

        function [artifactBadgePath, weaponBadgePath] = resolveEquipmentBadgePaths(obj, slot)
            % 为当前槽位生成套装图标与武器图标。
            [artifactDisplayName, artifactShort, artifactColor] = getArtifactSetTheme(slot.ArtifactSet1);
            appFolder = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(fileparts(appFolder));
            badgeDir = fullfile(projectRoot, 'art');
            artifactSubLabel = sprintf('%s | %s', artifactShort, obj.resolveArtifactModeLabel(slot));
            artifactBadgePath = string(getEquipmentBadge('artifact', slot.ArtifactSet1, artifactDisplayName, artifactSubLabel, badgeDir, artifactColor));

            weaponColor = obj.localWeaponBadgeColor(slot);
            weaponSubLabel = sprintf('R%d', slot.WeaponRefinement);
            weaponBadgePath = string(getEquipmentBadge('weapon', slot.WeaponName, slot.WeaponName, weaponSubLabel, badgeDir, weaponColor));
        end

        function color = localWeaponBadgeColor(obj, slot) %#ok<MANU>
            if isempty(slot.WeaponList)
                color = [0.55 0.64 0.76];
                return;
            end
            idx = find(string(slot.WeaponList.Name) == slot.WeaponName, 1, 'first');
            if isempty(idx)
                color = [0.55 0.64 0.76];
                return;
            end
            rank = slot.WeaponList.Rank(idx);
            switch rank
                case 5
                    color = [0.86 0.66 0.22];
                case 4
                    color = [0.58 0.46 0.80];
                otherwise
                    color = [0.45 0.58 0.74];
            end
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
                'StartTime', slot.StartTime, ...
                'RotationFile', tempRotationPath);
            memberCfg = getDefaultCharacterConfig(char(slot.CharacterKey), overrides);
        end

        function memberCfg = buildComparisonMemberConfig(obj, slotIndex, slot)
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
                'StartTime', slot.StartTime, ...
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

        function [members, slotIndices] = buildEnabledMembersFromSlotCopies(obj, slots)
            members = {};
            slotIndices = [];
            for i = 1:numel(slots)
                if slots(i).Enabled
                    members{end + 1} = obj.buildComparisonMemberConfig(i, slots(i)); %#ok<AGROW>
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
                obj.updateResultTables(summary, result.Breakdown, table(), table());
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

                obj.updateResultTables( ...
                    teamResult.Summary, ...
                    teamResult.Breakdown, ...
                    getFieldOrDefault(teamResult, 'EnergyTimeline', table()), ...
                    getFieldOrDefault(teamResult, 'ActiveEffectsTable', table()));
                obj.updateKpi(teamResult.TotalDMG, teamResult.DPS, teamResult.RotationDuration);
                obj.renderBarChart(teamResult.Summary);
                obj.renderTimeline(slotIndices, teamResult);
                obj.setStatus(obj.localBuildTeamStatus(teamResult, numel(slotIndices)));
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

            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
            obj.Slots(obj.SelectedSlot) = slot;
            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
            obj.refreshTimelinePreview();
            obj.setStatus(sprintf('Applied ranked candidate: %s.', char(string(row.Candidate))));
        end

        function updateResultTables(obj, summaryTable, breakdownTable, energyTable, effectsTable)
            % 更新右侧结果表格。
            obj.SummaryTable.Data = summaryTable;
            if nargin < 4 || isempty(energyTable)
                energyTable = table();
            end
            if nargin < 5 || isempty(effectsTable)
                effectsTable = table();
            end
            obj.EnergyTable.Data = energyTable;
            obj.BreakdownTable.Data = breakdownTable;
            obj.EffectsTable.Data = effectsTable;
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
            if isstruct(results) && isscalar(results) && isfield(results, 'TimelineTable')
                obj.renderSharedTimeline(results);
                hold(obj.TimelineAxes, 'off');
                return;
            end

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

        function renderSharedTimeline(obj, teamResult)
            % 根据共享时间线表渲染整队真实时间轴。
            timelineTable = getFieldOrDefault(teamResult, 'TimelineTable', table());
            if isempty(timelineTable) || ~istable(timelineTable) || height(timelineTable) == 0
                title(obj.TimelineAxes, '整队时间线为空');
                xlabel(obj.TimelineAxes, 'Time (s)');
                ylabel(obj.TimelineAxes, 'Character');
                grid(obj.TimelineAxes, 'on');
                return;
            end

            names = string(timelineTable.Character);
            orderedNames = unique(names, 'stable');
            colors = lines(max(4, numel(orderedNames)));
            maxEndTime = max([obj.TeamDurationField.Value; timelineTable.EndTime]);

            for i = 1:height(timelineTable)
                row = timelineTable(i, :);
                name = string(row.Character);
                duration = max(0, row.EndTime - row.StartTime);
                if duration <= 0
                    duration = 0.05;
                end

                yCenter = find(orderedNames == name, 1, 'first');
                if isempty(yCenter)
                    continue;
                end

                if strcmpi(char(name), 'Team')
                    faceColor = [0.88 0.88 0.90];
                    edgeColor = [0.45 0.45 0.48];
                else
                    faceColor = colors(yCenter, :) * 0.82 + 0.18;
                    edgeColor = colors(yCenter, :);
                end

                rectangle(obj.TimelineAxes, ...
                    'Position', [row.StartTime, yCenter - 0.34, duration, 0.68], ...
                    'FaceColor', faceColor, ...
                    'EdgeColor', edgeColor, ...
                    'LineWidth', 1.2);

                if duration >= 0.30
                    label = char(string(row.Action));
                    if strlength(string(getFieldOrDefault(row, 'Reaction', ""))) > 0 ...
                            && ~strcmpi(char(name), 'Team')
                        label = sprintf('%s | %s', char(string(row.Action)), char(string(row.Reaction)));
                    end
                    text(obj.TimelineAxes, row.StartTime + duration / 2, yCenter, label, ...
                        'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'middle', ...
                        'FontSize', 9, ...
                        'Color', [0.08 0.10 0.14], ...
                        'Interpreter', 'none');
                end
            end

            xline(obj.TimelineAxes, obj.TeamDurationField.Value, '--', '团队轴长', ...
                'Color', [0.68 0.28 0.28], 'LabelVerticalAlignment', 'middle');
            ylim(obj.TimelineAxes, [0.4, numel(orderedNames) + 0.6]);
            xlim(obj.TimelineAxes, [0, max(1, maxEndTime + 0.5)]);
            yticks(obj.TimelineAxes, 1:numel(orderedNames));
            yticklabels(obj.TimelineAxes, cellstr(orderedNames));
            xlabel(obj.TimelineAxes, 'Time (s)');
            ylabel(obj.TimelineAxes, 'Character');
            title(obj.TimelineAxes, sprintf('%s模式：共享队伍时间线', char(obj.LastSimulationMode)));
            grid(obj.TimelineAxes, 'on');
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
                message = sprintf('%s | Warnings %d', message, numel(warnings));
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
            slotIndices = find([obj.Slots.Enabled]);
            if isempty(slotIndices)
                slotIndices = obj.SelectedSlot;
            end
            obj.LastSimulationMode = "预览";
            obj.renderTimeline(slotIndices, struct([]));
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
            % 展示模拟错误，同时保留堆栈首条关键信息。
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
            slot.ArtifactSet1 = string(getFieldOrDefault(slot.Build, 'ArtifactSet1', slot.ArtifactSet1));
            slot.ArtifactSet1Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet1Pieces', slot.ArtifactSet1Pieces);
            slot.ArtifactSet2 = string(getFieldOrDefault(slot.Build, 'ArtifactSet2', slot.ArtifactSet2));
            slot.ArtifactSet2Pieces = getFieldOrDefault(slot.Build, 'ArtifactSet2Pieces', slot.ArtifactSet2Pieces);
            slot.ArtifactSet4Active = getFieldOrDefault(slot.Build, 'ArtifactSet4Active', slot.ArtifactSet4Active);
            slot.WeaponList = listWeaponsForCharacter(slot.CharacterKey);
            slot.Build = obj.applyWeaponStatsToBuild(slot.Build, slot.WeaponList, slot.WeaponName, slot.WeaponRefinement);
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
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
            slot = obj.applyArtifactModeToSlot(slot, obj.resolveArtifactMode(slot));
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
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
            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
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
            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
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
            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
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

        function onSelectedArtifactSetChanged(obj, setId)
            % 中间编辑区的套装选择回写。
            slot = obj.Slots(obj.SelectedSlot);
            slot.ArtifactSet1 = string(setId);
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
            obj.Slots(obj.SelectedSlot) = slot;
            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
        end

        function onSelectedArtifactSet2Changed(obj, setId)
            % 中间编辑区第二套圣遗物回写。
            slot = obj.Slots(obj.SelectedSlot);
            slot.ArtifactSet2 = string(setId);
            if obj.resolveArtifactMode(slot) ~= "2p2p" && slot.ArtifactSet2 ~= "None"
                slot = obj.applyArtifactModeToSlot(slot, '2p2p');
            end
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
            obj.Slots(obj.SelectedSlot) = slot;
            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
        end

        function onSelectedArtifactModeChanged(obj, modeValue)
            % 中间编辑区的套装件数模式切换回写。
            slot = obj.Slots(obj.SelectedSlot);
            slot = obj.applyArtifactModeToSlot(slot, modeValue);
            slot.Build = obj.applyArtifactSelectionToBuild(slot.Build, slot);
            [slot.ArtifactBadgePath, slot.WeaponBadgePath] = obj.resolveEquipmentBadgePaths(slot);
            obj.Slots(obj.SelectedSlot) = slot;
            obj.refreshSlotCard(obj.SelectedSlot);
            obj.refreshEditorForSelectedSlot();
        end

        function slot = applyArtifactModeToSlot(obj, slot, modeValue) %#ok<MANU>
            % 按 GUI 模式将件数分配回槽位状态。
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
