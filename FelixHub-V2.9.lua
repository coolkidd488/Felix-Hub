--[[
╔══════════════════════════════════════════════════════════╗
║               FELIX HUB v2.9 - DOORS EDITION             ║
╚══════════════════════════════════════════════════════════╝
  v2.9 — Diagnóstico completo + proteções máximas
]]

-- ══════════════════════════════════════
--  MODO DEBUG — mude para false depois
-- ══════════════════════════════════════
local DEBUG = true
local function Log(msg)
    if DEBUG then print("[FelixHub] " .. tostring(msg)) end
end
local function Erro(msg, err)
    warn("[FelixHub ERRO] " .. tostring(msg) .. ": " .. tostring(err))
end

-- ══════════════════
--  ANTI-DUPLICAÇÃO
-- ══════════════════
if _G.FelixHubCarregado then
    Log("Ja carregado, abortando.")
    return
end
_G.FelixHubCarregado = true
Log("=== INICIANDO v2.9 ===")

-- ══════════════════
--  SERVIÇOS
-- ══════════════════
Log("Carregando servicos...")

local Players, RunService, TweenService, UserInputService, StarterGui, Lighting, CoreGui

do
    local ok, err = pcall(function()
        Players          = game:GetService("Players")
        RunService       = game:GetService("RunService")
        TweenService     = game:GetService("TweenService")
        UserInputService = game:GetService("UserInputService")
        StarterGui       = game:GetService("StarterGui")
        Lighting         = game:GetService("Lighting")
        CoreGui          = game:GetService("CoreGui")
    end)
    if not ok then Erro("Servicos", err); _G.FelixHubCarregado=nil; return end
end
Log("Servicos OK")

-- ══════════════════
--  LOCAL PLAYER
-- ══════════════════
local LP = Players.LocalPlayer
if not LP then
    warn("[FelixHub ERRO] LocalPlayer nulo")
    _G.FelixHubCarregado = nil
    return
end
Log("LocalPlayer: " .. LP.Name)

local Camera = workspace.CurrentCamera
if not Camera then
    warn("[FelixHub ERRO] Camera nula")
    _G.FelixHubCarregado = nil
    return
end
Log("Camera OK")

-- ══════════════════════════════
--  GUIPARENT — CoreGui ou PlayerGui
-- ══════════════════════════════
Log("Detectando GuiParent...")
local GuiParent = nil

-- Tenta CoreGui primeiro
local okCG, errCG = pcall(function()
    local t = Instance.new("ScreenGui")
    t.Parent = CoreGui
    t:Destroy()
    GuiParent = CoreGui
end)
if not okCG then
    Erro("CoreGui bloqueado", errCG)
    -- Fallback para PlayerGui com timeout
    local okPG, pg = pcall(function()
        return LP:WaitForChild("PlayerGui", 5)
    end)
    if okPG and pg then
        GuiParent = pg
        Log("Usando PlayerGui como fallback")
    else
        Erro("PlayerGui tambem falhou", tostring(pg))
        _G.FelixHubCarregado = nil
        return
    end
end

if not GuiParent then
    warn("[FelixHub ERRO] GuiParent e nil")
    _G.FelixHubCarregado = nil
    return
end
Log("GuiParent: " .. GuiParent.Name)

-- ══════════════════
--  CONFIG
-- ══════════════════
local Cfg = {
    ESP_Ativo=true,   HL_Ativo=true,    BB_Ativo=true,
    Dist_Ativo=true,  Aviso_Ativo=true,
    ESP_Portas=true,  ESP_Chaves=true,  ESP_Alavancas=true,
    ESP_Livros=true,  ESP_Figure=true,  ESP_Screech=true,
    ESP_Itens=true,   ESP_Baus=true,    ESP_Fusiveis=true,
    RemoverScreech=true, NotifPortas=true,
    ProtecaoEyes=false,  AutoGaveta=false,
    WalkSpeedValor=16,   JumpPowerValor=50,
    cPorta   = Color3.fromRGB(255,215,  0),
    cChave   = Color3.fromRGB( 30,144,255),
    cAlavanca= Color3.fromRGB(255,140,  0),
    cLivro   = Color3.fromRGB(160, 32,240),
    cFigure  = Color3.fromRGB(220, 20, 60),
    cScreech = Color3.fromRGB(200,  0,  0),
    cItem    = Color3.fromRGB( 50,220,100),
    cBau     = Color3.fromRGB(200,170, 20),
    cFusivel = Color3.fromRGB(255,100,  0),
    cPerigo  = Color3.fromRGB(255, 30, 30),
    MaxDist=500, DistInt=0.25,
}

local Estado  = {ProcurandoFigure=false, ProcurandoLivros=false, LivrosN=0}
local Cache   = {}
local BBCache = {}
local EntCache= {}

-- ══════════════════
--  UTILS
-- ══════════════════
local function Notif(titulo, msg, dur)
    local ok, err = pcall(function()
        StarterGui:SetCore("SendNotification",{
            Title=titulo, Text=msg, Duration=dur or 4
        })
    end)
    if not ok then Erro("Notif", err) end
end

local function TW(obj, info, props)
    if not obj then return end
    local ok, err = pcall(function()
        TweenService:Create(obj, info, props):Play()
    end)
    if not ok then Erro("TW", err) end
end

-- Retorna BasePart válida de um objeto
local function GetPart(obj)
    if not obj then return nil end
    if not obj.Parent then return nil end
    local ok, result = pcall(function()
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Model") then
            if obj.PrimaryPart then return obj.PrimaryPart end
            for _,v in ipairs(obj:GetDescendants()) do
                if v:IsA("BasePart") then return v end
            end
        end
        return nil
    end)
    if ok then return result end
    return nil
end

-- Item diretamente solto no mapa (não dentro de gaveta/móvel)
local function ItemSolto(obj)
    if not obj then return false end
    local p = obj.Parent
    if not p then return false end
    if tonumber(p.Name) ~= nil then return true end
    if p.Name == "CurrentRooms" then return true end
    if p == workspace then return true end
    return false
end

-- ══════════════════
--  BILLBOARD
-- ══════════════════
local function LimparBB(uid)
    local e = BBCache[uid]
    if e then
        pcall(function() e.gui:Destroy() end)
        pcall(function() e.conn:Disconnect() end)
        BBCache[uid] = nil
    end
    if GuiParent then
        local g = GuiParent:FindFirstChild(uid)
        if g then pcall(function() g:Destroy() end) end
    end
end

