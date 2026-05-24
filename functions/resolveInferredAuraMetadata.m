function meta = resolveInferredAuraMetadata(member, action, meta)
    % Backfill high-confidence aura / ICD metadata for inferred team actions.
    % Reuses calibrated Lunaris attack names from existing simulators when the
    % timeline token alone is not descriptive enough.
    if nargin < 1 || isempty(member)
        member = struct();
    end
    if nargin < 2
        action = "";
    end
    if nargin < 3 || isempty(meta)
        meta = struct();
    end

    characterName = string(getFieldOrDefault(member, 'Name', ""));
    normalizedName = lower(char(characterName));
    lowerAction = localNormalizeActionToken(action);
    applyElement = string(getFieldOrDefault(meta, 'ApplyElement', getFieldOrDefault(meta, 'HitElement', "")));
    hitElement = string(getFieldOrDefault(meta, 'HitElement', ""));
    actionClass = string(getFieldOrDefault(meta, 'ActionClass', "Utility"));
    forceReactionName = string(getFieldOrDefault(meta, 'ForceReactionName', ""));
    isElemental = localIsElementalDamageElement(applyElement) || localIsElementalDamageElement(hitElement);

    if ~isfield(meta, 'ApplyGaugeSource') || strlength(string(meta.ApplyGaugeSource)) == 0
        meta.ApplyGaugeSource = "";
    end
    if ~isfield(meta, 'ICDRule')
        meta.ICDRule = "";
    end
    if ~isfield(meta, 'ICDGroup')
        meta.ICDGroup = "";
    end
    if ~isfield(meta, 'ICDSource') || strlength(string(meta.ICDSource)) == 0
        meta.ICDSource = "";
    end
    if ~isfield(meta, 'StrikeType')
        meta.StrikeType = "";
    end
    if ~isfield(meta, 'LunarisAttackName')
        meta.LunarisAttackName = "";
    end
    if ~isfield(meta, 'LunarisDamageParam')
        meta.LunarisDamageParam = "";
    end

    if strlength(forceReactionName) > 0 || actionClass == "Reaction"
        meta.ApplyGaugeSource = "not_applicable";
        meta.ICDSource = "not_applicable";
        meta.ICDRule = "";
        meta.ICDGroup = "";
        return;
    end

    if ~isElemental
        meta.ApplyGaugeSource = "not_applicable";
        meta.ICDSource = "not_applicable";
        meta.ICDRule = "";
        meta.ICDGroup = "";
        return;
    end

    if double(getFieldOrDefault(meta, 'ApplyGauge', 0)) <= 0 ...
            && ~logical(getFieldOrDefault(meta, 'CanApplyAura', false))
        meta.ApplyGaugeSource = "not_applicable";
        meta.ICDSource = "not_applicable";
        meta.ICDRule = "";
        meta.ICDGroup = "";
        return;
    end

    override = localResolveKnownAttackOverride(normalizedName, lowerAction);
    explicitAttackName = string(getFieldOrDefault(meta, 'LunarisAttackName', ""));
    explicitDamageParam = string(getFieldOrDefault(meta, 'LunarisDamageParam', ""));
    if strlength(explicitAttackName) > 0
        override.AttackName = explicitAttackName;
    end
    if strlength(explicitDamageParam) > 0
        override.DamageParam = explicitDamageParam;
    end

    attackMeta = localResolveAttackMetadata(characterName, override, hitElement);
    if ~isempty(fieldnames(attackMeta))
        meta.LunarisAttackName = string(getFieldOrDefault(attackMeta, 'Name', override.AttackName));
        damageParam = string(getFieldOrDefault(attackMeta, 'DamageParam', override.DamageParam));
        if damageParam ~= "-" && strlength(damageParam) > 0
            meta.LunarisDamageParam = damageParam;
        else
            meta.LunarisDamageParam = string(getFieldOrDefault(override, 'DamageParam', ""));
        end

        gaugeUnits = double(getFieldOrDefault(attackMeta, 'GaugeUnits', getFieldOrDefault(meta, 'ApplyGauge', 0)));
        meta.ApplyGauge = gaugeUnits;
        meta.CanApplyAura = gaugeUnits > 0 && localIsElementalDamageElement(applyElement);
        meta.ApplyGaugeSource = "metadata";
        meta.ICDRule = string(getFieldOrDefault(attackMeta, 'ICDRule', ""));
        if strlength(string(getFieldOrDefault(override, 'ICDGroup', ""))) > 0
            meta.ICDGroup = string(getFieldOrDefault(override, 'ICDGroup', ""));
        else
            meta.ICDGroup = localResolveMetadataICDGroup(attackMeta);
        end
        if strlength(meta.ICDRule) > 0
            meta.ICDSource = "metadata";
        else
            meta.ICDSource = "pending_verification";
        end
        meta.StrikeType = string(getFieldOrDefault(attackMeta, 'StrikeType', ""));
        return;
    end

    if logical(getFieldOrDefault(meta, 'CanApplyAura', false)) && double(getFieldOrDefault(meta, 'ApplyGauge', 0)) > 0
        if strlength(string(meta.ApplyGaugeSource)) == 0
            meta.ApplyGaugeSource = "inferred";
        end
        if strlength(string(meta.ICDSource)) == 0
            if strlength(string(getFieldOrDefault(meta, 'ICDRule', ""))) > 0
                meta.ICDSource = "inferred";
            else
                meta.ICDSource = "pending_verification";
            end
        end
    else
        meta.ApplyGaugeSource = "not_applicable";
        if strlength(string(meta.ICDSource)) == 0
            meta.ICDSource = "not_applicable";
        end
    end
