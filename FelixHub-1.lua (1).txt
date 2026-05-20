--[[
╔══════════════════════════════════════════════════════════╗
║               FELIX HUB v2.1 - DOORS EDITION             ║
║         Script Premium | Mobile & PC Optimized           ║
║    Executors: Delta, Hydrogen, Fluxus, Arceus X          ║
╚══════════════════════════════════════════════════════════╝

  FIXES v2.1:
  • Livros: scan completo do workspace (não só DescendantAdded)
  • FigureRig: busca no workspace inteiro (Model, sem restrição de sala)
  • Billboard: TextSize fixo 11, sem TextScaled, sem AutoSize
  • Hub: botão F corrigido (sem borda amarela, clique simples confiável)
  • Porta: número corrigido (+1 para bater com o número visual do jogo)
  • ESP novos: Lanterna, Vitamina, LockPick, Baú, Sopa, Bandagem, Fusíveis
]]

-- ════════════════════════════════════════════
--  ANTI-DUPLICAÇÃO
-- ════════════════════════════════════════════
if _G.FelixHubCarregado then
    warn("[FelixHub] Já carregado.")
    return
end
_G.FelixHubCarregado = true

-- ════════════════════════════════════════════
--  SERVIÇOS
-- ════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ════════════════════════════════════════════
--  CONFIG
-- ════════════════════════════════════════════
local Config = {
    ESP_Ativo           = true,
    Highlight_Ativo     = true,
    Billboard_Ativo     = true,
    Distancia_Ativo     = true,
    EntityWarning_Ativo = true,

    -- Seleção individual
    ESP_Portas    = true,
    ESP_Chaves    = true,
    ESP_Alavancas = true,
    ESP_Livros    = true,
    ESP_Figure    = true,
    ESP_Screech   = true,
    ESP_Itens     = true,   -- lanterna, vitamina, lockpick, bandagem, sopa
    ESP_Baus      = true,
    ESP_Fusiveis  = true,

    -- Visual / Player
    Fullbright_Ativo     = false,
    AntiLag_Ativo        = false,
    FOVChanger_Ativo     = false,
    FOVValor             = 70,
    WalkSpeed_Ativo      = false,
    WalkSpeedValor       = 16,
    JumpPower_Ativo      = false,
    JumpPowerValor       = 50,

    -- Doors
    RemoverScreech_Ativo = true,
    NotifPortas_Ativo    = true,
    ProtecaoEyes_Ativo   = false,

    -- Cores
    CorPorta    = Color3.fromRGB(255, 215,   0),
    CorChave    = Color3.fromRGB( 30, 144, 255),
    CorAlavanca = Color3.fromRGB(255, 140,   0),
    CorLivro    = Color3.fromRGB(160,  32, 240),
    CorFigure   = Color3.fromRGB(220,  20,  60),
    CorScreech  = Color3.fromRGB(200,   0,   0),
    CorItem     = Color3.fromRGB( 50, 220, 100),
    CorBau      = Color3.fromRGB(200, 170,  20),
    CorFusivel  = Color3.fromRGB(255, 100,   0),

    MaxDistancia       = 500,
    IntervaloDistancia = 0.25,
}

local Estado = {
    ProcurandoFigure  = false,
    ProcurandoLivros  = false,
    LivrosEncontrados = 0,
}

-- Cache anti-duplicação por UID string
local Cache = {}

local Conexoes = {}

-- ════════════════════════════════════════════
--  UTILITÁRIOS
-- ════════════════════════════════════════════
local function Criar(classe, props)
    local ok, obj = pcall(Instance.new, classe)
    if not ok then return nil end
    for k, v in pairs(props) do pcall(function() obj[k] = v end) end
    return obj
end

local function Tween(obj, info, props)
    if not obj then return end
    TweenService:Create(obj, info, props):Play()
end

local function Notificar(titulo, texto, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = titulo or "Felix Hub",
            Text  = texto  or "",
            Duration = dur or 4,
        })
    end)
end

local function GetAdorneePart(alvo)
    if not alvo or not alvo.Parent then return nil end
    if alvo:IsA("BasePart") then return alvo end
    if alvo:IsA("Model") then
        if alvo.PrimaryPart then return alvo.PrimaryPart end
        for _, v in ipairs(alvo:GetDescendants()) do
            if v:IsA("BasePart") then return v end
        end
    end
    return nil
end

