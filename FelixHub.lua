--[[
╔══════════════════════════════════════════════════════════╗
║               FELIX HUB v1.0 - DOORS EDITION             ║
║         Script Premium | Mobile & PC Optimized           ║
║    Executors: Delta, Hydrogen, Fluxus, Arceus X          ║
╚══════════════════════════════════════════════════════════╝
]]

-- ════════════════════════════════════════════
--  PROTEÇÃO ANTI-DUPLICAÇÃO PRINCIPAL
-- ════════════════════════════════════════════
if _G.FelixHubCarregado then
    warn("[FelixHub] Já está carregado. Ignorando duplicata.")
    return
end
_G.FelixHubCarregado = true

-- ════════════════════════════════════════════
--  SERVIÇOS
-- ════════════════════════════════════════════
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local StarterGui         = game:GetService("StarterGui")
local Lighting           = game:GetService("Lighting")
local CoreGui            = game:GetService("CoreGui")

-- ════════════════════════════════════════════
--  REFERÊNCIAS BÁSICAS
-- ════════════════════════════════════════════
local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

-- ════════════════════════════════════════════
--  CONFIGURAÇÕES GLOBAIS
-- ════════════════════════════════════════════
local Config = {
    -- ESP
    ESP_Ativo           = true,
    Highlight_Ativo     = true,
    Billboard_Ativo     = true,
    Distancia_Ativo     = true,
    EntityWarning_Ativo = true,

    -- Visual
    Fullbright_Ativo    = false,
    AntiLag_Ativo       = false,
    BlurFundo_Ativo     = false,
    FOVChanger_Ativo    = false,
    FOVValor            = 120,

    -- Player
    WalkSpeed_Ativo     = false,
    WalkSpeedValor      = 16,
    JumpPower_Ativo     = false,
    JumpPowerValor      = 50,

    -- Doors
    RemoverScreech_Ativo      = false,
    NotifPortas_Ativo         = true,
    AutoInteracao_Ativo       = false,

    -- Cores ESP
    CorPorta    = Color3.fromRGB(255, 215, 0),
    CorChave    = Color3.fromRGB(30, 144, 255),
    CorAlavanca = Color3.fromRGB(255, 140, 0),
    CorLivro    = Color3.fromRGB(160, 32, 240),
    CorFigure   = Color3.fromRGB(220, 20, 60),
    CorScreech  = Color3.fromRGB(200, 0, 0),

    -- Distância máxima do Billboard
    MaxDistancia = 500,
    IntervaloDistancia = 0.2,
}

-- ════════════════════════════════════════════
--  ESTADO DO JOGO (DOORS)
-- ════════════════════════════════════════════
local Estado = {
    ProcurandoFigure  = false,
    ProcurandoLivros  = false,
    LivrosEncontrados = 0,
    SalaAtual         = 0,
}

-- ════════════════════════════════════════════
--  CACHE ANTI-DUPLICAÇÃO
-- ════════════════════════════════════════════
local Processados = {
    Portas    = {},
    Chaves    = {},
    Alavancas = {},
    Livros    = {},
    Figuras   = {},
    Screechs  = {},
}

-- ════════════════════════════════════════════
--  CONEXÕES (para limpeza)
-- ════════════════════════════════════════════
local Conexoes = {}

-- ════════════════════════════════════════════
--  UTILITÁRIOS GERAIS
-- ════════════════════════════════════════════

-- Criar instância com propriedades de forma limpa
local function Criar(classe, props)
    local obj = Instance.new(classe)
    for k, v in pairs(props) do
        pcall(function() obj[k] = v end)
    end
    return obj
end

-- Tween suave
local function Tween(obj, info, props)
    TweenService:Create(obj, info, props):Play()
end

-- Notificação elegante
local function Notificar(titulo, texto, duracao)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = titulo or "Felix Hub",
            Text     = texto  or "",
            Duration = duracao or 4,
        })
    end)
end

-- ════════════════════════════════════════════
--  FUNÇÃO: EhNumeroValido (sala 1-100)
-- ════════════════════════════════════════════
local function EhNumeroValido(nome)
    local n = tonumber(nome)
    return n ~= nil and n >= 1 and n <= 100
end