local function CriarBB(obj, txt, cor)
    if not Cfg.BB_Ativo then return end
    if not obj then return end

    local parte = GetPart(obj)
    if not parte then return end

    local uid = "BB_" .. obj:GetFullName():gsub("[^%w]","_")
    LimparBB(uid)

    -- Criar BillboardGui diretamente
    local bbg = Instance.new("BillboardGui")
    bbg.Name = uid
    bbg.AlwaysOnTop = true
    bbg.LightInfluence = 0
    bbg.MaxDistance = Cfg.MaxDist
    bbg.Size = UDim2.new(0,100,0,22)
    bbg.StudsOffset = Vector3.new(0,3,0)
    bbg.Adornee = parte

    local okP, errP = pcall(function() bbg.Parent = GuiParent end)
    if not okP then Erro("BB Parent", errP); bbg:Destroy(); return end

    local fr = Instance.new("Frame")
    fr.BackgroundColor3 = Color3.fromRGB(8,8,12)
    fr.BackgroundTransparency = 0.2
    fr.Size = UDim2.new(1,0,1,0)
    fr.BorderSizePixel = 0
    fr.Parent = bbg

    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0,4)
        c.Parent = fr
        local s = Instance.new("UIStroke")
        s.Color = cor; s.Thickness = 1; s.Parent = fr
    end

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = false
    lbl.TextSize = 11
    lbl.TextColor3 = cor
    lbl.TextStrokeColor3 = Color3.new(0,0,0)
    lbl.TextStrokeTransparency = 0.3
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Text = txt
    lbl.Parent = fr

    local ult = 0
    local conn = RunService.Heartbeat:Connect(function()
        if not bbg or not bbg.Parent then return end
        local ag = tick()
        if ag - ult < Cfg.DistInt then return end
        ult = ag
        local ok2, err2 = pcall(function()
            if not parte or not parte.Parent then return end
            if Cfg.Dist_Ativo then
                local d = math.floor((Camera.CFrame.Position - parte.Position).Magnitude)
                lbl.Text = txt .. " " .. d .. "m"
            else
                lbl.Text = txt
            end
        end)
        if not ok2 then Erro("BB update", err2) end
    end)

    BBCache[uid] = {gui=bbg, conn=conn}

    -- Limpa quando objeto some
    local ok3, err3 = pcall(function()
        obj.AncestryChanged:Connect(function()
            if not obj:IsDescendantOf(game) then
                LimparBB(uid)
                Cache[obj:GetFullName()] = nil
            end
        end)
    end)
    if not ok3 then Erro("BB AncestryChanged", err3) end
end

-- ══════════════════
--  ESP
-- ══════════════════
local function ESP(obj, cor, txt)
    if not obj then return end
    if not obj.Parent then return end

    local uid = obj:GetFullName()
    if Cache[uid] then return end
    Cache[uid] = true

    -- Highlight
    if Cfg.HL_Ativo then
        local ok, err = pcall(function()
            local ha = obj:FindFirstChild("FHL")
            if ha then ha:Destroy() end
            local hl = Instance.new("Highlight")
            hl.Name = "FHL"
            hl.Adornee = obj
            hl.FillColor = cor
            hl.FillTransparency = 0.55
            hl.OutlineColor = Color3.fromRGB(255,255,255)
            hl.OutlineTransparency = 0.1
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Enabled = true
            hl.Parent = obj
            TW(hl,
                TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                {FillTransparency=0.78}
            )
            obj.AncestryChanged:Connect(function()
                if not obj:IsDescendantOf(game) then
                    pcall(function() hl:Destroy() end)
                    Cache[uid] = nil
                end
            end)
        end)
        if not ok then Erro("Highlight", err) end
    end

    -- Billboard
    if Cfg.BB_Ativo then
        local ok, err = pcall(CriarBB, obj, txt, cor)
        if not ok then Erro("Billboard", err) end
    end
end

-- ══════════════════
--  ENTIDADES
-- ══════════════════
local EntMap = {
    Rush         = {l="RUSH!",    n="RUSH vindo! ESCONDA-SE!",  c=Color3.fromRGB(255,40, 40)},
    RushMoving   = {l="RUSH!",    n="RUSH vindo! ESCONDA-SE!",  c=Color3.fromRGB(255,40, 40)},
    Ambush       = {l="AMBUSH!",  n="AMBUSH! Fique escondido!", c=Color3.fromRGB(255,120, 0)},
    AmbushMoving = {l="AMBUSH!",  n="AMBUSH! Fique escondido!", c=Color3.fromRGB(255,120, 0)},
    Halt         = {l="HALT!",    n="Halt apareceu!",           c=Color3.fromRGB(255,200, 0)},
    HaltMoving   = {l="HALT!",    n="Halt apareceu!",           c=Color3.fromRGB(255,200, 0)},
    SeekRig      = {l="SEEK!",    n="Seek apareceu!",           c=Color3.fromRGB(200,  0,200)},
    Eyes         = {l="EYES!",    n="Eyes! Nao olhe para ele!", c=Color3.fromRGB(255, 80, 80)},
    LockmanRig   = {l="LOCKMAN!", n="Lockman apareceu!",        c=Color3.fromRGB(100,200,255)},
    Lockman      = {l="LOCKMAN!", n="Lockman apareceu!",        c=Color3.fromRGB(100,200,255)},
    Timothy      = {l="TIMOTHY!", n="Timothy apareceu!",        c=Color3.fromRGB(180,100,255)},
    ElGoblino    = {l="GOBLINO!", n="El Goblino apareceu!",     c=Color3.fromRGB(100,255,100)},
}

local function ProcessarEntidade(obj)
    if not Cfg.Aviso_Ativo then return end
    if not obj then return end
    local info = EntMap[obj.Name]
    if not info then return end
    local uid = obj:GetFullName()
    if EntCache[uid] then return end
    EntCache[uid] = true

    local ok, err = pcall(function()
        local ha = obj:FindFirstChild("FHL")
        if ha then ha:Destroy() end
        local hl = Instance.new("Highlight")
        hl.Name = "FHL"; hl.Adornee = obj
        hl.FillColor = info.c; hl.FillTransparency = 0.4
        hl.OutlineColor = Color3.fromRGB(255,50,50); hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Enabled = true; hl.Parent = obj
        obj.AncestryChanged:Connect(function()
            if not obj:IsDescendantOf(game) then
                pcall(function() hl:Destroy() end)
                EntCache[uid] = nil
            end
        end)
    end)
    if not ok then Erro("Entidade HL", err) end

    local ok2, err2 = pcall(CriarBB, obj, info.l, info.c)
    if not ok2 then Erro("Entidade BB", err2) end

    Notif("AVISO: " .. obj.Name, info.n, 5)
    Log("Entidade detectada: " .. obj.Name)
end

