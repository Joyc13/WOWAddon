-- Variables globales
local frame
local columnHeaders = { "Nom", "Rang", "Date d'arrivée", "Action" }
local filterConnected = false -- Par défaut : afficher tous les membres
local filterEthylotest = false -- Filtre les membres Ethylotest

-- Fonction pour filtrer les membres par statut de connexion
local function FilterMembers(data)
    if filterConnected then
        local filtered = {}
        for _, member in ipairs(data) do
            if member.isOnline then
                table.insert(filtered, member)
            end
        end
        return filtered
    else
        return data
    end
end

-- Fonction pour filtrer les membres ayant le grade "Ethylotest"
local function FilterEthylotestMembers(data)
    if filterEthylotest then
        local filtered = {}
        for _, member in ipairs(data) do
            -- Nettoyage du rang et comparaison insensible à la casse
            local cleanedRank = member.rank and member.rank:match("^%s*(.-)%s*$") or ""
            if string.lower(cleanedRank) == "ethylotest" then
                table.insert(filtered, member)
            end
        end
        return filtered
    else
        return data
    end
end

-- Fonction pour calculer la différence de jours entre deux dates (format JJ/MM/AAAA)
local function DaysBetween(date1, date2)
    local day1, month1, year1 = date1:match("(%d%d)/(%d%d)/(%d%d%d%d)")
    local day2, month2, year2 = date2:match("(%d%d)/(%d%d)/(%d%d%d%d)")
    if not (year1 and month1 and day1 and year2 and month2 and day2) then
        --print("Erreur : une des dates est invalide.", date1, date2)
        return nil -- Retourne nil si les dates ne sont pas valides
    end
    local time1 = time({ year = year1, month = month1, day = day1 })
    local time2 = time({ year = year2, month = month2, day = day2 })
    return math.floor((time2 - time1) / (24 * 60 * 60)) -- Différence en jours
end

-- Fonction pour récupérer les couleurs de classe
local function GetClassColor(classFileName)
    if not classFileName then
        return { r = 1, g = 1, b = 1 } -- Couleur blanche par défaut si aucune classe n'est spécifiée
    end
    local color = RAID_CLASS_COLORS[classFileName]
    if color then
        return { r = color.r, g = color.g, b = color.b }
    else
        return { r = 1, g = 1, b = 1 } -- Couleur blanche par défaut si classe inconnue
    end
end