-- ════════════════════════════════════════════
--  FUNÇÃO: GetAdorneePart
--  Retorna BasePart válida de Model ou BasePart
-- ════════════════════════════════════════════
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
--  FUNÇÃO: CriarBillboard
-- ════════════════════════════════════════════
local function CriarBillboard(alvo, texto, cor)
    if not Config.Billboard_Ativo then return end
    local parte = GetAdorneePart(alvo)
    if not parte then return end

    -- Anti-duplicação por UID
    local uid = "BB_" .. alvo:GetFullName():gsub("[^%w]", "_")
    if alvo:GetAttribute("FelixBillboardUID") == uid then return end

    -- Remove billboard antigo se existir
    local antigo = CoreGui:FindFirstChild(uid)
    if antigo then antigo:Destroy() end

    alvo:SetAttribute("FelixBillboardUID", uid)

    local bbg = Criar("BillboardGui", {
        Name            = uid,
        Adornee         = parte,
        AlwaysOnTop     = true,
        LightInfluence  = 0,
        MaxDistance     = Config.MaxDistancia,
        Size            = UDim2.new(0, 160, 0, 40),
        StudsOffset     = Vector3.new(0, 2.5, 0),
        Parent          = CoreGui,
    })

    local frame = Criar("Frame", {
        BackgroundColor3 = Color3.fromRGB(10, 10, 15),
        BackgroundTransparency = 0.3,
        Size             = UDim2.new(1, 0, 1, 0),
        Parent           = bbg,
    })
    Criar("UICorner", { CornerRadius = UDim.new(0, 6), Parent = frame })
    Criar("UIStroke", { Color = cor, Thickness = 1.5, Parent = frame })

    local label = Criar("TextLabel", {
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 1, 0),
        Font                   = Enum.Font.GothamBold,
        TextColor3             = cor,
        TextStrokeColor3       = Color3.fromRGB(0, 0, 0),
        TextStrokeTransparency = 0.4,
        TextScaled             = true,
        Text                   = texto,
        Parent                 = frame,
    })

    -- Atualização leve de distância
    local conexaoDistancia
    conexaoDistancia = RunService.Heartbeat:Connect(function()
        if not bbg or not bbg.Parent then
            conexaoDistancia:Disconnect()
            return
        end
        if not Config.Distancia_Ativo then
            label.Text = texto
            return
        end
        pcall(function()
            local dist = math.floor((Camera.CFrame.Position - parte.Position).Magnitude)
            label.Text = texto .. "\n[" .. dist .. "m]"
        end)
    end)

    -- Intervalo para não sobrecarregar
    local ultimo = 0
    local conn2
    conn2 = RunService.Heartbeat:Connect(function()
        local agora = tick()
        if agora - ultimo < Config.IntervaloDistancia then return end
        ultimo = agora
        -- Atualizado no loop acima, apenas throttle
    end)

    -- Limpeza automática
    alvo.AncestryChanged:Connect(function()
        if not alvo:IsDescendantOf(game) then
            pcall(function() bbg:Destroy() end)
            pcall(function() conexaoDistancia:Disconnect() end)
            pcall(function() conn2:Disconnect() end)
        end
    end)

    return bbg
end

-- ════════════════════════════════════════════
--  FUNÇÃO: CriarDestaque (Highlight)
-- ════════════════════════════════════════════
local function CriarDestaque(alvo, cor, textoBillboard)
    if not Config.Highlight_Ativo then
        if Config.Billboard_Ativo then
            CriarBillboard(alvo, textoBillboard or "?", cor)
        end
        return
    end

    -- Anti-duplicação
    local uid = "HL_" .. alvo:GetFullName():gsub("[^%w]", "_")
    if alvo:FindFirstChild(uid) then return end

    local hl = Criar("Highlight", {
        Name               = uid,
        Adornee            = alvo,
        FillColor          = cor,
        FillTransparency   = 0.55,
        OutlineColor       = Color3.fromRGB(255, 255, 255),
        OutlineTransparency = 0,
        DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop,
        Enabled            = true,
        Parent             = alvo,
    })

    -- Animação suave de pulso
    local info = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    Tween(hl, info, { FillTransparency = 0.75 })

    -- Billboard junto
    if Config.Billboard_Ativo then
        CriarBillboard(alvo, textoBillboard or "?", cor)
    end

    -- Limpeza automática
    alvo.AncestryChanged:Connect(function()
        if not alvo:IsDescendantOf(game) then
            pcall(function() hl:Destroy() end)
        end
    end)

    return hl
end

-- ════════════════════════════════════════════
--  ESP: FUNÇÕES POR TIPO
-- ════════════════════════════════════════════

local function ProcessarChave(obj)
    if not Config.ESP_Ativo then return end
    local uid = obj:GetFullName()
    if Processados.Chaves[uid] then return end
    Processados.Chaves[uid] = true
    CriarDestaque(obj, Config.CorChave, "🔵 CHAVE")
end

local function ProcessarAlavanca(obj)
    if not Config.ESP_Ativo then return end
    local uid = obj:GetFullName()
    if Processados.Alavancas[uid] then return end
    Processados.Alavancas[uid] = true
    local main = obj:FindFirstChild("Main") or obj
    CriarDestaque(main, Config.CorAlavanca, "🟠 ALAVANCA")
end

local function ProcessarLivro(obj)
    if not Config.ESP_Ativo then return end
    if not Estado.ProcurandoLivros then return end
    local uid = obj:GetFullName()
    if Processados.Livros[uid] then return end
    Processados.Livros[uid] = true
    Estado.LivrosEncontrados = Estado.LivrosEncontrados + 1
    local n = Estado.LivrosEncontrados
    CriarDestaque(obj, Config.CorLivro, "🟣 LIVRO " .. n .. "/8")
    if n >= 8 then
        Estado.ProcurandoLivros = false
        Notificar("📚 Felix Hub", "Todos os 8 livros encontrados!", 5)
    end
end

local function ProcessarFigure(obj)
    if not Config.ESP_Ativo then return end
    if not Estado.ProcurandoFigure then return end
    local uid = obj:GetFullName()
    if Processados.Figuras[uid] then return end
    Processados.Figuras[uid] = true
    Estado.ProcurandoFigure = false
    CriarDestaque(obj, Config.CorFigure, "🔴 FIGURE!")
    if Config.EntityWarning_Ativo then
        Notificar("⚠️ PERIGO!", "Figure apareceu! Esconda-se!", 6)
    end
end