-- ══════════════════
--  PROCESSADORES
-- ══════════════════
local function PChave(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Chaves then return end
    local ok, err = pcall(ESP, o, Cfg.cChave, "CHAVE")
    if not ok then Erro("PChave", err) end
end

local function PAlavanca(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Alavancas then return end
    local alvo = o:FindFirstChild("Main") or o
    local ok, err = pcall(ESP, alvo, Cfg.cAlavanca, "ALAVANCA")
    if not ok then Erro("PAlavanca", err) end
end

local function ScanLivros()
    if not Estado.ProcurandoLivros then return end
    -- Evita rodar múltiplas vezes ao mesmo tempo
    Estado.ProcurandoLivros = false
    Log("Scan de livros iniciado em game:GetDescendants()...")
    local total = 0
    local encontrados = 0
    local ok, err = pcall(function()
        for _,o in ipairs(game:GetDescendants()) do
            if o and o.Name == "LiveHintBook" then
                total = total + 1
                local uid = o:GetFullName()
                -- NÃO marca cache aqui — deixa ESP() fazer isso
                if not Cache[uid] then
                    encontrados = encontrados + 1
                    -- Todos os livros recebem label "LIVRO" simples
                    -- O ESP() vai marcar o cache internamente
                    pcall(ESP, o, Cfg.cLivro, "LIVRO")
                    Log("Livro encontrado: " .. uid)
                end
            end
        end
    end)
    if not ok then Erro("ScanLivros", err) end
    Log("Scan concluido. LiveHintBook no mapa: " .. total .. " | Novos ESP: " .. encontrados)
    if total == 0 then
        Notif("Livros","Nenhum encontrado ainda.",4)
    else
        Notif("Livros", encontrados .. " livros marcados! Total: " .. total, 5)
    end
end

local function PLivro(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Livros then return end
    if not Estado.ProcurandoLivros then return end
    if not o then return end
    -- ESP() cuida do cache internamente
    pcall(ESP, o, Cfg.cLivro, "LIVRO")
end

local function PFigure(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Figure then return end
    if not Estado.ProcurandoFigure then return end
    if not o or o.Name ~= "FigureRig" then return end
    if Cache[o:GetFullName()] then return end
    Estado.ProcurandoFigure = false
    pcall(ESP, o, Cfg.cFigure, "FIGURE!")
    if Cfg.Aviso_Ativo then Notif("PERIGO!","Figure apareceu!",6) end
    Log("Figure detectado!")
end

local function PScreech(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Screech then return end
    if not o then return end
    if Cfg.RemoverScreech then
        local ok, err = pcall(function() o:Destroy() end)
        if not ok then Erro("RemoverScreech", err) end
        Notif("Felix Hub","Screech removido!",3)
        return
    end
    pcall(ESP, o, Cfg.cScreech, "SCREECH!")
    if Cfg.Aviso_Ativo then Notif("SCREECH!","Olhe para ele!",4) end
end

local NItens = {
    Flashlight="LANTERNA", Lighter="ISQUEIRO",  Vitamins="VITAMINA",
    Lockpick="LOCKPICK",   Bandage="BANDAGEM",   Crucifix="CRUCIFIXO",
    GreenSoup="SOPA",      GreenHerb="ERVA",     Candle="VELA",
    RedVial="POCAO",       Battery="PILHA",       Coins="MOEDAS",
}
local function PItem(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Itens then return end
    if not o then return end
    local label = NItens[o.Name]
    if not label then return end
    if not ItemSolto(o) then return end
    pcall(ESP, o, Cfg.cItem, label)
end

local NBaus = {
    Chest="BAU", GoldChest="BAU DOURADO",
    CraftChest="BAU CRAFT", LockedChest="BAU TRANCADO",
}
local function PBau(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Baus then return end
    if not o then return end
    local label = NBaus[o.Name]
    if not label then return end
    pcall(ESP, o, Cfg.cBau, label)
end

local NFus = {Fuse=true, FuseSocket=true, FuseSlot=true}
local function PFusivel(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Fusiveis then return end
    if not o or not NFus[o.Name] then return end
    pcall(ESP, o, Cfg.cFusivel, "FUSIVEL")
end

local function PPorta(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Portas then return end
    if not o then return end
    local sala = o.Parent
    local prof = 0
    while sala and sala ~= workspace and prof < 12 do
        if tonumber(sala.Name) then break end
        sala = sala.Parent
        prof = prof + 1
    end
    local ni = sala and tonumber(sala.Name)
    if not ni then return end
    local nv = ni + 1
    local uid = "Porta_" .. ni
    if Cache[uid] then return end
    Cache[uid] = true
    local alvo = o
    pcall(function()
        local df = sala:FindFirstChild("Door")
        if df then
            local dp = df:FindFirstChild("Door")
            if dp then alvo = dp end
        end
    end)
    pcall(ESP, alvo, Cfg.cPorta, "PORTA "..nv)
    if Cfg.NotifPortas then Notif("Porta","Proxima: "..nv,3) end
    Log("Porta detectada: " .. nv)
    if ni == 49 then
        Estado.ProcurandoFigure = true
        for k in pairs(Cache) do
            if k:find("LiveHintBook") or k:find("FigureRig") then Cache[k]=nil end
        end
        Estado.ProcurandoLivros = true
        task.delay(0.5, ScanLivros)
        Notif("Sala 50!","Buscando livros e Figure...",5)
        Log("Sala 50 detectada!")
    end
end

-- ══════════════════
--  ROTEADOR
-- ══════════════════
local function Rotear(o)
    if not o then return end
    local ok, err = pcall(function()
        if not o.Parent then return end
        local n = o.Name
        -- Entidades (cache separado)
        if EntMap[n]         then ProcessarEntidade(o) end
        -- Objetos de sala
        if n=="FigureRig"    then PFigure(o)   return end
        if n=="ScreechRig"   then PScreech(o)  return end
        if n=="KeyObtain"    then PChave(o)    return end
        if n=="LeverForGate" then PAlavanca(o) return end
        if n=="LiveHintBook" then PLivro(o)    return end
        if n=="ClientOpen"   then PPorta(o)    return end
        -- Itens
        if NItens[n]         then PItem(o)     return end
        if NBaus[n]          then PBau(o)      return end
        if NFus[n]           then PFusivel(o)  return end
    end)
    if not ok then Erro("Rotear "..tostring(o and o.Name), err) end
end

local function IniciarESP()
    Log("ESP iniciado")
    task.spawn(function()
        local ok, err = pcall(function()
            for _,o in ipairs(game:GetDescendants()) do
                task.spawn(Rotear, o)
            end
        end)
        if not ok then Erro("Scan inicial", err) end
    end)
    local ok, err = pcall(function()
        game.DescendantAdded:Connect(function(o)
            task.spawn(Rotear, o)
        end)
    end)
    if not ok then Erro("DescendantAdded", err) end
    Log("ESP conectado")
end

-- ══════════════════
--  AUTO-GAVETA
-- ══════════════════
local GavetaConn = nil
local GavetaNomes = {
    Drawer=true, Dresser=true, Cabinet=true,
    Nightstand=true, Desk=true, Wardrobe=true,
}
local ColetaNomes = {Coins=true, Battery=true, Gold=true, Money=true}

local function TentarColetar(o)
    if not o then return end
    -- Verifica ProximityPrompt
    local pp = o:FindFirstChildOfClass("ProximityPrompt")
    if pp then
        local ok, err = pcall(function() fireproximityprompt(pp) end)
        if not ok then Erro("fireproximityprompt", err) end
        return
    end
    -- Fallback firetouchinterest
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local parte = GetPart(o)
    if not parte then return end
    local ok, err = pcall(function() firetouchinterest(hrp, parte, 0) end)
    if not ok then Erro("firetouchinterest 0", err) end
    task.wait(0.05)
    local ok2, err2 = pcall(function() firetouchinterest(hrp, parte, 1) end)
    if not ok2 then Erro("firetouchinterest 1", err2) end
end

local function AbrirGaveta(o)
    if not o then return end
    -- Abre a gaveta
    local pp = o:FindFirstChildOfClass("ProximityPrompt")
    if pp then
        local ok, err = pcall(function() fireproximityprompt(pp) end)
        if not ok then Erro("AbrirGaveta PP", err) end
    else
        local char = LP.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local parte = GetPart(o)
            if not parte then return end
            pcall(function() firetouchinterest(hrp, parte, 0) end)
            task.wait(0.05)
            pcall(function() firetouchinterest(hrp, parte, 1) end)
        end
    end
    task.wait(0.3)
    -- Coleta itens dentro
    local ok, err = pcall(function()
        for _,f in ipairs(o:GetDescendants()) do
            if f and ColetaNomes[f.Name] then
                task.spawn(TentarColetar, f)
            end
        end
    end)
    if not ok then Erro("AbrirGaveta coleta", err) end
end

local function IniciarAutoGaveta()
    if GavetaConn then
        GavetaConn:Disconnect()
        GavetaConn = nil
    end
    if not Cfg.AutoGaveta then return end
    Log("Auto-gaveta ativado")
    task.spawn(function()
        local ok, err = pcall(function()
            for _,o in ipairs(game:GetDescendants()) do
                if o and GavetaNomes[o.Name] then
                    task.spawn(AbrirGaveta, o)
                end
            end
        end)
        if not ok then Erro("AutoGaveta scan", err) end
    end)
    local ok, err = pcall(function()
        GavetaConn = game.DescendantAdded:Connect(function(o)
            if not o then return end
            if GavetaNomes[o.Name] then
                task.wait(0.5)
                task.spawn(AbrirGaveta, o)
            end
            if ColetaNomes[o.Name] and ItemSolto(o) then
                task.wait(0.2)
                task.spawn(TentarColetar, o)
            end
        end)
    end)
    if not ok then Erro("AutoGaveta conn", err) end
end

-- ══════════════════
--  PROTEÇÃO EYES
-- ══════════════════
local TDOrig = nil
local EyesConn = nil
local function ProtEyes(v)
    Cfg.ProtecaoEyes = v
    local function Ap(char)
        if not char then return end
        local h = char:FindFirstChildOfClass("Humanoid")
        if not h then return end
        if v then
            TDOrig = h.TakeDamage
            h.TakeDamage = function() end
            Notif("Felix Hub","Protecao ativada!",3)
            Log("Protecao Eyes ativada")
        else
            if TDOrig then
                h.TakeDamage = TDOrig
                TDOrig = nil
                Log("Protecao Eyes desativada")
            end
        end
    end
    local ok, err = pcall(Ap, LP.Character)
    if not ok then Erro("ProtEyes", err) end
    if EyesConn then EyesConn:Disconnect() end
    if v then
        EyesConn = LP.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            pcall(Ap, c)
        end)
    end
end

local function AppSpeed(v)
    local ok, err = pcall(function()
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if not h then return end
        h.WalkSpeed = v
    end)
    if not ok then Erro("AppSpeed", err) end
end

local function AppJump(v)
    local ok, err = pcall(function()
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if not h then return end
        h.JumpPower = v
        h.UseJumpPower = true
    end)
    if not ok then Erro("AppJump", err) end
end

local function TFullbright(v)
    local ok, err = pcall(function()
        Lighting.Ambient        = v and Color3.fromRGB(255,255,255) or Color3.fromRGB(70,70,70)
        Lighting.OutdoorAmbient = v and Color3.fromRGB(255,255,255) or Color3.fromRGB(70,70,70)
        Lighting.Brightness     = v and 10 or 1
        Lighting.FogEnd         = 100000
    end)
    if not ok then Erro("TFullbright", err) end
end

local function TAntiLag(v)
    local ok, err = pcall(function()
        settings().Rendering.QualityLevel = v and 1 or Enum.QualityLevel.Automatic
    end)
    if not ok then Erro("TAntiLag", err) end
end

LP.CharacterAdded:Connect(function()
    task.wait(0.4)
    AppSpeed(Cfg.WalkSpeedValor)
    AppJump(Cfg.JumpPowerValor)
    if Cfg.ProtecaoEyes then task.wait(0.3); ProtEyes(true) end
    if Cfg.AutoGaveta then IniciarAutoGaveta() end
end)

-- ══════════════════════════════════════════
--  GUI — criação direta, sem função Criar()
-- ══════════════════════════════════════════
Log("=== CONSTRUINDO GUI ===")

-- Remove GUI antiga se existir
local gAnt = GuiParent:FindFirstChild("FelixHub_GUI")
if gAnt then
    pcall(function() gAnt:Destroy() end)
    Log("GUI antiga removida")
end

-- PASSO 1: ScreenGui
local SG = Instance.new("ScreenGui")
SG.Name = "FelixHub_GUI"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local okSG, errSG = pcall(function() SG.Parent = GuiParent end)
if not okSG then
    Erro("ScreenGui.Parent", errSG)
    -- Ultima tentativa
    pcall(function() SG.Parent = LP:FindFirstChildOfClass("PlayerGui") end)
end

if not SG.Parent then
    warn("[FelixHub ERRO FATAL] ScreenGui sem parent. Abortando.")
    _G.FelixHubCarregado = nil
    return
end
Log("PASSO 1 OK - ScreenGui em: " .. SG.Parent.Name)

-- PASSO 2: Botão F
local BH = Instance.new("Frame")
BH.Name = "BotaoF"
BH.Size = UDim2.new(0,44,0,44)
BH.Position = UDim2.new(0,12,0.28,0)
BH.BackgroundColor3 = Color3.fromRGB(12,12,18)
BH.BackgroundTransparency = 0
BH.BorderSizePixel = 0
BH.ClipsDescendants = true
BH.Parent = SG

do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1,0)
    c.Parent = BH

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(212,175,55)
    s.Thickness = 1.8
    pcall(function() s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end)
    s.Parent = BH

    local img = Instance.new("ImageLabel")
    img.Image = "rbxassetid://5028857472"
    img.ImageColor3 = Color3.fromRGB(212,175,55)
    img.ImageTransparency = 0.6
    img.BackgroundTransparency = 1
    img.Size = UDim2.new(1,0,1,0)
    img.ZIndex = 1
    img.Parent = BH
end

local BtnF = Instance.new("TextButton")
BtnF.Name = "BtnF"
BtnF.Text = "F"
BtnF.Font = Enum.Font.GothamBold
BtnF.TextColor3 = Color3.fromRGB(212,175,55)
BtnF.TextSize = 20
BtnF.BackgroundTransparency = 1
BtnF.BorderSizePixel = 0
BtnF.AutoButtonColor = false
BtnF.Size = UDim2.new(1,0,1,0)
BtnF.ZIndex = 2
BtnF.Parent = BH

Log("PASSO 2 OK - Botao F criado")

-- PASSO 3: Janela principal
local WIN_W, WIN_H = 460, 350
local WIN_X, WIN_Y = 10, 60

local Win = Instance.new("Frame")
Win.Name = "Win"
Win.Size = UDim2.new(0,WIN_W,0,WIN_H)
Win.Position = UDim2.new(0,WIN_X,0,WIN_Y)
Win.BackgroundColor3 = Color3.fromRGB(10,10,15)
Win.BorderSizePixel = 0
Win.Visible = false
Win.Parent = SG

do
    local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(0,13); c.Parent=Win
    local s = Instance.new("UIStroke"); s.Color=Color3.fromRGB(212,175,55); s.Thickness=1.4; s.Parent=Win
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(13,13,19)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(7,7,11)),
    })
    g.Rotation = 120; g.Parent = Win
end

Log("PASSO 3 OK - Janela criada")

-- PASSO 4: Header
local Hdr = Instance.new("Frame")
Hdr.Name = "Header"
Hdr.Size = UDim2.new(1,0,0,44)
Hdr.BackgroundColor3 = Color3.fromRGB(8,8,13)
Hdr.BorderSizePixel = 0
Hdr.Parent = Win

do
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,13); c.Parent=Hdr
    local ln=Instance.new("Frame")
    ln.Size=UDim2.new(1,0,0,1); ln.Position=UDim2.new(0,0,1,-1)
    ln.BackgroundColor3=Color3.fromRGB(212,175,55); ln.BorderSizePixel=0; ln.Parent=Hdr

    local t1=Instance.new("TextLabel")
    t1.Text="FELIX HUB"; t1.Font=Enum.Font.GothamBold
    t1.TextColor3=Color3.fromRGB(212,175,55); t1.TextSize=17
    t1.BackgroundTransparency=1; t1.Size=UDim2.new(0.6,0,0.58,0)
    t1.Position=UDim2.new(0,13,0.04,0)
    t1.TextXAlignment=Enum.TextXAlignment.Left; t1.Parent=Hdr

    local t2=Instance.new("TextLabel")
    t2.Text="DOORS EDITION  v2.9"; t2.Font=Enum.Font.Gotham
    t2.TextColor3=Color3.fromRGB(140,120,55); t2.TextSize=10
    t2.BackgroundTransparency=1; t2.Size=UDim2.new(0.6,0,0.36,0)
    t2.Position=UDim2.new(0,15,0.60,0)
    t2.TextXAlignment=Enum.TextXAlignment.Left; t2.Parent=Hdr
end

local BMin = Instance.new("TextButton")
BMin.Text="--"; BMin.Font=Enum.Font.GothamBold
BMin.TextColor3=Color3.fromRGB(212,175,55); BMin.TextSize=13
BMin.BackgroundColor3=Color3.fromRGB(20,20,30); BMin.BorderSizePixel=0
BMin.Size=UDim2.new(0,26,0,20); BMin.Position=UDim2.new(1,-58,0.5,-10); BMin.Parent=Hdr
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=BMin end

local BX = Instance.new("TextButton")
BX.Text="X"; BX.Font=Enum.Font.GothamBold
BX.TextColor3=Color3.fromRGB(255,75,75); BX.TextSize=12
BX.BackgroundColor3=Color3.fromRGB(20,20,30); BX.BorderSizePixel=0
BX.Size=UDim2.new(0,26,0,20); BX.Position=UDim2.new(1,-28,0.5,-10); BX.Parent=Hdr
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=BX end

Log("PASSO 4 OK - Header criado")

-- PASSO 5: Sidebar e Conteudo
local SB = Instance.new("Frame")
SB.Name = "Sidebar"
SB.Size=UDim2.new(0,90,1,-44); SB.Position=UDim2.new(0,0,0,44)
SB.BackgroundColor3=Color3.fromRGB(8,8,13); SB.BorderSizePixel=0; SB.Parent=Win

do
    local ln=Instance.new("Frame")
    ln.Size=UDim2.new(0,1,1,0); ln.Position=UDim2.new(1,0,0,0)
    ln.BackgroundColor3=Color3.fromRGB(212,175,55); ln.BackgroundTransparency=0.75
    ln.BorderSizePixel=0; ln.Parent=SB
    local ll=Instance.new("UIListLayout")
    ll.Padding=UDim.new(0,3); ll.HorizontalAlignment=Enum.HorizontalAlignment.Center; ll.Parent=SB
    local pd=Instance.new("UIPadding"); pd.PaddingTop=UDim.new(0,7); pd.Parent=SB
end

local Cont = Instance.new("Frame")
Cont.Name = "Conteudo"
Cont.Size=UDim2.new(1,-90,1,-44); Cont.Position=UDim2.new(0,90,0,44)
Cont.BackgroundTransparency=1; Cont.Parent=Win

Log("PASSO 5 OK - Sidebar e Conteudo criados")

-- PASSO 6: Abas
local Abas = {}
local AbaAtiva = nil
local IAbas = {
    {n="ESP",   i="ESP"},   {n="Itens", i="ITENS"},
    {n="Local", i="LOCAL"}, {n="Visual",i="VISUAL"},
    {n="Doors", i="DOORS"}, {n="Info",  i="INFO"},
}

for _,a in ipairs(IAbas) do
    local bt = Instance.new("TextButton")
    bt.Text = a.i; bt.Font = Enum.Font.GothamBold
    bt.TextColor3 = Color3.fromRGB(110,100,70); bt.TextSize = 9
    bt.BackgroundColor3 = Color3.fromRGB(14,14,21)
    bt.Size = UDim2.new(0.86,0,0,42)
    bt.AutoButtonColor = false; bt.BorderSizePixel = 0
    bt.Parent = SB
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=bt end

    local pn = Instance.new("ScrollingFrame")
    pn.Name = "P_"..a.n
    pn.Size=UDim2.new(1,-10,1,-6); pn.Position=UDim2.new(0,5,0,3)
    pn.BackgroundTransparency=1; pn.BorderSizePixel=0
    pn.ScrollBarThickness=3
    pn.ScrollBarImageColor3=Color3.fromRGB(212,175,55)
    pn.CanvasSize=UDim2.new(0,0,0,0)
    pn.AutomaticCanvasSize=Enum.AutomaticSize.Y
    pn.Visible=false; pn.Parent=Cont

    do
        local ll=Instance.new("UIListLayout")
        ll.Padding=UDim.new(0,5); ll.HorizontalAlignment=Enum.HorizontalAlignment.Center; ll.Parent=pn
        local pd=Instance.new("UIPadding")
        pd.PaddingTop=UDim.new(0,6); pd.PaddingLeft=UDim.new(0,6); pd.PaddingRight=UDim.new(0,6); pd.Parent=pn
    end

    Abas[a.n] = {p=pn, b=bt}
end

local function Aba(n)
    for _,a in pairs(Abas) do
        if a and a.p and a.b then
            a.p.Visible = false
            TW(a.b, TweenInfo.new(0.12), {
                BackgroundColor3=Color3.fromRGB(14,14,21),
                TextColor3=Color3.fromRGB(110,100,70),
            })
        end
    end
    local a = Abas[n]
    if a and a.p and a.b then
        a.p.Visible = true
        TW(a.b, TweenInfo.new(0.12), {
            BackgroundColor3=Color3.fromRGB(28,24,7),
            TextColor3=Color3.fromRGB(212,175,55),
        })
        AbaAtiva = n
    end
end

for n,a in pairs(Abas) do
    if a and a.b then
        a.b.MouseButton1Click:Connect(function() Aba(n) end)
    end
end

Log("PASSO 6 OK - " .. #IAbas .. " abas criadas")

-- ── COMPONENTES ──
local function Sec(p,t)
    if not p then return end
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,18); f.BackgroundTransparency=1; f.Parent=p
    local ln=Instance.new("Frame")
    ln.Size=UDim2.new(1,0,0,1); ln.Position=UDim2.new(0,0,0.5,0)
    ln.BackgroundColor3=Color3.fromRGB(212,175,55); ln.BackgroundTransparency=0.65
    ln.BorderSizePixel=0; ln.Parent=f
    local lb=Instance.new("TextLabel")
    lb.Text="  "..t.."  "; lb.Font=Enum.Font.GothamBold
    lb.TextColor3=Color3.fromRGB(212,175,55); lb.TextSize=9
    lb.BackgroundColor3=Color3.fromRGB(10,10,15)
    lb.Size=UDim2.new(0,0,1,0); lb.Position=UDim2.new(0.5,0,0,0)
    lb.AutomaticSize=Enum.AutomaticSize.X
    lb.TextXAlignment=Enum.TextXAlignment.Center; lb.Parent=f
end

local function Tog(p,t,ini,cb)
    if not p then return end
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,30); f.BackgroundColor3=Color3.fromRGB(15,15,22)
    f.BorderSizePixel=0; f.Parent=p
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=f end
    do local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(38,36,26); s.Thickness=1; s.Parent=f end
    local lb=Instance.new("TextLabel")
    lb.Text=t; lb.Font=Enum.Font.Gotham
    lb.TextColor3=Color3.fromRGB(195,185,145); lb.TextSize=11
    lb.BackgroundTransparency=1; lb.Size=UDim2.new(1,-46,1,0); lb.Position=UDim2.new(0,8,0,0)
    lb.TextXAlignment=Enum.TextXAlignment.Left; lb.TextWrapped=true; lb.Parent=f
    local tr=Instance.new("Frame")
    tr.Size=UDim2.new(0,32,0,16); tr.Position=UDim2.new(1,-39,0.5,-8)
    tr.BackgroundColor3 = ini and Color3.fromRGB(170,130,15) or Color3.fromRGB(34,34,40)
    tr.BorderSizePixel=0; tr.Parent=f
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=tr end
    local bl=Instance.new("Frame")
    bl.Size=UDim2.new(0,10,0,10)
    bl.Position = ini and UDim2.new(0,19,0.5,-5) or UDim2.new(0,3,0.5,-5)
    bl.BackgroundColor3=Color3.fromRGB(255,255,255); bl.BorderSizePixel=0; bl.Parent=tr
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=bl end
    local st=ini
    local b=Instance.new("TextButton")
    b.Text=""; b.BackgroundTransparency=1; b.BorderSizePixel=0
    b.Size=UDim2.new(1,0,1,0); b.Parent=f
    b.MouseButton1Click:Connect(function()
        st = not st
        TW(tr,TweenInfo.new(0.14),{BackgroundColor3=st and Color3.fromRGB(170,130,15) or Color3.fromRGB(34,34,40)})
        TW(bl,TweenInfo.new(0.14),{Position=st and UDim2.new(0,19,0.5,-5) or UDim2.new(0,3,0.5,-5)})
        local ok,err=pcall(cb,st)
        if not ok then Erro("Toggle cb",err) end
    end)
end

local function Sld(p,t,mn,mx,in0,cb)
    if not p then return end
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,46); f.BackgroundColor3=Color3.fromRGB(15,15,22)
    f.BorderSizePixel=0; f.Parent=p
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=f end
    do local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(38,36,26); s.Thickness=1; s.Parent=f end
    local lb=Instance.new("TextLabel")
    lb.Text=t..": "..in0; lb.Font=Enum.Font.Gotham
    lb.TextColor3=Color3.fromRGB(195,185,145); lb.TextSize=11; lb.BackgroundTransparency=1
    lb.Size=UDim2.new(1,-6,0,17); lb.Position=UDim2.new(0,8,0,3)
    lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=f
    local tr=Instance.new("Frame")
    tr.Size=UDim2.new(1,-16,0,5); tr.Position=UDim2.new(0,8,0,26)
    tr.BackgroundColor3=Color3.fromRGB(34,34,40); tr.BorderSizePixel=0; tr.Parent=f
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=tr end
    local p0=(in0-mn)/(mx-mn)
    local fi=Instance.new("Frame")
    fi.Size=UDim2.new(p0,0,1,0); fi.BackgroundColor3=Color3.fromRGB(212,175,55)
    fi.BorderSizePixel=0; fi.Parent=tr
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=fi end
    local kn=Instance.new("Frame")
    kn.Size=UDim2.new(0,11,0,11); kn.Position=UDim2.new(p0,-5,0.5,-5)
    kn.BackgroundColor3=Color3.fromRGB(240,230,200); kn.BorderSizePixel=0; kn.Parent=tr
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=kn end
    local dg=false
    local function U(x)
        local ok,err=pcall(function()
            local pp2=math.clamp((x-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1)
            local vv=math.floor(mn+(mx-mn)*pp2)
            fi.Size=UDim2.new(pp2,0,1,0); kn.Position=UDim2.new(pp2,-5,0.5,-5)
            lb.Text=t..": "..vv; pcall(cb,vv)
        end)
        if not ok then Erro("Slider",err) end
    end
    tr.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dg=true; U(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dg and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            U(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dg=false
        end
    end)
end

local function Inp(p,titulo,pad,btnT,cb)
    if not p then return end
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,58); f.BackgroundColor3=Color3.fromRGB(15,15,22)
    f.BorderSizePixel=0; f.Parent=p
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=f end
    do local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(38,36,26); s.Thickness=1; s.Parent=f end
    local lb=Instance.new("TextLabel")
    lb.Text=titulo; lb.Font=Enum.Font.Gotham
    lb.TextColor3=Color3.fromRGB(195,185,145); lb.TextSize=11; lb.BackgroundTransparency=1
    lb.Size=UDim2.new(1,-6,0,17); lb.Position=UDim2.new(0,8,0,3)
    lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=f
    local tb=Instance.new("TextBox")
    tb.Text=tostring(pad); tb.Font=Enum.Font.GothamBold
    tb.TextColor3=Color3.fromRGB(212,175,55); tb.TextSize=13
    tb.BackgroundColor3=Color3.fromRGB(10,10,16); tb.BorderSizePixel=0
    tb.Size=UDim2.new(0.54,0,0,22); tb.Position=UDim2.new(0,8,0,28)
    tb.ClearTextOnFocus=false; tb.Parent=f
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=tb end
    do local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(212,175,55); s.Thickness=1; s.Parent=tb end
    local bt=Instance.new("TextButton")
    bt.Text=btnT; bt.Font=Enum.Font.GothamBold
    bt.TextColor3=Color3.fromRGB(10,10,15); bt.TextSize=11
    bt.BackgroundColor3=Color3.fromRGB(212,175,55); bt.BorderSizePixel=0
    bt.Size=UDim2.new(0.38,0,0,22); bt.Position=UDim2.new(0.59,0,0,28); bt.Parent=f
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,5); c.Parent=bt end
    bt.MouseButton1Click:Connect(function()
        local v=tonumber(tb.Text)
        if v then
            local ok,err=pcall(cb,v)
            if not ok then Erro("Inp cb",err) end
        end
    end)
end

-- PASSO 7: Conteúdo das abas
Log("PASSO 7 - Preenchendo abas...")

local function GetP(n)
    local a = Abas[n]
    if not a then Erro("GetP","Aba '"..n.."' nao existe"); return nil end
    return a.p
end

local eP = GetP("ESP")
if eP then
    Sec(eP,"Geral")
    Tog(eP,"Ativar ESP",        Cfg.ESP_Ativo,   function(v) Cfg.ESP_Ativo=v end)
    Tog(eP,"Highlight",         Cfg.HL_Ativo,    function(v) Cfg.HL_Ativo=v end)
    Tog(eP,"Billboard",         Cfg.BB_Ativo,    function(v) Cfg.BB_Ativo=v end)
    Tog(eP,"Distancia",         Cfg.Dist_Ativo,  function(v) Cfg.Dist_Ativo=v end)
    Tog(eP,"Avisos Entidades",  Cfg.Aviso_Ativo, function(v) Cfg.Aviso_Ativo=v end)
    Sec(eP,"Selecionar")
    Tog(eP,"Portas",    Cfg.ESP_Portas,    function(v) Cfg.ESP_Portas=v end)
    Tog(eP,"Chaves",    Cfg.ESP_Chaves,    function(v) Cfg.ESP_Chaves=v end)
    Tog(eP,"Alavancas", Cfg.ESP_Alavancas, function(v) Cfg.ESP_Alavancas=v end)
    Tog(eP,"Livros",    Cfg.ESP_Livros,    function(v) Cfg.ESP_Livros=v end)
    Tog(eP,"Figure",    Cfg.ESP_Figure,    function(v) Cfg.ESP_Figure=v end)
    Tog(eP,"Screech",   Cfg.ESP_Screech,   function(v) Cfg.ESP_Screech=v end)
    Sec(eP,"Busca Manual")
    Tog(eP,"Buscar Figure",false,function(v)
        Estado.ProcurandoFigure=v
        if v then Notif("Felix Hub","Buscando Figure...",3) end
    end)
    Tog(eP,"Scan Livros (global)",false,function(v)
        if v then
            -- Limpa cache de livros para poder re-escanear
            for k in pairs(Cache) do
                if k:find("LiveHintBook") then Cache[k]=nil end
            end
            -- Ativa busca e roda scan UMA VEZ
            Estado.ProcurandoLivros = true
            task.spawn(ScanLivros)
        else
            Estado.ProcurandoLivros = false
        end
    end)
    Log("Aba ESP preenchida")
end

local iP = GetP("Itens")
if iP then
    Sec(iP,"Itens Coletaveis")
    Tog(iP,"Itens do chao", Cfg.ESP_Itens,    function(v) Cfg.ESP_Itens=v end)
    Tog(iP,"Baus",          Cfg.ESP_Baus,     function(v) Cfg.ESP_Baus=v end)
    Tog(iP,"Fusiveis",      Cfg.ESP_Fusiveis, function(v) Cfg.ESP_Fusiveis=v end)
    Sec(iP,"Auto-Gaveta")
    Tog(iP,"Abrir gavetas + coletar",Cfg.AutoGaveta,function(v)
        Cfg.AutoGaveta=v
        IniciarAutoGaveta()
        if v then Notif("Felix Hub","Auto-gaveta ativado!",4) end
    end)
    Log("Aba Itens preenchida")
end

local lP = GetP("Local")
if lP then
    Sec(lP,"Speed Hack")
    Inp(lP,"Velocidade:",16,"Ativar",function(v)
        Cfg.WalkSpeedValor=v; AppSpeed(v); Notif("Speed","WalkSpeed: "..v,3)
    end)
    do
        local rS=Instance.new("TextButton")
        rS.Text="Resetar Speed (16)"; rS.Font=Enum.Font.Gotham
        rS.TextColor3=Color3.fromRGB(195,185,145); rS.TextSize=11
        rS.BackgroundColor3=Color3.fromRGB(15,15,22); rS.BorderSizePixel=0
        rS.Size=UDim2.new(1,0,0,28); rS.Parent=lP
        do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=rS end
        do local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(38,36,26); s.Thickness=1; s.Parent=rS end
        rS.MouseButton1Click:Connect(function() Cfg.WalkSpeedValor=16; AppSpeed(16) end)
    end
    Sec(lP,"Jump Power")
    Inp(lP,"Jump Power:",50,"Ativar",function(v)
        Cfg.JumpPowerValor=v; AppJump(v); Notif("Jump","JumpPower: "..v,3)
    end)
    do
        local rJ=Instance.new("TextButton")
        rJ.Text="Resetar Jump (50)"; rJ.Font=Enum.Font.Gotham
        rJ.TextColor3=Color3.fromRGB(195,185,145); rJ.TextSize=11
        rJ.BackgroundColor3=Color3.fromRGB(15,15,22); rJ.BorderSizePixel=0
        rJ.Size=UDim2.new(1,0,0,28); rJ.Parent=lP
        do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=rJ end
        do local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(38,36,26); s.Thickness=1; s.Parent=rJ end
        rJ.MouseButton1Click:Connect(function() Cfg.JumpPowerValor=50; AppJump(50) end)
    end
    Sec(lP,"Camera")
    Sld(lP,"FOV",60,120,70,function(v) Camera.FieldOfView=v end)
    Log("Aba Local preenchida")
end

local vP = GetP("Visual")
if vP then
    Sec(vP,"Iluminacao")
    Tog(vP,"Fullbright",false,TFullbright)
    Tog(vP,"Anti-Lag",  false,TAntiLag)
    Log("Aba Visual preenchida")
end

local dP = GetP("Doors")
if dP then
    Sec(dP,"Protecao")
    Tog(dP,"Protecao Eyes",false,ProtEyes)
    Tog(dP,"Remover Screech",Cfg.RemoverScreech,function(v) Cfg.RemoverScreech=v end)
    Sec(dP,"Notificacoes")
    Tog(dP,"Notif. Portas",Cfg.NotifPortas,function(v) Cfg.NotifPortas=v end)
    Sec(dP,"Sala 50")
    local b50=Instance.new("TextButton")
    b50.Text="Ativar Modo Sala 50"; b50.Font=Enum.Font.GothamBold
    b50.TextColor3=Color3.fromRGB(212,175,55); b50.TextSize=12
    b50.BackgroundColor3=Color3.fromRGB(28,22,6); b50.BorderSizePixel=0
    b50.Size=UDim2.new(1,0,0,28); b50.Parent=dP
    do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,7); c.Parent=b50 end
    do local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(212,175,55); s.Thickness=1; s.Parent=b50 end
    b50.MouseButton1Click:Connect(function()
        Estado.ProcurandoFigure=true
        -- Limpa cache de livros/figures para re-escanear
        for k in pairs(Cache) do
            if k:find("LiveHintBook") or k:find("FigureRig") then Cache[k]=nil end
        end
        -- Ativa e roda scan UMA VEZ
        Estado.ProcurandoLivros = true
        task.delay(0.3, ScanLivros)
        Notif("Sala 50","Buscando livros e Figure...",5)
    end)
    Log("Aba Doors preenchida")
