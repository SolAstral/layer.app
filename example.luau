-- UI-only showcase. See layer-ui-documentation.txt for source requirements.
-- The retrieved upstream init.luau has trailing text after return Library.
-- Use a repaired, reviewed source or a corrected upstream revision.
-- this example is fully ai generated btw
local UI_URL = "https://raw.githubusercontent.com/SolAstral/layer.app/refs/heads/main/init.luau"
local source = game:HttpGet(UI_URL)
local chunk, compileError = loadstring(source)
assert(chunk, "UI source failed to compile: " .. tostring(compileError))
local Library = chunk()

local SaveManager = assert(Library.SaveManager, "SaveManager addon unavailable")
local InterfaceManager = assert(Library.InterfaceManager, "InterfaceManager addon unavailable")
local ThemeManager = assert(Library.ThemeManager, "ThemeManager addon unavailable")

local Settings = {
	Enabled = false,
	Rate = 60,
	Name = "Demo",
	Quality = "Balanced",
	Layers = { "Labels" },
	Color = Color3.fromRGB(100, 180, 255),
	Alpha = 1,
}

local Window = Library:Window({
	Title = "UI demo",
	Suffix = ".app",
	Folder = "layer-ui-demo",
	Width = 800,
	Height = 550,
	TabStyle = "side",
	TabWidth = 150,
	Footer = true,
	DefaultTheme = "oled",
})

local Main = Window:Tab("controls", "settings")
local General = Main:Section("General", 1)
local Display = Main:Section("Display", 2)
local status = General:Label("Ready", { Wrap = true })

local enabled = General:Toggle({
	Text = "Preview enabled",
	Flag = "demo_enabled",
	Default = Settings.Enabled,
	Hint = "Updates the demo state.",
	Callback = function(value)
		Settings.Enabled = value
		status:Set(value and "Preview active" or "Preview inactive")
	end,
})
enabled:Keybind({ Flag = "demo_enabled_key", Default = "K", Mode = "toggle" })
enabled:Gear(function(panel)
	panel:Slider({
		Text = "Refresh rate", Flag = "demo_rate",
		Min = 1, Max = 240, Default = Settings.Rate,
		Step = 1, Decimals = 0, Suffix = " Hz",
		Callback = function(value) Settings.Rate = value end,
	})
	panel:Toggle({
		Text = "Show details", Flag = "demo_details", Default = false,
		Callback = function(value) print("Details", value) end,
	})
end)

General:Input({
	Text = "Display name", Flag = "demo_name",
	Default = Settings.Name, Placeholder = "Enter a name",
	Callback = function(text) Settings.Name = text end,
})
local quality = General:Dropdown({
	Text = "Quality", Flag = "demo_quality",
	Options = { "Fast", "Balanced", "Detailed" },
	Default = Settings.Quality, Search = true,
	Callback = function(value) Settings.Quality = value end,
})
Display:Dropdown({
	Text = "Visible layers", Flag = "demo_layers", Multi = true,
	Options = { "Labels", "Icons", "Outlines" }, Default = Settings.Layers,
	Callback = function(values) Settings.Layers = values end,
})
local color = Display:ColorPicker({
	Text = "Preview color", Flag = "demo_color",
	Default = Settings.Color, DefaultAlpha = Settings.Alpha,
	Callback = function(value, alpha)
		Settings.Color = value
		Settings.Alpha = alpha
	end,
})
Display:Slider({
	Text = "Scale", Flag = "demo_scale", Min = 0.5, Max = 2,
	Default = 1, Step = 0.1, Decimals = 1, Suffix = "x",
	Callback = function(value) print("Preview scale", value) end,
})
Display:Keybind({
	Text = "Preview action", Flag = "demo_action_key", Default = "P", Mode = "hold",
	Callback = function(active) print("Action active", active) end,
	OnChanged = function(key) print("Assigned key", key) end,
})
Display:Paragraph({ Title = "About this demo", Content = "Controls update local demo settings.", Style = "normal" })

local Widgets = Window:Tab("widgets", "boxes")
local Content = Widgets:Full("Content examples")
Content:Search({
	Label = "filter", Placeholder = "Type to update the label", Live = true,
	Callback = function(text) status:Set(text == "" and "Ready" or text) end,
})
local dataTable = Content:Table({
	Columns = { "Item", "Value" }, MaxRows = 4,
	Rows = { { "Refresh rate", Settings.Rate }, { "Quality", Settings.Quality } },
})
Content:ButtonRow({
	{ Text = "Refresh rows", Callback = function()
		dataTable:SetRows({ { "Refresh rate", Settings.Rate }, { "Quality", Settings.Quality } })
	end },
	{ Text = "Clear rows", Callback = function() dataTable:Clear() end },
})
Content:Split({
	function(left) left:Label("Left content") end,
	function(right) right:Label("Right content") end,
})
Content:Image({ UserId = game:GetService("Players").LocalPlayer.UserId, Height = 100 })

local modal = Window:Modal({ Title = "Demo dialog", Width = 320, Height = 220 })
modal.Content:Label("Add regular controls through modal.Content.", { Wrap = true })
modal.Content:Button({ Text = "Close", Callback = function() modal:SetOpen(false) end })
Content:Button({ Text = "Open dialog", Callback = function() modal:SetOpen(true) end })
Content:Button({ Text = "Confirm action", Callback = function()
	Window:Confirm({
		Title = "Reset demo toggle", Text = "Turn the preview off?",
		Confirm = "Reset", Cancel = "Keep",
		OnConfirm = function() enabled:Set(false) end,
	})
end })
Content:Button({ Text = "Show notification", Callback = function()
	Library:Notify({ Title = "Demo", Text = "Your action completed.", Style = "success", Duration = 3 })
	Library:MiniNotify({ Text = "Demo feedback", Duration = 2, Sound = false })
end })

local panel = Library:Panel({ Title = "Demo panel", Width = 200, Visible = false })
panel.Content:Label("Standalone content")
Content:Button({ Text = "Show panel", Callback = function() panel:SetVisible(true) end })
panel.Content:Button({ Text = "Hide", Callback = function() panel:SetVisible(false) end })

-- Examples of programmatic control updates.
quality:Set("Balanced", true)
color:Set(Settings.Color, Settings.Alpha, true)
-- Library:DamageNumber(25, Vector2.new(400, 300), { Color = Settings.Color })
-- Library:ServerBrowser():SetVisible(true)
-- Window:OpenPlayerMenu()

Library:Hotkeys({ Position = UDim2.new(0, 18, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Visible = false })
local watermark = Library:Watermark({ Name = "UI demo", Auto = true, Options = { "Game", "Fps", "Ping" } })
watermark:SetVisibility(true)

Window:TabDivider()
local SettingsTab = Window:Tab("settings", "cog")
SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
InterfaceManager:SetWindow(Window)
ThemeManager:SetLibrary(Library)
SaveManager:SetFolder("layer-ui-demo")
InterfaceManager:SetFolder("layer-ui-demo")
ThemeManager:SetFolder("layer-ui-demo")

-- Explicit ignore policy. Add flags here if they should stay out of configs.
SaveManager:SetIgnoreIndexes({})
InterfaceManager:BuildInterfaceSection(SettingsTab, 1)
ThemeManager:Mount(Window)
SaveManager:BuildConfigSection(SettingsTab, 2)

local demoConnection = game:GetService("Players").PlayerAdded:Connect(function(player)
	print("Player joined", player.Name)
end)
Library:OnUnload(function() demoConnection:Disconnect() end)

-- Keep this last so saved values override startup defaults.
SaveManager:LoadAutoloadConfig()