local function ProcessarScreech(obj)
    if not Config.ESP_Ativo then return end
    local uid = obj:GetFullName()
    if Processados.Screechs[uid] then return end
    Processados.Screechs[uid] = true
    CriarDestaque(obj, Config.CorScreech, "🔴 SCREECH!")
    if Config.EntityWarning_Ativo then
        Notificar("⚠️ SCREECH!", "Olhe para o Screech!", 4)
    end
    -- Remover Screech se toggle ativo
    if Config.RemoverScreech_Ativo then
        pcall(function() obj:Destroy() end)
    end
end

local function ProcessarPorta(obj)
    if not Config.ESP_Ativo then return end
    -- Procurar sala pai
    local sala = obj.Parent
    while sala and sala ~= workspace do
        if EhNumeroValido(sala.Name) then break end
        sala = sala.Parent
    end
    local numSala = sala and tonumber(sala.Name) or 0
    if numSala == 0 then return end

    local uid = "Porta_" .. numSala
    if Processados.Portas[uid] then return end
    Processados.Portas[uid] = true

    -- Adornee: usar o pai da ClientOpen como porta
    local portaObj = obj.Parent
    CriarDestaque(portaObj, Config.CorPorta, "🚪 PORTA " .. numSala)

    if Config.NotifPortas_Ativo then
        Notificar("🚪 Porta Detectada", "Próxima porta: " .. numSala, 3)
    end

    -- Verificar sala 50 (Figure + Livros)
    if numSala == 50 then
        Estado.ProcurandoFigure  = true
        Estado.ProcurandoLivros  = true
        Estado.LivrosEncontrados = 0
        -- Limpar cache livros/figures para nova sala
        Processados.Livros  = {}
        Processados.Figuras = {}
        Notificar("📚 Felix Hub", "Sala 50! Modo livros + Figure ativado!", 5)
    end
end

-- ════════════════════════════════════════════
--  ESP: LISTENER PRINCIPAL (único DescendantAdded)
-- ════════════════════════════════════════════
local CurrentRooms = nil

local function IniciarESP()
    pcall(function()
        CurrentRooms = workspace:WaitForChild("CurrentRooms", 15)
    end)
    if not CurrentRooms then
        warn("[FelixHub] CurrentRooms não encontrado. ESP limitado.")
    end

    local function ProcessarObjeto(obj)
        if not obj or not obj.Parent then return end

        -- Verificar se pertence ao mapa de salas
        local pertence = true
        if CurrentRooms then
            pertence = obj:IsDescendantOf(CurrentRooms)
        end
        if not pertence then return end

        local nome = obj.Name

        if nome == "KeyObtain"    then ProcessarChave(obj)
        elseif nome == "LeverForGate" then ProcessarAlavanca(obj)
        elseif nome == "LiveHintBook" then ProcessarLivro(obj)
        elseif nome == "FigureRig"    then ProcessarFigure(obj)
        elseif nome == "ScreechRig"   then ProcessarScreech(obj)
        elseif nome == "ClientOpen"   then ProcessarPorta(obj)
        end
    end

    -- Objetos já existentes
    if CurrentRooms then
        for _, obj in ipairs(CurrentRooms:GetDescendants()) do
            task.spawn(ProcessarObjeto, obj)
        end
    end

    -- Listener único
    local conn = workspace.DescendantAdded:Connect(function(obj)
        task.spawn(ProcessarObjeto, obj)
    end)
    table.insert(Conexoes, conn)
end

-- ════════════════════════════════════════════
--  FUNÇÕES DE TOGGLE
-- ════════════════════════════════════════════

local BlurInstance = nil

local function ToggleFullbright(ativo)
    Config.Fullbright_Ativo = ativo
    if ativo then
        Lighting.Ambient       = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness    = 10
        Lighting.ClockTime     = 14
        Lighting.FogEnd        = 100000
    else
        Lighting.Ambient       = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
        Lighting.Brightness    = 1
        Lighting.ClockTime     = 14
        Lighting.FogEnd        = 100000
    end
end

local function ToggleBlur(ativo)
    Config.BlurFundo_Ativo = ativo
    if ativo then
        if not BlurInstance then
            BlurInstance = Criar("BlurEffect", { Size = 16, Parent = Lighting })
        end
        BlurInstance.Enabled = true
    else
        if BlurInstance then BlurInstance.Enabled = false end
    end
end

local function ToggleAntiLag(ativo)
    Config.AntiLag_Ativo = ativo
    if ativo then
        settings().Rendering.QualityLevel = 1
    else
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end
end

local function AplicarWalkSpeed(val)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = val end
    end
end

local function AplicarJumpPower(val)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.JumpPower = val
            hum.UseJumpPower = true
        end
    end
end

-- Aplicar sempre que reaparecer
LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid", 5)
    if Config.WalkSpeed_Ativo then AplicarWalkSpeed(Config.WalkSpeedValor) end
    if Config.JumpPower_Ativo then AplicarJumpPower(Config.JumpPowerValor) end
end)

-- ════════════════════════════════════════════
--  INTERFACE GRÁFICA — FELIX HUB
-- ════════════════════════════════════════════

-- Limpar GUI anterior
local guiAnterior = CoreGui:FindFirstChild("FelixHub_GUI")
if guiAnterior then guiAnterior:Destroy() end

local ScreenGui = Criar("ScreenGui", {
    Name                  = "FelixHub_GUI",
    ResetOnSpawn          = false,
    IgnoreGuiInset        = true,
    ZIndexBehavior        = Enum.ZIndexBehavior.Sibling,
    Parent                = CoreGui,
})

