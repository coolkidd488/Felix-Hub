--[[
╔══════════════════════════════════════════════════════════╗
║               FELIX HUB v2.7 - DOORS EDITION             ║
╚══════════════════════════════════════════════════════════╝
  FIXES v2.6:
  • Entidades: mapeamento correto de Screech/Lockman/Eyes sem duplicar
  • Hub: posição sempre na esquerda, abre sem deslocar
  • Gavetas: firetouchinterest como fallback (compatível com Delta)
  • Livros: game:GetDescendants() completo no scan global
]]

local ok, err = pcall(function()

if _G.FelixHubCarregado then warn("[FelixHub] Já carregado.") return end
_G.FelixHubCarregado = true
print("[FelixHub] Iniciando v2.7...")

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local function GetGuiParent()
    local ok2 = pcall(function()
        local t = Instance.new("ScreenGui"); t.Parent = CoreGui; t:Destroy()
    end)
    if ok2 then return CoreGui end
    return LP:WaitForChild("PlayerGui")
end
local GuiParent = GetGuiParent()
print("[FelixHub] Parent:", GuiParent.Name)

-- ══════════════════
--  CONFIG
-- ══════════════════
local Cfg = {
    ESP_Ativo=true, HL_Ativo=true, BB_Ativo=true,
    Dist_Ativo=true, Aviso_Ativo=true,
    ESP_Portas=true,  ESP_Chaves=true,   ESP_Alavancas=true,
    ESP_Livros=true,  ESP_Figure=true,   ESP_Screech=true,
    ESP_Itens=true,   ESP_Baus=true,     ESP_Fusiveis=true,
    RemoverScreech=true, NotifPortas=true,
    ProtecaoEyes=false,  AutoGaveta=false,
    WalkSpeedValor=16, JumpPowerValor=50,
    cPorta   =Color3.fromRGB(255,215,  0),
    cChave   =Color3.fromRGB( 30,144,255),
    cAlavanca=Color3.fromRGB(255,140,  0),
    cLivro   =Color3.fromRGB(160, 32,240),
    cFigure  =Color3.fromRGB(220, 20, 60),
    cScreech =Color3.fromRGB(200,  0,  0),
    cItem    =Color3.fromRGB( 50,220,100),
    cBau     =Color3.fromRGB(200,170, 20),
    cFusivel =Color3.fromRGB(255,100,  0),
    cPerigo  =Color3.fromRGB(255, 30, 30),
    MaxDist=500, DistInt=0.25,
}

local Estado = {ProcurandoFigure=false, ProcurandoLivros=false, LivrosN=0}
local Cache   = {}
local BBCache = {}

-- ══════════════════
--  UTILS
-- ══════════════════
local function Criar(cls, p)
    local ok2,o = pcall(Instance.new,cls)
    if not ok2 then return nil end
    for k,v in pairs(p) do pcall(function() o[k]=v end) end
    return o
end
local function TW(o,i,p) if o then pcall(function() TweenService:Create(o,i,p):Play() end) end end
local function Notif(t,m,d)
    pcall(function() StarterGui:SetCore("SendNotification",{Title=t,Text=m,Duration=d or 4}) end)
end
local function GetPart(obj)
    if not obj or not obj.Parent then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart end
        for _,v in ipairs(obj:GetDescendants()) do
            if v:IsA("BasePart") then return v end
        end
    end
    return nil
end
local function ItemSolto(obj)
    local p = obj.Parent; if not p then return false end
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
    local g = GuiParent:FindFirstChild(uid)
    if g then pcall(function() g:Destroy() end) end
end

local function CriarBB(obj, txt, cor)
    if not Cfg.BB_Ativo then return end
    local parte = GetPart(obj); if not parte then return end
    local uid = "BB_"..obj:GetFullName():gsub("[^%w]","_")
    LimparBB(uid)
    local bbg = Criar("BillboardGui",{
        Name=uid, Adornee=parte, AlwaysOnTop=true, LightInfluence=0,
        MaxDistance=Cfg.MaxDist, Size=UDim2.new(0,100,0,22),
        StudsOffset=Vector3.new(0,3,0), Parent=GuiParent,
    })
    if not bbg then return end
    local fr = Criar("Frame",{BackgroundColor3=Color3.fromRGB(8,8,12),
        BackgroundTransparency=0.2,Size=UDim2.new(1,0,1,0),Parent=bbg})
    Criar("UICorner",{CornerRadius=UDim.new(0,4),Parent=fr})
    Criar("UIStroke",{Color=cor,Thickness=1,Parent=fr})
    local lbl = Criar("TextLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),
        Font=Enum.Font.GothamBold,TextScaled=false,TextSize=11,
        TextColor3=cor,TextStrokeColor3=Color3.new(0,0,0),TextStrokeTransparency=0.3,
        TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,
        Text=txt,Parent=fr})
    local ult=0
    local conn = RunService.Heartbeat:Connect(function()
        if not bbg or not bbg.Parent then return end
        local ag=tick(); if ag-ult < Cfg.DistInt then return end; ult=ag
        pcall(function()
            if Cfg.Dist_Ativo then
                local d=math.floor((Camera.CFrame.Position-parte.Position).Magnitude)
                lbl.Text = txt.." "..d.."m"
            else lbl.Text = txt end
        end)
    end)
    BBCache[uid] = {gui=bbg,conn=conn}
    obj.AncestryChanged:Connect(function()
        if not obj:IsDescendantOf(game) then
            LimparBB(uid); Cache[obj:GetFullName()]=nil
        end
    end)
end

