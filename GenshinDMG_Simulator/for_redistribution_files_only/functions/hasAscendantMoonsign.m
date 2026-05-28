function tf = hasAscendantMoonsign(teamContext)
    % Resolve the current project-level Ascendant Gleam flag from the
    % normalized team context, while remaining compatible with older
    % callsites that still pass the legacy Members payload.
    memberNames = string(getFieldOrDefault(teamContext, 'MemberNames', strings(0, 1)));
    if isempty(memberNames)
        memberNames = localExtractLegacyMemberNames(getFieldOrDefault(teamContext, 'Members', {}));
    end

    memberNames = lower(strtrim(memberNames(:).'));
    memberNames(strlength(memberNames) == 0) = [];
    tf = any(ismember(memberNames, ["aino", "jahoda", "illuga"]));
end

function memberNames = localExtractLegacyMemberNames(members)
    memberNames = strings(0, 1);
    if isstruct(members)
        memberNames = strings(numel(members), 1);
        for i = 1:numel(members)
            memberNames(i) = string(getFieldOrDefault(members(i), 'Name', ""));
        end
    elseif iscell(members)
        memberNames = strings(numel(members), 1);
        for i = 1:numel(members)
            memberNames(i) = string(getFieldOrDefault(members{i}, 'Name', ""));
        end
    end
end