end

function token = localNormalizeActionToken(action)
    token = lower(char(string(action)));
    token = regexprep(token, '#\d+$', '');
end

function tf = localIsElementalDamageElement(element)
    switch lower(char(string(element)))
        case {'pyro', 'hydro', 'cryo', 'electro', 'anemo', 'geo', 'dendro'}
            tf = true;
        otherwise
            tf = false;
    end
end

function override = localResolveKnownAttackOverride(normalizedName, lowerAction)
    override = struct('AttackName', "", 'DamageParam', "", 'ICDGroup', "");

    switch normalizedName
        case 'fischl'
            switch lowerAction
                case 'oz'
                    override.AttackName = "Ability_Skill_S_CrowSummon";
                    override.ICDGroup = "Fischl_Oz";
                case 'qoz'
                    override.AttackName = "Skill_S_Crow_AutoAttack_Hit_01";
                    override.ICDGroup = "Fischl_Oz";
                case 'oztick'
                    override.AttackName = "Skill_S_Crow_AutoAttack_Hit_01";
                    override.ICDGroup = "Fischl_Oz";
            end

        case 'xingqiu'
            switch lowerAction
                case 'q'
                    override.AttackName = "Bullet_PhantomBurst1";
                case 'rainswordwave'
                    override.AttackName = "Bullet_PhantomBurst1";
                    override.ICDGroup = "Xingqiu_Rain";
            end

        case 'yelan'
            switch lowerAction
                case 'q'
                    override.AttackName = "ElementalBurst_Dice";
                case {'throw', 'exquisitethrowwave'}
                    override.AttackName = "ElementalBurst_Dice_Bullet_01";
            end

        case 'beidou'
            if strcmp(lowerAction, 'stormbreakerarc')
                override.AttackName = "ThunderShield_Gadget";
                override.ICDGroup = "Beidou_Stormbreaker";
            end

        case 'raidenshogun'
            switch lowerAction
                case 'e'
                    override.AttackName = "SkillObj_ElementalArt_EyeBoom";
                    override.DamageParam = "ElementalArt_Attack";
                case 'eyecoordslash'
                    override.AttackName = "Elf";
                    override.DamageParam = "Elf_Attack|Elf_RemoteAttackRatio|MUL";
            end

        case 'xiangling'
            switch lowerAction
                case 'e'
                    override.AttackName = "PandaFire_Attack";
                    override.DamageParam = "XiangLing_ProudSkill32_P1_Damage_Percentage";
                case 'pyronadotick'
                    override.AttackName = "FireCircle03";
                    override.DamageParam = "XiangLing_ProudSkill33_P4_Damage_Percentage";
            end

        case 'nahida'
            switch lowerAction
                case {'e', 'epress'}
                    override.AttackName = "ElementalArt_Click";
                    override.DamageParam = "Click_Damage";
                case 'ehold'
                    override.AttackName = "ElementalArt_RayCast";
                    override.DamageParam = "Hold_Damage";
                case {'trikarmatick', 'bursttrikarma'}
                    override.AttackName = "ElementalArt";
                    override.DamageParam = "Chain_Damage_PerAtk";
            end

        case 'qiqi'
            switch lowerAction
                case 'e'
                    override.AttackName = "ElementalArt_Bullet";
                case 'heraldcoord'
                    override.AttackName = "PermanentSkill_3";
            end

        case 'kaeya'
            if strcmp(lowerAction, 'glacialwaltz')
                override.AttackName = "Avatar_Keaya_FrozenTrap";
                override.DamageParam = "Damage";
            end

        case 'aino'
            switch lowerAction
                case 'duckywaterball'
                    override.AttackName = "ElementalBurst_Gadget";
                    override.DamageParam = "Burst_Damage";
                    override.ICDGroup = "Aino_Ducky";
                case 'duckywaterballc2'
                    override.AttackName = "ElementalBurst_ConsExtra_Bullet";
                    override.DamageParam = "Attack_Cons_Ratio";
                case 'e'
                    override.AttackName = "ElementalArt";
                    override.DamageParam = "Art01_Damage";
                case 'e2'
                    override.AttackName = "ElementalArt";
                    override.DamageParam = "Art02_Damage";
            end

        case 'jahoda'
            switch lowerAction
                case 'meowball'
                    override.AttackName = "Bullet_ElementalArt_Attack";
                    override.DamageParam = "ElementalArt_BulletExplode";
                    override.ICDGroup = "Jahoda_Meowball";
                case 'meowbounce'
                    override.AttackName = "Bullet_ElementalArt_Attack";
                    override.DamageParam = "ElementalArt_BulletExplode";
                    override.ICDGroup = "Jahoda_Meowball_C1";
                case 'robotstrike'
                    override.AttackName = "ElementalBurst";
                    override.DamageParam = "ElementalBurst_BulletExplode";
                    override.ICDGroup = "Jahoda_Robot";
                case 'q'
                    override.AttackName = "ElementalBurst";
                    override.DamageParam = "ElementalBurst_AvatarExplode";
                case 'e'
                    override.AttackName = "ElementalArt";
                    override.DamageParam = "ElementalArt_SmokeAttack";
                case 'e2'
                    override.AttackName = "ElementalArt_Second_Attack";
                    override.DamageParam = "ElementalArt_AvatarExplode";
                case 'flaskfull'
                    override.AttackName = "ElementalArt_Second_Attack";
                    override.DamageParam = "ElementalArt_AvatarExplode_Uncharged";
            end
    end
