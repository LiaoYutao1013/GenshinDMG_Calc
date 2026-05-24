function validateReactionMetadataReferenceRegression3()
    initProjectPaths();

    referenceCases = {
        struct('Name', "Wanderer", 'ExpectedActions', ["E", "CA", "Descent", "Q"]), ...
        struct('Name', "ShikanoinHeizou", 'ExpectedActions', ["Swirl1", "EFull", "Iris"]), ...
        struct('Name', "KamisatoAyato", 'ExpectedActions', ["Q", "E", "S3"]), ...
        struct('Name', "Tighnari", 'ExpectedActions', ["Charge", "Wreath1", "Cluster1", "Q2"])
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

    disp('validateReactionMetadataReferenceRegression3 passed');
end