-- ════════════════════════════
-- BOTÃO FLUTUANTE (Abrir/Fechar)
-- ════════════════════════════
local BotaoFlutuante = Criar("Frame", {
    Name             = "BotaoFlutuante",
    Size             = UDim2.new(0, 56, 0, 56),
    Position         = UDim2.new(0, 20, 0.5, -28),
    BackgroundColor3 = Color3.fromRGB(15, 15, 20),
    BorderSizePixel  = 0,
    Parent           = ScreenGui,
})
Criar("UICorner", { CornerRadius = UDim.new(1, 0), Parent = BotaoFlutuante })
Criar("UIStroke", { Color = Color3.fromRGB(212, 175, 55), Thickness = 2, Parent = BotaoFlutuante })

local BotaoLabel = Criar("TextLabel", {
    Text             = "F",
    Font             = Enum.Font.GothamBold,
    TextColor3       = Color3.fromRGB(212, 175, 55),
    TextSize         = 26,
    BackgroundTransparency = 1,
    Size             = UDim2.new(1,0,1,0),
    Parent           = BotaoFlutuante,
})

-- Glow no botão
local BotaoGlow = Criar("ImageLabel", {
    Image            = "rbxassetid://5028857472",
    ImageColor3      = Color3.fromRGB(212, 175, 55),
    ImageTransparency = 0.6,
    BackgroundTransparency = 1,
    Size             = UDim2.new(2.2, 0, 2.2, 0),
    Position         = UDim2.new(-0.6, 0, -0.6, 0),
    ZIndex           = 0,
    Parent           = BotaoFlutuante,
})

-- ════════════════════════════
-- JANELA PRINCIPAL
-- ════════════════════════════
local Janela = Criar("Frame", {
    Name             = "Janela",
    Size             = UDim2.new(0, 560, 0, 400),
    Position         = UDim2.new(0.5, -280, 0.5, -200),
    BackgroundColor3 = Color3.fromRGB(10, 10, 15),
    BorderSizePixel  = 0,
    ClipsDescendants = true,
    Visible          = false,
    Parent           = ScreenGui,
})
Criar("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Janela })
Criar("UIStroke", { Color = Color3.fromRGB(212, 175, 55), Thickness = 1.5, Parent = Janela })

-- Gradiente de fundo
local GradFundo = Criar("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 12, 18)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 12)),
    }),
    Rotation = 135,
    Parent = Janela,
})

