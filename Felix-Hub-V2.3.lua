--[=[
╔══════════════════════════════════════════════════════════╗
║            FELIX HUB v2.3 - STABLE & EXECUTOR SAFE       ║
║          Syntax Validated | Mobile Optimized             ║
║   Works on: Delta, Hydrogen, Fluxus, Arceus X, Codex     ║
╚══════════════════════════════════════════════════════════╝
--]=]

if _G.FelixHubLoaded then return end
_G.FelixHubLoaded = true

-- ════════════════════════════════════════════
--  SERVIÇOS & VARIÁVEIS LOCAIS
-- ════════════════════════════════════════════
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local UserInput     = game:GetService("UserInputService")
local StarterGui    = game:GetService("StarterGui")
local Lighting      = game:GetService("Lighting")
local CoreGui       = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ════════════════════════════════════════════
--  MAID SYSTEM (Limpeza automática: Conns, Objs, Tweens)
-- ════════════════════════════════════════════
local Maid = { conns = {}, objs = {}, tweens = {} }
function Maid:Add(obj)
if typeof(obj) == "RBXScriptConnection" then
table.insert(self.conns, obj)
elseif typeof(obj) == "Instance" then
table.insert(self.objs, obj)
elseif typeof(obj) == "Tween" then
table.insert(self.tweens, obj)
end
end
function Maid:Cleanup()
for _, c in ipairs(self.conns) do pcall(function() c:Disconnect() end) end
for _, o in ipairs(self.objs) do pcall(function() o:Destroy() end) end
for _, t in ipairs(self.tweens) do pcall(function() t:Cancel() end) end
self.conns, self.objs, self.tweens = {}, {}, {}
end

-- ════════════════════════════════════════════
--  CONFIGURAÇÕES & ESTADO
-- ════════════════════════════════════════════
local Config = {
ESP = true, Highlight = true, Billboard = true, Dist = true,    WarnEnt = true, Fullbright = false, Blur = false, AntiLag = false,
FOVChange = false, FOVVal = 120, Speed = false, SpeedVal = 16,
Jump = false, JumpVal = 50, KillScreech = true, NotifPortas = true,
AutoHeal = false, NoClip = false,
Colors = {
Door = Color3.fromRGB(255,215,0), Key = Color3.fromRGB(30,144,255),
Lever = Color3.fromRGB(255,140,0), Book = Color3.fromRGB(160,32,240),
Figure = Color3.fromRGB(220,20,60), Screech = Color3.fromRGB(200,0,0)
},
MaxDist = 500, UpdateRate = 0.2
}

local State = { Figure = false, Books = false, BooksFound = 0 }
local Processed = { Door = {}, Key = {}, Lever = {}, Book = {}, Figure = {}, Screech = {} }
local ActiveBillboards = {}
local BlurObj = nil
local HubOpen = false
local IsMinimized = false

-- ════════════════════════════════════════════
--  UTILITÁRIOS
-- ════════════════════════════════════════════
local function Create(class, props)
local o = Instance.new(class)
for k, v in pairs(props) do pcall(function() o[k] = v end) end
return o
end

local function Notify(title, text, dur)
pcall(function() StarterGui:SetCore("SendNotification", {Title = title or "Felix", Text = text or "", Duration = dur or 4}) end)
end

local function IsValidRoom(n)
local v = tonumber(n)
return v and v >= 1 and v <= 100
end

local function GetPart(target)
if not target or not target.Parent then return nil end
if target:IsA("BasePart") then return target end
if target:IsA("Model") then
if target.PrimaryPart then return target.PrimaryPart end
for _, v in ipairs(target:GetDescendants()) do if v:IsA("BasePart") then return v end end
end
return nil
end

