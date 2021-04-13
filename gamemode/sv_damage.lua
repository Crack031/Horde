local plymeta = FindMetaTable("Player")

HORDE.DMG_CALCULATED = 1
HORDE.DMG_SPLASH = 2

-- Player damage.
function HORDE:ApplyDamage(npc, hitgroup, dmginfo)
    if dmginfo:GetDamageCustom() > 0 then return end
    if dmginfo:GetDamage() <= 0 then return end
    if not npc:IsValid() then return end

    local attacker = dmginfo:GetAttacker()
    if attacker:GetNWEntity("HordeOwner"):IsPlayer() then
        dmginfo:SetInflictor(attacker)
        dmginfo:SetAttacker(attacker:GetNWEntity("HordeOwner"))
    end

    local ply = dmginfo:GetAttacker()
    if not ply:IsPlayer() then return end

    local increase = 0
    local more = 1
    local base_add = 0
    local post_add = 0

    -- Apply bonus
    local bonus = {increase=increase, more=more, base_add=base_add, post_add=post_add}
    hook.Run("Horde_OnPlayerDamage", ply, npc, bonus, hitgroup, dmginfo)
    if dmginfo:GetInflictor():GetNWEntity("HordeOwner"):IsPlayer() then
        hook.Run("Horde_OnPlayerMinionDamage", ply, npc, bonus, dmginfo)
    end

    dmginfo:AddDamage(base_add)
    dmginfo:ScaleDamage(bonus.more * (1 + bonus.increase))
    dmginfo:AddDamage(post_add)
    dmginfo:SetDamageCustom(HORDE.DMG_CALCULATED)
end

hook.Add("EntityTakeDamage", "Horde_MinionDamageRedirection", function (target, dmginfo)
    local attacker = dmginfo:GetAttacker()
    if attacker:GetNWEntity("HordeOwner"):IsPlayer() then
        dmginfo:SetInflictor(attacker)
        dmginfo:SetAttacker(attacker:GetNWEntity("HordeOwner"))
    end

    if attacker:IsPlayer() and target:IsNPC() and (not target:GetNWEntity("HordeOwner"):IsPlayer())then
        HORDE:ApplyDamage(target, HITGROUP_GENERIC, dmginfo)
    end
end)

-- Seems like ScaleNPCDamage is called before EntityTakeDamage.
hook.Add("ScaleNPCDamage", "Horde_ApplyDamage", function (npc, hitgroup, dmginfo)
    HORDE:ApplyDamage(npc, hitgroup, dmginfo)
end)

-- Player damage taken
hook.Add("EntityTakeDamage", "Horde_ApplyDamageTaken", function (target, dmg)
    if not target:IsValid() or not target:IsPlayer() then return end
    local ply = target

    -- Prevent damage from skill explosions (e.g. Rip and Tear, Chain Reaction, Kamikaze)
    if dmg:GetInflictor():IsNPC() and dmg:GetAttacker():IsPlayer() then return true end
    
    -- Prevent minion from damaging players
    if dmg:GetInflictor():GetNWEntity("HordeOwner"):IsPlayer() then return true end

    -- Apply bonus
    local bonus = {resistance=0, less=1, evasion=0}
    hook.Run("Horde_OnPlayerDamageTaken", ply, dmg, bonus)

    if bonus.evasion > 0 then
        local evade = math.random()
        if evade <= bonus.evasion then
            sound.Play("horde/player/evade.ogg", ply:GetPos())
            hook.Run("Horde_OnPlayerEvade", ply, dmg)
            return true
        end
    end
    if bonus.resistance >= 1.0 then return true end
    dmg:ScaleDamage(bonus.less * (1 - bonus.resistance))
end)

-- Enemy damage.
hook.Add("EntityTakeDamage", "Horde_MutationDamage", function (target, dmg)
    if target:IsValid() and target:IsNPC() and dmg:GetInflictor():IsWorld() and dmg:GetAttacker():IsNPC() then
        return true
    end
end)

-- Main target does not take splash damage
hook.Add("EntityTakeDamage", "Horde_SplashDamage", function (target, dmg)
    if target:IsValid() and target:IsNPC() and dmg:GetInflictor() == target and dmg:GetAttacker():IsPlayer() and dmg:GetDamageCustom() == HORDE.DMG_SPLASH then
        return true
    end
end)

-- Hulk headshot multiplier reduction
hook.Add("ScaleNPCDamage", "Horde_MutatedHulkDamage", function (npc, hitgroup, dmg)
    if npc:IsValid() and npc:GetClass() == "npc_vj_mutated_hulk" then
        if hitgroup == HITGROUP_HEAD then
            dmg:ScaleDamage(0.65)
        end
    end
end)

-- Gonome headshot multiplier reduction
hook.Add("ScaleNPCDamage", "Horde_GonomeDamage", function (npc, hitgroup, dmg)
    if npc:IsValid() and npc:GetClass() == "npc_vj_alpha_gonome" then
        if hitgroup == HITGROUP_HEAD then
            dmg:ScaleDamage(0.65)
        end
    end
end)

-- Host headshot multiplier reduction
hook.Add("ScaleNPCDamage", "Horde_HostDamage", function (npc, hitgroup, dmg)
    if npc:IsValid() and npc:Horde_GetName() == "Host" then
        if hitgroup == HITGROUP_HEAD then
            dmg:ScaleDamage(0.65)
        end
    end
end)