-- ─── TOPO / HEADER ───
local Header = Criar("Frame", {
    Name             = "Header",
    Size             = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = Color3.fromRGB(8, 8, 12),
    BorderSizePixel  = 0,
    Parent           = Janela,
})
Criar("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Header })

-- Linha dourada embaixo do header
Criar("Frame", {
    Size             = UDim2.new(1, 0, 0, 1),
    Position         = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = Color3.fromRGB(212, 175, 55),
    BorderSizePixel  = 0,
    Parent           = Header,
})

local TituloLabel = Criar("TextLabel", {
    Text             = "⚡ FELIX HUB",
    Font             = Enum.Font.GothamBold,
    TextColor3       = Color3.fromRGB(212, 175, 55),
    TextSize         = 20,
    BackgroundTransparency = 1,
    Size             = UDim2.new(0.7, 0, 1, 0),
    Position         = UDim2.new(0, 16, 0, 0),
    TextXAlignment   = Enum.TextXAlignment.Left,
    Parent           = Header,
})

local SubTitulo = Criar("TextLabel", {
    Text             = "DOORS EDITION",
    Font             = Enum.Font.Gotham,
    TextColor3       = Color3.fromRGB(150, 130, 60),
    TextSize         = 11,
    BackgroundTransparency = 1,
    Size             = UDim2.new(0.7, 0, 0, 14),
    Position         = UDim2.new(0, 18, 0, 30),
    TextXAlignment   = Enum.TextXAlignment.Left,
    Parent           = Header,
})

-- Botão Minimizar
local BotaoMinimizar = Criar("TextButton", {
    Text             = "─",
    Font             = Enum.Font.GothamBold,
    TextColor3       = Color3.fromRGB(212, 175, 55),
    TextSize         = 18,
    BackgroundColor3 = Color3.fromRGB(20, 20, 28),
    Size             = UDim2.new(0, 32, 0, 26),
    Position         = UDim2.new(1, -70, 0.5, -13),
    Parent           = Header,
})
Criar("UICorner", { CornerRadius = UDim.new(0, 6), Parent = BotaoMinimizar })

-- Botão Fechar
local BotaoFechar = Criar("TextButton", {
    Text             = "✕",
    Font             = Enum.Font.GothamBold,
    TextColor3       = Color3.fromRGB(255, 80, 80),
    TextSize         = 16,
    BackgroundColor3 = Color3.fromRGB(20, 20, 28),
    Size             = UDim2.new(0, 32, 0, 26),
    Position         = UDim2.new(1, -34, 0.5, -13),
    Parent           = Header,
})
Criar("UICorner", { CornerRadius = UDim.new(0, 6), Parent = BotaoFechar })

-- ─── SIDEBAR ───
local Sidebar = Criar("Frame", {
    Name             = "Sidebar",
    Size             = UDim2.new(0, 110, 1, -50),
    Position         = UDim2.new(0, 0, 0, 50),
    BackgroundColor3 = Color3.fromRGB(8, 8, 12),
    BorderSizePixel  = 0,
    Parent           = Janela,
})

-- Linha separadora sidebar
Criar("Frame", {
    Size             = UDim2.new(0, 1, 1, 0),
    Position         = UDim2.new(1, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(212, 175, 55),
    BackgroundTransparency = 0.7,
    BorderSizePixel  = 0,
    Parent           = Sidebar,
})

local SidebarLayout = Criar("UIListLayout", {
    Padding          = UDim.new(0, 4),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    Parent           = Sidebar,
})
Criar("UIPadding", { PaddingTop = UDim.new(0, 10), Parent = Sidebar })

-- ─── ÁREA DE CONTEÚDO ───
local Conteudo = Criar("Frame", {
    Name             = "Conteudo",
    Size             = UDim2.new(1, -110, 1, -50),
    Position         = UDim2.new(0, 110, 0, 50),
    BackgroundTransparency = 1,
    Parent           = Janela,
})

-- ════════════════════════════
-- SISTEMA DE ABAS
-- ════════════════════════════
local Abas = {}
local BotoesAbas = {}
local AbaAtiva = nil

local InfoAbas = {
    { nome = "ESP",    icon = "👁" },
    { nome = "Visual", icon = "🎨" },
    { nome = "Player", icon = "🏃" },
    { nome = "Misc",   icon = "⚙️" },
    { nome = "Doors",  icon = "🚪" },
}

-- Criar botões da sidebar e painéis
for _, info in ipairs(InfoAbas) do
    -- Botão
    local btn = Criar("TextButton", {
        Text             = info.icon .. "\n" .. info.nome,
        Font             = Enum.Font.GothamBold,
        TextColor3       = Color3.fromRGB(120, 110, 80),
        TextSize         = 12,
        BackgroundColor3 = Color3.fromRGB(14, 14, 20),
        Size             = UDim2.new(0.88, 0, 0, 52),
        AutoButtonColor  = false,
        Parent           = Sidebar,
    })
    Criar("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })

    -- Painel de conteúdo
    local painel = Criar("ScrollingFrame", {
        Name                    = "Painel_" .. info.nome,
        Size                    = UDim2.new(1, -10, 1, -10),
        Position                = UDim2.new(0, 5, 0, 5),
        BackgroundTransparency  = 1,
        BorderSizePixel         = 0,
        ScrollBarThickness      = 4,
        ScrollBarImageColor3    = Color3.fromRGB(212, 175, 55),
        CanvasSize              = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize     = Enum.AutomaticSize.Y,
        Visible                 = false,
        Parent                  = Conteudo,
    })

    local painelLayout = Criar("UIListLayout", {
        Padding          = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Parent           = painel,
    })
    Criar("UIPadding", {
        PaddingTop   = UDim.new(0, 8),
        PaddingLeft  = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        Parent       = painel,
    })

    Abas[info.nome] = { painel = painel, botao = btn }
    BotoesAbas[info.nome] = btn
end

-- Função para trocar aba
local function AbrirAba(nome)
    for n, aba in pairs(Abas) do
        aba.painel.Visible = false
        Tween(aba.botao, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(14, 14, 20),
            TextColor3       = Color3.fromRGB(120, 110, 80),
        })
    end
    local aba = Abas[nome]
    if aba then
        aba.painel.Visible = true
        Tween(aba.botao, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(30, 25, 8),
            TextColor3       = Color3.fromRGB(212, 175, 55),
        })
        AbaAtiva = nome
    end
end

-- Conectar botões das abas
for nome, aba in pairs(Abas) do
    aba.botao.MouseButton1Click:Connect(function()
        AbrirAba(nome)
    end)
end

-- ════════════════════════════
-- COMPONENTES DE UI
-- ════════════════════════════

-- Toggle moderno
local function CriarToggle(pai, texto, estadoInicial, callback)
    local frame = Criar("Frame", {
        Size             = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Color3.fromRGB(16, 16, 22),
        BorderSizePixel  = 0,
        Parent           = pai,
    })
    Criar("UICorner", { CornerRadius = UDim.new(0, 8), Parent = frame })
    Criar("UIStroke", {
        Color = Color3.fromRGB(40, 38, 28),
        Thickness = 1,
        Parent = frame,
    })

    local label = Criar("TextLabel", {
        Text             = texto,
        Font             = Enum.Font.Gotham,
        TextColor3       = Color3.fromRGB(200, 190, 150),
        TextSize         = 13,
        BackgroundTransparency = 1,
        Size             = UDim2.new(1, -54, 1, 0),
        Position         = UDim2.new(0, 10, 0, 0),
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = frame,
    })

    -- Trilho do toggle
    local trilho = Criar("Frame", {
        Size             = UDim2.new(0, 40, 0, 20),
        Position         = UDim2.new(1, -48, 0.5, -10),
        BackgroundColor3 = estadoInicial and Color3.fromRGB(180, 140, 20) or Color3.fromRGB(35, 35, 40),
        BorderSizePixel  = 0,
        Parent           = frame,
    })
    Criar("UICorner", { CornerRadius = UDim.new(1, 0), Parent = trilho })

    local bolinha = Criar("Frame", {
        Size             = UDim2.new(0, 14, 0, 14),
        Position         = estadoInicial and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0,
        Parent           = trilho,
    })
    Criar("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bolinha })

    local estado = estadoInicial
    local botao = Criar("TextButton", {
        Text                   = "",
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 1, 0),
        Parent                 = frame,
    })

    botao.MouseButton1Click:Connect(function()
        estado = not estado
        local corTrilho = estado and Color3.fromRGB(180, 140, 20) or Color3.fromRGB(35, 35, 40)
        local posBolinha = estado and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        Tween(trilho, TweenInfo.new(0.18), { BackgroundColor3 = corTrilho })
        Tween(bolinha, TweenInfo.new(0.18), { Position = posBolinha })
        pcall(callback, estado)
    end)

    return frame
end

-- Slider moderno
local function CriarSlider(pai, texto, min, max, valorInicial, callback)
    local frame = Criar("Frame", {
        Size             = UDim2.new(1, 0, 0, 54),
        BackgroundColor3 = Color3.fromRGB(16, 16, 22),
        BorderSizePixel  = 0,
        Parent           = pai,
    })
    Criar("UICorner", { CornerRadius = UDim.new(0, 8), Parent = frame })
    Criar("UIStroke", { Color = Color3.fromRGB(40, 38, 28), Thickness = 1, Parent = frame })

    local label = Criar("TextLabel", {
        Text             = texto .. ": " .. valorInicial,
        Font             = Enum.Font.Gotham,
        TextColor3       = Color3.fromRGB(200, 190, 150),
        TextSize         = 13,
        BackgroundTransparency = 1,
        Size             = UDim2.new(1, -10, 0, 22),
        Position         = UDim2.new(0, 10, 0, 4),
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = frame,
    })

    local trilho = Criar("Frame", {
        Size             = UDim2.new(1, -20, 0, 6),
        Position         = UDim2.new(0, 10, 0, 32),
        BackgroundColor3 = Color3.fromRGB(35, 35, 40),
        BorderSizePixel  = 0,
        Parent           = frame,
    })
    Criar("UICorner", { CornerRadius = UDim.new(1, 0), Parent = trilho })

    local percentInicial = (valorInicial - min) / (max - min)
    local preenchido = Criar("Frame", {
        Size             = UDim2.new(percentInicial, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(212, 175, 55),
        BorderSizePixel  = 0,
        Parent           = trilho,
    })
    Criar("UICorner", { CornerRadius = UDim.new(1, 0), Parent = preenchido })

    local cursor = Criar("Frame", {
        Size             = UDim2.new(0, 14, 0, 14),
        Position         = UDim2.new(percentInicial, -7, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0,
        Parent           = trilho,
    })
    Criar("UICorner", { CornerRadius = UDim.new(1, 0), Parent = cursor })

    local valor = valorInicial
    local arrastando = false

    local function AtualizarSlider(x)
        local abs = trilho.AbsolutePosition.X
        local lar = trilho.AbsoluteSize.X
        local pct = math.clamp((x - abs) / lar, 0, 1)
        valor = math.floor(min + (max - min) * pct)
        preenchido.Size = UDim2.new(pct, 0, 1, 0)
        cursor.Position = UDim2.new(pct, -7, 0.5, -7)
        label.Text = texto .. ": " .. valor
        pcall(callback, valor)
    end

    trilho.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            arrastando = true
            AtualizarSlider(inp.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if not arrastando then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            AtualizarSlider(inp.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            arrastando = false
        end
    end)

    return frame
end

-- Separador com título de seção
local function CriarSecao(pai, nome)
    local frame = Criar("Frame", {
        Size             = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Parent           = pai,
    })
    local linha = Criar("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(212, 175, 55),
        BackgroundTransparency = 0.6,
        BorderSizePixel  = 0,
        Parent           = frame,
    })
    local label = Criar("TextLabel", {
        Text             = "  " .. nome .. "  ",
        Font             = Enum.Font.GothamBold,
        TextColor3       = Color3.fromRGB(212, 175, 55),
        TextSize          = 11,
        BackgroundColor3 = Color3.fromRGB(10, 10, 15),
        Size             = UDim2.new(0, 0, 1, 0),
        Position         = UDim2.new(0.5, 0, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.X,
        TextXAlignment   = Enum.TextXAlignment.Center,
        Parent           = frame,
    })
    return frame
end

-- ════════════════════════════
-- PREENCHIMENTO DAS ABAS
-- ════════════════════════════

-- ── ABA ESP ──
local painelESP = Abas["ESP"].painel
CriarSecao(painelESP, "Detecção Visual")
CriarToggle(painelESP, "Ativar ESP", Config.ESP_Ativo, function(v)
    Config.ESP_Ativo = v
end)
CriarToggle(painelESP, "Highlight ESP", Config.Highlight_Ativo, function(v)
    Config.Highlight_Ativo = v
end)
CriarToggle(painelESP, "Billboard ESP", Config.Billboard_Ativo, function(v)
    Config.Billboard_Ativo = v
end)
CriarToggle(painelESP, "Mostrar Distância", Config.Distancia_Ativo, function(v)
    Config.Distancia_Ativo = v
end)
CriarSecao(painelESP, "Entidades")
CriarToggle(painelESP, "Aviso de Entidade", Config.EntityWarning_Ativo, function(v)
    Config.EntityWarning_Ativo = v
end)
CriarToggle(painelESP, "Buscar Figure", Estado.ProcurandoFigure, function(v)
    Estado.ProcurandoFigure = v
end)
CriarToggle(painelESP, "Buscar Livros", Estado.ProcurandoLivros, function(v)
    Estado.ProcurandoLivros = v
    if v then Estado.LivrosEncontrados = 0 end
end)

-- ── ABA VISUAL ──
local painelVisual = Abas["Visual"].painel
CriarSecao(painelVisual, "Iluminação")
CriarToggle(painelVisual, "Fullbright", Config.Fullbright_Ativo, function(v)
    ToggleFullbright(v)
end)
CriarToggle(painelVisual, "Blur de Fundo", Config.BlurFundo_Ativo, function(v)
    ToggleBlur(v)
end)
CriarSecao(painelVisual, "Performance")
CriarToggle(painelVisual, "Anti-Lag (Qualidade Baixa)", Config.AntiLag_Ativo, function(v)
    ToggleAntiLag(v)
end)
CriarSecao(painelVisual, "Câmera")
CriarToggle(painelVisual, "FOV Personalizado", Config.FOVChanger_Ativo, function(v)
    Config.FOVChanger_Ativo = v
    Camera.FieldOfView = v and Config.FOVValor or 70
end)
CriarSlider(painelVisual, "FOV", 60, 120, Config.FOVValor, function(v)
    Config.FOVValor = v
    if Config.FOVChanger_Ativo then Camera.FieldOfView = v end
end)

-- ── ABA PLAYER ──
local painelPlayer = Abas["Player"].painel
CriarSecao(painelPlayer, "Movimento")
CriarToggle(painelPlayer, "WalkSpeed Ativo", Config.WalkSpeed_Ativo, function(v)
    Config.WalkSpeed_Ativo = v
    AplicarWalkSpeed(v and Config.WalkSpeedValor or 16)
end)
CriarSlider(painelPlayer, "WalkSpeed", 8, 100, Config.WalkSpeedValor, function(v)
    Config.WalkSpeedValor = v
    if Config.WalkSpeed_Ativo then AplicarWalkSpeed(v) end
end)
CriarToggle(painelPlayer, "JumpPower Ativo", Config.JumpPower_Ativo, function(v)
    Config.JumpPower_Ativo = v
    AplicarJumpPower(v and Config.JumpPowerValor or 50)
end)
CriarSlider(painelPlayer, "JumpPower", 30, 200, Config.JumpPowerValor, function(v)
    Config.JumpPowerValor = v
    if Config.JumpPower_Ativo then AplicarJumpPower(v) end
end)
CriarSecao(painelPlayer, "Preset Rápido")
CriarToggle(painelPlayer, "FOV 120 (Imediato)", false, function(v)
    Camera.FieldOfView = v and 120 or 70
end)

-- ── ABA MISC ──
local painelMisc = Abas["Misc"].painel
CriarSecao(painelMisc, "Informações")
local InfoLabel = Criar("TextLabel", {
    Text = "Felix Hub v1.0\nDOORS Edition\nMobile & PC Otimizado\n\nExecutors: Delta, Hydrogen\nFluxus, Arceus X\n\nDesenvolvido com ♥",
    Font             = Enum.Font.Gotham,
    TextColor3       = Color3.fromRGB(180, 160, 100),
    TextSize         = 12,
    BackgroundColor3 = Color3.fromRGB(16, 16, 22),
    BackgroundTransparency = 0,
    Size             = UDim2.new(1, 0, 0, 120),
    TextWrapped      = true,
    TextYAlignment   = Enum.TextYAlignment.Top,
    Parent           = painelMisc,
})
Criar("UICorner", { CornerRadius = UDim.new(0, 8), Parent = InfoLabel })
Criar("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), Parent = InfoLabel })

CriarSecao(painelMisc, "Controle")
CriarToggle(painelMisc, "Notificações do Hub", true, function(v)
    Config.NotifPortas_Ativo = v
end)

-- ── ABA DOORS ──
local painelDoors = Abas["Doors"].painel
CriarSecao(painelDoors, "Entidades")
CriarToggle(painelDoors, "Remover Screech", Config.RemoverScreech_Ativo, function(v)
    Config.RemoverScreech_Ativo = v
end)
CriarToggle(painelDoors, "Notif. de Portas", Config.NotifPortas_Ativo, function(v)
    Config.NotifPortas_Ativo = v
end)
CriarSecao(painelDoors, "Automação")
CriarToggle(painelDoors, "Auto-Interação (Beta)", Config.AutoInteracao_Ativo, function(v)
    Config.AutoInteracao_Ativo = v
end)
CriarSecao(painelDoors, "Sala 50 Manual")
local BotaoSala50 = Criar("TextButton", {
    Text             = "⚡ Ativar Modo Sala 50",
    Font             = Enum.Font.GothamBold,
    TextColor3       = Color3.fromRGB(212, 175, 55),
    TextSize         = 13,
    BackgroundColor3 = Color3.fromRGB(30, 25, 8),
    Size             = UDim2.new(1, 0, 0, 38),
    BorderSizePixel  = 0,
    Parent           = painelDoors,
})
Criar("UICorner", { CornerRadius = UDim.new(0, 8), Parent = BotaoSala50 })
Criar("UIStroke", { Color = Color3.fromRGB(212, 175, 55), Thickness = 1, Parent = BotaoSala50 })

BotaoSala50.MouseButton1Click:Connect(function()
    Estado.ProcurandoFigure  = true
    Estado.ProcurandoLivros  = true
    Estado.LivrosEncontrados = 0
    Processados.Livros  = {}
    Processados.Figuras = {}
    Notificar("📚 Felix Hub", "Modo Sala 50 ativado! Procurando livros e Figure...", 5)
end)

-- ════════════════════════════
-- ARRASTAR JANELA (Mouse + Touch)
-- ════════════════════════════
local arrastando = false
local offsetArrastar = Vector2.new(0, 0)

Header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        arrastando = true
        local pos = Janela.AbsolutePosition
        offsetArrastar = Vector2.new(
            inp.Position.X - pos.X,
            inp.Position.Y - pos.Y
        )
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if not arrastando then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then
        local vp = Camera.ViewportSize
        local nx = math.clamp(inp.Position.X - offsetArrastar.X, 0, vp.X - Janela.AbsoluteSize.X)
        local ny = math.clamp(inp.Position.Y - offsetArrastar.Y, 0, vp.Y - Janela.AbsoluteSize.Y)
        Janela.Position = UDim2.new(0, nx, 0, ny)
    end
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        arrastando = false
    end
end)

-- ════════════════════════════
-- ARRASTAR BOTÃO FLUTUANTE
-- ════════════════════════════
local arrastandoBtn = false
local offsetBtn = Vector2.new(0, 0)

BotaoFlutuante.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        arrastandoBtn = true
        local pos = BotaoFlutuante.AbsolutePosition
        offsetBtn = Vector2.new(inp.Position.X - pos.X, inp.Position.Y - pos.Y)
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if not arrastandoBtn then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then
        local vp = Camera.ViewportSize
        local nx = math.clamp(inp.Position.X - offsetBtn.X, 0, vp.X - 56)
        local ny = math.clamp(inp.Position.Y - offsetBtn.Y, 0, vp.Y - 56)
        BotaoFlutuante.Position = UDim2.new(0, nx, 0, ny)
    end
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        arrastandoBtn = false
    end
end)

-- ════════════════════════════
-- ABRIR / FECHAR HUB
-- ════════════════════════════
local HubAberto = false
local JanelaMinimizada = false

local function AbrirHub()
    HubAberto = true
    Janela.Visible = true
    Janela.Size = UDim2.new(0, 10, 0, 10)
    Janela.BackgroundTransparency = 1
    Tween(Janela, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 560, 0, 400),
        BackgroundTransparency = 0,
    })
    if AbaAtiva == nil then AbrirAba("ESP") end
end

local function FecharHub()
    HubAberto = false
    Tween(Janela, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
    })
    task.delay(0.22, function() Janela.Visible = false end)