-- ══════════════════
--  ESP
-- ══════════════════
local function ESP(obj,cor,txt)
    if not obj or not obj.Parent then return end
    local uid = obj:GetFullName()
    if Cache[uid] then return end
    Cache[uid] = true
    if Cfg.HL_Ativo then
        pcall(function()
            local ha=obj:FindFirstChild("FHL"); if ha then ha:Destroy() end
            local hl=Criar("Highlight",{Name="FHL",Adornee=obj,FillColor=cor,
                FillTransparency=0.55,OutlineColor=Color3.fromRGB(255,255,255),
                OutlineTransparency=0.1,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
                Enabled=true,Parent=obj})
            TW(hl,TweenInfo.new(1.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{FillTransparency=0.78})
            obj.AncestryChanged:Connect(function()
                if not obj:IsDescendantOf(game) then
                    pcall(function() hl:Destroy() end); Cache[uid]=nil
                end
            end)
        end)
    end
    if Cfg.BB_Ativo then pcall(CriarBB,obj,txt,cor) end
end

-- ══════════════════════════════════════════════
--  ENTIDADES — mapeamento COMPLETO e CORRETO
--  Cada nome do modelo -> {label, notif, cor}
--  Screech tem nome diferente de ScreechRig
-- ══════════════════════════════════════════════
local EntMap = {
    -- Rush
    ["Rush"]         = {l="🔴 RUSH!",   n="RUSH vindo! ESCONDA-SE!",   c=Color3.fromRGB(255,40,40)},
    ["RushMoving"]   = {l="🔴 RUSH!",   n="RUSH vindo! ESCONDA-SE!",   c=Color3.fromRGB(255,40,40)},
    -- Ambush
    ["Ambush"]       = {l="🟠 AMBUSH!", n="AMBUSH! Fique escondido!",  c=Color3.fromRGB(255,120,0)},
    ["AmbushMoving"] = {l="🟠 AMBUSH!", n="AMBUSH! Fique escondido!",  c=Color3.fromRGB(255,120,0)},
    -- Halt
    ["Halt"]         = {l="⚠️ HALT!",   n="Halt apareceu!",            c=Color3.fromRGB(255,200,0)},
    ["HaltMoving"]   = {l="⚠️ HALT!",   n="Halt apareceu!",            c=Color3.fromRGB(255,200,0)},
    -- Seek
    ["SeekRig"]      = {l="🔴 SEEK!",   n="Seek apareceu!",            c=Color3.fromRGB(200,0,200)},
    -- Eyes — modelo chama "Eyes" mas NÃO é Screech nem Lockman
    ["Eyes"]         = {l="👁 EYES!",   n="Eyes! Não olhe para ele!",  c=Color3.fromRGB(255,80,80)},
    -- Screech — o modelo real chama "ScreechRig" mas o aviso vem de outra parte
    -- Lockman
    ["LockmanRig"]   = {l="🔒 LOCKMAN!",n="Lockman apareceu!",         c=Color3.fromRGB(100,200,255)},
    ["Lockman"]      = {l="🔒 LOCKMAN!",n="Lockman apareceu!",         c=Color3.fromRGB(100,200,255)},
    -- Timothy (aranha)
    ["Timothy"]      = {l="🕷️ TIMOTHY!",n="Timothy (aranha)!",         c=Color3.fromRGB(180,100,255)},
    -- El Goblino
    ["ElGoblino"]    = {l="👺 GOBLINO!",n="El Goblino apareceu!",      c=Color3.fromRGB(100,255,100)},
}

-- Cache separado para entidades (evita duplicar aviso)
local EntCache = {}

local function ProcessarEntidade(o)
    if not Cfg.Aviso_Ativo then return end
    local info = EntMap[o.Name]
    if not info then return end
    local uid = o:GetFullName()
    if EntCache[uid] then return end
    EntCache[uid] = true
    -- Highlight
    pcall(function()
        local ha=o:FindFirstChild("FHL"); if ha then ha:Destroy() end
        local hl=Criar("Highlight",{Name="FHL",Adornee=o,FillColor=info.c,
            FillTransparency=0.4,OutlineColor=Color3.fromRGB(255,50,50),
            OutlineTransparency=0,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
            Enabled=true,Parent=o})
        o.AncestryChanged:Connect(function()
            if not o:IsDescendantOf(game) then
                pcall(function() hl:Destroy() end); EntCache[uid]=nil
            end
        end)
    end)
    pcall(CriarBB, o, info.l, info.c)
    Notif("⚠️ "..o.Name, info.n, 5)
    print("[FelixHub] Entidade:", o.Name)
end

-- ══════════════════
--  PROCESSADORES
-- ══════════════════
local function PChave(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Chaves then return end
    ESP(o,Cfg.cChave,"CHAVE")
end
local function PAlavanca(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Alavancas then return end
    ESP(o:FindFirstChild("Main") or o,Cfg.cAlavanca,"ALAVANCA")
end

-- LIVROS: scan em GAME inteiro (não só workspace)
local function ScanLivros()
    if not Estado.ProcurandoLivros then return end
    print("[FelixHub] Scan de livros em game:GetDescendants()...")
    local count = 0
    for _,o in ipairs(game:GetDescendants()) do
        if o.Name == "LiveHintBook" then
            count += 1
            local uid = o:GetFullName()
            if not Cache[uid] then
                Cache[uid]=true
                Estado.LivrosN += 1
                ESP(o,Cfg.cLivro,"LIVRO "..Estado.LivrosN.."/8")
                print("[FelixHub] Livro "..Estado.LivrosN.." em:", uid)
                if Estado.LivrosN >= 8 then
                    Estado.ProcurandoLivros=false
                    Notif("📚 Felix Hub","Todos os 8 livros encontrados!",5)
                    break
                end
            end
        end
    end
    print("[FelixHub] Scan concluído. LiveHintBook encontrados:", count)
    if count == 0 then
        Notif("📚 Livros","Nenhum LiveHintBook encontrado ainda.",4)
    end
end

local function PLivro(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Livros then return end
    if not Estado.ProcurandoLivros then return end
    local uid=o:GetFullName(); if Cache[uid] then return end
    Cache[uid]=true; Estado.LivrosN+=1
    ESP(o,Cfg.cLivro,"LIVRO "..Estado.LivrosN.."/8")
    print("[FelixHub] Livro via DescendantAdded:", Estado.LivrosN)
    if Estado.LivrosN >= 8 then
        Estado.ProcurandoLivros=false; Notif("📚 Felix Hub","Todos os 8 livros!",5)
    end
end

local function PFigure(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Figure then return end
    if not Estado.ProcurandoFigure or o.Name~="FigureRig" then return end
    if Cache[o:GetFullName()] then return end
    Estado.ProcurandoFigure=false; ESP(o,Cfg.cFigure,"FIGURE!")
    if Cfg.Aviso_Ativo then Notif("⚠️ PERIGO!","Figure apareceu!",6) end
end

local function PScreech(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Screech then return end
    if Cfg.RemoverScreech then
        pcall(function() o:Destroy() end)
        Notif("Felix Hub","Screech removido!",3); return
    end
    ESP(o,Cfg.cScreech,"SCREECH!")
    if Cfg.Aviso_Ativo then Notif("⚠️ SCREECH!","Olhe para ele!",4) end
end

local NItens={
    Flashlight="LANTERNA",Lighter="ISQUEIRO",Vitamins="VITAMINA",
    Lockpick="LOCKPICK",Bandage="BANDAGEM",Crucifix="CRUCIFIXO",
    GreenSoup="SOPA VERDE",GreenHerb="ERVA VM",Candle="VELA",
    RedVial="POÇÃO VM",Battery="PILHA",Coins="MOEDAS",
}
local function PItem(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Itens then return end
    if not NItens[o.Name] or not ItemSolto(o) then return end
    ESP(o,Cfg.cItem,NItens[o.Name])
end

local NBaus={Chest="BAÚ",GoldChest="BAÚ DOURADO",CraftChest="BAÚ CRAFT",LockedChest="BAÚ TRANCADO"}
local function PBau(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Baus then return end
    if not NBaus[o.Name] then return end; ESP(o,Cfg.cBau,NBaus[o.Name])
end

local NFus={Fuse=true,FuseSocket=true,FuseSlot=true}
local function PFusivel(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Fusiveis then return end
    if not NFus[o.Name] then return end; ESP(o,Cfg.cFusivel,"FUSIVEL")
end

local function PPorta(o)
    if not Cfg.ESP_Ativo or not Cfg.ESP_Portas then return end
    local sala=o.Parent; local prof=0
    while sala and sala~=workspace and prof<12 do
        if tonumber(sala.Name) then break end; sala=sala.Parent; prof+=1
    end
    local ni=sala and tonumber(sala.Name); if not ni then return end
    local nv=ni+1; local uid="Porta_"..ni
    if Cache[uid] then return end; Cache[uid]=true
    local alvo=o
    pcall(function()
        local df=sala:FindFirstChild("Door")
        if df then local dp=df:FindFirstChild("Door"); if dp then alvo=dp end end
    end)
    ESP(alvo,Cfg.cPorta,"PORTA "..nv)
    if Cfg.NotifPortas then Notif("🚪 Porta","Próxima: "..nv,3) end
    if ni==49 then
        Estado.ProcurandoFigure=true; Estado.ProcurandoLivros=true; Estado.LivrosN=0
        for k in pairs(Cache) do
            if k:find("LiveHintBook") or k:find("FigureRig") then Cache[k]=nil end
        end
        task.spawn(ScanLivros); Notif("📚 Sala 50!","Buscando livros e Figure...",5)
    end
end

-- ══════════════════
--  ROTEADOR
-- ══════════════════
local function Rotear(o)
    if not o or not o.Parent then return end
    local n = o.Name
    -- Entidades primeiro (cache separado, não duplica)
    if EntMap[n]         then ProcessarEntidade(o) end
    -- Figure e Screech têm tratamento próprio
    if n=="FigureRig"    then PFigure(o)   return end
    if n=="ScreechRig"   then PScreech(o)  return end
    -- Sala
    if n=="KeyObtain"    then PChave(o)    return end
    if n=="LeverForGate" then PAlavanca(o) return end
    if n=="LiveHintBook" then PLivro(o)    return end
    if n=="ClientOpen"   then PPorta(o)    return end
    -- Itens
    if NItens[n]         then PItem(o)     return end
    if NBaus[n]          then PBau(o)      return end
    if NFus[n]           then PFusivel(o)  return end
end

local function IniciarESP()
    print("[FelixHub] ESP iniciado")
    task.spawn(function()
        for _,o in ipairs(game:GetDescendants()) do task.spawn(Rotear,o) end
    end)
    game.DescendantAdded:Connect(function(o) task.spawn(Rotear,o) end)
end

-- ══════════════════════════════════════════════
--  AUTO-GAVETA
--  Delta não tem fireproximityprompt confiável.
--  Usamos firetouchinterest como fallback.
-- ══════════════════════════════════════════════
local GavetaConn = nil
local GavetaNomes = {
    Drawer=true, Dresser=true, Cabinet=true,
    Nightstand=true, Desk=true, Wardrobe=true,
}
local ColetaNomes = {Coins=true, Battery=true, Gold=true, Money=true}

local function TentarColetar(o)
    pcall(function()
        -- Tenta ProximityPrompt primeiro
        local pp = o:FindFirstChildOfClass("ProximityPrompt")
            or o:FindFirstDescendantOfClass and o:FindFirstDescendantOfClass("ProximityPrompt")
        if pp then
            pcall(function() fireproximityprompt(pp) end)
            return
        end
        -- Fallback: firetouchinterest
        local char = LP.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local parte = GetPart(o)
            if hrp and parte then
                pcall(function() firetouchinterest(hrp, parte, 0) end)
                task.wait(0.05)
                pcall(function() firetouchinterest(hrp, parte, 1) end)
            end
        end
    end)
end

local function AbrirGaveta(o)
    pcall(function()
        -- Tenta abrir a gaveta
        local pp = o:FindFirstChildOfClass("ProximityPrompt")
        if pp then
            pcall(function() fireproximityprompt(pp) end)
        else
            local char = LP.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local parte = GetPart(o)
                if hrp and parte then
                    pcall(function() firetouchinterest(hrp, parte, 0) end)
                    task.wait(0.05)
                    pcall(function() firetouchinterest(hrp, parte, 1) end)
                end
            end
        end
        task.wait(0.3)
        -- Coleta moedas/pilhas dentro
        for _,f in ipairs(o:GetDescendants()) do
            if ColetaNomes[f.Name] then
                task.spawn(TentarColetar, f)
            end
        end
    end)
end

local function IniciarAutoGaveta()
    if GavetaConn then GavetaConn:Disconnect(); GavetaConn=nil end
    if not Cfg.AutoGaveta then return end
    print("[FelixHub] Auto-gaveta ativado")
    -- Scan inicial em paralelo
    task.spawn(function()
        for _,o in ipairs(game:GetDescendants()) do
            if GavetaNomes[o.Name] then
                task.spawn(AbrirGaveta, o)
            end
        end
    end)
    -- Monitora novas
    GavetaConn = game.DescendantAdded:Connect(function(o)
        if GavetaNomes[o.Name] then
            task.wait(0.5); task.spawn(AbrirGaveta, o)
        end
        if ColetaNomes[o.Name] and ItemSolto(o) then
            task.wait(0.2); task.spawn(TentarColetar, o)
        end
    end)
end

-- ══════════════════
--  PROTEÇÃO EYES
-- ══════════════════
local TDOrig=nil; local EyesConn=nil
local function ProtEyes(v)
    Cfg.ProtecaoEyes=v
    local function Ap(char)
        if not char then return end
        local h=char:FindFirstChildOfClass("Humanoid"); if not h then return end
        if v then
            TDOrig=h.TakeDamage; h.TakeDamage=function()end
            Notif("🛡️","Proteção de dano ativada!",3)
        else
            if TDOrig then h.TakeDamage=TDOrig; TDOrig=nil end
        end
    end
    Ap(LP.Character)
    if EyesConn then EyesConn:Disconnect() end
    if v then EyesConn=LP.CharacterAdded:Connect(function(c) task.wait(0.5);Ap(c) end) end
end

local function AppSpeed(v) pcall(function()
    local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed=v end
end) end
local function AppJump(v) pcall(function()
    local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then h.JumpPower=v; h.UseJumpPower=true end
end) end
local function TFullbright(v)
    Lighting.Ambient=v and Color3.fromRGB(255,255,255) or Color3.fromRGB(70,70,70)
    Lighting.OutdoorAmbient=v and Color3.fromRGB(255,255,255) or Color3.fromRGB(70,70,70)
    Lighting.Brightness=v and 10 or 1; Lighting.FogEnd=100000
end
local function TAntiLag(v) pcall(function()
    settings().Rendering.QualityLevel=v and 1 or Enum.QualityLevel.Automatic
end) end

LP.CharacterAdded:Connect(function()
    task.wait(0.4)
    AppSpeed(Cfg.WalkSpeedValor); AppJump(Cfg.JumpPowerValor)
    if Cfg.ProtecaoEyes then task.wait(0.3); ProtEyes(true) end
    if Cfg.AutoGaveta then IniciarAutoGaveta() end
end)

-- ══════════════════════════════════════════
--  GUI
-- ══════════════════════════════════════════
local gAnt=GuiParent:FindFirstChild("FelixHub_GUI"); if gAnt then gAnt:Destroy() end
local SG=Criar("ScreenGui",{Name="FelixHub_GUI",ResetOnSpawn=false,
    IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Parent=GuiParent})

-- Tamanhos fixos
local WIN_W, WIN_H = 460, 350
-- Posição de abertura fixa na esquerda
local WIN_X, WIN_Y = 10, 60

-- ── BOTÃO F ──
-- ClipsDescendants=true corta tudo fora do círculo (sem quadrado)
local BH=Criar("Frame",{
    Size=UDim2.new(0,44,0,44),
    Position=UDim2.new(0,12,0.28,0),
    BackgroundColor3=Color3.fromRGB(12,12,18),
    BorderSizePixel=0,
    ClipsDescendants=true,   -- ← corta glow fora do círculo
    Parent=SG,
})
Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=BH})
Criar("UIStroke",{Color=Color3.fromRGB(212,175,55),Thickness=1.8,
    ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Parent=BH})
Criar("ImageLabel",{Image="rbxassetid://5028857472",
    ImageColor3=Color3.fromRGB(212,175,55),ImageTransparency=0.6,
    BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),
    Position=UDim2.new(0,0,0,0),ZIndex=1,Parent=BH})
local BtnF=Criar("TextButton",{Text="F",Font=Enum.Font.GothamBold,
    TextColor3=Color3.fromRGB(212,175,55),TextSize=20,
    BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,
    Size=UDim2.new(1,0,1,0),ZIndex=2,Parent=BH})

-- ── JANELA ──
local Win=Criar("Frame",{Name="Win",
    Size=UDim2.new(0,WIN_W,0,WIN_H),
    Position=UDim2.new(0,WIN_X,0,WIN_Y),   -- FIXO, esquerda
    BackgroundColor3=Color3.fromRGB(10,10,15),
    BorderSizePixel=0,ClipsDescendants=true,Visible=false,Parent=SG})
Criar("UICorner",{CornerRadius=UDim.new(0,13),Parent=Win})
Criar("UIStroke",{Color=Color3.fromRGB(212,175,55),Thickness=1.4,Parent=Win})
Criar("UIGradient",{Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(13,13,19)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(7,7,11))}),
    Rotation=120,Parent=Win})

-- Header
local Hdr=Criar("Frame",{Size=UDim2.new(1,0,0,44),
    BackgroundColor3=Color3.fromRGB(8,8,13),BorderSizePixel=0,Parent=Win})
Criar("UICorner",{CornerRadius=UDim.new(0,13),Parent=Hdr})
Criar("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),
    BackgroundColor3=Color3.fromRGB(212,175,55),BorderSizePixel=0,Parent=Hdr})
Criar("TextLabel",{Text="⚡  FELIX HUB",Font=Enum.Font.GothamBold,
    TextColor3=Color3.fromRGB(212,175,55),TextSize=17,BackgroundTransparency=1,
    Size=UDim2.new(0.6,0,0.58,0),Position=UDim2.new(0,13,0.04,0),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=Hdr})
Criar("TextLabel",{Text="DOORS EDITION  v2.7",Font=Enum.Font.Gotham,
    TextColor3=Color3.fromRGB(140,120,55),TextSize=10,BackgroundTransparency=1,
    Size=UDim2.new(0.6,0,0.36,0),Position=UDim2.new(0,15,0.60,0),
    TextXAlignment=Enum.TextXAlignment.Left,Parent=Hdr})
local BMin=Criar("TextButton",{Text="─",Font=Enum.Font.GothamBold,
    TextColor3=Color3.fromRGB(212,175,55),TextSize=13,
    BackgroundColor3=Color3.fromRGB(20,20,30),BorderSizePixel=0,
    Size=UDim2.new(0,26,0,20),Position=UDim2.new(1,-58,0.5,-10),Parent=Hdr})
Criar("UICorner",{CornerRadius=UDim.new(0,5),Parent=BMin})
local BX=Criar("TextButton",{Text="✕",Font=Enum.Font.GothamBold,
    TextColor3=Color3.fromRGB(255,75,75),TextSize=12,
    BackgroundColor3=Color3.fromRGB(20,20,30),BorderSizePixel=0,
    Size=UDim2.new(0,26,0,20),Position=UDim2.new(1,-28,0.5,-10),Parent=Hdr})
Criar("UICorner",{CornerRadius=UDim.new(0,5),Parent=BX})

-- Sidebar
local SB=Criar("Frame",{Size=UDim2.new(0,90,1,-44),Position=UDim2.new(0,0,0,44),
    BackgroundColor3=Color3.fromRGB(8,8,13),BorderSizePixel=0,Parent=Win})
Criar("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(1,0,0,0),
    BackgroundColor3=Color3.fromRGB(212,175,55),BackgroundTransparency=0.75,
    BorderSizePixel=0,Parent=SB})
Criar("UIListLayout",{Padding=UDim.new(0,3),
    HorizontalAlignment=Enum.HorizontalAlignment.Center,Parent=SB})
Criar("UIPadding",{PaddingTop=UDim.new(0,7),Parent=SB})
local Cont=Criar("Frame",{Size=UDim2.new(1,-90,1,-44),Position=UDim2.new(0,90,0,44),
    BackgroundTransparency=1,Parent=Win})

-- Abas
local Abas={}; local AbaAtiva=nil
local IAbas={
    {n="ESP",i="👁"},{n="Itens",i="🎒"},{n="Local",i="⚡"},
    {n="Visual",i="🎨"},{n="Doors",i="🚪"},{n="Info",i="ℹ️"},
}
for _,a in ipairs(IAbas) do
    local bt=Criar("TextButton",{Text=a.i.."\n"..a.n,Font=Enum.Font.GothamBold,
        TextColor3=Color3.fromRGB(110,100,70),TextSize=9,
        BackgroundColor3=Color3.fromRGB(14,14,21),
        Size=UDim2.new(0.86,0,0,42),AutoButtonColor=false,BorderSizePixel=0,Parent=SB})
    Criar("UICorner",{CornerRadius=UDim.new(0,7),Parent=bt})
    local pn=Criar("ScrollingFrame",{Name="P_"..a.n,
        Size=UDim2.new(1,-10,1,-6),Position=UDim2.new(0,5,0,3),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
        ScrollBarImageColor3=Color3.fromRGB(212,175,55),
        CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        Visible=false,Parent=Cont})
    Criar("UIListLayout",{Padding=UDim.new(0,5),
        HorizontalAlignment=Enum.HorizontalAlignment.Center,Parent=pn})
    Criar("UIPadding",{PaddingTop=UDim.new(0,6),PaddingLeft=UDim.new(0,6),
        PaddingRight=UDim.new(0,6),Parent=pn})
    Abas[a.n]={p=pn,b=bt}
end

local function Aba(n)
    for _,a in pairs(Abas) do
        a.p.Visible=false
        TW(a.b,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(14,14,21),
            TextColor3=Color3.fromRGB(110,100,70)})
    end
    local a=Abas[n]; if a then
        a.p.Visible=true
        TW(a.b,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(28,24,7),
            TextColor3=Color3.fromRGB(212,175,55)})
        AbaAtiva=n
    end