-- ════════════════════════════════════════════
--  RENDERIZADOR GLOBAL DE BILLBOARDS (0.2s)
-- ════════════════════════════════════════════local function StartBillboardUpdater()
local last = 0
local conn = RunService.Heartbeat:Connect(function()
local now = tick()
if now - last < Config.UpdateRate then return end
last = now
if not Config.Dist or not Config.Billboard then return end
for uid, data in pairs(ActiveBillboards) do
pcall(function()
local dist = math.floor((Camera.CFrame.Position - data.part.Position).Magnitude)
data.label.Text = data.base .. " [" .. dist .. "m]"
end)
end
end)
Maid:Add(conn)
end

-- ════════════════════════════════════════════
--  CRIAÇÃO VISUAL
-- ════════════════════════════════════════════
local function CreateBillboard(target, text, color)
if not Config.Billboard then return end
local part = GetPart(target)
if not part then return end
local uid = "BB_" .. target:GetFullName():gsub("[^%w]", "_")
if target:GetAttribute("FBB") == uid then return end
target:SetAttribute("FBB", uid)
local old = CoreGui:FindFirstChild(uid)
if old then old:Destroy() end
local bbg = Create("BillboardGui", {
Name = uid, Adornee = part, AlwaysOnTop = true, LightInfluence = 0,
MaxDistance = Config.MaxDist, Size = UDim2.new(0, 140, 0, 34), StudsOffset = Vector3.new(0, 2.5, 0)
})
local frame = Create("Frame", {BackgroundTransparency = 0.3, BackgroundColor3 = Color3.fromRGB(10, 10, 15), Size = UDim2.new(1, 0, 1, 0), Parent = bbg})
Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = frame})
Create("UIStroke", {Color = color, Thickness = 1.5, Parent = frame})
local label = Create("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = Enum.Font.GothamBold, TextColor3 = color, TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = 0.4, TextScaled = true, Text = text, Parent = frame})
ActiveBillboards[uid] = {part = part, label = label, base = text}
if not pcall(function() bbg.Parent = CoreGui end) then bbg.Parent = LocalPlayer.PlayerGui end
Maid:Add(bbg)
target.AncestryChanged:Connect(function()
if not target:IsDescendantOf(game) then
pcall(function() bbg:Destroy() end)
ActiveBillboards[uid] = nil
end
end)
end

local function CreateHighlight(target, color, text)
if not Config.Highlight then        if Config.Billboard then CreateBillboard(target, text, color) end
return
end
local uid = "HL_" .. target:GetFullName():gsub("[^%w]", "_")
if target:FindFirstChild(uid) then return end
local hl = Create("Highlight", {Name = uid, Adornee = target, FillColor = color, FillTransparency = 0.55, OutlineColor = Color3.new(1, 1, 1), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = true, Parent = target})
Maid:Add(hl)
local tw = TweenService:Create(hl, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {FillTransparency = 0.75})
tw:Play()
Maid:Add(tw)
if Config.Billboard then CreateBillboard(target, text, color) end
target.AncestryChanged:Connect(function()
if not target:IsDescendantOf(game) then pcall(function() hl:Destroy() end) end
end)
end

-- ════════════════════════════════════════════
--  ESP PROCESSORS
-- ════════════════════════════════════════════
local function ProcKey(o) if not Config.ESP then return end; local u = o:GetFullName(); if not Processed.Key[u] then Processed.Key[u] = true; CreateHighlight(o, Config.Colors.Key, "🔵 CHAVE") end end
local function ProcLever(o) if not Config.ESP then return end; local u = o:GetFullName(); if not Processed.Lever[u] then Processed.Lever[u] = true; CreateHighlight(o:FindFirstChild("Main") or o, Config.Colors.Lever, "🟠 ALAVANCA") end end
local function ProcBook(o)
if not Config.ESP or not State.Books then return end
local u = o:GetFullName(); if Processed.Book[u] then return end
Processed.Book[u] = true; State.BooksFound = State.BooksFound + 1
CreateHighlight(o, Config.Colors.Book, "🟣 LIVRO " .. State.BooksFound .. "/8")
if State.BooksFound >= 8 then State.Books = false; Notify("📚 Felix", "8 livros encontrados!", 5) end
end
local function ProcFigure(o)
if not Config.ESP or not State.Figure then return end
local u = o:GetFullName(); if Processed.Figure[u] then return end
Processed.Figure[u] = true; State.Figure = false
CreateHighlight(o, Config.Colors.Figure, "🔴 FIGURE!")
if Config.WarnEnt then Notify("⚠️ PERIGO", "Figure! Esconda-se!", 6) end
end
local function ProcScreech(o)
if not Config.ESP then return end
local u = o:GetFullName(); if Processed.Screech[u] then return end
Processed.Screech[u] = true
CreateHighlight(o, Config.Colors.Screech, "🔴 SCREECH!")
if Config.WarnEnt then Notify("⚠️ SCREECH", "Olhe para ele!", 4) end
if Config.KillScreech then pcall(function() o:Destroy() end) end
end
local function ProcDoor(o)
if not Config.ESP then return end
local room = o.Parent; while room and room ~= workspace do if IsValidRoom(room.Name) then break end; room = room.Parent end
local num = room and tonumber(room.Name) or 0; if num == 0 then return end
local uid = "Door_" .. num; if Processed.Door[uid] then return end
Processed.Door[uid] = true
CreateHighlight(o:FindFirstAncestor("Door") or o.Parent, Config.Colors.Door, "🚪 PORTA " .. num)    if Config.NotifPortas then Notify("🚪 Porta", "Sala " .. num, 3) end
if num == 50 then State.Figure = true; State.Books = true; State.BooksFound = 0; Processed.Book, Processed.Figure = {}, {}; Notify("📚 Felix", "Modo Sala 50 ativado!", 5) end
end

-- ════════════════════════════════════════════
--  ESP LISTENER (Chunked)
-- ════════════════════════════════════════════
local function InitESP()
local CR = workspace:FindFirstChild("CurrentRooms")
if not CR then pcall(function() CR = workspace:WaitForChild("CurrentRooms", 10) end) end
if not CR then return end
local function Process(o)
if not o or not o:IsDescendantOf(CR) then return end
local n = o.Name
if n == "KeyObtain" then ProcKey(o)
elseif n == "LeverForGate" then ProcLever(o)
elseif n == "LiveHintBook" then ProcBook(o)
elseif n == "FigureRig" then ProcFigure(o)
elseif n == "ScreechRig" then ProcScreech(o)
elseif n == "ClientOpen" or n == "Door" then ProcDoor(o)
end
end
local desc = CR:GetDescendants()
task.spawn(function() for i = 1, #desc, 50 do for j = i, math.min(i + 49, #desc) do task.spawn(Process, desc[j]) end; if i % 150 == 0 then task.wait() end end end)
Maid:Add(workspace.DescendantAdded:Connect(function(o) task.spawn(Process, o) end))
end

-- ════════════════════════════════════════════
--  SECURITY & PLAYER
-- ════════════════════════════════════════════
local function AutoHeal()
if not Config.AutoHeal then return end
local c = LocalPlayer.Character; if not c then return end
local h = c:FindFirstChildOfClass("Humanoid"); if h and h.Health < h.MaxHealth then pcall(function() h.Health = h.MaxHealth end) end
end

local NoClipCache = {}
local function UpdateNoClip()
local c = LocalPlayer.Character; if not c then return end
for _, v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") and not NoClipCache[v] then v.CanCollide = not Config.NoClip; NoClipCache[v] = true end end
end

Maid:Add(LocalPlayer.CharacterAdded:Connect(function(c)
c:WaitForChild("Humanoid", 5)
task.wait(0.2)
UpdateNoClip()
if Config.Speed then c.Humanoid.WalkSpeed = Config.SpeedVal end
if Config.Jump then c.Humanoid.JumpPower = Config.JumpVal; c.Humanoid.UseJumpPower = true end
end))
Maid:Add(RunService.Heartbeat:Connect(function() if HubOpen then AutoHeal() end end))
-- ════════════════════════════════════════════
--  TOGGLES SEGUROS
-- ════════════════════════════════════════════
local function ToggleFull(v)
Config.Fullbright = v
if v then Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness = Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255), 10
else Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness = Color3.fromRGB(70,70,70), Color3.fromRGB(70,70,70), 1 end
end
local function ToggleBlur(v)
Config.Blur = v
if not BlurObj then BlurObj = Create("BlurEffect", {Size = 16, Parent = Lighting, Enabled = v}) else BlurObj.Enabled = v end
end
local function ToggleAntiLag(v)
Config.AntiLag = v
pcall(function() settings().Rendering.QualityLevel = v and 1 or Enum.QualityLevel.Automatic end)
end

-- ════════════════════════════════════════════
--  UI (Segura & Compacta)
-- ════════════════════════════════════════════
local OldGui = CoreGui:FindFirstChild("FelixGUI") or LocalPlayer.PlayerGui:FindFirstChild("FelixGUI")
if OldGui then OldGui:Destroy() end
local Screen = Create("ScreenGui", {Name = "FelixGUI", ResetOnSpawn = false, IgnoreGuiInset = true})
pcall(function() Screen.Parent = CoreGui end)
if not Screen.Parent then Screen.Parent = LocalPlayer.PlayerGui end

-- Botão Flutuante
local Btn = Create("Frame", {Name = "Btn", Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, 20, 0.5, -28), BackgroundColor3 = Color3.fromRGB(15, 15, 20), Parent = Screen})
Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Btn})
Create("UIStroke", {Color = Color3.fromRGB(212, 175, 55), Thickness = 2, Parent = Btn})
Create("TextLabel", {Text = "F", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(212, 175, 55), TextSize = 26, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Btn})
-- Click detector confiável
local BtnClick = Create("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = Btn})
Maid:Add(BtnClick)

local Win = Create("Frame", {Name = "Win", Size = UDim2.new(0, 560, 0, 400), Position = UDim2.new(0.5, -280, 0.5, -200), BackgroundColor3 = Color3.fromRGB(10, 10, 15), BorderSizePixel = 0, ClipsDescendants = true, Visible = false, Parent = Screen})
Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = Win})
Create("UIStroke", {Color = Color3.fromRGB(212, 175, 55), Thickness = 1.5, Parent = Win})
local Head = Create("Frame", {Name = "Head", Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Color3.fromRGB(8, 8, 12), Parent = Win})
Create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = Head})
Create("TextLabel", {Text = "⚡ FELIX v2.3", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(212, 175, 55), TextSize = 20, BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 1, 0), Position = UDim2.new(0, 16, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = Head})
local BMin = Create("TextButton", {Text = "─", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(212, 175, 55), TextSize = 18, BackgroundColor3 = Color3.fromRGB(20, 20, 28), Size = UDim2.new(0, 32, 0, 26), Position = UDim2.new(1, -70, 0.5, -13), Parent = Head})
Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = BMin})
local BClose = Create("TextButton", {Text = "✕", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 80, 80), TextSize = 16, BackgroundColor3 = Color3.fromRGB(20, 20, 28), Size = UDim2.new(0, 32, 0, 26), Position = UDim2.new(1, -34, 0.5, -13), Parent = Head})
Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = BClose})
local Side = Create("Frame", {Name = "Side", Size = UDim2.new(0, 110, 1, -50), Position = UDim2.new(0, 0, 0, 50), BackgroundColor3 = Color3.fromRGB(8, 8, 12), Parent = Win})
local Cont = Create("Frame", {Name = "Cont", Size = UDim2.new(1, -110, 1, -50), Position = UDim2.new(0, 110, 0, 50), BackgroundTransparency = 1, Parent = Win})