end

local function MinimizarHub()
    JanelaMinimizada = not JanelaMinimizada
    if JanelaMinimizada then
        Tween(Janela, TweenInfo.new(0.2), { Size = UDim2.new(0, 560, 0, 50) })
        Conteudo.Visible = false
        Sidebar.Visible  = false
    else
        Tween(Janela, TweenInfo.new(0.2), { Size = UDim2.new(0, 560, 0, 400) })
        Conteudo.Visible = true
        Sidebar.Visible  = true
    end
end

-- Botão flutuante: abrir/fechar
local cliqueBtnTimer = 0
BotaoFlutuante.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        local agora = tick()
        if agora - cliqueBtnTimer < 0.3 and not arrastandoBtn then
            if HubAberto then FecharHub() else AbrirHub() end
        end
        cliqueBtnTimer = agora
    end
end)

-- Botão fechar
BotaoFechar.MouseButton1Click:Connect(FecharHub)
-- Botão minimizar
BotaoMinimizar.MouseButton1Click:Connect(MinimizarHub)

-- Tecla atalho: RightControl ou F9
UserInputService.InputBegan:Connect(function(inp, proc)
    if proc then return end
    if inp.KeyCode == Enum.KeyCode.RightControl
    or inp.KeyCode == Enum.KeyCode.F9 then
        if HubAberto then FecharHub() else AbrirHub() end
    end
end)

