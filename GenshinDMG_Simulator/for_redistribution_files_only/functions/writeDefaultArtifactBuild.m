function writeDefaultArtifactBuild(build, outputPath)
    if isdeployed
        return;
    end

    outputDir = fileparts(outputPath);
    if exist(outputDir, 'dir') ~= 7
        mkdir(outputDir);
    end

    writetable(struct2table(build), outputPath);
end