local Tabs, TabBtns = {}, {}for , info in ipairs({{"ESP", "👁"}, {"Visual", "🎨"}, {"Player", "🏃"}, {"Sec", "⚙️"}, {"Doors", "🚪"}}) do
local b = Create("TextButton", {Text = info[2] .. "\n" .. info[1], Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(120, 110, 80), TextSize = 12, BackgroundColor3 = Color3.fromRGB(14, 14, 20), Size = UDim2.new(0.88, 0, 0, 52), AutoButtonColor = false, Parent = Side})
Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b})
local p = Create("ScrollingFrame", {Name = "P" .. info[1], Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = Cont})
Create("UIListLayout", {Padding = UDim.new(0, 8), Parent = p})
Create("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), Parent = p})
Tabs[info[1]] = p; TabBtns[info[1]] = b
end

local function OpenTab(n)
for k, v in pairs(Tabs) do v.Visible = false; TweenService:Create(TabBtns[k], TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(14, 14, 20), TextColor3 = Color3.fromRGB(120, 110, 80)}):Play() end
if Tabs[n] then Tabs[n].Visible = true; TweenService:Create(TabBtns[n], TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 25, 8), TextColor3 = Color3.fromRGB(212, 175, 55)}):Play() end
end
for k in pairs(Tabs) do TabBtns[k].MouseButton1Click:Connect(function() OpenTab(k) end) end