end

local nP = GetP("Info")
if nP then
    Sec(nP,"Felix Hub v2.9")
    local inf=Instance.new("TextLabel")
    inf.Text="Felix Hub v2.9 — DOORS Edition\nDelta / Hydrogen / Fluxus / Arceus X\n\nBotao F = abre/fecha\nRCtrl / F9 = abre/fecha\nArraste o header pra mover\n\nDEBUG="..tostring(DEBUG)
    inf.Font=Enum.Font.Gotham; inf.TextColor3=Color3.fromRGB(175,160,110); inf.TextSize=11
    inf.BackgroundColor3=Color3.fromRGB(15,15,22); inf.BackgroundTransparency=0
    inf.Size=UDim2.new(1,0,0,130); inf.TextWrapped=true
    inf.TextYAlignment=Enum.TextYAlignment.Top; inf.Parent=nP
    Log("Aba Info preenchida")
end

Log("PASSO 7 OK - Todas as abas preenchidas")

-- PASSO 8: Arrastar janela
local drg, dOff = false, Vector2.zero
Hdr.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        drg=true
        local ok,err=pcall(function()
            dOff=Vector2.new(i.Position.X-Win.AbsolutePosition.X, i.Position.Y-Win.AbsolutePosition.Y)
        end)
        if not ok then Erro("Drag start",err) end
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if not drg then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        pcall(function()
            local vp=Camera.ViewportSize
            Win.Position=UDim2.new(0,
                math.clamp(i.Position.X-dOff.X, 0, vp.X-WIN_W), 0,
                math.clamp(i.Position.Y-dOff.Y, 0, vp.Y-WIN_H))
        end)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        drg=false
    end
