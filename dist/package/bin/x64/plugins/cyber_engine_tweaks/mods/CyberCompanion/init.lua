-- ==============================================================================
--  CYBER COMPANION: RAE (РЭЙ) — Full AI Companion Mod for Cyberpunk 2077
--  Nexus Mods Edition (Cyber Engine Tweaks)
-- ==============================================================================

local mod = {
    version = "1.0.0",
    actionFiles = {
        "bin\\x64\\plugins\\cyber_engine_tweaks\\mods\\CyberCompanion\\last_action.json",
        "CyberCompanionBridge\\last_action.json",
        "last_action.json",
        "F:\\projects\\cyber\\last_action.json"
    },
    companionEntity = nil,
    companionID = nil,
    currentPreset = "Panam",
    currentStance = "NORMAL",
    lastProcessedTime = 0,
    checkInterval = 0.25,
    isCompanionActive = false,
    hudMessageTimer = 0,
    lastSpeech = "Системы связи активны. Жду указаний, Ви.",
    lastAction = "NONE",
    apiKeyInput = "pza_T_R95UsT7cfJJiJR8_Wc8o8_tEDgOcGK",
    keySavedMessage = ""
}

-- Пресеты персонажей из сюжетной кампании Cyberpunk 2077
local COMPANION_PRESETS = {
    ["Panam"]    = "Character.Panam",
    ["Judy"]     = "Character.Judy",
    ["Jackie"]   = "Character.Jackie",
    ["Takemura"] = "Character.Takemura",
    ["Reed"]     = "Character.Reed",
    ["Songbird"] = "Character.Songbird"
}

-- ------------------------------------------------------------------------------
--  HUD субтитры и уведомления
-- ------------------------------------------------------------------------------
function mod:ShowSubtitle(speech)
    self.lastSpeech = speech
    print("[Rae AI] " .. speech)
    
    local blackboard = Game.GetBlackboardSystem():Get(GetAllBlackboardDefs().UI_Notifications)
    if blackboard then
        blackboard:SetString(GetAllBlackboardDefs().UI_Notifications.WarningMessage, "Рэй: " .. speech, true)
    end
end

-- ------------------------------------------------------------------------------
--  Поиск и чтение файла команд
-- ------------------------------------------------------------------------------
function mod:GetActiveActionFile()
    for _, path in ipairs(self.actionFiles) do
        local f = io.open(path, "r")
        if f then
            f:close()
            return path
        end
    end
    return self.actionFiles[1]
end