end

function attackMeta = localResolveAttackMetadata(characterName, override, actionElement)
    attackMeta = struct();
    attacks = loadLunarisAttackMetadata(characterName);
    if isempty(attacks)
        return;
    end

    attackName = string(getFieldOrDefault(override, 'AttackName', ""));
    damageParam = string(getFieldOrDefault(override, 'DamageParam', ""));
    icdGroup = string(getFieldOrDefault(override, 'ICDGroup', ""));
    if strlength(attackName) == 0
        return;
    end

    normalizedName = localNormalizeLookupToken(attackName);
    normalizedParam = localNormalizeLookupToken(damageParam);
    normalizedElement = localNormalizeLookupToken(actionElement);

    bestScore = -inf;
    bestIndex = 0;
    for i = 1:numel(attacks)
        score = 0;
        if attacks(i).NormalizedName == normalizedName
            score = score + 5;
        end
        if strlength(normalizedParam) > 0
            if attacks(i).NormalizedDamageParam == normalizedParam
                score = score + 4;
            elseif localNormalizeLookupToken(getFieldOrDefault(attacks(i), 'DamageParam', "")) == normalizedParam
                score = score + 3;
            end
        end
        if strlength(normalizedElement) > 0 ...
                && localNormalizeLookupToken(getFieldOrDefault(attacks(i), 'Element', "")) == normalizedElement
            score = score + 1;
        end
        if strlength(icdGroup) > 0 && attacks(i).NormalizedICDSource == localNormalizeLookupToken(icdGroup)
            score = score + 1;
        end

        if score > bestScore
            bestScore = score;
            bestIndex = i;
        end
    end

    if bestIndex > 0 && bestScore > 0
        attackMeta = attacks(bestIndex);
    end
end

function token = localNormalizeLookupToken(value)
    token = string(lower(regexprep(char(string(value)), '[^a-z0-9]', '')));
end

function group = localResolveMetadataICDGroup(attackMeta)
    group = string(getFieldOrDefault(attackMeta, 'NormalizedICDSource', ""));
    if strlength(group) == 0
        group = string(getFieldOrDefault(attackMeta, 'NormalizedName', ""));
    end
end