end)

-- Arrastar botão
local bdg, bOff, bMov = false, Vector2.zero, false
BH.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        bdg=true; bMov=false
        local ok,err=pcall(function()
            local pos=BH.AbsolutePosition
            bOff=Vector2.new(i.Position.X-pos.X, i.Position.Y-pos.Y)
        end)
        if not ok then Erro("BtnDrag start",err) end
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if not bdg then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        pcall(function()
            local vp=Camera.ViewportSize
            BH.Position=UDim2.new(0,
                math.clamp(i.Position.X-bOff.X, 0, vp.X-44), 0,
                math.clamp(i.Position.Y-bOff.Y, 0, vp.Y-44))
        end)
        bMov=true
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        bdg=false
    end
end)

Log("PASSO 8 OK - Arrastar configurado")

-- PASSO 9: Abrir/Fechar
local Open = false
local Mini = false

local function Abrir()
    local ok, err = pcall(function()
        Open=true
        Win.Position=UDim2.new(0,WIN_X,0,WIN_Y)
        Win.Size=UDim2.new(0,WIN_W,0,WIN_H)
        Win.Visible=true
        if not AbaAtiva then Aba("ESP") end
    end)
    if not ok then Erro("Abrir",err) end
    Log("Hub aberto")
end

local function Fechar()
    local ok, err = pcall(function()
        Open=false
        Win.Visible=false
    end)
    if not ok then Erro("Fechar",err) end