-- ════════════════════════════════════════════
--  BILLBOARD — tamanho 100x22 FIXO para todos
-- ════════════════════════════════════════════
local function CriarBillboard(alvo, texto, cor)
    if not Config.Billboard_Ativo then return end
    local parte = GetAdorneePart(alvo)
    if not parte then return end

    local uid = "BB_" .. alvo:GetFullName():gsub("[^%w]", "_")
    local antigo = CoreGui:FindFirstChild(uid)
    if antigo then antigo:Destroy() end

    local bbg = Criar("BillboardGui", {
        Name           = uid,
        Adornee        = parte,
        AlwaysOnTop    = true,
        LightInfluence = 0,
        MaxDistance    = Config.MaxDistancia,
        -- TAMANHO ÚNICO E FIXO para todos os tipos sem exceção
        Size           = UDim2.new(0, 100, 0, 22),
        StudsOffset    = Vector3.new(0, 3, 0),
        Parent         = CoreGui,
    })

    local frame = Criar("Frame", {
        BackgroundColor3       = Color3.fromRGB(8, 8, 12),
        BackgroundTransparency = 0.2,
        Size                   = UDim2.new(1, 0, 1, 0),
        Parent                 = bbg,
    })
    Criar("UICorner", { CornerRadius = UDim.new(0, 4), Parent = frame })
    Criar("UIStroke", { Color = cor, Thickness = 1, Parent = frame })

    local label = Criar("TextLabel", {
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 1, 0),
        Font                   = Enum.Font.GothamBold,
        -- FIXO: sem TextScaled, sem AutomaticSize
        TextScaled             = false,
        TextSize               = 11,
        TextColor3             = cor,
        TextStrokeColor3       = Color3.fromRGB(0, 0, 0),
        TextStrokeTransparency = 0.3,
        TextXAlignment         = Enum.TextXAlignment.Center,
        TextTruncate           = Enum.TextTruncate.AtEnd,
        Text                   = texto,
        Parent                 = frame,
    })

    -- Distância com throttle leve
    local ultimo = 0
    local connD = RunService.Heartbeat:Connect(function()
        if not bbg or not bbg.Parent then return end
        local ag = tick()
        if ag - ultimo < Config.IntervaloDistancia then return end
        ultimo = ag
        pcall(function()
            if Config.Distancia_Ativo then
                local d = math.floor((Camera.CFrame.Position - parte.Position).Magnitude)
                label.Text = texto .. " " .. d .. "m"
            else
                label.Text = texto
            end
        end)
    end)

    alvo.AncestryChanged:Connect(function()
        if not alvo:IsDescendantOf(game) then
            pcall(function() bbg:Destroy() end)
            pcall(function() connD:Disconnect() end)
        end
    end)
    return bbg
end

-- ════════════════════════════════════════════
--  ESP PRINCIPAL (Highlight + Billboard)
-- ════════════════════════════════════════════
local function CriarESP(alvo, cor, labelTexto)
    if not alvo or not alvo.Parent then return end

    -- Anti-duplicação via cache de string
    local uid = alvo:GetFullName()
    if Cache[uid] then return end
    Cache[uid] = true

    if Config.Highlight_Ativo then
        local hlAnt = alvo:FindFirstChild("FelixHL")
        if hlAnt then hlAnt:Destroy() end
        local hl = Criar("Highlight", {
            Name                = "FelixHL",
            Adornee             = alvo,
            FillColor           = cor,
            FillTransparency    = 0.55,
            OutlineColor        = Color3.fromRGB(255, 255, 255),
            OutlineTransparency = 0.1,
            DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop,
            Enabled             = true,
            Parent              = alvo,
        })
        Tween(hl,
            TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { FillTransparency = 0.78 }
        )
        alvo.AncestryChanged:Connect(function()
            if not alvo:IsDescendantOf(game) then
                pcall(function() hl:Destroy() end)
                Cache[uid] = nil  -- libera cache para se o objeto ressurgir
            end
        end)
    end

    if Config.Billboard_Ativo then
        CriarBillboard(alvo, labelTexto, cor)
    end
end

-- ════════════════════════════════════════════
--  NÚMERO DA SALA  — corrigido +1
--  O jogo nomeia as salas de 0 a 99 internamente
--  mas exibe 1 a 100 para o jogador. Somamos +1.
-- ════════════════════════════════════════════
local function NumeroSalaVisual(nome)
    local n = tonumber(nome)
    if n == nil then return nil end
    return n + 1  -- converte nome interno → número visual
end

-- ════════════════════════════════════════════
--  PROCESSADORES POR TIPO
-- ════════════════════════════════════════════

-- Chave
local function ProcessarChave(obj)
    if not Config.ESP_Ativo or not Config.ESP_Chaves then return end
    CriarESP(obj, Config.CorChave, "CHAVE")
end

-- Alavanca
local function ProcessarAlavanca(obj)
    if not Config.ESP_Ativo or not Config.ESP_Alavancas then return end
    local alvo = obj:FindFirstChild("Main") or obj
    CriarESP(alvo, Config.CorAlavanca, "ALAVANCA")
end

-- Livros — scan no workspace todo (não apenas CurrentRooms)
local function ProcessarLivro(obj)
    if not Config.ESP_Ativo or not Config.ESP_Livros then return end
    if not Estado.ProcurandoLivros then return end
    local uid = obj:GetFullName()
    if Cache[uid] then return end   -- já marcado
    Estado.LivrosEncontrados += 1
    local n = Estado.LivrosEncontrados
    CriarESP(obj, Config.CorLivro, "LIVRO " .. n .. "/8")
    if n >= 8 then
        Estado.ProcurandoLivros = false
        Notificar("📚 Felix Hub", "Todos os 8 livros encontrados!", 5)
    end
end

-- Figure — busca em QUALQUER lugar do workspace
-- FigureRig é um Model; DescendantAdded pega quando ele aparece
local function ProcessarFigure(obj)
    if not Config.ESP_Ativo or not Config.ESP_Figure then return end
    if not Estado.ProcurandoFigure then return end
    -- Verifica se é o modelo raiz chamado FigureRig
    if obj.Name ~= "FigureRig" then return end
    local uid = obj:GetFullName()
    if Cache[uid] then return end
    Estado.ProcurandoFigure = false
    CriarESP(obj, Config.CorFigure, "FIGURE!")
    if Config.EntityWarning_Ativo then
        Notificar("⚠️ PERIGO!", "Figure apareceu! Esconda-se!", 6)
    end
end

-- Screech
local function ProcessarScreech(obj)
    if not Config.ESP_Ativo or not Config.ESP_Screech then return end
    if Config.RemoverScreech_Ativo then
        pcall(function() obj:Destroy() end)
        Notificar("Felix Hub", "Screech removido!", 3)
        return
    end
    CriarESP(obj, Config.CorScreech, "SCREECH!")
    if Config.EntityWarning_Ativo then
        Notificar("⚠️ SCREECH!", "Olhe para o Screech!", 4)
    end