function mod:ReadJsonFile(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    if content and #content > 0 then
        local success, result = pcall(json.decode, content)
        if success then return result end
    end
    return nil
end

function mod:MarkActionProcessed(path, data)
    data.action = "PROCESSED"
    local f = io.open(path, "w")
    if f then
        f:write(json.encode(data))
        f:close()
    end
end

-- ------------------------------------------------------------------------------
--  Спавн и управление напарником в игровом мире
-- ------------------------------------------------------------------------------
function mod:SpawnCompanion(presetName)
    local player = Game.GetPlayer()
    if not player then return end

    presetName = presetName or self.currentPreset
    local recordString = COMPANION_PRESETS[presetName] or "Character.Panam"
    local recordID = TweakDBID.new(recordString)

    self:DespawnCompanion()

    local playerPos = player:GetWorldPosition()
    local forward = player:GetWorldForward()
    local spawnPos = Vector4.new(playerPos.x - forward.x * 2.0, playerPos.y - forward.y * 2.0, playerPos.z, 1.0)
    local spawnEuler = EulerAngles.new(0, 0, player:GetWorldOrientation():ToEulerAngles().yaw)

    local transform = WorldTransform.new()
    transform:SetPosition(spawnPos)
    transform:SetOrientationEuler(spawnEuler)

    local spawnSystem = Game.GetPreventionSpawnSystem()
    if spawnSystem then
        spawnSystem:RequestSpawn(recordID, -1, transform)
        self.isCompanionActive = true
        self.currentPreset = presetName
        print("[Rae AI] Запрошен спавн персонажа " .. presetName)
        self:ShowSubtitle("Подключилась к каналу, Ви. Я на позиции!")
    end
end

function mod:BindTargetAsCompanion()
    local player = Game.GetPlayer()
    if not player then return end
    local target = Game.GetTargetingSystem():GetLookAtObject(player, false, false)
    if target and target:IsA("NPCPuppet") then
        self.companionEntity = target
        self.companionID = target:GetEntityID()
        self.isCompanionActive = true
        self:SetFollowerAI(target)
        self:ShowSubtitle("Цель перехвачена. Теперь я в твоем распоряжении, Ви!")
    else
        self:ShowSubtitle("В прицеле нет подходящего NPC для привязки!")
    end
end

function mod:DespawnCompanion()
    if self.companionEntity then
        Game.GetPreventionSpawnSystem():RequestDespawn(self.companionEntity:GetEntityID())
        self.companionEntity = nil
        self.companionID = nil
        self.isCompanionActive = false
    end
end

function mod:SetFollowerAI(puppet)
    if not puppet then return end
    pcall(function()
        local role = AIFollowerRole.new()
        role.followerRef = Game.CreateEntityReference("#player", nil)
        role.attitudeGroupName = CName.new("player")
        AIComponent.SetAIRole(puppet, role)
    end)
end

function mod:TeleportCompanionToPlayer()
    local player = Game.GetPlayer()
    if not player then return end
    if not self.companionEntity then return end

    local playerPos = player:GetWorldPosition()
    local forward = player:GetWorldForward()
    local targetPos = Vector4.new(playerPos.x - forward.x * 1.5, playerPos.y - forward.y * 1.5, playerPos.z, 1.0)
    Game.GetTeleportationFacility():Teleport(self.companionEntity, targetPos, player:GetWorldOrientation())
    self:ShowSubtitle("Перегруппировалась. Я прямо за тобой!")
end

-- ------------------------------------------------------------------------------
--  Команды: Взломы, Спасение, Авто, Двери, Стойки
-- ------------------------------------------------------------------------------
function mod:ExecuteOverheat(target)
    if not target then
        self:ShowSubtitle("Наведи прицел на врага для перегрева!")
        return
    end
    Game.GetStatusEffectSystem():ApplyStatusEffect(target:GetEntityID(), TDBID.Create("BaseStatusEffect.Burning"))
    Game.GetStatusEffectSystem():ApplyStatusEffect(target:GetEntityID(), TDBID.Create("BaseStatusEffect.Overheat"))
end

function mod:ExecuteWeaponGlitch(target)
    if not target then
        self:ShowSubtitle("Цель не захвачена для взлома стволов!")
        return
    end
    Game.GetStatusEffectSystem():ApplyStatusEffect(target:GetEntityID(), TDBID.Create("BaseStatusEffect.WeaponJam"))
    Game.GetStatusEffectSystem():ApplyStatusEffect(target:GetEntityID(), TDBID.Create("BaseStatusEffect.WeaponGlitch"))
end

function mod:ExecuteCyberwareMalfunction(target)
    if not target then
        self:ShowSubtitle("Наведи ствол, чтобы вырубить импланты цели!")
        return
    end
    Game.GetStatusEffectSystem():ApplyStatusEffect(target:GetEntityID(), TDBID.Create("BaseStatusEffect.CyberwareMalfunction"))
end

function mod:ExecuteDisableCameras()
    local player = Game.GetPlayer()
    if not player then return end
    local targetSys = Game.GetTargetingSystem()
    local lookObj = targetSys:GetLookAtObject(player, false, false)
    if lookObj and lookObj:IsA("SensorDevice") then
        pcall(function() lookObj:GetDevicePS():SetDeviceState(EDeviceStatus.OFF) end)
    end
    self:ShowSubtitle("Камеры в секторе заглушены. Сетка слепа!")
end

function mod:ExecuteDisableTurrets()
    local player = Game.GetPlayer()
    if not player then return end
    local targetSys = Game.GetTargetingSystem()
    local lookObj = targetSys:GetLookAtObject(player, false, false)
    if lookObj and (lookObj:IsA("Turret") or lookObj:IsA("SecurityTurret")) then
        pcall(function() lookObj:GetDevicePS():SetDeviceState(EDeviceStatus.OFF) end)
    end
    self:ShowSubtitle("Турели обесточены, чoomba! Дорога свободна!")
end

function mod:ExecutePingNetwork()
    local player = Game.GetPlayer()
    if not player then return end
    local target = Game.GetTargetingSystem():GetLookAtObject(player, false, false)
    if target then
        Game.GetStatusEffectSystem():ApplyStatusEffect(target:GetEntityID(), TDBID.Create("BaseStatusEffect.Ping"))
    end
    self:ShowSubtitle("Пропинговала сеть. Враги подсвечены сквозь стены!")
end

function mod:ExecuteCoverMe()
    local player = Game.GetPlayer()
    if not player then return end
    local target = Game.GetTargetingSystem():GetLookAtObject(player, false, false)
    if target then
        Game.GetStatusEffectSystem():ApplyStatusEffect(target:GetEntityID(), TDBID.Create("BaseStatusEffect.Suppressed"))
    end
    self:ShowSubtitle("Заливаю сектор свинцом! Лечись, я прикрою!")
end

function mod:ExecuteRevivePlayer()
    local player = Game.GetPlayer()
    if not player then return end
    local playerID = player:GetEntityID()
    Game.GetStatPoolsSystem():RequestSettingStatPoolValue(playerID, gamedataStatPoolType.Health, 80.0, player)
    Game.GetStatusEffectSystem():ApplyStatusEffect(playerID, TDBID.Create("BaseStatusEffect.MaxDocImmediate"))
    self:ShowSubtitle("Вколола стимулятор! Пульс в норме, вставай, Ви!")
end

function mod:ExecuteForceOpenDoor()
    local player = Game.GetPlayer()
    if not player then return end
    local target = Game.GetTargetingSystem():GetLookAtObject(player, false, false)
    if target and target:IsA("Door") then
        pcall(function()
            local ps = target:GetDevicePS()
            if ps then
                ps:SetIsLocked(false)
                ps:ForceOpen()
            end
        end)
        self:ShowSubtitle("Замок взломан в обход системы! Проходи!")
    else
        self:ShowSubtitle("Наведи прицел на дверь или терминал!")
    end
end

function mod:ExecuteVehicleCombat(mode)
    local player = Game.GetPlayer()
    if not player then return end
    local target = Game.GetTargetingSystem():GetLookAtObject(player, false, false)

    if mode == "TIRES" then
        if target and target:IsA("VehicleObject") then
            pcall(function() target:DestructTire(0) target:DestructTire(1) end)
            self:ShowSubtitle("Пробила им колеса! Машина идет юзом!")
        else
            self:ShowSubtitle("Стреляю по шинам преследователей!")
        end
    else
        self:ShowSubtitle("Целюсь в лобовуху, снимаю водителя!")
    end
end

function mod:SetStance(stance)
    self.currentStance = stance
    if stance == "GHOST" then
        self:ShowSubtitle("Режим «Призрак» активирован. Иду тихо, не шумим.")
    elseif stance == "BERSERK" then
        self:ShowSubtitle("Режим «Мясорубка»! Крошим всех в фарш!")
    elseif stance == "OVERWATCH" then
        self:ShowSubtitle("Режим «Снайпер». Держу дистанцию 20 метров.")
    else
        self:ShowSubtitle("Стандартный режим сопровождения.")
    end
end

function mod:ExecuteAction(actionData)
    local action = actionData.action
    local speech = actionData.speech or ""
    self.lastAction = action

    local player = Game.GetPlayer()
    local target = nil
    if player then
        target = Game.GetTargetingSystem():GetLookAtObject(player, false, false)
    end

    if speech and #speech > 0 then
        self:ShowSubtitle(speech)
    end

    if action == "HACK_OVERHEAT" then self:ExecuteOverheat(target)
    elseif action == "HACK_WEAPON_GLITCH" then self:ExecuteWeaponGlitch(target)
    elseif action == "HACK_CYBERWARE_MALFUNCTION" then self:ExecuteCyberwareMalfunction(target)
    elseif action == "HACK_DISABLE_CAMERAS" then self:ExecuteDisableCameras()
    elseif action == "HACK_DISABLE_TURRETS" then self:ExecuteDisableTurrets()
    elseif action == "HACK_PING_NETWORK" then self:ExecutePingNetwork()
    elseif action == "COVER_ME" then self:ExecuteCoverMe()
    elseif action == "REVIVE_PLAYER" then self:ExecuteRevivePlayer()
    elseif action == "FORCE_OPEN_DOOR" then self:ExecuteForceOpenDoor()
    elseif action == "VEHICLE_COMBAT_TIRES" then self:ExecuteVehicleCombat("TIRES")
    elseif action == "VEHICLE_COMBAT_DRIVER" then self:ExecuteVehicleCombat("DRIVER")
    elseif action == "SET_STANCE_GHOST" then self:SetStance("GHOST")
    elseif action == "SET_STANCE_BERSERK" then self:SetStance("BERSERK")
    elseif action == "SET_STANCE_OVERWATCH" then self:SetStance("OVERWATCH")
    elseif action == "REGROUP" then self:TeleportCompanionToPlayer()
    elseif action == "FOLLOW" then self:ShowSubtitle("Держусь рядом, веди!")
    elseif action == "HOLD_POSITION" then self:ShowSubtitle("Остаюсь на точке.")
    elseif action == "ENTER_VEHICLE" then self:ShowSubtitle("Прыгаю на пассажирское, погнали!")
    elseif action == "EXIT_VEHICLE" then self:ShowSubtitle("Высаживаюсь, держу ствол наготове.")
    end
end

registerForEvent("onInit", function()
    print("[Cyber Companion Rae] Мод успешно запущен в Cyberpunk 2077 v" .. mod.version)
end)

registerForEvent("onUpdate", function(delta)
    mod.lastProcessedTime = mod.lastProcessedTime + delta
    if mod.lastProcessedTime >= mod.checkInterval then
        mod.lastProcessedTime = 0
        local activePath = mod:GetActiveActionFile()
        local data = mod:ReadJsonFile(activePath)
        if data and data.action and data.action ~= "PROCESSED" then
            mod:ExecuteAction(data)
            mod:MarkActionProcessed(activePath, data)
        end
    end
end)

-- ------------------------------------------------------------------------------
--  CET ImGui Overlay UI
-- ------------------------------------------------------------------------------
registerForEvent("onDraw", function()
    ImGui.SetNextWindowSize(480, 520, ImGuiCond.FirstUseEver)
    if ImGui.Begin("CYBER COMPANION: RAE (AI BRIDGE)") then
        ImGui.TextColored(0.2, 0.8, 1.0, 1.0, "=== AI COMPANION SYSTEM v" .. mod.version .. " ===")
        ImGui.Separator()

        -- Статус
        if mod.isCompanionActive then
            ImGui.TextColored(0.2, 1.0, 0.2, 1.0, "Статус напарника: АКТИВЕН (" .. mod.currentPreset .. ")")
        else
            ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "Статус напарника: НЕ ПРИЗВАН")
        end
        ImGui.Text("Стойка: " .. mod.currentStance .. " | Последнее действие: " .. mod.lastAction)
        ImGui.Separator()

        -- Спавн
        ImGui.Text("Выбор персонажа:")
        for name, _ in pairs(COMPANION_PRESETS) do
            if ImGui.Button(name) then mod:SpawnCompanion(name) end
            ImGui.SameLine()
        end
        ImGui.NewLine()

        if ImGui.Button("Привязать NPC под прицелом") then mod:BindTargetAsCompanion() end
        ImGui.SameLine()
        if ImGui.Button("Телепорт ко мне") then mod:TeleportCompanionToPlayer() end

        ImGui.Separator()
        ImGui.Text("Стойки боевого поведения:")
        if ImGui.Button("Призрак (Стелс)") then mod:SetStance("GHOST") end
        ImGui.SameLine()
        if ImGui.Button("Берсерк (Штурм)") then mod:SetStance("BERSERK") end
        ImGui.SameLine()
        if ImGui.Button("Снайпер") then mod:SetStance("OVERWATCH") end

        ImGui.Separator()
        ImGui.Text("Тест команд (без микрофона):")
        local player = Game.GetPlayer()
        local target = player and Game.GetTargetingSystem():GetLookAtObject(player, false, false) or nil
        if ImGui.Button("Перегрев") then mod:ExecuteOverheat(target) end
        ImGui.SameLine()
        if ImGui.Button("Вырубить камеры") then mod:ExecuteDisableCameras() end
        ImGui.SameLine()
        if ImGui.Button("Вколоть стим") then mod:ExecuteRevivePlayer() end
        ImGui.SameLine()
        if ImGui.Button("Вскрыть дверь") then mod:ExecuteForceOpenDoor() end

        ImGui.Separator()
        ImGui.TextColored(1.0, 1.0, 0.4, 1.0, "Радиоканал Рэй:")
        ImGui.TextWrapped(mod.lastSpeech)

        ImGui.Separator()
        ImGui.Text("Настройка API ключа (сохранение в .env):")
        mod.apiKeyInput = ImGui.InputText("Ключ", mod.apiKeyInput, 128)
        if ImGui.Button("Сохранить ключ") then
            local paths = {
                "bin\\x64\\plugins\\cyber_engine_tweaks\\mods\\CyberCompanion\\.env",
                "F:\\projects\\cyber\\.env"
            }
            for _, p in ipairs(paths) do
                local f = io.open(p, "w")
                if f then
                    f:write("POLZA_API_KEY=" .. mod.apiKeyInput .. "\n")
                    f:write("DEEPSEEK_API_KEY=" .. mod.apiKeyInput .. "\n")
                    f:close()
                    mod.keySavedMessage = "Ключ успешно сохранен!"
                end
            end
        end
        if #mod.keySavedMessage > 0 then
            ImGui.SameLine()
            ImGui.TextColored(0.2, 1.0, 0.2, 1.0, mod.keySavedMessage)
        end

        ImGui.End()
    end
end)

return mod
