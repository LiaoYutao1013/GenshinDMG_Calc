function validateReactionMetadataReferenceRegression()
    initProjectPaths();

    referenceCases = {
        struct('Name', "Barbara", 'ExpectedActions', ["E", "CA", "Q"]), ...
        struct('Name', "Kaeya", 'ExpectedActions', ["E", "Q", "CA"]), ...
        struct('Name', "Venti", 'ExpectedActions', ["EHold", "QDot", "QInfuse"]), ...
        struct('Name', "Xiangling", 'ExpectedActions', ["E", "Chili", "PyronadoEarly", "Pyronado"]), ...
        struct('Name', "Nahida", 'ExpectedActions', ["EPress", "TriKarma", "BurstTriKarma"])
    };

    for caseIndex = 1:numel(referenceCases)
        caseSpec = referenceCases{caseIndex};
        audit = auditCharacterReactionMetadata(caseSpec.Name);
        rows = audit.Rows;
        fallbackRows = rows(rows.ApplyGaugeFallback | rows.ICDFallback, :);

        assert(~isempty(rows), ...
            sprintf('%s audit should produce at least one action row.', caseSpec.Name));
        assert(isempty(fallbackRows), ...
            sprintf('%s audit should resolve ApplyGauge and ICD metadata without fallback rows.', caseSpec.Name));

        actualActions = unique(string(rows.Action), 'stable');
        for actionIndex = 1:numel(caseSpec.ExpectedActions)
            expectedAction = caseSpec.ExpectedActions(actionIndex);
            assert(any(strcmp(actualActions, expectedAction)), ...
                sprintf('%s audit should include the %s action.', caseSpec.Name, expectedAction));
        end
    end

    disp('validateReactionMetadataReferenceRegression passed');
end