end

-- Itens do chão
local NomesItens = {
    -- Nome exato do objeto = label exibida
    ["Flashlight"]       = "LANTERNA",
    ["Lighter"]          = "ISQUEIRO",
    ["Vitamins"]         = "VITAMINA",
    ["Lockpick"]         = "LOCKPICK",
    ["Bandage"]          = "BANDAGEM",
    ["Crucifix"]         = "CRUCIFIXO",
    ["GreenSoup"]        = "SOPA VERDE",   -- copão verde
    ["GreenHerb"]        = "ERVA VERDE",
    ["Candle"]           = "VELA",
    ["RedVial"]          = "POÇÃO VERMELHA",
}

local function ProcessarItem(obj)
    if not Config.ESP_Ativo or not Config.ESP_Itens then return end
    local label = NomesItens[obj.Name]
    if not label then return end
    CriarESP(obj, Config.CorItem, label)
end

-- Baús (Chests)
local NomesBaus = {
    ["Chest"]      = true,
    ["GoldChest"]  = true,
    ["CraftChest"] = true,
    ["LockedChest"]= true,
}

local function ProcessarBau(obj)
    if not Config.ESP_Ativo or not Config.ESP_Baus then return end
    if not NomesBaus[obj.Name] then return end
    local label = obj.Name == "GoldChest" and "BAÚ DOURADO" or "BAÚ"
    CriarESP(obj, Config.CorBau, label)
end

-- Fusíveis (Sala 100 — o jogo usa objetos chamados "Fuse" ou similares)
local NomesFusiveis = {
    ["Fuse"]        = true,
    ["FuseSocket"]  = true,
    ["FuseSlot"]    = true,
}

local function ProcessarFusivel(obj)
    if not Config.ESP_Ativo or not Config.ESP_Fusiveis then return end
    if not NomesFusiveis[obj.Name] then return end
    CriarESP(obj, Config.CorFusivel, "FUSIVEL")
end

-- Porta — número visual = interno + 1
local function ProcessarPorta(obj)
    if not Config.ESP_Ativo or not Config.ESP_Portas then return end

    local sala = obj.Parent
    local prof = 0
    while sala and sala ~= workspace and prof < 12 do
        if tonumber(sala.Name) ~= nil then break end
        sala = sala.Parent
        prof += 1
    end

    local numInterno = sala and tonumber(sala.Name)
    if numInterno == nil then return end
    local numVisual = numInterno + 1  -- FIX: número que o jogador vê

    local uid = "Porta_" .. numInterno
    if Cache[uid] then return end
    Cache[uid] = true

    -- Tenta pegar o modelo da porta: Sala.Door.Door
    local portaAlvo = obj
    pcall(function()
        local df = sala:FindFirstChild("Door")
        if df then
            local dp = df:FindFirstChild("Door")
            if dp then portaAlvo = dp end
        end
    end)

    CriarESP(portaAlvo, Config.CorPorta, "PORTA " .. numVisual)

    if Config.NotifPortas_Ativo then
        Notificar("🚪 Porta", "Próxima porta: " .. numVisual, 3)
    end

    -- Sala 50 interna = visual 51... ajuste se necessário
    -- Sala que ativa livros é a 49 interna (visual 50)
    if numInterno == 49 then
        Estado.ProcurandoFigure  = true
        Estado.ProcurandoLivros  = true
        Estado.LivrosEncontrados = 0
        -- Limpa cache de livros/figures para nova tentativa
        for k in pairs(Cache) do
            if k:find("LiveHintBook") or k:find("FigureRig") then
                Cache[k] = nil
            end
        end
        Notificar("📚 Sala 50!", "Buscando livros e Figure...", 5)
    end
end

-- ════════════════════════════════════════════
--  ROTEADOR PRINCIPAL
-- ════════════════════════════════════════════
local function ProcessarObjeto(obj)
    if not obj or not obj.Parent then return end
    local n = obj.Name

    -- Entidades
    if n == "FigureRig"    then ProcessarFigure(obj)   return end
    if n == "ScreechRig"   then ProcessarScreech(obj)  return end

    -- Itens de sala (precisam ser descendentes do mapa)
    if n == "KeyObtain"    then ProcessarChave(obj)    return end
    if n == "LeverForGate" then ProcessarAlavanca(obj) return end
    if n == "LiveHintBook" then ProcessarLivro(obj)    return end
    if n == "ClientOpen"   then ProcessarPorta(obj)    return end

    -- Itens coletáveis
    if NomesItens[n]   then ProcessarItem(obj)   return end
    if NomesBaus[n]    then ProcessarBau(obj)    return end
    if NomesFusiveis[n] then ProcessarFusivel(obj) return end
end

-- ════════════════════════════════════════════
--  INICIAR ESP
--  FigureRig: workspace.DescendantAdded global
--  Livros: scan completo + DescendantAdded
-- ════════════════════════════════════════════
local function IniciarESP()
    local CurrentRooms
    pcall(function()
        CurrentRooms = workspace:WaitForChild("CurrentRooms", 20)
    end)

    -- Scan inicial de tudo que já existe
    task.spawn(function()
        -- Scan no workspace inteiro (pega Figure, Screech onde quer que estejam)
        for _, obj in ipairs(workspace:GetDescendants()) do
            task.spawn(ProcessarObjeto, obj)
        end
    end)

    -- DescendantAdded no workspace inteiro (Figure pode aparecer fora de CurrentRooms)
    local conn = workspace.DescendantAdded:Connect(function(obj)
        task.spawn(ProcessarObjeto, obj)
    end)
    table.insert(Conexoes, conn)