end
for n,a in pairs(Abas) do a.b.MouseButton1Click:Connect(function() Aba(n) end) end

-- Componentes
local function Sec(p,t)
    local f=Criar("Frame",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Parent=p})
    Criar("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,0.5,0),
        BackgroundColor3=Color3.fromRGB(212,175,55),BackgroundTransparency=0.65,
        BorderSizePixel=0,Parent=f})
    Criar("TextLabel",{Text="  "..t.."  ",Font=Enum.Font.GothamBold,
        TextColor3=Color3.fromRGB(212,175,55),TextSize=9,
        BackgroundColor3=Color3.fromRGB(10,10,15),
        Size=UDim2.new(0,0,1,0),Position=UDim2.new(0.5,0,0,0),
        AutomaticSize=Enum.AutomaticSize.X,
        TextXAlignment=Enum.TextXAlignment.Center,Parent=f})
end

local function Tog(p,t,ini,cb)
    local f=Criar("Frame",{Size=UDim2.new(1,0,0,30),
        BackgroundColor3=Color3.fromRGB(15,15,22),BorderSizePixel=0,Parent=p})
    Criar("UICorner",{CornerRadius=UDim.new(0,7),Parent=f})
    Criar("UIStroke",{Color=Color3.fromRGB(38,36,26),Thickness=1,Parent=f})
    Criar("TextLabel",{Text=t,Font=Enum.Font.Gotham,
        TextColor3=Color3.fromRGB(195,185,145),TextSize=11,
        BackgroundTransparency=1,Size=UDim2.new(1,-46,1,0),Position=UDim2.new(0,8,0,0),
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=f})
    local tr=Criar("Frame",{Size=UDim2.new(0,32,0,16),Position=UDim2.new(1,-39,0.5,-8),
        BackgroundColor3=ini and Color3.fromRGB(170,130,15) or Color3.fromRGB(34,34,40),
        BorderSizePixel=0,Parent=f})
    Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=tr})
    local bl=Criar("Frame",{Size=UDim2.new(0,10,0,10),
        Position=ini and UDim2.new(0,19,0.5,-5) or UDim2.new(0,3,0.5,-5),
        BackgroundColor3=Color3.fromRGB(255,255,255),BorderSizePixel=0,Parent=tr})
    Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=bl})
    local st=ini
    local b=Criar("TextButton",{Text="",BackgroundTransparency=1,BorderSizePixel=0,
        Size=UDim2.new(1,0,1,0),Parent=f})
    b.MouseButton1Click:Connect(function()
        st=not st
        TW(tr,TweenInfo.new(0.14),{BackgroundColor3=st and Color3.fromRGB(170,130,15) or Color3.fromRGB(34,34,40)})
        TW(bl,TweenInfo.new(0.14),{Position=st and UDim2.new(0,19,0.5,-5) or UDim2.new(0,3,0.5,-5)})
        pcall(cb,st)
    end)
