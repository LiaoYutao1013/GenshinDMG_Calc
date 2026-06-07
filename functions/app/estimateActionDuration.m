function duration = estimateActionDuration(characterName, action, fallbackDuration)
    % Generic GUI-side action duration estimate for timeline previews.
    if nargin < 3 || isempty(fallbackDuration)
        fallbackDuration = 0.60;
    end

    action = string(action);
    if strlength(action) == 0
        duration = 0;
        return;
    end

    lowerAction = lower(action);
    duration = fallbackDuration;

    if lowerAction == "auto"
        duration = NaN;
        return;
    end

    if startsWith(lowerAction, "n")
        token = regexp(char(lowerAction), 'n(\d+)', 'tokens', 'once');
        if ~isempty(token)
            normalIndex = str2double(token{1});
            duration = min(0.85, 0.28 + 0.08 * normalIndex);
            return;
        end
    end

    switch lowerAction
        case {"e", "skill"}
            duration = 0.70;
        case {"exq", "enhancedskill"}
            duration = 0.65;
        case {"q", "burst"}
            duration = 1.25;
        case {"charge", "charged", "heavy"}
            duration = 0.78;
        case "plunge"
            duration = 0.95;
        case {"droplet", "drain"}
            duration = 0.35;
        case {"rebuke", "rebukec2", "luster", "lusterbuffed"}
            duration = 0.80;
        case "blade"
            duration = 0.35;
        case "herald"
            duration = 15.00;
        case {"heraldcoord", "qstellar", "c6icicle", "n3stellar", "n5stellar", "n5stellarbuffed", ...
                "n3stellarc2", "n5stellarc2", "n5stellarbuffedc2", ...
                "lusterstellar", "lusterstellarbuffed", "lusterstellarc2", "lusterstellarbuffedc2", ...
                "n5icicle", "lustericicle"}
            duration = 0.01;
        case {"switchpneuma", "switchousia"}
            duration = 0.25;
        case {"usher", "cheval", "crab"}
            duration = 1.45;
        case "singer"
            duration = 1.80;
        case {"debttick", "summon", "arkhe"}
            duration = 0.40;
        case {"n1left", "n1right", "n2left", "n2right"}
            duration = 0.18;
        case {"n3left", "n3right"}
            duration = 0.22;
        case {"n4left", "n4right"}
            duration = 0.24;
        case {"n5left", "n5right"}
            duration = 0.28;
        case {"chargedleft", "chargedright"}
            duration = 0.32;
        case {"fourwindsright", "fourwindsanemo"}
            duration = 0.22;
        case {"azuredevourright1", "azuredevouranemo1", "azuredevourright2", "azuredevouranemo2"}
            duration = 0.16;
        case {"fourwindsc2", "azuredevourc2"}
            duration = 0.08;
        case "q1"
            duration = 0.42;
        case "q2"
            duration = 0.34;
        otherwise
            switch lower(char(string(characterName)))
                case 'ororon'
                    if strcmp(lowerAction, 'e')
                        duration = 0.60;
                    elseif strcmp(lowerAction, 'q')
                        duration = 0.95;
                    elseif any(strcmp(lowerAction, ["bounce", "hypersense", "c6echo"]))
                        duration = 0.20;
                    end
                case 'skirk'
                    if any(strcmp(lowerAction, ["n4a", "n4b", "n5"]))
                        duration = 0.60;
                    end
                case 'arlecchino'
                    if any(strcmp(lowerAction, ["n4a", "n4b"]))
                        duration = 0.45;
                    end
            end
    end
end