end

-- ════════════════════════════════════════════
--  PROTEÇÃO CONTRA EYES
-- ════════════════════════════════════════════
local TakeDamageOriginal = nil
local ConexaoEyes        = nil

local function AtivarProtecaoEyes(ativo)
    Config.ProtecaoEyes_Ativo = ativo
    local function Aplicar(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if ativo then
            TakeDamageOriginal = hum.TakeDamage
            hum.TakeDamage = function() end
            Notificar("🛡️ Felix Hub", "Proteção de dano ativada!", 3)
        else
            if TakeDamageOriginal then
                hum.TakeDamage = TakeDamageOriginal
                TakeDamageOriginal = nil
            end
            Notificar("Felix Hub", "Proteção desativada.", 3)
        end
    end
    Aplicar(LocalPlayer.Character)
    if ConexaoEyes then ConexaoEyes:Disconnect() end
    if ativo then
        ConexaoEyes = LocalPlayer.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            Aplicar(char)
        end)
    end
end

-- ════════════════════════════════════════════
--  TOGGLES GERAIS
-- ════════════════════════════════════════════
local function ToggleFullbright(v)
    Lighting.Ambient        = v and Color3.fromRGB(255,255,255) or Color3.fromRGB(70,70,70)
    Lighting.OutdoorAmbient = v and Color3.fromRGB(255,255,255) or Color3.fromRGB(70,70,70)
    Lighting.Brightness     = v and 10 or 1
    Lighting.FogEnd         = 100000
end

local function ToggleAntiLag(v)
    pcall(function()
        settings().Rendering.QualityLevel = v and 1 or Enum.QualityLevel.Automatic
    end)
end

local function AplicarSpeed(v)
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end)
end

local function AplicarJump(v)
    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = v; hum.UseJumpPower = true end
    end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.4)
    if Config.WalkSpeed_Ativo then AplicarSpeed(Config.WalkSpeedValor) end
    if Config.JumpPower_Ativo  then AplicarJump(Config.JumpPowerValor) end
    if Config.ProtecaoEyes_Ativo then task.wait(0.3); AtivarProtecaoEyes(true) end
end)

-- ══════════════════════════════════════════════
--  INTERFACE GRÁFICA
-- ══════════════════════════════════════════════
local guiAnt = CoreGui:FindFirstChild("FelixHub_GUI")
if guiAnt then guiAnt:Destroy() end

local ScreenGui = Criar("ScreenGui", {
    Name           = "FelixHub_GUI",
    ResetOnSpawn   = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent         = CoreGui,
})

-- ─── BOTÃO FLUTUANTE ───
-- Frame apenas para posicionar; TextButton transparente por cima
local BotaoHolder = Criar("Frame", {
    Size             = UDim2.new(0, 48, 0, 48),
    Position         = UDim2.new(0, 16, 0.5, -24),
    BackgroundColor3 = Color3.fromRGB(12, 12, 18),
    BorderSizePixel  = 0,  -- sem borda nativa
    Parent           = ScreenGui,
})
Criar("UICorner", { CornerRadius = UDim.new(1, 0), Parent = BotaoHolder })
-- UIStroke dourado no frame, NÃO no botão
Criar("UIStroke", {
    Color             = Color3.fromRGB(212, 175, 55),
    Thickness         = 1.8,
    ApplyStrokeMode   = Enum.ApplyStrokeMode.Border,
    Parent            = BotaoHolder,
})

local BotaoGlow = Criar("ImageLabel", {
    Image                  = "rbxassetid://5028857472",
    ImageColor3            = Color3.fromRGB(212, 175, 55),
    ImageTransparency      = 0.65,
    BackgroundTransparency = 1,
    Size                   = UDim2.new(2.6, 0, 2.6, 0),
    Position               = UDim2.new(-0.8, 0, -0.8, 0),
    ZIndex                 = 0,
    Parent                 = BotaoHolder,
})

-- TextButton completamente transparente — sem borda, sem fundo
local BtnF = Criar("TextButton", {
    Text                   = "F",
    Font                   = Enum.Font.GothamBold,
    TextColor3             = Color3.fromRGB(212, 175, 55),
    TextSize               = 22,
    BackgroundTransparency = 1,   -- totalmente transparente
    BorderSizePixel        = 0,   -- sem borda quadrada
    AutoButtonColor        = false,
    Size                   = UDim2.new(1, 0, 1, 0),
    Parent                 = BotaoHolder,
})

-- ─── JANELA PRINCIPAL ───
local Janela = Criar("Frame", {
    Name             = "Janela",
    Size             = UDim2.new(0, 580, 0, 430),
    Position         = UDim2.new(0.5, -290, 0.5, -215),
    BackgroundColor3 = Color3.fromRGB(10, 10, 15),
    BorderSizePixel  = 0,
    ClipsDescendants = true,
    Visible          = false,
    Parent           = ScreenGui,
})
Criar("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Janela })
Criar("UIStroke", { Color = Color3.fromRGB(212, 175, 55), Thickness = 1.5, Parent = Janela })
Criar("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 13, 19)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 7, 11)),
    }),
    Rotation = 120,
    Parent   = Janela,
})

