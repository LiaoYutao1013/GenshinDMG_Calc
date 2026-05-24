function validateAuditApplicabilityRegression()
    initProjectPaths();

    jean = auditCharacterReactionMetadata('Jean', struct('Constellation', 1));
    rows = jean.Rows;
    normalRows = rows(ismember(string(rows.Action), ["N1", "N2", "N3"]), :);

    assert(height(normalRows) == 3, ...
        'Jean audit should include the physical normal-string filler actions.');
    assert(all(strcmp(string(normalRows.ApplyGaugeSource), "not_applicable")), ...
        'Physical normal attacks should not be classified as aura ApplyGauge fallbacks.');
    assert(all(strcmp(string(normalRows.ICDSource), "not_applicable")), ...
        'Physical normal attacks should not be classified as ICD fallbacks.');
    assert(all(~normalRows.ApplyGaugeFallback) && all(~normalRows.ICDFallback), ...
        'Physical normal attacks should not contribute fallback audit rows.');
    assert(all(isnan(normalRows.ApplyGauge)), ...
        'Physical normal attacks should not expose a synthetic gauge value in the audit table.');

    disp('validateAuditApplicabilityRegression passed');
end