-- ════════════════════════════
-- HOVER EFEITO NO BOTÃO FLUTUANTE
-- ════════════════════════════
BotaoFlutuante.MouseEnter:Connect(function()
    Tween(BotaoFlutuante, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(25, 22, 8)
    })
    Tween(BotaoGlow, TweenInfo.new(0.15), { ImageTransparency = 0.3 })
end)
BotaoFlutuante.MouseLeave:Connect(function()
    Tween(BotaoFlutuante, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    })
    Tween(BotaoGlow, TweenInfo.new(0.15), { ImageTransparency = 0.6 })
end)

-- ════════════════════════════════════════════
--  INICIALIZAÇÃO FINAL
-- ════════════════════════════════════════════

-- Abrir aba ESP por padrão
AbrirAba("ESP")

-- Iniciar sistema ESP
task.spawn(IniciarESP)

-- Notificação de carregamento
task.delay(0.5, function()
    Notificar("⚡ Felix Hub", "Carregado com sucesso! Aperte RCtrl ou F9 para abrir.", 6)
end)

-- Animação de pulse no botão flutuante
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        Tween(BotaoFlutuante, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundColor3 = Color3.fromRGB(22, 18, 5)
        })
        task.wait(1.2)
        Tween(BotaoFlutuante, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        })
        task.wait(1.2)
    end
end)

print([[
╔══════════════════════════════════════════╗
║         FELIX HUB v1.0 CARREGADO         ║
║   RCtrl / F9 = Abrir | Botão Flutuante   ║
╚══════════════════════════════════════════╝
]])