-- Header
local Header = Criar("Frame", {
    Size             = UDim2.new(1, 0, 0, 52),
    BackgroundColor3 = Color3.fromRGB(8, 8, 13),
    BorderSizePixel  = 0,
    Parent           = Janela,
})
Criar("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Header })
Criar("Frame", {
    Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1),
    BackgroundColor3=Color3.fromRGB(212,175,55), BorderSizePixel=0, Parent=Header,
})
Criar("TextLabel", {
    Text="⚡  FELIX HUB", Font=Enum.Font.GothamBold,
    TextColor3=Color3.fromRGB(212,175,55), TextSize=20,
    BackgroundTransparency=1, Size=UDim2.new(0.65,0,0.58,0),
    Position=UDim2.new(0,16,0.04,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=Header,
})
Criar("TextLabel", {
    Text="DOORS EDITION  v2.1", Font=Enum.Font.Gotham,
    TextColor3=Color3.fromRGB(140,120,55), TextSize=11,
    BackgroundTransparency=1, Size=UDim2.new(0.65,0,0.36,0),
    Position=UDim2.new(0,18,0.60,0), TextXAlignment=Enum.TextXAlignment.Left, Parent=Header,
})

local BtnMin = Criar("TextButton", {
    Text="─", Font=Enum.Font.GothamBold, TextColor3=Color3.fromRGB(212,175,55),
    TextSize=16, BackgroundColor3=Color3.fromRGB(20,20,30), BorderSizePixel=0,
    Size=UDim2.new(0,30,0,24), Position=UDim2.new(1,-68,0.5,-12), Parent=Header,
})
Criar("UICorner",{CornerRadius=UDim.new(0,6),Parent=BtnMin})

local BtnFecha = Criar("TextButton", {
    Text="✕", Font=Enum.Font.GothamBold, TextColor3=Color3.fromRGB(255,75,75),
    TextSize=14, BackgroundColor3=Color3.fromRGB(20,20,30), BorderSizePixel=0,
    Size=UDim2.new(0,30,0,24), Position=UDim2.new(1,-34,0.5,-12), Parent=Header,
})
Criar("UICorner",{CornerRadius=UDim.new(0,6),Parent=BtnFecha})

-- Sidebar
local Sidebar = Criar("Frame", {
    Size=UDim2.new(0,108,1,-52), Position=UDim2.new(0,0,0,52),
    BackgroundColor3=Color3.fromRGB(8,8,13), BorderSizePixel=0, Parent=Janela,
})
Criar("Frame",{
    Size=UDim2.new(0,1,1,0), Position=UDim2.new(1,0,0,0),
    BackgroundColor3=Color3.fromRGB(212,175,55), BackgroundTransparency=0.75,
    BorderSizePixel=0, Parent=Sidebar,
})
Criar("UIListLayout",{Padding=UDim.new(0,4), HorizontalAlignment=Enum.HorizontalAlignment.Center, Parent=Sidebar})
Criar("UIPadding",{PaddingTop=UDim.new(0,10), Parent=Sidebar})

-- Conteúdo
local Conteudo = Criar("Frame",{
    Size=UDim2.new(1,-108,1,-52), Position=UDim2.new(0,108,0,52),
    BackgroundTransparency=1, Parent=Janela,
})

-- ════════════════════════════
--  ABAS
-- ════════════════════════════
local Abas     = {}
local AbaAtiva = nil

local InfoAbas = {
    { nome="ESP",    icon="👁"  },
    { nome="Itens",  icon="🎒"  },
    { nome="Visual", icon="🎨"  },
    { nome="Player", icon="🏃"  },
    { nome="Doors",  icon="🚪"  },
    { nome="Info",   icon="ℹ️"   },
}

for _, info in ipairs(InfoAbas) do
    local btn = Criar("TextButton",{
        Text=info.icon.."\n"..info.nome, Font=Enum.Font.GothamBold,
        TextColor3=Color3.fromRGB(110,100,70), TextSize=10,
        BackgroundColor3=Color3.fromRGB(14,14,21),
        Size=UDim2.new(0.86,0,0,48), AutoButtonColor=false, BorderSizePixel=0, Parent=Sidebar,
    })
    Criar("UICorner",{CornerRadius=UDim.new(0,8),Parent=btn})

    local painel = Criar("ScrollingFrame",{
        Name="P_"..info.nome,
        Size=UDim2.new(1,-12,1,-8), Position=UDim2.new(0,6,0,4),
        BackgroundTransparency=1, BorderSizePixel=0,
        ScrollBarThickness=3, ScrollBarImageColor3=Color3.fromRGB(212,175,55),
        CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
        Visible=false, Parent=Conteudo,
    })
    Criar("UIListLayout",{Padding=UDim.new(0,7), HorizontalAlignment=Enum.HorizontalAlignment.Center, Parent=painel})
    Criar("UIPadding",{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),Parent=painel})
    Abas[info.nome] = { painel=painel, botao=btn }
end

local function AbrirAba(nome)
    for _, aba in pairs(Abas) do
        aba.painel.Visible = false
        Tween(aba.botao, TweenInfo.new(0.14), {
            BackgroundColor3=Color3.fromRGB(14,14,21), TextColor3=Color3.fromRGB(110,100,70),
        })
    end
    local aba = Abas[nome]
    if aba then
        aba.painel.Visible = true
        Tween(aba.botao, TweenInfo.new(0.14), {
            BackgroundColor3=Color3.fromRGB(28,24,7), TextColor3=Color3.fromRGB(212,175,55),
        })
        AbaAtiva = nome
    end
end
for nome, aba in pairs(Abas) do
    aba.botao.MouseButton1Click:Connect(function() AbrirAba(nome) end)
end

