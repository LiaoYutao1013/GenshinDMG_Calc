function filePath = writeTempRotationFile(tempDir, characterName, slotIndex, rotationText)
    % 将 GUI 中编辑后的轮转文本写入临时文件，并返回绝对路径。
    % 角色模拟器继续复用现有 readRotationTokens 逻辑，无需修改底层解析器。
    if nargin < 4
        rotationText = "";
    end

    if ~exist(tempDir, 'dir')
        mkdir(tempDir);
    end

    safeName = regexprep(char(string(characterName)), '[^a-zA-Z0-9_-]', '_');
    filePath = fullfile(tempDir, sprintf('rotation_slot%d_%s.txt', slotIndex, safeName));

    fid = fopen(filePath, 'w');
    if fid == -1
        error('Unable to create temporary rotation file: %s', filePath);
    end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', char(string(rotationText)));
end