local function PromoteToAlcoolique(memberName)
    if not IsInGuild() then
        print("Vous devez être dans une guilde pour effectuer cette action.")
        return
    end

    if not memberName or memberName == "" then
        print("Nom de membre invalide.")
        return
    end

    -- Trouver l'index du grade "Alcoolique"
    local targetRankIndex = nil
    local targetRank = "Alcoolique"
    for i = 1, GuildControlGetNumRanks() do
        local rankName = GuildControlGetRankName(i):gsub("^%s*(.-)%s*$", "%1")
        if rankName:lower() == targetRank:lower() then
            targetRankIndex = i
            break
        end
    end

    if not targetRankIndex then
        print("Erreur : Le grade 'Alcoolique' n'existe pas dans la guilde.")
        return
    end

    -- Trouver le membre dans le roster
    local memberIndex = nil
    local currentRankIndex = nil
    local fullMemberName = nil
    for i = 1, GetNumGuildMembers() do
        local fullName, rank, rankIndex = GetGuildRosterInfo(i)
        local shortName = fullName and fullName:match("^(.-)%-") or fullName
        if shortName and shortName:lower() == memberName:lower() or fullName and fullName:lower() == memberName:lower() then
            memberIndex = i
            currentRankIndex = rankIndex
            fullMemberName = fullName -- Conserver le nom complet pour la macro
            break
        end
    end

    if not memberIndex or not currentRankIndex then
        print("Erreur : Membre '" .. memberName .. "' introuvable dans la guilde.")
        return
    end

    -- Générer une macro pour promouvoir ou rétrograder
    local macroText = ""
    if currentRankIndex > targetRankIndex then
        for _ = currentRankIndex, targetRankIndex + 1, -1 do
            macroText = macroText .. "/guilddemote " .. fullMemberName .. "\n"
        end
    elseif currentRankIndex < targetRankIndex then
        for _ = currentRankIndex, targetRankIndex - 1 do
            macroText = macroText .. "/guildpromote " .. fullMemberName .. "\n"
        end
    else
        print(memberName .. " est déjà au grade 'Alcoolique'.")
        return
    end

    -- Vérifier si une macro existe déjà ou créer une nouvelle macro
    local macroName = "PromoteAlcoolique"
    local macroIndex = GetMacroIndexByName(macroName)

    if macroIndex == 0 then
        -- Vérifie qu'il y a de l'espace pour créer une macro
        local numMacros, maxMacros = GetNumMacros()
        if numMacros >= maxMacros then
            print("Erreur : Vous avez atteint le nombre maximum de macros. Supprimez-en une pour continuer.")
            return
        end

        -- Créer une nouvelle macro
        local success = CreateMacro(macroName, "INV_MISC_QUESTIONMARK", macroText, true)
        if success then
            print("Macro 'PromoteAlcoolique' créée avec succès.")
        else
            print("Erreur : Impossible de créer la macro.")
        end
    else
        -- Met à jour une macro existante
        EditMacro(macroIndex, macroName, "INV_MISC_QUESTIONMARK", macroText)
        print("Macro 'PromoteAlcoolique' mise à jour avec succès.")
    end

    print("Ouvrez votre fenêtre de macros pour utiliser la macro créée.")
end



-- Fonction pour mettre à jour les données des membres
local function UpdateGuildInfo()
    if not IsInGuild() then
        print("Vous devez être dans une guilde pour utiliser cet addon.")
        return
    end

    C_GuildInfo.GuildRoster()

    local currentDate = date("%d/%m/%Y") -- Format JJ/MM/AAAA
    local memberData = {}
    for i = 1, GetNumGuildMembers() do
        local name, rank, rankIndex, _, _, _, _, officerNote, isOnline, _, classFileName, _, _, _, lastOnline = GetGuildRosterInfo(i)
        local joinDate = officerNote -- Utilise la note d'officier pour la date d'arrivée
        local daysSinceJoin = joinDate and DaysBetween(joinDate, currentDate) or nil

        -- Débogage pour vérifier les données
        --print(string.format("Membre : %s, Date d'arrivée : %s, Jours : %s", name, joinDate or "Inconnue", daysSinceJoin or "Invalide"))

        table.insert(memberData, {
            name = name,
            rank = rank,
            rankIndex = rankIndex,
            joinDate = joinDate,
            daysSinceJoin = daysSinceJoin,
            isOnline = isOnline,
            classFileName = classFileName -- Ajoute l'identifiant de la classe
        })
    end

	--for i, member in ipairs(memberData) do
    --print(string.format("Membre %d: Nom: %s, Rang: %s", i, member.name or "Inconnu", member.rank or "Inconnu"))
	--/reloadd

    -- Filtrer les membres si nécessaire
    local filteredData = FilterMembers(memberData)
	filteredData = FilterEthylotestMembers(filteredData) -- Filtre par grade
	
    frame:UpdateTable(filteredData)
end