-- ════════════════════════════
--  COMPONENTES UI
-- ════════════════════════════
local function Secao(pai, nome)
    local f = Criar("Frame",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Parent=pai})
    Criar("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,0.5,0),
        BackgroundColor3=Color3.fromRGB(212,175,55),BackgroundTransparency=0.65,
        BorderSizePixel=0,Parent=f})
    Criar("TextLabel",{Text="  "..nome.."  ",Font=Enum.Font.GothamBold,
        TextColor3=Color3.fromRGB(212,175,55),TextSize=10,
        BackgroundColor3=Color3.fromRGB(10,10,15),
        Size=UDim2.new(0,0,1,0),Position=UDim2.new(0.5,0,0,0),
        AutomaticSize=Enum.AutomaticSize.X,TextXAlignment=Enum.TextXAlignment.Center,Parent=f})
end

local function CriarToggle(pai, texto, inicial, cb)
    local f = Criar("Frame",{
        Size=UDim2.new(1,0,0,34),BackgroundColor3=Color3.fromRGB(15,15,22),
        BorderSizePixel=0,Parent=pai,
    })
    Criar("UICorner",{CornerRadius=UDim.new(0,8),Parent=f})
    Criar("UIStroke",{Color=Color3.fromRGB(38,36,26),Thickness=1,Parent=f})
    Criar("TextLabel",{
        Text=texto,Font=Enum.Font.Gotham,TextColor3=Color3.fromRGB(195,185,145),TextSize=12,
        BackgroundTransparency=1,Size=UDim2.new(1,-50,1,0),Position=UDim2.new(0,10,0,0),
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=f,
    })
    local trilho = Criar("Frame",{
        Size=UDim2.new(0,36,0,18),Position=UDim2.new(1,-44,0.5,-9),
        BackgroundColor3=inicial and Color3.fromRGB(170,130,15) or Color3.fromRGB(34,34,40),
        BorderSizePixel=0,Parent=f,
    })
    Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=trilho})
    local bola = Criar("Frame",{
        Size=UDim2.new(0,12,0,12),
        Position=inicial and UDim2.new(0,21,0.5,-6) or UDim2.new(0,3,0.5,-6),
        BackgroundColor3=Color3.fromRGB(255,255,255),BorderSizePixel=0,Parent=trilho,
    })
    Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=bola})
    local estado = inicial
    local btn2 = Criar("TextButton",{Text="",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),Parent=f})
    btn2.MouseButton1Click:Connect(function()
        estado = not estado
        Tween(trilho,TweenInfo.new(0.16),{BackgroundColor3=estado and Color3.fromRGB(170,130,15) or Color3.fromRGB(34,34,40)})
        Tween(bola,TweenInfo.new(0.16),{Position=estado and UDim2.new(0,21,0.5,-6) or UDim2.new(0,3,0.5,-6)})
        pcall(cb, estado)
    end)
end

