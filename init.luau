local function FirstTableKey(values)
	for key in values do return key end
	return nil
end

local UIEnvironment = shared or _G
if type(getgenv) == "function" then
	local ok, environment = pcall(getgenv)
	if ok and type(environment) == "table" then
		UIEnvironment = environment
	end
end

local previousUI = rawget(UIEnvironment, "__layer_active_ui") or rawget(UIEnvironment, "layer.app")
if type(previousUI) == "table" and type(previousUI.Destroy) == "function" then
	local ok, err = pcall(previousUI.Destroy, previousUI)
	if not ok then
		error("layer.app | failed to unload the previous UI: " .. tostring(err))
	end
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local ContextActionService = game:GetService("ContextActionService")
local CoreGui = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")

local CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local CHARS_LENGTH = #CHARS
local function RandomName(len)
	len = len or 12
	local t = {}
	for i = 1, len do
		local idx = math.random(1, CHARS_LENGTH)
		t[i] = string.sub(CHARS, idx, idx)
	end
	return table.concat(t)
end
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local function GetPlayerGui()
	local player = Players.LocalPlayer
	if not player then
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		player = Players.LocalPlayer
	end
	if not player then
		return nil
	end
	return player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
end

local function ParentGui(gui)
	local ok = pcall(function()
		if gethui then
			gui.Parent = gethui()
		elseif syn and syn.protect_gui then
			syn.protect_gui(gui)
			gui.Parent = CoreGui
		else
			gui.Parent = CoreGui
		end
	end)
	if ok and gui.Parent then
		return
	end
	local playerGui = GetPlayerGui()
	if playerGui then
		gui.Parent = playerGui
	else
		gui.Parent = CoreGui
	end
end

local Theme = {
	Window = Color3.fromRGB(26, 26, 28),
	WindowAlpha = 0.012,
	WindowBorder = Color3.fromRGB(52, 52, 56),
	TopBar = Color3.fromRGB(31, 31, 34),
	Section = Color3.fromRGB(29, 29, 32),
	SectionBorder = Color3.fromRGB(46, 46, 50),
	Group = Color3.fromRGB(34, 34, 37),
	GroupBorder = Color3.fromRGB(54, 54, 58),
	Field = Color3.fromRGB(40, 40, 44),
	FieldHover = Color3.fromRGB(48, 48, 52),
	Border = Color3.fromRGB(60, 60, 65),
	BorderSoft = Color3.fromRGB(45, 45, 49),
	PopupBg = Color3.fromRGB(38, 38, 42),
	PopupBorder = Color3.fromRGB(62, 62, 67),
	Track = Color3.fromRGB(58, 58, 62),
	Text = Color3.fromRGB(174, 174, 178),
	TextDim = Color3.fromRGB(108, 108, 113),
	TextBright = Color3.fromRGB(228, 228, 232),
	TextMarked = Color3.fromRGB(198, 198, 122),
	TextCode = Color3.fromRGB(96, 200, 96),
	Danger = Color3.fromRGB(226, 102, 102),
	Accent = Color3.fromRGB(232, 161, 168),
	Highlight = Color3.fromRGB(232, 161, 168),
	AccentSoft = Color3.fromRGB(240, 186, 191),
	AccentDim = Color3.fromRGB(146, 98, 103),
	Font = Enum.Font.Gotham,
	FontMedium = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	TextSize = 16,
	Radius = 7,
	GearIcon = "rbxassetid://6031280882",
}

local AccentHexColor
local AccentHexValue
local function AccentHex()
	local accent = Theme.Accent
	if AccentHexColor == accent and AccentHexValue then
		return AccentHexValue
	end
	AccentHexColor = accent
	AccentHexValue = string.format(
		"#%02X%02X%02X",
		math.floor(accent.R * 255 + 0.5),
		math.floor(accent.G * 255 + 0.5),
		math.floor(accent.B * 255 + 0.5)
	)
	return AccentHexValue
end

local MAX_DISPLAY_ORDER = 2147483647

local EASE = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_FAST = TweenInfo.new(0.10, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

local SetVisual, GetVisualValue

local Painted = {}
local PaintedCount = 0
local ThemeAlpha = {}
local ALPHA_PROPS = {
	BackgroundColor3 = "BackgroundTransparency",
	ImageColor3 = "ImageTransparency",
	TextColor3 = "TextTransparency",
	Color = "Transparency",
}
local ThemeIndex = {}
local THEME_ORDER = {
	"Window",
	"WindowBorder",
	"TopBar",
	"Section",
	"SectionBorder",
	"Group",
	"GroupBorder",
	"Field",
	"FieldHover",
	"Border",
	"BorderSoft",
	"PopupBg",
	"PopupBorder",
	"Track",
	"Text",
	"TextDim",
	"TextBright",
	"TextMarked",
	"TextCode",
	"Danger",
	"Accent",
	"Highlight",
	"AccentSoft",
	"AccentDim",
}

local function IndexTheme()
	table.clear(ThemeIndex)
	for _, key in THEME_ORDER do
		local value = Theme[key]
		if typeof(value) == "Color3" and ThemeIndex[tostring(value)] == nil then
			ThemeIndex[tostring(value)] = key
		end
	end
end
IndexTheme()

local function TagInstance(inst, props)
	local entry = Painted[inst]
	if not entry then
		entry = {}
		Painted[inst] = entry
		PaintedCount = PaintedCount + 1
		inst.Destroying:Once(function()
			if Painted[inst] then
				Painted[inst] = nil
				PaintedCount = PaintedCount - 1
			end
		end)
	end
	for property, key in props do
		if key == false then
			entry[property] = nil
		else
			entry[property] = key
			local color = Theme[key]
			if color ~= nil then
				pcall(function()
					if inst[property] ~= color then inst[property] = color end
				end)
			end
		end
	end
	return inst
end

local Library = {}
Library.Theme = Theme
Library.Flags = {}
Library.Windows = {}
Library.Connections = {}
Library.Open = true

Library.Animations = {
	Enabled = true,
	Window = 0.18,
	Popup = 0.12,
	Tab = 0.14,
	Modal = 0.18,
	Section = 0.22,
	Tooltip = 0.10,
}
Library.ToggleKey = Enum.KeyCode.End
Library.ToggleInput = nil
Library.ToggleKeyListeners = {}
Library.Binding = false
Library.Registry = {}
Library.Defaults = {}
Library.NotificationsEnabled = true
Library.NotificationLimit = nil
Library.Dirty = false
Library.DefaultTheme = "oled"
Library.UnloadCallbacks = {}
Library.BaseUrl = "https://gitlab.com/itsAstral/layer/-/raw/main/"
Library.AddonPaths = {
	Icons = "addons/Icons.luau",
	SaveManager = "addons/SaveManager.luau",
	InterfaceManager = "addons/InterfaceManager.luau",
	ThemeManager = "addons/ThemeManager.luau",
}
Library.Addons = {}
Library.Painted = Painted
Library.PaintedCount = function()
	return PaintedCount
end

Library.SectionTitleStyle = "inline"
Library.RepaintHooks = {}
Library.RepaintHookOwners = setmetatable({}, { __mode = "k" })

function Library:SafeCallback(label, callback, ...)
	if not callback then
		return
	end
	local packed = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(callback, table.unpack(packed, 1, packed.n))
		if ok then
			return
		end
		local message = tostring(err)
		local _, cut = string.find(message, ":%d+: ")
		if cut then
			message = string.sub(message, cut + 1)
		end
		warn("layer.app | callback error in '" .. tostring(label) .. "': " .. tostring(err))
		self:Error("callback error", tostring(label) .. " - " .. message, 7)
	end)
end

function Library:OnRepaint(callback, owner)
	table.insert(self.RepaintHooks, callback)
	if typeof(owner) == "Instance" then
		self.RepaintHookOwners[callback] = owner
		owner.Destroying:Connect(function()
			for i = #self.RepaintHooks, 1, -1 do
				if self.RepaintHooks[i] == callback then
					table.remove(self.RepaintHooks, i)
					break
				end
			end
			self.RepaintHookOwners[callback] = nil
		end)
	end
	return callback
end
Library.ThemeAlpha = ThemeAlpha
Library.Version = "2026.10.08-keybind-mode-dirty.125"

Library.CustomFont = {
	Name = "Iosevka Charon Mono",
	Url = "https://raw.githubusercontent.com/google/fonts/0b58fb370093f9a9f4ff785d94405710b79de67c/ofl/iosevkacharonmono/IosevkaCharonMono-Medium.ttf",
	File = "Layer_IosevkaCharonMono_Medium.ttf",
	RegularUrl = "https://raw.githubusercontent.com/google/fonts/0b58fb370093f9a9f4ff785d94405710b79de67c/ofl/iosevkacharonmono/IosevkaCharonMono-Regular.ttf",
	RegularFile = "Layer_IosevkaCharonMono_Regular.ttf",
	BoldUrl = "https://raw.githubusercontent.com/google/fonts/0b58fb370093f9a9f4ff785d94405710b79de67c/ofl/iosevkacharonmono/IosevkaCharonMono-Bold.ttf",
	BoldFile = "Layer_IosevkaCharonMono_Bold.ttf",
	FamilyFile = "Layer_IosevkaCharonMono.font",
	Weight = 500,
}
Library.FontFace = nil
Library.FontRegularFace = nil
Library.FontMediumFace = nil
Library.FontBoldFace = nil
Library.FontFamilyAsset = nil

function Library:LoadCustomFont()
	local asset = getcustomasset or getsynasset
	if not (isfile and writefile and asset) then
		return nil
	end

	local data = self.CustomFont
	local ok, result = pcall(function()
		local function loadFace(faceName, weight, url, file)
			if not isfile(file) then
				local bytes = game:HttpGet(url)
				assert(type(bytes) == "string" and #bytes > 0, "empty font response for " .. file)
				writefile(file, bytes)
			end
			return {
				name = faceName,
				weight = weight,
				style = "Regular",
				assetId = asset(file),
			}
		end

		local faces = {
			loadFace("Regular", 400, data.RegularUrl, data.RegularFile),
			not data.RegularOnly and loadFace("Medium", data.Weight or 500, data.Url, data.File) or nil,
			not data.RegularOnly and loadFace("Bold", 700, data.BoldUrl, data.BoldFile) or nil,
		}
		local family = {
			name = data.Name,
			faces = faces,
		}
		writefile(data.FamilyFile, HttpService:JSONEncode(family))
		self.FontFamilyAsset = asset(data.FamilyFile)
		self.FontRegularFace = Font.new(self.FontFamilyAsset, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
		self.FontMediumFace = data.RegularOnly and self.FontRegularFace
			or Font.new(self.FontFamilyAsset, Enum.FontWeight.Medium, Enum.FontStyle.Normal)
		self.FontBoldFace = data.RegularOnly and self.FontRegularFace
			or Font.new(self.FontFamilyAsset, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
		self.FontFace = self.FontRegularFace
		self.CustomFontWeight = Enum.FontWeight.Medium
		return self.FontFace
	end)

	if not ok then
		warn("layer.app | failed to load " .. tostring(data.Name) .. " font: " .. tostring(result))
		self.FontFace = nil
		self.FontRegularFace = nil
		self.FontMediumFace = nil
		self.FontBoldFace = nil
		self.FontFamilyAsset = nil
	end
	return self.FontFace
end

Library:LoadCustomFont()

function Library:LoadAddon(name)
	if self.Addons[name] ~= nil then
		return self.Addons[name]
	end

	local module
	local ok, found = pcall(function()
		local root = script and script.Parent
		local folder = root and (root:FindFirstChild("addons") or root:FindFirstChild("Addons"))
		local file = folder and folder:FindFirstChild(name)
		return file and require(file) or nil
	end)
	if ok then
		module = found
	end

	if module == nil then
		local path = self.AddonPaths[name]
		if not path then
			warn("layer.app | unknown addon '" .. tostring(name) .. "'")
			return nil
		end
		local fetched, source = pcall(function()
			return game:HttpGet(self.BaseUrl .. path)
		end)
		if fetched and type(source) == "string" and #source > 0 then
			local built, chunk = pcall(loadstring, source)
			if built and type(chunk) == "function" then
				local ran, value = pcall(chunk)
				if ran then
					module = value
				end
			end
		end
	end

	if module == nil then
		warn("layer.app | addon '" .. tostring(name) .. "' unavailable")
		return nil
	end
	if type(module) == "function" then
		module = module(self)
	end
	self.Addons[name] = module
	return module
end

function Library:SetColor(key, color, alpha)
	if typeof(color) ~= "Color3" or Theme[key] == nil then
		return false
	end
	Theme[key] = color
	if alpha ~= nil then
		ThemeAlpha[key] = math.clamp(alpha, 0, 1)
	end
	self:Repaint()
	return true
end

function Library:Tag(instance, props)
	if typeof(instance) ~= "Instance" then
		return instance
	end
	return TagInstance(instance, props)
end

function Library:Untag(instance)
	if Painted[instance] then
		Painted[instance] = nil
		PaintedCount = PaintedCount - 1
	end
end

function Library:Repaint()
	IndexTheme()

	local dead = {}
	for instance, entry in Painted do
		local ok = pcall(function()
			if not instance.Parent and not instance:IsA("ScreenGui") then
				table.insert(dead, instance)
				return
			end
			for property, key in entry do
				local color = Theme[key]
				if color ~= nil then
					instance[property] = color
					local alpha = tonumber(ThemeAlpha[key])
					local transparency = ALPHA_PROPS[property]
					if
						alpha
						and alpha < 1
						and alpha > 0
						and transparency
						and GetVisualValue(instance, transparency) < 1
					then
						SetVisual(instance, transparency, 1 - alpha)
					end
				end
			end
		end)
		if not ok then
			table.insert(dead, instance)
		end
	end

	for _, instance in dead do
		Painted[instance] = nil
		PaintedCount = PaintedCount - 1
	end

	self:RefreshHotkeys()
	for i = #self.RepaintHooks, 1, -1 do
		local callback = self.RepaintHooks[i]
		local owner = self.RepaintHookOwners[callback]
		local alive = owner == nil or owner.Parent ~= nil
		local ok = alive and pcall(callback)
		if not ok then
			table.remove(self.RepaintHooks, i)
			self.RepaintHookOwners[callback] = nil
		end
	end
end

function Library:Register(flag, entry)
	if self.Registry[flag] then
		warn("layer.app | duplicate flag '" .. tostring(flag) .. "', the previous element will no longer be saved")
	end
	self.Registry[flag] = entry
	self.Defaults[flag] = entry.Get()
end

local function CloneConfigValue(value, seen)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}
	if seen[value] then
		return seen[value]
	end

	local copy = {}
	seen[value] = copy
	for key, child in value do
		copy[CloneConfigValue(key, seen)] = CloneConfigValue(child, seen)
	end
	return copy
end

local function ConfigValuesEqual(a, b, seen)
	if a == b then
		return true
	end
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return false
	end

	seen = seen or {}
	seen[a] = seen[a] or {}
	if seen[a][b] then
		return true
	end
	seen[a][b] = true

	for key, value in a do
		if not ConfigValuesEqual(value, b[key], seen) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function Library:SetDirtyState(state)
	state = state == true
	if self.Dirty == state then
		return state
	end

	self.Dirty = state
	if self.OnDirty then
		task.spawn(self.OnDirty, state)
	end
	return state
end

function Library:CaptureDirtyBaseline()
	self.DirtyBaseline = CloneConfigValue(self:GetConfig())
	return self.DirtyBaseline
end

function Library:RefreshDirty()
	if self.LoadingConfig then
		return self.Dirty
	end

	if not self.DirtyBaseline then
		return self.Dirty
	end

	local current = self:GetConfig()
	return self:SetDirtyState(not ConfigValuesEqual(current, self.DirtyBaseline))
end

function Library:MarkDirty(flag)
	if self.LoadingConfig then
		return
	end
	if flag and self.DirtyIgnore and self.DirtyIgnore[flag] then
		return
	end

	self:SetDirtyState(true)

	if not self.DirtyBaseline then
		return true
	end

	self.DirtyRefreshDeadline = os.clock() + 0.14
	if self.DirtyRefreshWorker then
		return true
	end

	self.DirtyRefreshWorker = true
	task.spawn(function()
		while self.DirtyRefreshDeadline do
			local remaining = self.DirtyRefreshDeadline - os.clock()
			if remaining <= 0 then
				break
			end
			task.wait(remaining)
		end

		self.DirtyRefreshDeadline = nil
		self.DirtyRefreshWorker = false

		if self.DirtyBaseline and not self.LoadingConfig then
			self:RefreshDirty()
		end
	end)

	return true
end

function Library:ClearDirty()
	self:CaptureDirtyBaseline()
	return self:SetDirtyState(false)
end

function Library:GetConfig(ignore)
	local data = {}
	for flag, entry in self.Registry do
		local reserved = type(flag) == "string" and string.sub(flag, 1, #"__layer_") == "__layer_"
		if reserved or not (ignore and ignore[flag]) then
			local ok, value = pcall(entry.Get)
			if ok then
				data[flag] = value
			end
		end
	end
	return data
end

function Library:LoadConfig(data, ignore)
	data = data or {}
	self.LoadingConfig = true

	for flag, value in data do
		if flag ~= "__layer_theme" then
			local entry = self.Registry[flag]
			local reserved = type(flag) == "string" and string.sub(flag, 1, #"__layer_") == "__layer_"
			if entry and (reserved or not (ignore and ignore[flag])) then
				pcall(entry.Set, value)
			end
		end
	end

	local themeValue = data.__layer_theme
	local themeEntry = self.Registry.__layer_theme
	if themeEntry and themeValue ~= nil then
		pcall(themeEntry.Set, themeValue)
	end

	self.LoadingConfig = false
	self:RefreshHotkeys()
	self:ClearDirty()
end

function Library:CaptureDefaults()
	for flag, entry in self.Registry do
		local ok, value = pcall(entry.Get)
		if ok then
			if flag ~= "__layer_theme" or self.Defaults[flag] == nil then
				self.Defaults[flag] = value
			end
		end
	end
end

function Library:ResetDefaults(ignore)
	self:LoadConfig(self.Defaults, ignore)
end

local TrackAdds = 0
local function Track(conn)
	if not conn then
		return conn
	end
	table.insert(Library.Connections, conn)
	TrackAdds = TrackAdds + 1

	if TrackAdds >= 128 then
		TrackAdds = 0
		local alive = {}
		for _, current in Library.Connections do
			local ok, connected = pcall(function()
				return current.Connected
			end)
			if ok and connected then
				table.insert(alive, current)
			end
		end
		Library.Connections = alive
	end

	return conn
end

local function SetUIScalePreservePosition(scaleObject, targetScale)
	targetScale = math.max(tonumber(targetScale) or 1, 0.0001)
	if scaleObject then
		scaleObject.Scale = targetScale
	end
	return targetScale
end

Library.StandaloneScales = Library.StandaloneScales or {}

function Library:GetInterfaceScale()
	 
	local fallback = tonumber(self.InterfaceUserScale) or 1
	for i = #self.Windows, 1, -1 do
		local window = self.Windows[i]
		local scale = window and tonumber(window.BaseScale)
		if scale and scale > 0 and scale < math.huge then
			fallback = scale
			if window.Visible then
				return scale
			end
		end
	end
	return fallback
end

function Library:RefreshStandaloneScales()
	local scale = self:GetInterfaceScale()
	for i = #self.StandaloneScales, 1, -1 do
		local entry = self.StandaloneScales[i]
		local object = entry and entry.Object
		if not object then
			table.remove(self.StandaloneScales, i)
		else

			local ok, alive = pcall(function()
				if not object.Parent then return false end
				local target = scale * (entry.Multiplier or 1)
				local changed = entry.Target == nil and math.abs(object.Scale - target) > 0.0001
					or entry.Target ~= nil and math.abs(entry.Target - target) > 0.0001
				if entry.Target == nil or changed then
					if entry.Target ~= nil then
						 
						local motion = TweenService:Create(object, TweenInfo.new(0), { Scale = target })
						motion:Play()
					else
						SetUIScalePreservePosition(object, target)
					end
					entry.Target = target
					if changed and entry.OnChanged then entry.OnChanged(target) end
				end
				return true
			end)
			if ok and not alive then
				table.remove(self.StandaloneScales, i)
			end
		end
	end
	return scale
end

function Library:RegisterStandaloneScale(object, multiplier, preservePosition, onChanged)
	if not object then
		return nil
	end
	table.insert(self.StandaloneScales, {
		Object = object,
		Multiplier = multiplier or 1,
		PreservePosition = preservePosition ~= false,
		OnChanged = onChanged,
	})
	self:RefreshStandaloneScales()
	return object
end

local ScrollHintRegions = setmetatable({}, { __mode = "k" })
local AttachScrollHint
local function New(class, props, children)
	local inst = Instance.new(class)
	local parent = nil
	local tag = nil
	local scrollHint = true

	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		elseif k == "ThemeTag" then
			tag = v
		elseif k == "ScrollHint" then
			scrollHint = v
		else
			inst[k] = v

			if typeof(v) == "Color3" then
				local key = ThemeIndex[tostring(v)]
				if key then
					TagInstance(inst, { [k] = key })
				end
			end
		end
	end

	if tag then
		TagInstance(inst, tag)
	end

	if class == "ScreenGui" then
		pcall(function()
			inst.IgnoreGuiInset = true
			inst.ScreenInsets = Enum.ScreenInsets.None
			inst.ClipToDeviceSafeArea = false
		end)
	end

	if Library.FontFace and (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) then
		local requested = props and props.Font
		local face = Library.FontFace
		if requested == Theme.FontBold then
			face = Library.FontBoldFace or face
		elseif requested == Theme.FontMedium then
			face = Library.FontMediumFace or face
		elseif requested == Theme.Font then
			face = Library.FontRegularFace or face
		end
		pcall(function()
			inst.FontFace = face
		end)
	end

	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	if class == "ScrollingFrame" then
		inst.ScrollBarThickness = 0
		inst.VerticalScrollBarInset = Enum.ScrollBarInset.None
		inst.HorizontalScrollBarInset = Enum.ScrollBarInset.None
		if AttachScrollHint and scrollHint ~= false then
			AttachScrollHint(inst, type(scrollHint) == "table" and scrollHint or nil)
		end
	end
	return inst
end

local function Corner(parent, r)
	return New("UICorner", { CornerRadius = UDim.new(0, r or Theme.Radius), Parent = parent })
end

local function Shadow(parent, color, transparency, blur, spread, offset, zIndex)
	local ok, shadow = pcall(function()
		return New("UIShadow", {
			Color = color or Color3.new(0, 0, 0),
			Transparency = transparency == nil and 0.5 or transparency,
			BlurRadius = UDim.new(0, blur or 12),
			Spread = spread or UDim2.fromOffset(0, 0),
			Offset = offset or UDim2.fromOffset(0, 0),
			ZIndex = zIndex or 0,
			Parent = parent,
		})
	end)
	if ok then
		return shadow
	end
	return nil
end

local function Stroke(parent, color, thickness, transparency)
	return New("UIStroke", {
		Color = color or Theme.Border,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function Pad(parent, t, r, b, l)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or t or 0),
		PaddingBottom = UDim.new(0, b or t or 0),
		PaddingLeft = UDim.new(0, l or r or t or 0),
		Parent = parent,
	})
end

local function List(parent, padding, dir, sort)
	return New("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 0),
		SortOrder = sort or Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function Label(parent, text, color, size, font)
	return New("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or Theme.Text,
		TextSize = size or Theme.TextSize,
		Font = font or Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = true,
		Parent = parent,
	})
end

local Visuals, Fades = {}, {}
local HoverResets = setmetatable({}, { __mode = "k" })
local InlineDropdowns = setmetatable({}, { __mode = "k" })
local function CloseInlineDropdowns(root)
	for shell, dropdown in InlineDropdowns do
		if dropdown.Open and (shell == root or shell:IsDescendantOf(root)) then
			dropdown:SetOpen(false, true)
		end
	end
end
local TRANSPARENCIES = {
	BackgroundTransparency = true,
	TextTransparency = true,
	TextStrokeTransparency = true,
	ImageTransparency = true,
	ScrollBarImageTransparency = true,
	Transparency = true,
}

local function AnimationInfo(kind, _closing)
	local settings = Library.Animations
	local duration = settings.Enabled == false and 0 or math.max(tonumber(settings[kind]) or 0.14, 0)
	return TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local function SameVisualValue(property, current, expected)
	if TRANSPARENCIES[property] then
		 
		return math.abs(current - expected) <= 0.000001
	end
	return current == expected
end

local function CaptureVisual(node)
	if node.Dead or node.Writing then
		return
	end
	for property, value in node.Properties do
		local current = node.Instance[property]
		if not SameVisualValue(property, current, value.Last) then
			value.Base, value.Last = current, current
			if value.Tween then
				value.Tween:Cancel()
				value.Tween = nil
			end
			if value.Driver then
				value.Driver.Value = current
			end
		end
	end
end

local function PaintVisual(node, skipCapture)
	if node.Dead or node.Writing then
		return
	end
	if not skipCapture then
		CaptureVisual(node)
	end
	local opacity, interactive = 1, true
	for fade in node.Fades do
		opacity = opacity * (1 - fade.Value.Value)
		if not fade.Show then
			interactive = false
		end
	end
	node.Writing = true
	for property, value in node.Properties do
		local rendered
		if TRANSPARENCIES[property] then
			rendered = 1 - (1 - value.Base) * opacity
		else
			rendered = interactive and value.Base or false
		end
		 
		value.Last = rendered
		if node.Instance[property] ~= rendered then
			node.Instance[property] = rendered
		end
		 
		value.Last = node.Instance[property]
	end
	node.Writing = false
end

local function ForgetVisual(node)
	if node.Dead then
		return
	end
	node.Dead = true
	Visuals[node.Instance] = nil
	for fade in node.Fades do
		fade.Nodes[node] = nil
	end
	for _, connection in node.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	local properties = {
		"BackgroundTransparency",
		"TextTransparency",
		"TextStrokeTransparency",
		"ImageTransparency",
		"Interactable",
		"TextEditable",
		"ScrollBarImageTransparency",
		"ScrollingEnabled",
		"Transparency",
	}
	for _, property in properties do
		local value = node.Properties[property]
		if value then
			if value.Tween then
				pcall(function()
					value.Tween:Cancel()
				end)
			end
			if value.Driver then
				pcall(function()
					value.Driver:Destroy()
				end)
			end
		end
	end
	table.clear(node.Fades)
end

local function Visual(inst)
	if Visuals[inst] then
		return Visuals[inst]
	end
	local properties = {}
	if inst:IsA("GuiObject") then
		table.insert(properties, "BackgroundTransparency")
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			table.insert(properties, "TextTransparency")
			table.insert(properties, "TextStrokeTransparency")
		end
		if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
			table.insert(properties, "ImageTransparency")
		end
		if inst:IsA("GuiButton") then
			table.insert(properties, "Interactable")
		end
		if inst:IsA("TextBox") then
			table.insert(properties, "TextEditable")
		end
		if inst:IsA("ScrollingFrame") then
			table.insert(properties, "ScrollBarImageTransparency")
			table.insert(properties, "ScrollingEnabled")
		end
	elseif inst:IsA("UIStroke") or inst.ClassName == "UIShadow" then
		table.insert(properties, "Transparency")
	end
	if #properties == 0 then
		return nil
	end
	local node = { Instance = inst, Properties = {}, Fades = {}, Connections = {} }
	Visuals[inst] = node
	for _, property in properties do
		local value = { Base = inst[property], Last = inst[property] }
		node.Properties[property] = value
		table.insert(
			node.Connections,
			inst:GetPropertyChangedSignal(property):Connect(function()
				if node.Dead or node.Writing or SameVisualValue(property, inst[property], value.Last) then
					return
				end
				PaintVisual(node)
			end)
		)
	end
	table.insert(
		node.Connections,
		inst.Destroying:Connect(function()
			ForgetVisual(node)
		end)
	)
	return node
end

GetVisualValue = function(inst, property)
	local node = Visuals[inst]
	if node then
		PaintVisual(node)
	end
	local value = node and node.Properties[property]
	if value then
		return value.Base
	end
	return inst[property]
end

SetVisual = function(inst, property, base)
	local node = Visuals[inst]
	local value = node and node.Properties[property]
	if not value then
		inst[property] = base
		return
	end
	CaptureVisual(node)
	if value.Tween then
		value.Tween:Cancel()
		value.Tween = nil
	end
	value.Base = base
	if value.Driver then
		value.Driver.Value = base
	end
	PaintVisual(node)
end

local function Tween(inst, goal, info)
	info = info or EASE
	local ordinary, tweens = {}, {}
	for property, target in goal do
		local node = TRANSPARENCIES[property] and Visual(inst)
		local value = node and node.Properties[property]
		if value then
			CaptureVisual(node)
			if value.Tween then
				value.Tween:Cancel()
			end
			if not value.Driver then
				value.Driver = Instance.new("NumberValue")
				table.insert(
					node.Connections,
					value.Driver.Changed:Connect(function()
						if node.Dead then
							return
						end
						value.Base = value.Driver.Value
						PaintVisual(node)
					end)
				)
			end
			value.Driver.Value = value.Base
			local tween = TweenService:Create(value.Driver, info, { Value = target })
			value.Tween = tween
			tween.Completed:Once(function()
				if value.Tween == tween then
					value.Tween = nil
				end
			end)
			table.insert(tweens, tween)
		else
			ordinary[property] = target
		end
	end
	if FirstTableKey(ordinary) then
		table.insert(tweens, TweenService:Create(inst, info, ordinary))
	end
	for _, tween in tweens do
		pcall(function()
			tween:Play()
		end)
	end
	return tweens[#tweens]
end

local function TweenTheme(inst, property, key, info)
	local current = inst[property]
	TagInstance(inst, { [property] = key })
	inst[property] = current
	return Tween(inst, { [property] = Theme[key] }, info)
end

local function ReleaseFade(fade)
	if fade.Dead then
		return
	end
	fade.Dead = true
	if Fades[fade.Root] == fade then
		Fades[fade.Root] = nil
	end
	if fade.Completion then
		fade.Completion:Disconnect()
	end
	if fade.Tween then
		fade.Tween:Cancel()
	end

	for _, connection in fade.Connections do
		connection:Disconnect()
	end
	for node in fade.Nodes do
		node.Fades[fade] = nil
		PaintVisual(node)
	end
	table.clear(fade.Nodes)
	fade.Value:Destroy()
end

local function Fade(root, show, info, onComplete)
	show = show ~= false
	if not show then
		CloseInlineDropdowns(root)
		for button, reset in HoverResets do
			if button == root or button:IsDescendantOf(root) then
				reset()
			end
		end
	end

	local fade = Fades[root]
	if fade then
		 
		fade.Ticket = fade.Ticket + 1
		if fade.Completion then
			fade.Completion:Disconnect()
			fade.Completion = nil
		end
		if fade.Tween then
			fade.Tween:Cancel()
			fade.Tween = nil
		end
	else
		local value = Instance.new("NumberValue")
		value.Value = root.Visible and 0 or 1
		fade = {
			Root = root,
			Value = value,
			Nodes = {},
			Connections = {},
			Ticket = 0,
			Persistent = true,
			LastPaint = 0,
		}
		Fades[root] = fade

		local function add(inst)
			local node = Visual(inst)
			if not node or fade.Nodes[node] then
				return
			end
			fade.Nodes[node] = true
			node.Fades[fade] = true
			PaintVisual(node)
		end

		local function remove(inst)
			local node = Visuals[inst]
			if not node or not fade.Nodes[node] then
				return
			end
			fade.Nodes[node] = nil
			node.Fades[fade] = nil
			PaintVisual(node)
		end

		add(root)
		for _, inst in root:GetDescendants() do
			add(inst)
		end

		table.insert(fade.Connections, root.DescendantAdded:Connect(add))
		table.insert(fade.Connections, root.DescendantRemoving:Connect(remove))
		table.insert(
			fade.Connections,
			value.Changed:Connect(function()
				if fade.Dead then
					return
				end
				local now = os.clock()
				if now - fade.LastPaint < (1 / 30) then
					return
				end
				fade.LastPaint = now
				for node in fade.Nodes do
					PaintVisual(node, true)
				end
			end)
		)
		table.insert(
			fade.Connections,
			root.Destroying:Connect(function()
				ReleaseFade(fade)
			end)
		)
	end

	fade.Ticket = fade.Ticket + 1
	local ticket = fade.Ticket
	fade.Show = show
	fade.LastPaint = 0

	for node in fade.Nodes do
		PaintVisual(node)
	end

	if show then
		root.Visible = true
	end
	if not show then
		local focused
		local getFocusedTextBox = UserInputService.GetFocusedTextBox
		if type(getFocusedTextBox) == "function" then
			local ok, result = pcall(getFocusedTextBox, UserInputService)
			if ok then
				focused = result
			end
		end
		if focused and (focused == root or focused:IsDescendantOf(root)) then
			focused:ReleaseFocus()
		end
	end

	local function finish()
		if fade.Dead or fade.Ticket ~= ticket then
			return
		end
		root.Visible = show
		fade.Value.Value = show and 0 or 1

		for node in fade.Nodes do
			PaintVisual(node, true)
		end
		if fade.Completion then
			fade.Completion:Disconnect()
			fade.Completion = nil
		end
		fade.Tween = nil
		if onComplete then
			onComplete()
		end
	end

	info = info or AnimationInfo("Popup", not show)
	if info.Time == 0 or (not show and not root.Visible) then
		finish()
		return
	end

	local tween = TweenService:Create(fade.Value, info, { Value = show and 0 or 1 })
	fade.Tween = tween
	fade.Completion = tween.Completed:Connect(function(status)
		if status == Enum.PlaybackState.Completed and fade.Tween == tween then
			finish()
		end
	end)
	tween:Play()
end

local SoftGroups = {}

local function EnsureSoftGroup(root)
	local state = SoftGroups[root]
	if state then
		return state
	end

	local value = Instance.new("NumberValue")
	value.Value = 0

	state = {
		Root = root,
		Value = value,
		Nodes = {},
		Connections = {},
		Show = true,
		Tween = nil,
	}
	SoftGroups[root] = state

	local function add(inst)
		local node = Visual(inst)
		if not node or state.Nodes[node] then
			return
		end
		state.Nodes[node] = true
		node.Fades[state] = true
		PaintVisual(node)
	end

	local function remove(inst)
		local node = Visuals[inst]
		if not node or not state.Nodes[node] then
			return
		end
		state.Nodes[node] = nil
		node.Fades[state] = nil
		PaintVisual(node)
	end

	add(root)
	for _, inst in root:GetDescendants() do
		add(inst)
	end

	table.insert(state.Connections, root.DescendantAdded:Connect(add))
	table.insert(state.Connections, root.DescendantRemoving:Connect(remove))
	table.insert(
		state.Connections,
		value.Changed:Connect(function()
			for node in state.Nodes do
				PaintVisual(node, true)
			end
		end)
	)
	table.insert(
		state.Connections,
		root.Destroying:Connect(function()
			if state.Tween then
				state.Tween:Cancel()
			end
			for _, connection in state.Connections do
				connection:Disconnect()
			end
			for node in state.Nodes do
				node.Fades[state] = nil
				PaintVisual(node)
			end
			SoftGroups[root] = nil
			value:Destroy()
		end)
	)

	return state
end

local NativeGroupTweens = setmetatable({}, { __mode = "k" })
local function CancelNativeGroupTween(root)
	local tween = NativeGroupTweens[root]
	NativeGroupTweens[root] = nil
	if tween then
		tween:Cancel()
	end
end

local function SetGroupTransparency(root, transparency)
	transparency = math.clamp(transparency or 0, 0, 1)

	if root:IsA("CanvasGroup") then
		CancelNativeGroupTween(root)
		root.GroupTransparency = transparency
		return
	end

	local state = EnsureSoftGroup(root)
	if state.Tween then
		state.Tween:Cancel()
		state.Tween = nil
	end

	state.Show = transparency < 0.999
	state.Value.Value = transparency

	for node in state.Nodes do
		PaintVisual(node, true)
	end
end

local function TweenGroupTransparency(root, transparency, info, onComplete)
	transparency = math.clamp(transparency or 0, 0, 1)

	if root:IsA("CanvasGroup") then
		CancelNativeGroupTween(root)
		local tween = TweenService:Create(root, info or EASE, { GroupTransparency = transparency })
		NativeGroupTweens[root] = tween
		tween.Completed:Once(function(status)
			if NativeGroupTweens[root] ~= tween then
				return
			end
			NativeGroupTweens[root] = nil
			if status == Enum.PlaybackState.Completed and onComplete then
				onComplete()
			end
		end)
		tween:Play()
		return tween
	end

	local state = EnsureSoftGroup(root)
	if state.Tween then
		state.Tween:Cancel()
		state.Tween = nil
	end

	if transparency < 0.999 then
		state.Show = true
	end

	local tween = TweenService:Create(state.Value, info or EASE, { Value = transparency })
	state.Tween = tween

	tween.Completed:Connect(function(status)
		if state.Tween ~= tween then
			return
		end

		state.Tween = nil
		if status == Enum.PlaybackState.Completed then
			state.Show = transparency < 0.999
			for node in state.Nodes do
				PaintVisual(node, true)
			end
			if onComplete then
				onComplete()
			end
		end
	end)

	tween:Play()
	return tween
end

local function ScrollHintDirection(canvas, window, position, enabled, direction)
	if not enabled then return nil end
	if direction ~= Enum.ScrollingDirection.X and canvas.Y - window.Y - position.Y > 1 then return "down" end
	if direction ~= Enum.ScrollingDirection.Y and canvas.X - window.X - position.X > 1 then return "right" end
	return nil
end

local function ShadowLightness()
	local color = Theme.Window
	local luminance = color.R * 0.2126 + color.G * 0.7152 + color.B * 0.0722
	return math.clamp((luminance - 0.35) / 0.4, 0, 1)
end

AttachScrollHint = function(scroller, opts)
	opts = opts or {}
	local folder = New("Folder", { Name = "LayerScrollHint", Parent = scroller.Parent })
	local overlay = New("CanvasGroup", {
		Name = "ScrollHint", BackgroundTransparency = 1, BorderSizePixel = 0,
		ClipsDescendants = true, Visible = false, Active = false, Parent = folder,
	})
	local overlayCorner = Corner(overlay, 0)
	 
	local edge = New("Frame", {
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = overlay,
	})
	local shadow = Shadow(edge, Color3.new(0, 0, 0), 0.48, 36, UDim2.fromOffset(0, 12), UDim2.fromOffset(0, -16), -1)
	ScrollHintRegions[scroller] = { Overlay = overlay, Edge = edge, Shadow = shadow }
	local shade = New("Frame", {
			Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = overlay,
			ThemeTag = { BackgroundColor3 = false },
		})
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.93),
			NumberSequenceKeypoint.new(0.75, 0.78),
			NumberSequenceKeypoint.new(1, 0.48),
		}), Parent = shade })

	local function repaintShadow()
		local light = ShadowLightness()
		SetVisual(shade, "BackgroundTransparency", light * 0.68)
		if shadow then SetVisual(shadow, "Transparency", 0.48 + light * 0.38) end
	end
	Library:OnRepaint(repaintShadow, overlay)
	repaintShadow()
	local arrow = New("TextButton", {
		Text = "", AutoButtonColor = false, Active = true,
		Size = UDim2.fromOffset(14, 8), Position = UDim2.new(0.5, 0, 1, -9),
		AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = overlay,
	})
	local bars, pixels = {}, {}
	if opts.PixelChevron then
		for y = 0, 5 do
			for side = 1, y == 5 and 1 or 2 do
				local x = side == 1 and y - 5 or 5 - y
				local pixel = New("Frame", {
					Size = UDim2.fromOffset(1, 1), BackgroundColor3 = Theme.TextDim, BorderSizePixel = 0,
					Parent = arrow, ThemeTag = { BackgroundColor3 = "TextDim" },
				})
				bars[#bars + 1] = pixel
				pixels[#pixels + 1] = { Frame = pixel, X = x, Y = y }
			end
		end
	else
		for i = 1, 2 do
			local bar = New("Frame", {
				Size = UDim2.fromOffset(8, opts.StrokeThickness or 1.5), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(i == 1 and 4.1 or 9.7, 3.5), Rotation = i == 1 and 45 or -45,
				BackgroundColor3 = Theme.TextDim, BorderSizePixel = 0, Parent = arrow,
				ThemeTag = { BackgroundColor3 = "TextDim" },
			})
			Corner(bar, 1)
			bars[i] = bar
		end
	end
	local function alignPixels()
		if not opts.PixelChevron then return end
		local scale = arrow.AbsoluteSize.X / 14
		if scale <= 0 then return end
		local step = math.max(1, math.floor(scale + 0.5))
		local centerX = math.floor(arrow.AbsolutePosition.X + arrow.AbsoluteSize.X * 0.5 + 0.5)
		local topY = math.floor(arrow.AbsolutePosition.Y + 0.5)
		local size = UDim2.fromOffset(step / scale, step / scale)
		for _, pixel in pixels do
			local position = UDim2.fromOffset((centerX + pixel.X * step - arrow.AbsolutePosition.X) / scale,
				(topY + pixel.Y * step - arrow.AbsolutePosition.Y) / scale)
			if pixel.Frame.Size ~= size then pixel.Frame.Size = size end
			if pixel.Frame.Position ~= position then pixel.Frame.Position = position end
		end
	end
	local connections, dead, shown = {}, false, false
	local function refresh()
		if dead then return end
		folder.Parent = scroller.Parent
		local direction = ScrollHintDirection(scroller.AbsoluteCanvasSize, scroller.AbsoluteWindowSize,
			scroller.CanvasPosition, scroller.ScrollingEnabled, scroller.ScrollingDirection)
		local visible = scroller.Visible and scroller.Parent ~= nil and direction ~= nil
		if shown ~= visible then
			shown = visible
			Fade(overlay, visible, TweenInfo.new(visible and 0.18 or 0.14,
				Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		end
		if not overlay.Visible then return end
		local bottomScale = scroller.Position.Y.Scale + scroller.Size.Y.Scale * (1 - scroller.AnchorPoint.Y)
		local bottomOffset = scroller.Position.Y.Offset + scroller.Size.Y.Offset * (1 - scroller.AnchorPoint.Y)
		local parent = scroller.Parent
		local fullWidth = scroller.ScrollingDirection ~= Enum.ScrollingDirection.X
			and parent and parent:IsA("GuiObject") and parent.AbsoluteSize.X > 0
			and scroller.AbsoluteSize.X >= parent.AbsoluteSize.X * 0.7
		if fullWidth then
			local gap = parent.AbsolutePosition.Y + parent.AbsoluteSize.Y - scroller.AbsolutePosition.Y - scroller.AbsoluteSize.Y
			if math.abs(gap) <= 14 * Library:GetInterfaceScale() + 0.5 then bottomScale, bottomOffset = 1, 0 end
		end
		local flushBottom = fullWidth and bottomScale == 1 and bottomOffset == 0
		 
		if not fullWidth then
			overlay.Size = UDim2.new(scroller.Size.X.Scale, scroller.Size.X.Offset, 0, 96)
			overlay.Position = UDim2.new(scroller.Position.X.Scale, scroller.Position.X.Offset, bottomScale, bottomOffset)
			overlay.AnchorPoint = Vector2.new(scroller.AnchorPoint.X, 1)
		else
			overlay.Size = UDim2.new(1, -2, 0, 96)
			overlay.Position = UDim2.new(0, 1, bottomScale, bottomOffset - (flushBottom and 1 or 0))
			overlay.AnchorPoint = Vector2.new(0, 1)
		end

		local radius = 0
		if fullWidth then
			local corner = parent:FindFirstChildOfClass("UICorner")
			if corner then
				radius = math.max(0, corner.CornerRadius.Offset - 1)
				local scale = overlay.AbsoluteSize.Y / 96
				if scale > 0 and corner.CornerRadius.Scale ~= 0 then
					radius = radius + corner.CornerRadius.Scale
						* math.min(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) / scale
				end
			end
		end
		overlayCorner.CornerRadius = UDim.new(0, math.clamp(radius, 0, 49))
		overlay.Rotation = scroller.Rotation
		local zIndex = scroller.ZIndex + 1
		overlay.ZIndex, edge.ZIndex, arrow.ZIndex = zIndex, zIndex, zIndex + 1
		if shade then shade.ZIndex = zIndex end
		for _, bar in bars do bar.ZIndex = zIndex + 1 end
		arrow.Rotation = direction == "right" and -90 or 0
		alignPixels()
	end
	if opts.PixelChevron then
		connections[#connections + 1] = arrow:GetPropertyChangedSignal("AbsolutePosition"):Connect(alignPixels)
		connections[#connections + 1] = arrow:GetPropertyChangedSignal("AbsoluteSize"):Connect(alignPixels)
	end
	for _, property in { "AbsoluteCanvasSize", "AbsoluteWindowSize", "CanvasPosition", "Visible",
		"Size", "Position", "AbsoluteSize", "AbsolutePosition", "AnchorPoint", "Rotation", "ZIndex", "Parent", "ScrollingEnabled", "ScrollingDirection" } do
		connections[#connections + 1] = scroller:GetPropertyChangedSignal(property):Connect(refresh)
	end
	scroller.Destroying:Once(function()
		dead = true
		ScrollHintRegions[scroller] = nil
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
		folder:Destroy()
	end)
	refresh()
end

local function PointInScrollRect(point, x, y, width, height)
	return point.X >= x and point.X <= x + width and point.Y >= y and point.Y <= y + height
end

local function IsPointInScrollHint(frame, point)
	for scroller, region in ScrollHintRegions do
		local overlay = region.Overlay
		if scroller.Parent and overlay.Visible and (scroller == frame or scroller:IsDescendantOf(frame)) then
			local position, size = overlay.AbsolutePosition, overlay.AbsoluteSize
			if PointInScrollRect(point, position.X, position.Y, size.X, size.Y) then return true end
			local shadow = region.Shadow
			if shadow then
				local edge = region.Edge
				local edgePosition, edgeSize = edge.AbsolutePosition, edge.AbsoluteSize
				local scale = size.Y / math.max(overlay.Size.Y.Offset, 1)
				local blur = shadow.BlurRadius.Scale * math.min(edgeSize.X, edgeSize.Y) + shadow.BlurRadius.Offset * scale
				local spreadX = shadow.Spread.X.Scale * edgeSize.X + shadow.Spread.X.Offset * scale
				local spreadY = shadow.Spread.Y.Scale * edgeSize.Y + shadow.Spread.Y.Offset * scale
				local offsetX = shadow.Offset.X.Scale * edgeSize.X + shadow.Offset.X.Offset * scale
				local offsetY = shadow.Offset.Y.Scale * edgeSize.Y + shadow.Offset.Y.Offset * scale
				if PointInScrollRect(point, edgePosition.X + offsetX - spreadX * 0.5 - blur,
					edgePosition.Y + offsetY - spreadY * 0.5 - blur,
					edgeSize.X + spreadX + blur * 2, edgeSize.Y + spreadY + blur * 2) then return true end
			end
		end
	end
	return false
end

local function IsInteractive(inst)
	while inst do
		if inst:IsA("GuiObject") and not inst.Visible then
			return false
		end
		if inst:IsA("ScreenGui") and not inst.Enabled then
			return false
		end
		local fade = Fades[inst]
		if fade and not fade.Show then
			return false
		end
		inst = inst.Parent
	end
	return true
end

local function ClearAnimations()
	for root in NativeGroupTweens do
		CancelNativeGroupTween(root)
	end
	local fades = {}
	for _, fade in Fades do
		table.insert(fades, fade)
	end
	for _, fade in fades do
		ReleaseFade(fade)
	end

	local visuals = {}
	for _, node in Visuals do
		table.insert(visuals, node)
	end
	for _, node in visuals do
		ForgetVisual(node)
	end
end

local function Chevron(parent, color)
	local holder = New("Frame", {
		Name = "Chevron",
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for i = 1, 2 do
		local bar = New("Frame", {
			Size = UDim2.fromOffset(7, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, i == 1 and -2 or 2, 0.5, 0),
			Rotation = i == 1 and 45 or -45,
			BackgroundColor3 = color or Theme.TextDim,
			BorderSizePixel = 0,
			Parent = holder,
		})
		Corner(bar, 1)
	end
	return holder
end

local CapturedBindingInputs = setmetatable({}, { __mode = "k" })
local function BindingInputBlocked(input)
	return Library.Binding or CapturedBindingInputs[input] == true
end
 
Track(UserInputService.InputBegan:Connect(function(input)
	if Library.Binding then
		CapturedBindingInputs[input] = true
	end
end))
Track(UserInputService.InputEnded:Connect(function(input)
	task.defer(function()
		CapturedBindingInputs[input] = nil
	end)
end))

local function KeyName(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		return "MB1"
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		return "MB2"
	end
	if input.UserInputType == Enum.UserInputType.MouseButton3 then
		return "MB3"
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		return input.KeyCode.Name
	end
	return nil
end

local EscapeCaptureSerial = 0
local function CaptureEscapeForKeybind(callback)
	EscapeCaptureSerial = EscapeCaptureSerial + 1

	local actionName = "LayerKeybindEscape_" .. tostring(EscapeCaptureSerial)
	local coreActionName = actionName .. "_Core"

	local active = true
	local consumed = false
	local inputConnection
	local menuConnection
	local coreBound = false
	local normalBound = false

	local function forceMenuClosed()
		pcall(function()
			if GuiService.MenuIsOpen then
				GuiService:SetMenuIsOpen(false)
			end
		end)
	end

	local function release()
		if not active then
			return
		end

		active = false

		if coreBound then
			pcall(function()
				ContextActionService:UnbindCoreAction(coreActionName)
			end)
			coreBound = false
		end

		if normalBound then
			pcall(function()
				ContextActionService:UnbindAction(actionName)
			end)
			normalBound = false
		end

		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end

		if menuConnection then
			menuConnection:Disconnect()
			menuConnection = nil
		end
	end

	local function consume()
		if not active or consumed then
			return
		end

		consumed = true
		forceMenuClosed()
		callback()
	end

	local function finishEscape()
		forceMenuClosed()

		task.defer(function()
			RunService.RenderStepped:Wait()
			forceMenuClosed()
			release()
		end)
	end

	local function escapeHandler(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			forceMenuClosed()
			consume()
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			finishEscape()
		end

		return Enum.ContextActionResult.Sink
	end

	local coreOk = pcall(function()
		ContextActionService:BindCoreActionAtPriority(
			coreActionName,
			escapeHandler,
			false,
			2147483647,
			Enum.KeyCode.Escape
		)
	end)

	if coreOk then
		coreBound = true
	else
		local normalOk = pcall(function()
			ContextActionService:BindActionAtPriority(actionName, escapeHandler, false, 2147483647, Enum.KeyCode.Escape)
		end)

		normalBound = normalOk
	end

	inputConnection = UserInputService.InputBegan:Connect(function(input)
		if active and input.KeyCode == Enum.KeyCode.Escape then
			forceMenuClosed()
			consume()
		end
	end)

	menuConnection = GuiService.MenuOpened:Connect(function()
		if active then
			forceMenuClosed()
		end
	end)

	return release
end

local function Hover(button, target, baseKey, hoverKey)
	local function pointerOverButton()
		if not button.Parent or not target.Parent or not IsInteractive(button) then
			return false
		end
		local pointer = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		local position = button.AbsolutePosition
		local size = button.AbsoluteSize
		local function contains(point)
			return point.X >= position.X
				and point.X <= position.X + size.X
				and point.Y >= position.Y
				and point.Y <= position.Y + size.Y
		end
		return contains(pointer) or contains(pointer - inset)
	end
	local function refreshHover(animate)
		if not button.Parent or not target.Parent then
			return
		end
		local interactive = button.Active
		pcall(function()
			interactive = interactive and button.Interactable
		end)
		local colorKey = pointerOverButton() and interactive and hoverKey or baseKey
		Library:Tag(target, { BackgroundColor3 = colorKey })
		if animate then
			Tween(target, { BackgroundColor3 = Theme[colorKey] }, EASE_FAST)
		else
			SetVisual(target, "BackgroundColor3", Theme[colorKey])
		end
	end

	HoverResets[button] = function()
		Library:Tag(target, { BackgroundColor3 = baseKey })
		SetVisual(target, "BackgroundColor3", Theme[baseKey])
	end
	Track(button.Destroying:Connect(function()
		HoverResets[button] = nil
	end))

	Track(button.MouseEnter:Connect(function()
		task.defer(function()
			refreshHover(true)
		end)
	end))
	Track(button.MouseLeave:Connect(function()
		task.defer(function()
			refreshHover(true)
		end)
	end))
	Track(button.Activated:Connect(function(input)
		if not input or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		task.defer(function()
			RunService.RenderStepped:Wait()
			refreshHover(true)
		end)
	end))
	Library:OnRepaint(function()
		refreshHover(false)
	end, button)
end

local function BindDrag(target, callback)
	local moveConn, endConn
	Track(target.InputBegan:Connect(function(input)
		if not IsInteractive(target) then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		callback(input.Position)
		if moveConn then
			moveConn:Disconnect()
		end
		moveConn = UserInputService.InputChanged:Connect(function(move)
			if
				move.UserInputType == Enum.UserInputType.MouseMovement
				or move.UserInputType == Enum.UserInputType.Touch
			then
				callback(move.Position)
			end
		end)
		if endConn then
			endConn:Disconnect()
		end
		endConn = UserInputService.InputEnded:Connect(function(ended)
			if ended.UserInputType == input.UserInputType then
				if moveConn then
					moveConn:Disconnect()
					moveConn = nil
				end
				if endConn then
					endConn:Disconnect()
					endConn = nil
				end
			end
		end)
	end))
end

Library.DraggableFrames = Library.DraggableFrames or {}

local LAYER_DRAG_MARGIN = 12

local function LerpUDim2(a, b, t)
	return UDim2.new(
		a.X.Scale + (b.X.Scale - a.X.Scale) * t,
		a.X.Offset + (b.X.Offset - a.X.Offset) * t,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
		a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
	)
end

local function BezierSample(a1, a2, t)
	local inv = 1 - t
	return 3 * inv * inv * t * a1 + 3 * inv * t * t * a2 + t * t * t
end

local function BezierSlope(a1, a2, t)
	local inv = 1 - t
	return 3 * inv * inv * a1 + 6 * inv * t * (a2 - a1) + 3 * t * t * (1 - a2)
end

local function CubicBezierEase(progress, x1, y1, x2, y2)
	progress = math.clamp(progress, 0, 1)
	x1, y1, x2, y2 = x1 or 0.22, y1 or 1, x2 or 0.36, y2 or 1

	local t = progress
	for _ = 1, 5 do
		local s = BezierSlope(x1, x2, t)
		if math.abs(s) < 0.0001 then
			break
		end
		t = math.clamp(t - (BezierSample(x1, x2, t) - progress) / s, 0, 1)
	end

	local low, high = 0, 1
	for _ = 1, 7 do
		local x = BezierSample(x1, x2, t)
		if math.abs(x - progress) < 0.0001 then
			break
		end
		if x < progress then
			low = t
		else
			high = t
		end
		t = (low + high) * 0.5
	end
	return BezierSample(y1, y2, t)
end

local function LerpTweenValue(a, b, t)
	local kind = typeof(a)
	if kind == "number" then
		return a + (b - a) * t
	elseif kind == "UDim2" then
		return LerpUDim2(a, b, t)
	elseif kind == "Vector2" then
		return a:Lerp(b, t)
	elseif kind == "Color3" then
		return a:Lerp(b, t)
	end
	return t >= 1 and b or a
end

local ActiveBezierTweens = {}
local BezierRenderConnection
local BezierActiveCount = 0

local function StopBezierSchedulerIfIdle()
	if BezierActiveCount <= 0 then
		BezierActiveCount = 0
		if BezierRenderConnection then
			BezierRenderConnection:Disconnect()
			BezierRenderConnection = nil
		end
	end
end

local function RemoveBezierController(controller)
	if not controller or not ActiveBezierTweens[controller] then
		return false
	end
	ActiveBezierTweens[controller] = nil
	BezierActiveCount = BezierActiveCount - 1
	return true
end

local function EnsureBezierScheduler()
	if BezierRenderConnection then
		return
	end
	BezierRenderConnection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local completed

		for controller in ActiveBezierTweens do
			local instance = controller.Instance
			if controller.Cancelled or not instance or not instance.Parent then
				RemoveBezierController(controller)
			else
				local raw = math.clamp((now - controller.Started) / controller.Duration, 0, 1)
				local curve = controller.Curve
				local eased = CubicBezierEase(raw, curve[1], curve[2], curve[3], curve[4])
				for property, target in controller.Goals do
					instance[property] = LerpTweenValue(controller.Starts[property], target, eased)
				end
				if raw >= 1 then
					RemoveBezierController(controller)
					completed = completed or {}
					table.insert(completed, controller)
				end
			end
		end

		if completed then
			for _, controller in completed do
				if not controller.Cancelled and controller.OnComplete then
					controller.OnComplete()
				end
			end
		end

		StopBezierSchedulerIfIdle()
	end)
end

local function BezierTween(instance, goals, duration, curve, onComplete)
	duration = math.max(tonumber(duration) or 0, 0)
	curve = curve or { 0.22, 1, 0.36, 1 }
	local starts = {}
	for property in goals do
		starts[property] = instance[property]
	end

	local controller = {
		Instance = instance,
		Goals = goals,
		Starts = starts,
		Duration = duration,
		Curve = curve,
		OnComplete = onComplete,
		Started = os.clock(),
		Cancelled = false,
	}

	function controller:Cancel()
		if self.Cancelled then
			return
		end
		self.Cancelled = true
		RemoveBezierController(self)
		StopBezierSchedulerIfIdle()
	end

	if duration <= 0 then
		for property, target in goals do
			instance[property] = target
		end
		if onComplete then
			onComplete()
		end
		return controller
	end

	ActiveBezierTweens[controller] = true
	BezierActiveCount = BezierActiveCount + 1
	EnsureBezierScheduler()
	return controller
end

local function RegisterDraggableFrame(frame)
	local entry = { Frame = frame, LayerOwned = true }
	pcall(function()
		frame:SetAttribute("LayerOwnedDraggable", true)
	end)
	table.insert(Library.DraggableFrames, entry)
	frame.Destroying:Once(function()
		for i = #Library.DraggableFrames, 1, -1 do
			if Library.DraggableFrames[i] == entry then
				table.remove(Library.DraggableFrames, i)
				break
			end
		end
	end)
	return entry
end

local function GetDragViewportSize()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

local function GetDragSafeInsets()
	return Vector2.new(0, 0), Vector2.new(0, 0)
end

local function GetFrameOffsetScale(frame)
	local scale = 1
	local current = frame and frame.Parent
	while current and not current:IsA("ScreenGui") do
		if current:IsA("GuiObject") then
			for _, child in current:GetChildren() do
				if child:IsA("UIScale") then
					scale = scale * child.Scale
				end
			end
		end
		current = current.Parent
	end
	return math.max(math.abs(scale), 0.0001)
end

local function GetFrameRenderScale(frame)
	local scale = GetFrameOffsetScale(frame)
	if frame and frame:IsA("GuiObject") then
		for _, child in frame:GetChildren() do
			if child:IsA("UIScale") then
				scale = scale * child.Scale
			end
		end
	end
	return math.max(math.abs(scale), 0.0001)
end

local function ScreenPixelsToOffsets(frame, pixels, knownPositionScale)
	local scale = knownPositionScale or GetFrameOffsetScale(frame)
	return pixels / math.max(math.abs(scale), 0.0001)
end

local function GetRenderedOffsetSize(frame, knownRenderScale)
	if frame and frame:IsA("GuiObject") then
		local absolute = frame.AbsoluteSize
		if absolute.X > 0 and absolute.Y > 0 then
			return absolute
		end

		if frame.Size.X.Scale == 0 and frame.Size.Y.Scale == 0 then
			local scale = knownRenderScale or GetFrameRenderScale(frame)
			return Vector2.new(math.abs(frame.Size.X.Offset) * scale, math.abs(frame.Size.Y.Offset) * scale)
		end
	end
	return Vector2.new(0, 0)
end

local function GetFrameViewportRect(_frame)
	local insetTopLeft = Vector2.new(0, 0)
	pcall(function()
		local topLeft = GuiService:GetGuiInset()
		if typeof(topLeft) == "Vector2" then
			insetTopLeft = topLeft
		end
	end)
	return -insetTopLeft, GetDragViewportSize()
end

local function ClampRectToViewport(pos, size, margin, viewport, viewportOrigin)
	margin = margin or LAYER_DRAG_MARGIN
	viewport = viewport or GetDragViewportSize()
	viewportOrigin = viewportOrigin or Vector2.new(0, 0)
	local topLeft, bottomRight = GetDragSafeInsets()

	local minX = viewportOrigin.X + topLeft.X + margin
	local minY = viewportOrigin.Y + topLeft.Y + margin
	local safeRight = viewportOrigin.X + viewport.X - bottomRight.X - margin
	local safeBottom = viewportOrigin.Y + viewport.Y - bottomRight.Y - margin
	local maxX = safeRight - size.X
	local maxY = safeBottom - size.Y
	local availableX = math.max(0, safeRight - minX)
	local availableY = math.max(0, safeBottom - minY)

	if size.X > availableX then
		maxX = minX
	end
	if size.Y > availableY then
		maxY = minY
	end

	return Vector2.new(
		math.clamp(pos.X, math.min(minX, maxX), math.max(minX, maxX)),
		math.clamp(pos.Y, math.min(minY, maxY), math.max(minY, maxY))
	)
end

local function GetDockedPlayerExtension(frame)
	local menu = Library.PlayerMenuApi
	if not menu or not menu.Open or menu.AnchorWindow == nil then
		return Vector2.new(0, 0)
	end
	local anchorFrame = menu.AnchorWindow.Main
	if anchorFrame ~= frame or not menu.Frame or not menu.Frame.Parent then
		return Vector2.new(0, 0)
	end

	local panelSize = GetRenderedOffsetSize(menu.Frame)
	local frameSize = GetRenderedOffsetSize(frame)
	local gap = tonumber(menu.DockGap) or 10
	return Vector2.new(gap + panelSize.X, math.max(0, panelSize.Y - frameSize.Y))
end

local function ClampFrameGroupToViewport(frame, pos, size, margin, viewport, viewportOrigin)
	local extension = GetDockedPlayerExtension(frame)
	local groupSize = Vector2.new(size.X + extension.X, size.Y + extension.Y)
	return ClampRectToViewport(pos, groupSize, margin, viewport, viewportOrigin)
end

local function ClampRenderedFrame(frame)
	if not frame or not frame.Parent then
		return
	end
	local current = frame.AbsolutePosition
	local viewportOrigin, viewportSize = GetFrameViewportRect(frame)
	local renderedSize = GetRenderedOffsetSize(frame)
	local clamped =
		ClampFrameGroupToViewport(frame, current, renderedSize, LAYER_DRAG_MARGIN, viewportSize, viewportOrigin)
	local correctionPixels = clamped - current
	if math.abs(correctionPixels.X) < 0.05 and math.abs(correctionPixels.Y) < 0.05 then
		return
	end
	local correctionOffsets = ScreenPixelsToOffsets(frame, correctionPixels)
	frame.Position = UDim2.new(
		frame.Position.X.Scale,
		frame.Position.X.Offset + correctionOffsets.X,
		frame.Position.Y.Scale,
		frame.Position.Y.Offset + correctionOffsets.Y
	)
end

local function ClampRenderedFrameNextFrame(frame)
	if not frame or not frame.Parent then
		return
	end
	task.defer(function()
		if not frame.Parent then
			return
		end
		RunService.RenderStepped:Wait()
		if frame.Parent then
			ClampRenderedFrame(frame)
		end
	end)
end

local function RaiseLayerFrame(frame)
	local screen = frame and frame:FindFirstAncestorOfClass("ScreenGui")
	if not screen then
		return
	end

	local linkedPlayerScreen
	local linkedWindow
	local playerMenu = Library.PlayerMenuApi
	if playerMenu and playerMenu.Open and playerMenu.HostVisible ~= false and playerMenu.AnchorWindow then
		local anchorFrame = playerMenu.AnchorWindow.Main
		if anchorFrame == frame then
			linkedPlayerScreen = playerMenu.Gui
			linkedWindow = playerMenu.AnchorWindow
		end
	end

	local mainHasForegroundFloat = false
	if linkedWindow and type(linkedWindow) == "table" and linkedWindow.FloatStack then
		mainHasForegroundFloat = #linkedWindow.FloatStack > 0
	end
	local cursorGui = Library.CursorGui
	local reserveCursorLayer = cursorGui and cursorGui.Parent and cursorGui.Enabled
	local foregroundOrder = reserveCursorLayer and (MAX_DISPLAY_ORDER - 1) or MAX_DISPLAY_ORDER

	local seen = {}
	for _, entry in Library.DraggableFrames do
		local other = entry.Frame
		local otherScreen = other and other:FindFirstAncestorOfClass("ScreenGui")
		if otherScreen and not seen[otherScreen] then
			seen[otherScreen] = true
			if otherScreen ~= screen and otherScreen ~= linkedPlayerScreen then
				pcall(function()
					otherScreen.DisplayOrder = MAX_DISPLAY_ORDER - 3
				end)
			end
		end
	end

	if playerMenu and playerMenu.Gui and playerMenu.Gui.Parent and playerMenu.Gui ~= linkedPlayerScreen then
		pcall(function()
			playerMenu.Gui.DisplayOrder = MAX_DISPLAY_ORDER - 3
		end)
	end

	if linkedPlayerScreen and linkedPlayerScreen.Parent then
		pcall(function()
			if mainHasForegroundFloat then
				screen.DisplayOrder = foregroundOrder
				linkedPlayerScreen.DisplayOrder = foregroundOrder - 1
			else
				screen.DisplayOrder = foregroundOrder - 1
				linkedPlayerScreen.DisplayOrder = foregroundOrder
			end
		end)
	else
		pcall(function()
			screen.DisplayOrder = foregroundOrder
		end)
	end
	if reserveCursorLayer then
		pcall(function()
			cursorGui.DisplayOrder = MAX_DISPLAY_ORDER
		end)
	end

	for _, activeScreen in { screen, linkedPlayerScreen } do
		if activeScreen and activeScreen.Parent then
			pcall(function()
				activeScreen.IgnoreGuiInset = true
				activeScreen.OnTopOfCoreBlur = true
			end)
		end
	end
end

local function ScreenVector2(value)
	if typeof(value) == "Vector2" then
		return value
	end
	if typeof(value) == "Vector3" then
		return Vector2.new(value.X, value.Y)
	end
	return Vector2.new(0, 0)
end

local function DragTargetPosition(
	frame,
	startPosition,
	startAbsolute,
	startInput,
	inputPosition,
	knownScale,
	dragMetrics
)
	startInput = ScreenVector2(startInput)
	inputPosition = ScreenVector2(inputPosition)
	local deltaPixels = inputPosition - startInput
	local desiredAbsolute = startAbsolute + deltaPixels
	local viewportOrigin, viewportSize, groupSize
	if dragMetrics then
		viewportOrigin = dragMetrics.ViewportOrigin
		viewportSize = dragMetrics.ViewportSize
		groupSize = dragMetrics.GroupSize
	else
		viewportOrigin, viewportSize = GetFrameViewportRect(frame)
		groupSize = GetRenderedOffsetSize(frame, knownScale) + GetDockedPlayerExtension(frame)
	end
	local clampedAbsolute =
		ClampRectToViewport(desiredAbsolute, groupSize, LAYER_DRAG_MARGIN, viewportSize, viewportOrigin)
	local appliedOffsets = ScreenPixelsToOffsets(frame, clampedAbsolute - startAbsolute, knownScale)
	return UDim2.new(
		startPosition.X.Scale,
		startPosition.X.Offset + appliedOffsets.X,
		startPosition.Y.Scale,
		startPosition.Y.Offset + appliedOffsets.Y
	)
end

local function RestoreCursorFromPlayerMenu()
	local cursorGui = Library.CursorGui
	local cursorHolder = Library.CursorHolder
	pcall(function()
		if cursorHolder and cursorGui and cursorHolder.Parent ~= cursorGui then
			cursorHolder.Parent = cursorGui
		end
		if cursorHolder then
			cursorHolder.ZIndex = 1
		end
		if cursorGui and cursorGui.Parent then
			cursorGui.DisplayOrder = MAX_DISPLAY_ORDER
		end
	end)
end

local function BeginCursorDrag()
	local cursorGui = Library.CursorGui
	pcall(function()
		if cursorGui and cursorGui.Parent then
			cursorGui.DisplayOrder = MAX_DISPLAY_ORDER
		end
	end)
	if Library.CursorFollow then
		Library.CursorFollow()
	end
end

local function AttachSmoothFrameDrag(frame, handle, onStart, canStart, onStop, onStep, directUpdate)
	if not frame or not handle then
		return nil
	end

	handle.Active = true
	local detector = New("UIDragDetector", {
		DragStyle = Enum.UIDragDetectorDragStyle.TranslatePlane,
		ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomOffset,
		Parent = handle,
	})
	RegisterDraggableFrame(frame)

	local dragging = false
	local enabled = true
	local startInput
	local startPosition
	local startAbsolute
	local dragScale = 1
	local dragMetrics
	local targetPosition = frame.Position
	local renderConnection
	local renderElapsed = 0
	local stepElapsed = 0

	local function stopRender()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
	end

	local function finishDrag()
		if not dragging then
			stopRender()
			return
		end

		targetPosition = frame.Position
		dragging = false
		stopRender()
		startInput = nil
		startPosition = nil
		startAbsolute = nil
		dragMetrics = nil
		if onStop then
			pcall(onStop)
		end
	end

	Track(detector.DragStart:Connect(function(inputPosition)
		if not enabled or not IsInteractive(handle) then
			return
		end
		if canStart and canStart() == false then
			return
		end

		finishDrag()
		dragging = true
		startInput = ScreenVector2(inputPosition)
		startPosition = frame.Position
		startAbsolute = frame.AbsolutePosition
		dragScale = GetFrameOffsetScale(frame)
		RaiseLayerFrame(frame)
		if onStart then
			onStart()
		end

		local viewportOrigin, viewportSize = GetFrameViewportRect(frame)
		local renderedSize = GetRenderedOffsetSize(frame, dragScale)
		if directUpdate then
			dragMetrics = {
				ViewportOrigin = viewportOrigin,
				ViewportSize = viewportSize,
				GroupSize = renderedSize + GetDockedPlayerExtension(frame),
			}
		end
		local clampedStart = ClampFrameGroupToViewport(
			frame,
			startAbsolute,
			renderedSize,
			LAYER_DRAG_MARGIN,
			viewportSize,
			viewportOrigin
		)
		local correctionOffsets = ScreenPixelsToOffsets(frame, clampedStart - startAbsolute, dragScale)
		targetPosition = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + correctionOffsets.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + correctionOffsets.Y
		)

		stopRender()
		if directUpdate then
			frame.Position = targetPosition
			if onStep then
				onStep()
			end
		else
			renderElapsed = 0
			stepElapsed = 0
			renderConnection = RunService.RenderStepped:Connect(function(dt)
				if not dragging or not frame.Parent then
					stopRender()
					return
				end
				renderElapsed = renderElapsed + math.max(dt, 0)
				if renderElapsed < (1 / 120) then
					return
				end
				local stepDt = renderElapsed
				renderElapsed = 0
				local nextPosition = LerpUDim2(frame.Position, targetPosition, 1 - math.exp(-stepDt * 34))
				local absoluteSize = frame.AbsoluteSize
				local remainingX = math.abs(nextPosition.X.Offset - targetPosition.X.Offset)
					+ math.abs(nextPosition.X.Scale - targetPosition.X.Scale) * absoluteSize.X
				local remainingY = math.abs(nextPosition.Y.Offset - targetPosition.Y.Offset)
					+ math.abs(nextPosition.Y.Scale - targetPosition.Y.Scale) * absoluteSize.Y
				if remainingX <= 0.1 and remainingY <= 0.1 then
					nextPosition = targetPosition
				end
				if frame.Position ~= nextPosition then
					frame.Position = nextPosition
					if onStep then
						stepElapsed = stepElapsed + stepDt
						if stepElapsed >= (1 / 90) or nextPosition == targetPosition then
							stepElapsed = 0
							onStep()
						end
					end
				end
			end)
		end
	end))

	Track(detector.DragContinue:Connect(function(inputPosition)
		if not dragging or not startInput or not startPosition or not startAbsolute then
			return
		end
		targetPosition = DragTargetPosition(
			frame,
			startPosition,
			startAbsolute,
			startInput,
			ScreenVector2(inputPosition),
			dragScale,
			directUpdate and dragMetrics or nil
		)
		if directUpdate then
			frame.Position = targetPosition
			if onStep then
				onStep()
			end
		end
	end))

	Track(detector.DragEnd:Connect(function(_inputPosition)
		finishDrag()
	end))

	local controller = { Detector = detector }
	function controller:SetEnabled(state)
		enabled = state ~= false
		pcall(function()
			detector.Enabled = enabled
		end)
		if not enabled then
			finishDrag()
		end
		return self
	end
	function controller:Cancel()
		finishDrag()
		return self
	end
	return controller
end

local function ToHex(color, alpha)
	return string.format(
		"#%02X%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5),
		math.floor(math.clamp(alpha or 1, 0, 1) * 255 + 0.5)
	)
end

local function FromHex(text)
	if typeof(text) == "Color3" then
		return text, 1
	end
	if type(text) ~= "string" then
		return nil
	end
	local hex = string.gsub(string.gsub(text, "#", ""), "%s", "")
	if #hex ~= 6 and #hex ~= 8 then
		return nil
	end
	local r = tonumber(string.sub(hex, 1, 2), 16)
	local g = tonumber(string.sub(hex, 3, 4), 16)
	local b = tonumber(string.sub(hex, 5, 6), 16)
	if not r or not g or not b then
		return nil
	end
	local a = 255
	if #hex == 8 then
		a = tonumber(string.sub(hex, 7, 8), 16) or 255
	end
	return Color3.fromRGB(r, g, b), a / 255
end

local HUE_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
})

local IconLib, IconTried
local IconAtlases = {}
local IconCache = {}

local function IndexIconAtlases(lib)
	table.clear(IconAtlases)
	table.clear(IconCache)
	if type(lib) ~= "table" then
		return
	end

	for key, set in lib do
		local px = type(key) == "string" and tonumber(string.match(key, "^(%d+)%s*[pP][xX]$")) or nil
		if px and type(set) == "table" then
			table.insert(IconAtlases, { Size = px, Set = set })
		end
	end

	table.sort(IconAtlases, function(a, b)
		return a.Size < b.Size
	end)
end

function Library:PreloadIcons()
	if IconTried then
		return IconLib
	end
	IconTried = true
	local loaded = self:LoadAddon("Icons")
	if type(loaded) == "table" then
		IconLib = loaded
		IndexIconAtlases(loaded)
	end
	return IconLib
end

local function IconSourceScore(sourceSize, desired)
	if sourceSize < desired then
		return 10000 + (desired - sourceSize)
	end

	local ratio = sourceSize / desired
	local rounded = math.floor(ratio + 0.5)
	local integerScale = math.abs(ratio - rounded) < 0.001

	return (integerScale and 0 or 1000) + ratio
end

local function ResolveIcon(icon, targetSize)
	if not icon or icon == 0 or icon == "" then
		return nil
	end
	if type(icon) == "number" then
		return { Image = "rbxassetid://" .. icon }
	end
	if type(icon) ~= "string" then
		return nil
	end
	if string.find(icon, "rbxassetid://") == 1 or string.find(icon, "rbxasset://") == 1 then
		return { Image = icon }
	end

	local lib = Library:PreloadIcons()
	if type(lib) ~= "table" then
		return nil
	end

	local name = string.lower(string.match(icon, "^%s*(.-)%s*$"))
	local desired = math.max(math.floor((tonumber(targetSize) or 16) + 0.5), 1)
	local cacheKey = name .. "@" .. desired
	local cached = IconCache[cacheKey]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local bestEntry, bestSize, bestScore
	for _, atlas in IconAtlases do
		local entry = atlas.Set[name]
		if entry and type(entry[1]) == "number" then
			local score = IconSourceScore(atlas.Size, desired)
			if bestScore == nil or score < bestScore then
				bestEntry, bestSize, bestScore = entry, atlas.Size, score
			end
		end
	end

	if not bestEntry then
		local set = lib["48px"]
		local entry = type(set) == "table" and set[name] or nil
		if entry and type(entry[1]) == "number" then
			bestEntry, bestSize = entry, 48
		end
	end

	if not bestEntry then
		IconCache[cacheKey] = false
		return nil
	end

	local resolved = {
		Image = "rbxassetid://" .. bestEntry[1],
		RectSize = bestEntry[2] and Vector2.new(bestEntry[2][1], bestEntry[2][2]) or nil,
		RectOffset = bestEntry[3] and Vector2.new(bestEntry[3][1], bestEntry[3][2]) or nil,
		SourceSize = bestSize,
	}
	IconCache[cacheKey] = resolved
	return resolved
end

local function StyleColor(style, fallback)
	if typeof(style) == "Color3" then
		return style
	end
	if type(style) ~= "string" then
		return fallback
	end
	style = string.lower(style)
	if style == "normal" or style == "text" then
		return Theme.Text
	end
	if style == "dim" or style == "muted" then
		return Theme.TextDim
	end
	if style == "bright" or style == "title" then
		return Theme.TextBright
	end
	if style == "warning" or style == "warn" or style == "yellow" then
		return Theme.TextMarked
	end
	if style == "danger" or style == "error" or style == "red" then
		return Theme.Danger
	end
	if style == "success" or style == "green" then
		return Theme.TextCode
	end
	if style == "accent" or style == "pink" then
		return Theme.Accent
	end
	return fallback
end

local function Disableable(api, parts, opts)
	api.Enabled = true

	function api:SetEnabled(state)
		state = state ~= false
		self.Enabled = state
		for _, inst in parts do
			pcall(function()
				if inst:IsA("UIStroke") then
					SetVisual(inst, "Transparency", state and 0 or 0.7)
				elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
					SetVisual(inst, "ImageTransparency", state and 0 or 0.6)
				else
					SetVisual(inst, "TextTransparency", state and 0 or 0.6)
					if inst:IsA("TextBox") then
						SetVisual(inst, "TextEditable", state)
					end
				end
			end)
		end
		return self
	end

	function api:SetDisabled(state)
		return self:SetEnabled(not state)
	end

	if opts and opts.Disabled then
		api:SetEnabled(false)
	end
	return api
end

local function LabelColor(opts, fallback)
	if typeof(opts.Color) == "Color3" then
		return opts.Color, true
	end
	local styled = StyleColor(opts.Style, nil)
	if styled then
		return styled, true
	end
	return fallback, false
end

local function FlagOf(opts, owner)
	local explicit = opts.Flag ~= nil
	local flag = opts.Flag
	if flag == nil then
		flag = opts.Text
	end
	if flag == false then
		return nil
	end
	if not explicit and flag ~= nil and owner and owner.FlagPrefix then
		flag = tostring(owner.FlagPrefix) .. tostring(flag)
	end
	return flag
end

local BuildColorPicker, ColorSwatch
local ColorClipboard = nil

local Elements = {}
Elements.__index = Elements

local function NewContainer(window, frame, float, flagPrefix)
	return setmetatable({ Window = window, Container = frame, Float = float, FlagPrefix = flagPrefix }, Elements)
end

function Elements:Image(opts)
	opts = opts or {}

	local height = opts.Height or 120
	local holder = New("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Theme.Field,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.Container,
		ThemeTag = { BackgroundColor3 = "Field" },
	})
	Corner(holder, opts.Corner or 6)
	if opts.Border ~= false then
		Stroke(holder, Theme.Border)
	end

	local image = New("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = opts.Image or "",
		ScaleType = opts.ScaleType or Enum.ScaleType.Crop,
		Parent = holder,
	})

	local api = { Instance = holder, Image = image }

	function api:Set(asset)
		image.Image = tostring(asset or "")
		return self
	end

	function api:SetUser(userId, thumbType, size)
		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(
					tonumber(userId) or 0,
					thumbType or Enum.ThumbnailType.HeadShot,
					size or Enum.ThumbnailSize.Size150x150
				)
			end)
			if ok and content then
				image.Image = content
			end
		end)
		return self
	end

	function api:SetHeight(value)
		holder.Size = UDim2.new(1, 0, 0, value)
		return self
	end

	if opts.UserId then
		api:SetUser(opts.UserId)
	end
	return api
end

function Elements:Table(opts)
	opts = opts or {}

	local columns = opts.Columns or { "column" }
	local count = math.max(#columns, 1)
	local maxRows = opts.MaxRows or 12
	local rowHeight = opts.RowHeight or 18

	local block = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	List(block, 4)

	local function buildRow(parent, order)
		local row = New("Frame", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = parent,
		})
		local cells = {}
		for index = 1, count do
			local cell = Label(row, "", Theme.Text, Theme.TextSize - 1)
			cell.Position = UDim2.fromScale((index - 1) / count, 0)
			cell.Size = UDim2.new(1 / count, -6, 1, 0)
			cell.TextTruncate = Enum.TextTruncate.AtEnd
			if index > 1 and opts.AlignRight then
				cell.TextXAlignment = Enum.TextXAlignment.Right
			end
			cells[index] = cell
		end
		return row, cells
	end

	local headerCells
	if opts.Header ~= false then
		local header
		header, headerCells = buildRow(block, 1)
		for index, cell in headerCells do
			cell.Text = tostring(columns[index] or "")
			cell.TextColor3 = Theme.TextDim
			TagInstance(cell, { TextColor3 = "TextDim" })
		end

		New("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.BorderSoft,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Parent = block,
			ThemeTag = { BackgroundColor3 = "BorderSoft" },
		})
	end

	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = block,
	})
	List(body, 2)

	local empty = Label(block, opts.EmptyText or "no data", Theme.TextDim, Theme.TextSize - 1)
	empty.Size = UDim2.new(1, 0, 0, rowHeight)
	empty.LayoutOrder = 4

	local rows = {}
	for index = 1, maxRows do
		local row, cells = buildRow(body, index)
		row.Visible = false
		rows[index] = { Frame = row, Cells = cells }
	end

	local api = { Instance = block, Rows = rows }

	function api:SetRows(data)
		data = data or {}
		local shown = 0

		for index, row in rows do
			local entry = data[index]
			if entry then
				shown = shown + 1
				row.Frame.Visible = true
				for cellIndex, cell in row.Cells do
					local value = entry[cellIndex]
					cell.Text = value ~= nil and tostring(value) or ""
					local color = entry.Color or (entry.Colors and entry.Colors[cellIndex])
					if typeof(color) == "Color3" then
						cell.TextColor3 = color
					elseif entry.Style then
						cell.TextColor3 = StyleColor(entry.Style, Theme.Text)
					end
				end
			else
				row.Frame.Visible = false
			end
		end

		empty.Visible = shown == 0
		if headerCells then
			for _, cell in headerCells do
				cell.Visible = shown > 0 or opts.KeepHeader == true
			end
		end
		return shown
	end

	function api:Clear()
		return self:SetRows({})
	end

	api:SetRows(opts.Rows)
	return api
end

function Elements:Divider()
	local d = New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.BorderSoft,
		BorderSizePixel = 0,
		Parent = self.Container,
		ThemeTag = { BackgroundColor3 = "BorderSoft" },
	})
	return d
end

local function SnapIconSize(requested)
	requested = math.max(tonumber(requested) or 16, 1)
	if requested <= 13 then
		return 12
	end
	if requested <= 19 then
		return 16
	end
	if requested <= 27 then
		return 24
	end
	if requested <= 39 then
		return 32
	end
	if requested <= 55 then
		return 48
	end
	if requested <= 79 then
		return 64
	end
	if requested <= 111 then
		return 96
	end
	if requested <= 159 then
		return 128
	end
	return 256
end

local function AttachIcon(parent, icon, color, size)
	size = SnapIconSize(size)
	local resolved = ResolveIcon(icon, size)
	if not resolved then
		return nil
	end
	local image = New("ImageLabel", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromOffset(0, 1),
		BackgroundTransparency = 1,
		Image = resolved.Image,
		ImageColor3 = color,
		Parent = parent,
	})
	if resolved.RectOffset then
		image.ImageRectOffset = resolved.RectOffset
	end
	if resolved.RectSize then
		image.ImageRectSize = resolved.RectSize
	end
	return image
end

function Elements:Label(text, opts)
	if typeof(opts) == "Color3" then
		opts = { Color = opts }
	end
	opts = opts or {}
	local color = opts.Color or StyleColor(opts.Style, Theme.TextDim)

	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Container,
	})

	local icon = AttachIcon(row, opts.Icon, color, 14)
	local inset = icon and 20 or 0

	local l = Label(row, tostring(text or ""), color, opts.TextSize, opts.Font)
	l.Position = UDim2.fromOffset(inset, 0)
	local wrap = opts.Wrap == true or opts.TextWrapped == true or opts.Multiline == true
	if wrap then
		l.Size = UDim2.new(1, -inset, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.TextWrapped = true
		l.TextYAlignment = Enum.TextYAlignment.Top
	else
		row.Size = UDim2.new(1, 0, 0, 18)
		row.AutomaticSize = Enum.AutomaticSize.None
		l.Size = UDim2.new(1, -inset, 1, 0)
		l.AutomaticSize = Enum.AutomaticSize.None
		l.TextWrapped = false
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.TextYAlignment = Enum.TextYAlignment.Center
	end

	local api = { Instance = row, Text = l, Icon = icon }

	local function syncVisibility()
		if opts.KeepSpace then
			return
		end
		row.Visible = l.Text ~= ""
	end

	function api:Set(value)
		l.Text = tostring(value or "")
		syncVisibility()
	end
	function api:SetColor(c)
		local themeKey = typeof(c) == "Color3" and ThemeIndex[tostring(c)] or nil

		if themeKey then
			Library:Tag(l, { TextColor3 = themeKey })
		else
			Library:Tag(l, { TextColor3 = false })
		end
		l.TextColor3 = c

		if icon then
			if themeKey then
				Library:Tag(icon, { ImageColor3 = themeKey })
			else
				Library:Tag(icon, { ImageColor3 = false })
			end
			icon.ImageColor3 = c
		end
	end
	function api:SetStyle(style)
		api:SetColor(StyleColor(style, Theme.TextDim))
	end

	syncVisibility()
	return api
end

function Elements:Paragraph(opts)
	opts = opts or {}
	local accent = StyleColor(opts.Style, Theme.TextBright)
	local styled = type(opts.Style) == "string" and string.lower(opts.Style) ~= "normal"

	local card = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Group,
		BorderSizePixel = 0,
		Parent = self.Container,
		ThemeTag = { BackgroundColor3 = "Group" },
	})
	Corner(card, 5)
	local stroke = Stroke(card, styled and accent or Theme.GroupBorder, 1, styled and 0.55 or 0)
	Pad(card, 9, 11)

	local inner = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	})
	List(inner, 4)

	local head = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = inner,
	})
	local icon = AttachIcon(head, opts.Icon, accent, 15)
	local inset = icon and 21 or 0
	local title = Label(head, opts.Title or "", accent, Theme.TextSize, Theme.FontMedium)
	title.Position = UDim2.fromOffset(inset, 0)
	title.Size = UDim2.new(1, -inset, 0, 0)
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.TextWrapped = true
	title.TextYAlignment = Enum.TextYAlignment.Top

	local body
	if opts.Content then
		body = Label(inner, opts.Content, opts.ContentColor or Theme.TextDim, opts.TextSize or 12)
		body.Size = UDim2.new(1, 0, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.LayoutOrder = 2
	end

	local api = { Instance = card, Title = title, Body = body, Icon = icon }
	function api:Set(newOpts)
		newOpts = newOpts or {}
		if newOpts.Title then
			title.Text = newOpts.Title
		end
		if newOpts.Content and body then
			body.Text = newOpts.Content
		end
		if newOpts.Style then
			local c = StyleColor(newOpts.Style, Theme.TextBright)
			title.TextColor3 = c
			if icon then
				icon.ImageColor3 = c
			end
			stroke.Color = c
		end
	end
	return api
end

local function MakeButton(parent, opts, size, order)
	local state = { Enabled = true }
	local btn = New("TextButton", {
		Size = size or UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Field,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
		ThemeTag = { BackgroundColor3 = "Field" },
	})
	Corner(btn, 5)
	Stroke(btn, Theme.Border)
	local text = Label(btn, opts.Text or "button", (LabelColor(opts, Theme.TextBright)))
	text.Size = UDim2.fromScale(1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextTruncate = Enum.TextTruncate.AtEnd
	Hover(btn, btn, "Field", "FieldHover")
	Track(btn.Activated:Connect(function()
		if state.Enabled == false then
			return
		end
		Library:SafeCallback(opts.Text or "button", opts.Callback)
	end))
	return btn, state, text
end

function Elements:Button(opts)
	opts = opts or {}
	local btn, state, text = MakeButton(self.Container, opts)
	local api = Disableable({ Instance = btn }, { text })
	local baseSetEnabled = api.SetEnabled
	function api:SetEnabled(value)
		state.Enabled = value ~= false
		return baseSetEnabled(self, value)
	end
	if opts.Disabled then
		api:SetEnabled(false)
	end
	return api
end

function Elements:ButtonRow(list)
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	List(row, 8, Enum.FillDirection.Horizontal)
	local n = math.max(#list, 1)
	local buttons = {}
	for i, opts in list do
		buttons[i] = MakeButton(row, opts, UDim2.new(1 / n, -(8 * (n - 1)) / n, 1, 0), i)
	end
	return { Instance = row, Buttons = buttons }
end

function Elements:Split(builders)
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	local list = List(row, 12, Enum.FillDirection.Horizontal)
	list.SortOrder = Enum.SortOrder.LayoutOrder

	local count = math.max(#builders, 1)
	local columns = {}
	for i = 1, count do
		local frame = New("Frame", {
			Size = UDim2.new(1 / count, -(12 * (count - 1)) / count, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = row,
		})
		List(frame, 9)
		columns[i] = NewContainer(self.Window, frame, self.Float)
		if type(builders[i]) == "function" then
			builders[i](columns[i])
		end
	end

	return { Instance = row, Columns = columns }
end

function Elements:Input(opts)
	opts = opts or {}
	local flag = FlagOf(opts, self)
	local block = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	List(block, 5)
	if opts.Text then
		local cap = Label(block, opts.Text, (LabelColor(opts, Theme.Text)))
		cap.Size = UDim2.new(1, 0, 0, 15)
	end
	local field = New("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Field,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = block,
		ThemeTag = { BackgroundColor3 = "Field" },
	})
	Corner(field, 5)
	local fStroke = Stroke(field, Theme.Border)
	local box = New("TextBox", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = opts.Default or "",
		PlaceholderText = opts.Placeholder or "",
		PlaceholderColor3 = Theme.TextDim,
		TextColor3 = Theme.TextBright,
		TextSize = Theme.TextSize,
		Font = Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = field,
		ThemeTag = { PlaceholderColor3 = "TextDim", TextColor3 = "TextBright" },
	})

	local api = Disableable({ Instance = block, Box = box }, { box }, opts)
	function api:Get()
		return box.Text
	end
	function api:Set(value, silent)
		box.Text = tostring(value or "")
		if flag then
			Library.Flags[flag] = box.Text
		end
		if not silent then
			Library:SafeCallback(opts.Text or "input", opts.Callback, box.Text)
		end
	end

	Track(box.Focused:Connect(function()
		Tween(fStroke, { Color = Theme.Accent }, EASE_FAST)
	end))
	Track(box.FocusLost:Connect(function(enter)
		Tween(fStroke, { Color = Theme.Border }, EASE_FAST)
		if flag then
			Library.Flags[flag] = box.Text
			Library:MarkDirty(flag)
		end
		Library:SafeCallback(opts.Text or "input", opts.Callback, box.Text, enter)
	end))

	if flag then
		Library.Flags[flag] = box.Text
		Library:Register(flag, {
			Type = "Input",
			Get = function()
				return box.Text
			end,
			Set = function(v)
				api:Set(v)
			end,
		})
	end
	return api
end

local TextWidthCache, TextWidthCacheOrder = {}, {}
local TextWidthCacheIndex = 0
local function MeasureRenderedTextWidth(label, value)
	value = tostring(value or "")

	local cacheKey
	if #value <= 1024 then
		local valid, key = pcall(function()
			local face = label.FontFace
			return table.concat({ tostring(face.Family), tostring(face.Weight), tostring(face.Style), tostring(label.TextSize), value }, "\0")
		end)
		if valid then cacheKey = key end
	end
	if cacheKey and TextWidthCache[cacheKey] ~= nil then return TextWidthCache[cacheKey] end
	local params
	local ok, width = pcall(function()
		params = Instance.new("GetTextBoundsParams")
		params.Text = value
		params.Font = label.FontFace
		params.Size = label.TextSize
		params.Width = 10000
		return TextService:GetTextBoundsAsync(params).X
	end)
	if params then params:Destroy() end
	if ok and type(width) == "number" then
		if cacheKey then
			TextWidthCacheIndex = TextWidthCacheIndex % 256 + 1
			local expired = TextWidthCacheOrder[TextWidthCacheIndex]
			if expired then TextWidthCache[expired] = nil end
			TextWidthCacheOrder[TextWidthCacheIndex] = cacheKey
			TextWidthCache[cacheKey] = width
		end
		return width
	end
	return TextService:GetTextSize(
		value,
		label.TextSize,
		label.Font,
		Vector2.new(10000, math.max(22, label.TextSize + 4))
	).X
end

local function MeasureTooltipTextWidth(label, text, maxWidth)
	local ok, bounds = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = label.FontFace
		params.Size = label.TextSize
		params.Width = math.max(1, maxWidth - 4)
		return TextService:GetTextBoundsAsync(params)
	end)
	if not ok then
		bounds = TextService:GetTextSize(text, label.TextSize, label.Font,
			Vector2.new(math.max(1, maxWidth - 4), 10000))
	end
	return math.clamp(math.ceil(bounds.X) + 4, 24, maxWidth)
end

local function MakeHint(owner, parent, text, order)
	local hintText = "(?)"
	local hintTextSize = Theme.TextSize - 1
	local hintWidth = math.ceil(
		TextService:GetTextSize(hintText, hintTextSize, Theme.FontMedium, Vector2.new(100, 18)).X
	) + 4
	local mark = New("TextButton", {
		Size = UDim2.fromOffset(hintWidth, 22),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = hintText,
		TextColor3 = Theme.TextDim,
		TextTransparency = 0.16,
		TextSize = hintTextSize,
		Font = Theme.FontMedium,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = order or 2,
		Name = "Hint",
		Parent = parent,
		ThemeTag = { TextColor3 = "TextDim" },
	})

	mark.Size = UDim2.fromOffset(math.ceil(MeasureRenderedTextWidth(mark, hintText)) + 4, 22)

	Track(mark.MouseEnter:Connect(function()
		Library:Tag(mark, { TextColor3 = "AccentSoft" })
		Tween(mark, {
			TextColor3 = Theme.AccentSoft,
			TextTransparency = 0,
		}, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end))
	Track(mark.MouseLeave:Connect(function()
		Library:Tag(mark, { TextColor3 = "TextDim" })
		Tween(mark, {
			TextColor3 = Theme.TextDim,
			TextTransparency = 0.12,
		}, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end))

	local window = owner and owner.Window
	local tip
	local ticket = 0
	local reposition

	local function hide(immediate)
		ticket = ticket + 1
		reposition = nil
		if not tip then
			return
		end
		local closing = tip
		tip = nil
		local info = immediate == true and TweenInfo.new(0)
			or TweenInfo.new(0.17, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
		Fade(closing, false, info, function()
			if closing.Parent then
				closing:Destroy()
			end
		end)
	end

	if window then
		window.Hints = window.Hints or {}
		window.Hints[mark] = hide
		mark.Destroying:Once(function()
			hide(true)
			window.Hints[mark] = nil
		end)
	end

	Track(mark.MouseEnter:Connect(function()
		if not IsInteractive(mark) then
			return
		end
		if window then
			local activeFloat = window.FloatStack and window.FloatStack[#window.FloatStack]
			if activeFloat and (not owner or owner.Float ~= activeFloat) then
				hide(true)
				return
			end
			for _, modal in window.Modals or {} do
				if modal.Open then
					hide(true)
					return
				end
			end
		end
		hide(true)
		ticket = ticket + 1
		local myTicket = ticket

		local rawText = tostring(text or "")
		if not string.find(rawText, "%S") then return end
		local fontSize = Theme.TextSize - 1
		local padX, padY = 10, 7
		local layer = window and window.Overlay or mark
		local maxTextWidth = 240
		if window then
			local s = GetFrameRenderScale(layer)
			maxTextWidth = math.max(72, math.min(240, layer.AbsoluteSize.X / s - 36))
		end

		local probe = New("TextLabel", {
			Visible = false,
			Size = UDim2.fromOffset(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			TextSize = fontSize,
			Font = Theme.Font,
			RichText = false,
			Parent = layer,
		})

		local textWidth = MeasureTooltipTextWidth(probe, rawText, maxTextWidth)
		probe:Destroy()
		if myTicket ~= ticket then return end
		local textHeight = fontSize + 4

		tip = New("Frame", {
			Visible = false,
			Size = UDim2.fromOffset(textWidth + padX * 2, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.PopupBg,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 340,
			Parent = layer,
			ThemeTag = { BackgroundColor3 = "PopupBg" },
		})
		Corner(tip, 7)
		Stroke(tip, Theme.PopupBorder, 1, 0.15)
		Pad(tip, padY, padX, padY, padX)

		local tipText = New("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Text = rawText,
			TextColor3 = Theme.TextBright,
			TextSize = fontSize,
			Font = Theme.Font,
			TextWrapped = true,
			RichText = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 341,
			Parent = tip,
			ThemeTag = { TextColor3 = "TextBright" },
		})

		if myTicket ~= ticket or not tip or not tip.Parent then
			return
		end
		local tipWidth = textWidth + padX * 2
		local tipHeight = textHeight + padY * 2

		reposition = function()
			if myTicket ~= ticket or not tip or not tip.Parent then return end
			local scale = GetFrameRenderScale(layer)
			if tip.AbsoluteSize.Y > 0 then tipHeight = tip.AbsoluteSize.Y / scale end
			local markCenter = mark.AbsolutePosition + mark.AbsoluteSize * 0.5
			local origin = layer.AbsolutePosition
			local centerX = (markCenter.X - origin.X) / scale
			local centerY = (markCenter.Y - origin.Y) / scale
			local viewport = GetDragViewportSize()
			local minX, minY = 8, 8
			local maxX = window and layer.AbsoluteSize.X / scale or (viewport.X - origin.X) / scale
			local maxY = window and layer.AbsoluteSize.Y / scale or (viewport.Y - origin.Y) / scale
			if not window then
				minX, minY = (8 - origin.X) / scale, (8 - origin.Y) / scale
			end
			local tx = math.clamp(centerX, minX + tipWidth * 0.5,
				math.max(minX + tipWidth * 0.5, maxX - tipWidth * 0.5 - 8))
			local halfMark = mark.AbsoluteSize.Y / scale * 0.5
			local preferredY = centerY - halfMark - tipHeight * 0.5 - 8
			if preferredY - tipHeight * 0.5 < minY then
				preferredY = centerY + halfMark + tipHeight * 0.5 + 8
			end
			local ty = math.clamp(preferredY, minY + tipHeight * 0.5,
				math.max(minY + tipHeight * 0.5, maxY - tipHeight * 0.5 - 8))
			tip.Position = UDim2.fromOffset(tx, ty)
		end
		local openedTip = tip
		local sizeConnection = openedTip:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if tip == openedTip and reposition then reposition() end
		end)
		openedTip.Destroying:Once(function() sizeConnection:Disconnect() end)
		reposition()
		Fade(tip, true, TweenInfo.new(0.24, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out))
	end))
	Track(mark.MouseLeave:Connect(function()
		hide(false)
	end))
	local function updatePosition()
		if reposition then reposition() end
	end
	Track(mark:GetPropertyChangedSignal("AbsolutePosition"):Connect(updatePosition))
	Track(mark:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePosition))
	if window and window.Overlay then
		Track(window.Overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePosition))
		Track(window.Overlay:GetPropertyChangedSignal("AbsolutePosition"):Connect(updatePosition))
	end
	return mark
end
local function KeybindDisplay(key, listening)
	return listening and "[...]" or "[" .. (key and string.upper(tostring(key)) or "NONE") .. "]"
end

local function BindTextMotion(button, label, isListening, isEnabled)
	local hovered, dead, ticket = false, false, 0
	local colorTween
	local function paint(color, duration)
		if colorTween then colorTween:Cancel() end
		colorTween = TweenService:Create(label,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextColor3 = color })
		colorTween:Play()
	end
	local function sync(immediate)
		ticket = ticket + 1
		if dead then return end
		if not isEnabled() then
			if colorTween then colorTween:Cancel() end
			return
		end
		local color = isListening() and Theme.Accent or hovered and Theme.TextBright or Theme.TextDim
		paint(color, immediate and 0 or 0.14)
	end
	local function pulse()
		if dead or not isEnabled() then return end
		ticket = ticket + 1
		local current = ticket
		paint(Theme.Accent, 0.045)
		task.delay(0.09, function()
			if dead or current ~= ticket then return end
			sync()
		end)
	end
	Track(button.MouseEnter:Connect(function() hovered = true; sync() end))
	Track(button.MouseLeave:Connect(function() hovered = false; sync() end))
	button.Destroying:Once(function()
		dead = true
		ticket = ticket + 1
		if colorTween then colorTween:Cancel(); colorTween = nil end
	end)
	return sync, pulse
end

local function AttachKeybindModeMenu(owner, anchor, getMode, setMode)
	local window = owner and owner.Window
	if not window then
		return nil
	end
	local panel = window:CreateFloating(112, false, owner.Float)
	panel.Frame.ClipsDescendants = true
	local entries = {}
	local choices = {
		{ Key = "toggle", Text = "toggle" },
		{ Key = "hold", Text = "hold" },
		{ Key = "always", Text = "always on" },
	}

	local function refresh(info)
		info = info or TweenInfo.new(0)
		local current = getMode()
		for _, entry in entries do
			local selected = entry.Mode == current
			Library:Tag(entry.Label, { TextColor3 = selected and "Accent" or "Text" })
			Tween(entry.Label, { TextColor3 = selected and Theme.Accent or Theme.Text }, info)
			Tween(entry.Button, { BackgroundTransparency = selected and 0.58 or 1 }, info)
		end
	end

	for i, choice in choices do
		local button = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = Theme.FieldHover,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = panel.Frame.ZIndex,
			Parent = panel.Content,
			ThemeTag = { BackgroundColor3 = "FieldHover" },
		})
		Corner(button, 4)
		local label = Label(button, choice.Text, Theme.Text, Theme.TextSize - 1)
		label.Position = UDim2.fromOffset(7, 0)
		label.Size = UDim2.new(1, -14, 1, 0)
		label.ZIndex = panel.Frame.ZIndex
		entries[i] = { Button = button, Label = label, Mode = choice.Key }

		Track(button.MouseEnter:Connect(function()
			if getMode() ~= choice.Key then
				Tween(button, { BackgroundTransparency = 0.72 }, EASE_FAST)
			end
		end))
		Track(button.MouseLeave:Connect(function()
			refresh(EASE_FAST)
		end))
		Track(button.Activated:Connect(function()
			setMode(choice.Key)
			refresh(EASE_FAST)
			window:CloseFloatingFrom(panel.Depth)
		end))
	end

	panel.OnOpen = function(info)
		refresh(info)
	end
	Track(anchor.MouseButton2Click:Connect(function()
		window:ToggleFloating(panel, anchor)
	end))
	return panel
end

function Elements:Toggle(opts)
	opts = opts or {}
	local flag = FlagOf(opts, self)
	local state = opts.Default == true

	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})

	local hit = New("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	})

	local box = New("Frame", {
		Size = UDim2.fromOffset(15, 15),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 7.5, 0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Parent = row,
	})
	Corner(box, 5)
	local boxStroke = Stroke(box, Theme.Border)
	local fill = New("Frame", {
		Size = UDim2.fromOffset(15, 15),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Visible = state,
		Parent = box,
		ThemeTag = { BackgroundColor3 = "Accent" },
	})
	Corner(fill, 5)
	local fillGlow = Shadow(fill, Theme.Accent, 0.82, 5, UDim2.fromOffset(1, 1), UDim2.fromOffset(0, 0), 0)
	if fillGlow then
		fillGlow.Color = Theme.Accent
		Library:OnRepaint(function()
			if fillGlow.Parent then
				fillGlow.Color = Theme.Accent
			end
		end, row)
	end
	local function accentGradientSequence()
		local accent = Theme.Accent
		local vivid = accent:Lerp(Color3.new(1, 1, 1), 0.10)
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, vivid),
			ColorSequenceKeypoint.new(1, accent),
		})
	end
	local fillGradient = New("UIGradient", {
		Rotation = 90,
		Color = accentGradientSequence(),
		Parent = fill,
	})
	Library:OnRepaint(function()
		if fillGradient.Parent then
			fillGradient.Color = accentGradientSequence()
		end
	end, row)
	local fillScale = New("UIScale", { Scale = state and 1 or 0, Parent = fill })
	local fillMotion

	local labelColor, customLabel = LabelColor(opts, Theme.Text)
	local text = Label(row, opts.Text or "toggle", labelColor)
	text.Position = UDim2.fromOffset(21, 0)
	text.Size = UDim2.new(1, -21, 1, 0)

	local left = New("Frame", {
		Size = UDim2.new(1, -21, 1, 0),
		Position = UDim2.fromOffset(21, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = row,
	})
	text.Parent = left
	text.AutomaticSize = Enum.AutomaticSize.None
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.TextWrapped = false
	text.Size = UDim2.new(1, 0, 1, 0)
	 
	local textOffsetY = -1
	text.Position = UDim2.fromOffset(0, textOffsetY)
	text.LayoutOrder = 1
	local hintMark
	if opts.Hint then
		hintMark = MakeHint(self, left, opts.Hint, 2)
	end

	local right
	local function syncInlineLabel()
		local scale = GetFrameOffsetScale(left)
		local available = math.max(left.AbsoluteSize.X / scale, 0)
		local float = self.Float
		if float and float.FitContents then
			local controls = right and right.AbsoluteSize.X / scale or 0
			local hintSpace = hintMark and (hintMark.Size.X.Offset + 8) or 0
			local padding = float.Padding
			local minimum = 21 + math.ceil(MeasureRenderedTextWidth(text, text.Text)) + 2 + hintSpace
				+ (controls > 0 and controls + 10 or 0) + padding.PaddingLeft.Offset + padding.PaddingRight.Offset
			minimum = math.ceil(minimum)
			float.ContentWidths = float.ContentWidths or setmetatable({}, { __mode = "k" })
			if float.ContentWidths[row] ~= minimum then
				float.ContentWidths[row] = minimum
				if float.RequestPosition then float.RequestPosition() end
			end
		end
		if hintMark then
			local hintWidth = hintMark.Size.X.Offset
			local gap = 8
			local maxTextWidth = math.max(0, available - hintWidth - gap)

			local measured = MeasureRenderedTextWidth(text, text.Text)
			local textWidth = math.min(math.ceil(measured) + (float and float.FitContents and 2 or 0), maxTextWidth)
			text.Size = UDim2.new(0, math.max(0, textWidth), 1, 0)
			hintMark.Position = UDim2.new(0, textWidth + gap, 0.5, -1)
		else
			text.Size = UDim2.new(1, 0, 1, 0)
		end
	end
	Track(left:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncInlineLabel))
	Track(text:GetPropertyChangedSignal("TextBounds"):Connect(syncInlineLabel))
	task.defer(syncInlineLabel)

	right = New("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = row,
	})
	local rightList = List(right, 8, Enum.FillDirection.Horizontal)
	rightList.VerticalAlignment = Enum.VerticalAlignment.Center
	rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right

	local owner = self
	local function syncRow()
		local s = GetFrameOffsetScale(right)
		local w = right.AbsoluteSize.X / s
		left.Size = UDim2.new(1, -(21 + (w > 0 and w + 10 or 0)), 1, 0)
		task.defer(syncInlineLabel)
	end
	Track(right:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncRow))
	syncRow()

	local pickerCount = 0
	local api = { Instance = row, State = state, Pickers = {} }

	local function render(animate)
		if fillMotion then
			fillMotion:Cancel()
			fillMotion = nil
		end
		local info = animate and TweenInfo.new(0.18, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
			or TweenInfo.new(0)

		local dimmed = api.Enabled == false and api.Dimmed == true
		local textKey = dimmed and "TextDim" or "Text"
		local strokeKey = state and "Accent" or "Border"
		if not customLabel then
			Library:Tag(text, { TextColor3 = textKey })
			Tween(text, { TextColor3 = Theme[textKey] }, info)
		end
		Library:Tag(boxStroke, { Color = strokeKey })
		Tween(boxStroke, {
			Color = Theme[strokeKey],
			Transparency = state and 1 or 0,
		}, info)

		fill.Visible = true
		if not animate then
			fillScale.Scale = state and 1 or 0
			fill.Visible = state
			return
		end

		fillMotion = TweenService:Create(fillScale, info, { Scale = state and 1 or 0 })
		local motion = fillMotion
		motion.Completed:Once(function(status)
			if fillMotion ~= motion then
				return
			end
			fillMotion = nil
			if status == Enum.PlaybackState.Completed and not state then
				fill.Visible = false
			end
		end)
		motion:Play()
	end

	function api:SetInputEnabled(value, dim)
		api.Enabled = value ~= false
		api.Dimmed = not api.Enabled and dim == true
		hit.Visible = api.Enabled
		local textKey = api.Dimmed and "TextDim" or "Text"
		local strokeKey = state and "Accent" or "Border"
		if not customLabel then
			Library:Tag(text, { TextColor3 = textKey })
			Tween(text, { TextColor3 = Theme[textKey] }, EASE_FAST)
		end
		Library:Tag(boxStroke, { Color = strokeKey })
		Tween(boxStroke, {
			Color = Theme[strokeKey],
			Transparency = state and 1 or 0,
		}, EASE_FAST)
		return api
	end

	function api:Set(value, silent)
		state = value and true or false
		api.State = state
		if flag then
			Library.Flags[flag] = state
			Library:MarkDirty(flag)
		end
		render(true)
		Library:RefreshHotkeys()
		if not silent then
			Library.LastToggleInteraction = {
				Api = api,
				Flag = flag,
				State = state,
				At = os.clock(),
			}
			Library:SafeCallback(opts.Text or "toggle", opts.Callback, state)
		end
	end

	Track(hit.Activated:Connect(function()
		if api.Enabled == false then
			return
		end
		api:Set(not state)
	end))
	Track(hit.MouseEnter:Connect(function()
		if customLabel or api.Enabled == false then
			return
		end
		Tween(text, { TextColor3 = Theme.TextBright }, EASE_FAST)
	end))
	Track(hit.MouseLeave:Connect(function()
		if customLabel then
			return
		end
		local textKey = api.Dimmed and "TextDim" or "Text"
		Library:Tag(text, { TextColor3 = textKey })
		Tween(text, { TextColor3 = Theme[textKey] }, EASE_FAST)
	end))

	function api:Keybind(bindOpts)
		bindOpts = bindOpts or {}
		local key = bindOpts.Default
		local mode = string.lower(bindOpts.Mode or "toggle")
		if mode == "press" then
			mode = "toggle"
		end
		if mode ~= "toggle" and mode ~= "hold" and mode ~= "always" then
			mode = "toggle"
		end
		local pill = New("TextButton", {
			Size = UDim2.fromOffset(52, 20),
			AutomaticSize = Enum.AutomaticSize.None,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			LayoutOrder = 20,
			Parent = right,
		})

		Pad(pill, 0, 2)

		local bindTextGroup = New("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			GroupTransparency = 0,
			Parent = pill,
		})
		local pl = Label(bindTextGroup, "", Theme.TextDim, Theme.TextSize - 2)
		pl.Size = UDim2.fromScale(1, 1)
		pl.TextXAlignment = Enum.TextXAlignment.Right

		local bindFlag = bindOpts.Flag
		if bindFlag == nil and flag then
			bindFlag = tostring(flag) .. "__keybind"
		elseif bindFlag == false then
			bindFlag = nil
		end
		local listening = false
		local releaseEscapeCapture
		local pillWidthTween
		local pillWidthInitialized = false
		local bindTextFadeTicket = 0
		local bindTextFadeTween
		local bindTextInitialized = false
		local displayedBindText

		local function measurePillWidth(richText)
			local plainText = tostring(richText or ""):gsub("<[^>]->", "")
			local width

			local ok = pcall(function()
				local params = Instance.new("GetTextBoundsParams")
				params.Text = plainText
				params.Font = pl.FontFace
				params.Size = pl.TextSize
				params.Width = 10000
				width = TextService:GetTextBoundsAsync(params).X
			end)

			if not ok or type(width) ~= "number" then
				width = TextService:GetTextSize(plainText, pl.TextSize, pl.Font, Vector2.new(10000, 20)).X
			end

			return math.max(20, math.ceil(width) + 4)
		end

		local function tweenPillWidth(richText)
			local targetWidth = measurePillWidth(richText)
			local targetHeight = math.max(20, math.ceil(pl.TextSize) + 6)

			if pillWidthTween then
				pillWidthTween:Cancel()
				pillWidthTween = nil
			end

			if not pillWidthInitialized then
				pillWidthInitialized = true
				pill.Size = UDim2.fromOffset(targetWidth, targetHeight)
				return
			end

			if math.abs(pill.Size.X.Offset - targetWidth) <= 1 and pill.Size.Y.Offset == targetHeight then
				return
			end

			pillWidthTween = TweenService:Create(
				pill,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(targetWidth, targetHeight) }
			)
			pillWidthTween:Play()
		end

		local syncBindText, pulseKeybind = BindTextMotion(pill, pl,
			function() return listening end, function() return api.Enabled ~= false end)

		local function refresh(skipStateWrite)
			local bindText = KeybindDisplay(key, listening)
			syncBindText(skipStateWrite)

			if bindFlag and not skipStateWrite then
				Library.Flags[bindFlag] = key or ""
				Library:MarkDirty(bindFlag)
			end
			Library:RefreshHotkeys()

			if skipStateWrite or not bindTextInitialized then
				bindTextFadeTicket += 1
				if bindTextFadeTween then
					bindTextFadeTween:Cancel()
					bindTextFadeTween = nil
				end
				bindTextInitialized = true
				displayedBindText = bindText
				pl.Text = bindText
				bindTextGroup.GroupTransparency = 0
				tweenPillWidth(bindText)
				return
			end

			bindTextFadeTicket += 1
			local ticket = bindTextFadeTicket
			if bindTextFadeTween then
				bindTextFadeTween:Cancel()
				bindTextFadeTween = nil
			end
			if displayedBindText == bindText then
				bindTextGroup.GroupTransparency = 0
				return
			end

			bindTextFadeTween = TweenService:Create(
				bindTextGroup,
				TweenInfo.new(0.045, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ GroupTransparency = 0.65 }
			)

			bindTextFadeTween.Completed:Once(function(status)
				if
					status ~= Enum.PlaybackState.Completed
					or ticket ~= bindTextFadeTicket
					or not bindTextGroup.Parent
				then
					return
				end

				displayedBindText = bindText
				pl.Text = bindText
				tweenPillWidth(bindText)
				bindTextGroup.GroupTransparency = 0.65

				bindTextFadeTween = TweenService:Create(
					bindTextGroup,
					TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ GroupTransparency = 0 }
				)

				bindTextFadeTween.Completed:Once(function()
					if ticket == bindTextFadeTicket then
						bindTextFadeTween = nil
					end
				end)

				bindTextFadeTween:Play()
			end)

			bindTextFadeTween:Play()
		end

		Library:RegisterHotkey(function()
			return {
				Label = opts.Text or "toggle",
				Key = key,
				Mode = mode,
				Active = mode == "always" or state,
				Visible = key ~= nil,
			}
		end)

		for _, property in { "FontFace", "TextSize" } do
			Track(pl:GetPropertyChangedSignal(property):Connect(function()
				tweenPillWidth(pl.Text)
			end))
		end

		refresh()
		Library:OnRepaint(function()
			refresh(true)
		end, pill)

		if bindFlag then
			Library:Register(bindFlag, {
				Type = "Keybind",
				Get = function()
					return key or ""
				end,
				Set = function(v)
					key = (v ~= "" and v) or nil
					listening = false
					if releaseEscapeCapture then
						releaseEscapeCapture()
						releaseEscapeCapture = nil
					end
					refresh()
				end,
			})
		end

		Track(pill.Activated:Connect(function()
			if releaseEscapeCapture then
				releaseEscapeCapture()
			end
			listening = true
			Library.Binding = true
			refresh()
			releaseEscapeCapture = CaptureEscapeForKeybind(function()
				if not listening then
					return
				end
				key = nil
				listening = false
				Library.Binding = false
				releaseEscapeCapture = nil
				refresh()
			end)
		end))
		Track(UserInputService.InputBegan:Connect(function(input, gpe)
			local name = KeyName(input)
			if listening then
				if input.KeyCode == Enum.KeyCode.Escape then
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					listening = false
					Library.Binding = false
					if releaseEscapeCapture then
						releaseEscapeCapture()
						releaseEscapeCapture = nil
					end
					refresh()
					return
				end
				if not name then
					return
				end
				key = name
				listening = false
				Library.Binding = false
				if releaseEscapeCapture then
					releaseEscapeCapture()
					releaseEscapeCapture = nil
				end
				refresh()
				pulseKeybind()
				return
			end
			if gpe or BindingInputBlocked(input) or api.Enabled == false or not key or name ~= key or mode == "always" then
				return
			end
			pulseKeybind()
			if mode == "hold" then
				api:Set(true)
			else
				api:Set(not state)
			end
		end))
		Track(UserInputService.InputEnded:Connect(function(input)
			if not CapturedBindingInputs[input] and mode == "hold" and key and KeyName(input) == key then
				pulseKeybind()
				api:Set(false)
			end
		end))

		local function setMode(nextMode)
			nextMode = string.lower(tostring(nextMode or ""))
			if nextMode ~= "toggle" and nextMode ~= "hold" and nextMode ~= "always" then
				return
			end
			local previous = mode
			mode = nextMode
			if bindFlag then
				Library:MarkDirty(tostring(bindFlag) .. "__mode")
			end
			if mode == "always" then
				api:Set(true)
			elseif previous == "always" then
				api:Set(false)
			else
				Library:RefreshHotkeys()
			end
		end
		if bindFlag then
			Library:Register(tostring(bindFlag) .. "__mode", {
				Type = "KeybindMode",
				Get = function()
					return mode
				end,
				Set = setMode,
			})
		end
		AttachKeybindModeMenu(owner, pill, function()
			return mode
		end, setMode)
		if mode == "always" and not state then
			api:Set(true, true)
		end
		return api
	end

	function api:ColorPicker(pickerOpts)
		pickerOpts = pickerOpts or {}
		pickerCount = pickerCount + 1
		local swatch = ColorSwatch(right, {
			Size = UDim2.fromOffset(24, 13),
			BackgroundColor3 = pickerOpts.Default or Color3.fromRGB(255, 255, 255),
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			LayoutOrder = pickerCount,
			Parent = right,
		})
		local picker = BuildColorPicker(owner, swatch, pickerOpts)
		api.Pickers[pickerCount] = picker
		return api
	end

	function api:Gear(builder)
		local gearSize = 16
		local gearResolved = ResolveIcon("settings", gearSize)
		local gear = New("ImageButton", {
			Size = UDim2.fromOffset(gearSize, gearSize),
			BackgroundTransparency = 1,
			Image = gearResolved and gearResolved.Image or Theme.GearIcon,
			ImageColor3 = Theme.TextDim,
			LayoutOrder = 30,
			Parent = right,
			ThemeTag = { ImageColor3 = "TextDim" },
		})
		if gearResolved then
			if gearResolved.RectOffset then
				gear.ImageRectOffset = gearResolved.RectOffset
			end
			if gearResolved.RectSize then
				gear.ImageRectSize = gearResolved.RectSize
			end
		end
		local panel = owner.Window:CreateFloating(190, false, owner.Float)
		panel.KeepInsideWindow = true
		panel.FitContents = true
		local gearPrefix = tostring(flag or opts.Text or "toggle") .. "."
		local content = NewContainer(owner.Window, panel.Content, panel, gearPrefix)
		if builder then
			builder(content)
		end
		Track(gear.MouseEnter:Connect(function()
			Tween(gear, { ImageColor3 = Theme.TextBright }, EASE_FAST)
		end))
		Track(gear.MouseLeave:Connect(function()
			Tween(gear, { ImageColor3 = Theme.TextDim }, EASE_FAST)
		end))
		Track(gear.Activated:Connect(function()
			owner.Window:ToggleFloating(panel, gear)
		end))
		return api
	end

	Disableable(api, { text, boxStroke }, opts)

	if flag then
		Library.Flags[flag] = state
		Library:Register(flag, {
			Type = "Toggle",
			Api = api,
			Get = function()
				return state
			end,
			Set = function(v)
				api:Set(v == true)
			end,
		})
	end
	render(false)
	if state then
		Library:SafeCallback(opts.Text or "toggle", opts.Callback, state)
	end
	return api
end

function Elements:Dropdown(opts)
	opts = opts or {}
	local flag = FlagOf(opts, self)
	local values = opts.Options or {}
	local multi = opts.Multi == true
	local selected = multi and (opts.Default or {}) or opts.Default or values[1]
	local ownerWindow = self.Window

	local block = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	List(block, 5)

	local caption
	if opts.Text then
		caption = Label(block, opts.Text, (LabelColor(opts, Theme.Text)))
		caption.Size = UDim2.new(1, 0, 0, 15)
	end

	local shell = New("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Field,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = block,
		ThemeTag = { BackgroundColor3 = "Field" },
	})
	Corner(shell, 5)
	local shellStroke = Stroke(shell, Theme.Border)

	local button = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = shell,
	})
	local value = Label(button, "", Theme.TextBright)
	value.Position = UDim2.fromOffset(10, 0)
	value.Size = UDim2.new(1, -36, 1, 0)
	value.TextTruncate = Enum.TextTruncate.AtEnd
	local chev = Chevron(button, Theme.Text)
	chev.AnchorPoint = Vector2.new(1, 0.5)
	chev.Position = UDim2.new(1, -10, 0.5, 0)

	local panel = New("Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Theme.Field,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = shell,
		ThemeTag = { BackgroundColor3 = "Field" },
	})

	local panelTopPadding = tonumber(opts.PanelTopPadding) or 0
	local panelBottomPadding = tonumber(opts.PanelBottomPadding) or 0

	local content = New("Frame", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = panel,
	})
	List(content, 4)
	Pad(content, panelTopPadding, 0, panelBottomPadding, 0)

	local searchField = New("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = Theme.FieldHover,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = 1,
		Visible = false,
		Parent = content,
		ThemeTag = { BackgroundColor3 = "FieldHover" },
	})
	Corner(searchField, 4)
	Stroke(searchField, Theme.BorderSoft)
	local searchBox = New("TextBox", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "search",
		PlaceholderColor3 = Theme.TextDim,
		TextColor3 = Theme.TextBright,
		TextSize = Theme.TextSize,
		Font = Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = searchField,
		ThemeTag = { PlaceholderColor3 = "TextDim", TextColor3 = "TextBright" },
	})

	local scroller = New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 24),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ScrollBarThickness = 0,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ClipsDescendants = true,
		Parent = content,
	})

	List(scroller, 0)

	local api = { Instance = block, Open = false, Options = values }
	InlineDropdowns[shell] = api
	Track(shell.Destroying:Connect(function()
		InlineDropdowns[shell] = nil
		if ownerWindow.OpenInlineDropdown == api then
			ownerWindow.OpenInlineDropdown = nil
		end
	end))
	local rows = {}
	local sizeTween
	local shellColorTween
	local panelHeight = 0
	local openHeight = 26
	local resizeShell
	local resizeTicket = 0
	local openingRevealPending = false
	local resettingSearch = false

	local function display()
		if multi then
			if #selected == 0 then
				return opts.Empty or "none"
			end
			return table.concat(selected, ", ")
		end
		return tostring(selected or opts.Empty or "none")
	end

	local function isPicked(v)
		if multi then
			for _, x in selected do
				if x == v then
					return true
				end
			end
			return false
		end
		return selected == v
	end

	local function refresh()
		value.Text = display()
		local colorTags = opts.ValueColorTags
		local valueKey = colorTags and colorTags[selected] or "TextBright"
		Library:Tag(value, { TextColor3 = valueKey })
		Tween(value, { TextColor3 = Theme[valueKey] }, EASE_FAST)
		for v, row in rows do
			local picked = isPicked(v)
			local rowKey = colorTags and colorTags[v] or (picked and "AccentSoft" or "Text")
			Library:Tag(row.Text, { TextColor3 = rowKey })
			Tween(row.Text, { TextColor3 = Theme[rowKey] }, EASE_FAST)
		end
		if flag then
			Library.Flags[flag] = selected
			Library:MarkDirty(flag)
		end
	end

	local function calculateHeight(shown)
		local rowContentHeight = math.max(shown, 1) * 26
		local rowsHeight = math.min(rowContentHeight, opts.MaxHeight or 156)
		scroller.Size = UDim2.new(1, 0, 0, rowsHeight)
		scroller.CanvasSize = UDim2.new(0, 0, 0, rowContentHeight)

		panelHeight = rowsHeight + panelTopPadding + panelBottomPadding + (searchField.Visible and 28 or 0)
		openHeight = 26 + panelHeight
		panel.Size = UDim2.new(1, 0, 0, panelHeight)
		return openHeight
	end

	local function applyFilter(animateResize, layoutOnly)
		local query = searchField.Visible and string.lower(searchBox.Text) or ""
		local shown = 0
		local lastVisible
		for _, v in values do
			local row = rows[v]
			if row then
				local visible = query == "" or string.find(string.lower(tostring(v)), query, 1, true) ~= nil
				row.Button.Visible = visible
				row.BottomSquare.Visible = true
				if visible then
					lastVisible = row
					shown = shown + 1
				end
			end
		end
		if lastVisible then
			lastVisible.BottomSquare.Visible = false
		end
		calculateHeight(shown)
		if api.Open and not layoutOnly then
			local info = animateResize and TweenInfo.new(0.18, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
				or TweenInfo.new(0)
			resizeShell(openHeight, info)
		end
	end

	local optionFadeTweens = {}
	local function fadeOptions(alpha, duration)
		for _, tween in optionFadeTweens do
			pcall(function()
				tween:Cancel()
			end)
		end
		table.clear(optionFadeTweens)
		local info = TweenInfo.new(duration or 0.14, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
		for _, row in rows do
			if row.Button.Visible then
				local tween = Tween(row.Text, { TextTransparency = alpha }, info)
				if tween then
					table.insert(optionFadeTweens, tween)
				end
			end
		end
		if searchField.Visible then
			local tween = Tween(searchBox, { TextTransparency = alpha }, info)
			if tween then
				table.insert(optionFadeTweens, tween)
			end
		end
	end

	resizeShell = function(height, info)
		resizeTicket = resizeTicket + 1
		local ticket = resizeTicket
		if sizeTween then
			sizeTween:Cancel()
			sizeTween = nil
		end
		local function reveal()
			if ticket == resizeTicket and api.Open and openingRevealPending then
				openingRevealPending = false
				fadeOptions(0, info.Time <= 0 and 0 or 0.12)
			end
		end
		if info.Time <= 0 then
			shell.Size = UDim2.new(1, 0, 0, height)
			reveal()
			return
		end
		sizeTween = Tween(shell, { Size = UDim2.new(1, 0, 0, height) }, info)
		reveal()
	end

	function api:SetOpen(state, immediate)
		state = state == true
		if state == self.Open then
			return self
		end
		if state and ownerWindow.OpenInlineDropdown and ownerWindow.OpenInlineDropdown ~= self then
			ownerWindow.OpenInlineDropdown:SetOpen(false)
		end
		self.Open = state
		openingRevealPending = state
		if self.OnOpenChanged then
			pcall(self.OnOpenChanged, state)
		end
		if state then
			ownerWindow.OpenInlineDropdown = self
		elseif ownerWindow.OpenInlineDropdown == self then
			ownerWindow.OpenInlineDropdown = nil
		end

		if sizeTween then
			sizeTween:Cancel()
			sizeTween = nil
		end

		local info = immediate and TweenInfo.new(0)
			or TweenInfo.new(state and 0.22 or 0.19, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

		if state then
			resettingSearch = true
			searchBox.Text = ""
			resettingSearch = false
			applyFilter(false, true)
			for _, row in rows do
				row.Text.TextTransparency = 1
			end
			if searchField.Visible then
				searchBox.TextTransparency = 1
			end
			if shellColorTween then
				shellColorTween:Cancel()
			end
			Library:Tag(shell, { BackgroundColor3 = "FieldHover" })
			shellColorTween = Tween(shell, { BackgroundColor3 = Theme.FieldHover }, EASE_FAST)
			Tween(chev, { Rotation = 180 }, TweenInfo.new(0.18, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out))
			resizeShell(openHeight, info)
		else
			if shellColorTween then
				shellColorTween:Cancel()
			end
			Library:Tag(shell, { BackgroundColor3 = "Field" })
			shellColorTween = Tween(shell, { BackgroundColor3 = Theme.Field }, EASE_FAST)
			Tween(chev, { Rotation = 0 }, TweenInfo.new(0.16, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out))
			for _, row in rows do
				SetGroupTransparency(row.Highlight, 1)
			end
			fadeOptions(1, immediate and 0 or 0.12)
			resizeShell(26, info)
		end
		return self
	end

	function api:ToggleOpen()
		return self:SetOpen(not self.Open)
	end

	local function build()
		for _, row in rows do
			row.Button:Destroy()
		end
		searchField.Visible = opts.Search == true or (opts.Search ~= false and #values > 8)
		rows = {}
		for i, v in values do
			local item = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = Theme.AccentSoft,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
				LayoutOrder = i,
				Parent = scroller,
				ThemeTag = { BackgroundColor3 = "AccentSoft" },
			})
			local highlight = New("CanvasGroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				GroupTransparency = 1,
				Parent = item,
			})
			local fill = New("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.AccentSoft,
				BorderSizePixel = 0,
				Parent = highlight,
				ThemeTag = { BackgroundColor3 = "AccentSoft" },
			})
			Corner(fill, 5)
			local function squareEdge(bottom)
				return New("Frame", {
					Size = UDim2.new(1, 0, 0, 5),
					AnchorPoint = Vector2.new(0, bottom and 1 or 0),
					Position = UDim2.fromScale(0, bottom and 1 or 0),
					BackgroundColor3 = Theme.AccentSoft,
					BorderSizePixel = 0,
					Parent = highlight,
					ThemeTag = { BackgroundColor3 = "AccentSoft" },
				})
			end
			 squareEdge(false)
			local bottomSquare = squareEdge(true)
			local il = Label(item, tostring(v), Theme.Text)
			if openingRevealPending then
				il.TextTransparency = 1
			end
			il.Position = UDim2.fromOffset(10, -1)
			il.Size = UDim2.new(1, -20, 1, 0)
			rows[v] = { Button = item, Text = il, Highlight = highlight, BottomSquare = bottomSquare }

			HoverResets[item] = function()
				SetGroupTransparency(highlight, 1)
			end
			Track(item.Destroying:Connect(function()
				HoverResets[item] = nil
			end))

			Track(item.MouseEnter:Connect(function()
				if not api.Open or not IsInteractive(item) then
					return
				end
				TweenGroupTransparency(highlight, 0.94,
					TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
			end))
			Track(item.MouseLeave:Connect(function()
				TweenGroupTransparency(highlight, 1,
					TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
			end))
			Track(item.Activated:Connect(function()
				if multi then
					local found
					for idx, x in selected do
						if x == v then
							found = idx
							break
						end
					end
					if found then
						table.remove(selected, found)
					else
						table.insert(selected, v)
					end
				else
					selected = v
					api:SetOpen(false)
				end
				refresh()
				Library:SafeCallback(opts.Text or "dropdown", opts.Callback, selected)
			end))
		end
		applyFilter(false)
	end

	Track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if resettingSearch then
			return
		end
		applyFilter(true)
	end))
	Track(button.Activated:Connect(function()
		if api.Enabled == false then
			return
		end
		api:ToggleOpen()
	end))
	Track(button.MouseEnter:Connect(function()
		if api.Open then
			return
		end
		if shellColorTween then
			shellColorTween:Cancel()
		end
		Library:Tag(shell, { BackgroundColor3 = "FieldHover" })
		shellColorTween = Tween(shell, { BackgroundColor3 = Theme.FieldHover }, EASE_FAST)
	end))
	Track(button.MouseLeave:Connect(function()
		if api.Open then
			return
		end
		if shellColorTween then
			shellColorTween:Cancel()
		end
		Library:Tag(shell, { BackgroundColor3 = "Field" })
		shellColorTween = Tween(shell, { BackgroundColor3 = Theme.Field }, EASE_FAST)
	end))

	function api:Set(v, silent)
		selected = v
		refresh()
		if not silent then
			Library:SafeCallback(opts.Text or "dropdown", opts.Callback, selected)
		end
	end

	function api:Get()
		return selected
	end

	function api:SetOptions(newValues)
		values = newValues or {}
		self.Options = values
		if not multi then
			local stillExists = false
			for _, candidate in values do
				if candidate == selected then
					stillExists = true
					break
				end
			end
			if not stillExists then
				selected = values[1]
			end
		end
		build()
		refresh()
		return self
	end

	build()
	refresh()
	Disableable(api, { value, caption, shellStroke }, opts)
	Library:OnRepaint(function()
		refresh()
		if shellColorTween then
			shellColorTween:Cancel()
			shellColorTween = nil
		end
		local shellKey = api.Open and "FieldHover" or "Field"
		Library:Tag(shell, { BackgroundColor3 = shellKey })
		SetVisual(shell, "BackgroundColor3", Theme[shellKey])
		SetVisual(panel, "BackgroundColor3", Theme.Field)
	end, shell)

	if flag then
		Library:Register(flag, {
			Type = multi and "MultiDropdown" or "Dropdown",
			Api = api,
			Get = function()
				if not multi then
					return selected
				end
				local copy = {}
				for i, v in selected do
					copy[i] = v
				end
				return copy
			end,
			Set = function(v)
				if multi and type(v) ~= "table" then
					v = { v }
				end
				api:Set(v)
			end,
		})
	end
	return api
end
function Elements:Slider(opts)
	opts = opts or {}
	local flag = FlagOf(opts, self)
	local min = opts.Min or 0
	local max = opts.Max or 100
	local decimals = opts.Decimals or 0
	local value = math.clamp(opts.Default or min, min, max)

	local block = New("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})

	local head = New("Frame", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Parent = block,
	})
	local headList = List(head, 8, Enum.FillDirection.Horizontal)
	headList.VerticalAlignment = Enum.VerticalAlignment.Center

	local name = Label(head, opts.Text or "slider", (LabelColor(opts, Theme.Text)))
	name.Size = UDim2.fromOffset(0, 16)
	name.AutomaticSize = Enum.AutomaticSize.X

	local valueBox = New("TextBox", {
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Theme.TextDim,
		TextSize = 12,
		Font = Theme.Font,
		PlaceholderColor3 = Theme.TextDim,
		ClearTextOnFocus = true,
		LayoutOrder = 2,
		Parent = head,
		ThemeTag = { TextColor3 = "TextDim", PlaceholderColor3 = "TextDim" },
	})

	local valueLabel = valueBox

	local track = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 0, 24),
		BackgroundColor3 = Theme.Track,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = block,
		ThemeTag = { BackgroundColor3 = "Track" },
	})
	Corner(track, 2)
	local fill = New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
		ThemeTag = { BackgroundColor3 = "Accent" },
	})
	Corner(fill, 2)
	local sliderFillGlow = Shadow(fill, Theme.Accent, 0.72, 6, UDim2.fromOffset(1, 1), UDim2.fromOffset(0, 0), 0)
	if sliderFillGlow then
		Library:Tag(sliderFillGlow, { Color = "Accent" })
	end
	local knob = New("Frame", {
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
		ThemeTag = { BackgroundColor3 = "Accent" },
	})
	Corner(knob, 5)
	local sliderKnobGlow = Shadow(knob, Theme.Accent, 0.56, 8, UDim2.fromOffset(2, 2), UDim2.fromOffset(0, 0), 0)
	if sliderKnobGlow then
		Library:Tag(sliderKnobGlow, { Color = "Accent" })
	end

	local hit = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 15),
		Position = UDim2.new(0, 0, 0, 16),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = block,
	})

	local api = { Instance = block, Value = value }

	local function format(v)
		if opts.ZeroText and v == min then
			return opts.ZeroText
		end
		local s = decimals > 0 and string.format("%." .. decimals .. "f", v) or tostring(math.floor(v + 0.5))
		return s .. (opts.Suffix or "")
	end

	local function sliderPixelGeometry(alpha)
		alpha = math.clamp(alpha, 0, 1)

		local absoluteSize = track.AbsoluteSize
		if absoluteSize.X <= 0 or absoluteSize.Y <= 0 then
			return UDim2.new(alpha, 0, 0.5, 0), UDim2.fromScale(alpha, 1)
		end

		local scale = math.max(GetFrameOffsetScale(track), 0.0001)
		local left = track.AbsolutePosition.X
		local top = track.AbsolutePosition.Y

		local centerScreenX = math.floor(left + absoluteSize.X * alpha + 0.5)
		local centerScreenY = math.floor(top + absoluteSize.Y * 0.5 + 0.5)

		local localX = (centerScreenX - left) / scale
		local localY = (centerScreenY - top) / scale

		return UDim2.fromOffset(localX, localY), UDim2.new(0, localX, 1, 0)
	end

	local function render(v, animate)
		local alpha = (max - min) == 0 and 0 or (v - min) / (max - min)
		local info = animate and EASE_FAST or TweenInfo.new(0)
		local knobPosition, fillSize = sliderPixelGeometry(alpha)

		Tween(fill, { Size = fillSize }, info)
		Tween(knob, { Position = knobPosition }, info)
		valueBox.Text = format(v)
	end

	Track(track:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		render(value, false)
	end))

	Track(valueBox.Focused:Connect(function()
		valueBox.Text = tostring(math.floor(value * 10 ^ decimals + 0.5) / 10 ^ decimals)
		valueBox.TextColor3 = Theme.TextBright
	end))

	Track(valueBox.FocusLost:Connect(function(entered)
		valueBox.TextColor3 = Theme.TextDim
		if entered then
			local num = tonumber(valueBox.Text)
			if num then
				api:Set(num)
			else
				render(value, false)
			end
		else
			render(value, false)
		end
	end))

	function api:Set(v, silent)
		v = math.clamp(v, min, max)
		if opts.Step then
			v = min + math.floor((v - min) / opts.Step + 0.5) * opts.Step
		end
		if decimals == 0 then
			v = math.floor(v + 0.5)
		end
		value = v
		api.Value = v
		if flag then
			Library.Flags[flag] = v
			Library:MarkDirty(flag)
		end
		render(v, true)
		if not silent then
			Library:SafeCallback(opts.Text or "slider", opts.Callback, v)
		end
	end

	local dragging, moveConn, endConn

	local function fromX(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		api:Set(min + (max - min) * alpha)
	end

	Track(hit.InputBegan:Connect(function(input)
		if not IsInteractive(hit) then
			return
		end
		if api.Enabled == false then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		dragging = true
		fromX(input.Position.X)
		moveConn = UserInputService.InputChanged:Connect(function(move)
			if
				move.UserInputType == Enum.UserInputType.MouseMovement
				or move.UserInputType == Enum.UserInputType.Touch
			then
				if dragging then
					fromX(move.Position.X)
				end
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(ended)
			if ended.UserInputType == input.UserInputType then
				dragging = false
				if moveConn then
					moveConn:Disconnect()
					moveConn = nil
				end
				if endConn then
					endConn:Disconnect()
					endConn = nil
				end
			end
		end)
	end))

	Disableable(api, { name, valueLabel }, opts)

	if flag then
		Library.Flags[flag] = value
		Library:Register(flag, {
			Type = "Slider",
			Get = function()
				return value
			end,
			Set = function(v)
				api:Set(tonumber(v) or min)
			end,
		})
	end
	render(value, false)
	return api
end

function BuildColorPicker(owner, swatch, opts)
	opts = opts or {}
	local flag = FlagOf(opts, self)
	local useAlpha = opts.Alpha ~= false
	local base = opts.Default or Color3.fromRGB(255, 255, 255)
	local alpha = opts.DefaultAlpha or 1
	local hue, sat, val = base:ToHSV()

	local panel = owner.Window:CreateFloating(198, false, owner.Float)
	local z = panel.Frame.ZIndex

	local area = New("Frame", {
		Size = UDim2.new(1, 0, 0, 106),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = panel.Content,
	})

	local sv = New("TextButton", {
		Size = UDim2.new(1, -22, 1, 0),
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		ThemeTag = { BackgroundColor3 = false },
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = area,
	})
	Corner(sv, 4)
	local light = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ThemeTag = { BackgroundColor3 = false },
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = sv,
	})
	Corner(light, 4)
	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = light,
	})
	local shade = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		ThemeTag = { BackgroundColor3 = false },
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = sv,
	})
	Corner(shade, 4)
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = shade,
	})
	local svCursor = New("Frame", {
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = sv,
	})
	Corner(svCursor, 5)
	Library:Tag(Stroke(svCursor, Color3.fromRGB(255, 255, 255), 2), { Color = false })

	local hueBar = New("TextButton", {
		Size = UDim2.new(0, 14, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ThemeTag = { BackgroundColor3 = false },
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = area,
	})
	Corner(hueBar, 4)
	New("UIGradient", { Rotation = 90, Color = HUE_SEQUENCE, Parent = hueBar })
	local hueCursor = New("Frame", {
		Size = UDim2.new(1, 4, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ThemeTag = { BackgroundColor3 = false },
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = hueBar,
	})
	Corner(hueCursor, 2)

	local alphaBar, alphaCursor, alphaGradient
	if useAlpha then
		local track = New("Frame", {
			Size = UDim2.new(1, 0, 0, 10),
			BackgroundColor3 = Theme.Track,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			ZIndex = z,
			Parent = panel.Content,
			ThemeTag = { BackgroundColor3 = "Track" },
		})
		Corner(track, 3)
		alphaBar = New("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ThemeTag = { BackgroundColor3 = false },
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = track,
		})
		Corner(alphaBar, 3)
		alphaGradient = New("UIGradient", {
			Color = ColorSequence.new(base),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Parent = alphaBar,
		})
		alphaCursor = New("Frame", {
			Size = UDim2.new(0, 3, 1, 4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			ThemeTag = { BackgroundColor3 = false },
			BorderSizePixel = 0,
			ZIndex = z + 1,
			Parent = alphaBar,
		})
		Corner(alphaCursor, 2)
	end

	local hexField = New("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = Theme.Field,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = 3,
		ZIndex = z,
		Parent = panel.Content,
		ThemeTag = { BackgroundColor3 = "Field" },
	})
	Corner(hexField, 4)
	local hexStroke = Stroke(hexField, Theme.Border)
	local hexBox = New("TextBox", {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		Text = ToHex(base, alpha),
		TextColor3 = Theme.TextBright,
		TextSize = 12,
		Font = Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = z,
		Parent = hexField,
		ThemeTag = { TextColor3 = "TextBright" },
	})

	local api = { Instance = swatch, Swatch = swatch, Color = base, Alpha = alpha }
	local editing = false

	local contextPanel = owner.Window:CreateFloating(128, false, owner.Float)
	contextPanel.Frame.ClipsDescendants = true

	local function closeContext()
		owner.Window:CloseFloatingFrom(contextPanel.Depth)
	end

	local function contextButton(textValue, callback)
		local button = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = Theme.Field,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			Parent = contextPanel.Content,
			ThemeTag = { BackgroundColor3 = "Field" },
		})
		Corner(button, 4)

		local buttonText = Label(button, textValue, Theme.Text, Theme.TextSize - 1)
		buttonText.Position = UDim2.fromOffset(8, 0)
		buttonText.Size = UDim2.new(1, -16, 1, 0)

		Track(button.MouseEnter:Connect(function()
			Tween(button, { BackgroundTransparency = 0.45 }, EASE_FAST)
			Tween(buttonText, { TextColor3 = Theme.TextBright }, EASE_FAST)
		end))

		Track(button.MouseLeave:Connect(function()
			Tween(button, { BackgroundTransparency = 1 }, EASE_FAST)
			Tween(buttonText, { TextColor3 = Theme.Text }, EASE_FAST)
		end))

		Track(button.Activated:Connect(function()
			callback()
			closeContext()
		end))

		return button
	end

	local function current()
		return Color3.fromHSV(hue, sat, val)
	end

	local function render()
		local color = current()
		api.Color = color
		api.Alpha = alpha
		sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svCursor.Position = UDim2.fromScale(sat, 1 - val)
		hueCursor.Position = UDim2.new(0.5, 0, hue, 0)
		swatch.BackgroundColor3 = color
		SetVisual(swatch, "BackgroundTransparency", useAlpha and (1 - alpha) * 0.75 or 0)
		if alphaGradient then
			alphaGradient.Color = ColorSequence.new(color)
			alphaCursor.Position = UDim2.new(alpha, 0, 0.5, 0)
		end
		if not editing then
			hexBox.Text = ToHex(color, alpha)
		end
		if flag then
			Library.Flags[flag] = ToHex(color, alpha)
			Library:MarkDirty(flag)
		end
	end

	local function fire()
		Library:SafeCallback(opts.Text or "color picker", opts.Callback, current(), alpha)
	end

	function api:Set(color, newAlpha, silent)
		local parsed, parsedAlpha = FromHex(color)
		if parsed then
			color = parsed
			newAlpha = newAlpha or parsedAlpha
		end
		if typeof(color) == "Color3" then
			hue, sat, val = color:ToHSV()
		end
		if newAlpha then
			alpha = math.clamp(newAlpha, 0, 1)
		end
		render()
		if not silent then
			fire()
		end
	end

	function api:Get()
		return current(), alpha
	end

	BindDrag(sv, function(position)
		sat = math.clamp((position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		val = 1 - math.clamp((position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		render()
		fire()
	end)

	BindDrag(hueBar, function(position)
		hue = math.clamp((position.Y - hueBar.AbsolutePosition.Y) / math.max(hueBar.AbsoluteSize.Y, 1), 0, 1)
		render()
		fire()
	end)

	if alphaBar then
		BindDrag(alphaBar, function(position)
			alpha = math.clamp((position.X - alphaBar.AbsolutePosition.X) / math.max(alphaBar.AbsoluteSize.X, 1), 0, 1)
			render()
			fire()
		end)
	end

	Track(hexBox.Focused:Connect(function()
		editing = true
		Tween(hexStroke, { Color = Theme.Accent }, EASE_FAST)
	end))
	Track(hexBox.FocusLost:Connect(function()
		editing = false
		Tween(hexStroke, { Color = Theme.Border }, EASE_FAST)
		local parsed, parsedAlpha = FromHex(hexBox.Text)
		if parsed then
			api:Set(parsed, parsedAlpha)
		else
			render()
		end
	end))

	contextButton("copy color", function()
		local value = ToHex(current(), alpha)

		ColorClipboard = value

		pcall(function()
			setclipboard(value)
		end)
	end)

	contextButton("paste color", function()
		if not ColorClipboard then
			Library:Notify({
				Title = "color picker",
				Text = "no copied color yet",
				Style = "warning",
				Duration = 2,
			})
			return
		end

		local parsed, parsedAlpha = FromHex(ColorClipboard)
		if parsed then
			api:Set(parsed, parsedAlpha)
		end
	end)

	Track(swatch.Activated:Connect(function()
		if api.Enabled == false then
			return
		end
		owner.Window:ToggleFloating(panel, swatch)
	end))

	Track(swatch.MouseButton2Click:Connect(function()
		if api.Enabled == false then
			return
		end
		owner.Window:ToggleFloating(contextPanel, swatch)
	end))

	Disableable(api, {}, opts)
	Library:OnRepaint(render, swatch)

	if flag then
		Library.Flags[flag] = ToHex(base, alpha)
		Library:Register(flag, {
			Type = "ColorPicker",
			Get = function()
				return ToHex(current(), alpha)
			end,
			Set = function(v)
				api:Set(v)
			end,
		})
	end

	render()
	return api
end

function ColorSwatch(parent, props)
	local swatch = New("TextButton", props)
	Library:Tag(swatch, { BackgroundColor3 = false })
	Corner(swatch, 3)
	Stroke(swatch, Theme.Border)
	return swatch
end

function Elements:ColorPicker(opts)
	opts = opts or {}
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	local name = Label(row, opts.Text or "color", (LabelColor(opts, Theme.Text)))
	name.Size = UDim2.new(1, -42, 1, 0)
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local swatch = ColorSwatch(row, {
		Size = UDim2.fromOffset(28, 14),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundColor3 = opts.Default or Color3.fromRGB(255, 255, 255),
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = row,
	})

	local api = BuildColorPicker(self, swatch, opts)
	api.Instance = row
	return api
end

function Elements:Keybind(opts)
	opts = opts or {}
	local flag = FlagOf(opts, self)
	local key = opts.Default
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	local name = Label(row, opts.Text or "keybind", (LabelColor(opts, Theme.Text)))
	name.TextSize = Theme.TextSize
	name.Font = Theme.FontMedium
	if Library.FontMediumFace then
		pcall(function()
			name.FontFace = Library.FontMediumFace
		end)
	end
	name.Size = UDim2.new(1, -88, 1, 0)
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local pill = New("TextButton", {
		Size = UDim2.fromOffset(44, 20),
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = row,
	})
	Pad(pill, 0, 2)
	local keyTextGroup = New("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 0,
		Parent = pill,
	})
	local pl = Label(keyTextGroup, "", Theme.TextDim, Theme.TextSize - 2)
	pl.Size = UDim2.fromScale(1, 1)
	pl.AutomaticSize = Enum.AutomaticSize.None
	pl.TextXAlignment = Enum.TextXAlignment.Right
	pl.RichText = true

	local api
	local listening = false
	local releaseEscapeCapture
	local held = false
	local active = opts.Active == true
	local mode = string.lower(opts.Mode or "toggle")
	if mode == "press" then
		mode = "toggle"
	end
	if mode ~= "toggle" and mode ~= "hold" and mode ~= "always" then
		mode = "toggle"
	end

	local keyTextFadeTicket = 0
	local keyTextFadeTween
	local keyTextInitialized = false

	local pillWidthTween
	local pillWidthInitialized = false
	local function applyKeybindText(display)
		local plainText = tostring(display or ""):gsub("<[^>]->", "")
		local targetWidth = math.max(20, math.ceil(MeasureRenderedTextWidth(pl, plainText)) + 4)
		local targetHeight = math.max(20, math.ceil(pl.TextSize) + 6)
		if pillWidthTween then
			pillWidthTween:Cancel()
			pillWidthTween = nil
		end
		if not pillWidthInitialized then
			pillWidthInitialized = true
			pill.Size = UDim2.fromOffset(targetWidth, targetHeight)
		elseif math.abs(pill.Size.X.Offset - targetWidth) > 1 or pill.Size.Y.Offset ~= targetHeight then
			pillWidthTween = TweenService:Create(pill,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(targetWidth, targetHeight) })
			pillWidthTween:Play()
		end
		name.Size = UDim2.new(1, -(targetWidth + 8), 1, 0)
		pl.Text = display
	end

	for _, property in { "FontFace", "TextSize" } do
		Track(pl:GetPropertyChangedSignal(property):Connect(function()
			applyKeybindText(pl.Text)
		end))
	end

	local syncBindText, pulseKeybind = BindTextMotion(pill, pl,
		function() return listening end, function() return not api or api.Enabled ~= false end)

	local function refresh(immediate)
		syncBindText(immediate)
		local display = KeybindDisplay(key, listening)

		if not keyTextInitialized then
			keyTextInitialized = true
			applyKeybindText(display)
			keyTextGroup.GroupTransparency = 0
			return
		end

		keyTextFadeTicket += 1
		local ticket = keyTextFadeTicket
		if keyTextFadeTween then
			keyTextFadeTween:Cancel()
			keyTextFadeTween = nil
		end
		if pl.Text == display or immediate then
			applyKeybindText(display)
			keyTextGroup.GroupTransparency = 0
			return
		end

		keyTextFadeTween = TweenService:Create(
			keyTextGroup,
			TweenInfo.new(0.045, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ GroupTransparency = 0.65 }
		)

		keyTextFadeTween.Completed:Once(function(status)
			if status ~= Enum.PlaybackState.Completed or ticket ~= keyTextFadeTicket or not keyTextGroup.Parent then
				return
			end

			applyKeybindText(display)
			keyTextGroup.GroupTransparency = 0.65

			keyTextFadeTween = TweenService:Create(
				keyTextGroup,
				TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ GroupTransparency = 0 }
			)

			keyTextFadeTween.Completed:Once(function()
				if ticket == keyTextFadeTicket then
					keyTextFadeTween = nil
				end
			end)

			keyTextFadeTween:Play()
		end)

		keyTextFadeTween:Play()
	end
	refresh()

	local isMenuToggleKey = opts.MenuToggle == true
	if isMenuToggleKey then
		local disconnectToggleSync = Library:OnToggleKeyChanged(function(value)
			key = (value ~= nil and value ~= "" and value) or nil
			listening = false
			if releaseEscapeCapture then
				releaseEscapeCapture()
				releaseEscapeCapture = nil
			end
			refresh()
		end)
		Track(row.Destroying:Connect(disconnectToggleSync))
	end

	local function apply()
		if isMenuToggleKey then
			Library:SetToggleKey(key)
		end
		if flag then
			Library.Flags[flag] = key or ""
			Library:MarkDirty(flag)
		end
		Library:RefreshHotkeys()
		Library:SafeCallback(opts.Text or "keybind", opts.OnChanged, key)
	end

	Track(pill.Activated:Connect(function()
		if api and api.Enabled == false then
			return
		end
		if releaseEscapeCapture then
			releaseEscapeCapture()
		end
		listening = true
		Library.Binding = true
		refresh()
		releaseEscapeCapture = CaptureEscapeForKeybind(function()
			if not listening then
				return
			end
			key = nil
			listening = false
			Library.Binding = false
			releaseEscapeCapture = nil
			refresh()
			apply()
		end)
	end))
	Track(UserInputService.InputBegan:Connect(function(input, gpe)
		local n = KeyName(input)
		if listening then
			if input.KeyCode == Enum.KeyCode.Escape then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				listening = false
				Library.Binding = false
				if releaseEscapeCapture then
					releaseEscapeCapture()
					releaseEscapeCapture = nil
				end
				refresh()
				return
			end
			if not n then
				return
			end
			key = n
			listening = false
			Library.Binding = false
			if releaseEscapeCapture then
				releaseEscapeCapture()
				releaseEscapeCapture = nil
			end
			refresh()
			pulseKeybind()
			apply()
			return
		end
		if opts.PlayersToggle and UserInputService:GetFocusedTextBox() then return end
		if gpe or BindingInputBlocked(input) or not key or n ~= key or mode == "always" then
			return
		end
		if api and api.Enabled == false then
			return
		end
		pulseKeybind()
		if mode == "toggle" then
			active = not active
			if api then
				api.Active = active
			end
			Library:RefreshHotkeys()
			Library:SafeCallback(opts.Text or "keybind", opts.Callback, active)
		elseif mode == "hold" then
			held = true
			Library:RefreshHotkeys()
			Library:SafeCallback(opts.Text or "keybind", opts.Callback, true)
		end
	end))
	Track(UserInputService.InputEnded:Connect(function(input)
		if CapturedBindingInputs[input] or mode ~= "hold" or not held then
			return
		end
		if key and KeyName(input) == key then
			held = false
			pulseKeybind()
			Library:RefreshHotkeys()
			Library:SafeCallback(opts.Text or "keybind", opts.Callback, false)
		end
	end))

	api = {
		Instance = row,
		Active = active,
		Mode = mode,
		Get = function()
			return key or ""
		end,
		Set = function(_, k)
			key = (k ~= "" and k) or nil
			listening = false
			if releaseEscapeCapture then
				releaseEscapeCapture()
				releaseEscapeCapture = nil
			end
			refresh()
			apply()
		end,
	}

	if isMenuToggleKey then
		local currentToggle = Library:GetToggleKeyValue()
		if currentToggle and currentToggle ~= "" then
			key = currentToggle
			refresh()
		end
	end

	function api:SetMode(nextMode)
		nextMode = string.lower(tostring(nextMode or ""))
		if opts.PlayersToggle and nextMode ~= "toggle" then return self end
		if nextMode ~= "toggle" and nextMode ~= "hold" and nextMode ~= "always" then
			return self
		end
		local previous = mode
		mode = nextMode
		self.Mode = mode
		held = false
		if flag then
			Library:MarkDirty(tostring(flag) .. "__mode")
		end
		if mode == "always" then
			active = true
			self.Active = true
			Library:SafeCallback(opts.Text or "keybind", opts.Callback, true)
		elseif previous == "always" then
			active = false
			self.Active = false
			Library:SafeCallback(opts.Text or "keybind", opts.Callback, false)
		end
		Library:RefreshHotkeys()
		return self
	end

	if flag then
		Library:Register(tostring(flag) .. "__mode", {
			Type = "KeybindMode",
			Get = function()
				return mode
			end,
			Set = function(v)
				api:SetMode(v)
			end,
		})
	end

	if not opts.PlayersToggle then
		AttachKeybindModeMenu(self, pill, function()
			return mode
		end, function(nextMode)
			api:SetMode(nextMode)
		end)
	end
	Disableable(api, { name, pl }, opts)

	Library:RegisterHotkey(function()
		local isActive = mode == "always" or (mode == "toggle" and active) or (mode == "hold" and held)
		if opts.PlayersToggle then
			isActive = Library.PlayerMenuApi and Library.PlayerMenuApi.Open and Library.PlayerMenuApi.HostVisible or false
		end
		if isMenuToggleKey then
			isActive = Library.Open
		end
		return {
			Label = opts.Text or "keybind",
			Key = key,
			Mode = mode,
			Active = isActive,
			Visible = key ~= nil,
		}
	end)

	Library:OnRepaint(function() refresh(true) end, pill)

	if flag then
		Library.Flags[flag] = key or ""
		Library:Register(flag, {
			Type = "Keybind",
			Get = function()
				return key or ""
			end,
			Set = function(v)
				api:Set(v)
			end,
		})
	end
	if mode == "always" then
		active = true
		api.Active = true
		Library:SafeCallback(opts.Text or "keybind", opts.Callback, true)
	end
	if key then
		apply()
	end
	return api
end

function Elements:Search(opts)
	opts = opts or {}
	local flag = opts.Flag or nil
	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Parent = self.Container,
	})
	local field = New("Frame", {
		Size = UDim2.new(1, -56, 1, 0),
		BackgroundColor3 = Theme.Field,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = row,
		ThemeTag = { BackgroundColor3 = "Field" },
	})
	Corner(field, 5)
	local fStroke = Stroke(field, Theme.Border)
	local box = New("TextBox", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = opts.Default or "",
		PlaceholderText = opts.Placeholder or "",
		PlaceholderColor3 = Theme.TextDim,
		TextColor3 = Theme.TextBright,
		TextSize = Theme.TextSize,
		Font = Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = field,
		ThemeTag = { PlaceholderColor3 = "TextDim", TextColor3 = "TextBright" },
	})
	local side = Label(row, opts.Label or "search", Theme.TextDim)
	side.AnchorPoint = Vector2.new(1, 0.5)
	side.Position = UDim2.new(1, 0, 0.5, 0)
	side.Size = UDim2.fromOffset(48, 18)
	side.TextXAlignment = Enum.TextXAlignment.Right

	Track(box.Focused:Connect(function()
		Tween(fStroke, { Color = Theme.Accent }, EASE_FAST)
	end))
	Track(box.FocusLost:Connect(function(enter)
		Tween(fStroke, { Color = Theme.Border }, EASE_FAST)
		Library:SafeCallback(opts.Text or "input", opts.Callback, box.Text, enter)
	end))
	if opts.Live then
		Track(box:GetPropertyChangedSignal("Text"):Connect(function()
			Library:SafeCallback(opts.Text or "search", opts.Callback, box.Text, false)
		end))
	end

	local api = Disableable({
		Instance = row,
		Box = box,
		Get = function()
			return box.Text
		end,
		Set = function(_, v)
			box.Text = tostring(v or "")
		end,
	}, { box, side }, opts)
	if flag then
		Library.Flags[flag] = box.Text
		Library:Register(flag, {
			Type = "Input",
			Get = function()
				return box.Text
			end,
			Set = function(v)
				box.Text = tostring(v or "")
				Library:SafeCallback(opts.Text or "search", opts.Callback, box.Text, false)
			end,
		})
	end
	return api
end

local Section = setmetatable({}, { __index = Elements })
Section.__index = Section

local function CreateSection(window, parent, title, order)
	local borderTitle = Library.SectionTitleStyle == "border"

	local frame = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Section,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
		ThemeTag = { BackgroundColor3 = "Section" },
	})
	Corner(frame, 7)
	Stroke(frame, Theme.SectionBorder)

	local inner = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Pad(inner, borderTitle and 18 or 12, 14, 14, 14)
	local frameList = List(inner, 0)

	local header, htitle, hchev

	if borderTitle then
		header = New("TextButton", {
			Size = UDim2.fromOffset(0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(12, 0),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 3,
			Parent = frame,
		})
		Pad(header, 0, 6, 0, 6)

		New("Frame", {
			Size = UDim2.new(1, 0, 0, 3),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Theme.Window,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = header,
			ThemeTag = { BackgroundColor3 = "Window" },
		})

		local row = New("Frame", {
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = header,
		})
		local rowList = List(row, 5, Enum.FillDirection.Horizontal)
		rowList.VerticalAlignment = Enum.VerticalAlignment.Center

		htitle = Label(row, title, Theme.TextBright, Theme.TextSize, Theme.FontMedium)
		htitle.Size = UDim2.new(0, 0, 1, 0)
		htitle.AutomaticSize = Enum.AutomaticSize.X
		htitle.ZIndex = 3

		hchev = Chevron(row, Theme.TextDim)
		hchev.LayoutOrder = 2
		hchev.ZIndex = 3
	else
		header = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Parent = inner,
		})
		htitle = Label(header, title, Theme.TextBright, Theme.TextSize + 1, Theme.FontMedium)
		htitle.Size = UDim2.new(1, -16, 1, 0)
		hchev = Chevron(header, Theme.TextDim)
		hchev.AnchorPoint = Vector2.new(0, 0.5)
		hchev.Position = UDim2.new(0, htitle.TextBounds.X + 6, 0.5, 1)
		Track(htitle:GetPropertyChangedSignal("TextBounds"):Connect(function()
			hchev.Position = UDim2.new(0, htitle.TextBounds.X + 6, 0.5, 1)
		end))
	end

	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		LayoutOrder = 2,
		Parent = inner,
	})
	local content = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	})
	List(content, 9)
	 
	Pad(content, 5, 2, 2, 2)

	local self = setmetatable(NewContainer(window, content), Section)
	self.Frame = frame
	self.Open = true

	local sectionSizeMotion
	local sectionChevronMotion
	Track(header.Activated:Connect(function()
		self.Open = not self.Open

		local info = AnimationInfo("Section", not self.Open)
		local baseDuration = info.Time
		local duration = self.Open and baseDuration or (baseDuration * 0.88)
		local fadeDuration = math.min(duration * 0.78, 0.18)
		local scale = math.max(window.Scale.Scale, 0.05)
		local current = body.Visible and body.AbsoluteSize.Y / scale or 0

		local clipBleed = 2 / scale
		local target = self.Open and (content.AbsoluteSize.Y / scale + clipBleed) or 0

		body.Visible = true
		body.ClipsDescendants = true
		body.AutomaticSize = Enum.AutomaticSize.None
		body.Size = UDim2.new(1, 0, 0, current)

		if sectionSizeMotion then
			sectionSizeMotion:Cancel()
		end
		if sectionChevronMotion then
			sectionChevronMotion:Cancel()
		end

		local motionCurve = { 0.22, 1, 0.36, 1 }

		sectionSizeMotion = BezierTween(body, { Size = UDim2.new(1, 0, 0, target) }, duration, motionCurve, function()
			if self.Open then
				body.AutomaticSize = Enum.AutomaticSize.Y
				body.ClipsDescendants = false
			else
				body.Size = UDim2.new(1, 0, 0, 0)
			end
		end)

		sectionChevronMotion =
			BezierTween(hchev, { Rotation = self.Open and 0 or 180 }, math.min(duration, 0.20), motionCurve)

		Fade(body, self.Open, TweenInfo.new(fadeDuration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out))

		window:CloseFloating()
	end))
	Track(header.MouseEnter:Connect(function()
		Tween(htitle, { TextColor3 = Theme.AccentSoft }, EASE_FAST)
	end))
	Track(header.MouseLeave:Connect(function()
		Tween(htitle, { TextColor3 = Theme.TextBright }, EASE_FAST)
	end))

	return self
end

local Column = {}
Column.__index = Column

function Column:Section(title)
	self.Order = self.Order + 1
	return CreateSection(self.Window, self.Frame, title, self.Order)
end

local Tab = {}
Tab.__index = Tab

function Tab:Block()
	if self.CurrentBlock then
		return self.CurrentBlock
	end

	self.Order = self.Order + 1
	local block = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self.Order,
		Parent = self.Page,
	})
	local list = List(block, 14, Enum.FillDirection.Horizontal)
	list.SortOrder = Enum.SortOrder.LayoutOrder

	self.Columns = {}
	for i = 1, 2 do
		local frame = New("Frame", {
			Size = UDim2.new(0.5, -7, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = block,
		})
		List(frame, Library.SectionTitleStyle == "border" and 22 or 14)
		self.Columns[i] = setmetatable({ Window = self.Window, Frame = frame, Order = 0 }, Column)
	end

	self.CurrentBlock = block
	return block
end

function Tab:Column(index)
	self:Block()
	local slot = math.clamp(math.floor(tonumber(index) or 1), 1, #self.Columns)
	return self.Columns[slot]
end

function Tab:Full(title)
	self.Order = self.Order + 1
	local section = CreateSection(self.Window, self.Page, title, self.Order)
	self.CurrentBlock = nil
	return section
end

function Tab:Section(title, columnIndex)
	if columnIndex == "full" or columnIndex == "0" or tonumber(columnIndex) == 0 then
		return self:Full(title)
	end
	return self:Column(columnIndex):Section(title)
end

local Window = {}
Window.__index = Window

function Window:CreateFloating(width, matchAnchor, parent)
	local depth = parent and (parent.Depth + 1) or 1
	local z = self.Blocker.ZIndex + 8 + depth * 4
	local frame = New("Frame", {
		Size = UDim2.fromOffset(width > 0 and width or 160, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.PopupBg,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		ZIndex = z,
		Parent = self.Overlay,
		ThemeTag = { BackgroundColor3 = "PopupBg" },
	})
	Corner(frame, 5)
	Stroke(frame, matchAnchor and Theme.Accent or Theme.PopupBorder)
	local padding = Pad(frame, 9, 10, 10, 10)
	local content = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = frame,
	})
	List(content, 8)
	local panel = {
		Frame = frame,
		Content = content,
		Padding = padding,
		MatchAnchor = matchAnchor,
		Parent = parent,
		Depth = depth,
		BaseWidth = width > 0 and width or 160,
		KeepInsideWindow = parent and parent.KeepInsideWindow or false,
		AnchorConnections = {},
		Open = false,
	}
	local scheduled = false
	local function requestPosition()
		if scheduled or not panel.Open then return end
		scheduled = true
		task.defer(function()
			RunService.RenderStepped:Wait()
			scheduled = false
			if frame.Parent then self:RepositionFloating(panel) end
		end)
	end
	panel.RequestPosition = requestPosition
	Track(frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(requestPosition))
	local overlaySizeConnection = Track(self.Overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(requestPosition))
	frame.Destroying:Once(function()
		overlaySizeConnection:Disconnect()
		for _, connection in panel.AnchorConnections do connection:Disconnect() end
		table.clear(panel.AnchorConnections)
	end)
	return panel
end

function Window:CloseFloatingFrom(depth, immediate)
	for _, hideHint in self.Hints or {} do hideHint(true) end
	local stack = self.FloatStack
	self.ClosingFloats = self.ClosingFloats or {}
	if immediate then
		for panel in self.ClosingFloats do
			if panel.Depth >= depth then
				if panel.Motion then
					panel.Motion:Cancel()
					panel.Motion = nil
				end
				Fade(panel.Frame, false, TweenInfo.new(0))
				self.ClosingFloats[panel] = nil
			end
		end
	end
	while #stack > 0 and stack[#stack].Depth >= depth do
		local panel = table.remove(stack)
		panel.Open = false
		self.ClosingFloats[panel] = true
		local info = immediate and TweenInfo.new(0) or AnimationInfo("Popup", true)
		if panel.Motion then
			panel.Motion:Cancel()
			panel.Motion = nil
		end
		if panel.TargetPosition and not panel.Attached then
			panel.Motion = Tween(panel.Frame, { Position = panel.TargetPosition - UDim2.fromOffset(0, 4) }, info)
		end
		if panel.OnClose then
			panel.OnClose(info)
		end
		Fade(panel.Frame, false, info, function()
			self.ClosingFloats[panel] = nil
			self.Blocker.Visible = #stack > 0 or FirstTableKey(self.ClosingFloats) ~= nil
		end)
	end
	self.Blocker.Visible = #stack > 0 or FirstTableKey(self.ClosingFloats) ~= nil
	RaiseLayerFrame(self.Main)
end

function Window:CloseFloating(immediate)
	for _, hide in self.Hints or {} do
		hide(immediate)
	end
	self:CloseFloatingFrom(1, immediate)
end

function Window:FloatingTarget(panel, anchor, matchWidth)
	local layer = panel.Frame.Parent or self.Overlay
	local scale = GetFrameRenderScale(layer)
	local origin = layer.AbsolutePosition
	local anchorPosition = anchor.AbsolutePosition
	local anchorSize = anchor.AbsoluteSize
	local viewportOrigin, viewport = GetFrameViewportRect(panel.Frame)
	local margin = 8
	if panel.KeepInsideWindow then
		local windowPosition, windowSize = self.Main.AbsolutePosition, self.Main.AbsoluteSize
		local left = math.max(viewportOrigin.X, windowPosition.X)
		local top = math.max(viewportOrigin.Y, windowPosition.Y)
		local right = math.min(viewportOrigin.X + viewport.X, windowPosition.X + windowSize.X)
		local bottom = math.min(viewportOrigin.Y + viewport.Y, windowPosition.Y + windowSize.Y)
		viewportOrigin = Vector2.new(left, top)
		viewport = Vector2.new(math.max(1, right - left), math.max(1, bottom - top))
		margin = math.min(8 * scale, viewport.X * 0.25, viewport.Y * 0.25)
	end
	if matchWidth then
		panel.Frame.Size = UDim2.fromOffset(anchorSize.X / scale, 0)
	elseif panel.FitContents then
		local width = panel.BaseWidth
		for row, minimum in panel.ContentWidths or {} do
			if row.Parent then width = math.max(width, minimum) end
		end
		width = math.min(width, math.max(1, (viewport.X - margin * 2) / scale))
		if panel.Frame.Size.X.Offset ~= width then panel.Frame.Size = UDim2.fromOffset(width, 0) end
	end
	local x = anchorPosition.X
	local y = panel.Attached and anchorPosition.Y or anchorPosition.Y + anchorSize.Y + 4 * scale
	if not panel.Attached then
		local size = GetRenderedOffsetSize(panel.Frame)
		if panel.FitContents then size = Vector2.new(panel.Frame.Size.X.Offset * scale, size.Y) end
		local bottom = viewportOrigin.Y + viewport.Y - margin
		local above = anchorPosition.Y - size.Y - 4 * scale
		if y + size.Y > bottom and above >= viewportOrigin.Y + margin then y = above end
		local position = ClampRectToViewport(Vector2.new(x, y), size, margin, viewport, viewportOrigin)
		x, y = position.X, position.Y
	end
	return UDim2.fromOffset((x - origin.X) / scale, (y - origin.Y) / scale)
end

function Window:RepositionFloating(panel)
	local anchor = panel.Anchor
	if not panel.Open or not anchor or not anchor.Parent or not panel.Frame.Parent then return end
	local target = self:FloatingTarget(panel, anchor, panel.MatchWidth)
	if panel.TargetPosition == target then return end
	if panel.Motion then panel.Motion:Cancel(); panel.Motion = nil end
	panel.TargetPosition = target
	panel.Frame.Position = target
end

function Window:ToggleFloating(panel, anchor, matchWidth)
	if not IsInteractive(anchor) then
		return
	end
	for _, open in self.FloatStack do
		if open == panel then
			self:CloseFloatingFrom(panel.Depth)
			return
		end
	end
	self:CloseFloatingFrom(panel.Depth)
	self.ClosingFloats[panel] = nil

	if panel.Anchor ~= anchor then
		for _, connection in panel.AnchorConnections do connection:Disconnect() end
		table.clear(panel.AnchorConnections)
		for _, property in { "AbsolutePosition", "AbsoluteSize" } do
			panel.AnchorConnections[#panel.AnchorConnections + 1] = anchor:GetPropertyChangedSignal(property):Connect(panel.RequestPosition)
		end
	end
	panel.Anchor = anchor
	panel.MatchWidth = matchWidth
	local target = self:FloatingTarget(panel, anchor, matchWidth)
	panel.TargetPosition = target
	if panel.Motion then
		panel.Motion:Cancel()
		panel.Motion = nil
	end
	if panel.Attached then
		panel.Frame.Position = target
	elseif not panel.Frame.Visible then
		panel.Frame.Position = target - UDim2.fromOffset(0, 4)
	end
	panel.Open = true
	table.insert(self.FloatStack, panel)
	self.Blocker.Visible = true
	RaiseLayerFrame(self.Main)
	local info = AnimationInfo("Popup")
	if panel.OnOpen then
		panel.OnOpen(info)
	end
	Fade(panel.Frame, true, info)
	if not panel.Attached then
		panel.Motion = Tween(panel.Frame, { Position = target }, info)
	end
end

function Window:Tab(name, icon)
	local opts = type(name) == "table" and name or { Title = name, Icon = icon }
	local title = opts.Title or opts.Text or "tab"

	local page = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = Theme.AccentDim,
		ScrollBarImageTransparency = 0.3,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Visible = false,
		Parent = self.Body,
		ThemeTag = { ScrollBarImageColor3 = "AccentDim" },
	})
	local pageList = List(page, Library.SectionTitleStyle == "border" and 22 or 14)
	pageList.SortOrder = Enum.SortOrder.LayoutOrder
	Pad(page, Library.SectionTitleStyle == "border" and 12 or 6, 9, 10, 8)

	local tab = setmetatable({
		Window = self,
		Page = page,
		Columns = {},
		Name = title,
		Order = 0,
	}, Tab)

	local side = self.TabStyle == "side"

	local button = New("TextButton", {
		Size = side and UDim2.new(1, 0, 0, 36) or UDim2.new(0, 0, 1, 0),
		AutomaticSize = (not side) and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
		BackgroundColor3 = Theme.Field,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = self:NextTabOrder(),
		Parent = self.TabBar,
		ThemeTag = { BackgroundColor3 = "Field" },
	})
	if side then
		Corner(button, 5)
		New("Frame", {
			Size = UDim2.fromOffset(2, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Name = "ActiveBar",
			ZIndex = 2,
			Parent = button,
			ThemeTag = { BackgroundColor3 = "Accent" },
		})
		Corner(button:FindFirstChild("ActiveBar") or button, 2)
	end

	local row = New("Frame", {
		Size = side and UDim2.new(1, -28, 1, 0) or UDim2.new(0, 0, 1, 0),
		Position = side and UDim2.fromOffset(14, 0) or UDim2.fromOffset(0, 0),
		AutomaticSize = (not side) and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		Parent = button,
	})
	local rowList = List(row, side and 6 or 7, Enum.FillDirection.Horizontal)
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center

	local icon = AttachIcon(row, opts.Icon, Theme.TextDim, 15)
	if icon then
		icon.Position = UDim2.fromOffset(0, 0)
		icon.LayoutOrder = 1
	end

	local label = Label(row, title, Theme.TextDim, Theme.TextSize)
	label.Size = side and UDim2.new(1, icon and (side and -21 or -22) or 0, 1, 0) or UDim2.new(0, 0, 1, 0)
	label.AutomaticSize = (not side) and Enum.AutomaticSize.X or Enum.AutomaticSize.None
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.LayoutOrder = 2

	tab.Button = button
	tab.Label = label
	tab.Icon = icon

	local activeBar = side and button:FindFirstChild("ActiveBar") or nil
	tab.VisualTweens = {}

	local function cancelTabTween(slot)
		local tween = tab.VisualTweens[slot]
		if tween then
			tween:Cancel()
			tab.VisualTweens[slot] = nil
		end
	end

	local function setTabVisual(slot, object, property, value, info)
		if not object then
			return
		end
		cancelTabTween(slot)
		if info and info.Time > 0 then
			local tween = TweenService:Create(object, info, { [property] = value })
			tab.VisualTweens[slot] = tween
			tween.Completed:Once(function()
				if tab.VisualTweens[slot] == tween then
					tab.VisualTweens[slot] = nil
				end
			end)
			tween:Play()
		else
			object[property] = value
		end
	end

	local function cancelTabVisuals()
		for slot in tab.VisualTweens do
			cancelTabTween(slot)
		end
	end

	function tab:SetActive(active, animate, info)
		info = info or (animate and AnimationInfo("Tab") or TweenInfo.new(0))
		local key = active and "Highlight" or "TextDim"
		local iconKey = active and "Highlight" or "TextDim"
		cancelTabVisuals()

		Library:Tag(label, { TextColor3 = key })
		if icon then
			Library:Tag(icon, { ImageColor3 = iconKey })
		end
		if activeBar then
			Library:Tag(activeBar, { BackgroundColor3 = "Highlight" })
		end

		local motion = animate and info or TweenInfo.new(0)
		setTabVisual("label", label, "TextColor3", Theme[key], motion)
		if icon then
			setTabVisual("icon", icon, "ImageColor3", Theme[iconKey], motion)
		end
		if side then
			setTabVisual("button", button, "BackgroundTransparency", active and 0.85 or 1, motion)
			if activeBar then
				setTabVisual("bar", activeBar, "BackgroundTransparency", active and 0 or 1, motion)
			end
		end
	end

	table.insert(self.Tabs, tab)

	Track(button.Activated:Connect(function()
		self:SetTab(tab)
	end))
	Track(button.MouseEnter:Connect(function()
		if self.ActiveTab == tab then
			return
		end
		setTabVisual("label", label, "TextColor3", Theme.Text, EASE_FAST)
		if icon then
			setTabVisual("icon", icon, "ImageColor3", Theme.Text, EASE_FAST)
		end
		if side then
			setTabVisual("button", button, "BackgroundTransparency", 0.55, EASE_FAST)
		end
	end))
	Track(button.MouseLeave:Connect(function()
		if self.ActiveTab == tab then
			return
		end
		setTabVisual("label", label, "TextColor3", Theme.TextDim, EASE_FAST)
		if icon then
			setTabVisual("icon", icon, "ImageColor3", Theme.TextDim, EASE_FAST)
		end
		if side then
			setTabVisual("button", button, "BackgroundTransparency", 1, EASE_FAST)
		end
	end))
	Track(page:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:CloseFloating()
	end))

	if not self.ActiveTab then
		self.ActiveTab = tab
		tab.Page.Position = UDim2.fromOffset(0, 0)
		tab.Page.Visible = true
		tab:SetActive(true, false, TweenInfo.new(0))
		task.defer(function()
			if self.ActiveTab == tab and tab.Label and tab.Label.Parent then
				tab:SetActive(true, false, TweenInfo.new(0))
			end
		end)
	end
	return tab
end

function Window:NextTabOrder()
	self.TabOrder = (self.TabOrder or 0) + 1
	return self.TabOrder
end

function Window:TabDivider(opts)
	if self.TabStyle ~= "side" then
		return nil
	end
	opts = opts or {}

	local holder = New("Frame", {
		Size = UDim2.new(1, 0, 0, opts.Height or 11),
		BackgroundTransparency = 1,
		LayoutOrder = self:NextTabOrder(),
		Parent = self.TabBar,
	})

	local inset = opts.Inset or 12
	local line = New("Frame", {
		Size = UDim2.new(1, -inset * 2, 0, 1),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, inset, 0.5, 0),
		BackgroundColor3 = Theme.BorderSoft,
		BorderSizePixel = 0,
		Parent = holder,
		ThemeTag = { BackgroundColor3 = "BorderSoft" },
	})

	if opts.Text then
		holder.Size = UDim2.new(1, 0, 0, opts.Height or 24)
		line:Destroy()
		local label = Label(holder, opts.Text, Theme.TextDim, Theme.TextSize - 2)
		label.Position = UDim2.fromOffset(inset, 0)
		label.Size = UDim2.new(1, -inset * 2, 1, 0)
		label.TextYAlignment = Enum.TextYAlignment.Bottom
		return { Instance = holder, Label = label }
	end

	return { Instance = holder, Line = line }
end

function Window:SetTab(tab)
	if type(tab) == "string" then
		for _, candidate in self.Tabs do
			if candidate.Name == tab then
				tab = candidate
				break
			end
		end
	end

	if type(tab) ~= "table" or tab.Window ~= self or not tab.Page then
		return false
	end

	if self.ActiveTab == tab then
		tab.Page.Position = UDim2.fromOffset(0, 0)
		tab.Page.Visible = true
		tab:SetActive(true, false, TweenInfo.new(0))
		return true
	end

	if self.OpenInlineDropdown then
		self.OpenInlineDropdown:SetOpen(false, true)
		self.OpenInlineDropdown = nil
	end
	self:CloseFloating(true)

	local previous = self.ActiveTab
	self.ActiveTab = tab

	if previous then
		previous:SetActive(false, true, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		previous.Page.Active = false
		Fade(previous.Page, false, TweenInfo.new(0))
		previous.Page.Position = UDim2.fromOffset(0, 0)
	end

	tab.Page.Position = UDim2.fromOffset(0, 0)
	tab.Page.Active = true
	tab:SetActive(true, true, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))

	Fade(tab.Page, true, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))

	return true
end

function Window:Action(text, callback)
	local btn = New("TextButton", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = text,
		TextColor3 = Theme.Accent,
		TextSize = Theme.TextSize,
		Font = Theme.FontMedium,
		Parent = self.Footer,
		ThemeTag = { TextColor3 = "Accent" },
	})
	Track(btn.MouseEnter:Connect(function()
		Tween(btn, { TextColor3 = Theme.AccentSoft }, EASE_FAST)
	end))
	Track(btn.MouseLeave:Connect(function()
		Tween(btn, { TextColor3 = Theme.Accent }, EASE_FAST)
	end))
	Track(btn.Activated:Connect(function()
		Library:SafeCallback("action", callback)
	end))
	return btn
end

function Window:SetUserScale(value)
	if self.DragController then
		self.DragController:Cancel()
	end
	if self.CancelResize then
		self.CancelResize()
	end
	self.UserScale = math.clamp(tonumber(value) or 1, 0.6, 1.4)
	Library.InterfaceUserScale = self.UserScale
	if self.Refit then
		self.Refit()
	end
	Library:RefreshStandaloneScales()
	return self.UserScale
end

function Library:SetInterfaceUserScale(value)
	value = math.clamp(tonumber(value) or 1, 0.6, 1.4)
	self.InterfaceUserScale = value
	for _, window in self.Windows do
		if window and window.Main and window.Main.Parent then
			if window.DragController then
				window.DragController:Cancel()
			end
			if window.CancelResize then
				window.CancelResize()
			end
			window.UserScale = value
			if window.Refit then
				window.Refit()
			end
		end
	end
	self:RefreshStandaloneScales()
	return value
end

function Window:SetOpacity(alpha)
	self.Opacity = math.clamp(tonumber(alpha) or 1, 0.2, 1)
	SetVisual(self.Main, "BackgroundTransparency", 1 - self.Opacity)
	return self.Opacity
end

function Window:SetSize(width, height)
	self.Width = math.max(width, self.MinWidth)
	self.Height = math.max(height, self.MinHeight)
	if self.PlayerDockWidthActive and self.PlayerDockRestoreWidth then
		self.PlayerDockRestoreWidth = self.Width
	end
	self.Main.Size = UDim2.fromOffset(self.Width, self.Height)
	if self.Refit then
		self.Refit()
	end
end

function Window:GetPlayerDockWidth(panel, renderScale)
	panel = panel or Library.PlayerMenuApi
	if not panel or panel.AnchorWindow ~= self then
		return self.Width
	end

	renderScale = math.max(tonumber(renderScale) or self.BaseScale or GetFrameRenderScale(self.Main), 0.05)
	local _, viewportSize = GetFrameViewportRect(self.Main)
	local topLeftInset, bottomRightInset = GetDragSafeInsets()
	local safeWidth = math.max(1, viewportSize.X - topLeftInset.X - bottomRightInset.X - LAYER_DRAG_MARGIN * 2)
	local panelWidth = tonumber(panel.BaseWidth) or 384
	local gap = tonumber(panel.DockGap) or 10
	local maxMainWidth = (safeWidth - gap - panelWidth * renderScale) / renderScale
	local restoreWidth = tonumber(self.PlayerDockRestoreWidth) or self.Width
	return math.max(self.MinWidth, math.min(restoreWidth, math.floor(maxMainWidth + 0.5)))
end

function Window:SetPlayerDockVisible(state, panel, renderScale)
	state = state == true
	panel = panel or Library.PlayerMenuApi

	if state then
		if not self.PlayerDockWidthActive then
			self.PlayerDockRestoreWidth = self.Width
		end
		self.PlayerDockWidthActive = true
		self.PlayerDockPanel = panel
		local targetWidth = self:GetPlayerDockWidth(panel, renderScale)
		if targetWidth ~= self.Width then
			self.Width = targetWidth
			self.Main.Size = UDim2.fromOffset(self.Width, self.Height)
		end
	else
		if self.PlayerDockWidthActive then
			local restoreWidth = math.max(self.MinWidth, tonumber(self.PlayerDockRestoreWidth) or self.Width)
			self.PlayerDockWidthActive = false
			self.PlayerDockPanel = nil
			self.PlayerDockRestoreWidth = nil
			if restoreWidth ~= self.Width then
				self.Width = restoreWidth
				self.Main.Size = UDim2.fromOffset(self.Width, self.Height)
			end
		end
	end
	return self.Width
end

function Window:IconAction(icon, callback, order)
	if not self.FooterLeft then
		return nil
	end

	local button = New("ImageButton", {
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		ImageColor3 = Theme.TextDim,
		LayoutOrder = order or 1,
		ZIndex = 266,
		Parent = self.FooterLeft,
		ThemeTag = { ImageColor3 = "TextDim" },
	})

	local resolved = ResolveIcon(icon, 16)
	if resolved then
		button.Image = resolved.Image
		if resolved.RectOffset then
			button.ImageRectOffset = resolved.RectOffset
		end
		if resolved.RectSize then
			button.ImageRectSize = resolved.RectSize
		end
	end

	Track(button.MouseEnter:Connect(function()
		Tween(button, { ImageColor3 = Theme.Accent }, EASE_FAST)
	end))
	Track(button.MouseLeave:Connect(function()
		Tween(button, { ImageColor3 = Theme.TextDim }, EASE_FAST)
	end))
	Track(button.Activated:Connect(function()
		Library:SafeCallback("action", callback)
	end))

	return button
end

function Window:GetSharedDimmer()
	if self.SharedDimmer and self.SharedDimmer.Parent then
		return self.SharedDimmer
	end

	local dimmer = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 260,
		Parent = self.Main,
		ThemeTag = { BackgroundColor3 = false },
	})
	Corner(dimmer, 10)

	self.SharedDimmer = dimmer
	self.SharedDimmerTarget = nil
	self.SharedDimmerTween = nil
	self.SharedDimmerTicket = 0

	Track(dimmer.Activated:Connect(function()
		local target = self.SharedDimmerTarget
		local frame = target and target.Frame

		if not frame or not frame.Parent then
			return
		end

		local mouse = UserInputService:GetMouseLocation()
		local pos = frame.AbsolutePosition
		local size = frame.AbsoluteSize

		local inside = mouse.X >= pos.X and mouse.X <= pos.X + size.X and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y

		if inside or IsPointInScrollHint(frame, mouse) then
			return
		end

		if target.SetOpen then
			target:SetOpen(false)
		elseif target.SetVisible then
			target:SetVisible(false)
		end
	end))

	return dimmer
end

function Window:SetSharedDimmer(target, state, transparency)
	local dimmer = self:GetSharedDimmer()
	state = state ~= false
	self.SharedDimmerTicket = (self.SharedDimmerTicket or 0) + 1
	local ticket = self.SharedDimmerTicket

	if self.SharedDimmerTween then
		self.SharedDimmerTween:Cancel()
		self.SharedDimmerTween = nil
	end

	if state then
		self.SharedDimmerTarget = target
		dimmer.Visible = true
		dimmer.Active = true

		local playerMenu = Library.PlayerMenuApi
		if playerMenu and playerMenu.AnchorWindow == self and playerMenu.SetModalDimmed then
			playerMenu:SetModalDimmed(true, transparency or 0.78)
		end

		local tween = TweenService:Create(
			dimmer,
			AnimationInfo("Modal", false),
			{ BackgroundTransparency = transparency or 0.78 }
		)
		self.SharedDimmerTween = tween
		tween.Completed:Once(function()
			if self.SharedDimmerTween == tween then
				self.SharedDimmerTween = nil
			end
		end)
		tween:Play()
		return
	end

	if self.SharedDimmerTarget ~= target then
		return
	end

	self.SharedDimmerTarget = nil
	dimmer.Active = false

	local playerMenu = Library.PlayerMenuApi
	if playerMenu and playerMenu.AnchorWindow == self and playerMenu.SetModalDimmed then
		playerMenu:SetModalDimmed(false, transparency or 0.78)
	end

	local tween = TweenService:Create(dimmer, AnimationInfo("Modal", true), { BackgroundTransparency = 1 })
	self.SharedDimmerTween = tween
	tween.Completed:Once(function(status)
		if status ~= Enum.PlaybackState.Completed or ticket ~= self.SharedDimmerTicket then
			return
		end
		self.SharedDimmerTween = nil
		if not self.SharedDimmerTarget then
			dimmer.Visible = false
		end
	end)
	tween:Play()
end

function Window:Modal(opts)
	opts = opts or {}
	local window = self

	local root = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 270,
		Parent = self.Main,
	})

	local isThemeModal = string.lower(tostring(opts.Title or "")) == "theme"
	local scrimTransparency = isThemeModal and 0.78 or (opts.Dim ~= nil and opts.Dim or 0.58)

	local card = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = (opts.Height and opts.Height > 1) and UDim2.fromOffset(opts.Width or 340, opts.Height)
			or UDim2.new(0, opts.Width or 340, opts.Height or 0.78, 0),
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 280,
		Parent = root,
		ThemeTag = { BackgroundColor3 = "Window" },
	})
	Corner(card, 10)
	Stroke(card, Theme.WindowBorder)
	if isThemeModal then
		local shadow = Shadow(card, Color3.new(0, 0, 0), 0.38, 22,
			UDim2.fromOffset(8, 8), UDim2.fromOffset(0, 5), 0)
		if shadow then
			local function repaintShadow()
				local light = ShadowLightness()
				SetVisual(shadow, "Transparency", 0.38 + light * 0.42)
				shadow.BlurRadius = UDim.new(0, 22 + light * 6)
				shadow.Spread = UDim2.fromOffset(8 - light * 4, 8 - light * 4)
			end
			Library:OnRepaint(repaintShadow, card)
			repaintShadow()
		end
	end
	local cardScale = New("UIScale", { Parent = card })

	local header = New("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		ZIndex = 280,
		Parent = card,
	})
	local heading = Label(header, opts.Title or "panel", Theme.TextBright, Theme.TextSize, Theme.FontMedium)
	heading.Position = UDim2.fromOffset(16, 0)
	heading.Size = UDim2.new(1, -48, 1, 0)
	heading.ZIndex = 210

	local close = New("TextButton", {
		Size = UDim2.fromOffset(20, 20),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 280,
		Parent = header,
	})
	local closeBars = {}
	for i = 1, 2 do
		local bar = New("Frame", {
			Size = UDim2.fromOffset(13, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = i == 1 and 45 or -45,
			BackgroundColor3 = Theme.TextDim,
			BorderSizePixel = 0,
			ZIndex = 280,
			Parent = close,
			ThemeTag = { BackgroundColor3 = "TextDim" },
		})
		Corner(bar, 1)
		closeBars[i] = bar
	end

	New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, 38),
		BackgroundColor3 = Theme.BorderSoft,
		BorderSizePixel = 0,
		ZIndex = 280,
		Parent = card,
		ThemeTag = { BackgroundColor3 = "BorderSoft" },
	})

	local scroller = New("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -50),
		Position = UDim2.fromOffset(8, 45),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = Theme.AccentDim,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		ZIndex = 280,
		Parent = card,
		ThemeTag = { ScrollBarImageColor3 = "AccentDim" },
	})
	List(scroller, 9)
	Pad(scroller, 4, 10, 8, 6)

	local api = {
		Root = root,
		Frame = card,
		Scroller = scroller,
		Content = NewContainer(self, scroller),
		Open = false,
	}

	local function setBlur(state)
		if (opts.Blur or 0) <= 0 then
			return
		end
		if state and not api.Blur then
			local blur = Instance.new("BlurEffect")
			blur.Name = "LayerModalBlur"
			blur.Size = 0
			blur.Parent = Lighting
			api.Blur = blur
		end
		local blur = api.Blur
		if not blur then
			return
		end
		if api.BlurTween then
			api.BlurTween:Cancel()
		end
		local tween =
			TweenService:Create(blur, AnimationInfo("Modal", not state), { Size = state and (opts.Blur or 16) or 0 })
		api.BlurTween = tween
		tween.Completed:Once(function(status)
			if status ~= Enum.PlaybackState.Completed or api.BlurTween ~= tween then
				return
			end
			api.BlurTween = nil
			if not api.Open and api.Blur == blur then
				api.Blur = nil
				blur:Destroy()
			end
		end)
		tween:Play()
	end

	root.Destroying:Once(function()
		if api.BlurTween then
			api.BlurTween:Cancel()
			api.BlurTween = nil
		end
		if api.Blur then
			api.Blur:Destroy()
			api.Blur = nil
		end
	end)

	function api:SetOpen(state)
		state = state ~= false
		if state == self.Open then
			return self
		end
		self.Open = state

		if state then
			local serverBrowser = Library.ServerBrowserApi
			if serverBrowser and serverBrowser.Open and serverBrowser.SetVisible then
				serverBrowser:SetVisible(false)
			end
		end

		window:CloseFloating()
		if state and window.Hints then
			for _, hideHint in window.Hints do
				if type(hideHint) == "function" then
					hideHint(true)
				end
			end
		end
		local info = AnimationInfo("Modal", not state)
		local motionInfo = state and TweenInfo.new(info.Time, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
			or info
		if state and not root.Visible then
			cardScale.Scale = 0.965
		end
		Tween(cardScale, { Scale = state and 1 or 0.965 }, motionInfo)
		window:SetSharedDimmer(self, state, scrimTransparency)
		Fade(root, state, info)
		setBlur(state)
		if not state and api.OnClose then
			task.spawn(api.OnClose)
		end
		return self
	end

	function api:Toggle()
		self:SetOpen(not self.Open)
	end

	Track(close.Activated:Connect(function()
		api:SetOpen(false)
	end))
	Track(close.MouseEnter:Connect(function()
		for _, bar in closeBars do
			Tween(bar, { BackgroundColor3 = Theme.Danger }, EASE_FAST)
		end
	end))
	Track(close.MouseLeave:Connect(function()
		for _, bar in closeBars do
			Tween(bar, { BackgroundColor3 = Theme.TextDim }, EASE_FAST)
		end
	end))
	Track(UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and not BindingInputBlocked(input) and api.Open and input.KeyCode == Enum.KeyCode.Escape then
			api:SetOpen(false)
		end
	end))

	self.Modals = self.Modals or {}
	table.insert(self.Modals, api)
	return api
end

function Window:Confirm(opts)
	opts = opts or {}

	local modal = self:Modal({
		Title = opts.Title or "confirm",
		Width = opts.Width or 280,
		Height = opts.Height or 150,
		Dim = opts.Dim or 0.45,
		Blur = opts.Blur or 10,
	})

	local content = modal.Content
	content:Label(opts.Text or "are you sure?", { Style = "text", Wrap = true })

	modal.Scroller.Size = UDim2.new(1, -16, 1, -95)

	local answered = false
	local function answer(callback)
		answered = true
		modal:SetOpen(false)
		Library:SafeCallback("action", callback)
	end

	local footer = New("Frame", {
		Size = UDim2.new(1, -24, 0, 30),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		BackgroundTransparency = 1,
		ZIndex = modal.Frame.ZIndex,
		Parent = modal.Frame,
	})
	local footerContainer = NewContainer(self, footer)
	footerContainer:ButtonRow({
		{
			Text = opts.Confirm or "save",
			Callback = function()
				answer(opts.OnConfirm)
			end,
		},
		{
			Text = opts.Cancel or "discard",
			Callback = function()
				answer(opts.OnCancel)
			end,
		},
	})

	modal.OnClose = function()
		if not answered and opts.OnDismiss then
			task.spawn(opts.OnDismiss)
		end
		answered = false
	end

	modal:SetOpen(true)
	return modal
end

function Library:TogglePlayers(window)
	window = window or self.Windows[#self.Windows]
	if not window or window.PlayersDisabled or self.Destroyed then return nil end
	local menu = self.PlayerMenuApi
	if menu and menu.Open and menu.HostVisible then
		menu:SetVisible(false)
		self:RefreshHotkeys()
		return menu
	end
	local options = {}
	for key, value in window.PlayerMenuOptions or {} do options[key] = value end
	options.AnchorWindow = nil
	menu = self:PlayerMenu(options)
	menu:SetAnchorWindow(nil)
	if menu.Open then menu:SetHostVisible(true) else menu:SetVisible(true) end
	self:RefreshHotkeys()
	return menu
end

function Library:SetMainMenuBlur(state)
	if self.MainMenuBlurTween then
		self.MainMenuBlurTween:Cancel()
		self.MainMenuBlurTween = nil
	end
	if self.MainMenuBlur then
		self.MainMenuBlur:Destroy()
		self.MainMenuBlur = nil
	end
end

function Library:RefreshMainMenuBlur()
	self:SetMainMenuBlur(false)
end

function Window:SetVisible(state)
	state = state ~= false
	local fade = Fades[self.Main]
	if self.Visible == state and self.Main.Visible == state
		and (not fade or (fade.Show == state and (fade.Tween or fade.Value.Value == (state and 0 or 1)))) then
		return self
	end

	local firstReveal = state and self.HasBeenShown ~= true
	if firstReveal then
		self.HasBeenShown = true
	end

	self.VisibilityRevealTicket = (self.VisibilityRevealTicket or 0) + 1
	local ticket = self.VisibilityRevealTicket
	self.Visible = state
	Library:RefreshMainMenuBlur()

	local playerMenu = Library.PlayerMenuApi
	local function playStartupSound()
		if Library.StartupRevealPlayed then
			return
		end

		Library.StartupRevealPlayed = true

		local startupSound = Instance.new("Sound")
		startupSound.Name = "LayerStartup"
		startupSound.SoundId = "rbxassetid://140419294351439"
		startupSound.Volume = 0.35
		startupSound.Parent = SoundService

		local cleaned = false
		local function cleanupStartupSound()
			if cleaned then
				return
			end

			cleaned = true
			if startupSound.Parent then
				startupSound:Destroy()
			end
		end

		startupSound.Ended:Once(cleanupStartupSound)
		task.delay(8, cleanupStartupSound)
		startupSound:Play()
	end

	local duration = state and 0.20 or 0.12
	local motionInfo = TweenInfo.new(duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

	if state then
		if firstReveal then
			playStartupSound()
		end

		Fade(self.Main, true, motionInfo, function()
			if ticket ~= self.VisibilityRevealTicket or not self.Visible or not self.Main.Parent then
				return
			end
			ClampRenderedFrame(self.Main)
			if playerMenu and playerMenu.Open and playerMenu.AnchorWindow == self and playerMenu.SyncToAnchor then
				playerMenu:SyncToAnchor(false)
				task.defer(function()
					RunService.RenderStepped:Wait()
					if
						ticket == self.VisibilityRevealTicket
						and self.Visible
						and playerMenu.Open
						and playerMenu.AnchorWindow == self
					then
						playerMenu:SyncToAnchor(true)
					end
				end)
			end
		end)
		ClampRenderedFrameNextFrame(self.Main)
		return self
	end

	if self.DragController then
		self.DragController:Cancel()
	end
	if self.CancelResize then
		self.CancelResize()
	end

	self:CloseFloating()

	for _, modal in self.Modals or {} do
		modal:SetOpen(false)
	end

	Fade(self.Main, false, motionInfo, function()
		if self.VisibilityRevealTicket == ticket and not self.Visible then
			self.Main.Visible = false
		end
	end)

	return self
end

function Library:Window(opts)
	opts = opts or {}
	local width = opts.Width or 620
	local height = opts.Height or 560

	local defaultTheme = opts.DefaultTheme or self.DefaultTheme
	if type(defaultTheme) == "string" and defaultTheme ~= "" then
		pcall(function()
			if self:ApplyThemeByName(defaultTheme) then
				self.Defaults.__layer_theme = CloneConfigValue(self:GetThemeConfigValue())
			end
		end)
	end

	pcall(function()
		local folder = opts.ThemeFolder or opts.Folder or "layer.app"
		local path = folder .. "/settings/theme.json"
		if not (isfile and isfile(path)) then
			return
		end

		local raw = readfile(path)
		if not raw then
			return
		end

		local ok, data = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not ok or type(data) ~= "table" or type(data.Colors) ~= "table" then
			return
		end

		for key, hex in data.Colors do
			if Theme[key] ~= nil then
				local color, alpha = FromHex(hex)
				if color then
					Theme[key] = color
					if alpha then
						ThemeAlpha[key] = alpha
					end
				end
			end
		end

		IndexTheme()
	end)

	if opts.Discord and opts.Discord.Enabled ~= false and opts.Discord.Invite then
		local inv = opts.Discord.Invite
		local remember = opts.Discord.RememberJoins ~= false
		local joined = false

		if remember then
			pcall(function()
				if isfile and isfile("layer_discord_" .. inv .. ".dat") then
					joined = true
				end
			end)
		end

		if not joined then
			pcall(function()
				local req = request or http_request or (http and http.request)
				if not req then
					return
				end
				req({
					Url = "http://127.0.0.1:6463/rpc?v=1",
					Method = "POST",
					Headers = {
						["Content-Type"] = "application/json",
						["Origin"] = "https://discord.com",
					},
					Body = HttpService:JSONEncode({
						cmd = "INVITE_BROWSER",
						args = { code = inv },
						nonce = tick(),
					}),
				})
				if remember then
					pcall(function()
						if writefile then
							writefile("layer_discord_" .. inv .. ".dat", "1")
						end
					end)
				end
			end)
		end
	end

	if opts.KeySystem then
		local ks = opts.KeySettings or {}
		local title = ks.Title or "Key System"
		local subtitle = ks.Subtitle or "Enter your key to continue"
		local note = ks.Note or ""
		local fileName = (ks.FileName or "key") .. ".dat"
		local saveKey = ks.SaveKey ~= false
		local grabFromSite = ks.GrabKeyFromSite == true
		local keys = ks.Key or {}

		local keyValid = false

		if saveKey then
			pcall(function()
				if isfile and isfile(fileName) then
					local saved = readfile(fileName)
					if saved then
						saved = saved:gsub("%s+", "")
					end
					local validKeys = keys
					if grabFromSite and type(keys) == "table" then
						local fresh = {}
						for _, url in keys do
							pcall(function()
								local res = game:HttpGet(url)
								if res then
									for _, line in string.split(res, "\n") do
										table.insert(fresh, line:gsub("%s+", ""))
									end
								end
							end)
						end
						if #fresh > 0 then
							validKeys = fresh
						end
					end
					for _, k in validKeys do
						if saved == k:gsub("%s+", "") then
							keyValid = true
							break
						end
					end
				end
			end)
		end

		if not keyValid then
			local gui = New("ScreenGui", {
				Name = RandomName(),
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				AutoLocalize = false,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
				DisplayOrder = MAX_DISPLAY_ORDER,
			})
			ParentGui(gui)

			local card = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(520, 178),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundColor3 = Theme.Window,
				BorderSizePixel = 0,
				Active = true,
				Parent = gui,
				ThemeTag = { BackgroundColor3 = "Window" },
			})
			Corner(card, 9)
			Stroke(card, Theme.WindowBorder)

			local shadowHolder = New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(1, 35, 1.096, 35),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				Parent = card,
			})
			New("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 0,
				Image = "rbxassetid://5587865193",
				ImageColor3 = Color3.fromRGB(20, 20, 20),
				Size = UDim2.new(1.6, 0, 1.3, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				ImageTransparency = 0.5,
				Parent = shadowHolder,
			})

			local ksTitle = Label(card, title, Theme.TextBright, 14, Theme.FontMedium)
			ksTitle.Position = UDim2.fromOffset(24, 22)
			ksTitle.Size = UDim2.fromOffset(200, 16)

			local ksSub = Label(card, subtitle, Theme.TextDim, 12)
			ksSub.Position = UDim2.fromOffset(24, 40)
			ksSub.Size = UDim2.fromOffset(200, 13)

			local announce = Label(card, "Get Key", Theme.TextBright, 14, Theme.FontMedium)
			announce.Position = UDim2.fromOffset(286, 22)
			announce.Size = UDim2.fromOffset(210, 16)

			local descr = New("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(210, 60),
				Position = UDim2.fromOffset(286, 42),
				TextColor3 = Theme.TextDim,
				RichText = true,
				Text = note ~= "" and note
					or 'To obtain the key, simply click on <font color="rgb(232,161,168)">Get-Key</font>. This will copy the key link to your clipboard. For any help, don\'t hesitate to ask on our Discord by clicking on <font color="rgb(120,170,230)">Discord</font>.',
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				Font = Theme.Font,
				TextSize = 12,
				Parent = card,
				ThemeTag = { TextColor3 = "TextDim" },
			})

			New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(262, 89),
				Size = UDim2.new(0, 1, 1, -44),
				BackgroundColor3 = Theme.BorderSoft,
				BorderSizePixel = 0,
				Parent = card,
				ThemeTag = { BackgroundColor3 = "BorderSoft" },
			})

			local field = New("Frame", {
				Position = UDim2.fromOffset(24, 68),
				Size = UDim2.fromOffset(214, 32),
				BackgroundColor3 = Theme.Field,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Parent = card,
				ThemeTag = { BackgroundColor3 = "Field" },
			})
			Corner(field, 6)
			Stroke(field, Theme.Border)

			local box = New("TextBox", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -15, 0, 14),
				Position = UDim2.new(0.517, 0, 0.5, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				PlaceholderText = "Input script key here...",
				PlaceholderColor3 = Theme.TextDim,
				Font = Theme.Font,
				TextColor3 = Theme.Text,
				TextSize = Theme.TextSize,
				Text = "",
				ClearTextOnFocus = false,
				Parent = field,
				ThemeTag = { PlaceholderColor3 = "TextDim", TextColor3 = "Text" },
			})

			local validateFrame = New("Frame", {
				Position = UDim2.fromOffset(61, 124),
				Size = UDim2.fromOffset(140, 30),
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
				Parent = card,
				ThemeTag = { BackgroundColor3 = "Accent" },
			})
			Corner(validateFrame, 6)

			local btn = New("TextButton", {
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "Validate Key",
				TextColor3 = Color3.fromRGB(40, 32, 34),
				TextSize = Theme.TextSize,
				Font = Theme.FontMedium,
				Parent = validateFrame,
			})

			local errorLabel = Label(card, "", Theme.Danger, 11)
			errorLabel.Position = UDim2.fromOffset(24, 104)
			errorLabel.Size = UDim2.fromOffset(214, 14)
			errorLabel.Visible = false

			if ks.GetKey then
				local gkFrame = New("Frame", {
					Position = UDim2.fromOffset(286, 124),
					Size = UDim2.fromOffset(100, 30),
					BackgroundColor3 = Theme.Accent,
					BorderSizePixel = 0,
					Parent = card,
					ThemeTag = { BackgroundColor3 = "Accent" },
				})
				Corner(gkFrame, 6)
				local gkBtn = New("TextButton", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					AutoButtonColor = false,
					Text = "Get-Key",
					TextColor3 = Color3.fromRGB(40, 32, 34),
					TextSize = Theme.TextSize,
					Font = Theme.FontMedium,
					Parent = gkFrame,
				})
				Track(gkBtn.Activated:Connect(function()
					pcall(function()
						if setclipboard then
							setclipboard(ks.GetKey)
						end
					end)
				end))
			end

			if ks.Discord then
				local dcFrame = New("Frame", {
					Position = UDim2.fromOffset(396, 124),
					Size = UDim2.fromOffset(100, 30),
					BackgroundColor3 = Theme.Field,
					BorderSizePixel = 0,
					Parent = card,
					ThemeTag = { BackgroundColor3 = "Field" },
				})
				Corner(dcFrame, 6)
				Stroke(dcFrame, Theme.Border)
				local dcBtn = New("TextButton", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					AutoButtonColor = false,
					Text = "Discord",
					TextColor3 = Theme.TextBright,
					TextSize = Theme.TextSize,
					Font = Theme.FontMedium,
					Parent = dcFrame,
					ThemeTag = { TextColor3 = "TextBright" },
				})
				Track(dcBtn.Activated:Connect(function()
					pcall(function()
						if setclipboard then
							setclipboard("https://discord.gg/" .. ks.Discord)
						end
					end)
				end))
			end

			do
				local dragging, dragStart, startPos = false, nil, nil
				local targetPosition = card.Position
				local activeInput = nil
				Track(card.InputBegan:Connect(function(input)
					if not IsInteractive(card) then
						return
					end
					if
						input.UserInputType ~= Enum.UserInputType.MouseButton1
						and input.UserInputType ~= Enum.UserInputType.Touch
					then
						return
					end
					if dragging then
						return
					end
					dragging = true
					activeInput = input
					dragStart = input.Position
					startPos = card.Position
					input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End then
							dragging = false
							activeInput = nil
						end
					end)
				end))
				Track(UserInputService.InputChanged:Connect(function(input)
					if not dragging then
						return
					end
					if input ~= activeInput and input.UserInputType ~= Enum.UserInputType.MouseMovement then
						return
					end
					if
						input.UserInputType ~= Enum.UserInputType.MouseMovement
						and input.UserInputType ~= Enum.UserInputType.Touch
					then
						return
					end
					local delta = input.Position - dragStart
					card.Position = UDim2.new(
						startPos.X.Scale,
						startPos.X.Offset + delta.X,
						startPos.Y.Scale,
						startPos.Y.Offset + delta.Y
					)
				end))
			end

			local done = false
			local function validate()
				if done then
					return
				end
				local input = box.Text:gsub("%s+", "")
				if input == "" then
					return
				end

				local validKeys = keys
				if grabFromSite then
					local fresh = {}
					for _, url in keys do
						pcall(function()
							local res = game:HttpGet(url)
							if res then
								for _, line in string.split(res, "\n") do
									table.insert(fresh, line:gsub("%s+", ""))
								end
							end
						end)
					end
					if #fresh > 0 then
						validKeys = fresh
					end
				end

				local ok = false
				for _, k in validKeys do
					if input == k:gsub("%s+", "") then
						ok = true
						break
					end
				end

				if ok then
					done = true
					if saveKey then
						pcall(function()
							if writefile then
								writefile(fileName, input)
							end
						end)
					end
					gui:Destroy()
				else
					errorLabel.Text = "invalid key, try again."
					errorLabel.Visible = true
				end
			end

			Track(btn.Activated:Connect(validate))
			Track(box.FocusLost:Connect(function(enter)
				if enter then
					validate()
				end
			end))

			repeat
				task.wait()
			until done
			gui:Destroy()
		end
	end

	local gui = New("ScreenGui", {
		Name = RandomName(),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		AutoLocalize = false,
		IgnoreGuiInset = true,
		DisplayOrder = MAX_DISPLAY_ORDER,
	})
	ParentGui(gui)

	local main = New("Frame", {
		Visible = false,
		Size = UDim2.fromOffset(width, height),
		Position = opts.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = Theme.WindowAlpha,
		Interactable = true,
		BorderSizePixel = 0,
		Parent = gui,
		ThemeTag = { BackgroundColor3 = "Window" },
	})
	Corner(main, 10)

	local innerOutline = New("Frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 250,
		Parent = main,
	})
	Corner(innerOutline, 9)
	local innerStroke = Stroke(innerOutline, Theme.WindowBorder, 1, 0)
	Library:Tag(innerStroke, { Color = "WindowBorder" })
	local scale = New("UIScale", { Parent = main })

	local topBar = New("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.TopBar,
		BorderSizePixel = 0,
		ZIndex = 211,
		Parent = main,
		ThemeTag = { BackgroundColor3 = "TopBar" },
	})
	Corner(topBar, 10)
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 1, -12),
		BackgroundColor3 = Theme.TopBar,
		BorderSizePixel = 0,
		Parent = topBar,
		ThemeTag = { BackgroundColor3 = "TopBar" },
	})
	local title = New("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = topBar,
	})
	local titleList = List(title, 0, Enum.FillDirection.Horizontal)
	titleList.VerticalAlignment = Enum.VerticalAlignment.Center

	local titleName = Label(title, opts.Title or "layer", Theme.Accent, Theme.TextSize, Theme.FontMedium)
	Library:Tag(titleName, { TextColor3 = "Accent" })
	titleName.Size = UDim2.new(0, 0, 1, 0)
	titleName.AutomaticSize = Enum.AutomaticSize.X
	local titleSuffix = Label(title, opts.Suffix or ".app", Theme.Highlight, Theme.TextSize, Theme.FontMedium)
	Library:Tag(titleSuffix, { TextColor3 = "Highlight" })
	titleSuffix.Size = UDim2.new(0, 0, 1, 0)
	titleSuffix.AutomaticSize = Enum.AutomaticSize.X
	titleSuffix.LayoutOrder = 2
	local titleDivider = New("Frame", {
		Size = UDim2.fromOffset(1, 14),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Parent = topBar,
		ThemeTag = { BackgroundColor3 = "Border" },
	})

	if opts.SectionTitleStyle == "border" or opts.SectionTitle == "border" then
		Library.SectionTitleStyle = "border"
	elseif opts.SectionTitleStyle == "inline" or opts.SectionTitle == "inline" then
		Library.SectionTitleStyle = "inline"
	end

	local tabStyle = (opts.TabStyle == "side" or opts.CategoryMod == 2) and "side" or "top"
	local tabWidth = opts.TabWidth or 140
	local footerHeight = opts.Footer == false and 0 or 40

	local tabBar
	local layoutTabs

	if tabStyle == "side" then
		titleDivider.Visible = false

		tabBar = New("ScrollingFrame", {
			Size = UDim2.new(0, tabWidth, 1, -(47 + footerHeight + 22)),
			ScrollHint = false,
			Position = UDim2.fromOffset(14, 58),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			Parent = main,
		})
		List(tabBar, 4)

		layoutTabs = function() end
	else
		tabBar = New("ScrollingFrame", {
			Size = UDim2.new(1, -180, 1, 0),
			Position = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			Parent = topBar,
		})
		local tabList = List(tabBar, 16, Enum.FillDirection.Horizontal)
		tabList.VerticalAlignment = Enum.VerticalAlignment.Center

		local lastTabX
		layoutTabs = function()
			local s = math.max(scale.Scale, 0.05)
			local titleWidth = math.floor(title.AbsoluteSize.X / s + 0.5)
			local x = 16 + titleWidth + 28
			if x == lastTabX then
				return
			end
			lastTabX = x
			titleDivider.Position = UDim2.new(0, 16 + titleWidth + 12, 0.5, 0)
			tabBar.Position = UDim2.fromOffset(x, 0)
			tabBar.Size = UDim2.new(1, -(x + 14), 1, 0)
		end
	end
	Track(title:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTabs))
	layoutTabs()

	New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, 46),
		BackgroundColor3 = Theme.BorderSoft,
		BorderSizePixel = 0,
		Parent = main,
		ThemeTag = { BackgroundColor3 = "BorderSoft" },
	})

	local shellLeft = tabStyle == "side" and (14 + tabWidth + 10) or 14
	local shell = New("Frame", {
		Size = UDim2.new(1, -(14 + shellLeft), 1, -(47 + footerHeight + 22)),
		Position = UDim2.fromOffset(shellLeft, 58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = main,
	})
	Corner(shell, 8)
	Stroke(shell, Theme.SectionBorder)

	local body = New("Frame", {
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = shell,
	})

	local footer, footerLine, footerLeft
	if footerHeight > 0 then
		footerLine = New("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, -footerHeight),
			BackgroundColor3 = Theme.BorderSoft,
			BorderSizePixel = 0,
			Parent = main,
			ThemeTag = { BackgroundColor3 = "BorderSoft" },
		})
		footer = New("Frame", {
			Size = UDim2.new(1, -46, 0, footerHeight - 1),
			Position = UDim2.new(0, 16, 1, -(footerHeight - 1)),
			BackgroundTransparency = 1,
			Parent = main,
		})
		local fList = List(footer, 16, Enum.FillDirection.Horizontal)
		fList.HorizontalAlignment = Enum.HorizontalAlignment.Right
		fList.VerticalAlignment = Enum.VerticalAlignment.Center

		footerLeft = New("Frame", {
			Size = UDim2.new(0, 0, 0, footerHeight - 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.new(0, 16, 1, -(footerHeight - 1)),
			BackgroundTransparency = 1,
			ZIndex = 265,
			Parent = main,
		})
		local lList = List(footerLeft, 10, Enum.FillDirection.Horizontal)
		lList.VerticalAlignment = Enum.VerticalAlignment.Center
	end

	local overlay = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 300,
		Parent = main,
	})
	local blocker = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 110,
		Parent = overlay,
	})

	local window = setmetatable({
		Gui = gui,
		Main = main,
		TopBar = topBar,
		TabBar = tabBar,
		Body = body,
		Footer = footer,
		FooterLeft = footerLeft,
		Overlay = overlay,
		Blocker = blocker,
		Scale = scale,
		TabStyle = tabStyle,
		TabWidth = tabWidth,
		BaseScale = 1,
		FloatStack = {},
		UserScale = Library.InterfaceUserScale or 1,
		Opacity = 1 - Theme.WindowAlpha,
		Width = width,
		Height = height,
		MinWidth = opts.MinWidth or 460,
		MinHeight = opts.MinHeight or 320,
		Tabs = {},
		Visible = false,
	}, Window)

	Track(blocker.Activated:Connect(function()
		window:CloseFloating()
	end))

	local scaleReconcileTicket = 0
	local function reconcileScaleLayout()
		scaleReconcileTicket = scaleReconcileTicket + 1
		local ticket = scaleReconcileTicket
		task.defer(function()
			RunService.RenderStepped:Wait()
			if ticket ~= scaleReconcileTicket or not main.Parent or not window.Visible then
				return
			end
			ClampRenderedFrame(main)
			for _, panel in window.FloatStack do window:RepositionFloating(panel) end
			local menu = Library.PlayerMenuApi
			if menu and menu.Open and menu.AnchorWindow == window and menu.SyncToAnchor then
				menu:SyncToAnchor(true)
			end
		end)
	end

	local function fit()
		local _, vp = GetFrameViewportRect(main)
		if vp.X <= 0 then
			return
		end
		local topLeftInset, bottomRightInset = GetDragSafeInsets()
		local safeWidth = math.max(1, vp.X - topLeftInset.X - bottomRightInset.X - LAYER_DRAG_MARGIN * 2)
		local safeHeight = math.max(1, vp.Y - topLeftInset.Y - bottomRightInset.Y - LAYER_DRAG_MARGIN * 2)
		local desired = math.clamp(window.UserScale or 1, 0.6, 1.4)
		local playerMenu = Library.PlayerMenuApi

		if playerMenu and playerMenu.Open and playerMenu.AnchorWindow == window then
			window:SetPlayerDockVisible(true, playerMenu, desired)
		elseif window.PlayerDockWidthActive then
			window:SetPlayerDockVisible(false, window.PlayerDockPanel)
		end

		local fitWidth = safeWidth / window.Width
		if playerMenu and playerMenu.Open and playerMenu.AnchorWindow == window then
			local dockWidth = tonumber(playerMenu.BaseWidth) or 384
			local gap = tonumber(playerMenu.DockGap) or 10
			fitWidth = math.max(1, safeWidth - gap) / (window.Width + dockWidth)
		end
		local fitHeight = safeHeight / window.Height
		local fitLimit = math.min(fitWidth, fitHeight)
		local s = math.max(0.1, math.min(desired, fitLimit))
		local changed = math.abs(window.BaseScale - s) > 0.0001
		window.BaseScale = s
		if window.Visible then
			SetUIScalePreservePosition(scale, s)
			if changed then
				Library:RefreshStandaloneScales()
				Library:_ScheduleHotkeyLayout()
			end
			reconcileScaleLayout()
		end
	end
	window.Refit = fit
	Track(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	fit()

	Library:EnsureSystemConfigEntries()

	if not Library.ScaleConfigRegistered then
		Library.ScaleConfigRegistered = true
		Library:Register("__layer_ui_scale", {
			Type = "UIScale",
			Get = function()
				return Library.InterfaceUserScale or window.UserScale or 1
			end,
			Set = function(value)
				Library:SetInterfaceUserScale(value)
			end,
		})
	end

	window.DragController = AttachSmoothFrameDrag(main, topBar, function()
		window:CloseFloating()
		RaiseLayerFrame(main)
		BeginCursorDrag()
		local menu = Library.PlayerMenuApi
		if menu and menu.Open and menu.AnchorWindow == window then
			menu.AnchorDragActive = true
			menu.AnchorDragScale = menu.Frame and GetFrameOffsetScale(menu.Frame) or nil
		end
	end, function()
		return not window.Resizing
	end, function()
		local menu = Library.PlayerMenuApi
		if menu and menu.Open and menu.AnchorWindow == window then
			menu.AnchorDragActive = false
			menu.AnchorDragScale = nil
			menu:SyncToAnchor(true)
		end
	end, function()
		local menu = Library.PlayerMenuApi
		if menu and menu.Open and menu.AnchorWindow == window then
			menu:SyncToAnchor(true)
		end
	end)

	local grip = New("TextButton", {
		Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = true,
		ZIndex = 130,
		Parent = main,
	})
	local gripBars = {}
	for i, d in { 3, 7, 11 } do
		local bar = New("Frame", {
			Size = UDim2.fromOffset(d * 2, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(16 - d, 16 - d),
			Rotation = -45,
			BackgroundColor3 = Theme.Border,
			BorderSizePixel = 0,
			ZIndex = 130,
			Parent = grip,
			ThemeTag = { BackgroundColor3 = "Border" },
		})
		Corner(bar, 1)
		gripBars[i] = bar
	end
	Track(grip.MouseEnter:Connect(function()
		for _, bar in gripBars do
			Tween(bar, { BackgroundColor3 = Theme.Accent }, EASE_FAST)
		end
	end))
	Track(grip.MouseLeave:Connect(function()
		if window.Resizing then
			return
		end
		for _, bar in gripBars do
			Tween(bar, { BackgroundColor3 = Theme.Border }, EASE_FAST)
		end
	end))

	local resizeMove, resizeEnd
	local function cancelResize()
		if not window.Resizing then
			return
		end
		window.Resizing = false
		if resizeMove then
			resizeMove:Disconnect()
			resizeMove = nil
		end
		if resizeEnd then
			resizeEnd:Disconnect()
			resizeEnd = nil
		end
		for _, bar in gripBars do
			Tween(bar, { BackgroundColor3 = Theme.Border }, EASE_FAST)
		end
	end
	window.CancelResize = cancelResize

	Track(grip.InputBegan:Connect(function(input)
		if not IsInteractive(grip) then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		if window.DragController then
			window.DragController:Cancel()
		end
		cancelResize()
		window.Resizing = true
		window:CloseFloating()
		local origin = ScreenVector2(input.Position)
		local startW, startH = window.Width, window.Height
		local resizeScale = GetFrameRenderScale(main)
		local oldAnchor = main.AnchorPoint
		local anchorShift = Vector2.new(startW * resizeScale * oldAnchor.X, startH * resizeScale * oldAnchor.Y)
		local anchorShiftOffsets = ScreenPixelsToOffsets(main, anchorShift)

		main.Position = UDim2.new(
			main.Position.X.Scale,
			main.Position.X.Offset - anchorShiftOffsets.X,
			main.Position.Y.Scale,
			main.Position.Y.Offset - anchorShiftOffsets.Y
		)
		main.AnchorPoint = Vector2.new(0, 0)
		local fixedTopLeftScreen = main.AbsolutePosition

		resizeMove = UserInputService.InputChanged:Connect(function(move)
			if not window.Resizing then
				return
			end
			if
				move.UserInputType ~= Enum.UserInputType.MouseMovement
				and move.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			local vpOrigin, vp = GetFrameViewportRect(main)
			local delta = ScreenVector2(move.Position) - origin
			local safeRight = vpOrigin.X + vp.X - LAYER_DRAG_MARGIN
			local safeBottom = vpOrigin.Y + vp.Y - LAYER_DRAG_MARGIN
			local playerMenu = Library.PlayerMenuApi
			local dockWidth = 0
			if playerMenu and playerMenu.Open and playerMenu.AnchorWindow == window then
				local panelWidth = playerMenu.Frame and GetRenderedOffsetSize(playerMenu.Frame).X or 0
				dockWidth = (tonumber(playerMenu.DockGap) or 10) + panelWidth
			end
			local availableW = math.max(1, safeRight - fixedTopLeftScreen.X - dockWidth)
			local availableH = math.max(1, safeBottom - fixedTopLeftScreen.Y)
			local maxW = math.max(window.MinWidth, availableW / resizeScale)
			local maxH = math.max(window.MinHeight, availableH / resizeScale)
			local w = math.floor(math.clamp(startW + delta.X / resizeScale, window.MinWidth, maxW) + 0.5)
			local h = math.floor(math.clamp(startH + delta.Y / resizeScale, window.MinHeight, maxH) + 0.5)
			if w == window.Width and h == window.Height then
				return
			end

			window.Width = w
			window.Height = h

			if window.PlayerDockWidthActive then
				window.PlayerDockRestoreWidth = w
			end
			main.Size = UDim2.fromOffset(w, h)
		end)

		resizeEnd = UserInputService.InputEnded:Connect(function(ended)
			if ended.UserInputType ~= input.UserInputType then
				return
			end

			local finalScale = GetFrameRenderScale(main)
			local restoreShift =
				Vector2.new(window.Width * finalScale * oldAnchor.X, window.Height * finalScale * oldAnchor.Y)
			local restoreOffsets = ScreenPixelsToOffsets(main, restoreShift)
			main.Position = UDim2.new(
				main.Position.X.Scale,
				main.Position.X.Offset + restoreOffsets.X,
				main.Position.Y.Scale,
				main.Position.Y.Offset + restoreOffsets.Y
			)
			main.AnchorPoint = oldAnchor

			cancelResize()
			ClampRenderedFrameNextFrame(main)
		end)
	end))

	if opts.Cursor ~= false then
		Library:SetCursor(true, type(opts.Cursor) == "table" and opts.Cursor or nil)
	else
		Library:SetCursor(false)
	end

	if opts.MobileButton == true or (opts.MobileButton ~= false and UserInputService.TouchEnabled) then
		Library:CreateMobileButton(opts.MobileButtonOptions)
	end

	window.PlayersDisabled = opts.PlayerMenu == false
	window.PlayerMenuOptions = type(opts.PlayerMenu) == "table" and opts.PlayerMenu or opts.PlayerMenuOptions
	if not window.PlayersDisabled and window.FooterLeft then
		window.PlayerMenuButton = window:IconAction("users", function()
			Library:TogglePlayers(window)
		end, -50)
	end

	if opts.ServerBrowser ~= false and window.FooterLeft then
		local serverBrowserOptions = type(opts.ServerBrowser) == "table" and opts.ServerBrowser
			or opts.ServerBrowserOptions
		window.ServerBrowserButton = window:IconAction("server", function()
			for _, modal in window.Modals or {} do
				if modal.Open and modal.SetOpen then
					modal:SetOpen(false)
				end
			end

			local resolved = {}
			if type(serverBrowserOptions) == "table" then
				for key, value in serverBrowserOptions do
					resolved[key] = value
				end
			end

			resolved.AnchorWindow = window
			local browser = Library:ServerBrowser(resolved)
			if browser.SetAnchorWindow then
				browser:SetAnchorWindow(window)
			end
			browser:Toggle()
		end, -49)
	end

	table.insert(Library.Windows, window)
	Track(scale:GetPropertyChangedSignal("Scale"):Connect(function()
		Library:RefreshStandaloneScales()
		if window.Visible then
			reconcileScaleLayout()
		end
	end))
	Library:RefreshStandaloneScales()
	window:SetVisible(Library.Open and opts.Visible ~= false)
	return window
end

Library.MiniNotificationsEnabled = true
Library.MiniNotificationLimit = nil
Library.MiniNotificationSoundId = "rbxassetid://89087762338808"
Library.MiniNotificationSoundVolume = 0.65
Library.DamageNumbersEnabled = true
Library.DamageNumberLimit = 64
Library.DamageNumberRenderer = "auto"
Library.DamageNumberDrawingFont = 2
Library.DamageNumberDrawRate = 60
Library.DamageDrawingPoolLimit = 24

Library.FeedbackQueue = {}
Library.FeedbackIntervals = { mini = 0.04, damage = 0.025 }
Library.FeedbackNextEmission = {}
function Library:_QueueTransientFeedback(callback, creation, sequenceKey)
	if self.Destroyed then return false end
	 
	if creation and #self.FeedbackQueue >= 256 then return false end
	table.insert(self.FeedbackQueue, {
		Callback = callback,
		Kind = type(creation) == "string" and creation or nil,
		Sequence = creation == "mini" and ("mini:" .. tostring(sequenceKey or "")) or creation,
	})
	return true
end
Track(RunService.Heartbeat:Connect(function()
	if Library.Destroyed then
		Library.FeedbackQueue = {}
		return
	end
	if #Library.FeedbackQueue == 0 and FirstTableKey(Library.FeedbackNextEmission) == nil then return end
	local clock = os.clock()
	for key, deadline in Library.FeedbackNextEmission do
		if clock >= deadline then Library.FeedbackNextEmission[key] = nil end
	end
	if Library.FeedbackWorkerBusy or #Library.FeedbackQueue == 0 then return end
	Library.FeedbackWorkerBusy = true
	local available = #Library.FeedbackQueue
	local deadline = os.clock() + 0.002
	local index, inspected, processed = 1, 0, 0
	while inspected < available and processed < 32 do
		if Library.Destroyed or index > #Library.FeedbackQueue then break end
		local request = Library.FeedbackQueue[index]
		local now = os.clock()
		local interval = request.Kind and Library.FeedbackIntervals[request.Kind]
		local due = not interval or now >= (Library.FeedbackNextEmission[request.Sequence] or 0)
		inspected = inspected + 1
		if due then
			table.remove(Library.FeedbackQueue, index)
			if interval then Library.FeedbackNextEmission[request.Sequence] = now + interval end
			processed = processed + 1
			local ok, err = xpcall(request.Callback, function(message)
				return debug.traceback(tostring(message), 2)
			end)
			if not ok then warn("UI | Feedback worker failed:\n" .. tostring(err)) end
		else
			index = index + 1
		end
		if os.clock() >= deadline then break end
	end
	Library.FeedbackWorkerBusy = false
end))

local function FeedbackDuration(value, fallback)
	value = tonumber(value)
	if not value or value ~= value or math.abs(value) == math.huge then
		return fallback
	end
	return math.clamp(value, 0.1, 30)
end

function Library:_ScheduleMiniNotificationExpiry(entry)
	entry.ExpiryTicket = (entry.ExpiryTicket or 0) + 1
	if entry.ExpiryTask then return end
	local function expire()
		entry.ExpiryTask = nil
		if self.Destroyed or entry.Dead then return end
		local remaining = entry.Expires - os.clock()
		if remaining > 0 then
			entry.ExpiryTask = task.delay(remaining, expire)
		else
			entry:Dismiss()
		end
	end
	entry.ExpiryTask = task.delay(math.max(0, entry.Expires - os.clock()), expire)
end

function Library:_ReflowMiniNotifications(animate)
	local offset = 0
	for _, entry in self.MiniNotifications or {} do
		if not entry.Dead then
			if entry.Motion then entry.Motion:Cancel(); entry.Motion = nil end
			entry.StackY = entry.StackY or entry.Frame.Position.Y.Offset
			entry.TargetY = offset
			if not animate then
				entry.StackY = offset
				entry.Frame.Position = UDim2.new(0.5, 0, 0, offset)
			end
			 
			offset = offset + entry.Height - 6 + 3
		end
	end
end

local function FollowMiniNotificationSize(entry, frame, targetSize, dt)
	if not targetSize then return end
	local motion = entry.SizeTransitions[frame]
	if not motion or motion.Target ~= targetSize then
		motion = { Start = frame.Size, Target = targetSize, Elapsed = 0 }
		entry.SizeTransitions[frame] = motion
	end
	motion.Elapsed = math.min(0.18, motion.Elapsed + dt)
	local t = motion.Elapsed / 0.18
	local size = t >= 1 and targetSize or motion.Start:Lerp(targetSize, 1 - (1 - t) ^ 2)
	if frame.Size ~= size then frame.Size = size end
end

local function BeginMiniNotificationCountRoll(entry)
	local previous = entry.DisplayedCount or 1
	if entry.CountRollElapsed or previous >= (entry.CountTarget or 1) then return end
	local nextCount = previous + 1
	entry.CountViewport.Visible = true
	entry.CountPrevious.Text = previous > 1 and "x" .. previous or ""
	entry.CountPrevious.Visible = previous > 1
	entry.CountText.Text = "x" .. nextCount
	entry.DisplayedCount = nextCount
	entry.CountRollElapsed = 0
	 
	entry.CountRollDuration = math.max(0.05, 0.075 - (entry.CountTarget - nextCount) * 0.002)
	entry.CountText.Position = UDim2.new(0, 0, 0.5, 8)
	entry.CountPrevious.Position = UDim2.new(0, 0, 0.5, 0)
	SetVisual(entry.CountText, "TextTransparency", 0.65)
	SetVisual(entry.CountPrevious, "TextTransparency", 0)
end

local function PublishMiniNotificationCount(entry)
	local count = entry.PendingCount or 1
	local width, height = entry.TargetTextWidth, entry.TargetTextHeight
	local countWidth, gap = entry.PendingCountWidth or 0, entry.PendingCountGap or 0
	entry.Text.Text = entry.Message
	entry.Text.AnchorPoint = Vector2.new(0, 0.5)
	entry.Text.Position = UDim2.new(0, 10, 0.5, 0)
	entry.Text.Size = UDim2.fromOffset(math.max(1, width - countWidth - gap), height)
	entry.Text.Visible = true
	entry.CountViewport.Size = UDim2.fromOffset(countWidth, height)
	entry.CountViewport.Position = UDim2.new(0, 10 + width - countWidth, 0.5, 0)
	entry.CountTarget = count
	entry.DisplayedCount = entry.DisplayedCount or 1
	BeginMiniNotificationCountRoll(entry)
	entry.PendingText = nil
end

local function StepMiniNotificationCount(entry, dt)
	local elapsed = entry.CountRollElapsed
	if elapsed == nil then
		BeginMiniNotificationCountRoll(entry)
		elapsed = entry.CountRollElapsed
		if elapsed == nil then return end
	end
	local duration = entry.CountRollDuration
	elapsed = math.min(duration, elapsed + dt)
	local t = elapsed / duration
	local eased = math.sin(t * math.pi * 0.5)
	entry.CountText.Position = UDim2.new(0, 0, 0.5, 8 * (1 - eased))
	entry.CountPrevious.Position = UDim2.new(0, 0, 0.5, -8 * eased)
	SetVisual(entry.CountText, "TextTransparency", 0.65 * (1 - eased))
	SetVisual(entry.CountPrevious, "TextTransparency", eased)
	if t >= 1 then entry.CountPrevious.Visible = false end
	entry.CountRollElapsed = t < 1 and elapsed or nil
	if t >= 1 then BeginMiniNotificationCountRoll(entry) end
end

function Library:_StepMiniNotificationStack(deltaTime)
	local dt = math.max(tonumber(deltaTime) or 1 / 60, 0)
	local previousBottom
	for _, entry in self.MiniNotifications or {} do
		if not entry.Dead then
			entry.SizeTransitions = entry.SizeTransitions or {}
			FollowMiniNotificationSize(entry, entry.Frame, entry.TargetFrameSize, dt)
			FollowMiniNotificationSize(entry, entry.Surface, entry.TargetSurfaceSize, dt)
			 
			if entry.PendingText and entry.PendingTextReady and entry.TargetFrameSize
				and entry.Frame.Size.X.Offset >= entry.TargetFrameSize.X.Offset - 0.5
				and entry.Surface.Size.Y.Offset >= entry.TargetSurfaceSize.Y.Offset - 0.5 then
				PublishMiniNotificationCount(entry)
			end
			StepMiniNotificationCount(entry, dt)
			local target = entry.TargetY or 0
			local current = entry.StackY or entry.Frame.Position.Y.Offset
			local motion = entry.StackTransition
			if not motion or motion.Target ~= target then
				motion = { Start = current, Target = target, Elapsed = 0 }
				entry.StackTransition = motion
			end
			motion.Elapsed = math.min(0.22, motion.Elapsed + dt)
			local t = motion.Elapsed / 0.22
			local y = t >= 1 and target or motion.Start + (target - motion.Start) * (1 - (1 - t) ^ 2)
			 
			if previousBottom then y = math.max(y, previousBottom + 3) end
			entry.StackY = y
			local position = UDim2.new(0.5, 0, 0, y)
			if entry.Frame.Position ~= position then entry.Frame.Position = position end
			previousBottom = y + math.max(entry.Height, entry.Frame.Size.Y.Offset) - 6
		end
	end
end

function Library:_ClearTransientFeedback()
	self.FeedbackClearing = true
	self.FeedbackQueue = {}
	self.FeedbackNextEmission = {}
	if self.FeedbackConnection then
		self.FeedbackConnection:Disconnect()
		self.FeedbackConnection = nil
	end
	for _, entries in { self.MiniNotifications or {}, self.DamageNumbers or {} } do
		for _, entry in entries do
			entry.Dead = true
			if entry.ExpiryTask and task.cancel then pcall(task.cancel, entry.ExpiryTask) end
			entry.ExpiryTask = nil
			if entry.Motion then entry.Motion:Cancel() end
			self:_DestroyDamageNumberVisual(entry)
		end
	end
	self.MiniNotifications = {}
	self.DamageNumbers = {}
	for _, pooled in self.DamageDrawingPool or {} do self:_RemoveDamageDrawing(pooled.Object) end
	self.DamageDrawingPool = {}
	self.FeedbackClearing = false
	if self.FeedbackGui then self.FeedbackGui:Destroy() end
	self.FeedbackGui = nil
	self.MiniNotificationHolder = nil
	for sound in self.MiniNotificationSounds or {} do sound:Destroy() end
	self.MiniNotificationSounds = {}
	self.MiniNotificationSoundPool = {}
	self.MiniNotificationSoundIndex = 0
end

function Library:_PlayMiniNotificationSound()
	self.MiniNotificationSoundPool = self.MiniNotificationSoundPool or {}
	self.MiniNotificationSounds = self.MiniNotificationSounds or {}
	local index = (self.MiniNotificationSoundIndex or 0) % 4 + 1
	self.MiniNotificationSoundIndex = index
	local sound = self.MiniNotificationSoundPool[index]
	if not sound then
		sound = New("Sound", {
			SoundId = self.MiniNotificationSoundId,
			Volume = 0, Parent = SoundService,
		})
		self.MiniNotificationSoundPool[index] = sound
		self.MiniNotificationSounds[sound] = true
	end
	sound:Stop()
	sound.SoundId = self.MiniNotificationSoundId
	sound.Volume = math.clamp(tonumber(self.MiniNotificationSoundVolume) or 0.65, 0, 1)
	sound.TimePosition = 0
	sound:Play()
end

function Library:_EnsureTransientFeedback()
	if self.Destroyed then return false end
	if not self.FeedbackGui then
		local gui = New("ScreenGui", {
			Name = RandomName(), ResetOnSpawn = false, IgnoreGuiInset = true,
			AutoLocalize = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = MAX_DISPLAY_ORDER,
		})
		ParentGui(gui)
		self.FeedbackGui = gui
		self.MiniNotifications = {}
		self.DamageNumbers = {}
		local holder = New("Frame", {
			Size = UDim2.fromOffset(340, 0), AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.66), BackgroundTransparency = 1,
			Parent = gui,
		})
		self.MiniNotificationHolder = holder
		self:RegisterStandaloneScale(New("UIScale", { Scale = 1, Parent = holder }), 1, false, function()
			for _, entry in self.MiniNotifications or {} do
				if not entry.Dead then self:_LayoutMiniNotification(entry) end
			end
		end)
	end
	if not self.FeedbackConnection then
		self.FeedbackConnection = Track(RunService.RenderStepped:Connect(function(deltaTime)
			local now = os.clock()
			for i = #self.MiniNotifications, 1, -1 do
				local entry = self.MiniNotifications[i]
				if not entry.Dead and not entry.Closing and now >= entry.Expires then
					entry:Dismiss()
				end
				if entry.Dead or (entry.Closing and now >= entry.RemoveAt) then
					entry:Destroy()
					table.remove(self.MiniNotifications, i)
				end
			end
			self:_ReflowMiniNotifications(true)
			self:_StepMiniNotificationStack(deltaTime)
			local camera = workspace.CurrentCamera
			local viewport = camera and camera.ViewportSize
			local scale = self:GetInterfaceScale()
			for i = #self.DamageNumbers, 1, -1 do
				local entry = self.DamageNumbers[i]
				local age = (now - entry.Started) / entry.Duration
				if entry.Dead or age >= 1 then
					entry:Destroy()
					table.remove(self.DamageNumbers, i)
				elseif camera then
					local x, y, visible
					local elapsed = now - entry.Started
					local flightProgress = 0
					local distanceScale = 1
					local spreadScale = 1
					if entry.WorldPosition then
						local position = entry.WorldPosition
						flightProgress = age
						local distance = (camera.CFrame.Position - position).Magnitude
						spreadScale = math.clamp(35 / math.max(distance, 35), 0.1, 1)
						local t = math.clamp((distance - 25) / 175, 0, 1)
						distanceScale = 0.8 - 0.1 * t * t * (3 - 2 * t)
						local point, onScreen = camera:WorldToViewportPoint(position)
						x, y, visible = point.X, point.Y, onScreen and point.Z > 0
					elseif typeof(entry.Position) == "UDim2" then
						x = viewport.X * entry.Position.X.Scale + entry.Position.X.Offset
						y = viewport.Y * entry.Position.Y.Scale + entry.Position.Y.Offset
						visible = true
					else
						x, y, visible = entry.Position.X, entry.Position.Y, true
					end
					local pop
					if elapsed < 0.075 then
						local t = elapsed / 0.075
						pop = 0.55 + 0.77 * (1 - (1 - t) ^ 2)
					else
						local t = math.clamp((elapsed - 0.075) / 0.125, 0, 1)
						pop = 1 + 0.32 * (1 - t) ^ 2
					end
					local textSize = entry.Size * scale * pop * distanceScale
					local fall = age * age
					local rotation = (entry.Tilt or 0) * (1 - age) ^ 2 + (entry.FallDrift or 0) * 0.5 * fall
					local screenX, screenY, fade
					if entry.WorldPosition then
						local turn = entry.SpinSign or 1
						local wobble = math.sin(elapsed * 15 + (entry.WobblePhase or 0)) * 5 * math.sin(math.pi * flightProgress)
						rotation = turn * (16 * (1 - flightProgress) + 18 * flightProgress ^ 2) + wobble
						local path = self:_DamageNumberFlightOffset(entry, flightProgress)
						local travelScale = math.sqrt(spreadScale)
						screenX = x + ((entry.OffsetX or 0) * 0.12 * spreadScale + path.X * travelScale) * scale
						screenY = y + ((entry.OffsetY or 0) * 0.2 * spreadScale + path.Y * travelScale) * scale
						fade = math.clamp((flightProgress - 0.55) / 0.4, 0, 1)
					else
						screenX = x + ((entry.OffsetX or 0) + entry.Drift * age + (entry.FallDrift or 0) * fall) * scale
						local flightY = entry.Rise * (6.25 * fall - 5 * age)
						screenY = y + ((entry.OffsetY or 0) + flightY) * scale
						fade = math.clamp((age - 0.5) / 0.5, 0, 1)
					end
					local alpha = fade * fade * (3 - 2 * fade)
					self:_RenderDamageNumber(entry, screenX, screenY, textSize, rotation, alpha, visible)
				else
					if entry.Drawing then
						entry.Drawing.Visible = false
						if entry.DrawingState then entry.DrawingState.Visible = false end
					else entry.Frame.Visible = false end
				end
			end
			if #self.MiniNotifications == 0 and #self.DamageNumbers == 0 then
				self.FeedbackConnection:Disconnect()
				self.FeedbackConnection = nil
			end
		end))
	end
	return true
end

function Library:MiniNotify(opts, duration)
	if self.MiniNotificationsEnabled == false or self.Destroyed then return nil end
	if type(opts) == "table" then
		local copy = {}
		for key, value in opts do copy[key] = value end
		opts = copy
	end
	local notification
	local cancelled = false
	local handle = {}
	function handle:Destroy()
		if cancelled then return end
		cancelled = true
		if notification then
			Library:_QueueTransientFeedback(function() notification:Destroy() end)
		end
	end
	function handle:Dismiss()
		if notification then
			Library:_QueueTransientFeedback(function()
				if not cancelled then notification:Dismiss() end
			end)
		else
			cancelled = true
		end
	end
	setmetatable(handle, { __index = function(_, key)
		if key == "Dead" then return cancelled or (notification and notification.Dead) or false end
		return notification and notification[key] or nil
	end })
	 
	local sequenceKey = type(opts) == "table" and tostring(opts.Text or opts.Content or "") or tostring(opts or "")
	 
	local queued = self:_QueueTransientFeedback(function()
		if cancelled or self.Destroyed then return end
		local ok, result = xpcall(function()
			return self:_CreateMiniNotification(opts, duration)
		end, function(err)
			return debug.traceback(tostring(err), 2)
		end)
		if not ok then
			cancelled = true
			warn("UI | MiniNotify failed:\n" .. tostring(result))
			return
		end
		notification = result
		if not notification then
			cancelled = true
		elseif cancelled or self.Destroyed then
			notification:Destroy()
		end
	end, "mini", sequenceKey)
	if not queued then cancelled = true end
	return handle
end

function Library:_LayoutMiniNotification(entry)
	entry.LayoutTicket = (entry.LayoutTicket or 0) + 1
	local ticket = entry.LayoutTicket
	local padX, padY = 10, 4
	local message = entry.Message .. (entry.Count > 1 and ("  x" .. entry.Count) or "")
	entry.PendingText = message
	entry.PendingCount = entry.Count
	entry.PendingTextReady = false
	local rearCount = math.min(entry.Count - 1, 2)
	local depth = rearCount > 0 and (4 + (rearCount - 1) * 3) or 0
	entry.BackPositionMotions = entry.BackPositionMotions or {}
	entry.BackSizeTargets = entry.BackSizeTargets or {}
	entry.BackSizeMotions = entry.BackSizeMotions or {}
	local info = TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local function placeBack(frame, visible, offset, z)
		local wasVisible = frame.Visible
		frame.Visible = visible
		if not visible then return end
		frame.ZIndex = z
		if not wasVisible then
			entry.BackPositionMotions[frame] = Tween(frame,
				{ Position = UDim2.new(0.5, 0, 0, offset) }, info)
		end
		CancelNativeGroupTween(frame)
		SetGroupTransparency(frame, 0.12)
	end
	placeBack(entry.BackOne, entry.Count >= 2, 18, 3)
	placeBack(entry.BackTwo, entry.Count >= 3, 21, 2)
	local function apply(width, height)
		entry.TargetTextWidth, entry.TargetTextHeight = width, height
		if not entry.LayoutReady then entry.Text.Size = UDim2.fromOffset(width, height) end
		local cardHeight = height + padY * 2
		local surfaceSize = UDim2.new(1, 0, 0, cardHeight)
		local frameSize = UDim2.fromOffset(width + padX * 2, cardHeight + depth + 6)
		entry.TargetFrameSize = frameSize
		entry.TargetSurfaceSize = surfaceSize
		if not entry.LayoutReady then
			entry.Frame.Size = frameSize
			entry.Surface.Size = surfaceSize
			entry.LayoutReady = true
		end
		local function resizeBack(frame, inset)
			local target = UDim2.new(1, -inset, 0, cardHeight - 8)
			if frame.Visible and entry.BackSizeTargets[frame] == target then return end
			local previous = entry.BackSizeMotions[frame]
			if previous then previous:Cancel() end
			if frame.Visible then
				local motion = Tween(frame, { Size = target }, info)
				entry.BackSizeMotions[frame] = motion
				entry.BackSizeTargets[frame] = target
			else
				frame.Size = UDim2.new(1, 0, 0, cardHeight)
				entry.BackSizeMotions[frame] = nil
				entry.BackSizeTargets[frame] = nil
			end
		end
		resizeBack(entry.BackOne, 16)
		resizeBack(entry.BackTwo, 28)
		entry.Height = cardHeight + depth + 6
		self:_ReflowMiniNotifications(true)
	end
	 
	local currentHeight = entry.Text.Size.Y.Offset
	if not entry.LayoutReady then
		apply(math.max(40, entry.Text.Size.X.Offset), math.max(currentHeight, Theme.TextSize + 4))
	else
		entry.Height = math.max(entry.Height, entry.Surface.Size.Y.Offset + depth + 6)
		self:_ReflowMiniNotifications(true)
	end
	if entry.MeasureBusy then entry.MeasureDirty = true; return end
	entry.MeasureBusy = true
	entry.MeasureDirty = false
	task.defer(function()
		local ok, err = xpcall(function()
			if entry.Dead or self.Destroyed or ticket ~= entry.LayoutTicket then return end
			local renderScale = math.max(self:GetInterfaceScale(), 0.05)
			local viewport = GetDragViewportSize()
			local maxWidth = math.max(40, math.min(320, viewport.X / renderScale - 48))
			local probe = entry.MeasureLabel
			if not probe then
				probe = New("TextLabel", {
					Visible = false, BackgroundTransparency = 1, RichText = false,
					Text = message, TextSize = entry.Text.TextSize, Font = entry.Text.Font,
					TextWrapped = false, AutomaticSize = Enum.AutomaticSize.XY,
					Size = UDim2.fromOffset(0, 0), Parent = self.FeedbackGui,
				})
				entry.MeasureLabel = probe
			end
			probe.FontFace = entry.Text.FontFace
			probe.Text, probe.TextSize = message, entry.Text.TextSize
			probe.TextWrapped = false
			probe.AutomaticSize = Enum.AutomaticSize.XY
			probe.Size = UDim2.fromOffset(0, 0)
			RunService.RenderStepped:Wait()
			if entry.Dead or self.Destroyed or ticket ~= entry.LayoutTicket then return end
			local bounds = probe.TextBounds
			if bounds.X <= 0 then
				RunService.RenderStepped:Wait()
				if entry.Dead or self.Destroyed or ticket ~= entry.LayoutTicket then return end
				bounds = probe.TextBounds
			end
			local width = math.min(maxWidth, math.max(1, bounds.X + 2))
			local wrapped = bounds.X + 2 > maxWidth
			if wrapped then
				probe.TextWrapped = true
				probe.AutomaticSize = Enum.AutomaticSize.Y
				probe.Size = UDim2.fromOffset(width, 0)
				RunService.RenderStepped:Wait()
				if entry.Dead or self.Destroyed or ticket ~= entry.LayoutTicket then return end
				bounds = probe.TextBounds
			end
			if bounds.X <= 0 then width = math.min(maxWidth, math.max(40, #message * entry.Text.TextSize * 0.65)) end
			local count = entry.PendingCount or 1
			local suffixWidth, gap = 0, 0
			if count > 1 then
				local value = tostring(count)
				suffixWidth = math.ceil(math.max(MeasureRenderedTextWidth(entry.Text, "x" .. value),
					MeasureRenderedTextWidth(entry.Text, "x" .. string.rep("0", #value)))) + 2
				gap = math.ceil(MeasureRenderedTextWidth(entry.Text, "  "))
			end
			local messageWidth = math.ceil(MeasureRenderedTextWidth(entry.Text, entry.Message)) + 2
			if entry.Dead or self.Destroyed or ticket ~= entry.LayoutTicket then return end
			 
			width = math.min(maxWidth, messageWidth + suffixWidth + gap)
			wrapped = messageWidth + suffixWidth + gap > maxWidth
			local messageHeight = entry.Text.TextSize + 4
			if wrapped then
				probe.Text = entry.Message
				probe.TextWrapped = true
				probe.AutomaticSize = Enum.AutomaticSize.Y
				probe.Size = UDim2.fromOffset(math.max(1, width - suffixWidth - gap), 0)
				RunService.RenderStepped:Wait()
				if entry.Dead or self.Destroyed or ticket ~= entry.LayoutTicket then return end
				messageHeight = math.max(messageHeight, probe.TextBounds.Y + 2)
			end
			entry.PendingCountWidth, entry.PendingCountGap = suffixWidth, gap
			entry.Text.TextWrapped = wrapped
			entry.RenderedSizeReady = true
			apply(width, messageHeight)
			entry.PendingTextReady = true
		end, function(message)
			return debug.traceback(tostring(message), 2)
		end)
		entry.MeasureBusy = false
		if not ok and not entry.Dead and not self.Destroyed then warn("UI | MiniNotify measurement failed:\n" .. tostring(err)) end
		if entry.MeasureDirty and not entry.Dead and not self.Destroyed then
			entry.MeasureDirty = false
			self:_LayoutMiniNotification(entry)
		end
	end)
end

function Library:_CreateMiniNotification(opts, duration)
	if self.MiniNotificationsEnabled == false or self.Destroyed then return nil end
	if type(opts) ~= "table" then opts = { Text = tostring(opts or ""), Duration = duration } end
	local message = tostring(opts.Text or opts.Content or "")
	if message == "" or not self:_EnsureTransientFeedback() then return nil end
	for index, existing in self.MiniNotifications do
		if not existing.Dead and existing.Message == message and existing.Color == opts.Color then
			existing.Count = existing.Count + 1
			 
			existing.Expires = os.clock() + math.max(FeedbackDuration(opts.Duration, 2),
				(existing.Count - (existing.DisplayedCount or 1)) * 0.09 + 0.2)
			existing.Closing = false
			existing.RemoveAt = nil
			 
			TweenGroupTransparency(existing.Frame, 0,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
			self:_LayoutMiniNotification(existing)
			self:_ScheduleMiniNotificationExpiry(existing)
			if opts.Sound ~= false then self:_PlayMiniNotificationSound() end
			return existing
		end
	end
	local card = New("CanvasGroup", {
		Visible = true, GroupTransparency = 1, Size = UDim2.fromOffset(100, 28),
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = self.MiniNotificationHolder,
	})
	local function layer(inset, offset, z, alpha)
		local frame = New("CanvasGroup", {
			Size = UDim2.new(1, -inset, 0, 28), AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, offset), BackgroundColor3 = Theme.Window,
			BackgroundTransparency = 0, GroupTransparency = alpha, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = z, Parent = card,
			ThemeTag = { BackgroundColor3 = "Window" },
		})
		Corner(frame, 10)
		local border = New("Frame", {
			Size = UDim2.new(1, -2, 1, -2), Position = UDim2.fromOffset(1, 1),
			BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z, Parent = frame,
		})
		Corner(border, 9)
		Stroke(border, Theme.BorderSoft)
		return frame
	end
	local backTwo = layer(0, 6, 2, 0.12)
	local backOne = layer(0, 6, 3, 0.12)
	backOne.Visible, backTwo.Visible = false, false
	local function createSurface()
		local surface = layer(0, 6, 4, 0)
		local text = Label(surface, message, opts.Color or Theme.TextBright, Theme.TextSize)
		 
		text.Visible = false
		text.RichText = false
		text.TextWrapped = true
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.Position = UDim2.fromOffset(8, 3)
		text.Size = UDim2.fromOffset(80, Theme.TextSize + 4)
		text.ZIndex = 5
		if opts.Color then Library:Tag(text, { TextColor3 = false }) end
		return surface, text
	end
	local surface, text = createSurface()
	local countViewport = New("Frame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
		AnchorPoint = Vector2.new(0, 0.5), Visible = false, Active = false,
		ZIndex = 5, Parent = surface,
	})
	local function countLabel()
		local label = Label(countViewport, "", opts.Color or Theme.TextBright, Theme.TextSize)
		label.RichText = false
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Size = UDim2.fromScale(1, 1)
		label.Position = UDim2.fromScale(0, 0.5)
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.ZIndex = 5
		if opts.Color then Library:Tag(label, { TextColor3 = false }) end
		return label
	end
	local countText, countPrevious = countLabel(), countLabel()
	countPrevious.Visible = false
	local library = self
	local entry = { Frame = card, Surface = surface, Text = text, CountText = countText, CountPrevious = countPrevious, CountViewport = countViewport,
		BackOne = backOne, BackTwo = backTwo,
		Height = Theme.TextSize + 12, Message = message, Color = opts.Color, Count = 1,
		Expires = os.clock() + FeedbackDuration(opts.Duration, 2) }
	function entry:Destroy()
		if self.Dead then return end
		self.Dead = true
		if self.ExpiryTask and task.cancel then pcall(task.cancel, self.ExpiryTask) end
		self.ExpiryTask = nil
		if self.Motion then self.Motion:Cancel() end
		if self.EntryMotion then self.EntryMotion:Cancel() end
		if self.SizeMotion then self.SizeMotion:Cancel() end
		if self.SurfaceSizeMotion then self.SurfaceSizeMotion:Cancel() end
		for _, motion in self.BackPositionMotions or {} do motion:Cancel() end
		for _, motion in self.BackSizeMotions or {} do motion:Cancel() end
		CancelNativeGroupTween(self.Frame)
		CancelNativeGroupTween(self.BackOne)
		CancelNativeGroupTween(self.BackTwo)
		if self.MeasureLabel then self.MeasureLabel:Destroy(); self.MeasureLabel = nil end
		self.Frame:Destroy()
		library:_ReflowMiniNotifications(true)
	end
	function entry:Dismiss()
		if self.Dead or self.Closing then return end
		self.Closing = true
		self.RemoveAt = os.clock() + 0.4
		local ticket = self.ExpiryTicket
		 
		task.delay(0.4, function()
			if not self.Dead and self.Closing and self.ExpiryTicket == ticket then
				self:Destroy()
			end
		end)
		TweenGroupTransparency(self.Frame, 1,
			TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), function()
				if self.Closing then self:Destroy() end
			end)
	end
	local limit = tonumber(self.MiniNotificationLimit)
	if limit and limit >= 1 and limit < math.huge then
		while #self.MiniNotifications >= math.floor(limit) do
			table.remove(self.MiniNotifications):Destroy()
		end
	end
	 
	entry.StackY = -(entry.Height - 6 + 3)
	card.Position = UDim2.new(0.5, 0, 0, entry.StackY)
	table.insert(self.MiniNotifications, 1, entry)
	self:_LayoutMiniNotification(entry)
	self:_ScheduleMiniNotificationExpiry(entry)
	TweenGroupTransparency(card, 0, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
	if opts.Sound ~= false then self:_PlayMiniNotificationSound() end
	return entry
end

function Library:DamageNumber(amount, position, opts)
	if self.DamageNumbersEnabled == false or self.Destroyed then return nil end
	if type(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge then return nil end
	if type(opts) == "table" then
		local copy = {}
		for key, value in opts do copy[key] = value end
		opts = copy
	end
	local number
	local cancelled = false
	local handle = {}
	function handle:Destroy()
		if cancelled then return end
		cancelled = true
		if number then
			Library:_QueueTransientFeedback(function() number:Destroy() end)
		end
	end
	handle.Dismiss = handle.Destroy
	setmetatable(handle, { __index = function(_, key)
		if key == "Dead" then return cancelled or (number and number.Dead) or false end
		return number and number[key] or nil
	end })
	 
	local queued = self:_QueueTransientFeedback(function()
		if cancelled or self.Destroyed then return end
		local ok, result = xpcall(function()
			return self:_CreateDamageNumber(amount, position, opts)
		end, function(err)
			return debug.traceback(tostring(err), 2)
		end)
		if not ok then
			cancelled = true
			warn("UI | DamageNumber failed:\n" .. tostring(result))
			return
		end
		number = result
		if not number then
			cancelled = true
		elseif cancelled or self.Destroyed then
			number:Destroy()
		end
	end, "damage")
	if not queued then cancelled = true end
	return handle
end

function Library:_PrepareDamageNumberFlight(entry, opts)
	if not entry.WorldPosition then return end
	local side = math.random(0, 1) == 0 and -1 or 1
	local reach = math.random(75, 125) / 100
	local height = math.random(85, 115) / 100
	entry.SpinSign = side
	entry.WobblePhase = math.random() * math.pi * 2
	entry.FlightControlOne = Vector2.new(side * math.random(24, 36) * reach, -math.random(95, 115) * height)
	entry.FlightControlTwo = Vector2.new(side * math.random(86, 104) * reach, -math.random(90, 115) * height)
	entry.FlightEnd = Vector2.new(side * math.random(100, 120) * reach, math.random(80, 110) * height)
	if opts.Duration == nil then entry.Duration = math.random(65, 105) / 100 end
end

function Library:_DamageNumberFlightOffset(entry, progress)
	local t = math.clamp(progress, 0, 1)
	local inv = 1 - t
	local first, second, last = entry.FlightControlOne, entry.FlightControlTwo, entry.FlightEnd
	return first * (3 * inv * inv * t) + second * (3 * inv * t * t) + last * (t * t * t)
end

function Library:_RemoveDamageDrawing(object)
	pcall(function() object.Visible = false end)
	local removed = pcall(function() object:Remove() end)
	if not removed then pcall(function() object:Destroy() end) end
end

function Library:_TryCreateDamageDrawing(text, color, size, opts)
	if opts.Renderer == "gui" or self.DamageNumberRenderer == "gui"
		or not Drawing or type(Drawing.new) ~= "function" then return nil end
	local pooled = self.DamageDrawingPool and table.remove(self.DamageDrawingPool)
	local object = pooled and pooled.Object
	local ok = pcall(function()
		object = object or Drawing.new("Text")
		object.Visible = false
		object.Text = text
		object.Size = size
		object.Color = color
		object.Center = true
		object.Outline = true
		object.Font = tonumber(opts.DrawingFont) or self.DamageNumberDrawingFont or 2
		object.Transparency = 1
		object.Position = Vector2.new(0, 0)
	end)
	if not ok then
		if object then self:_RemoveDamageDrawing(object) end
		return nil
	end
	pcall(function() object.ZIndex = tonumber(opts.ZIndex) or 2147483647 end)
	pcall(function() object.OutlineColor = Color3.new(0, 0, 0) end)
	local canRotate
	if pooled then
		canRotate = pooled.CanRotate
	else
		canRotate = pcall(function() object.Rotation = 0 end)
	end
	return object, canRotate
end

function Library:_DestroyDamageNumberVisual(entry)
	if entry.Drawing then
		local object = entry.Drawing
		entry.Drawing = nil
		local hidden = pcall(function() object.Visible = false end)
		self.DamageDrawingPool = self.DamageDrawingPool or {}
		local limit = math.clamp(tonumber(self.DamageDrawingPoolLimit) or 24, 0, 64)
		if hidden and not self.Destroyed and not self.FeedbackClearing and #self.DamageDrawingPool < limit then
			table.insert(self.DamageDrawingPool, { Object = object, CanRotate = entry.DrawingCanRotate })
		else
			self:_RemoveDamageDrawing(object)
		end
		entry.DrawingState = nil
	elseif entry.Frame then
		entry.Frame:Destroy()
	end
end

local function SetDamageDrawingProperty(object, state, property, value)
	if state[property] ~= value then object[property] = value; state[property] = value end
end

function Library:_RenderDamageNumber(entry, x, y, size, rotation, alpha, visible)
	if entry.Drawing then
		local object = entry.Drawing
		local state = entry.DrawingState
		if not state then state = {}; entry.DrawingState = state end
		local show = visible and alpha < 1
		if not show then
			if state.Visible ~= false then object.Visible = false; state.Visible = false end
			return
		end
		local now = os.clock()
		if state.Visible and now + 0.00001 < (entry.NextDrawingUpdate or 0) then return end
		local rate = math.clamp(tonumber(self.DamageNumberDrawRate) or 60, 15, 120)
		local nextUpdate = (entry.NextDrawingUpdate or now) + 1 / rate
		entry.NextDrawingUpdate = nextUpdate > now and nextUpdate or now + 1 / rate
		local pixels = math.max(1, math.floor(size + 0.5))
		SetDamageDrawingProperty(object, state, "Size", pixels)
		SetDamageDrawingProperty(object, state, "Color", entry.Color or Theme.Accent)
		SetDamageDrawingProperty(object, state, "Transparency", 1 - alpha)
		if entry.DrawingCanRotate then SetDamageDrawingProperty(object, state, "Rotation", math.floor(rotation * 2 + 0.5) / 2) end
		if state.BoundsSize ~= pixels then
			local bounds = object.TextBounds
			state.HalfHeight = (bounds and bounds.Y or pixels) * 0.5
			state.BoundsSize = pixels
		end
		SetDamageDrawingProperty(object, state, "Position", Vector2.new(math.floor(x + 0.5), math.floor(y - state.HalfHeight + 0.5)))
		SetDamageDrawingProperty(object, state, "Visible", true)
	else
		entry.Frame.Visible = visible
		entry.Frame.TextSize = size
		entry.Frame.Rotation = rotation
		entry.Frame.Position = UDim2.fromOffset(x, y)
		SetVisual(entry.Frame, "TextTransparency", alpha)
		SetVisual(entry.Frame, "TextStrokeTransparency", 0.55 + alpha * 0.45)
	end
end

function Library:_CreateDamageNumber(amount, position, opts)
	opts = opts or {}
	if self.DamageNumbersEnabled == false or self.Destroyed then return nil end
	if type(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge then return nil end
	local worldPosition
	if typeof(position) == "Vector3" then
		worldPosition = position
	elseif typeof(position) == "Instance" then
		if position:IsA("BasePart") then worldPosition = position.Position
		elseif position:IsA("Model") then worldPosition = position:GetPivot().Position
		else return nil end
	elseif position ~= nil and typeof(position) ~= "Vector2" and typeof(position) ~= "UDim2" then
		return nil
	end
	if worldPosition then worldPosition = worldPosition + (opts.WorldOffset or Vector3.new(0, 2, 0)) end
	if not self:_EnsureTransientFeedback() then return nil end
	local text = opts.Text or tostring(math.floor(math.abs(amount) + 0.5))
	local size = tonumber(opts.Size) or Theme.TextSize + 14
	local color = opts.Color or (math.random(0, 1) == 0 and Theme.Accent or (Theme.Highlight or Theme.Accent))
	local drawing, canRotate = self:_TryCreateDamageDrawing(text, color, size, opts)
	local label
	if not drawing then
		label = Label(self.FeedbackGui, text, color, size, Theme.Font)
		 
		if not self.DamageNumberFontFace then
			local ok, face = pcall(function()
				return Font.new("rbxasset://fonts/families/BuilderExtended.json",
					Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
			end)
			if ok then self.DamageNumberFontFace = face end
		end
		pcall(function()
			if opts.FontFace then
				label.FontFace = opts.FontFace
			elseif self.DamageNumberFontFace then
				label.FontFace = self.DamageNumberFontFace
			else
				label.Font = Enum.Font.BuilderSansExtraBold
			end
		end)
		label.Visible = false
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.Size = UDim2.fromOffset(0, 0)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.RichText = false
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = 0.55
		Library:Tag(label, { TextColor3 = false })
	end
	local limit = math.max(1, math.floor(tonumber(self.DamageNumberLimit) or 64))
	while #self.DamageNumbers >= limit do
		table.remove(self.DamageNumbers, 1):Destroy()
	end
	local used = {}
	local recent
	local now = os.clock()
	for _, other in self.DamageNumbers do
		if not other.Dead and now - other.Started < other.Duration then
			local nearby = worldPosition and other.WorldPosition
				and (worldPosition - other.WorldPosition).Magnitude < 12
			if nearby or (not worldPosition and not other.WorldPosition and other.Position == (position or UDim2.fromScale(0.5, 0.45))) then
				used[other.SpreadSlot or 0] = true
				if not recent or other.Started >= recent.Started then recent = other end
			end
		end
	end
	local ring = 0
	local free = {}
	repeat
		for column = 0, 2 do
			local candidate = ring * 3 + column
			if not used[candidate] then table.insert(free, candidate) end
		end
		if #free == 0 then ring = ring + 1 end
	until #free > 0
	local slot = free[math.random(1, #free)]
	local column = slot % 3
	local lane = column == 0 and 0 or math.ceil(column / 2) * (column % 2 == 1 and -1 or 1)
	local spacing = math.max(24, tonumber(opts.Spacing) or 42)
	local heightSign = recent and (recent.OffsetY or -24) < -24 and 1 or -1
	if not recent then heightSign = math.random(0, 1) == 0 and -1 or 1 end
	local entry = { Frame = label, Drawing = drawing, DrawingCanRotate = canRotate, Color = color, Started = now, Duration = FeedbackDuration(opts.Duration, 0.95),
		Position = position or UDim2.fromScale(0.5, 0.45), WorldPosition = worldPosition,
		Size = size, Rise = tonumber(opts.Rise) or 36,
		Drift = tonumber(opts.Drift) or math.random(-4, 4),
		FallDrift = math.random(-18, 18),
		SpreadSlot = slot, OffsetX = lane * spacing + math.random(-4, 4),
		OffsetY = -24 + heightSign * math.random(10, 18),
		Tilt = math.random(-10, 10) }
	self:_PrepareDamageNumberFlight(entry, opts)
	function entry:Destroy()
		if self.Dead then return end
		self.Dead = true
		Library:_DestroyDamageNumberVisual(self)
	end
	entry.Dismiss = entry.Destroy
	table.insert(self.DamageNumbers, entry)
	return entry
end

function Library:Notify(opts, text, duration)
	if self.NotificationsEnabled == false then
		return
	end
	if type(opts) == "string" then
		opts = { Title = opts, Text = text, Duration = duration }
	end
	opts = opts or {}
	opts.Text = opts.Text or opts.Content or opts.Description

	local accent = opts.Color or StyleColor(opts.Style, Theme.Accent)
	local iconName = opts.Icon
	if iconName == nil and type(opts.Style) == "string" then
		local key = string.lower(opts.Style)
		if key == "warning" or key == "warn" or key == "yellow" then
			iconName = "alert-triangle"
		elseif key == "danger" or key == "error" or key == "red" then
			iconName = "x-circle"
		elseif key == "success" or key == "green" then
			iconName = "check-circle"
		end
	end

	local width = opts.Width or 304
	if not self.NotifyGui then
		local gui = New("ScreenGui", {
			Name = RandomName(),
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			AutoLocalize = false,
			DisplayOrder = MAX_DISPLAY_ORDER,
		})
		ParentGui(gui)

		local holder = New("Frame", {
			Size = UDim2.new(0, width, 1, -32),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -16),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			Parent = gui,
		})
		local notifyScale = New("UIScale", { Scale = 1, Parent = holder })
		self:RegisterStandaloneScale(notifyScale)
		self.NotifyScale = notifyScale
		self.NotifyGui = gui
		self.NotifyHolder = holder
	end

	self.ActiveNotifications = self.ActiveNotifications or {}

	local function stackGap()
		return 10
	end

	local function reflow(time)
		local offset = 0
		local gap = stackGap()
		for i = #self.ActiveNotifications, 1, -1 do
			local notification = self.ActiveNotifications[i]
			local slot = notification and notification.Slot
			if slot and slot.Parent then
				local target = UDim2.new(0, 0, 1, -offset)
				if notification.StackTween then
					notification.StackTween:Cancel()
					notification.StackTween = nil
				end
				if time and time > 0 then
					notification.StackTween = Tween(
						slot,
						{ Position = target },
						TweenInfo.new(time, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
					)
				else
					slot.Position = target
				end
				offset = offset + (notification.Height or slot.Size.Y.Offset) + gap
			end
		end
	end

	local estimatedHeight = opts.Text and 70 or 54
	local slot = New("Frame", {
		Name = "NotificationSlot",
		Size = UDim2.new(1, 0, 0, estimatedHeight),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Parent = self.NotifyHolder,
	})

	local cardWidth = width
	local offscreenX = cardWidth + 40
	local card = New("Frame", {
		Visible = false,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(offscreenX, 0),
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = 0.015,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = slot,
		ThemeTag = { BackgroundColor3 = "Window" },
	})
	Corner(card, 11)
	SetGroupTransparency(card, 1)
	Stroke(card, Theme.WindowBorder, 1, 0.08)
	local cardScale = New("UIScale", { Scale = 1, Parent = card })

	local inner = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	})
	Pad(inner, 13, 15, 27, 15)
	List(inner, 5)

	local headRow = New("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Parent = inner,
	})
	local icon = AttachIcon(headRow, iconName, accent, 15)
	if icon then
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 0, 0.5, 0)
	end
	local inset = icon and 23 or 0
	local head = Label(headRow, opts.Title or "notice", Theme.TextBright, Theme.TextSize, Theme.FontMedium)
	head.Position = UDim2.fromOffset(inset, 0)
	head.Size = UDim2.new(1, -inset, 1, 0)

	if opts.Text then
		local body = Label(inner, opts.Text, Theme.Text, math.max(Theme.TextSize - 1, 12))
		body.Size = UDim2.new(1, 0, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.LayoutOrder = 2
	end

	local timerTrack = New("Frame", {
		Size = UDim2.new(1, -30, 0, 2),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 15, 1, -15),
		BackgroundColor3 = Theme.Track,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = card,
		ThemeTag = { BackgroundColor3 = "Track" },
	})
	Corner(timerTrack, 2)
	local timerFill = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Parent = timerTrack,
	})
	Corner(timerFill, 2)

	local lifetime = math.max(tonumber(opts.Duration) or 3.5, 0.1)
	local closed = false
	local started = false
	local timerTween, slideTween, opacityTween, scaleTween
	local api = {
		Instance = slot,
		Slot = slot,
		Motion = slot,
		Card = card,
		Height = estimatedHeight,
		StackTween = nil,
	}

	local function forget()
		for i = #self.ActiveNotifications, 1, -1 do
			if self.ActiveNotifications[i] == api then
				table.remove(self.ActiveNotifications, i)
				break
			end
		end
	end

	local function removeNow()
		if started then
			forget()
		end
		if slot.Parent then
			slot:Destroy()
		end
		if started then
			reflow(0.20)
		end
	end

	function api:_Dismiss(immediate)
		if closed then
			return self
		end
		closed = true
		if timerTween then
			timerTween:Cancel()
			timerTween = nil
		end
		if slideTween then
			slideTween:Cancel()
			slideTween = nil
		end
		if opacityTween then
			opacityTween:Cancel()
			opacityTween = nil
		end
		if scaleTween then
			scaleTween:Cancel()
			scaleTween = nil
		end
		if self.StackTween then
			self.StackTween:Cancel()
			self.StackTween = nil
		end

		if immediate or not started then
			removeNow()
			return self
		end

		local compressionScale = 0.965
		local compressionTime = 0.17
		local holdTime = 0.11
		local dragTime = 0.80

		local visualHeight = math.max(api.Height or card.AbsoluteSize.Y, 1)
		local centerOffsetX = (cardWidth * (1 - compressionScale) * 0.5) / compressionScale
		local centerOffsetY = (visualHeight * (1 - compressionScale) * 0.5) / compressionScale
		local compressedPosition = UDim2.fromOffset(centerOffsetX, centerOffsetY)

		local settleInfo = TweenInfo.new(compressionTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		scaleTween = TweenService:Create(cardScale, settleInfo, { Scale = compressionScale })
		opacityTween = TweenGroupTransparency(card, 0.35, settleInfo)
		slideTween = Tween(card, { Position = compressedPosition }, settleInfo)
		scaleTween:Play()

		task.delay(compressionTime + holdTime, function()
			if closed and slot.Parent then
				local targetX = offscreenX / compressionScale

				local dragOutInfo = TweenInfo.new(dragTime, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)
				slideTween = Tween(card, { Position = UDim2.fromOffset(targetX, centerOffsetY) }, dragOutInfo)
				task.delay(dragTime, function()
					if slot.Parent then
						removeNow()
					end
				end)
			end
		end)
		return self
	end

	function api:Close(immediate)
		return self:_Dismiss(immediate == true)
	end

	task.defer(function()
		RunService.Heartbeat:Wait()
		if closed or not slot.Parent then
			return
		end
		local notifyScaleValue = self.NotifyScale and math.max(self.NotifyScale.Scale, 0.05) or 1
		local measured = math.max(math.ceil(card.AbsoluteSize.Y / notifyScaleValue), 1)
		api.Height = measured
		slot.Size = UDim2.new(1, 0, 0, measured)
		started = true
		table.insert(self.ActiveNotifications, api)
		reflow(0.24)

		card.Visible = true
		cardScale.Scale = 1
		local slideIn = TweenInfo.new(0.28, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
		local opacityIn = TweenInfo.new(0.16, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
		slideTween = Tween(card, { Position = UDim2.fromOffset(0, 0) }, slideIn)
		opacityTween = TweenGroupTransparency(card, 0, opacityIn)

		timerTween = TweenService:Create(
			timerFill,
			TweenInfo.new(lifetime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, 0, 1, 0) }
		)
		timerTween:Play()

		task.delay(lifetime, function()
			if not closed and slot.Parent then
				api:_Dismiss(false)
			end
		end)
	end)

	return api
end

local MOUSE_KEYS = {
	MB1 = Enum.UserInputType.MouseButton1,
	MB2 = Enum.UserInputType.MouseButton2,
	MB3 = Enum.UserInputType.MouseButton3,
}

local INPUT_MOUSE_KEYS = {}
for name, input in MOUSE_KEYS do
	INPUT_MOUSE_KEYS[input] = name
end

function Library:SetToggleKey(key)
	self.ToggleKey = nil
	self.ToggleInput = nil
	if typeof(key) == "EnumItem" then
		if key.EnumType == Enum.UserInputType then
			self.ToggleInput = key
		else
			self.ToggleKey = key
		end
	elseif type(key) == "string" then
		if MOUSE_KEYS[key] then
			self.ToggleInput = MOUSE_KEYS[key]
		else
			local ok, code = pcall(function()
				return Enum.KeyCode[key]
			end)
			self.ToggleKey = ok and code or nil
		end
	end

	local value = self:GetToggleKeyValue()
	for callback in self.ToggleKeyListeners do
		local ok = pcall(callback, value)
		if not ok then
			self.ToggleKeyListeners[callback] = nil
		end
	end
	return self.ToggleKey or self.ToggleInput
end

function Library:OnToggleKeyChanged(callback)
	if type(callback) ~= "function" then
		return function() end
	end
	self.ToggleKeyListeners[callback] = true
	return function()
		self.ToggleKeyListeners[callback] = nil
	end
end

function Library:GetToggleKeyValue()
	if self.ToggleInput then
		return INPUT_MOUSE_KEYS[self.ToggleInput] or self.ToggleInput.Name
	end
	if self.ToggleKey then
		return self.ToggleKey.Name
	end
	return nil
end

local function ThemeColorError(a, b)
	if typeof(a) ~= "Color3" or typeof(b) ~= "Color3" then
		return math.huge
	end
	return math.max(math.abs(a.R - b.R), math.abs(a.G - b.G), math.abs(a.B - b.B))
end

function Library:DetectThemePresetName()
	local manager = self.ThemeManager
	if type(manager) ~= "table" or type(manager.Presets) ~= "table" then
		return nil
	end

	local bestName, bestScore
	for name, preset in manager.Presets do
		if type(preset) == "table" then
			local bg = preset.Bg or preset.Background or preset.Window
			local accent = preset.Accent
			if typeof(bg) == "Color3" and typeof(accent) == "Color3" then
				local bgError = ThemeColorError(Theme.Window, bg)
				local accentError = ThemeColorError(Theme.Accent, accent)
				local score = bgError + accentError * 1.5
				if not bestScore or score < bestScore then
					bestName = name
					bestScore = score
				end
			end
		end
	end

	if bestName and bestScore and bestScore <= 0.02 then
		return bestName
	end
	return nil
end

function Library:SyncThemePresetControl(name)
	if type(name) ~= "string" or name == "" then
		return false
	end

	local manager = self.ThemeManager
	if type(manager) == "table" then
		manager.Current = name
	end
	self.CurrentThemeName = name

	local loweredName = string.lower(name)
	for flag, entry in self.Registry do
		if type(entry) == "table" and entry.Type == "Dropdown" and entry.Api then
			local flagText = string.lower(tostring(flag))
			local likelyThemeControl = string.find(flagText, "theme", 1, true) ~= nil
				or string.find(flagText, "preset", 1, true) ~= nil

			if not likelyThemeControl and type(entry.Api.Options) == "table" and type(manager) == "table" then
				local presetMatches = 0
				for _, option in entry.Api.Options do
					if type(option) == "string" and manager.Presets and manager.Presets[option] then
						presetMatches = presetMatches + 1
					end
				end
				likelyThemeControl = presetMatches >= 2
			end

			if likelyThemeControl then
				for _, option in entry.Api.Options or {} do
					if type(option) == "string" and string.lower(option) == loweredName then
						entry.Api:Set(option, true)
						return true
					end
				end
			end
		end
	end
	return false
end

function Library:GetCurrentThemeName()
	local detected = self:DetectThemePresetName()
	if detected then
		self:SyncThemePresetControl(detected)
		return detected
	end

	local manager = self.ThemeManager
	if type(manager) ~= "table" then
		return self.CurrentThemeName
	end
	if type(manager.GetCurrentTheme) == "function" then
		local ok, value = pcall(manager.GetCurrentTheme, manager)
		if ok and type(value) == "string" and value ~= "" then
			self.CurrentThemeName = value
			return value
		end
	end
	for _, key in { "Current", "CurrentTheme", "ActiveTheme", "SelectedTheme", "Theme", "ThemeName" } do
		local value = manager[key]
		if type(value) == "string" and value ~= "" then
			self.CurrentThemeName = value
			return value
		end
	end
	return self.CurrentThemeName
end

function Library:ApplyThemeByName(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	local manager = self.ThemeManager
	if type(manager) ~= "table" then
		return false
	end
	name = manager.Aliases and manager.Aliases[name] or name
	for _, methodName in { "Apply", "ApplyTheme", "SetTheme", "LoadTheme" } do
		local method = manager[methodName]
		if type(method) == "function" then
			local ok, result = pcall(method, manager, name)
			if ok and result ~= false then
				self.CurrentThemeName = name
				if type(manager) == "table" then
					manager.Current = name
				end
				self:SyncThemePresetControl(name)
				return true
			end
		end
	end
	return false
end

function Library:GetThemeConfigValue()
	local colors = {}
	for _, key in THEME_ORDER do
		local color = Theme[key]
		if typeof(color) == "Color3" then
			colors[key] = ToHex(color, ThemeAlpha[key] or 1)
		end
	end
	return {
		Name = self:GetCurrentThemeName(),
		Colors = colors,
	}
end

function Library:ApplyThemeConfigValue(value)
	if type(value) == "string" then
		return self:ApplyThemeByName(value)
	end
	if type(value) ~= "table" then
		return false
	end

	if type(value.Name) == "string" and value.Name ~= "" then
		self:ApplyThemeByName(value.Name)
	end

	local colors = value.Colors
	if type(colors) == "table" then
		for key, encoded in colors do
			if Theme[key] ~= nil then
				local color, alpha = FromHex(encoded)
				if color then
					Theme[key] = color
					if alpha ~= nil then
						ThemeAlpha[key] = alpha
					end
				end
			end
		end
		self:Repaint()
	end

	local detectedName = self:DetectThemePresetName()
	if detectedName then
		self:SyncThemePresetControl(detectedName)
	elseif type(value.Name) == "string" and value.Name ~= "" then
		self.CurrentThemeName = value.Name
	end

	local manager = self.ThemeManager
	if type(manager) == "table" then
		if detectedName then
			manager.Current = detectedName
		elseif type(value.Name) == "string" and value.Name ~= "" then
			manager.Current = value.Name
		end
		if type(manager.Pickers) == "table" then
			for key, picker in manager.Pickers do
				if picker and type(picker.Set) == "function" and typeof(Theme[key]) == "Color3" then
					pcall(picker.Set, picker, Theme[key], ThemeAlpha[key] or 1, true)
				end
			end
		end
	end
	return true
end

function Library:EnsureSystemConfigEntries()
	if self.SystemConfigEntriesRegistered then
		return
	end
	self.SystemConfigEntriesRegistered = true
	self:Register("__layer_toggle_key", {
		Type = "Keybind",
		Get = function()
			return self:GetToggleKeyValue()
		end,
		Set = function(value)
			self:SetToggleKey(value)
		end,
	})
	self:Register("__layer_theme", {
		Type = "Theme",
		Get = function()
			return self:GetThemeConfigValue()
		end,
		Set = function(value)
			self:ApplyThemeConfigValue(value)
		end,
	})
end

Library.Panels = {}

function Library:Panel(opts)
	opts = opts or {}

	local gui = New("ScreenGui", {
		Name = RandomName(),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		AutoLocalize = false,
		DisplayOrder = opts.DisplayOrder or 997,
	})
	ParentGui(gui)

	gui.Name = RandomName()
	gui.DisplayOrder = MAX_DISPLAY_ORDER
	local root = New("Frame", {
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = MAX_DISPLAY_ORDER,
		Parent = gui,
	})
	local rootScale = New("UIScale", { Parent = root })
	Library:RegisterStandaloneScale(rootScale)

	local frame = New("Frame", {
		Size = opts.Height and UDim2.fromOffset(opts.Width or 180, opts.Height)
			or UDim2.new(0, opts.Width or 180, 0, 0),
		AutomaticSize = (not opts.Height) and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		Position = opts.Position or UDim2.fromOffset(18, 90),
		BackgroundColor3 = Theme.Section,
		BorderSizePixel = 0,
		Active = true,
		Parent = root,
		ThemeTag = { BackgroundColor3 = "Section" },
	})
	Corner(frame, 8)
	Stroke(frame, Theme.SectionBorder)

	local stack = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = frame,
	})
	List(stack, 0)

	local headerChevron, headerTitle, headerButton, header
	if opts.Title then
		header = New("Frame", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			Parent = stack,
		})
		Pad(header, 0, 11, 0, 11)

		local titleKey = string.lower(tostring(opts.Title or ""))
		local hidePanelIcon = titleKey == "player"
			or titleKey == "players"
			or string.find(titleKey, "player ", 1, true) == 1
		local icon = (not hidePanelIcon) and AttachIcon(header, opts.Icon, Theme.TextBright, 14) or nil
		if icon then
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 0, 0.5, 0)
		end
		local inset = icon and 20 or 0
		headerTitle = Label(header, opts.Title, Theme.TextBright, Theme.TextSize, Theme.FontMedium)
		headerTitle.Position = UDim2.fromOffset(inset, 0)
		headerTitle.Size = UDim2.new(1, -inset - 16, 1, 0)

		headerChevron = Chevron(header, Theme.TextDim)
		headerChevron.AnchorPoint = Vector2.new(1, 0.5)
		headerChevron.Position = UDim2.new(1, 0, 0.5, 0)

		headerButton = New("TextButton", {
			Size = UDim2.fromOffset(26, 26),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 6, 0.5, 0),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 2,
			Parent = header,
		})

		New("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.BorderSoft,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Parent = stack,
			ThemeTag = { BackgroundColor3 = "BorderSoft" },
		})
	end

	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 3,
		Parent = stack,
	})
	local bodyPadding = Pad(body, opts.Title and 9 or 11, 11, 11, 11)
	local bodyList = List(body, 8)

	local overlay = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 300,
		Parent = root,
	})
	local blocker = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 310,
		Parent = overlay,
	})

	local api = setmetatable({
		Gui = gui,
		Frame = frame,
		Main = root,
		Scale = rootScale,
		Overlay = overlay,
		Blocker = blocker,
		FloatStack = {},
		Modals = {},
	}, { __index = Window })

	api.Content = NewContainer(api, body)
	api.Open = true
	api.Visible = false

	local bodySizeMotion
	local bodyChevronMotion
	function api:SetOpen(state)
		state = state ~= false
		if state == self.Open then
			return self
		end
		self.Open = state
		self:CloseFloating()
		local info = AnimationInfo("Section", not state)
		local duration = info.Time
		local scale = math.max(rootScale.Scale, 0.05)
		local current = body.Visible and body.AbsoluteSize.Y / scale or 0
		local target = state
				and (bodyList.AbsoluteContentSize.Y / scale + bodyPadding.PaddingTop.Offset + bodyPadding.PaddingBottom.Offset)
			or 0
		body.Visible = true
		body.AutomaticSize = Enum.AutomaticSize.None
		body.Size = UDim2.new(1, 0, 0, current)
		if bodySizeMotion then
			bodySizeMotion:Cancel()
		end
		if bodyChevronMotion then
			bodyChevronMotion:Cancel()
		end
		bodySizeMotion = BezierTween(
			body,
			{ Size = UDim2.new(1, 0, 0, target) },
			duration,
			{ 0.16, 1, 0.3, 1 },
			function()
				if self.Open then
					body.AutomaticSize = Enum.AutomaticSize.Y
				end
			end
		)
		if headerChevron then
			bodyChevronMotion = BezierTween(
				headerChevron,
				{ Rotation = state and 0 or 180 },
				duration,
				{ 0.16, 1, 0.3, 1 }
			)
		end
		Fade(body, state, TweenInfo.new(duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out))
		return self
	end

	function api:Toggle()
		return self:SetOpen(not self.Open)
	end

	if headerButton then
		Track(headerButton.Activated:Connect(function()
			api:Toggle()
		end))
		Track(headerButton.MouseEnter:Connect(function()
			for _, bar in headerChevron:GetChildren() do
				if bar:IsA("Frame") then
					Tween(bar, { BackgroundColor3 = Theme.AccentSoft }, EASE_FAST)
				end
			end
		end))
		Track(headerButton.MouseLeave:Connect(function()
			for _, bar in headerChevron:GetChildren() do
				if bar:IsA("Frame") then
					Tween(bar, { BackgroundColor3 = Theme.TextDim }, EASE_FAST)
				end
			end
		end))
	end

	Track(blocker.Activated:Connect(function()
		api:CloseFloating()
	end))

	function api:SetVisible(state)
		state = state ~= false
		if state == self.Visible then
			return self
		end
		self.Visible = state
		if state then
			gui.Enabled = true
			RaiseLayerFrame(frame)
		else
			self:CloseFloating()
			for _, modal in self.Modals do
				modal:SetOpen(false)
			end
		end
		Fade(root, state, AnimationInfo("Window", not state), function()
			if not self.Visible then
				gui.Enabled = false
			end
		end)
		return self
	end

	function api:SetPosition(position)
		frame.Position = position
	end

	function api:Destroy()
		self:CloseFloating()
		gui:Destroy()
		for index, panel in Library.Panels do
			if panel == api then
				table.remove(Library.Panels, index)
				break
			end
		end
	end

	if opts.Draggable ~= false then
		AttachSmoothFrameDrag(frame, header or frame, function()
			api:CloseFloating()
		end)
	end

	api:SetVisible(opts.Visible ~= false)
	if opts.Collapsed then
		api:SetOpen(false)
	end

	table.insert(self.Panels, api)
	return api
end

Library.HotkeyEntries = {}
Library.HotkeysEnabled = false

function Library:RegisterHotkey(getter)
	table.insert(self.HotkeyEntries, getter)
	self:RefreshHotkeys()
	return getter
end

function Library:CreateHotkeyPanel(opts)
	if self.HotkeyGui then
		if type(opts) == "table" then
			if opts.Position then self.HotkeyPanel.Position = opts.Position end
			if opts.AnchorPoint then self.HotkeyPanel.AnchorPoint = opts.AnchorPoint end
		end
		return self.HotkeyPanel
	end
	opts = opts or {}

	local gui = New("ScreenGui", {
		Name = RandomName(),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		AutoLocalize = false,
		DisplayOrder = MAX_DISPLAY_ORDER,
		Enabled = false,
	})
	ParentGui(gui)

	local panelWidth = opts.Width or 172
	local panel = New("CanvasGroup", {
		Visible = false,
		Size = UDim2.fromOffset(panelWidth, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = opts.AnchorPoint or Vector2.new(0, 0),
		Position = opts.Position or UDim2.fromOffset(18, 90),
		BackgroundColor3 = Theme.Window,
		GroupTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		Parent = gui,
		ThemeTag = { BackgroundColor3 = "Window" },
	})
	Corner(panel, 8)
	SetGroupTransparency(panel, 1)
	local panelStroke = Stroke(panel, Theme.WindowBorder)
	panelStroke.Transparency = 1
	local panelScale = New("UIScale", { Scale = 1, Parent = panel })
	Library:RegisterStandaloneScale(panelScale)
	local inner = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = panel,
	})
	List(inner, 0)

	local header = New("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.TopBar,
		BorderSizePixel = 0,
		Parent = inner,
		ThemeTag = { BackgroundColor3 = "TopBar" },
	})
	Corner(header, 8)

	New("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.new(0, 0, 1, -8),
		BackgroundColor3 = Theme.TopBar,
		BorderSizePixel = 0,
		Parent = header,
		ThemeTag = { BackgroundColor3 = "TopBar" },
	})

	Pad(header, 0, 12, 0, 12)
	local title = Label(header, opts.Title or "keybinds", Theme.Accent, Theme.TextSize + 1, Theme.FontMedium)
	Library:Tag(title, { TextColor3 = "Accent" })
	title.Position = UDim2.fromOffset(0, 0)
	title.Size = UDim2.new(1, 0, 1, 0)

	New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.BorderSoft,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		Parent = inner,
		ThemeTag = { BackgroundColor3 = "BorderSoft" },
	})

	local body = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = inner,
	})
	Pad(body, 8, 12, 4, 12)

	local rows = New("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		GroupTransparency = 0,
		Position = UDim2.fromOffset(0, 0),
		Parent = body,
	})
	List(rows, 0)
	SetGroupTransparency(rows, 0)

	AttachSmoothFrameDrag(panel, header)

	self.HotkeyGui = gui
	self.HotkeyPanel = panel
	self.HotkeyStroke = panelStroke
	self.HotkeyRows = rows
	self.HotkeyScale = panelScale
	self.HotkeyPanelWidth = panelWidth
	self.HotkeyPanelMinWidth = opts.Width or 0
	self.HotkeyShown = false
	self.HotkeyCount = 0
	self.HotkeyRowRecords = {}
	return panel
end

function Library:_ScheduleHotkeyLayout()
	if self.HotkeyLayoutPending or self.Destroyed then return end
	self.HotkeyLayoutPending = true
	task.defer(function()
		RunService.RenderStepped:Wait()
		self.HotkeyLayoutPending = false
		if self.Destroyed or not self.HotkeysEnabled or not self.HotkeyShown then return end
		local panel = self.HotkeyPanel
		if not panel or not panel.Parent then return end
		local required = self.HotkeyPanelMinWidth or 0
		for _, record in self.HotkeyRowRecords or {} do
			if not record.Exiting and record.Row.Parent and record.Label then
				local scale = GetFrameRenderScale(record.Row)
				local labelWidth = record.Label.AbsoluteSize.X / scale
				local modeWidth = record.Mode.AbsoluteSize.X / scale
				local capWidth = record.KeyCap.AbsoluteSize.X / scale
				local statusWidth = capWidth + 8 + modeWidth
				record.Status.Size = UDim2.fromOffset(statusWidth, 22)
				record.KeyCap.Position = UDim2.new(1, -(modeWidth + 8), 0, 1)
				required = math.max(required, 24 + labelWidth + 12 + statusWidth)
			end
		end
		local scale = math.max(self:GetInterfaceScale(), 0.05)
		local available = math.max(1, GetDragViewportSize().X / scale - 36)
		local width = math.min(math.ceil(required), available)
		if math.abs(width - (self.HotkeyTargetWidth or 0)) < 0.5 then return end
		if self.HotkeySizeTween then self.HotkeySizeTween:Cancel() end
		self.HotkeyTargetWidth = width
		self.HotkeyCurrentWidth = width
		self.HotkeySizeTween = TweenService:Create(panel,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(width, self.HotkeyTargetHeight or panel.Size.Y.Offset) })
		self.HotkeySizeTween:Play()
	end)
end

function Library:RefreshHotkeys()
	if self.LoadingConfig then
		return
	end
	if not self.HotkeysEnabled then
		self.HotkeyVisibilityTicket = (self.HotkeyVisibilityTicket or 0) + 1

		if self.HotkeyFadeTween then
			self.HotkeyFadeTween:Cancel()
			self.HotkeyFadeTween = nil
		end
		if self.HotkeyStrokeTween then
			self.HotkeyStrokeTween:Cancel()
			self.HotkeyStrokeTween = nil
		end

		if self.HotkeyGui then
			self.HotkeyGui.Enabled = false
		end
		if self.HotkeyPanel then
			self.HotkeyPanel.Visible = false
			SetGroupTransparency(self.HotkeyPanel, 1)
			if self.HotkeyStroke then
				self.HotkeyStroke.Transparency = 1
			end
			self.HotkeyShown = false
		end
		self.HotkeyRefreshSignature = nil
		return
	end
	if not self.HotkeyGui then
		return
	end

	self.HotkeyGui.Enabled = true

	local entries = {}
	local shown = 0
	local signatureParts = {}

	for index = #self.HotkeyEntries, 1, -1 do
		local ok, data = pcall(self.HotkeyEntries[index])
		if not ok then
			table.remove(self.HotkeyEntries, index)
		elseif type(data) == "table" and data.Visible and data.Active == true and data.Key and data.Key ~= "" then
			shown = shown + 1

			local mode = string.lower(tostring(data.Mode or "toggle"))
			if mode == "press" then
				mode = "toggle"
			end

			local modeText = mode == "always" and "always" or (mode == "hold" and "hold" or "toggle")
			local labelText = tostring(data.Label or "action")
			if string.lower(labelText) == "menu key" then
				labelText = "Menu Key"
			end
			local keyText = tostring(data.Key)

			entries[#entries + 1] = {
				Label = labelText,
				Key = keyText,
				Mode = modeText,
				StatusPlain = string.format("%s  ·  %s", keyText, modeText),
			}

			signatureParts[#signatureParts + 1] = labelText .. "\0" .. keyText .. "\0" .. modeText
		end
	end

	local panel = self.HotkeyPanel
	local rows = self.HotkeyRows
	local baseWidth = self.HotkeyPanelMinWidth or 0
	local viewportWidth = GetDragViewportSize().X
	local shouldShow = shown > 0
	local targetHeight = shouldShow and (47 + shown * 27) or 0
	local baseScale = self:GetInterfaceScale()
	local contentSignature = table.concat(signatureParts, "\1")
	local refreshSignature = table.concat({
		contentSignature,
		AccentHex(),
		tostring(Theme.TextSize),
		tostring(Theme.Font),
		tostring(Theme.FontMedium),
		tostring(math.floor(viewportWidth + 0.5)),
		string.format("%.4f", baseScale),
	}, "\2")

	if
		refreshSignature == self.HotkeyRefreshSignature
		and shouldShow == self.HotkeyShown
		and self.HotkeyTargetHeight == targetHeight
	then
		return
	end

	local measureLabel = Label(panel, "", Theme.Text, Theme.TextSize - 1, Theme.FontMedium)
	measureLabel.Visible = false
	local requiredWidth = baseWidth
	for _, entry in entries do
		local labelWidth = math.ceil(MeasureRenderedTextWidth(measureLabel, entry.Label))
		entry.KeyWidth = math.ceil(MeasureRenderedTextWidth(measureLabel, entry.Key))
		entry.ModeWidth = math.ceil(MeasureRenderedTextWidth(measureLabel, entry.Mode))
		entry.KeyChipWidth = entry.KeyWidth + 12
		entry.StatusWidth = entry.KeyChipWidth + 8 + entry.ModeWidth
		requiredWidth = math.max(requiredWidth, 24 + labelWidth + 12 + entry.StatusWidth)
	end
	measureLabel:Destroy()

	local maxWidth = math.max(baseWidth, viewportWidth / math.max(baseScale, 0.05) - 36)
	local width = math.clamp(math.ceil(requiredWidth), baseWidth, maxWidth)
	local styleSignature = table.concat({
		tostring(Theme.TextSize),
		tostring(Theme.Font),
		tostring(Theme.FontMedium),
	}, "\2")
	local styleChanged = styleSignature ~= self.HotkeyRenderStyleSignature
	local contentChanged = refreshSignature ~= self.HotkeyRenderSignature
	local oldRecords = self.HotkeyRowRecords or {}
	local available = {}
	if not styleChanged then
		for _, record in oldRecords do
			if record.Row and record.Row.Parent then
				local bucket = available[record.Signature]
				if not bucket then
					bucket = {}
					available[record.Signature] = bucket
				end
				table.insert(bucket, record)
			end
		end
	end

	local nextRecords = {}
	local used = {}
	local rowTweenInfo = TweenInfo.new(0.20, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	local exitTweenInfo = TweenInfo.new(0.28, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	local hasExitingRows = false
	local function cancelRowTween(record)
		local tween = record.Tween
		if tween then
			tween:Cancel()
			record.Tween = nil
		end
	end

	for index, entry in entries do
		local signature = entry.Label .. "\0" .. entry.Key .. "\0" .. entry.Mode
		local layoutSignature = table.concat({
			tostring(entry.StatusWidth),
			tostring(entry.ModeWidth),
			tostring(entry.KeyChipWidth),
			tostring(Theme.TextSize),
			tostring(Theme.Font),
			tostring(Theme.FontMedium),
		}, "\2")
		local bucket = available[signature]
		local record
		local shouldExpand = false
		while bucket and #bucket > 0 do
			local candidate = table.remove(bucket, 1)
			if not used[candidate] and candidate.LayoutSignature == layoutSignature then
				record = candidate
				break
			end
		end

		if not record then
			local rowHeight = 22
			local rowSlotHeight = 27
			local initialHeight = self.HotkeyShown and 0 or rowSlotHeight
			shouldExpand = initialHeight < rowSlotHeight
			local row = New("Frame", {
				Size = UDim2.new(1, 0, 0, initialHeight),
				BackgroundTransparency = 1,
				LayoutOrder = index * 100,
				ClipsDescendants = true,
				Parent = rows,
			})

			local textY = 0
			local keyCapY = 1
			local label = Label(row, entry.Label, Theme.Text, Theme.TextSize - 1, Theme.FontMedium)
			label.Position = UDim2.fromOffset(0, textY)
			label.Size = UDim2.fromOffset(0, rowHeight)
			label.AutomaticSize = Enum.AutomaticSize.X
			label.TextWrapped = false
			label.TextTruncate = Enum.TextTruncate.None
			label.TextYAlignment = Enum.TextYAlignment.Center

			local status = New("Frame", {
				Size = UDim2.fromOffset(entry.StatusWidth, rowHeight),
				Position = UDim2.new(1, -entry.StatusWidth, 0, 0),
				BackgroundTransparency = 1,
				Parent = row,
			})
			local mode = Label(status, entry.Mode, Theme.TextDim, Theme.TextSize - 1, Theme.Font)
			mode.AnchorPoint = Vector2.new(1, 0)
			mode.Position = UDim2.new(1, 0, 0, textY)
			mode.Size = UDim2.fromOffset(0, rowHeight)
			mode.AutomaticSize = Enum.AutomaticSize.X
			mode.TextXAlignment = Enum.TextXAlignment.Right
			mode.TextYAlignment = Enum.TextYAlignment.Center
			mode.TextWrapped = false

			local keyCap = New("Frame", {
				Size = UDim2.fromOffset(0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -(entry.ModeWidth + 8), 0, keyCapY),
				BackgroundColor3 = Theme.FieldHover,
				BorderSizePixel = 0,
				Parent = status,
				ThemeTag = { BackgroundColor3 = "FieldHover" },
			})
			Corner(keyCap, 5)
			Stroke(keyCap, Theme.Border, 1)
			Pad(keyCap, 0, 6, 0, 6)

			local keyLabel = Label(keyCap, entry.Key, Theme.Highlight, Theme.TextSize - 1, Theme.FontMedium)
			Library:Tag(keyLabel, { TextColor3 = "Highlight" })
			keyLabel.Position = UDim2.fromOffset(0, 0)
			keyLabel.Size = UDim2.new(0, 0, 1, 0)
			keyLabel.AutomaticSize = Enum.AutomaticSize.X
			keyLabel.TextXAlignment = Enum.TextXAlignment.Left
			keyLabel.TextYAlignment = Enum.TextYAlignment.Center
			keyLabel.TextWrapped = false
			keyLabel.TextTruncate = Enum.TextTruncate.None

			record = {
				Row = row,
				Label = label, Mode = mode, KeyCap = keyCap, Status = status,
				Signature = signature,
				LayoutSignature = layoutSignature,
				Order = index,
			}
			local function reconcileRow() Library:_ScheduleHotkeyLayout() end
			Track(label:GetPropertyChangedSignal("AbsoluteSize"):Connect(reconcileRow))
			Track(mode:GetPropertyChangedSignal("AbsoluteSize"):Connect(reconcileRow))
			Track(keyCap:GetPropertyChangedSignal("AbsoluteSize"):Connect(reconcileRow))
		end

		cancelRowTween(record)
		shouldExpand = shouldExpand or record.Row.Size.Y.Offset < 27
		record.Exiting = false
		record.Order = index
		record.Row.LayoutOrder = index * 100
		if shouldExpand then
			record.Row.Size = UDim2.new(1, 0, 0, 0)
			record.Tween = TweenService:Create(record.Row, rowTweenInfo, {
				Size = UDim2.new(1, 0, 0, 27),
			})
			record.Tween:Play()
		else
			record.Row.Size = UDim2.new(1, 0, 0, 27)
		end
		used[record] = true
		table.insert(nextRecords, record)
	end

	for _, record in oldRecords do
		if not used[record] and record.Row.Parent then
			hasExitingRows = true
			cancelRowTween(record)
			record.Exiting = true
			local anchor = math.clamp(record.Order or 1, 1, #entries + 1)
			record.Row.LayoutOrder = (anchor - 1) * 100 + 50
			record.Tween = TweenService:Create(record.Row, exitTweenInfo, {
				Size = UDim2.new(1, 0, 0, 0),
			})
			local exitingRecord = record
			record.Tween.Completed:Connect(function(playbackState)
				if
					playbackState == Enum.PlaybackState.Completed
					and exitingRecord.Exiting
					and exitingRecord.Row.Parent
				then
					exitingRecord.Row:Destroy()
				end
			end)
			record.Tween:Play()
			table.insert(nextRecords, record)
		end
	end

	self.HotkeyRowRecords = nextRecords
	self.HotkeyRenderSignature = refreshSignature
	self.HotkeyRenderStyleSignature = styleSignature

	self.HotkeyVisibilityTicket = (self.HotkeyVisibilityTicket or 0) + 1
	local visibilityTicket = self.HotkeyVisibilityTicket

	if self.HotkeyFadeTween then
		self.HotkeyFadeTween:Cancel()
		self.HotkeyFadeTween = nil
	end
	if self.HotkeyRowsTween then
		self.HotkeyRowsTween:Cancel()
		self.HotkeyRowsTween = nil
	end
	if self.HotkeyStrokeTween then
		self.HotkeyStrokeTween:Cancel()
		self.HotkeyStrokeTween = nil
	end

	local panelStroke = self.HotkeyStroke
	local panelScale = self.HotkeyScale
	local firstShow = shouldShow and not self.HotkeyShown
	local sizeChanged = self.HotkeyTargetWidth ~= width or self.HotkeyTargetHeight ~= targetHeight

	if shouldShow then
		panel.Visible = true

		if firstShow then
			SetGroupTransparency(panel, 1)
			panel.Size = UDim2.fromOffset(width, targetHeight)
			if panelStroke then
				panelStroke.Transparency = 1
			end
			if panelScale then
				panelScale.Scale = baseScale * 0.965
			end
		elseif sizeChanged then
			if self.HotkeySizeTween then
				self.HotkeySizeTween:Cancel()
			end
			self.HotkeySizeTween = TweenService:Create(
				panel,
				TweenInfo.new(hasExitingRows and 0.28 or 0.24, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(width, targetHeight) }
			)
			self.HotkeySizeTween:Play()
		end

		local revealInfo = AnimationInfo("Modal", false)
		local motionInfo = TweenInfo.new(revealInfo.Time, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

		self.HotkeyFadeTween = TweenGroupTransparency(panel, 0, revealInfo)

		if panelStroke then
			self.HotkeyStrokeTween = TweenService:Create(panelStroke, revealInfo, {
				Transparency = 0,
			})
			self.HotkeyStrokeTween:Play()
		end

		if firstShow and panelScale then
			Tween(panelScale, { Scale = baseScale }, motionInfo)
		end

		if contentChanged and not firstShow then
			SetGroupTransparency(rows, 0.22)
			self.HotkeyRowsTween = TweenGroupTransparency(
				rows,
				0,
				TweenInfo.new(0.16, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
			)
		else
			SetGroupTransparency(rows, 0)
		end
	else
		if self.HotkeySizeTween then
			self.HotkeySizeTween:Cancel()
			self.HotkeySizeTween = nil
		end

		if panel.Visible then
			local fadeInfo = AnimationInfo("Modal", true)

			self.HotkeyFadeTween = TweenGroupTransparency(panel, 1, fadeInfo)

			if panelStroke then
				self.HotkeyStrokeTween = TweenService:Create(panelStroke, fadeInfo, {
					Transparency = 1,
				})
				self.HotkeyStrokeTween:Play()
			end

			if panelScale then
				Tween(panelScale, { Scale = baseScale * 0.965 }, fadeInfo)
			end

			task.delay(fadeInfo.Time, function()
				if self.HotkeyVisibilityTicket ~= visibilityTicket or self.HotkeyShown or not panel.Parent then
					return
				end

				panel.Visible = false
				SetGroupTransparency(panel, 1)
				panel.Size = UDim2.fromOffset(baseWidth, 0)
				SetGroupTransparency(rows, 0)

				if panelScale then
					panelScale.Scale = baseScale
				end
				if panelStroke then
					panelStroke.Transparency = 1
				end
			end)
		else
			panel.Visible = false
			SetGroupTransparency(panel, 1)
			panel.Size = UDim2.fromOffset(baseWidth, 0)
			SetGroupTransparency(rows, 0)

			if panelScale then
				panelScale.Scale = baseScale
			end
			if panelStroke then
				panelStroke.Transparency = 1
			end
		end
	end

	self.HotkeyShown = shouldShow
	self.HotkeyCount = shown
	self.HotkeyCurrentWidth = width
	self.HotkeyTargetWidth = width
	self.HotkeyTargetHeight = targetHeight
	self.HotkeyRefreshSignature = refreshSignature
	self:_ScheduleHotkeyLayout()
end

function Library:SetHotkeysVisible(state)
	self.HotkeysEnabled = state and true or false
	if self.HotkeysEnabled then
		self:CreateHotkeyPanel()
	end
	if self.HotkeyGui then
		self.HotkeyGui.Enabled = self.HotkeysEnabled
	end
	self:RefreshHotkeys()
	return self.HotkeysEnabled
end

function Library:Hotkeys(opts)
	if type(opts) == "boolean" then
		self:SetHotkeysVisible(opts)
		return self.HotkeyPanel
	end

	opts = opts or {}
	local panel = self:CreateHotkeyPanel(opts)
	self:SetHotkeysVisible(opts.Visible ~= false)
	return panel
end

Library.WatermarkEnabled = false
Library.WatermarkOptions = Library.WatermarkOptions or { "Game", "Status", "Fps", "Ping" }
Library.WatermarkRefreshRate = Library.WatermarkRefreshRate or 0.1
Library.GameName = Library.GameName or nil

function Library:HasWatermarkOption(name, options)
	local wanted = string.lower(tostring(name or ""))
	options = options or self.WatermarkOptions
	if type(options) == "table" then
		for _, option in options do
			if string.lower(tostring(option)) == wanted then
				return true
			end
		end
		return false
	end
	return string.lower(tostring(options or "")) == wanted
end

function Library:GetGameName()
	if self.GameName and tostring(self.GameName) ~= "" then
		return tostring(self.GameName)
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	local name
	if ok and type(info) == "table" and info.Name then
		name = tostring(info.Name)
	else
		name = "place " .. tostring(game.PlaceId)
	end
	name = name:gsub("[\128-\255]", "")
	name = name:gsub("%s+", " ")
	name = name:gsub("^%s*(.-)%s*$", "%1")
	if name == "" then
		name = "place " .. tostring(game.PlaceId)
	end
	self.GameName = name
	return name
end

function Library:CreateWatermark(opts)
	if self.WatermarkGui then
		return self.WatermarkPanel
	end

	opts = opts or {}

	local gui = New("ScreenGui", {
		Name = RandomName(),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		AutoLocalize = false,
		DisplayOrder = MAX_DISPLAY_ORDER,
		Enabled = false,
	})
	ParentGui(gui)

	local panel = New("CanvasGroup", {
		Visible = false,
		Size = UDim2.fromOffset(opts.Width or 220, 30),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = opts.Position or UDim2.new(0.5, 0, 0, 18),
		BackgroundColor3 = Theme.Window,
		GroupTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
		ThemeTag = { BackgroundColor3 = "Window" },
	})
	Corner(panel, 7)

	local stroke = Stroke(panel, Theme.WindowBorder, 1, 0)
	Library:Tag(stroke, { Color = "WindowBorder" })

	local accent = New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = panel,
		ThemeTag = { BackgroundColor3 = false },
	})

	local lineGradient = New("UIGradient", {
		Color = ColorSequence.new(Theme.Accent, Theme.Highlight),
		Rotation = 0,
		Parent = accent,
	})
	Library:OnRepaint(function()
		lineGradient.Color = ColorSequence.new(Theme.Accent, Theme.Highlight)
	end, accent)

	local scale = New("UIScale", {
		Scale = 1,
		Parent = panel,
	})
	Library:RegisterStandaloneScale(scale)

	local textLabel = Label(panel, "", Theme.Text, Theme.TextSize - 1, Theme.FontMedium)
	textLabel.Visible = false
	textLabel.ZIndex = 10
	textLabel.Size = UDim2.fromOffset(1, 1)

	local content = New("Frame", {
		Size = UDim2.fromOffset(0, 29),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 1),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	self.WatermarkGui = gui
	self.WatermarkPanel = panel
	self.WatermarkText = textLabel
	self.WatermarkContent = content
	self.WatermarkLabels = {}
	self.WatermarkStroke = stroke
	self.WatermarkAccent = accent
	self.WatermarkFps = 0
	self.WatermarkPing = 0
	self.WatermarkFrames = 0
	self.WatermarkElapsed = 0
	self.WatermarkLastWidth = opts.Width or 220
	self.WatermarkStaticWidth = opts.Width
	self.WatermarkFpsSlotWidth = nil
	self.WatermarkPingSlotWidth = nil
	self.WatermarkDragController = AttachSmoothFrameDrag(panel, panel)

	return panel
end

function Library:BuildWatermarkParts(object)
	local options = object.Options or self.WatermarkOptions
	local parts = {}
	local ordered = type(options) == "table" and options or { options }
	local player = Players.LocalPlayer

	for _, raw in ordered do
		local option = string.lower(tostring(raw or ""))

		if option == "game" then
			parts[#parts + 1] = {
				Kind = "normal",
				Text = self:GetGameName(),
			}
		elseif option == "status" then
			local status = tostring(object.Status or "")
			if status ~= "" then
				parts[#parts + 1] = {
					Kind = "normal",
					Text = status,
				}
			end
		elseif option == "fps" then
			parts[#parts + 1] = {
				Kind = "fps",
				Text = tostring(math.max(0, math.floor((self.WatermarkFps or 0) + 0.5))) .. " fps",
			}
		elseif option == "ping" then
			parts[#parts + 1] = {
				Kind = "ping",
				Text = tostring(math.max(0, math.floor((self.WatermarkPing or 0) + 0.5))) .. " ms",
			}
		elseif option == "user" or option == "username" then
			parts[#parts + 1] = {
				Kind = "normal",
				Text = player and player.Name or "player",
			}
		elseif option == "time" then
			parts[#parts + 1] = {
				Kind = "normal",
				Text = os.date("%H:%M"),
			}
		end
	end

	return parts
end

function Library:RefreshWatermark()
	local object = self.WatermarkObject
	if
		not self.WatermarkEnabled
		or not object
		or not self.WatermarkGui
		or not self.WatermarkPanel
		or not self.WatermarkText
		or not self.WatermarkContent
	then
		return
	end

	local brand = tostring(object.Name or "layer.app")
	local parts = {}

	if object.Auto then
		parts = self:BuildWatermarkParts(object)
	else
		local subText = tostring(object.SubName or "")
		if subText ~= "" then
			parts[1] = {
				Kind = "normal",
				Text = subText,
			}
		end
	end

	local plainParts = {}
	for index, part in parts do
		plainParts[index] = tostring(part.Text or "")
	end
	object.SubName = table.concat(plainParts, " · ")

	self.WatermarkText.Text = object.SubName ~= ""
			and string.format('<font color="%s">%s</font>  ·  %s', AccentHex(), brand, object.SubName)
		or string.format('<font color="%s">%s</font>', AccentHex(), brand)
	self.WatermarkText.Visible = false

	local name, suffix = string.match(brand, "^(.-)(%.app)$")
	local entries = { { Kind = "brand", Text = name or brand } }
	if suffix then entries[#entries + 1] = { Kind = "brandSuffix", Text = suffix } end

	for _, part in parts do
		entries[#entries + 1] = {
			Kind = "separator",
			Text = " · ",
		}
		entries[#entries + 1] = part
	end

	local labels = self.WatermarkLabels
	local content = self.WatermarkContent
	if content.Visible ~= true then content.Visible = true end

	local function getLabel(index)
		local label = labels[index]
		if label and label.Parent then
			if label.Visible ~= true then label.Visible = true end
			return label
		end

		label = Label(content, "", Theme.Text, Theme.TextSize - 1, Theme.FontMedium)
		label.BackgroundTransparency = 1
		label.TextWrapped = false
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.RichText = false
		labels[index] = label
		return label
	end

	local function fixedWidthFor(kind, value, label)
		local sample = kind == "fps" and "999 fps"
			or kind == "ping" and "999 ms"
			or kind == "time" and "00:00"
			or tostring(value or "")
		return math.ceil(MeasureRenderedTextWidth(label, sample)) + (kind == "separator" and 9 or 1)
	end

	if not self.WatermarkLayoutWidths then
		self.WatermarkLayoutWidths = {}

		for index, entry in entries do
			local kind = entry.Kind
			local value = tostring(entry.Text or "")
			self.WatermarkLayoutWidths[index] = math.max(1, fixedWidthFor(kind, value, getLabel(index)))
		end

		local total = 0
		for _, width in self.WatermarkLayoutWidths do
			total += width
		end

		self.WatermarkStaticWidth = self.WatermarkStaticWidth
			or math.clamp(total + 24, 120, math.max(120, GetDragViewportSize().X - 36))

		self.WatermarkLastWidth = self.WatermarkStaticWidth
		self.WatermarkPanel.Size = UDim2.fromOffset(self.WatermarkStaticWidth, 30)
	end

	local x = 0
	for index, entry in entries do
		local label = getLabel(index)
		local kind = entry.Kind
		local value = tostring(entry.Text or "")
		local width = self.WatermarkLayoutWidths[index] or fixedWidthFor(kind, value, label)

		if label.Text ~= value then label.Text = value end
		if label.Position ~= UDim2.fromOffset(x, 0) then label.Position = UDim2.fromOffset(x, 0) end
		if label.Size ~= UDim2.fromOffset(width, 29) then label.Size = UDim2.fromOffset(width, 29) end

		if kind == "brand" or kind == "brandSuffix" then
			if label.TextXAlignment ~= Enum.TextXAlignment.Left then label.TextXAlignment = Enum.TextXAlignment.Left end
			local key = kind == "brandSuffix" and "Highlight" or "Accent"
			Library:Tag(label, { TextColor3 = key })
			if label.TextColor3 ~= Theme[key] then label.TextColor3 = Theme[key] end
		elseif kind == "fps" or kind == "ping" then
			if label.TextXAlignment ~= Enum.TextXAlignment.Right then label.TextXAlignment = Enum.TextXAlignment.Right end
			Library:Tag(label, { TextColor3 = "Text" })
			if label.TextColor3 ~= Theme.Text then label.TextColor3 = Theme.Text end
		elseif kind == "separator" then
			if label.TextXAlignment ~= Enum.TextXAlignment.Center then label.TextXAlignment = Enum.TextXAlignment.Center end
			Library:Tag(label, { TextColor3 = "Text" })
			if label.TextColor3 ~= Theme.Text then label.TextColor3 = Theme.Text end
		else
			if label.TextXAlignment ~= Enum.TextXAlignment.Left then label.TextXAlignment = Enum.TextXAlignment.Left end
			Library:Tag(label, { TextColor3 = "Text" })
			if label.TextColor3 ~= Theme.Text then label.TextColor3 = Theme.Text end
		end

		x += width
	end

	for index = #entries + 1, #labels do
		local label = labels[index]
		if label then
			if label.Visible ~= false then label.Visible = false end
		end
	end

	if content.Size ~= UDim2.fromOffset(x, 29) then content.Size = UDim2.fromOffset(x, 29) end
	if content.AnchorPoint ~= Vector2.new(0.5, 0) then content.AnchorPoint = Vector2.new(0.5, 0) end
	if content.Position ~= UDim2.new(0.5, 0, 0, 1) then content.Position = UDim2.new(0.5, 0, 0, 1) end
end

function Library:StartWatermarkUpdates()
	if self.WatermarkConnection then
		return
	end
	self.WatermarkFrames = 0
	self.WatermarkElapsed = 0
	self.WatermarkFps = 0
	self.WatermarkPing = 0
	local refreshElapsed = 0
	local rate = math.max(tonumber(self.WatermarkRefreshRate) or 0.1, 0.05)
	self.WatermarkConnection = RunService.PreRender:Connect(function(dt)
		if not self.WatermarkEnabled then
			return
		end
		dt = math.max(dt, 0)
		local object = self.WatermarkObject
		local options = object and object.Options or self.WatermarkOptions
		local needsFps = self:HasWatermarkOption("Fps", options)
		if needsFps then
			self.WatermarkFrames = self.WatermarkFrames + 1
			self.WatermarkElapsed = self.WatermarkElapsed + dt
		end
		refreshElapsed = refreshElapsed + dt
		if refreshElapsed >= rate then
			if needsFps and self.WatermarkElapsed > 0 then
				self.WatermarkFps = self.WatermarkFrames / self.WatermarkElapsed
			end
			self.WatermarkFrames = 0
			self.WatermarkElapsed = 0
			refreshElapsed = 0
			rate = math.max(tonumber(self.WatermarkRefreshRate) or 0.1, 0.05)
			if self:HasWatermarkOption("Ping", options) then
				local player = Players.LocalPlayer
				if player then
					local ok, ping = pcall(player.GetNetworkPing, player)
					if ok and type(ping) == "number" then
						self.WatermarkPing = ping * 1000
					end
				end
			end
			self:RefreshWatermark()
		end
	end)
end

function Library:StopWatermarkUpdates()
	if self.WatermarkConnection then
		self.WatermarkConnection:Disconnect()
		self.WatermarkConnection = nil
	end
end

function Library:Watermark(params)
	params = params or {}
	self:CreateWatermark(params)
	local object = self.WatermarkObject or {}
	object.Name = params.Name or params.name or object.Name or "layer.app"
	object.SubName = params.SubName or params.subname or object.SubName or ""
	object.Status = params.Status or params.status or object.Status or object.SubName or ""
	object.Options = params.Options or params.options or object.Options
	object.Auto = params.Auto ~= false and params.auto ~= false
	object.Items = {
		Frame = self.WatermarkPanel,
		Text = self.WatermarkText,
		Accent = self.WatermarkAccent,
	}
	self.WatermarkObject = object
	self.WatermarkLayoutWidths = nil
	self.WatermarkStaticWidth = params.Width or params.width or self.WatermarkStaticWidth

	function object:SetText(value)
		self.Name = tostring(value or "")
		Library:RefreshWatermark()
		return self
	end

	function object:SetSubText(value)
		self.SubName = tostring(value or "")
		if not self.Auto then
			Library:RefreshWatermark()
		end
		return self
	end

	function object:SetStatus(value)
		self.Status = tostring(value or "")
		Library:RefreshWatermark()
		return self
	end

	function object:SetOptions(options)
		self.Options = options
		Library:RefreshWatermark()
		return self
	end

	function object:SetAuto(state)
		self.Auto = state ~= false
		Library:RefreshWatermark()
		return self
	end

	function object:SetVisibility(state)
		Library:SetWatermarkVisible(state)
		return self
	end

	function object:SetPosition(position)
		if typeof(position) == "UDim2" and Library.WatermarkPanel then
			Library.WatermarkPanel.Position = position
		end
		return self
	end

	function object:Refresh()
		Library:RefreshWatermark()
		return self
	end

	self:RefreshWatermark()
	return object
end

function Library:SetWatermarkVisible(state)
	state = state == true
	if state == self.WatermarkEnabled then
		if state then
			self:RefreshWatermark()
		end
		return state
	end
	self.WatermarkEnabled = state
	if state then
		if not self.WatermarkObject then
			self:Watermark({ Name = "layer.app", Status = "" })
		else
			self:CreateWatermark()
		end
		self.WatermarkGui.Enabled = true
		self:RefreshStandaloneScales()
		self:RefreshWatermark()
		self:StartWatermarkUpdates()
		local panel = self.WatermarkPanel
		panel.Visible = true
		Fade(panel, true, TweenInfo.new(0.18, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out))
	else
		self:StopWatermarkUpdates()
		if self.WatermarkPanel and self.WatermarkPanel.Visible then
			local panel = self.WatermarkPanel
			Fade(panel, false, TweenInfo.new(0.14, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), function()
				if not self.WatermarkEnabled and self.WatermarkGui then
					self.WatermarkGui.Enabled = false
				end
			end)
		elseif self.WatermarkGui then
			self.WatermarkGui.Enabled = false
		end
	end
	return self.WatermarkEnabled
end

Library:OnRepaint(function()
	if Library.WatermarkEnabled then
		Library:RefreshWatermark()
	end
end)

Library.CursorEnabled = true

function Library:CreateCursor(opts)
	if self.CursorGui then
		return self.CursorGui
	end
	opts = opts or {}

	local explicitDotSize = opts.Size or opts.DotSize

	local function resolveDotSize()
		if explicitDotSize then
			return explicitDotSize
		end

		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local shortestSide = math.min(viewport.X, viewport.Y)
		local screenSize = math.clamp(shortestSide / 150, 7, 11)
		local interfaceScale = math.clamp(Library:GetInterfaceScale() or 1, 0.6, 1.4)

		return math.clamp(math.floor(screenSize * interfaceScale + 0.5), 6, 15)
	end

	local dotSize = resolveDotSize()

	local gui = New("ScreenGui", {
		Name = RandomName(),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		AutoLocalize = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		DisplayOrder = MAX_DISPLAY_ORDER,
		Enabled = false,
	})
	ParentGui(gui)
	pcall(function()
		gui.OnTopOfCoreBlur = true
	end)

	local holder = New("Frame", {
		Size = UDim2.fromOffset(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Active = false,
		Selectable = false,
		Parent = gui,
	})

	local dot = New("Frame", {
		Size = UDim2.fromOffset(dotSize, dotSize),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = opts.Color or Theme.Accent,
		BorderSizePixel = 0,
		Active = false,
		Selectable = false,
		ZIndex = MAX_DISPLAY_ORDER,
		Parent = holder,
	})
	Library:Tag(dot, { BackgroundColor3 = not opts.Color and "Accent" or false })
	Corner(dot, dotSize * 0.5)

	if opts.Outline ~= false then
		local outline = Stroke(dot, opts.OutlineColor or Theme.Border, opts.OutlineThickness or 1)
		Library:Tag(outline, { Color = not opts.OutlineColor and "Border" or false })
	end

	local function follow()
		if not gui.Enabled then
			return
		end

		local resolvedSize = resolveDotSize()
		if dot.Size.X.Offset ~= resolvedSize or dot.Size.Y.Offset ~= resolvedSize then
			dot.Size = UDim2.fromOffset(resolvedSize, resolvedSize)
			if dot:FindFirstChildOfClass("UICorner") then
				dot:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, resolvedSize * 0.5)
			end
		end

		local position = UserInputService:GetMouseLocation()
		if not gui.IgnoreGuiInset then
			position = position - GuiService:GetGuiInset()
		end
		local cursorPosition = UDim2.fromOffset(position.X, position.Y)
		if holder.Position ~= cursorPosition then holder.Position = cursorPosition end
	end

	self.CursorFollow = follow
	self.CursorBindName = "LayerCursor_" .. RandomName(6)

	self.CursorGui = gui
	self.CursorHolder = holder
	self.CursorFocusConnections = {
		UserInputService.WindowFocused:Connect(function()
			self.CursorFocused = true
			self:RefreshCursor()
		end),
		UserInputService.WindowFocusReleased:Connect(function()
			self.CursorFocused = false
			self:RefreshCursor()
		end),
	}
	return gui
end

function Library:_ReleaseCursorOverride()
	if not self.CursorOverrideOwned then return end
	local previous = self.CursorPreviousOverride
	self.CursorOverrideOwned = false
	self.CursorPreviousOverride = nil
	pcall(function()
		if UserInputService.OverrideMouseIconBehavior == Enum.OverrideMouseIconBehavior.ForceHide then
			UserInputService.OverrideMouseIconBehavior = previous or Enum.OverrideMouseIconBehavior.None
		end
	end)
end

function Library:_UpdateCursorPresentation()
	local gui = self.CursorGui
	local playersOpen = self.PlayerMenuApi and self.PlayerMenuApi.Open and self.PlayerMenuApi.HostVisible
	local wantsCursor = not self.Destroyed and self.CursorEnabled and (self.Open or playersOpen) and self.CursorFocused ~= false
	local coreMenu = false
	pcall(function() coreMenu = GuiService.MenuIsOpen end)
	wantsCursor = wantsCursor and not coreMenu
	if not gui or not gui.Parent or not self.CursorHolder or not self.CursorHolder.Parent then
		self:_ReleaseCursorOverride()
		return
	end
	if not wantsCursor then
		gui.Enabled = false
		self:_ReleaseCursorOverride()
		return
	end

	local showCustom = false
	if self.CursorOverrideSupported ~= false then
		local ok = pcall(function()
			local current = UserInputService.OverrideMouseIconBehavior
			 
			if self.CursorOverrideOwned and current ~= Enum.OverrideMouseIconBehavior.ForceHide then
				self.CursorOverrideOwned = false
				self.CursorPreviousOverride = nil
			end
			if current == Enum.OverrideMouseIconBehavior.ForceShow then return end
			if not self.CursorOverrideOwned then
				self.CursorPreviousOverride = current
				UserInputService.OverrideMouseIconBehavior = Enum.OverrideMouseIconBehavior.ForceHide
				self.CursorOverrideOwned = true
			end
			showCustom = true
		end)
		if not ok then
			self:_ReleaseCursorOverride()
			self.CursorOverrideSupported = false
		end
	end
	if self.CursorOverrideSupported == false then
		 
		local ok, nativeVisible = pcall(function() return UserInputService.MouseIconEnabled end)
		showCustom = ok and not nativeVisible
	end

	if showCustom and self.CursorFollow then
		 
		gui.Enabled = true
		local ok = pcall(self.CursorFollow)
		if not ok then
			gui.Enabled = false
			self:_ReleaseCursorOverride()
		end
	else
		gui.Enabled = false
	end
end

function Library:RefreshCursor()
	local playersOpen = self.PlayerMenuApi and self.PlayerMenuApi.Open and self.PlayerMenuApi.HostVisible
	local visible = self.Open or playersOpen
	if self.CursorEnabled and visible and not self.Destroyed and not self.CursorGui then
		self:CreateCursor()
	end
	local active = self.CursorEnabled and visible and not self.Destroyed and self.CursorGui ~= nil
	if self.CursorNativeLock then
		self.CursorNativeLock:Disconnect()
		self.CursorNativeLock = nil
	end
	if self.CursorConnection and not active then
		self.CursorConnection:Disconnect()
		self.CursorConnection = nil
	end
	if active and not self.CursorConnection then
		self.CursorConnection = RunService.PreRender:Connect(function()
			self:_UpdateCursorPresentation()
		end)
	end
	self:_UpdateCursorPresentation()
end

function Library:SetCursor(state, opts)
	self.CursorEnabled = state and true or false
	if self.CursorEnabled then
		self:CreateCursor(opts)
	end
	self:RefreshCursor()
	return self.CursorEnabled
end

function Library:Cursor(opts)
	if type(opts) == "boolean" then
		self:SetCursor(opts)
		return self.CursorGui
	end

	opts = opts or {}
	self:SetCursor(opts.Visible ~= false, opts)
	return self.CursorGui
end

Library.PlayerRelations = Library.PlayerRelations or {}

local PLAYER_RELATIONS = {
	neutral = true,
	friendly = true,
	enemy = true,
}

local function ResolvePlayerSubject(subject)
	if typeof(subject) == "Instance" and subject:IsA("Player") then
		return subject
	end

	local asNumber = tonumber(subject)
	for _, player in Players:GetPlayers() do
		if asNumber and player.UserId == asNumber then
			return player
		end
		if type(subject) == "string" then
			local query = string.lower(subject)
			if string.lower(player.Name) == query or string.lower(player.DisplayName) == query then
				return player
			end
		end
	end
	return nil
end

local function PlayerRelationKey(subject)
	local player = ResolvePlayerSubject(subject)
	if player then
		return player.UserId, player
	end
	local id = tonumber(subject)
	if id then
		return id, nil
	end
	return nil, nil
end

function Library:GetPlayerRelation(subject)
	local id = PlayerRelationKey(subject)
	if not id then
		return "neutral"
	end
	local relation = self.PlayerRelations[id]
	return PLAYER_RELATIONS[relation] and relation or "neutral"
end

Library.GetPlayerStatus = Library.GetPlayerRelation

function Library:SetPlayerRelation(subject, relation)
	local id, player = PlayerRelationKey(subject)
	if not id then
		return false
	end
	relation = string.lower(tostring(relation or "neutral"))
	if not PLAYER_RELATIONS[relation] then
		return false
	end

	if relation == "neutral" then
		self.PlayerRelations[id] = nil
	else
		self.PlayerRelations[id] = relation
	end

	if self.PlayerMenuApi and self.PlayerMenuApi.RefreshRelation then
		self.PlayerMenuApi:RefreshRelation(player or id)
	end
	return relation
end

function Library:IsFriendly(subject)
	return self:GetPlayerRelation(subject) == "friendly"
end

function Library:IsEnemy(subject)
	return self:GetPlayerRelation(subject) == "enemy"
end

function Library:IsNeutral(subject)
	return self:GetPlayerRelation(subject) == "neutral"
end

function Library:GetPlayersByRelation(relation)
	relation = string.lower(tostring(relation or "neutral"))
	if not PLAYER_RELATIONS[relation] then
		return {}
	end
	local found = {}
	for _, player in Players:GetPlayers() do
		if self:GetPlayerRelation(player) == relation then
			table.insert(found, player)
		end
	end
	return found
end

function Library:PlayerMenu(opts)
	if self.PlayerMenuApi then
		return self.PlayerMenuApi
	end
	opts = opts or {}

	local gui = New("ScreenGui", {
		Name = RandomName(),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		AutoLocalize = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = MAX_DISPLAY_ORDER - 1,
		Enabled = false,
	})
	ParentGui(gui)

	local width = opts.Width or 384
	local height = opts.Height or 440
	local main = New("Frame", {
		Visible = false,
		Size = UDim2.fromOffset(width, height),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = opts.Position or UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		Parent = gui,
		ThemeTag = { BackgroundColor3 = "Window" },
	})
	Corner(main, 10)
	Stroke(main, Theme.WindowBorder)
	local mainScale = New("UIScale", { Scale = 1, Parent = main })
	Library:RegisterStandaloneScale(mainScale, 1, false)
	local function cancelPlayerMenuVisibility()
		local fade = Fades[main]
		if not fade then
			return
		end
		fade.Ticket = fade.Ticket + 1
		if fade.Completion then
			fade.Completion:Disconnect()
			fade.Completion = nil
		end
		if fade.Tween then
			fade.Tween:Cancel()
			fade.Tween = nil
		end
	end

	local function playerMenuFadeInfo(show)
		local duration = Library.Animations.Enabled == false and 0 or (show and 0.20 or 0.12)
		return TweenInfo.new(duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	end

	local modalDimmer = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Active = false,
		ZIndex = 260,
		Parent = main,
		ThemeTag = { BackgroundColor3 = false },
	})
	Corner(modalDimmer, 10)

	local topBar = New("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Theme.TopBar,
		BorderSizePixel = 0,
		Parent = main,
		ThemeTag = { BackgroundColor3 = "TopBar" },
	})
	Corner(topBar, 10)
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 1, -12),
		BackgroundColor3 = Theme.TopBar,
		BorderSizePixel = 0,
		Parent = topBar,
		ThemeTag = { BackgroundColor3 = "TopBar" },
	})
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Theme.BorderSoft,
		BorderSizePixel = 0,
		Parent = topBar,
		ThemeTag = { BackgroundColor3 = "BorderSoft" },
	})

	local playerTextSize = Theme.TextSize
	local playerRowLineHeight = math.max(22, playerTextSize + 4)
	local playerRowHeight = playerRowLineHeight * 2 + 11
	local heading = Label(topBar, opts.Title or "players", Theme.Accent, playerTextSize, Theme.FontMedium)
	Library:Tag(heading, { TextColor3 = "Accent" })
	heading.Position = UDim2.fromOffset(14, 0)
	heading.Size = UDim2.new(1, -156, 1, 0)

	local countLabel = Label(topBar, "0 players", Theme.Highlight, math.max(Theme.TextSize - 3, 12) + 1)
	Library:Tag(countLabel, { TextColor3 = "Highlight" })
	countLabel.AnchorPoint = Vector2.new(1, 0.5)
	countLabel.Position = UDim2.new(1, -47, 0.5, 0)
	countLabel.Size = UDim2.fromOffset(0, 16)
	countLabel.AutomaticSize = Enum.AutomaticSize.X
	countLabel.TextXAlignment = Enum.TextXAlignment.Right

	local closeBtn = New("TextButton", {
		Size = UDim2.fromOffset(20, 20),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = topBar,
	})
	local closeBars = {}
	for i = 1, 2 do
		local bar = New("Frame", {
			Size = UDim2.fromOffset(13, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = i == 1 and 45 or -45,
			BackgroundColor3 = Theme.TextDim,
			BorderSizePixel = 0,
			Parent = closeBtn,
			ThemeTag = { BackgroundColor3 = "TextDim" },
		})
		Corner(bar, 1)
		closeBars[i] = bar
	end

	local searchFrame = New("Frame", {
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.fromOffset(12, 56),
		BackgroundColor3 = Theme.Field,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = main,
		ThemeTag = { BackgroundColor3 = "Field" },
	})
	Corner(searchFrame, 5)
	local searchStroke = Stroke(searchFrame, Theme.Border)
	local searchIcon = AttachIcon(searchFrame, "search", Theme.TextDim, 14)
	if searchIcon then
		searchIcon.AnchorPoint = Vector2.new(0, 0.5)
		searchIcon.Position = UDim2.new(0, 9, 0.5, 0)
	end
	local searchInset = searchIcon and 30 or 10
	local searchBox = New("TextBox", {
		Size = UDim2.new(1, -(searchInset + 9), 1, 0),
		Position = UDim2.fromOffset(searchInset, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = opts.SearchPlaceholder or "search players",
		PlaceholderColor3 = Theme.TextDim,
		TextColor3 = Theme.TextBright,
		TextSize = playerTextSize,
		Font = Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = searchFrame,
		ThemeTag = { PlaceholderColor3 = "TextDim", TextColor3 = "TextBright" },
	})

	local list = New("ScrollingFrame", {
		Size = UDim2.new(1, -20, 1, -100),
		Position = UDim2.fromOffset(10, 92),
		ScrollHint = { PixelChevron = true },
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		Parent = main,
	})
	List(list, 6)
	Pad(list, 2, 2, 2, 2)

	local detailHeight = 172
	local detailPanel = New("Frame", {
		Size = UDim2.new(1, -20, 0, 0),
		Position = UDim2.new(0, 10, 1, -2),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.Section,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 3,
		Parent = main,
		ThemeTag = { BackgroundColor3 = "Section" },
	})
	Corner(detailPanel, 7)
	SetGroupTransparency(detailPanel, 0)
	local detailStroke = Stroke(detailPanel, Theme.SectionBorder)
	detailStroke.Transparency = 1

	local detailIdentity = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = detailPanel,
	})
	SetGroupTransparency(detailIdentity, 1)

	local api = {
		Gui = gui,
		Frame = main,
		List = list,
		Open = false,
		HostVisible = true,
		AnchorWindow = nil,
		ModalDimmer = modalDimmer,
		ModalDimTween = nil,
		ModalDimmed = false,
		BaseWidth = width,
		BaseHeight = height,
		CurrentHeight = height,
		DockGap = opts.DockGap or 10,
		DockConnection = nil,
		DockConnections = {},
		Rows = {},
		Selected = nil,
		SelectedLeft = false,
		PlayerCount = 0,
		Connections = {},
		RowConnections = {},
		Viewing = nil,
		ViewEnabled = false,
		ViewSession = 0,
		ViewConnection = nil,
		ViewRespawnConnection = nil,
		ViewTransitioning = false,
		ViewOriginal = nil,
		ViewProxy = nil,
		ViewReturning = false,
		ViewReturnFast = false,
		ViewReturnDeadline = nil,
		OnBring = opts.OnBring,
		OnTeleport = opts.OnTeleport,
		OnView = opts.OnView,
	}

	function api:SetModalDimmed(state, transparency)
		state = state == true
		self.ModalDimmed = state

		if self.ModalDimTween then
			self.ModalDimTween:Cancel()
			self.ModalDimTween = nil
		end

		local dimmer = self.ModalDimmer
		if not dimmer or not dimmer.Parent then
			return self
		end

		if state and self.Open and self.HostVisible and gui.Enabled and main.Visible then
			dimmer.Visible = true
			dimmer.Active = true

			local tween = TweenService:Create(
				dimmer,
				AnimationInfo("Modal", false),
				{ BackgroundTransparency = transparency or 0.78 }
			)

			self.ModalDimTween = tween
			tween.Completed:Once(function()
				if self.ModalDimTween == tween then
					self.ModalDimTween = nil
				end
			end)
			tween:Play()

			return self
		end

		dimmer.Active = false

		local tween = TweenService:Create(dimmer, AnimationInfo("Modal", true), { BackgroundTransparency = 1 })

		self.ModalDimTween = tween
		tween.Completed:Once(function(status)
			if status ~= Enum.PlaybackState.Completed then
				return
			end

			if self.ModalDimTween == tween then
				self.ModalDimTween = nil
			end

			if not self.ModalDimmed then
				dimmer.Visible = false
			end
		end)
		tween:Play()

		return self
	end

	Track(modalDimmer.Activated:Connect(function()
		local window = api.AnchorWindow
		local target = window and window.SharedDimmerTarget

		if not target then
			return
		end

		if target.SetOpen then
			target:SetOpen(false)
		elseif target.SetVisible then
			target:SetVisible(false)
		end
	end))

	local sizeTween
	local sizeTweenTicket = 0
	local visibilityTicket = 0
	local function tweenMenuSize(targetSize, opening, onComplete)
		sizeTweenTicket = sizeTweenTicket + 1
		local ticket = sizeTweenTicket
		if sizeTween then
			sizeTween:Cancel()
			sizeTween = nil
		end
		local duration = opening and 0.30 or 0.20
		sizeTween = BezierTween(main, { Size = targetSize }, duration, { 0.16, 1, 0.3, 1 }, function()
			if ticket ~= sizeTweenTicket then
				return
			end
			sizeTween = nil
			if onComplete then
				onComplete()
			end
		end)
		return TweenInfo.new(duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	end

	local function getDockTargetHeight()
		local anchorWindow = api.AnchorWindow
		local anchorFrame = anchorWindow and anchorWindow.Main
		if not anchorFrame or not anchorFrame.Parent then
			return nil
		end
		local anchorHeight = anchorFrame.AbsoluteSize.Y

		local panelScale = math.max(Library:GetInterfaceScale(), 0.0001)
		return math.max(1, (anchorHeight - 1) / panelScale)
	end

	local function syncDockHeight()
		local targetHeight = getDockTargetHeight()
		if not targetHeight then
			return nil
		end
		api.CurrentHeight = targetHeight

		if not sizeTween then
			local currentHeight = math.abs(main.Size.Y.Offset)
			if math.abs(currentHeight - targetHeight) > 0.05 then
				main.Size = UDim2.fromOffset(width, targetHeight)
			end
		end
		return targetHeight
	end

	local function connect(signal, callback, bucket)
		local connection = signal:Connect(callback)
		table.insert(bucket or api.Connections, connection)
		return connection
	end

	local function disconnectBucket(bucket)
		for _, connection in bucket do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(bucket)
	end

	local function getDockAbsolutePosition()
		local anchorWindow = api.AnchorWindow
		local anchorFrame = anchorWindow and anchorWindow.Main
		if not anchorFrame or not anchorFrame.Parent then
			return nil
		end
		return Vector2.new(
			anchorFrame.AbsolutePosition.X + anchorFrame.AbsoluteSize.X + api.DockGap,
			anchorFrame.AbsolutePosition.Y
		)
	end

	local function disconnectDockSync(self)
		for _, connection in self.DockConnections or {} do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(self.DockConnections)
		self.DockConnection = nil
	end

	local function connectDockSync(self)
		disconnectDockSync(self)

		local anchorWindow = self.AnchorWindow
		local anchorFrame = anchorWindow and anchorWindow.Main
		if not anchorFrame or not anchorFrame.Parent then
			return
		end

		local scheduled = false
		local function requestSync()
			if scheduled or self.AnchorDragActive or not self.Open or not self.HostVisible then
				return
			end
			scheduled = true
			task.defer(function()
				scheduled = false
				if self.Open and self.HostVisible and self.AnchorWindow == anchorWindow and anchorFrame.Parent then
					self:SyncToAnchor(true)
				end
			end)
		end

		local function watch(signal)
			local connection = signal:Connect(requestSync)
			table.insert(self.DockConnections, connection)
			return connection
		end

		watch(anchorFrame:GetPropertyChangedSignal("AbsolutePosition"))
		watch(anchorFrame:GetPropertyChangedSignal("AbsoluteSize"))

		if anchorWindow.Scale then
			watch(anchorWindow.Scale:GetPropertyChangedSignal("Scale"))
		end

		self.DockConnection = self.DockConnections[1]
	end

	function api:SetAnchorWindow(_window)
		 
		local previous = self.AnchorWindow
		if self.Open and previous then previous:SetPlayerDockVisible(false, self) end
		disconnectDockSync(self)
		self.AnchorWindow = nil
		self.PreferredAnchorWindow = nil
		if sizeTween then sizeTween:Cancel(); sizeTween = nil end
		sizeTweenTicket = sizeTweenTicket + 1
		self:SetModalDimmed(false)
		if self.DragController then self.DragController:SetEnabled(true) end
		return self
	end

	function api:SyncToAnchor(immediate)
		local anchorWindow = self.AnchorWindow
		local anchorFrame = anchorWindow and anchorWindow.Main
		if not immediate and anchorFrame and anchorFrame.Parent and self.Open and self.HostVisible then
			ClampRenderedFrame(anchorFrame)
		end
		local topLeft = getDockAbsolutePosition()
		if not topLeft then
			return self
		end
		if not self.AnchorDragActive then
			syncDockHeight()
		end

		local interfaceScale = math.max(Library:GetInterfaceScale(), 0.0001)
		local fullVisualSize = Vector2.new(width, self.CurrentHeight or height) * interfaceScale
		local anchorScreen = topLeft + fullVisualSize * 0.5
		local anchorLocal = anchorScreen - gui.AbsolutePosition
		local anchorOffsets =
			ScreenPixelsToOffsets(main, anchorLocal, self.AnchorDragActive and self.AnchorDragScale or nil)
		if main.AnchorPoint ~= Vector2.new(0.5, 0.5) then
			main.AnchorPoint = Vector2.new(0.5, 0.5)
		end
		local targetPosition = UDim2.fromOffset(anchorOffsets.X, anchorOffsets.Y)
		if main.Position ~= targetPosition then
			main.Position = targetPosition
		end
		if not immediate then
			ClampRenderedFrameNextFrame(main)
		end
		return self
	end

	local relationTheme = {
		neutral = "TextDim",
		friendly = "TextCode",
		enemy = "Danger",
	}

	local function applyInspectorNativeFont(textObject)
		pcall(function()
			textObject.Font = Theme.Font
		end)
		if Library.FontFace then
			pcall(function()
				textObject.FontFace = Library.FontFace
			end)
		end
	end

	local refreshViewingIndicator = function() end

	local function destroyLocalViewMarker(self)
		if not self then
			return
		end

		if self.LocalViewMarkerConnection then
			self.LocalViewMarkerConnection:Disconnect()
			self.LocalViewMarkerConnection = nil
		end

		local marker = self.LocalViewMarker
		self.LocalViewMarker = nil
		if not marker then
			return
		end

		for _, object in marker do
			pcall(function()
				object:Remove()
			end)
		end
	end

	local function refreshLocalViewMarker(self)
		destroyLocalViewMarker(self)

		if not self or not self.Viewing or self.ViewReturning then
			return
		end
		if not Drawing or type(Drawing.new) ~= "function" then
			return
		end

		local circle = Drawing.new("Circle")
		circle.Visible = false
		circle.ZIndex = 100000
		circle.Transparency = 1
		circle.Color = Theme.Accent
		circle.Radius = 9
		circle.NumSides = 32
		circle.Thickness = 1
		circle.Filled = true

		local textObject = Drawing.new("Text")
		textObject.Visible = false
		textObject.ZIndex = 100000
		textObject.Transparency = 1
		textObject.Color = Theme.TextBright
		textObject.Text = "YOU"
		textObject.Size = 18
		textObject.Center = true
		textObject.Outline = true
		textObject.OutlineColor = Color3.new(0, 0, 0)

		self.LocalViewMarker = {
			Circle = circle,
			Text = textObject,
		}

		local function hide()
			circle.Visible = false
			textObject.Visible = false
		end

		self.LocalViewMarkerConnection = RunService.RenderStepped:Connect(function()
			if not self.Viewing or self.ViewReturning then
				hide()
				return
			end

			local camera = workspace.CurrentCamera
			local localPlayer = Players.LocalPlayer
			local character = localPlayer and localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not camera or not root then
				hide()
				return
			end

			local screenPoint, onScreen = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3.35, 0))
			if not onScreen or screenPoint.Z <= 0 then
				hide()
				return
			end

			local position = Vector2.new(screenPoint.X, screenPoint.Y)
			circle.Position = position
			textObject.Position = position + Vector2.new(0, 12)
			circle.Color = Theme.Accent
			textObject.Color = Theme.TextBright
			circle.Visible = true
			textObject.Visible = true
		end)
	end

	local updateSelectedDetail = function() end
	local refreshPlayerMenuLayout = function() end
	local paintRelation = function() end

	local actionButtonStates = {}

	local function actionButton(parent, text, order, callback, buttonWidth, connectionBucket)
		local button = New("TextButton", {
			Size = UDim2.fromOffset(buttonWidth or 54, 28),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = parent,
		})

		local visual = New("Frame", {
			Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Theme.Field,
			BorderSizePixel = 0,
			Parent = button,
			ThemeTag = { BackgroundColor3 = "Field" },
		})
		Corner(visual, 8)
		local visualStroke = Stroke(visual, Theme.Border)

		local buttonText = Label(visual, text, Theme.Text, playerTextSize, Theme.Font)
		buttonText.Size = UDim2.fromScale(1, 1)
		buttonText.TextXAlignment = Enum.TextXAlignment.Center
		buttonText.TextTruncate = Enum.TextTruncate.AtEnd
		applyInspectorNativeFont(buttonText)

		local enabled = true
		local hovered = false

		local function applyVisual(animate)
			local backgroundKey = enabled and hovered and IsInteractive(button) and "FieldHover" or (enabled and "Field" or "Section")
			local textKey = enabled and "TextBright" or "TextDim"
			local strokeKey = enabled and "Border" or "BorderSoft"
			local strokeTransparency = enabled and 0 or 0.35

			Library:Tag(visual, { BackgroundColor3 = backgroundKey })
			Library:Tag(buttonText, { TextColor3 = textKey })
			Library:Tag(visualStroke, { Color = strokeKey })

			if animate then
				Tween(visual, { BackgroundColor3 = Theme[backgroundKey] }, EASE_FAST)
				Tween(buttonText, { TextColor3 = Theme[textKey] }, EASE_FAST)
				Tween(visualStroke, { Color = Theme[strokeKey], Transparency = strokeTransparency }, EASE_FAST)
			else
				SetVisual(visual, "BackgroundColor3", Theme[backgroundKey])
				SetVisual(buttonText, "TextColor3", Theme[textKey])
				SetVisual(visualStroke, "Color", Theme[strokeKey])
				SetVisual(visualStroke, "Transparency", strokeTransparency)
			end
		end

		local function setEnabled(state)
			enabled = state ~= false
			button.Active = enabled
			pcall(function()
				button.Interactable = enabled
			end)
			if not enabled then
				hovered = false
			end
			applyVisual(true)
		end

		actionButtonStates[button] = { SetEnabled = setEnabled }
		HoverResets[button] = function()
			hovered = false
			applyVisual(false)
		end
		connect(button.Destroying, function()
			HoverResets[button] = nil
		end, (connectionBucket or api.RowConnections))

		connect(button.MouseLeave, function()
			hovered = false
			applyVisual(true)
		end, (connectionBucket or api.RowConnections))
		connect(button.MouseEnter, function()
			if not enabled or not IsInteractive(button) then
				return
			end
			hovered = true
			applyVisual(true)
		end, (connectionBucket or api.RowConnections))
		Library:OnRepaint(function()
			applyVisual(false)
		end, button)
		connect(button.Activated, function()
			if not enabled then
				return
			end
			callback()
		end, (connectionBucket or api.RowConnections))
		return button
	end

	local function setActionButtonEnabled(button, state)
		local data = actionButtonStates[button]
		if data then
			data.SetEnabled(state)
		end
	end

	local detailContentX = 14
	local detailAvatar = New("ImageLabel", {
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.fromOffset(detailContentX, 12),
		BackgroundColor3 = Theme.Field,
		BorderSizePixel = 0,
		Image = "",
		Parent = detailIdentity,
		ThemeTag = { BackgroundColor3 = "Field" },
	})
	Corner(detailAvatar, 7)
	Stroke(detailAvatar, Theme.BorderSoft)

	local detailNameRow = New("Frame", {
		Size = UDim2.new(1, -220, 0, 20),
		Position = UDim2.fromOffset(detailContentX + 70, 10),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = detailIdentity,
	})

	local detailName = Label(detailNameRow, "", Theme.TextBright, playerTextSize, Theme.FontMedium)
	detailName.Position = UDim2.fromOffset(0, 1)
	detailName.Size = UDim2.new(1, 0, 1, 0)
	detailName.TextTruncate = Enum.TextTruncate.AtEnd

	local detailUsername = Label(detailIdentity, "", Theme.TextDim, playerTextSize - 1)
	detailUsername.Position = UDim2.fromOffset(detailContentX + 70, 30)
	detailUsername.Size = UDim2.new(1, -176, 0, 16)
	detailUsername.TextTruncate = Enum.TextTruncate.AtEnd

	local detailMeta = Label(detailIdentity, "", Theme.TextDim, math.max(playerTextSize - 2, 12))
	detailMeta.Position = UDim2.fromOffset(detailContentX + 70, 49)
	detailMeta.Size = UDim2.new(1, -176, 0, 15)
	detailMeta.TextTruncate = Enum.TextTruncate.AtEnd

	local detailRelationReveal = New("Frame", {
		Size = UDim2.fromOffset(118, 118),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 12),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = detailPanel,
	})

	SetGroupTransparency(detailRelationReveal, 1)

	local relationDropdownHost = {
		Container = detailRelationReveal,
		Window = api.AnchorWindow or Library.Windows[1],
	}

	local detailRelationDropdown = Elements.Dropdown(relationDropdownHost, {
		ValueColorTags = relationTheme,
		Options = { "neutral", "friendly", "enemy" },
		Default = "neutral",
		Search = false,
		MaxHeight = 78,
		Callback = function(relation)
			local player = api.Selected
			if player then
				api:SetRelation(player, relation)
			end
		end,
	})

	detailRelationDropdown.Instance.Size = UDim2.new(1, -4, 0, 26)
	detailRelationDropdown.Instance.Position = UDim2.fromOffset(2, 2)

	for _, descendant in detailRelationDropdown.Instance:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = 21
		end
	end

	local detailTogglesReveal = New("Frame", {
		Size = UDim2.new(1, -26, 0, 46),
		Position = UDim2.fromOffset(detailContentX + 1, 80),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = detailPanel,
	})

	SetGroupTransparency(detailTogglesReveal, 1)

	local detailTogglesContent = New("Frame", {
		Size = UDim2.new(1, -2, 1, 0),
		Position = UDim2.fromOffset(2, 0),
		BackgroundTransparency = 1,
		Parent = detailTogglesReveal,
	})

	local detailToggleList = List(detailTogglesContent, 2, Enum.FillDirection.Vertical)
	detailToggleList.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local detailToggleHost = NewContainer(api.AnchorWindow or Library.Windows[1], detailTogglesContent)

	local loopGotoToggle
	loopGotoToggle = Elements.Toggle(detailToggleHost, {
		Text = "loop goto",
		Flag = false,
		Default = false,
		Callback = function(state)
			api.LoopGoto = state == true
			if api.LoopGoto and not api.Selected then
				api.LoopGoto = false
				task.defer(function()
					loopGotoToggle:Set(false, true)
				end)
			end
		end,
	})

	local viewToggle
	viewToggle = Elements.Toggle(detailToggleHost, {
		Text = "view player",
		Flag = false,
		Default = false,
		Callback = function(state)
			local player = api.Selected
			if not player then
				task.defer(function()
					viewToggle:Set(false, true)
				end)
				return
			end

			if state then
				if api.Viewing ~= player or api.ViewReturning then
					api:View(player)
				end
			elseif api.Viewing == player and not api.ViewReturning then
				api:StopViewing()
			end
		end,
	})

	detailRelationDropdown.OnOpenChanged = function(open)
		local available = api.Selected ~= nil and api.SelectedLeft ~= true and api.Selected.Parent == Players
		loopGotoToggle:SetInputEnabled(not open and available, not available)
		viewToggle:SetInputEnabled(not open and available, not available)
	end

	local detailActions = New("Frame", {
		Size = UDim2.fromOffset(344, 32),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		BackgroundTransparency = 1,
		Parent = detailPanel,
	})
	local detailActionList = List(detailActions, 6, Enum.FillDirection.Horizontal)
	detailActionList.VerticalAlignment = Enum.VerticalAlignment.Center

	local function detailActionSlot(width, order)
		local slot = New("Frame", {
			Size = UDim2.fromOffset(width, 32),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = detailActions,
		})
		SetGroupTransparency(slot, 1)
		return slot
	end

	local gotoReveal = detailActionSlot(62, 1)
	local gotoButton = actionButton(gotoReveal, "goto", 1, function()
		if api.Selected then
			api:TeleportTo(api.Selected)
		end
	end, 62, api.Connections)
	gotoButton.Size = UDim2.new(1, -4, 0, 28)
	gotoButton.Position = UDim2.fromOffset(2, 6)
	gotoButton.LayoutOrder = 0

	local bringReveal = detailActionSlot(62, 2)
	local bringButton = actionButton(bringReveal, "bring", 1, function()
		if api.Selected then
			api:Bring(api.Selected)
		end
	end, 62, api.Connections)
	bringButton.Size = UDim2.new(1, -4, 0, 28)
	bringButton.Position = UDim2.fromOffset(2, 6)
	bringButton.LayoutOrder = 0

	local copyReveal = detailActionSlot(116, 3)
	local copyButton = actionButton(copyReveal, "copy username", 1, function()
		local player = api.Selected
		if not player then
			return
		end
		local copied = false
		if setclipboard then
			copied = pcall(setclipboard, player.Name)
		elseif toclipboard then
			copied = pcall(toclipboard, player.Name)
		end
		Library:Notify({
			Title = "players",
			Text = copied and ("copied @" .. player.Name) or ("username: " .. player.Name),
			Style = copied and "success" or "info",
			Duration = 2,
		})
	end, 116, api.Connections)
	copyButton.Size = UDim2.new(1, -4, 0, 28)
	copyButton.Position = UDim2.fromOffset(2, 6)
	copyButton.LayoutOrder = 0

	local copyIdReveal = detailActionSlot(86, 4)
	local copyIdButton = actionButton(copyIdReveal, "copy id", 1, function()
		local player = api.Selected
		if not player then
			return
		end
		local id = tostring(player.UserId)
		local copied = false
		if setclipboard then
			copied = pcall(setclipboard, id)
		elseif toclipboard then
			copied = pcall(toclipboard, id)
		end
		Library:Notify({
			Title = "players",
			Text = copied and ("copied id " .. id) or ("user id: " .. id),
			Style = copied and "success" or "info",
			Duration = 2,
		})
	end, 86, api.Connections)
	copyIdButton.Size = UDim2.new(1, -4, 0, 28)
	copyIdButton.Position = UDim2.fromOffset(2, 6)
	copyIdButton.LayoutOrder = 0

	local function setSelectedPlayerAvailable(available)
		available = available == true

		if not available then
			if api.LoopGoto then
				api.LoopGoto = false
				loopGotoToggle:Set(false, true)
			end
			if api.Viewing == api.Selected then
				api:StopViewing()
			end
			viewToggle:Set(false, true)
		end

		local inputEnabled = available and not detailRelationDropdown.Open
		loopGotoToggle:SetInputEnabled(inputEnabled, not available)
		viewToggle:SetInputEnabled(inputEnabled, not available)
		setActionButtonEnabled(gotoButton, available)
		setActionButtonEnabled(bringButton, available)
	end

	local function getHumanoid(player)
		local character = player and player.Character
		return character and character:FindFirstChildOfClass("Humanoid") or nil
	end

	local function getRoot(player)
		local character = player and player.Character
		return character and character:FindFirstChild("HumanoidRootPart") or nil
	end

	local function getViewPoint(player)
		local character = player and player.Character
		if not character then
			return nil
		end
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head.Position
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		return root and root.Position or nil
	end

	local function destroyViewProxy(self)
		if self.ViewConnection then
			self.ViewConnection:Disconnect()
			self.ViewConnection = nil
		end
		if self.ViewRespawnConnection then
			self.ViewRespawnConnection:Disconnect()
			self.ViewRespawnConnection = nil
		end
		if self.ViewProxy then
			pcall(function()
				self.ViewProxy:Destroy()
			end)
			self.ViewProxy = nil
		end
		self.ViewReturning = false
		self.ViewReturnFast = false
		self.ViewReturnDeadline = nil
		self.ViewTransitioning = false
		self.ViewMotionPlayer, self.ViewMotionPosition, self.ViewMotionLook, self.ViewLockUntil = nil, nil, nil, nil
	end

	local function isLocalCameraUnstable()
		local humanoid = getHumanoid(Players.LocalPlayer)
		if not humanoid or humanoid.Health <= 0 then
			return true
		end
		local state = humanoid:GetState()
		return state == Enum.HumanoidStateType.Dead
			or state == Enum.HumanoidStateType.Physics
			or state == Enum.HumanoidStateType.Ragdoll
			or state == Enum.HumanoidStateType.FallingDown
	end

	local function restoreLocalCamera(self, camera, original)
		camera = camera or workspace.CurrentCamera
		if not camera then
			return false
		end

		local humanoid = getHumanoid(Players.LocalPlayer)
		local subject = humanoid
		if not subject then
			local originalSubject = original and original.CameraSubject
			if originalSubject and originalSubject.Parent then
				subject = originalSubject
			end
		end

		if camera.CameraType ~= Enum.CameraType.Custom then camera.CameraType = Enum.CameraType.Custom end
		if subject and camera.CameraSubject ~= subject then
			camera.CameraSubject = subject
		end

		local ticket = (self.CameraRestoreTicket or 0) + 1
		self.CameraRestoreTicket = ticket
		task.spawn(function()
			for _ = 1, 4 do
				RunService.RenderStepped:Wait()
				if self.CameraRestoreTicket ~= ticket then
					return
				end
				local currentCamera = workspace.CurrentCamera
				local currentHumanoid = getHumanoid(Players.LocalPlayer)
				if currentCamera and currentHumanoid then
					if currentCamera.CameraType ~= Enum.CameraType.Custom then currentCamera.CameraType = Enum.CameraType.Custom end
					if currentCamera.CameraSubject ~= currentHumanoid then currentCamera.CameraSubject = currentHumanoid end
				end
			end
		end)
		return subject ~= nil
	end

	local function ensureViewProxy(self, camera)
		if self.ViewProxy and self.ViewProxy.Parent then
			return self.ViewProxy
		end
		local start = getViewPoint(Players.LocalPlayer) or camera.CFrame.Position
		local proxy = Instance.new("Part")
		proxy.Name = RandomName()
		proxy.Size = Vector3.new(1, 1, 1)
		proxy.Anchored = true
		proxy.CanCollide = false
		proxy.CanTouch = false
		proxy.CanQuery = false
		proxy.Transparency = 1
		proxy.CastShadow = false
		proxy.CFrame = CFrame.new(start)
		proxy.Parent = workspace
		self.ViewProxy = proxy
		return proxy
	end

	local function lockViewMotion(self, player, target, dt, current, alpha)
		local root = getRoot(player)
		local look = root and root.CFrame.LookVector
		local velocity = root and root.AssemblyLinearVelocity.Magnitude or 0
		local samePlayer = self.ViewMotionPlayer == player
		local previous = samePlayer and self.ViewMotionPosition
		local step = previous and (target - previous).Magnitude or 0
		local elapsed = math.max(dt, 1 / 1000)
		local speed = math.max(velocity, step / elapsed)
		local turn = 0
		if samePlayer and look and self.ViewMotionLook then
			turn = math.acos(math.clamp(look:Dot(self.ViewMotionLook), -1, 1)) / elapsed
		end
		if not samePlayer then self.ViewLockUntil = nil end
		self.ViewMotionPlayer, self.ViewMotionPosition, self.ViewMotionLook = player, target, look
		local now = os.clock()
		local remainingGap = current and (target - current).Magnitude * (1 - (alpha or 0)) or 0
		local trailing = samePlayer and not self.ViewTransitioning and step > 0.03 and remainingGap > 0.12
		if trailing or speed >= 60 or step >= 8 or turn >= math.rad(360) then
			self.ViewLockUntil = now + 0.18
		end
		return self.ViewLockUntil ~= nil and now < self.ViewLockUntil
	end

	local function startViewProxyFollow(self, _camera)
		if self.ViewConnection then
			return
		end
		local bindName = "LayerView_" .. RandomName(6)
		self.ViewConnection = {
			Disconnect = function() RunService:UnbindFromRenderStep(bindName) end,
		}
		RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value - 1, function(dt)
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end

			if not self.ViewReturning and (not self.ViewEnabled or not self.Viewing) then
				return
			end

			local destinationPlayer = self.ViewReturning and Players.LocalPlayer or self.Viewing
			if not destinationPlayer then
				return
			end

			local proxy = self.ViewProxy
			if not proxy or not proxy.Parent then
				proxy = ensureViewProxy(self, camera)
			end
			if not proxy then
				return
			end

			if camera.CameraType ~= Enum.CameraType.Custom then
				camera.CameraType = Enum.CameraType.Custom
			end
			if camera.CameraSubject ~= proxy then
				camera.CameraSubject = proxy
			end

			local target = getViewPoint(destinationPlayer)
			if self.ViewReturning and not target then
				local original = self.ViewOriginal
				self.ViewOriginal = nil
				restoreLocalCamera(self, camera, original)
				destroyViewProxy(self)
				return
			end
			if target then
				local current = proxy.Position
				local distance = (target - current).Magnitude
				if self.ViewTransitioning and self.ViewTransitionStarted
					and os.clock() - self.ViewTransitionStarted >= 0.25 then
					self.ViewTransitioning = false
				end
				local speed
				if self.ViewReturning then
					speed = self.ViewReturnFast and 34 or 22
				else
					speed = self.ViewTransitioning and 14 or 150
				end
				local alpha = math.clamp(1 - math.exp(-dt * speed), 0, 1)
				local locked = not self.ViewReturning and lockViewMotion(self, destinationPlayer, target, dt, current, alpha)
				local nextPosition = locked and target or current:Lerp(target, alpha)
				if locked then self.ViewTransitioning = false end
				if distance < 0.04 then
					nextPosition = target
				end
				proxy.CFrame = CFrame.new(nextPosition)

				if not self.ViewReturning and distance < 0.18 then
					self.ViewTransitioning = false
				end

				if
					self.ViewReturning
					and (distance < 0.08 or (self.ViewReturnDeadline and os.clock() >= self.ViewReturnDeadline))
				then
					local original = self.ViewOriginal
					self.ViewOriginal = nil
					restoreLocalCamera(self, camera, original)
					destroyViewProxy(self)
				end
			elseif self.ViewReturning and self.ViewReturnDeadline and os.clock() >= self.ViewReturnDeadline then
				local original = self.ViewOriginal
				self.ViewOriginal = nil
				restoreLocalCamera(self, camera, original)
				destroyViewProxy(self)
			end
		end)
	end

	function api:StopViewing(fast)
		if not self.Viewing and not self.ViewTransitioning and not self.ViewReturning then
			self.ViewEnabled = false
			return self
		end
		local old = self.Viewing
		self.ViewEnabled = false
		self.ViewSession = (self.ViewSession or 0) + 1

		self.CameraRestoreTicket = (self.CameraRestoreTicket or 0) + 1
		self.Viewing = nil
		self.ViewTransitioning = false
		refreshViewingIndicator()
		destroyLocalViewMarker(self)

		if self.OnView then
			destroyViewProxy(self)
			Library:SafeCallback("player view", self.OnView, old, false, self)
			return self
		end

		local camera = workspace.CurrentCamera
		if not camera then
			destroyViewProxy(self)
			return self
		end
		if not self.ViewProxy then
			local original = self.ViewOriginal
			self.ViewOriginal = nil
			restoreLocalCamera(self, camera, original)
			return self
		end

		local returnPoint = getViewPoint(Players.LocalPlayer)
		local longReturn = returnPoint and (returnPoint - self.ViewProxy.Position).Magnitude >= 80
		if isLocalCameraUnstable() or longReturn then
			local original = self.ViewOriginal
			self.ViewOriginal = nil
			restoreLocalCamera(self, camera, original)
			destroyViewProxy(self)
			return self
		end

		self.ViewReturning = true
		self.ViewReturnFast = fast == true
		self.ViewReturnDeadline = os.clock() + (fast == true and 0.16 or 0.30)
		startViewProxyFollow(self, camera)
		return self
	end

	function api:TeleportTo(player)
		player = ResolvePlayerSubject(player)
		if not player or player == Players.LocalPlayer then
			return false
		end
		if self.OnTeleport then
			Library:SafeCallback("player teleport", self.OnTeleport, player, self)
			return true
		end
		local localCharacter = Players.LocalPlayer and Players.LocalPlayer.Character
		local targetRoot = getRoot(player)
		if not localCharacter or not targetRoot then
			return false
		end
		local ok = pcall(function()
			localCharacter:PivotTo(targetRoot.CFrame * CFrame.new(0, 0, 3))
		end)
		return ok
	end

	function api:View(player)
		player = ResolvePlayerSubject(player)
		if not player or player == Players.LocalPlayer then
			return false
		end
		if self.Viewing == player and not self.ViewReturning then
			self:StopViewing(self.ViewTransitioning == true)
			return true
		end

		local camera = workspace.CurrentCamera
		local targetPoint = getViewPoint(player)
		if not camera or not targetPoint then
			return false
		end

		local previous = self.Viewing
		self.ViewEnabled = true
		self.ViewSession = (self.ViewSession or 0) + 1

		self.CameraRestoreTicket = (self.CameraRestoreTicket or 0) + 1
		if self.OnView then
			if previous then
				Library:SafeCallback("player view", self.OnView, previous, false, self)
			end
			self.Viewing = player
			self.ViewTransitioning = false
			refreshViewingIndicator()
			refreshLocalViewMarker(self)
			Library:SafeCallback("player view", self.OnView, player, true, self)
			return true
		end

		if not self.ViewOriginal then
			self.ViewOriginal = {
				CameraType = camera.CameraType,
				CameraSubject = camera.CameraSubject,
				CFrame = camera.CFrame,
			}
		end

		local proxy = ensureViewProxy(self, camera)
		self.Viewing = player
		self.ViewReturning = false
		refreshViewingIndicator()
		refreshLocalViewMarker(self)
		self.ViewReturnFast = false
		self.ViewReturnDeadline = nil
		self.ViewTransitioning = true
		self.ViewTransitionStarted = os.clock()
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = proxy
		startViewProxyFollow(self, camera)
		return true
	end

	function api:Bring(player)
		player = ResolvePlayerSubject(player)
		if not player or player == Players.LocalPlayer then
			return false
		end
		if type(self.OnBring) ~= "function" then
			Library:Notify({
				Title = "player menu",
				Text = "bring needs an OnBring callback",
				Style = "warning",
				Duration = 3,
			})
			return false
		end
		Library:SafeCallback("player bring", self.OnBring, player, self)
		return true
	end

	function api:SetBringFunction(callback)
		self.OnBring = callback
		return self
	end

	function api:SetTeleportFunction(callback)
		self.OnTeleport = callback
		return self
	end

	function api:SetViewFunction(callback)
		self.OnView = callback
		return self
	end

	function api:GetRelation(player)
		return Library:GetPlayerRelation(player)
	end

	function api:SetRelation(player, relation)
		local result = Library:SetPlayerRelation(player, relation)
		if result and opts.OnRelationChanged then
			Library:SafeCallback("player relation", opts.OnRelationChanged, ResolvePlayerSubject(player), result, self)
		end
		return result
	end

	paintRelation = function(player, object)
		if not object or not object.Parent then
			return
		end
		local relation = Library:GetPlayerRelation(player)
		local key = relationTheme[relation] or "TextDim"
		object.Text = relation
		Library:Tag(object, { TextColor3 = key })
		Tween(object, { TextColor3 = Theme[key] }, EASE_FAST)
	end

	local detailRevealTicket = 0
	local detailRevealControllers = {}

	local function cancelDetailReveal()
		detailRevealTicket = detailRevealTicket + 1
		for _, controller in detailRevealControllers do
			pcall(function()
				controller:Cancel()
			end)
		end
		table.clear(detailRevealControllers)
		return detailRevealTicket
	end

	local function detailTween(instance, goals, duration, curve, onComplete)
		local groupTransparency = goals.GroupTransparency
		if groupTransparency ~= nil then
			local filtered = {}
			for key, value in goals do
				if key ~= "GroupTransparency" then
					filtered[key] = value
				end
			end

			local groupTween = TweenGroupTransparency(
				instance,
				groupTransparency,
				TweenInfo.new(duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
				FirstTableKey(filtered) == nil and onComplete or nil
			)

			if FirstTableKey(filtered) == nil then
				table.insert(detailRevealControllers, groupTween)
				return groupTween
			end

			local controller = BezierTween(instance, filtered, duration, curve or { 0.16, 1, 0.3, 1 }, onComplete)
			table.insert(detailRevealControllers, groupTween)
			table.insert(detailRevealControllers, controller)
			return controller
		end

		local controller = BezierTween(instance, goals, duration, curve or { 0.16, 1, 0.3, 1 }, onComplete)
		table.insert(detailRevealControllers, controller)
		return controller
	end

	local function resetDetailControlReveal()
		SetGroupTransparency(detailIdentity, 1)
		SetGroupTransparency(detailRelationReveal, 1)
		detailRelationReveal.Position = UDim2.new(1, -10, 0, 16)
		SetGroupTransparency(detailTogglesReveal, 1)
		detailTogglesReveal.Position = UDim2.fromOffset(detailContentX + 1, 84)
		for _, pair in {
			{ gotoReveal, gotoButton },
			{ bringReveal, bringButton },
			{ copyReveal, copyButton },
			{ copyIdReveal, copyIdButton },
		} do
			SetGroupTransparency(pair[1], 1)
			pair[2].Position = UDim2.fromOffset(2, 6)
		end
	end

	local function revealDetailControls(ticket)
		local controlCurve = { 0.16, 1, 0.3, 1 }
		local stages = {
			{ 0.00, detailRelationReveal, { GroupTransparency = 0, Position = UDim2.new(1, -10, 0, 12) } },
			{
				0.045,
				detailTogglesReveal,
				{ GroupTransparency = 0, Position = UDim2.fromOffset(detailContentX + 1, 80) },
			},
			{ 0.090, gotoReveal, { GroupTransparency = 0 }, gotoButton },
			{ 0.130, bringReveal, { GroupTransparency = 0 }, bringButton },
			{ 0.170, copyReveal, { GroupTransparency = 0 }, copyButton },
			{ 0.210, copyIdReveal, { GroupTransparency = 0 }, copyIdButton },
		}
		for _, stage in stages do
			task.delay(stage[1], function()
				if ticket ~= detailRevealTicket or not api.Selected or not detailPanel.Visible then
					return
				end
				local target = stage[2]
				local button = stage[4]
				detailTween(target, stage[3], 0.18, controlCurve)
				if button then
					detailTween(button, { Position = UDim2.fromOffset(2, 2) }, 0.18, controlCurve)
				end
			end)
		end
	end

	local detailAvatarTicket = 0
	local detailAvatarPlayer = nil
	local detailLeftState = false
	local detailLeftNameMotion

	local function setDetailLeftPill(active, animated)
		active = active == true
		if detailLeftState == active then
			return
		end
		detailLeftState = active

		if detailLeftNameMotion then
			detailLeftNameMotion:Cancel()
			detailLeftNameMotion = nil
		end

		local avatarTransparency = active and 0.55 or 0
		local nameKey = active and "Danger" or "TextBright"

		Library:Tag(detailName, { TextColor3 = nameKey })
		if animated then
			local info = TweenInfo.new(active and 0.18 or 0.12, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
			Tween(detailAvatar, { ImageTransparency = avatarTransparency }, info)
			detailLeftNameMotion = Tween(detailName, { TextColor3 = Theme[nameKey] }, info)
			if detailLeftNameMotion then
				local motion = detailLeftNameMotion
				motion.Completed:Once(function()
					if detailLeftNameMotion == motion then
						detailLeftNameMotion = nil
					end
				end)
			end
		else
			SetVisual(detailAvatar, "ImageTransparency", avatarTransparency)
			SetVisual(detailName, "TextColor3", Theme[nameKey])
		end
	end

	local function setViewToggleVisual(active)
		viewToggle:Set(active == true, true)
	end

	local loopGotoElapsed = 0
	connect(RunService.Heartbeat, function(dt)
		if not api.LoopGoto then
			loopGotoElapsed = 0
			return
		end

		local player = api.Selected
		if not player or player.Parent ~= Players then
			api.LoopGoto = false
			loopGotoToggle:Set(false, true)
			loopGotoElapsed = 0
			return
		end

		loopGotoElapsed = loopGotoElapsed + dt
		if loopGotoElapsed >= 0.05 then
			loopGotoElapsed = 0
			api:TeleportTo(player)
		end
	end)

	updateSelectedDetail = function()
		local player = api.Selected
		if not player then
			detailAvatarPlayer = nil
			detailAvatar.Image = ""
			setDetailLeftPill(false, false)
			setViewToggleVisual(false)
			setSelectedPlayerAvailable(false)
			if api.LoopGoto then
				api.LoopGoto = false
				loopGotoToggle:Set(false, true)
			end
			return
		end

		detailName.Text = player.DisplayName
		local available = api.SelectedLeft ~= true and player.Parent == Players
		setDetailLeftPill(not available, false)
		setSelectedPlayerAvailable(available)
		detailUsername.Text = "@" .. player.Name
		local meta = "user id: " .. tostring(player.UserId)
		if player.Team then
			meta = meta .. "  ·  " .. player.Team.Name
		end
		detailMeta.Text = meta
		detailRelationDropdown:Set(Library:GetPlayerRelation(player), true)
		local viewing = api.Viewing == player and not api.ViewReturning
		setViewToggleVisual(viewing)

		if detailAvatarPlayer ~= player then
			detailAvatarPlayer = player
			detailAvatarTicket = detailAvatarTicket + 1
			local ticket = detailAvatarTicket
			detailAvatar.Image = ""
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(
						player.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size150x150
					)
				end)
				if ok and image and ticket == detailAvatarTicket and api.Selected == player and detailAvatar.Parent then
					detailAvatar.Image = image
				end
			end)
		end
	end

	local detailSwitchTicket = 0
	local detailSwitchOut
	local detailSwitchIn
	local function cancelDetailSwitch()
		detailSwitchTicket = detailSwitchTicket + 1
		if detailSwitchOut then
			detailSwitchOut:Cancel()
			detailSwitchOut = nil
		end
		if detailSwitchIn then
			detailSwitchIn:Cancel()
			detailSwitchIn = nil
		end
	end

	local function switchSelectedDetail(player)
		cancelDetailSwitch()
		local ticket = detailSwitchTicket

		detailSwitchOut = TweenGroupTransparency(
			detailIdentity,
			1,
			TweenInfo.new(0.11, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
			function()
				if ticket ~= detailSwitchTicket or api.Selected ~= player or not detailIdentity.Parent then
					return
				end
				detailSwitchOut = nil
				updateSelectedDetail()
				detailSwitchIn = TweenGroupTransparency(
					detailIdentity,
					0,
					TweenInfo.new(0.19, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
					function()
						if ticket == detailSwitchTicket then
							detailSwitchIn = nil
						end
					end
				)
			end
		)
	end

	local selectedCardScrollMotion
	local selectedCardScrollTicket = 0
	local lastManualCardScroll = -math.huge
	local selectedCardAnchor
	local selectedCardScrollStarting = false
	local selectedCardAnchorPending = false
	local selectedCardScrollWriting = false
	local function cancelSelectedCardScroll()
		selectedCardScrollTicket = selectedCardScrollTicket + 1
		selectedCardAnchor = nil
		selectedCardScrollStarting = false
		if selectedCardScrollMotion then
			selectedCardScrollMotion:Cancel()
			selectedCardScrollMotion = nil
		end
	end

	local function selectedCardScrollTarget(player, planned)
		local row = api.Rows[player]
		local card = row and row.Frame
		if not card or not card.Parent or not card.Visible then return nil end
		local scale = GetFrameRenderScale(list)
		local viewportHeight = list.AbsoluteSize.Y / scale
		if planned then
			local frameHeight = main.Size.Y.Scale == 0 and main.Size.Y.Offset
				or main.AbsoluteSize.Y / GetFrameRenderScale(main)
			viewportHeight = frameHeight - 100 - (api.Selected and (detailHeight + 10) or 0)
		end
		viewportHeight = math.max(1, viewportHeight)
		local current = list.CanvasPosition.Y
		local function bounds(child)
			 
			local top = current + (child.AbsolutePosition.Y - list.AbsolutePosition.Y) / scale
			return top, child.AbsoluteSize.Y / scale
		end
		local top = bounds(card)
		local contentBottom = 0
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				local childTop, childHeight = bounds(child)
				contentBottom = math.max(contentBottom, childTop + childHeight)
			end
		end
		local padding = list:FindFirstChildOfClass("UIPadding")
		if padding then contentBottom = contentBottom + padding.PaddingBottom.Offset + padding.PaddingBottom.Scale * viewportHeight end
		return math.clamp(top - 6, 0, math.max(0, contentBottom - viewportHeight))
	end

	local function selectedCardAnchorValid()
		return selectedCardAnchor and api.Open and api.HostVisible and list.Parent ~= nil
			and api.Selected == selectedCardAnchor.Player
	end

	local function preserveSelectedCardAnchor()
		if not selectedCardAnchorValid() or selectedCardScrollMotion or selectedCardScrollStarting
			or selectedCardScrollWriting or selectedCardAnchorPending then return end
		selectedCardAnchorPending = true
		local ticket = selectedCardScrollTicket
		task.defer(function()
			RunService.RenderStepped:Wait()
			selectedCardAnchorPending = false
			if ticket ~= selectedCardScrollTicket or not selectedCardAnchorValid()
				or selectedCardScrollMotion or selectedCardScrollStarting then return end
			local target = selectedCardScrollTarget(selectedCardAnchor.Player)
			if target and math.abs(target - list.CanvasPosition.Y) > 0.25 then
				selectedCardScrollWriting = true
				list.CanvasPosition = Vector2.new(list.CanvasPosition.X, target)
				selectedCardScrollWriting = false
			end
		end)
	end

	local function scrollSelectedCardIntoView(player)
		cancelSelectedCardScroll()
		if not player or os.clock() - lastManualCardScroll < 0.15 then return end
		selectedCardAnchor = { Player = player }
		selectedCardScrollStarting = true
		local ticket = selectedCardScrollTicket
		task.defer(function()
			RunService.RenderStepped:Wait()
			if ticket ~= selectedCardScrollTicket then return end
			if not selectedCardAnchorValid() then cancelSelectedCardScroll(); return end
			local target = selectedCardScrollTarget(player, true)
			if target == nil then cancelSelectedCardScroll(); return end
			if math.abs(target - list.CanvasPosition.Y) < 0.5 then
				selectedCardScrollStarting = false
				preserveSelectedCardAnchor()
				return
			end
			if list.ResetScrollVelocity then list:ResetScrollVelocity() end
			selectedCardScrollMotion = BezierTween(list, { CanvasPosition = Vector2.new(list.CanvasPosition.X, target) },
				0.28, { 0.16, 1, 0.3, 1 }, function()
					if ticket ~= selectedCardScrollTicket then return end
					selectedCardScrollMotion = nil
					preserveSelectedCardAnchor()
				end)
			selectedCardScrollStarting = false
		end)
	end

	local function cancelCardScrollForInput(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseWheel then
			 
			lastManualCardScroll = os.clock()
			if selectedCardAnchor or selectedCardScrollMotion or selectedCardScrollStarting then cancelSelectedCardScroll() end
			return
		end
		if kind ~= Enum.UserInputType.Touch or not selectedCardAnchor then return end
		local point = input.Position
		local position, size = main.AbsolutePosition, main.AbsoluteSize
		if point.X >= position.X and point.X <= position.X + size.X
			and point.Y >= position.Y and point.Y <= position.Y + size.Y then cancelSelectedCardScroll() end
	end
	connect(UserInputService.InputChanged, cancelCardScrollForInput)
	connect(UserInputService.InputBegan, cancelCardScrollForInput)
	connect(list.InputChanged, cancelCardScrollForInput)
	connect(list.InputBegan, cancelCardScrollForInput)
	for _, property in { "AbsoluteSize", "AbsoluteWindowSize", "AbsoluteCanvasSize", "CanvasPosition" } do
		connect(list:GetPropertyChangedSignal(property), preserveSelectedCardAnchor)
	end
	connect(list.Destroying, cancelSelectedCardScroll)

	local detailSizeTween
	local listSizeTween
	refreshPlayerMenuLayout = function(animated)
		local hasSelection = api.Selected ~= nil
		local detailSpace = hasSelection and (detailHeight + 10) or 0
		local targetListSize = UDim2.new(1, -20, 1, -(100 + detailSpace))
		local layoutDuration = 0.30
		local shellCurve = { 0.16, 1, 0.3, 1 }

		if listSizeTween then
			listSizeTween:Cancel()
			listSizeTween = nil
		end
		if detailSizeTween then
			detailSizeTween:Cancel()
			detailSizeTween = nil
		end

		if animated and api.Open and api.HostVisible then
			listSizeTween = BezierTween(list, { Size = targetListSize }, layoutDuration, shellCurve)
		else
			list.Size = targetListSize
		end

		if hasSelection then
			local ticket = cancelDetailReveal()
			if not detailPanel.Visible then
				detailPanel.Visible = true
				detailPanel.Size = UDim2.new(1, -20, 0, 0)
				detailPanel.Position = UDim2.new(0, 10, 1, -2)
				detailPanel.BackgroundTransparency = 1
				detailStroke.Transparency = 1
				resetDetailControlReveal()
			end

			if animated and api.Open and api.HostVisible then
				detailPanel.ClipsDescendants = true
				detailSizeTween = detailTween(
					detailPanel,
					{
						Size = UDim2.new(1, -20, 0, detailHeight),
						Position = UDim2.new(0, 10, 1, -10),
						BackgroundTransparency = 0,
					},
					0.30,
					shellCurve,
					function()
						if api.Selected and detailPanel.Parent then
							detailPanel.ClipsDescendants = false
						end
					end
				)
				detailTween(detailStroke, { Transparency = 0 }, 0.22, shellCurve)

				task.delay(0.055, function()
					if ticket ~= detailRevealTicket or not api.Selected or not detailPanel.Visible then
						return
					end
					detailTween(detailIdentity, { GroupTransparency = 0 }, 0.21, shellCurve)
				end)

				task.delay(0.19, function()
					if ticket == detailRevealTicket then
						revealDetailControls(ticket)
					end
				end)
			else
				detailPanel.Size = UDim2.new(1, -20, 0, detailHeight)
				detailPanel.Position = UDim2.new(0, 10, 1, -10)
				detailPanel.BackgroundTransparency = 0
				detailPanel.ClipsDescendants = false
				detailStroke.Transparency = 0
				SetGroupTransparency(detailIdentity, 0)
				SetGroupTransparency(detailRelationReveal, 0)
				detailRelationReveal.Position = UDim2.new(1, -10, 0, 12)
				SetGroupTransparency(detailTogglesReveal, 0)
				detailTogglesReveal.Position = UDim2.fromOffset(detailContentX + 1, 80)
				for _, pair in {
					{ gotoReveal, gotoButton },
					{ bringReveal, bringButton },
					{ copyReveal, copyButton },
					{ copyIdReveal, copyIdButton },
				} do
					SetGroupTransparency(pair[1], 0)
					pair[2].Position = UDim2.fromOffset(2, 2)
				end
			end
		else
			local ticket = cancelDetailReveal()
			if detailPanel.Visible and animated and api.Open and api.HostVisible then
				detailPanel.ClipsDescendants = true

				for index, target in {
					copyIdReveal,
					copyReveal,
					bringReveal,
					gotoReveal,
					detailTogglesReveal,
					detailRelationReveal,
				} do
					task.delay((index - 1) * 0.018, function()
						if ticket ~= detailRevealTicket then
							return
						end
						detailTween(target, { GroupTransparency = 1 }, 0.09, shellCurve)
					end)
				end
				task.delay(0.045, function()
					if ticket == detailRevealTicket then
						detailTween(detailIdentity, { GroupTransparency = 1 }, 0.10, shellCurve)
					end
				end)
				task.delay(0.065, function()
					if ticket ~= detailRevealTicket then
						return
					end
					detailTween(detailStroke, { Transparency = 1 }, 0.10, shellCurve)
					detailSizeTween = detailTween(
						detailPanel,
						{
							Size = UDim2.new(1, -20, 0, 0),
							Position = UDim2.new(0, 10, 1, -2),
							BackgroundTransparency = 1,
						},
						0.17,
						shellCurve,
						function()
							if ticket == detailRevealTicket and not api.Selected and detailPanel.Parent then
								detailPanel.Visible = false
							end
						end
					)
				end)
			else
				detailPanel.Visible = false
				detailPanel.ClipsDescendants = true
				detailPanel.Size = UDim2.new(1, -20, 0, 0)
				detailPanel.Position = UDim2.new(0, 10, 1, -2)
				detailPanel.BackgroundTransparency = 1
				detailStroke.Transparency = 1
				resetDetailControlReveal()
			end
		end

		if api.Open and api.AnchorWindow then
			if api.AnchorWindow.Refit then
				api.AnchorWindow:Refit()
			end
			if api.AnchorWindow.Main then
				ClampRenderedFrameNextFrame(api.AnchorWindow.Main)
			end
		end
	end

	function api:SelectPlayer(subject)
		local player = ResolvePlayerSubject(subject)
		if player == Players.LocalPlayer then
			player = nil
		end
		if player == self.Selected then
			player = nil
		end

		local previous = self.Selected
		local switching = previous ~= nil and player ~= nil and previous ~= player and detailPanel.Visible
		if self.LoopGoto and previous ~= player then
			self.LoopGoto = false
			loopGotoToggle:Set(false, true)
		end
		self.Selected = player
		self.SelectedLeft = false
		setDetailLeftPill(false, false)

		if switching then
			refreshViewingIndicator(true)
			switchSelectedDetail(player)
		else
			cancelDetailSwitch()
			updateSelectedDetail()
			refreshViewingIndicator(true)
			refreshPlayerMenuLayout(true)
		end
		scrollSelectedCardIntoView(player)
		return self
	end

	function api:RefreshRelation(subject)
		local player = ResolvePlayerSubject(subject)
		if not player then
			return self
		end
		local row = self.Rows[player]
		if row and row.Relation then
			paintRelation(player, row.Relation)
		end
		if self.Selected == player then
			detailRelationDropdown:Set(Library:GetPlayerRelation(player), true)
		end
		return self
	end

	refreshViewingIndicator = function(skipDetail)
		for player, row in api.Rows do
			local viewing = api.Viewing == player and not api.ViewReturning
			local selected = api.Selected == player
			local strokeKey = viewing and "AccentDim" or (selected and "Border" or "SectionBorder")
			local backgroundKey = selected and "FieldHover" or "Section"
			if row.RowStroke then
				Library:Tag(row.RowStroke, { Color = strokeKey })
				Tween(row.RowStroke, { Color = Theme[strokeKey] }, EASE_FAST)
			end
			Library:Tag(row.Frame, { BackgroundColor3 = backgroundKey })
			Tween(row.Frame, { BackgroundColor3 = Theme[backgroundKey] }, EASE_FAST)
		end
		if not skipDetail then
			updateSelectedDetail()
		end
	end

	local function applyFilter()
		local query = string.lower(searchBox.Text)
		for player, row in api.Rows do
			local haystack = string.lower(player.Name .. " " .. player.DisplayName)
			local visible = query == "" or string.find(haystack, query, 1, true) ~= nil
			if row.Frame.Visible ~= visible then row.Frame.Visible = visible end
		end
	end

	local function clearRows()
		disconnectBucket(api.RowConnections)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(api.Rows)
	end

	local function addPlayerRow(player, order, animate)
		local row = New("Frame", {
			Size = UDim2.new(1, 0, 0, animate and 0 or playerRowHeight),
			BackgroundColor3 = Theme.Section,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ClipsDescendants = true,
			Parent = list,
			ThemeTag = { BackgroundColor3 = "Section" },
		})
		local rowConnections = {}
		row.Destroying:Once(function() disconnectBucket(rowConnections) end)
		Corner(row, 7)
		SetGroupTransparency(row, animate and 1 or 0)
		local rowStroke = Stroke(row, Theme.SectionBorder)

		local nameRow = New("Frame", {
			Size = UDim2.new(1, -112, 0, playerRowLineHeight),
			Position = UDim2.fromOffset(12, 6),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Parent = row,
		})

		local displayName = Label(nameRow, player.DisplayName, Theme.TextBright, playerTextSize, Theme.FontMedium)
		displayName.Position = UDim2.fromOffset(0, 0)
		displayName.Size = UDim2.fromScale(1, 1)
		displayName.TextTruncate = Enum.TextTruncate.AtEnd

		local username = Label(row, "@" .. player.Name, Theme.TextDim, math.max(playerTextSize - 1, 12))
		username.Position = UDim2.fromOffset(12, 4 + playerRowLineHeight)
		username.Size = UDim2.new(1, -112, 0, playerRowLineHeight)
		username.TextTruncate = Enum.TextTruncate.AtEnd

		local relationPill = New("Frame", {
			Size = UDim2.fromOffset(72, 20),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			BackgroundColor3 = Theme.Field,
			BorderSizePixel = 0,
			Parent = row,
			ThemeTag = { BackgroundColor3 = "Field" },
		})
		Corner(relationPill, 99)
		Stroke(relationPill, Theme.Border)
		local relation = Label(relationPill, "neutral", Theme.TextDim, math.max(playerTextSize - 1, 12), Theme.FontMedium)
		relation.Size = UDim2.fromScale(1, 1)
		relation.Position = UDim2.fromOffset(0, -1)
		relation.TextXAlignment = Enum.TextXAlignment.Center
		applyInspectorNativeFont(relation)
		paintRelation(player, relation)

		local hit = New("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 5,
			Parent = row,
		})
		connect(hit.MouseButton1Down, function()
			Tween(
				row,
				{ BackgroundColor3 = Theme.FieldHover },
				TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			)
		end, rowConnections)
		connect(hit.MouseButton1Up, function()
			refreshViewingIndicator()
		end, rowConnections)
		connect(hit.MouseEnter, function()
			if api.Selected ~= player then
				Tween(row, { BackgroundColor3 = Theme.FieldHover }, EASE_FAST)
			end
		end, rowConnections)
		connect(hit.MouseLeave, function()
			refreshViewingIndicator()
		end, rowConnections)
		connect(hit.Activated, function()
			refreshViewingIndicator()
			api:SelectPlayer(player)
		end, rowConnections)
		connect(hit.MouseButton2Click, function()
			if not IsInteractive(hit) or player.Parent ~= Players
				or (api.RemovingPlayers and api.RemovingPlayers[player]) then return end
			api:View(player)
		end, rowConnections)

		api.Rows[player] = {
			Player = player,
			Frame = row,
			Relation = relation,
			RowStroke = rowStroke,
			DisplayName = displayName,
			Username = username,
		}

		if animate then
			task.defer(function()
				if row.Parent and api.Rows[player] and api.Rows[player].Frame == row then
					TweenGroupTransparency(
						row,
						0,
						TweenInfo.new(0.18, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
					)
					api.Rows[player].SizeMotion = BezierTween(row, {
						Size = UDim2.new(1, 0, 0, playerRowHeight),
					}, 0.24, { 0.16, 1, 0.3, 1 })
				end
			end)
		end
	end

	local refreshGeneration = 0
	function api:Refresh(animate)
		refreshGeneration = refreshGeneration + 1
		local generation = refreshGeneration
		animate = animate == true

		local players = {}
		local present = {}
		for _, player in Players:GetPlayers() do
			if player ~= Players.LocalPlayer and not (self.RemovingPlayers and self.RemovingPlayers[player]) then
				table.insert(players, player)
				present[player] = true
			end
		end
		table.sort(players, function(a, b)
			return string.lower(a.DisplayName) < string.lower(b.DisplayName)
		end)

		if self.Selected and not present[self.Selected] and not self.SelectedLeft then
			self.Selected = nil
			cancelSelectedCardScroll()
		end

		self.ExitingRows = self.ExitingRows or {}
		local slots, orders = {}, {}
		for player, rowData in self.Rows do
			table.insert(slots, { Player = player, Data = rowData })
		end
		for rowData, player in self.ExitingRows do
			if rowData.Frame.Parent then
				table.insert(slots, { Player = player, Data = rowData, Exiting = true })
			else
				self.ExitingRows[rowData] = nil
			end
		end
		for _, player in players do
			if not self.Rows[player] then table.insert(slots, { Player = player }) end
		end
		table.sort(slots, function(a, b)
			local aName, bName = string.lower(a.Player.DisplayName), string.lower(b.Player.DisplayName)
			if aName ~= bName then return aName < bName end
			if a.Player.UserId ~= b.Player.UserId then return a.Player.UserId < b.Player.UserId end
			return a.Exiting == true and b.Exiting ~= true
		end)
		for index, slot in slots do
			if slot.Data then slot.Data.Frame.LayoutOrder = index end
			if not slot.Exiting and present[slot.Player] then orders[slot.Player] = index end
		end

		for player, rowData in self.Rows do
			if not present[player] then
				self.Rows[player] = nil
				local row = rowData.Frame
				if row and row.Parent then
					if rowData.SizeMotion then rowData.SizeMotion:Cancel() end
					if animate and row.Visible then
						self.ExitingRows[rowData] = player
						TweenGroupTransparency(
							row,
							1,
							TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
						)
						rowData.SizeMotion = BezierTween(
							row,
							{
								Size = UDim2.new(1, 0, 0, 0),
							},
							0.24,
							{ 0.22, 1, 0.36, 1 },
							function()
								self.ExitingRows[rowData] = nil
								if row.Parent then
									row:Destroy()
								end
							end
						)
					else
						row:Destroy()
					end
				end
			end
		end

		for index, player in players do
			local rowData = self.Rows[player]
			if not rowData then
				addPlayerRow(player, orders[player] or index, animate)
				rowData = self.Rows[player]
			else
				rowData.Frame.LayoutOrder = orders[player] or index
				if rowData.DisplayName then
					rowData.DisplayName.Text = player.DisplayName
				end
				if rowData.Username then
					rowData.Username.Text = "@" .. player.Name
				end
				if rowData.Relation then
					paintRelation(player, rowData.Relation)
				end
			end
		end

		self.PlayerCount = #players
		countLabel.Text = string.format("%d player%s", #players, #players == 1 and "" or "s")
		applyFilter()
		updateSelectedDetail()
		refreshViewingIndicator()
		refreshPlayerMenuLayout(self.Open and self.HostVisible)

		if animate then
			task.delay(0.26, function()
				if generation == refreshGeneration and gui.Parent then
					applyFilter()
					refreshPlayerMenuLayout(self.Open and self.HostVisible)
				end
			end)
		end
		return self
	end

	function api:SetVisible(state)
		state = state ~= false
		local actuallyVisible = self.Open and self.HostVisible and gui.Enabled and main.Visible
		if state == self.Open and state == actuallyVisible then
			return self
		end
		visibilityTicket = visibilityTicket + 1
		local ticket = visibilityTicket
		self.HostVisibilityTicket = (self.HostVisibilityTicket or 0) + 1
		cancelPlayerMenuVisibility()
		self.Open = state
		if not state then
			cancelSelectedCardScroll()
			RestoreCursorFromPlayerMenu()
		end
		local anchorWindow = self.AnchorWindow
		local dockHeight = getDockTargetHeight()
		if dockHeight then
			self.CurrentHeight = dockHeight
		end
		local fullSize = UDim2.fromOffset(width, self.CurrentHeight or height)

		if state then
			self.HostVisible = not anchorWindow or anchorWindow.Visible
			if anchorWindow then
				anchorWindow:SetPlayerDockVisible(true, self, anchorWindow.UserScale or anchorWindow.BaseScale)
				if anchorWindow.Refit then
					anchorWindow:Refit()
				end
			end

			if self.HostVisible and self.AnchorWindow then
				connectDockSync(self)
			end

			Library:RefreshStandaloneScales()
			if self.HostVisible then
				gui.Enabled = true
				main.Size = fullSize
				task.defer(function()
					RunService.RenderStepped:Wait()
					if ticket ~= visibilityTicket or not self.Open or not self.HostVisible then
						return
					end
					if anchorWindow and anchorWindow.Main and anchorWindow.Main.Parent then
						ClampRenderedFrame(anchorWindow.Main)
						RunService.RenderStepped:Wait()
					end
					if ticket ~= visibilityTicket or not self.Open or not self.HostVisible then
						return
					end

					self:SyncToAnchor(true)
					RaiseLayerFrame(main)
					local fadeInfo = playerMenuFadeInfo(true)
					Fade(main, true, fadeInfo)

					local window = self.AnchorWindow
					self:SetModalDimmed(window ~= nil and window.SharedDimmerTarget ~= nil, 0.78)
				end)
			else
				main.Size = fullSize
				gui.Enabled = false
			end
		else
			self:SetModalDimmed(false, 0.78)
			self.HostVisible = false
			disconnectDockSync(self)
			if anchorWindow then
				anchorWindow:SetPlayerDockVisible(false, self)
				if anchorWindow.Refit then
					anchorWindow:Refit()
				end
			end

			if main.Visible then
				local info = playerMenuFadeInfo(false)

				Fade(main, false, info, function()
					if ticket == visibilityTicket and not self.Open then
						gui.Enabled = false
						main.Visible = false
						main.Size = fullSize
					end
				end)
			else
				gui.Enabled = false
				main.Size = fullSize
			end
		end
		Library:RefreshCursor()
		Library:RefreshHotkeys()
		return self
	end

	function api:SetHostVisible(state, info)
		state = state ~= false
		self.HostVisibilityTicket = (self.HostVisibilityTicket or 0) + 1
		local hostTicket = self.HostVisibilityTicket
		visibilityTicket = visibilityTicket + 1
		cancelPlayerMenuVisibility()
		self.HostVisible = state
		if not state then
			RestoreCursorFromPlayerMenu()
		end
		if not self.Open then
			gui.Enabled = false
			return self
		end

		if state then
			gui.Enabled = true
			if self.AnchorWindow then
				connectDockSync(self)
			end
			local ticket = visibilityTicket
			task.defer(function()
				RunService.RenderStepped:Wait()
				if
					hostTicket ~= self.HostVisibilityTicket
					or ticket ~= visibilityTicket
					or not self.Open
					or not self.HostVisible
				then
					return
				end
				local anchor = self.AnchorWindow and self.AnchorWindow.Main
				if anchor and anchor.Parent then
					ClampRenderedFrame(anchor)
					RunService.RenderStepped:Wait()
				end
				if
					hostTicket ~= self.HostVisibilityTicket
					or ticket ~= visibilityTicket
					or not self.Open
					or not self.HostVisible
				then
					return
				end
				self:SyncToAnchor(true)
				local fadeInfo = info or playerMenuFadeInfo(true)
				Fade(main, true, fadeInfo)

				local window = self.AnchorWindow
				self:SetModalDimmed(window ~= nil and window.SharedDimmerTarget ~= nil, 0.78)
			end)
		else
			disconnectDockSync(self)
			self:SetModalDimmed(false, 0.78)
			local ticket = visibilityTicket
			local fadeInfo = info or playerMenuFadeInfo(false)

			Fade(main, false, fadeInfo, function()
				if ticket == visibilityTicket and hostTicket == self.HostVisibilityTicket
					and self.Open and not self.HostVisible then
					gui.Enabled = false
					main.Visible = false
				end
			end)
		end
		return self
	end

	function api:Toggle()
		return self:SetVisible(not self.Open)
	end

	function api:Destroy()
		cancelSelectedCardScroll()
		visibilityTicket = visibilityTicket + 1
		self.HostVisibilityTicket = (self.HostVisibilityTicket or 0) + 1
		self.Open = false
		cancelPlayerMenuVisibility()
		RestoreCursorFromPlayerMenu()
		self.ViewEnabled = false
		self.ViewSession = (self.ViewSession or 0) + 1
		self.CameraRestoreTicket = (self.CameraRestoreTicket or 0) + 1
		if self.AnchorWindow then
			self.AnchorWindow:SetPlayerDockVisible(false, self)
			if self.AnchorWindow.Refit then
				self.AnchorWindow:Refit()
			end
		end
		disconnectDockSync(self)
		if self.ModalDimTween then
			self.ModalDimTween:Cancel()
			self.ModalDimTween = nil
		end
		if self.ViewOriginal and workspace.CurrentCamera then
			restoreLocalCamera(self, workspace.CurrentCamera, self.ViewOriginal)
		end
		destroyViewProxy(self)
		destroyLocalViewMarker(self)
		self.ViewOriginal = nil
		self.Viewing = nil
		disconnectBucket(self.RowConnections)
		disconnectBucket(self.Connections)
		if gui.Parent then
			gui:Destroy()
		end
		if Library.PlayerMenuApi == self then
			Library.PlayerMenuApi = nil
		end
		Library:RefreshCursor()
	end

	connect(searchBox.Focused, function()
		Tween(searchStroke, { Color = Theme.Accent }, EASE_FAST)
	end)
	connect(searchBox.FocusLost, function()
		Tween(searchStroke, { Color = Theme.Border }, EASE_FAST)
	end)
	connect(searchBox:GetPropertyChangedSignal("Text"), function()
		applyFilter()
	end)
	connect(closeBtn.Activated, function()
		api:SetVisible(false)
	end)
	connect(closeBtn.MouseEnter, function()
		for _, bar in closeBars do
			Tween(bar, { BackgroundColor3 = Theme.Danger }, EASE_FAST)
		end
	end)
	connect(closeBtn.MouseLeave, function()
		for _, bar in closeBars do
			Tween(bar, { BackgroundColor3 = Theme.TextDim }, EASE_FAST)
		end
	end)
	connect(Players.PlayerAdded, function(player)
		if api.RemovingPlayers then
			api.RemovingPlayers[player] = nil
		end

		local selected = api.Selected
		if api.SelectedLeft and selected and selected.UserId == player.UserId then
			api.Selected = player
			api.SelectedLeft = false
			setDetailLeftPill(false, true)
			setSelectedPlayerAvailable(true)
			updateSelectedDetail()
			refreshViewingIndicator(true)
		end

		api:Refresh(true)
	end)
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		connect(localPlayer.CharacterAdded, function(character)
			if not api.Viewing or api.ViewReturning then
				return
			end
			task.spawn(function()
				local root = character:WaitForChild("HumanoidRootPart", 5)
				if root and api.Viewing and not api.ViewReturning then
					refreshLocalViewMarker(api)
				end
			end)
		end)
	end

	connect(Players.PlayerRemoving, function(player)
		api.RemovingPlayers = api.RemovingPlayers or {}
		api.RemovingPlayers[player] = true
		if api.Selected == player then
			api.SelectedLeft = true
			setDetailLeftPill(true, true)
			setSelectedPlayerAvailable(false)
		end
		if api.Viewing == player then
			api:StopViewing()
		end
		task.defer(function()
			if gui.Parent then
				api:Refresh(true)
			end
		end)
	end)

	api.DragController = AttachSmoothFrameDrag(main, topBar, nil, function()
		return api.AnchorWindow == nil
	end)
	api.DragController:SetEnabled(api.AnchorWindow == nil)

	self.PlayerMenuApi = api
	api:Refresh()
	if opts.Visible == true then
		api:SetVisible(true)
	end
	return api
end

Library.CreatePlayerMenu = Library.PlayerMenu

function Library:OpenPlayerMenu(opts)
	local menu = self:PlayerMenu(opts)
	menu:SetVisible(true)
	return menu
end

function Window:PlayerMenu(opts)
	return Library:PlayerMenu(opts)
end

function Window:OpenPlayerMenu(opts)
	return Library:OpenPlayerMenu(opts)
end

function Library:ServerBrowser(opts)
	if self.ServerBrowserApi then
		return self.ServerBrowserApi
	end
	opts = opts or {}

	local player = Players.LocalPlayer
	local placeId = opts.PlaceId or game.PlaceId

	local gui = New("ScreenGui", {
		Name = RandomName(),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		AutoLocalize = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = MAX_DISPLAY_ORDER - 2,
		Enabled = false,
	})
	ParentGui(gui)

	local main = New("Frame", {
		Visible = false,
		Size = UDim2.fromOffset(opts.Width or 340, opts.Height or 420),
		AnchorPoint = opts.Position and Vector2.new(0, 0) or Vector2.new(0.5, 0.5),
		Position = opts.Position or UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		Active = true,
		Parent = gui,
		ThemeTag = { BackgroundColor3 = "Window" },
	})
	Corner(main, 10)
	Stroke(main, Theme.WindowBorder)
	local serverScale = New("UIScale", { Scale = 1, Parent = main })
	local serverBaseScale = 1

	local topBar = New("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.TopBar,
		BorderSizePixel = 0,
		Parent = main,
		ThemeTag = { BackgroundColor3 = "TopBar" },
	})
	Corner(topBar, 10)
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.fromOffset(0, 28),
		BackgroundColor3 = Theme.TopBar,
		BorderSizePixel = 0,
		Parent = topBar,
		ThemeTag = { BackgroundColor3 = "TopBar" },
	})
	New("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 39),
		BackgroundColor3 = Theme.BorderSoft,
		BorderSizePixel = 0,
		Parent = topBar,
		ThemeTag = { BackgroundColor3 = "BorderSoft" },
	})

	local heading = Label(topBar, opts.Title or "servers", Theme.TextBright, Theme.TextSize + 1, Theme.FontMedium)
	heading.Position = UDim2.fromOffset(14, 0)
	heading.Size = UDim2.new(1, -90, 1, 0)

	local statusLabel = Label(topBar, "", Theme.TextDim, 11)
	statusLabel.AnchorPoint = Vector2.new(1, 0.5)
	statusLabel.Position = UDim2.new(1, -66, 0.5, 0)
	statusLabel.Size = UDim2.fromOffset(120, 14)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right

	local refreshBtn = New("TextButton", {
		Size = UDim2.fromOffset(22, 22),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -38, 0.5, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = topBar,
	})
	local refreshIcon = AttachIcon(refreshBtn, "refresh-cw", Theme.TextDim, 15)
	if refreshIcon then
		refreshIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		refreshIcon.Position = UDim2.fromScale(0.5, 0.5)
	end

	local closeBtn = New("TextButton", {
		Size = UDim2.fromOffset(22, 22),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = topBar,
	})
	local closeBars = {}
	for i = 1, 2 do
		local bar = New("Frame", {
			Size = UDim2.fromOffset(13, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = i == 1 and 45 or -45,
			BackgroundColor3 = Theme.TextDim,
			BorderSizePixel = 0,
			Parent = closeBtn,
			ThemeTag = { BackgroundColor3 = "TextDim" },
		})
		Corner(bar, 1)
		closeBars[i] = bar
	end

	local list = New("ScrollingFrame", {
		Size = UDim2.new(1, -20, 1, -54),
		Position = UDim2.fromOffset(10, 48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = Theme.AccentDim,
		ScrollBarImageTransparency = 0.3,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		ZIndex = 211,
		Parent = main,
		ThemeTag = { ScrollBarImageColor3 = "AccentDim" },
	})
	List(list, 6)
	Pad(list, 2, 8, 2, 2)

	local explicitToggleBinding = opts.Toggle ~= nil
		or opts.ToggleControl ~= nil
		or opts.ToggleFlag ~= nil
		or opts.Flag ~= nil
	local api = {
		Gui = gui,
		Frame = main,
		Open = false,
		BoundToggle = opts.Toggle or opts.ToggleControl,
		ToggleFlag = opts.ToggleFlag or opts.Flag or "server browser",
		AnchorWindow = opts.AnchorWindow,
		AnchorConnection = nil,
		ModalRoot = nil,
	}

	local function syncToAnchor()
		local window = api.AnchorWindow or Library.Windows[1]
		local anchor = window and window.Main

		if not anchor or not anchor.Parent then
			if main.Parent ~= gui then
				main.Parent = gui
			end
			main.AnchorPoint = Vector2.new(0.5, 0.5)
			main.Position = UDim2.fromScale(0.5, 0.5)
			return
		end

		api.AnchorWindow = window

		if not api.ModalRoot or not api.ModalRoot.Parent then
			local root = New("Frame", {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				Visible = false,
				ZIndex = 270,
				Parent = anchor,
			})

			api.ModalRoot = root
		end

		if api.ModalRoot.Parent ~= anchor then
			api.ModalRoot.Parent = anchor
		end

		if main.Parent ~= api.ModalRoot then
			main.Parent = api.ModalRoot
		end

		main.AnchorPoint = Vector2.new(0.5, 0.5)
		main.Position = UDim2.fromScale(0.5, 0.5)
		main.ZIndex = 280
	end

	function api:SetAnchorWindow(window)
		self.AnchorWindow = window
		syncToAnchor()
		return self
	end

	local function normalizedToggleName(value)
		return string.lower(tostring(value or "")):gsub("[^%w]", "")
	end

	local function resolveBoundToggle()
		local candidate = api.BoundToggle
		if type(candidate) == "string" then
			local entry = Library.Registry[candidate]
			candidate = entry and entry.Api or nil
		end
		if type(candidate) == "table" and type(candidate.Set) == "function" then
			return candidate
		end

		local wanted = normalizedToggleName(api.ToggleFlag or "server browser")
		for flag, entry in Library.Registry do
			if type(entry) == "table" and entry.Type == "Toggle" and entry.Api then
				if normalizedToggleName(flag) == wanted then
					api.BoundToggle = entry.Api
					return entry.Api
				end
			end
		end

		if not explicitToggleBinding then
			local recent = Library.LastToggleInteraction
			if
				recent
				and type(recent.Api) == "table"
				and type(recent.Api.Set) == "function"
				and recent.State == true
				and os.clock() - (recent.At or 0) <= 2
			then
				api.BoundToggle = recent.Api
				if recent.Flag then
					api.ToggleFlag = recent.Flag
				end
				return recent.Api
			end
		end
		return nil
	end

	local function syncBoundToggle(state)
		local toggle = resolveBoundToggle()
		if toggle and toggle.State ~= state then
			toggle:Set(state, true)
		end
	end

	function api:BindToggle(toggleOrFlag)
		if type(toggleOrFlag) == "string" then
			self.ToggleFlag = toggleOrFlag
			self.BoundToggle = nil
		else
			self.BoundToggle = toggleOrFlag
		end
		syncBoundToggle(self.Open)
		return self
	end

	local loading = false
	local latestServers = {}

	local function clearRows()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	local function addRow(server, index)
		local row = New("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Theme.Section,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = list,
			ThemeTag = { BackgroundColor3 = "Section" },
		})
		Corner(row, 6)
		Stroke(row, Theme.SectionBorder)

		local players =
			Label(row, string.format("%d / %d players", server.playing or 0, server.maxPlayers or 0), Theme.TextBright)
		players.Position = UDim2.fromOffset(12, 6)
		players.Size = UDim2.new(1, -90, 0, 16)

		local ping = server.ping or 0
		local pingColor = Theme.TextCode
		if ping > 150 then
			pingColor = Theme.Danger
		elseif ping > 80 then
			pingColor = Theme.TextMarked
		end

		local meta =
			Label(row, string.format("%d ms  -  %d fps", math.floor(ping), math.floor(server.fps or 0)), pingColor, 14)
		meta.Position = UDim2.fromOffset(12, 23)
		meta.Size = UDim2.new(1, -90, 0, 18)

		local joinFrame = New("Frame", {
			Size = UDim2.fromOffset(62, 26),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			BackgroundColor3 = Theme.Highlight,
			BorderSizePixel = 0,
			Parent = row,
			ThemeTag = { BackgroundColor3 = "Highlight" },
		})
		Corner(joinFrame, 6)

		local joinBtn = New("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "join",
			TextColor3 = Color3.fromRGB(40, 32, 34),
			TextSize = Theme.TextSize,
			Font = Theme.FontMedium,
			Parent = joinFrame,
		})

		Track(joinBtn.Activated:Connect(function()
			Library:Notify(opts.Title or "servers", "teleporting...", 3)

			if opts.OnJoin then
				Library:SafeCallback("server browser", opts.OnJoin, server.id, placeId, server)
				return
			end

			local ok, err = pcall(function()
				TeleportService:TeleportToPlaceInstance(placeId, server.id, player)
			end)

			if not ok then
				Library:Error(opts.Title or "servers", tostring(err), 6)
			end
		end))
	end

	local function refresh()
		if loading then
			return
		end
		loading = true
		statusLabel.Text = "loading..."
		clearRows()

		task.spawn(function()
			local ok, result = pcall(function()
				local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
				return HttpService:JSONDecode(game:HttpGet(url))
			end)

			if not ok or type(result) ~= "table" or type(result.data) ~= "table" then
				statusLabel.Text = "request failed"
				loading = false
				return
			end

			local servers = {}
			for _, srv in result.data do
				if not (placeId == game.PlaceId and srv.id == game.JobId) then
					table.insert(servers, srv)
				end
			end

			table.sort(servers, function(a, b)
				return (a.ping or 999) < (b.ping or 999)
			end)

			latestServers = servers

			local shown = 0
			for _, srv in servers do
				shown = shown + 1
				addRow(srv, shown)
				if shown >= (opts.MaxRows or 40) then
					break
				end
			end

			statusLabel.Text = shown .. " servers"
			loading = false
		end)
	end

	local function serverHop()
		local servers = latestServers

		if #servers == 0 then
			local ok, result = pcall(function()
				local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
				return HttpService:JSONDecode(game:HttpGet(url))
			end)

			if ok and type(result) == "table" and type(result.data) == "table" then
				servers = {}
				for _, server in result.data do
					if not (placeId == game.PlaceId and server.id == game.JobId) then
						servers[#servers + 1] = server
					end
				end
				table.sort(servers, function(a, b)
					return (a.ping or 999) < (b.ping or 999)
				end)
				latestServers = servers
			end
		end

		local candidate
		for _, server in servers do
			local playing = tonumber(server.playing) or 0
			local maxPlayers = tonumber(server.maxPlayers) or 0
			if server.id and server.id ~= game.JobId and (maxPlayers <= 0 or playing < maxPlayers) then
				candidate = server
				break
			end
		end

		if not candidate then
			Library:Notify(opts.Title or "servers", "no available server found", 3)
			return
		end

		Library:Notify(opts.Title or "servers", "server hopping...", 3)
		local ok, err = pcall(function()
			TeleportService:TeleportToPlaceInstance(placeId, candidate.id, player)
		end)
		if not ok then
			Library:Error(opts.Title or "servers", tostring(err), 6)
		end
	end

	local function rejoin()
		Library:Notify(opts.Title or "servers", "rejoining...", 3)
		local ok, err = pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
		end)
		if not ok then
			Library:Error(opts.Title or "servers", tostring(err), 6)
		end
	end

	function api:ServerHop()
		serverHop()
		return self
	end

	function api:Rejoin()
		rejoin()
		return self
	end

	Track(refreshBtn.Activated:Connect(refresh))
	Track(refreshBtn.MouseEnter:Connect(function()
		if refreshIcon then
			Tween(refreshIcon, { ImageColor3 = Theme.Highlight }, EASE_FAST)
		end
	end))
	Track(refreshBtn.MouseLeave:Connect(function()
		if refreshIcon then
			Tween(refreshIcon, { ImageColor3 = Theme.TextDim }, EASE_FAST)
		end
	end))

	Track(closeBtn.Activated:Connect(function()
		syncBoundToggle(false)
		api:SetVisible(false)
	end))
	Track(closeBtn.MouseEnter:Connect(function()
		for _, bar in closeBars do
			Tween(bar, { BackgroundColor3 = Theme.Danger }, EASE_FAST)
		end
	end))
	Track(closeBtn.MouseLeave:Connect(function()
		for _, bar in closeBars do
			Tween(bar, { BackgroundColor3 = Theme.TextDim }, EASE_FAST)
		end
	end))

	Track(UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and not BindingInputBlocked(input) and api.Open and input.KeyCode == Enum.KeyCode.Escape then
			api:SetVisible(false)
		end
	end))

	function api:SetVisible(state)
		state = state ~= false
		local actuallyVisible = self.Open and gui.Enabled and main.Visible

		if state == self.Open and state == actuallyVisible then
			syncBoundToggle(state)
			return self
		end

		self.Open = state
		syncBoundToggle(state)
		Library:RefreshStandaloneScales()

		local baseScale = serverBaseScale
		local info = AnimationInfo("Modal", not state)
		local motionInfo = state and TweenInfo.new(info.Time, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
			or info

		if state then
			syncToAnchor()
			gui.Enabled = true

			if self.AnchorWindow and self.AnchorWindow.SetSharedDimmer then
				self.AnchorWindow:SetSharedDimmer(self, true, 0.78)
			end

			if self.ModalRoot then
				self.ModalRoot.Visible = true
			end

			main.Visible = true
			serverScale.Scale = serverBaseScale * 0.965
			Tween(serverScale, { Scale = serverBaseScale }, motionInfo)

			if self.ModalRoot then
				Fade(self.ModalRoot, true, info)
			else
				Fade(main, true, info)
			end
		else
			if self.AnchorWindow and self.AnchorWindow.SetSharedDimmer then
				self.AnchorWindow:SetSharedDimmer(self, false, 0.78)
			end

			Tween(serverScale, { Scale = serverBaseScale * 0.965 }, motionInfo)

			if self.ModalRoot then
				Fade(self.ModalRoot, false, info, function()
					if not self.Open then
						self.ModalRoot.Visible = false
						serverScale.Scale = serverBaseScale
					end
				end)
			else
				Fade(main, false, info, function()
					if not self.Open then
						gui.Enabled = false
						serverScale.Scale = serverBaseScale
					end
				end)
			end
		end

		if self.Open and #list:GetChildren() <= 2 then
			refresh()
		end

		return self
	end

	function api:Toggle()
		local actuallyVisible = self.Open and gui.Enabled and main.Visible

		if self.Open and not actuallyVisible then
			self.Open = false
		end

		self:SetVisible(not actuallyVisible)
	end

	function api:Refresh()
		refresh()
	end

	self.ServerBrowserApi = api
	return api
end

function Library:ToggleUI(state)
	if state == nil then
		state = not self.Open
	end
	self.Open = state
	for _, window in self.Windows do
		window:SetVisible(state)
	end
	self:RefreshHotkeys()
	self:RefreshCursor()
	return self.Open
end

function Library:CreateMobileButton(opts)
	if self.MobileGui then
		return self.MobileButton
	end
	opts = opts or {}

	local gui = New("ScreenGui", {
		Name = RandomName(),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		AutoLocalize = false,
		DisplayOrder = MAX_DISPLAY_ORDER,
	})
	ParentGui(gui)

	local button = New("TextButton", {
		Size = UDim2.fromOffset(opts.Size or 44, opts.Size or 44),
		Position = opts.Position or UDim2.new(0, 18, 0.5, -22),
		BackgroundColor3 = Theme.Section,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = gui,
		ThemeTag = { BackgroundColor3 = "Section" },
	})
	Corner(button, 12)
	Stroke(button, Theme.Border)
	for i = 1, 3 do
		local bar = New("Frame", {
			Size = UDim2.fromOffset(18, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, (i - 2) * 6),
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Parent = button,
			ThemeTag = { BackgroundColor3 = "Accent" },
		})
		Corner(bar, 1)
	end

	local moved, origin, startPos, moveConn, endConn
	local pressing = false
	local lastToggle = 0

	Track(button.InputBegan:Connect(function(input)
		if not IsInteractive(button) then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		if pressing then
			return
		end
		pressing = true

		moved = false
		origin = input.Position
		startPos = button.Position
		Tween(button, { BackgroundColor3 = Theme.FieldHover }, EASE_FAST)

		moveConn = UserInputService.InputChanged:Connect(function(move)
			if
				move.UserInputType ~= Enum.UserInputType.MouseMovement
				and move.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local delta = move.Position - origin
			if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then
				moved = true
			end
			button.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end)

		endConn = UserInputService.InputEnded:Connect(function(ended)
			if
				ended.UserInputType ~= Enum.UserInputType.MouseButton1
				and ended.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			if moveConn then
				moveConn:Disconnect()
				moveConn = nil
			end
			if endConn then
				endConn:Disconnect()
				endConn = nil
			end
			pressing = false
			Tween(button, { BackgroundColor3 = Theme.Section }, EASE_FAST)

			if not moved and (tick() - lastToggle) > 0.25 then
				lastToggle = tick()
				Library:ToggleUI()
			end
		end)
	end))

	self.MobileGui = gui
	self.MobileButton = button
	return button
end

function Library:SetMobileButtonVisible(state)
	if not self.MobileGui then
		if not state then
			return
		end
		self:CreateMobileButton()
	end
	self.MobileGui.Enabled = state and true or false
end

function Library:Mobile(opts)
	if type(opts) == "boolean" then
		self:SetMobileButtonVisible(opts)
		return self.MobileButton
	end

	opts = opts or {}
	local button = self:CreateMobileButton(opts)
	self:SetMobileButtonVisible(opts.Visible ~= false)
	return button
end

Track(UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe or BindingInputBlocked(input) then
		return
	end
	local hit = (Library.ToggleKey ~= nil and input.KeyCode == Library.ToggleKey)
		or (Library.ToggleInput ~= nil and input.UserInputType == Library.ToggleInput)
	if hit then
		Library:ToggleUI()
	end
end))

function Library:OnUnload(callback)
	if type(callback) ~= "function" then
		return nil
	end

	table.insert(self.UnloadCallbacks, callback)
	return callback
end

function Library:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	for _, key in { "__layer_active_ui", "layer.app", "layer" } do
		if rawget(UIEnvironment, key) == self then
			UIEnvironment[key] = nil
		end
	end
	local callbacks = self.UnloadCallbacks
	self.UnloadCallbacks = {}

	for i = #callbacks, 1, -1 do
		pcall(callbacks[i])
	end

	self:_ClearTransientFeedback()
	ClearAnimations()
	for _, conn in self.Connections do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(self.Connections)
	for _, w in self.Windows do
		if w.DragController then
			w.DragController:Cancel()
		end
		w.Gui:Destroy()
	end
	table.clear(self.Windows)
	if self.PlayerMenuApi then
		pcall(function()
			self.PlayerMenuApi:Destroy()
		end)
		self.PlayerMenuApi = nil
	end
	if self.NotifyGui then
		self.NotifyGui:Destroy()
		self.NotifyGui = nil
		self.NotifyScale = nil
	end
	if self.ActiveNotifications then
		table.clear(self.ActiveNotifications)
	end
	if self.MainMenuBlurTween then
		self.MainMenuBlurTween:Cancel()
		self.MainMenuBlurTween = nil
	end
	if self.MainMenuBlur then
		self.MainMenuBlur:Destroy()
		self.MainMenuBlur = nil
	end
	if self.DraggableFrames then
		table.clear(self.DraggableFrames)
	end
	if self.MobileGui then
		self.MobileGui:Destroy()
		self.MobileGui = nil
		self.MobileButton = nil
	end
	if self.CursorConnection then
		self.CursorConnection:Disconnect()
		self.CursorConnection = nil
	end
	if self.CursorNativeLock then
		self.CursorNativeLock:Disconnect()
		self.CursorNativeLock = nil
	end
	self:_ReleaseCursorOverride()
	for _, connection in self.CursorFocusConnections or {} do connection:Disconnect() end
	self.CursorFocusConnections = nil
	self.CursorBind = nil
	self.CursorBindName = nil
	self.CursorFollow = nil
	if self.CursorGui then
		self.CursorGui:Destroy()
		self.CursorGui = nil
		self.CursorHolder = nil
	end
	if self.ServerBrowserApi then
		pcall(function()
			if self.ServerBrowserApi.AnchorConnection then
				self.ServerBrowserApi.AnchorConnection:Disconnect()
				self.ServerBrowserApi.AnchorConnection = nil
			end
			if self.ServerBrowserApi.ModalRoot then
				self.ServerBrowserApi.ModalRoot:Destroy()
				self.ServerBrowserApi.ModalRoot = nil
			end
			self.ServerBrowserApi.Gui:Destroy()
		end)
		self.ServerBrowserApi = nil
	end
	if self.HotkeyGui then
		self.HotkeyGui:Destroy()
		self.HotkeyGui = nil
		self.HotkeyPanel = nil
		self.HotkeyStroke = nil
		self.HotkeyScale = nil
		self.HotkeyPanelWidth = nil
	end
	if self.WatermarkGui then
		self:StopWatermarkUpdates()
		self.WatermarkGui:Destroy()
		self.WatermarkGui = nil
		self.WatermarkPanel = nil
		self.WatermarkText = nil
		self.WatermarkContent = nil
		self.WatermarkLabels = nil
		self.WatermarkFpsSlotWidth = nil
		self.WatermarkPingSlotWidth = nil
		self.WatermarkStroke = nil
		self.WatermarkAccent = nil
		self.WatermarkObject = nil
		self.WatermarkDragController = nil
		self.WatermarkEnabled = false
	end
	for index = #self.Panels, 1, -1 do
		pcall(function()
			self.Panels[index].Gui:Destroy()
		end)
		self.Panels[index] = nil
	end
	table.clear(self.HotkeyEntries)
	table.clear(self.Registry)
	table.clear(self.Flags)
end

local FileSystem = {}
FileSystem.Memory = {}
FileSystem.Native = typeof(writefile) == "function" and typeof(readfile) == "function"

function FileSystem:MakeFolder(path)
	if not self.Native then
		return
	end
	if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
		local ok, exists = pcall(isfolder, path)
		if ok and not exists then
			pcall(makefolder, path)
		end
	end
end

function FileSystem:Write(path, text)
	if self.Native and pcall(writefile, path, text) then
		self.Memory[path] = nil
		return true
	end
	self.Memory[path] = text
	return true
end

function FileSystem:Read(path)
	if self.Native and typeof(isfile) == "function" then
		local ok, exists = pcall(isfile, path)
		if ok and exists then
			local read, data = pcall(readfile, path)
			if read then
				return data
			end
		end
	end
	return self.Memory[path]
end

function FileSystem:Delete(path)
	if self.Native and typeof(delfile) == "function" then
		pcall(delfile, path)
	end
	self.Memory[path] = nil
end

function FileSystem:List(folder)
	local names, seen = {}, {}
	if self.Native and typeof(listfiles) == "function" then
		local ok, files = pcall(listfiles, folder)
		if ok and files then
			for _, full in files do
				local name = string.match(full, "[^/\\]+$")
				if name and not seen[name] then
					seen[name] = true
					table.insert(names, name)
				end
			end
		end
	end
	for path in self.Memory do
		if string.sub(path, 1, #folder + 1) == folder .. "/" then
			local name = string.match(path, "[^/\\]+$")
			if name and not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
	end
	table.sort(names)
	return names
end

function Library:BuildFolders(folder)
	local path = ""
	for _, part in string.split(folder, "/") do
		path = path == "" and part or (path .. "/" .. part)
		FileSystem:MakeFolder(path)
	end
	FileSystem:MakeFolder(folder .. "/configs")
	FileSystem:MakeFolder(folder .. "/settings")
	return folder
end

Library.FileSystem = FileSystem

UIEnvironment.__layer_active_ui = Library
UIEnvironment["layer.app"] = Library
UIEnvironment.layer = Library
Library.SaveManager = Library:LoadAddon("SaveManager")
Library.InterfaceManager = Library:LoadAddon("InterfaceManager")
Library.ThemeManager = Library:LoadAddon("ThemeManager")

local function WrapThemeMethod(methodName)
	if type(Library.ThemeManager) ~= "table" then
		return
	end
	local original = Library.ThemeManager[methodName]
	if type(original) ~= "function" or Library.ThemeManager["__layer_wrapped_" .. methodName] then
		return
	end
	Library.ThemeManager["__layer_wrapped_" .. methodName] = true
	Library.ThemeManager[methodName] = function(self, themeName, ...)
		local ok, result = pcall(original, self, themeName, ...)
		if ok and result ~= false and type(themeName) == "string" and themeName ~= "" then
			Library.CurrentThemeName = themeName
			self.Current = themeName
			task.defer(function()
				local detected = Library:DetectThemePresetName() or themeName
				Library:SyncThemePresetControl(detected)
			end)
		end
		if not ok then
			error(result)
		end
		return result
	end
end

WrapThemeMethod("Apply")
WrapThemeMethod("ApplyTheme")
WrapThemeMethod("SetTheme")
WrapThemeMethod("LoadTheme")
Library:EnsureSystemConfigEntries()

function Library:InstallBuiltInThemePresets(manager)
	manager = manager or self.ThemeManager
	if type(manager) ~= "table" or type(manager.Presets) ~= "table" then
		return manager
	end

	local extraThemes = {
		oled = { Bg = Color3.fromRGB(0, 0, 0), Accent = Color3.fromRGB(255,255,255) },
		sirmeme = {
			Bg = Color3.fromRGB(0, 0, 0), Accent = Color3.fromRGB(64, 255, 0),
			Highlight = Color3.fromRGB(230, 48, 210),
			Colors = {
				TopBar = Color3.fromRGB(7, 7, 7),
				Field = Color3.fromRGB(15, 15, 17),
				FieldHover = Color3.fromRGB(24, 24, 26),
				TextMarked = Color3.fromRGB(230, 48, 210),
				TextCode = Color3.fromRGB(64, 255, 0),
			},
		},
		cobalt = {
			Bg = Color3.fromRGB(10, 17, 34), Accent = Color3.fromRGB(92, 151, 255),
			Highlight = Color3.fromRGB(231, 155, 105),
			Colors = {
				Text = Color3.fromRGB(190, 204, 226), TextDim = Color3.fromRGB(126, 148, 179),
				TextBright = Color3.fromRGB(235, 243, 255),
			},
		},
		matcha = {
			Bg = Color3.fromRGB(25, 27, 23), Accent = Color3.fromRGB(172, 197, 128),
			Highlight = Color3.fromRGB(198, 166, 218),
			Colors = {
				Text = Color3.fromRGB(202, 207, 190), TextDim = Color3.fromRGB(139, 149, 125),
				TextBright = Color3.fromRGB(240, 241, 225),
			},
		},
		cherry = {
			Bg = Color3.fromRGB(24, 12, 19), Accent = Color3.fromRGB(244, 93, 122),
			Highlight = Color3.fromRGB(255, 185, 105),
			Colors = {
				Text = Color3.fromRGB(208, 190, 198), TextDim = Color3.fromRGB(153, 126, 139),
				TextBright = Color3.fromRGB(249, 235, 240),
			},
		},
		porcelain = {
			Bg = Color3.fromRGB(244, 237, 225), Accent = Color3.fromRGB(34, 107, 104),
			Highlight = Color3.fromRGB(167, 73, 48), Light = true,
			Colors = {
				Text = Color3.fromRGB(74, 67, 59), TextDim = Color3.fromRGB(119, 109, 96),
				TextBright = Color3.fromRGB(35, 42, 44),
			},
		},
		graphite = { Bg = Color3.fromRGB(20, 21, 24), Accent = Color3.fromRGB(128, 142, 164) },
		midnight = { Bg = Color3.fromRGB(13, 17, 27), Accent = Color3.fromRGB(95, 133, 214) },
		ocean = { Bg = Color3.fromRGB(12, 24, 29), Accent = Color3.fromRGB(65, 174, 190) },
		forest = { Bg = Color3.fromRGB(16, 25, 20), Accent = Color3.fromRGB(105, 176, 124) },
		ember = { Bg = Color3.fromRGB(28, 18, 16), Accent = Color3.fromRGB(220, 116, 82) },
		lavender = { Bg = Color3.fromRGB(24, 20, 31), Accent = Color3.fromRGB(166, 135, 216) },
		mocha = { Bg = Color3.fromRGB(29, 24, 22), Accent = Color3.fromRGB(190, 143, 112) },
		ice = { Bg = Color3.fromRGB(20, 25, 29), Accent = Color3.fromRGB(139, 190, 214) },
		aurora = { Bg = Color3.fromRGB(13, 24, 25), Accent = Color3.fromRGB(103, 209, 170) },
		sandstone = { Bg = Color3.fromRGB(29, 27, 23), Accent = Color3.fromRGB(203, 166, 104) },
	}

	manager.Order = manager.Order or {}
	local existing = {}
	for _, name in manager.Order do
		existing[name] = true
	end

	for _, name in {
		"oled",
		"sirmeme",
		"cherry",
		"porcelain",
		"cobalt",
		"matcha",
		"graphite",
		"midnight",
		"ocean",
		"forest",
		"ember",
		"lavender",
		"mocha",
		"ice",
		"aurora",
		"sandstone",
	} do
		if not existing[name] then
			table.insert(manager.Order, name)
			existing[name] = true
		end
		manager.Presets[name] = extraThemes[name]
	end

	return manager
end

Library:InstallBuiltInThemePresets(Library.ThemeManager)

if type(Library.ThemeManager) == "table" then
	local manager = Library.ThemeManager
	manager.__layer_original_names = manager.__layer_original_names or manager.Names

	manager.Names = function(self)
		local names = {}
		local seen = {}

		for _, name in self.Order or {} do
			if type(name) == "string" and self.Presets and self.Presets[name] and not seen[name] then
				table.insert(names, name)
				seen[name] = true
			end
		end

		local missing = {}
		for name in self.Presets or {} do
			if type(name) == "string" and not seen[name] then
				table.insert(missing, name)
			end
		end
		table.sort(missing)

		for _, name in missing do
			table.insert(names, name)
		end

		return names
	end
end

Library:OnRepaint(function()
	local detected = Library:DetectThemePresetName()
	if detected then
		Library:SyncThemePresetControl(detected)
	end

	if Library.DirtyBaseline and not Library.LoadingConfig then
		task.defer(function()
			if Library.DirtyBaseline and not Library.LoadingConfig then
				Library:RefreshDirty()
			end
		end)
	end
end)

return Library
