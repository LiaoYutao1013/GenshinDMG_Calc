function rows = buildStructToTableData(build)
    % 将 build struct 展平为 GUI 可编辑的两列表格。
    fields = fieldnames(build);
    rows = cell(numel(fields), 2);
    for i = 1:numel(fields)
        rows{i, 1} = fields{i};
        value = build.(fields{i});
        if isstring(value)
            rows{i, 2} = char(value);
        elseif ischar(value)
            rows{i, 2} = value;
        else
            rows{i, 2} = value;
        end
    end
end