local function CriarSlider(pai, texto, mn, mx, ini, cb)
    local f = Criar("Frame",{
        Size=UDim2.new(1,0,0,50),BackgroundColor3=Color3.fromRGB(15,15,22),
        BorderSizePixel=0,Parent=pai,
    })
    Criar("UICorner",{CornerRadius=UDim.new(0,8),Parent=f})
    Criar("UIStroke",{Color=Color3.fromRGB(38,36,26),Thickness=1,Parent=f})
    local lbl = Criar("TextLabel",{
        Text=texto..": "..ini,Font=Enum.Font.Gotham,TextColor3=Color3.fromRGB(195,185,145),TextSize=12,
        BackgroundTransparency=1,Size=UDim2.new(1,-8,0,20),Position=UDim2.new(0,10,0,4),
        TextXAlignment=Enum.TextXAlignment.Left,Parent=f,
    })
    local trilho = Criar("Frame",{
        Size=UDim2.new(1,-20,0,5),Position=UDim2.new(0,10,0,30),
        BackgroundColor3=Color3.fromRGB(34,34,40),BorderSizePixel=0,Parent=f,
    })
    Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=trilho})
    local p0=(ini-mn)/(mx-mn)
    local fill=Criar("Frame",{Size=UDim2.new(p0,0,1,0),BackgroundColor3=Color3.fromRGB(212,175,55),BorderSizePixel=0,Parent=trilho})
    Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=fill})
    local knob=Criar("Frame",{Size=UDim2.new(0,12,0,12),Position=UDim2.new(p0,-6,0.5,-6),
        BackgroundColor3=Color3.fromRGB(240,230,200),BorderSizePixel=0,Parent=trilho})
    Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=knob})
    local drag=false
    local function Upd(x)
        local p=math.clamp((x-trilho.AbsolutePosition.X)/trilho.AbsoluteSize.X,0,1)
        local v=math.floor(mn+(mx-mn)*p)
        fill.Size=UDim2.new(p,0,1,0); knob.Position=UDim2.new(p,-6,0.5,-6)
        lbl.Text=texto..": "..v; pcall(cb,v)
    end
    trilho.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true;Upd(i.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then Upd(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end
    end)
end

-- ════════════════════════════
--  CONTEÚDO DAS ABAS
-- ════════════════════════════

-- ABA ESP
local pESP = Abas["ESP"].painel
Secao(pESP,"Geral")
CriarToggle(pESP,"Ativar ESP",          Config.ESP_Ativo,           function(v) Config.ESP_Ativo=v end)
CriarToggle(pESP,"Highlight",           Config.Highlight_Ativo,     function(v) Config.Highlight_Ativo=v end)
CriarToggle(pESP,"Billboard (Labels)",  Config.Billboard_Ativo,     function(v) Config.Billboard_Ativo=v end)
CriarToggle(pESP,"Mostrar Distância",   Config.Distancia_Ativo,     function(v) Config.Distancia_Ativo=v end)
CriarToggle(pESP,"Aviso de Entidade",   Config.EntityWarning_Ativo, function(v) Config.EntityWarning_Ativo=v end)
Secao(pESP,"Selecionar")
CriarToggle(pESP,"🚪 Portas",    Config.ESP_Portas,    function(v) Config.ESP_Portas=v end)
CriarToggle(pESP,"🔵 Chaves",    Config.ESP_Chaves,    function(v) Config.ESP_Chaves=v end)
CriarToggle(pESP,"🟠 Alavancas", Config.ESP_Alavancas, function(v) Config.ESP_Alavancas=v end)
CriarToggle(pESP,"🟣 Livros",    Config.ESP_Livros,    function(v) Config.ESP_Livros=v end)
CriarToggle(pESP,"🔴 Figure",    Config.ESP_Figure,    function(v) Config.ESP_Figure=v end)
CriarToggle(pESP,"🔴 Screech",   Config.ESP_Screech,   function(v) Config.ESP_Screech=v end)
Secao(pESP,"Busca Manual")
CriarToggle(pESP,"Buscar Figure", false, function(v)
    Estado.ProcurandoFigure=v
    if v then Notificar("Felix Hub","Buscando Figure...",3) end
end)
CriarToggle(pESP,"Buscar Livros (Sala 50)", false, function(v)
    Estado.ProcurandoLivros=v
    if v then Estado.LivrosEncontrados=0; Notificar("Felix Hub","Buscando livros...",3) end
end)

-- ABA ITENS
local pItens = Abas["Itens"].painel
Secao(pItens,"Itens Coletáveis")
CriarToggle(pItens,"🟢 Itens (lanterna, vitamina...)", Config.ESP_Itens, function(v) Config.ESP_Itens=v end)
CriarToggle(pItens,"🟡 Baús",     Config.ESP_Baus,    function(v) Config.ESP_Baus=v end)
CriarToggle(pItens,"🟠 Fusíveis", Config.ESP_Fusiveis,function(v) Config.ESP_Fusiveis=v end)
Secao(pItens,"Lista de Itens Detectados")
Criar("TextLabel",{
    Text="• Lanterna\n• Isqueiro\n• Vitamina\n• Lockpick\n• Bandagem\n• Crucifixo\n• Sopa Verde\n• Erva Verde\n• Vela\n• Poção Vermelha\n• Baús (normal/dourado)\n• Fusíveis (Sala 100)",
    Font=Enum.Font.Gotham, TextColor3=Color3.fromRGB(160,150,100), TextSize=11,
    BackgroundColor3=Color3.fromRGB(15,15,22), BackgroundTransparency=0,
    Size=UDim2.new(1,0,0,170), TextWrapped=true, TextYAlignment=Enum.TextYAlignment.Top,
    Parent=pItens,
})

-- ABA VISUAL
local pVis = Abas["Visual"].painel
Secao(pVis,"Iluminação")
CriarToggle(pVis,"Fullbright", false, ToggleFullbright)
CriarToggle(pVis,"Anti-Lag",   false, ToggleAntiLag)
Secao(pVis,"Câmera")
CriarToggle(pVis,"FOV Customizado", false, function(v)
    Config.FOVChanger_Ativo=v; Camera.FieldOfView=v and Config.FOVValor or 70
end)
CriarSlider(pVis,"FOV",60,120,70,function(v)
    Config.FOVValor=v; if Config.FOVChanger_Ativo then Camera.FieldOfView=v end
end)

-- ABA PLAYER
local pPlay = Abas["Player"].painel
Secao(pPlay,"Movimento")
CriarToggle(pPlay,"WalkSpeed", false, function(v)
    Config.WalkSpeed_Ativo=v; AplicarSpeed(v and Config.WalkSpeedValor or 16)
end)
CriarSlider(pPlay,"Speed",8,100,16,function(v)
    Config.WalkSpeedValor=v; if Config.WalkSpeed_Ativo then AplicarSpeed(v) end
end)
CriarToggle(pPlay,"JumpPower", false, function(v)
    Config.JumpPower_Ativo=v; AplicarJump(v and Config.JumpPowerValor or 50)
end)
CriarSlider(pPlay,"Jump",30,200,50,function(v)
    Config.JumpPowerValor=v; if Config.JumpPower_Ativo then AplicarJump(v) end
end)

-- ABA DOORS
local pDoors = Abas["Doors"].painel
Secao(pDoors,"Proteção")
CriarToggle(pDoors,"🛡️ Proteção contra Eyes", false, function(v) AtivarProtecaoEyes(v) end)
CriarToggle(pDoors,"Remover Screech (auto)", Config.RemoverScreech_Ativo, function(v)
    Config.RemoverScreech_Ativo=v
end)
Secao(pDoors,"Notificações")
CriarToggle(pDoors,"Notif. de Portas", Config.NotifPortas_Ativo, function(v) Config.NotifPortas_Ativo=v end)
Secao(pDoors,"Sala 50 Manual")
local btn50 = Criar("TextButton",{
    Text="⚡  Ativar Modo Sala 50", Font=Enum.Font.GothamBold,
    TextColor3=Color3.fromRGB(212,175,55), TextSize=13,
    BackgroundColor3=Color3.fromRGB(28,22,6), BorderSizePixel=0,
    Size=UDim2.new(1,0,0,34), Parent=pDoors,
})
Criar("UICorner",{CornerRadius=UDim.new(0,8),Parent=btn50})
Criar("UIStroke",{Color=Color3.fromRGB(212,175,55),Thickness=1,Parent=btn50})
btn50.MouseButton1Click:Connect(function()
    Estado.ProcurandoFigure=true; Estado.ProcurandoLivros=true; Estado.LivrosEncontrados=0
    for k in pairs(Cache) do
        if k:find("LiveHintBook") or k:find("FigureRig") then Cache[k]=nil end
    end
    Notificar("📚 Sala 50","Buscando Figure + Livros...",5)
end)

-- ABA INFO
local pInfo = Abas["Info"].painel
Secao(pInfo,"Felix Hub v2.1")
Criar("TextLabel",{
    Text="Felix Hub  v2.1\nDOORS Edition\n\n✅ Mobile & PC\n✅ Delta / Hydrogen\n✅ Fluxus / Arceus X\n\n• RCtrl ou F9 = abre/fecha\n• Botão F na tela = abre/fecha\n• Arraste o header pra mover\n\nFeito com  ♥",
    Font=Enum.Font.Gotham, TextColor3=Color3.fromRGB(175,160,110), TextSize=12,
    BackgroundColor3=Color3.fromRGB(15,15,22), BackgroundTransparency=0,
    Size=UDim2.new(1,0,0,165), TextWrapped=true, TextYAlignment=Enum.TextYAlignment.Top,
    Parent=pInfo,
})

-- ════════════════════════════
--  ARRASTAR JANELA
-- ════════════════════════════
local drg, drgOff = false, Vector2.zero
Header.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        drg=true
        drgOff=Vector2.new(i.Position.X-Janela.AbsolutePosition.X, i.Position.Y-Janela.AbsolutePosition.Y)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if drg and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local vp=Camera.ViewportSize
        Janela.Position=UDim2.new(0,
            math.clamp(i.Position.X-drgOff.X, 0, vp.X-Janela.AbsoluteSize.X), 0,
            math.clamp(i.Position.Y-drgOff.Y, 0, vp.Y-Janela.AbsoluteSize.Y))
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drg=false end
end)