local function Toggle(parent, txt, init, cb)
local f = Create("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(16, 16, 22), BorderSizePixel = 0, Parent = parent})
Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = f})
Create("UIStroke", {Color = Color3.fromRGB(40, 38, 28), Thickness = 1, Parent = f})
Create("TextLabel", {Text = txt, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 190, 150), TextSize = 13, BackgroundTransparency = 1, Size = UDim2.new(1, -54, 1, 0), Position = UDim2.new(0, 10, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
local t = Create("Frame", {Size = UDim2.new(0, 40, 0, 20), Position = UDim2.new(1, -48, 0.5, -10), BackgroundColor3 = init and Color3.fromRGB(180, 140, 20) or Color3.fromRGB(35, 35, 40), BorderSizePixel = 0, Parent = f})
Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = t})
local b = Create("Frame", {Size = UDim2.new(0, 14, 0, 14), Position = init and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = t})
Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = b})
local st = init
local btn = Create("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = f})
btn.MouseButton1Click:Connect(function() st = not st; TweenService:Create(t, TweenInfo.new(0.18), {BackgroundColor3 = st and Color3.fromRGB(180, 140, 20) or Color3.fromRGB(35, 35, 40)}):Play(); TweenService:Create(b, TweenInfo.new(0.18), {Position = st and UDim2.new(0, 23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)}):Play(); pcall(cb, st) end)
end

-- Preencher Abas
Toggle(Tabs["ESP"], "ESP Ativo", Config.ESP, function(v) Config.ESP = v end)
Toggle(Tabs["ESP"], "Billboard + Dist", Config.Billboard, function(v) Config.Billboard = v; Config.Dist = v end)
Toggle(Tabs["ESP"], "Buscar Figure", State.Figure, function(v) State.Figure = v end)
Toggle(Tabs["Visual"], "Fullbright", Config.Fullbright, ToggleFull)
Toggle(Tabs["Visual"], "Blur", Config.Blur, ToggleBlur)
Toggle(Tabs["Visual"], "Anti-Lag (pcall)", Config.AntiLag, ToggleAntiLag)
Toggle(Tabs["Player"], "WalkSpeed", Config.Speed, function(v) Config.Speed = v; local c = LocalPlayer.Character; if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = v and Config.SpeedVal or 16 end end)
Toggle(Tabs["Player"], "JumpPower", Config.Jump, function(v) Config.Jump = v; local c = LocalPlayer.Character; if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpPower = v and Config.JumpVal or 50; c.Humanoid.UseJumpPower = true end end)
Toggle(Tabs["Sec"], "Auto-Regen (Client)", Config.AutoHeal, function(v) Config.AutoHeal = v end)
Toggle(Tabs["Sec"], "NoClip", Config.NoClip, function(v) Config.NoClip = v; UpdateNoClip() end)
Toggle(Tabs["Sec"], "Kill Screech", Config.KillScreech, function(v) Config.KillScreech = v end)
Toggle(Tabs["Doors"], "Notif Portas", Config.NotifPortas, function(v) Config.NotifPortas = v end)
local b50 = Create("TextButton", {Text = "⚡ Modo Sala 50", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(212, 175, 55), TextSize = 13, BackgroundColor3 = Color3.fromRGB(30, 25, 8), Size = UDim2.new(1, 0, 0, 38), BorderSizePixel = 0, Parent = Tabs["Doors"]})
Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b50})
b50.MouseButton1Click:Connect(function() State.Figure = true; State.Books = true; State.BooksFound = 0; Processed.Book, Processed.Figure = {}, {}; Notify("📚 Felix", "Sala 50 ativada!", 5) end)