-- Fonction pour initialiser l'interface
local function CreateMainFrame()
    frame = CreateFrame("Frame", "ImInMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(600, 400)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface/CHATFRAME/CHATFRAMEBACKGROUND",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(1, 1, 1, 0.8)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide() -- Masquer la fenêtre au démarrage

	

    -- Bouton de fermeture
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Titre
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("ImIn - Membres de la Guilde")

    -- Cadre du tableau
    local tableFrame = CreateFrame("Frame", nil, frame)
    tableFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -50)
    tableFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 50)

    -- Colonnes du tableau
    local headerFrame = CreateFrame("Frame", nil, tableFrame)
    headerFrame:SetSize(580, 20)
    headerFrame:SetPoint("TOPLEFT", tableFrame, "TOPLEFT")
    for i, header in ipairs(columnHeaders) do
        local column = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        column:SetText(header)
        column:SetPoint("LEFT", headerFrame, "LEFT", (i - 1) * 140, 0)
    end

    -- Cadre défilant pour les lignes du tableau
    local scrollFrame = CreateFrame("ScrollFrame", nil, tableFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, -20)
    scrollFrame:SetPoint("BOTTOMRIGHT", tableFrame, "BOTTOMRIGHT")
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(560, 1000)
    scrollFrame:SetScrollChild(scrollChild)
    frame.ScrollChild = scrollChild

    -- Fonction pour mettre à jour le tableau
    frame.UpdateTable = function(_, data)
        -- Supprime les anciennes lignes
        for _, child in ipairs({scrollChild:GetChildren()}) do
            child:Hide()
            child:SetParent(nil)
        end

        -- Ajoute les nouvelles lignes
        local rowHeight = 20
        for i, member in ipairs(data) do
            local row = CreateFrame("Frame", nil, scrollChild)
            row:SetSize(560, rowHeight)
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((i - 1) * rowHeight))

            -- Applique la couleur de la classe
            local classColor = GetClassColor(member.classFileName)
            if type(classColor) ~= "table" then
                classColor = { r = 1, g = 1, b = 1 } -- Couleur blanche par défaut
            end

            local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            name:SetText(member.name)
            name:SetPoint("LEFT", row, "LEFT", 0, 0)
            name:SetTextColor(classColor.r, classColor.g, classColor.b)

            local rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            rank:SetText(member.rank)
            rank:SetPoint("LEFT", row, "LEFT", 140, 0)
            rank:SetTextColor(classColor.r, classColor.g, classColor.b)

            local joinDate = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            joinDate:SetText(member.joinDate or "Inconnue")
            joinDate:SetPoint("LEFT", row, "LEFT", 280, 0)
            joinDate:SetTextColor(classColor.r, classColor.g, classColor.b)

            if member.daysSinceJoin and member.daysSinceJoin < 15 then
                local actionButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                actionButton:SetSize(80, 18)
                actionButton:SetPoint("LEFT", row, "LEFT", 420, 0)
                actionButton:SetText("Changer")
                actionButton:SetScript("OnClick", function()
                    PromoteToAlcoolique(member.name) -- Change le grade du membre
                end)
            end
        end
    end

    -- Case à cocher pour filtrer les connectés
    local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    checkbox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    checkbox.text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    checkbox.text:SetText("Afficher connectés uniquement")
    checkbox:SetScript("OnClick", function(self)
        filterConnected = self:GetChecked()
        UpdateGuildInfo()
    end)
	
	-- Ajoute la case à cocher pour filtrer par grade "Ethylotest"
local function AddEthylotestFilterCheckbox(frame)
    local ethylotestCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    ethylotestCheckbox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    ethylotestCheckbox.text = ethylotestCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ethylotestCheckbox.text:SetPoint("LEFT", ethylotestCheckbox, "RIGHT", 5, 0)
    ethylotestCheckbox.text:SetText("Filtrer 'Ethylotest'")
    ethylotestCheckbox:SetScript("OnClick", function(self)
        filterEthylotest = self:GetChecked()
        UpdateGuildInfo()
    end)
end

AddEthylotestFilterCheckbox(frame)

end

-- Commande pour ouvrir/fermer l'interface
SLASH_IMIN1 = "/imin"
SlashCmdList["IMIN"] = function()
    if not frame then
        CreateMainFrame()
    end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        UpdateGuildInfo()
    end
end

-- Gestion des événements
local addon = CreateFrame("Frame")
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("GUILD_ROSTER_UPDATE")
addon:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "ImIn" then
        CreateMainFrame()
    elseif event == "GUILD_ROSTER_UPDATE" then
        UpdateGuildInfo()
    end
end)