-- ════════════════════════════
--  ARRASTAR BOTÃO FLUTUANTE
-- ════════════════════════════
local btnDrg, btnOff, btnMoveu = false, Vector2.zero, false
BotaoHolder.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        btnDrg=true; btnMoveu=false
        local p=BotaoHolder.AbsolutePosition
        btnOff=Vector2.new(i.Position.X-p.X, i.Position.Y-p.Y)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if btnDrg and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local vp=Camera.ViewportSize
        BotaoHolder.Position=UDim2.new(0,
            math.clamp(i.Position.X-btnOff.X, 0, vp.X-48), 0,
            math.clamp(i.Position.Y-btnOff.Y, 0, vp.Y-48))
        btnMoveu=true
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then btnDrg=false end
end)

-- ════════════════════════════
--  ABRIR / FECHAR
-- ════════════════════════════
local HubAberto  = false
local Minimizado = false

local function AbrirHub()
    HubAberto=true; Janela.Visible=true; Janela.Size=UDim2.new(0,20,0,20)
    Tween(Janela, TweenInfo.new(0.24,Enum.EasingStyle.Back,Enum.EasingDirection.Out), {Size=UDim2.new(0,580,0,430)})
    if AbaAtiva==nil then AbrirAba("ESP") end
end
local function FecharHub()
    HubAberto=false
    Tween(Janela, TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Size=UDim2.new(0,20,0,20)})
    task.delay(0.2, function() if not HubAberto then Janela.Visible=false end end)
end
local function ToggleHub() if HubAberto then FecharHub() else AbrirHub() end end
local function MinHub()
    Minimizado=not Minimizado
    if Minimizado then
        Tween(Janela,TweenInfo.new(0.18),{Size=UDim2.new(0,580,0,52)})
        Conteudo.Visible=false; Sidebar.Visible=false
    else
        Tween(Janela,TweenInfo.new(0.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,580,0,430)})
        Conteudo.Visible=true; Sidebar.Visible=true
    end
end

-- Clique simples — só abre se não arrastou
BtnF.MouseButton1Click:Connect(function()
    if not btnMoveu then ToggleHub() end
    btnMoveu=false
end)
BtnFecha.MouseButton1Click:Connect(FecharHub)
BtnMin.MouseButton1Click:Connect(MinHub)

UserInputService.InputBegan:Connect(function(i, proc)
    if proc then return end
    if i.KeyCode==Enum.KeyCode.RightControl or i.KeyCode==Enum.KeyCode.F9 then ToggleHub() end
end)

-- Hover
BotaoHolder.MouseEnter:Connect(function()
    Tween(BotaoHolder,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(24,20,6)})
    Tween(BotaoGlow,TweenInfo.new(0.14),{ImageTransparency=0.3})
end)
BotaoHolder.MouseLeave:Connect(function()
    Tween(BotaoHolder,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(12,12,18)})
    Tween(BotaoGlow,TweenInfo.new(0.14),{ImageTransparency=0.65})
end)

-- Pulso do glow
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        Tween(BotaoGlow,TweenInfo.new(1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{ImageTransparency=0.38})
        task.wait(1.6)
        Tween(BotaoGlow,TweenInfo.new(1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{ImageTransparency=0.72})
        task.wait(1.6)
    end
end)

-- ════════════════════════════════════════════
--  INICIAR
-- ════════════════════════════════════════════
AbrirAba("ESP")
task.spawn(IniciarESP)
task.delay(0.6, function()
    Notificar("⚡ Felix Hub v2.1","Carregado! Clique no F ou aperte RCtrl.",5)
end)

print([[
╔══════════════════════════════════════════╗
║        FELIX HUB v2.1 — CARREGADO        ║
║   Clique no F  |  RCtrl / F9 pra abrir   ║
╚══════════════════════════════════════════╝
]])