-- Drag System
local dragWin, dragOffW = false, Vector2.new()
Head.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragWin = true; dragOffW = Vector2.new(i.Position.X - Win.AbsolutePosition.X, i.Position.Y - Win.AbsolutePosition.Y) end end)
UserInput.InputChanged:Connect(function(i) if dragWin and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local vp = Camera.ViewportSize; Win.Position = UDim2.new(0, math.clamp(i.Position.X - dragOffW.X, 0, vp.X - 560), 0, math.clamp(i.Position.Y - dragOffW.Y, 0, vp.Y - 400)) end end)
UserInput.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragWin = false end end)

local dragBtn, dragOffB = false, Vector2.new()
Btn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragBtn = true; dragOffB = Vector2.new(i.Position.X - Btn.AbsolutePosition.X, i.Position.Y - Btn.AbsolutePosition.Y) end end)
UserInput.InputChanged:Connect(function(i) if dragBtn and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local vp = Camera.ViewportSize; Btn.Position = UDim2.new(0, math.clamp(i.Position.X - dragOffB.X, 0, vp.X - 56), 0, math.clamp(i.Position.Y - dragOffB.Y, 0, vp.Y - 56)) end end)
UserInput.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragBtn = false end end)

-- Open/Close Logic
local function OpenHub()
HubOpen = true
Win.Visible = true
Win.Size = UDim2.new(0, 10, 0, 10)
Win.BackgroundTransparency = 1
TweenService:Create(Win, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Size = UDim2.new(0, 560, 0, 400), BackgroundTransparency = 0}):Play()
if not Tabs["ESP"].Visible then OpenTab("ESP") end
end
local function CloseHub()
HubOpen = false
TweenService:Create(Win, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 10, 0, 10), BackgroundTransparency = 1}):Play()
task.delay(0.22, function() Win.Visible = false end)
end
local function ToggleMinHub()
IsMinimized = not IsMinimized
if IsMinimized then
TweenService:Create(Win, TweenInfo.new(0.2), {Size = UDim2.new(0, 560, 0, 50)}):Play()
Cont.Visible, Side.Visible = false, false
else
TweenService:Create(Win, TweenInfo.new(0.2), {Size = UDim2.new(0, 560, 0, 400)}):Play()
Cont.Visible, Side.Visible = true, true
end
end

-- Click do botão F (agora via TextButton overlay)
BtnClick.MouseButton1Click:Connect(function() if HubOpen then CloseHub() else OpenHub() end end)
BClose.MouseButton1Click:Connect(CloseHub)
BMin.MouseButton1Click:Connect(ToggleMinHub)
UserInput.InputBegan:Connect(function(i, p) if p then return end; if i.KeyCode == Enum.KeyCode.RightControl or i.KeyCode == Enum.KeyCode.F9 then if HubOpen then CloseHub() else OpenHub() end end end)

-- Init
OpenTab("ESP")
StartBillboardUpdater()
task.spawn(InitESP)
Notify("⚡ Felix v2.3", "Carregado! RCtrl/F9 ou botão F.", 5)