end

local function Sld(p,t,mn,mx,in0,cb)
    local f=Criar("Frame",{Size=UDim2.new(1,0,0,46),
        BackgroundColor3=Color3.fromRGB(15,15,22),BorderSizePixel=0,Parent=p})
    Criar("UICorner",{CornerRadius=UDim.new(0,7),Parent=f})
    Criar("UIStroke",{Color=Color3.fromRGB(38,36,26),Thickness=1,Parent=f})
    local lb=Criar("TextLabel",{Text=t..": "..in0,Font=Enum.Font.Gotham,
        TextColor3=Color3.fromRGB(195,185,145),TextSize=11,BackgroundTransparency=1,
        Size=UDim2.new(1,-6,0,17),Position=UDim2.new(0,8,0,3),
        TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
    local tr=Criar("Frame",{Size=UDim2.new(1,-16,0,5),Position=UDim2.new(0,8,0,26),
        BackgroundColor3=Color3.fromRGB(34,34,40),BorderSizePixel=0,Parent=f})
    Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=tr})
    local p0=(in0-mn)/(mx-mn)
    local fi=Criar("Frame",{Size=UDim2.new(p0,0,1,0),
        BackgroundColor3=Color3.fromRGB(212,175,55),BorderSizePixel=0,Parent=tr})
    Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=fi})
    local kn=Criar("Frame",{Size=UDim2.new(0,11,0,11),Position=UDim2.new(p0,-5,0.5,-5),
        BackgroundColor3=Color3.fromRGB(240,230,200),BorderSizePixel=0,Parent=tr})
    Criar("UICorner",{CornerRadius=UDim.new(1,0),Parent=kn})
    local dg=false
    local function U(x)
        local pp=math.clamp((x-tr.AbsolutePosition.X)/tr.AbsoluteSize.X,0,1)
        local vv=math.floor(mn+(mx-mn)*pp)
        fi.Size=UDim2.new(pp,0,1,0); kn.Position=UDim2.new(pp,-5,0.5,-5)
        lb.Text=t..": "..vv; pcall(cb,vv)
    end
    tr.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dg=true;U(i.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dg and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then U(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dg=false end
    end)
end

local function Inp(p,titulo,pad,btnT,cb)
    local f=Criar("Frame",{Size=UDim2.new(1,0,0,58),
        BackgroundColor3=Color3.fromRGB(15,15,22),BorderSizePixel=0,Parent=p})
    Criar("UICorner",{CornerRadius=UDim.new(0,7),Parent=f})
    Criar("UIStroke",{Color=Color3.fromRGB(38,36,26),Thickness=1,Parent=f})
    Criar("TextLabel",{Text=titulo,Font=Enum.Font.Gotham,
        TextColor3=Color3.fromRGB(195,185,145),TextSize=11,BackgroundTransparency=1,
        Size=UDim2.new(1,-6,0,17),Position=UDim2.new(0,8,0,3),
        TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
    local tb=Criar("TextBox",{Text=tostring(pad),Font=Enum.Font.GothamBold,
        TextColor3=Color3.fromRGB(212,175,55),TextSize=13,
        BackgroundColor3=Color3.fromRGB(10,10,16),BorderSizePixel=0,
        Size=UDim2.new(0.54,0,0,22),Position=UDim2.new(0,8,0,28),
        ClearTextOnFocus=false,Parent=f})
    Criar("UICorner",{CornerRadius=UDim.new(0,5),Parent=tb})
    Criar("UIStroke",{Color=Color3.fromRGB(212,175,55),Thickness=1,Parent=tb})
    local bt=Criar("TextButton",{Text=btnT,Font=Enum.Font.GothamBold,
        TextColor3=Color3.fromRGB(10,10,15),TextSize=11,
        BackgroundColor3=Color3.fromRGB(212,175,55),BorderSizePixel=0,
        Size=UDim2.new(0.38,0,0,22),Position=UDim2.new(0.59,0,0,28),Parent=f})
    Criar("UICorner",{CornerRadius=UDim.new(0,5),Parent=bt})
    bt.MouseButton1Click:Connect(function()
        local v=tonumber(tb.Text); if v then pcall(cb,v) end
    end)
end

-- ── Conteúdo das Abas ──

-- ESP
local eP=Abas["ESP"].p
Sec(eP,"Geral")
Tog(eP,"Ativar ESP",         Cfg.ESP_Ativo,   function(v) Cfg.ESP_Ativo=v end)
Tog(eP,"Highlight",          Cfg.HL_Ativo,    function(v) Cfg.HL_Ativo=v end)
Tog(eP,"Billboard",          Cfg.BB_Ativo,    function(v) Cfg.BB_Ativo=v end)
Tog(eP,"Distância",          Cfg.Dist_Ativo,  function(v) Cfg.Dist_Ativo=v end)
Tog(eP,"⚠️ Avisos Entidades",Cfg.Aviso_Ativo, function(v) Cfg.Aviso_Ativo=v end)
Sec(eP,"Selecionar")
Tog(eP,"🚪 Portas",    Cfg.ESP_Portas,    function(v) Cfg.ESP_Portas=v end)
Tog(eP,"🔵 Chaves",    Cfg.ESP_Chaves,    function(v) Cfg.ESP_Chaves=v end)
Tog(eP,"🟠 Alavancas", Cfg.ESP_Alavancas, function(v) Cfg.ESP_Alavancas=v end)
Tog(eP,"🟣 Livros",    Cfg.ESP_Livros,    function(v) Cfg.ESP_Livros=v end)
Tog(eP,"🔴 Figure",    Cfg.ESP_Figure,    function(v) Cfg.ESP_Figure=v end)
Tog(eP,"🔴 Screech",   Cfg.ESP_Screech,   function(v) Cfg.ESP_Screech=v end)
Sec(eP,"Busca Manual")
Tog(eP,"Buscar Figure",false,function(v)
    Estado.ProcurandoFigure=v
    if v then Notif("Felix Hub","Buscando Figure...",3) end
end)
Tog(eP,"🔍 Scan Livros (global)",false,function(v)
    Estado.ProcurandoLivros=v
    if v then
        Estado.LivrosN=0
        for k in pairs(Cache) do if k:find("LiveHintBook") then Cache[k]=nil end end
        task.spawn(ScanLivros)
    end
end)

-- Itens
local iP=Abas["Itens"].p
Sec(iP,"Itens Coletáveis")
Tog(iP,"🟢 Itens do chão",Cfg.ESP_Itens,    function(v) Cfg.ESP_Itens=v end)
Tog(iP,"🟡 Baús",          Cfg.ESP_Baus,     function(v) Cfg.ESP_Baus=v end)
Tog(iP,"🟠 Fusíveis",      Cfg.ESP_Fusiveis, function(v) Cfg.ESP_Fusiveis=v end)
Sec(iP,"Auto-Gaveta")
Tog(iP,"🔑 Abrir gavetas + coletar",Cfg.AutoGaveta,function(v)
    Cfg.AutoGaveta=v
    IniciarAutoGaveta()
    if v then Notif("Felix Hub","Auto-gaveta ativado! Abrindo gavetas...",4) end
end)

-- Local Player
local lP=Abas["Local"].p
Sec(lP,"Speed Hack")
Inp(lP,"Velocidade:",16,"▶ Ativar",function(v)
    Cfg.WalkSpeedValor=v; AppSpeed(v); Notif("⚡ Speed","WalkSpeed: "..v,3)
end)
local rS=Criar("TextButton",{Text="↺ Resetar (16)",Font=Enum.Font.Gotham,
    TextColor3=Color3.fromRGB(195,185,145),TextSize=11,
    BackgroundColor3=Color3.fromRGB(15,15,22),BorderSizePixel=0,
    Size=UDim2.new(1,0,0,28),Parent=lP})
Criar("UICorner",{CornerRadius=UDim.new(0,7),Parent=rS})
Criar("UIStroke",{Color=Color3.fromRGB(38,36,26),Thickness=1,Parent=rS})
rS.MouseButton1Click:Connect(function() Cfg.WalkSpeedValor=16; AppSpeed(16) end)
Sec(lP,"Jump Power")
Inp(lP,"Jump Power:",50,"▶ Ativar",function(v)
    Cfg.JumpPowerValor=v; AppJump(v); Notif("⚡ Jump","JumpPower: "..v,3)
end)
local rJ=Criar("TextButton",{Text="↺ Resetar (50)",Font=Enum.Font.Gotham,
    TextColor3=Color3.fromRGB(195,185,145),TextSize=11,
    BackgroundColor3=Color3.fromRGB(15,15,22),BorderSizePixel=0,
    Size=UDim2.new(1,0,0,28),Parent=lP})
Criar("UICorner",{CornerRadius=UDim.new(0,7),Parent=rJ})
Criar("UIStroke",{Color=Color3.fromRGB(38,36,26),Thickness=1,Parent=rJ})
rJ.MouseButton1Click:Connect(function() Cfg.JumpPowerValor=50; AppJump(50) end)
Sec(lP,"Câmera")
Sld(lP,"FOV",60,120,70,function(v) Camera.FieldOfView=v end)

-- Visual
local vP=Abas["Visual"].p
Sec(vP,"Iluminação")
Tog(vP,"Fullbright",false,TFullbright)
Tog(vP,"Anti-Lag",  false,TAntiLag)

-- Doors
local dP=Abas["Doors"].p
Sec(dP,"Proteção")
Tog(dP,"🛡️ Proteção Eyes",false,ProtEyes)
Tog(dP,"Remover Screech",Cfg.RemoverScreech,function(v) Cfg.RemoverScreech=v end)
Sec(dP,"Notificações")
Tog(dP,"Notif. Portas",Cfg.NotifPortas,function(v) Cfg.NotifPortas=v end)
Sec(dP,"Sala 50")
local b50=Criar("TextButton",{Text="⚡  Ativar Modo Sala 50",Font=Enum.Font.GothamBold,
    TextColor3=Color3.fromRGB(212,175,55),TextSize=12,
    BackgroundColor3=Color3.fromRGB(28,22,6),BorderSizePixel=0,
    Size=UDim2.new(1,0,0,28),Parent=dP})
Criar("UICorner",{CornerRadius=UDim.new(0,7),Parent=b50})
Criar("UIStroke",{Color=Color3.fromRGB(212,175,55),Thickness=1,Parent=b50})
b50.MouseButton1Click:Connect(function()
    Estado.ProcurandoFigure=true; Estado.ProcurandoLivros=true; Estado.LivrosN=0
    for k in pairs(Cache) do
        if k:find("LiveHintBook") or k:find("FigureRig") then Cache[k]=nil end
    end
    task.spawn(ScanLivros); Notif("📚 Sala 50","Buscando livros e Figure...",5)
end)

-- Info
local nP=Abas["Info"].p
Sec(nP,"Felix Hub v2.7")
Criar("TextLabel",{
    Text="Felix Hub  v2.7\nDOORS Edition\n\n✅ Mobile & PC\n✅ Delta/Hydrogen/Fluxus/Arceus X\n\n• Botão F = abre/fecha\n• RCtrl / F9 = abre/fecha\n• Arraste o header pra mover",
    Font=Enum.Font.Gotham,TextColor3=Color3.fromRGB(175,160,110),TextSize=11,
    BackgroundColor3=Color3.fromRGB(15,15,22),BackgroundTransparency=0,
    Size=UDim2.new(1,0,0,120),TextWrapped=true,
    TextYAlignment=Enum.TextYAlignment.Top,Parent=nP})

-- ── Arrastar janela ──
local drg,dOff=false,Vector2.zero
Hdr.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        drg=true
        dOff=Vector2.new(i.Position.X-Win.AbsolutePosition.X, i.Position.Y-Win.AbsolutePosition.Y)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if drg and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local vp=Camera.ViewportSize
        Win.Position=UDim2.new(0,
            math.clamp(i.Position.X-dOff.X, 0, vp.X-WIN_W), 0,
            math.clamp(i.Position.Y-dOff.Y, 0, vp.Y-WIN_H))
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drg=false end
end)

-- ── Arrastar botão ──
local bdg,bOff,bMov=false,Vector2.zero,false
BH.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        bdg=true; bMov=false
        local p=BH.AbsolutePosition; bOff=Vector2.new(i.Position.X-p.X,i.Position.Y-p.Y)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if bdg and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local vp=Camera.ViewportSize
        BH.Position=UDim2.new(0,
            math.clamp(i.Position.X-bOff.X,0,vp.X-44), 0,
            math.clamp(i.Position.Y-bOff.Y,0,vp.Y-44))
        bMov=true
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then bdg=false end
end)

-- ── Abrir/Fechar ──
local Open=false; local Mini=false

local function Abrir()
    Open=true
    -- Posição sempre fixa na esquerda antes de mostrar
    Win.Position=UDim2.new(0,WIN_X,0,WIN_Y)
    Win.Size=UDim2.new(0,WIN_W,0,WIN_H)
    Win.BackgroundTransparency=0
    Win.Visible=true
    if not AbaAtiva then Aba("ESP") end
end

local function Fechar()
    Open=false
    Win.Visible=false
end

local function Toggle() if Open then Fechar() else Abrir() end end

local function Minimizar()
    Mini=not Mini
    if Mini then
        TW(Win,TweenInfo.new(0.15),{Size=UDim2.new(0,WIN_W,0,44)})
        Cont.Visible=false; SB.Visible=false
    else
        Win.Size=UDim2.new(0,WIN_W,0,44)
        TW(Win,TweenInfo.new(0.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
            {Size=UDim2.new(0,WIN_W,0,WIN_H)})
        Cont.Visible=true; SB.Visible=true
    end
end

BtnF.MouseButton1Click:Connect(function() if not bMov then Toggle() end; bMov=false end)
BX.MouseButton1Click:Connect(Fechar)
BMin.MouseButton1Click:Connect(Minimizar)
UserInputService.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode==Enum.KeyCode.RightControl or i.KeyCode==Enum.KeyCode.F9 then Toggle() end
end)

BH.MouseEnter:Connect(function()
    TW(BH,TweenInfo.new(0.13),{BackgroundColor3=Color3.fromRGB(24,20,6)})
end)
BH.MouseLeave:Connect(function()
    TW(BH,TweenInfo.new(0.13),{BackgroundColor3=Color3.fromRGB(12,12,18)})
end)

-- Iniciar
Aba("ESP")
task.spawn(IniciarESP)
task.delay(0.6,function()
    Notif("⚡ Felix Hub v2.7","Carregado! Clique no F ou RCtrl.",5)
end)
print("[FelixHub] v2.7 carregado!")

end) -- fim pcall

if not ok then
    warn("[FelixHub] ERRO:", err)
    pcall(function()
        local sg=Instance.new("ScreenGui"); sg.ResetOnSpawn=false
        sg.Parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        local lb=Instance.new("TextLabel")
        lb.Text="FelixHub ERRO:\n"..tostring(err)
        lb.TextColor3=Color3.fromRGB(255,80,80)
        lb.BackgroundColor3=Color3.fromRGB(10,10,15)
        lb.Size=UDim2.new(0,340,0,120)
        lb.Position=UDim2.new(0.5,-170,0.5,-60)
        lb.Font=Enum.Font.Gotham; lb.TextSize=11
        lb.TextWrapped=true; lb.Parent=sg
    end)
end