end

local function Toggle()
    if Open then Fechar() else Abrir() end
end

local function Minimizar()
    local ok, err = pcall(function()
        Mini = not Mini
        if Mini then
            Win.Size=UDim2.new(0,WIN_W,0,44)
            Cont.Visible=false; SB.Visible=false
        else
            Win.Size=UDim2.new(0,WIN_W,0,WIN_H)
            Cont.Visible=true; SB.Visible=true
        end
    end)
    if not ok then Erro("Minimizar",err) end
end

BtnF.MouseButton1Click:Connect(function()
    if not bMov then Toggle() end
    bMov=false
end)
BX.MouseButton1Click:Connect(Fechar)
BMin.MouseButton1Click:Connect(Minimizar)

UserInputService.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode==Enum.KeyCode.RightControl or i.KeyCode==Enum.KeyCode.F9 then
        Toggle()
    end
end)

BH.MouseEnter:Connect(function()
    TW(BH, TweenInfo.new(0.13), {BackgroundColor3=Color3.fromRGB(24,20,6)})
end)
BH.MouseLeave:Connect(function()
    TW(BH, TweenInfo.new(0.13), {BackgroundColor3=Color3.fromRGB(12,12,18)})
end)

Log("PASSO 9 OK - Botoes configurados")

-- ══════════════════
--  INICIAR TUDO
-- ══════════════════
Aba("ESP")
task.spawn(IniciarESP)
task.delay(0.8, function()
    Notif("Felix Hub v2.9","Carregado! Toque no F ou RCtrl.",5)
end)

Log("=== v2.9 CARREGADO COM SUCESSO ===")
Log("GuiParent final: " .. tostring(SG.Parent and SG.Parent.Name or "SEM PARENT"))
Log("BotaoF parent: " .. tostring(BH.Parent and BH.Parent.Name or "SEM PARENT"))
Log("Janela parent: " .. tostring(Win.Parent and Win.Parent.Name or "SEM PARENT"))
