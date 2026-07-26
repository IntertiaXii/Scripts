--!nocheck
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local HoverEnabled = true

local Int3UI = {}
Int3UI.__index = Int3UI
Int3UI.Name = "Int3UI"
Int3UI.Version = "2.0.0"

local ACTIVE_WINDOW_KEY = "__INT3_UI_WINDOW"
local ActiveTweens = setmetatable({}, { __mode = "k" })

local Theme = {
	Paper = Color3.fromRGB(218, 216, 198),
	PaperDark = Color3.fromRGB(190, 188, 174),
	PaperShadow = Color3.fromRGB(176, 174, 160),
	Ink = Color3.fromRGB(55, 54, 49),
	InkSoft = Color3.fromRGB(80, 79, 72),
	Line = Color3.fromRGB(176, 174, 160),
	Accent = Color3.fromRGB(246, 243, 209),
	White = Color3.fromRGB(218, 216, 200),
	Black = Color3.fromRGB(29, 29, 26),
}

local function create(className, properties)
	local object = Instance.new(className)
	for property, value in pairs(properties or {}) do
		if property ~= "Parent" then
			object[property] = value
		end
	end
	object.Parent = properties and properties.Parent or nil
	return object
end

local function corner(parent, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius or 2),
		Parent = parent,
	})
end

local function stroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color or Theme.Line,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		Parent = parent,
	})
end

local function padding(parent, left, right, top, bottom)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingTop = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		Parent = parent,
	})
end

local function tween(object, duration, properties, style, direction)
	local previous = ActiveTweens[object]
	if previous then previous:Cancel() end
	local ok, animation = pcall(
		TweenService.Create,
		TweenService,
		object,
		TweenInfo.new(duration or 0.16, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		properties
	)
	if not ok then
		for property, value in pairs(properties) do
			pcall(function() object[property] = value end)
		end
		return nil
	end
	ActiveTweens[object] = animation
	animation.Completed:Once(function()
		if ActiveTweens[object] == animation then ActiveTweens[object] = nil end
	end)
	animation:Play()
	return animation
end

local function invokeCallback(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	local ok, message = pcall(callback, ...)
	if not ok then
		warn("[Int3UI] callback error: " .. tostring(message))
	end
end

local function bindHover(gui, entered, left)
	if not HoverEnabled then return end
	gui.MouseEnter:Connect(entered)
	gui.MouseLeave:Connect(left)
end

local function addPaperPattern(parent, lowDetail)
	local pattern = create("Frame", {
		Name = "PaperPattern",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = parent,
	})

	for index = 0, lowDetail and 3 or 7 do
		create("Frame", {
			Name = "Diagonal",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Line,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			Position = UDim2.new(0.64, index * 24 - 40, 0.52, 0),
			Rotation = -36,
			Size = UDim2.new(0, 1, 0, 360),
			ZIndex = 1,
			Parent = pattern,
		})
	end

	for index = 1, lowDetail and 1 or 3 do
		local ring = create("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(1, 30, 1, 20),
			Size = UDim2.fromOffset(115 + index * 34, 115 + index * 34),
			ZIndex = 1,
			Parent = pattern,
		})
		corner(ring, 999)
		stroke(ring, Theme.Line, 1, 0.8)
	end

	for index = 0, lowDetail and 7 or 14 do
		create("Frame", {
			Name = "TopDash",
			BackgroundColor3 = index % 2 == 0 and Theme.Ink or Theme.Line,
			BackgroundTransparency = 0.68,
			BorderSizePixel = 0,
			Position = UDim2.new(0, index * 38 - 8, 0, 0),
			Rotation = index % 2 == 0 and 18 or -18,
			Size = UDim2.fromOffset(24, 1),
			ZIndex = 2,
			Parent = pattern,
		})
	end

	return pattern
end

local function attachDragBehavior(handle, target, window)
	local dragStart
	local startPosition

	table.insert(
		window.Connections,
		handle.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragStart = input.Position
				startPosition = target.Position
				window:CapturePointer(input, function(changedInput)
					local delta = changedInput.Position - dragStart
					target.Position = UDim2.new(
						startPosition.X.Scale,
						startPosition.X.Offset + delta.X,
						startPosition.Y.Scale,
						startPosition.Y.Offset + delta.Y
					)
				end)
			end
		end)
	)
end

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

function Window:CapturePointer(input, onMove, onEnd)
	if self.PointerCapture then self:ReleasePointer() end
	self.PointerCapture = { Input = input, Move = onMove, Finish = onEnd }
end

function Window:ReleasePointer(input)
	local capture = self.PointerCapture
	if not capture or (input and input ~= capture.Input) then return end
	self.PointerCapture = nil
	if capture.Finish then invokeCallback(capture.Finish) end
end

function Int3UI:CreateWindow(options)
	options = options or {}
	local camera = Workspace.CurrentCamera
	local initialViewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local touchPrimary = UserInputService.TouchEnabled
		and UserInputService.PreferredInput == Enum.PreferredInput.Touch
	local lowDetail = options.LowDetail
	if lowDetail == nil then
		lowDetail = touchPrimary or initialViewport.X < 700 or initialViewport.Y < 420
	end

	local environment = getgenv and getgenv() or _G
	local existing = environment[ACTIVE_WINDOW_KEY]
	if existing and existing.Destroy then
		pcall(existing.Destroy, existing)
	end

	local parent = CoreGui
	if gethui then
		local ok, result = pcall(gethui)
		if ok and result then
			parent = result
		end
	elseif LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") then
		parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end

	local screen = create("ScreenGui", {
		Name = options.Name or "Int3UI",
		DisplayOrder = options.DisplayOrder or 1000,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})

	local notificationHost = create("Frame", {
		Name = "NotificationHost",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -22, 1, -22),
		Size = UDim2.new(0, 560, 1, -44),
		ZIndex = 100,
		Parent = screen,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = notificationHost,
	})

	if syn and syn.protect_gui then
		pcall(syn.protect_gui, screen)
	end

	local shadow = create("Frame", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Black,
		BackgroundTransparency = 0.62,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 7, 0.5, 9),
		Size = options.Size or UDim2.fromOffset(790, 508),
		Visible = false,
		Parent = screen,
	})
	corner(shadow, 2)

	local root = create("CanvasGroup", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		GroupTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = options.Size or UDim2.fromOffset(790, 508),
		Parent = screen,
	})

	local scale = create("UIScale", {
		Scale = options.Scale or 1,
		Parent = root,
	})
	local shadowScale = create("UIScale", {
		Scale = options.Scale or 1,
		Parent = shadow,
	})

	local topbar = create("Frame", {
		Name = "Topbar",
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 34),
		ZIndex = 20,
		Parent = root,
	})

	local mark = create("Frame", {
		Name = "Mark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 17),
		Rotation = 45,
		Size = UDim2.fromOffset(12, 12),
		ZIndex = 21,
		Parent = topbar,
	})
	create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -108, 1, 0),
		Text = options.Title or "INT3 UI",
		TextColor3 = Theme.Accent,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
		Parent = topbar,
	})

	local close = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(38, 34),
		Text = utf8.char(215),
		TextColor3 = Theme.Accent,
		TextSize = 18,
		ZIndex = 22,
		Parent = topbar,
	})

	local sidebar = create("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(0, 190, 1, -34),
		ZIndex = 4,
		Parent = root,
	})

	create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Line,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 2, 1, 0),
		ZIndex = 6,
		Parent = sidebar,
	})
	create("Frame", {
		Name = "DividerAccent",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Line,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -7, 0, 0),
		Size = UDim2.new(0, 5, 1, 0),
		ZIndex = 6,
		Parent = sidebar,
	})
	local sidebarRuleA = create("Frame", {
		Name = "SidebarRuleA",
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, -11, 0, 3),
		ZIndex = 7,
		Parent = sidebar,
	})
	local tabList = create("ScrollingFrame", {
		Name = "TabList",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(0, 23),
		ScrollBarImageColor3 = Theme.Line,
		ScrollBarThickness = 2,
		Size = UDim2.new(1, -11, 1, -35),
		ZIndex = 7,
		Parent = sidebar,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabList,
	})

	local content = create("Frame", {
		Name = "Content",
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(190, 34),
		Size = UDim2.new(1, -190, 1, -34),
		ZIndex = 2,
		Parent = root,
	})
	local pages = create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -20, 1, 0),
		ZIndex = 5,
		Parent = content,
	})

	local self = setmetatable({
		Screen = screen,
		Root = root,
		Shadow = shadow,
		Scale = scale,
		ShadowScale = shadowScale,
		Topbar = topbar,
		SidebarRuleA = sidebarRuleA,
		TabList = tabList,
		Pages = pages,
		Tabs = {},
		Connections = {},
		SelectedTab = nil,
		Visible = true,
		ToggleKey = options.ToggleKey or Enum.KeyCode.RightShift,
		NotificationHost = notificationHost,
		NotificationOrder = 0,
		Destroyed = false,
		LowDetail = lowDetail,
		MinimumScale = tonumber(options.MinimumScale) or 0.25,
		TargetScale = options.Scale or 1,
		VisibilityGeneration = 0,
	}, Window)

	-- Keep the desktop composition intact, but fit it inside smaller phone/tablet
	-- viewports. UIScale is used instead of rebuilding every control so saved
	-- positions and the existing visual proportions remain stable.
	local function applyResponsiveScale()
		if options.AutoScale == false then return end
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize
		if not viewport or viewport.X <= 0 or viewport.Y <= 0 then return end
		local baseSize = options.Size or UDim2.fromOffset(790, 508)
		local width = baseSize.X.Offset > 0 and baseSize.X.Offset or 790
		local height = baseSize.Y.Offset > 0 and baseSize.Y.Offset or 508
		local margin = touchPrimary and 12 or 24
		local availableWidth = math.max(viewport.X - margin, 1)
		local availableHeight = math.max(viewport.Y - margin, 1)
		local fitted = math.min(availableWidth / width, availableHeight / height, 1)
		local responsive = math.clamp(fitted, self.MinimumScale, 1)
		self:SetScale(responsive)
		local maxOffsetX = math.max((viewport.X - width * responsive) * 0.5, 0)
		local maxOffsetY = math.max((viewport.Y - height * responsive) * 0.5, 0)
		self.Root.Position = UDim2.new(
			self.Root.Position.X.Scale,
			math.clamp(self.Root.Position.X.Offset, -maxOffsetX, maxOffsetX),
			self.Root.Position.Y.Scale,
			math.clamp(self.Root.Position.Y.Offset, -maxOffsetY, maxOffsetY)
		)
		self.NotificationHost.Size = UDim2.new(0, math.max(math.min(viewport.X - 32, 560), 1), 1, -44)
	end

	local viewportConnection
	local function bindViewport()
		if viewportConnection then viewportConnection:Disconnect() end
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveScale)
			table.insert(self.Connections, viewportConnection)
		end
		applyResponsiveScale()
	end
	table.insert(self.Connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport))
	bindViewport()

	attachDragBehavior(topbar, root, self)

	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
		local capture = self.PointerCapture
		if not capture then return end
		local sourceType = capture.Input.UserInputType
		if (sourceType == Enum.UserInputType.Touch and input == capture.Input)
			or (sourceType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
		then
			invokeCallback(capture.Move, input)
		end
	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
		local capture = self.PointerCapture
		if not capture then return end
		if input == capture.Input
			or (capture.Input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
		then
			self:ReleasePointer()
		end
	end))

	if not lowDetail then
		table.insert(
			self.Connections,
			root:GetPropertyChangedSignal("Position"):Connect(function()
				shadow.Position = UDim2.new(
					root.Position.X.Scale,
					root.Position.X.Offset + 7,
					root.Position.Y.Scale,
					root.Position.Y.Offset + 9
				)
			end)
		)
	end

	table.insert(
		self.Connections,
		close.MouseButton1Click:Connect(function()
			self:Toggle(false)
		end)
	)

	bindHover(close, function()
		tween(close, 0.12, { BackgroundTransparency = 0.75, BackgroundColor3 = Theme.PaperShadow })
	end, function()
		tween(close, 0.12, { BackgroundTransparency = 1 })
	end)

	table.insert(
		self.Connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and not self.CapturingKeybind and input.KeyCode == self.ToggleKey then
				self:Toggle()
			end
		end)
	)

	self.Environment = environment
	environment[ACTIVE_WINDOW_KEY] = self
	task.defer(function()
		if self.Destroyed then return end
		local targetScale = self.TargetScale
		self.Scale.Scale = targetScale * 0.97
		tween(self.Root, 0.18, { GroupTransparency = 0 }, Enum.EasingStyle.Quart)
		tween(self.Scale, 0.2, { Scale = targetScale }, Enum.EasingStyle.Quart)
	end)

	return self
end

function Window:Toggle(force)
	if self.Destroyed then return false end
	if force == nil then
		self.Visible = not self.Visible
	else
		self.Visible = force == true
	end
	self.VisibilityGeneration = (self.VisibilityGeneration or 0) + 1
	local generation = self.VisibilityGeneration
	local targetScale = self.TargetScale or self.Scale.Scale
	if self.Visible then
		self.Screen.Enabled = true
		self.Root.Visible = true
		self.Root.GroupTransparency = 1
		self.Scale.Scale = targetScale * 0.97
		tween(self.Root, 0.18, { GroupTransparency = 0 }, Enum.EasingStyle.Quart)
		tween(self.Scale, 0.2, { Scale = targetScale }, Enum.EasingStyle.Quart)
	else
		tween(self.Root, 0.14, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(self.Scale, 0.14, { Scale = targetScale * 0.98 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.15, function()
			if not self.Destroyed and self.VisibilityGeneration == generation and not self.Visible then
				self.Root.Visible = false
			end
		end)
	end
	return self.Visible
end

function Window:SetScale(value)
	if self.Destroyed then return end
	local nextScale = math.clamp(tonumber(value) or 1, self.MinimumScale or 0.48, 1.4)
	self.TargetScale = nextScale
	self.Scale.Scale = nextScale
	if self.ShadowScale then self.ShadowScale.Scale = nextScale end
end

function Window:Notify(options)
	if self.Destroyed then return end
	options = type(options) == "table" and options or { Message = tostring(options) }
	self.NotificationOrder = self.NotificationOrder + 1

	local kind = string.lower(tostring(options.Type or "info"))
	local accentColors = {
		info = Theme.Accent,
		success = Color3.fromRGB(167, 187, 154),
		warning = Color3.fromRGB(214, 177, 105),
		error = Color3.fromRGB(184, 105, 96),
	}
	local accent = accentColors[kind] or accentColors.info
	local duration = math.max(tonumber(options.Duration) or 4, 0.5)
	local notificationTitle = tostring(options.Title or "")
	local notificationMessage = tostring(options.Message or options.Text or "Notification")
	local closing = false

	local wrapper = create("Frame", {
		Name = "NotificationWrapper",
		BackgroundTransparency = 1,
		LayoutOrder = self.NotificationOrder,
		Size = UDim2.new(1, 0, 0, 38),
		ZIndex = 101,
		Parent = self.NotificationHost,
	})

	local shadow = create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.Black,
		BackgroundTransparency = 0.66,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(5, 6),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 101,
		Visible = false,
		Parent = wrapper,
	})
	corner(shadow, 2)

	local card = create("Frame", {
		Name = "Notification",
		BackgroundColor3 = Theme.White,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.new(1, 24, 0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 102,
		Parent = wrapper,
	})

	create("Frame", {
		Name = "AccentA",
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 6, 1, 0),
		ZIndex = 104,
		Parent = card,
	})
	create("Frame", {
		Name = "AccentB",
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0, 3, 1, 0),
		ZIndex = 104,
		Parent = card,
	})

	local header = create("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		Visible = false,
		ZIndex = 103,
		Parent = card,
	})

	local icon = create("Frame", {
		Name = "TypeIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(15, 16),
		Rotation = 45,
		Size = UDim2.fromOffset(9, 9),
		ZIndex = 104,
		Parent = header,
	})
	corner(icon, 1)

	local title = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(29, 0),
		Size = UDim2.new(1, -62, 1, 0),
		Text = notificationTitle ~= "" and notificationTitle or string.upper(kind),
		TextColor3 = Theme.White,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 104,
		Parent = header,
	})

	local close = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(32, 32),
		Text = utf8.char(215),
		TextColor3 = Theme.White,
		TextSize = 16,
		ZIndex = 105,
		Parent = header,
	})

	local message = create("TextLabel", {
		Name = "Message",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Text = notificationMessage,
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 103,
		Parent = card,
	})

	local progress = create("Frame", {
		Name = "Progress",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 104,
		Parent = card,
	})

	local controller = {}
	local function dismiss()
		if closing or not wrapper.Parent then
			return
		end
		closing = true
		tween(card, 0.18, { Position = UDim2.new(1, 24, 0, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		tween(shadow, 0.22, { BackgroundTransparency = 1 })
		task.delay(0.19, function()
			if wrapper.Parent then
				tween(wrapper, 0.16, { Size = UDim2.new(1, 0, 0, 0) })
				task.delay(0.17, function()
					if wrapper.Parent then
						wrapper:Destroy()
					end
				end)
			end
		end)
	end

	function controller:Close()
		dismiss()
	end

	function controller:SetTitle(value)
		notificationTitle = tostring(value or "")
		title.Text = notificationTitle
	end

	function controller:SetMessage(value)
		notificationMessage = tostring(value or "")
		message.Text = notificationMessage
	end

	close.MouseButton1Click:Connect(dismiss)
	bindHover(close, function()
		tween(close, 0.1, { BackgroundTransparency = 0.76, BackgroundColor3 = accent })
	end, function()
		tween(close, 0.1, { BackgroundTransparency = 1 })
	end)

	tween(card, 0.22, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quart)
	tween(progress, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
	task.delay(duration, dismiss)

	return controller
end

function Window:FocusTab(tab)
	if not tab or self.SelectedTab ~= tab then return end
	tab.SectionFocused = false
	if self.SidebarRuleA then self.SidebarRuleA.Visible = true end
	if tab.Footer then tab.Footer.Visible = true end
	tween(tab.Button, 0.14, {
		BackgroundColor3 = Theme.Ink,
		Size = UDim2.new(1, 0, 0, 34),
	})
	tween(tab.Label, 0.14, {
		Position = UDim2.fromOffset(31, 0),
		TextColor3 = Theme.White,
	})
	tween(tab.Icon, 0.16, {
		BackgroundColor3 = Theme.Accent,
		Position = UDim2.fromOffset(9, 17),
		Rotation = 45,
		Size = UDim2.fromOffset(12, 12),
	}, Enum.EasingStyle.Quart)
	for _, section in ipairs(tab.Sections) do
		tween(section.NavButton, 0.14, {
			BackgroundColor3 = Theme.PaperDark,
			Size = UDim2.new(1, -20, 0, 34),
		})
		tween(section.NavIcon, 0.16, {
			BackgroundColor3 = Theme.InkSoft,
			Position = UDim2.fromOffset(12, 17),
			Rotation = 0,
		}, Enum.EasingStyle.Quart)
		tween(section.NavLabel, 0.14, {
			Position = UDim2.fromOffset(34, 0),
			TextColor3 = Theme.InkSoft,
		})
		if section.NavTopLine then section.NavTopLine.Visible = false end
		if section.NavBottomLine then section.NavBottomLine.Visible = false end
	end
end

function Window:SelectTab(tab)
	if self.SelectedTab == tab then
		self:FocusTab(tab)
		return
	end
	local previousTab = self.SelectedTab
	for _, candidate in ipairs(self.Tabs) do
		local selected = candidate == tab
		if selected then
			candidate.Page.Visible = true
		elseif candidate ~= previousTab then
			candidate.Page.Visible = false
		end
		if candidate.SectionList then candidate.SectionList.Visible = selected end
		if candidate.Footer then candidate.Footer.Visible = selected end
		tween(candidate.Button, 0.15, {
			BackgroundColor3 = selected and Theme.Ink or Theme.PaperDark,
			Size = UDim2.new(1, 0, 0, 34),
		})
		tween(candidate.Label, 0.15, {
			Position = UDim2.fromOffset(31, 0),
			TextColor3 = selected and Theme.White or Theme.InkSoft,
		})
		tween(candidate.Icon, 0.18, {
			BackgroundColor3 = selected and Theme.Accent or Theme.InkSoft,
			Position = UDim2.fromOffset(9, 17),
			Rotation = selected and 45 or 0,
			Size = selected and UDim2.fromOffset(12, 12) or UDim2.fromOffset(13, 13),
		}, Enum.EasingStyle.Back)
	end
	self.SelectedTab = tab
	if previousTab and previousTab.Page.Parent then
		tween(previousTab.Page, 0.1, { Position = UDim2.fromOffset(-10, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.11, function()
			if self.SelectedTab ~= previousTab and previousTab.Page.Parent then
				previousTab.Page.Visible = false
			end
		end)
	end
	if tab.Sections and tab.Sections[1] and not tab.SelectedSection then
		tab:SelectSection(tab.Sections[1], false, false)
	end
	self:FocusTab(tab)
	local page = tab.Page
	page.Position = UDim2.fromOffset(14, 0)
	tween(page, 0.18, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quart)
end

function Window:ShowWelcome(options)
	if self.Destroyed then return end
	options = options or {}
	if self.WelcomeOverlay and self.WelcomeOverlay.Parent then
		self.WelcomeOverlay:Destroy()
	end

	local overlay = create("Frame", {
		Name = "WelcomeOverlay",
		BackgroundColor3 = Theme.Black,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
		Parent = self.Root,
	})
	self.WelcomeOverlay = overlay

	local card = create("Frame", {
		Name = "WelcomeCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 260),
		ZIndex = 61,
		Parent = overlay,
	})
	corner(card, 3)
	stroke(card, Theme.Ink, 1, 0.12)
	addPaperPattern(card, self.LowDetail)

	local accent = create("Frame", {
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 6, 1, 0),
		ZIndex = 63,
		Parent = card,
	})

	local stepLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.new(1, -48, 0, 18),
		Text = options.FirstStepLabel or ("01 / 02  " .. utf8.char(183) .. "  FIRST SETUP"),
		TextColor3 = Theme.Line,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 64,
		Parent = card,
	})
	local title = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Garamond,
		Position = UDim2.fromOffset(24, 43),
		Size = UDim2.new(1, -48, 0, 40),
		Text = options.Title or "WELCOME",
		TextColor3 = Theme.Ink,
		TextSize = 27,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 64,
		Parent = card,
	})
	local body = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(24, 88),
		Size = UDim2.new(1, -48, 0, 80),
		Text = options.Message or "Take a moment to review the recommended settings before you begin.",
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 64,
		Parent = card,
	})

	local actions = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 24, 1, -58),
		Size = UDim2.new(1, -48, 0, 34),
		ZIndex = 64,
		Parent = card,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = actions,
	})

	local function actionButton(text, width, primary, callback)
		local button = create("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = primary and Theme.Ink or Theme.PaperDark,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Size = UDim2.fromOffset(width, 34),
			Text = text,
			TextColor3 = primary and Theme.White or Theme.InkSoft,
			TextSize = 10,
			ZIndex = 65,
			Parent = actions,
		})
		corner(button, 2)
		button.MouseButton1Click:Connect(callback)
		return button
	end

	local continueButton
	local joinButton
	local invite = tostring(options.DiscordInvite or "")
	local hasCommunityStep = options.ShowCommunityStep
	if hasCommunityStep == nil then
		hasCommunityStep = invite ~= ""
			or options.CommunityTitle ~= nil
			or options.CommunityMessage ~= nil
	end
	local function finish()
		if type(options.OnComplete) == "function" then invokeCallback(options.OnComplete) end
		self.WelcomeOverlay = nil
		overlay:Destroy()
	end
	joinButton = actionButton(options.JoinText or "JOIN DISCORD", 124, false, function()
		if invite ~= "" and typeof(setclipboard) == "function" then
			pcall(setclipboard, invite)
		end
		self:Notify({
			Title = "Discord invite",
			Message = invite ~= "" and ("Copied: " .. invite) or "Invite unavailable",
			Type = invite ~= "" and "Success" or "Warning",
			Duration = 4,
		})
	end)
	joinButton.Visible = false
	continueButton = actionButton(hasCommunityStep and (options.NextText or "NEXT") or (options.ContinueText or "CONTINUE"), 104, true, function()
		if hasCommunityStep and continueButton.Text == (options.NextText or "NEXT") then
			stepLabel.Text = options.SecondStepLabel or ("02 / 02  " .. utf8.char(183) .. "  COMMUNITY")
			title.Text = options.CommunityTitle or "JOIN THE COMMUNITY"
			body.Text = options.CommunityMessage or "Join the community for updates, documentation and support."
			joinButton.Visible = true
			continueButton.Text = options.ContinueText or "CONTINUE"
		else
			finish()
		end
	end)

	card.Size = UDim2.fromOffset(410, 240)
	tween(card, 0.24, { Size = UDim2.fromOffset(440, 260) }, Enum.EasingStyle.Back)
	return { Close = finish, Instance = overlay }
end

function Window:CreateTab(name, options)
	if self.Destroyed then return nil end
	options = options or {}
	local index = #self.Tabs + 1

	local tabContainer = create("Frame", {
		Name = "TabContainer_" .. tostring(name),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 8,
		Parent = self.TabList,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabContainer,
	})

	local button = create("TextButton", {
		Name = "Tab_" .. tostring(name),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.PaperDark,
		BorderSizePixel = 0,
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 34),
		Text = "",
		ZIndex = 8,
		Parent = tabContainer,
	})

	local icon = create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.InkSoft,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(9, 17),
		Size = UDim2.fromOffset(13, 13),
		ZIndex = 9,
		Parent = button,
	})
	local label = create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(31, 0),
		Size = UDim2.new(1, -37, 1, 0),
		Text = tostring(name),
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = button,
	})

	local page = create("ScrollingFrame", {
		Name = "Page_" .. tostring(name),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarImageColor3 = Theme.Line,
		ScrollBarThickness = 3,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 6,
		Parent = self.Pages,
	})
	padding(page, 18, 7, 0, 16)

	create("TextLabel", {
		Name = "PageTitle",
		BackgroundTransparency = 1,
		Font = Enum.Font.Garamond,
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 50),
		Text = options.Title or tostring(name),
		TextColor3 = Theme.Ink,
		TextSize = 27,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = page,
	})

	create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})

	local tabFooter = create("Frame", {
		Name = "TabFooter",
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 8),
		Visible = false,
		ZIndex = 8,
		Parent = tabContainer,
	})
	create("Frame", {
		Name = "RuleA",
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 3),
		ZIndex = 9,
		Parent = tabFooter,
	})
	local sectionList = create("Frame", {
		Name = "Sections",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		Visible = false,
		ZIndex = 8,
		Parent = tabContainer,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sectionList,
	})

	local tab = setmetatable({
		Window = self,
		Container = tabContainer,
		Button = button,
		Icon = icon,
		Label = label,
		Page = page,
		Footer = tabFooter,
		SectionList = sectionList,
		Sections = {},
		SelectedSection = nil,
		ActiveSection = nil,
		Order = 0,
	}, Tab)
	table.insert(self.Tabs, tab)

	button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)
	bindHover(button, function()
		if self.SelectedTab ~= tab or tab.SectionFocused then
			tween(button, 0.12, { BackgroundColor3 = Theme.PaperShadow })
		end
	end, function()
		if self.SelectedTab ~= tab or tab.SectionFocused then
			tween(button, 0.12, { BackgroundColor3 = Theme.PaperDark })
		end
	end)

	if index == 1 then
		self:SelectTab(tab)
	end
	return tab
end

function Tab:SelectSection(section, scroll, focusSection)
	if not section then return end
	focusSection = focusSection == true
	self.SelectedSection = section
	self.SectionFocused = focusSection
	if focusSection then
		if self.Window.SidebarRuleA then self.Window.SidebarRuleA.Visible = false end
		if self.Footer then self.Footer.Visible = false end
		tween(self.Button, 0.14, {
			BackgroundColor3 = Theme.PaperDark,
			Size = UDim2.new(1, -20, 0, 34),
		})
		tween(self.Label, 0.14, {
			Position = UDim2.fromOffset(34, 0),
			TextColor3 = Theme.InkSoft,
		})
		tween(self.Icon, 0.16, {
			BackgroundColor3 = Theme.InkSoft,
			Position = UDim2.fromOffset(12, 17),
			Rotation = 0,
			Size = UDim2.fromOffset(13, 13),
		}, Enum.EasingStyle.Quart)
	end
	for _, candidate in ipairs(self.Sections) do
		local active = candidate == section
		local selected = active and focusSection
		candidate.Root.Visible = active
		tween(candidate.NavButton, 0.14, {
			BackgroundColor3 = selected and Theme.Ink or Theme.PaperDark,
			Size = selected and UDim2.new(1, 0, 0, 34) or UDim2.new(1, -20, 0, 34),
		})
		tween(candidate.NavIcon, 0.16, {
			BackgroundColor3 = selected and Theme.Accent or Theme.InkSoft,
			Position = selected and UDim2.fromOffset(9, 17) or UDim2.fromOffset(12, 17),
			Rotation = selected and 45 or 0,
		}, Enum.EasingStyle.Quart)
		tween(candidate.NavLabel, 0.14, {
			Position = selected and UDim2.fromOffset(31, 0) or UDim2.fromOffset(34, 0),
			TextColor3 = selected and Theme.White or Theme.InkSoft,
		})
		if candidate.NavTopLine then candidate.NavTopLine.Visible = selected end
		if candidate.NavBottomLine then candidate.NavBottomLine.Visible = selected end
	end
	section:SetOpen(true)
	self.Page.CanvasPosition = Vector2.new(0, 0)
end

function Section:SetOpen(nextOpen)
	nextOpen = nextOpen == true
	if self.Open == nextOpen then return end
	self.Open = nextOpen
	self.Generation = (self.Generation or 0) + 1
	local generation = self.Generation
	self.Header.Text = self.Name .. (nextOpen and "  " .. utf8.char(9660) or "  " .. utf8.char(9654))
	if nextOpen then
		self.Body.Visible = true
		self.Body.ClipsDescendants = true
		self.Body.AutomaticSize = Enum.AutomaticSize.None
		self.Body.Size = UDim2.new(1, 0, 0, 0)
		local targetHeight = math.max(self.BodyLayout.AbsoluteContentSize.Y, self.ExpandedHeight or 0)
		tween(self.Body, 0.2, { Size = UDim2.new(1, 0, 0, targetHeight) }, Enum.EasingStyle.Quart)
		task.delay(0.21, function()
			if self.Generation == generation and self.Open and self.Body.Parent then
				self.Body.AutomaticSize = Enum.AutomaticSize.Y
				self.Body.ClipsDescendants = false
			end
		end)
	else
		self.ExpandedHeight = math.max(self.Body.AbsoluteSize.Y, self.BodyLayout.AbsoluteContentSize.Y)
		self.Body.ClipsDescendants = true
		self.Body.AutomaticSize = Enum.AutomaticSize.None
		self.Body.Size = UDim2.new(1, 0, 0, self.Body.AbsoluteSize.Y)
		tween(self.Body, 0.18, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quart)
		task.delay(0.19, function()
			if self.Generation == generation and not self.Open and self.Body.Parent then
				self.Body.Visible = false
			end
		end)
	end
end

function Tab:AddSection(name, options)
	if type(name) == "table" then
		options = name
		name = options.Name
	end
	options = options or {}
	self.Order = self.Order + 1
	local sectionName = tostring(name or "Section")
	local sectionTitle = tostring(options.Title or sectionName)
	local root = create("Frame", {
		Name = "Section_" .. sectionName,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self.Order,
		Size = UDim2.new(1, 0, 0, 0),
		Visible = #self.Sections == 0,
		ZIndex = 7,
		Parent = self.Page,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = root,
	})

	local header = create("TextButton", {
		Name = "Header",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 30),
		Text = sectionTitle .. "  " .. utf8.char(9660),
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = root,
	})

	local body = create("Frame", {
		Name = "Body",
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ClipsDescendants = false,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 7,
		Parent = root,
	})
	local bodyLayout = create("UIListLayout", {
		Padding = UDim.new(0, 9),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})

	local navButton = create("TextButton", {
		Name = "Section_" .. sectionName,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.PaperDark,
		BorderSizePixel = 0,
		LayoutOrder = #self.Sections + 1,
		Size = UDim2.new(1, -20, 0, 34),
		Text = "",
		ZIndex = 8,
		Parent = self.SectionList,
	})
	local navTopLine = create("Frame", {
		Name = "SelectionTop",
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, -6),
		Size = UDim2.new(1, 0, 0, 3),
		Visible = false,
		ZIndex = 10,
		Parent = navButton,
	})
	local navBottomLine = create("Frame", {
		Name = "SelectionBottom",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, 6),
		Size = UDim2.new(1, 0, 0, 3),
		Visible = false,
		ZIndex = 10,
		Parent = navButton,
	})
	local navIcon = create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.InkSoft,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 17),
		Size = UDim2.fromOffset(12, 12),
		ZIndex = 9,
		Parent = navButton,
	})
	local navLabel = create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Text = sectionName,
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = navButton,
	})

	local section = setmetatable({
		Tab = self,
		Name = sectionTitle,
		NavName = sectionName,
		Root = root,
		Header = header,
		Body = body,
		BodyLayout = bodyLayout,
		NavButton = navButton,
		NavIcon = navIcon,
		NavLabel = navLabel,
		NavTopLine = navTopLine,
		NavBottomLine = navBottomLine,
		Open = true,
		Generation = 0,
		ExpandedHeight = 0,
	}, Section)
	table.insert(self.Sections, section)
	self.ActiveSection = section

	header.MouseButton1Click:Connect(function()
		section:SetOpen(not section.Open)
	end)
	bindHover(header, function()
		tween(header, 0.12, { TextColor3 = Theme.Ink })
	end, function()
		tween(header, 0.12, { TextColor3 = Theme.InkSoft })
	end)
	navButton.MouseButton1Click:Connect(function()
		self:SelectSection(section, true, true)
	end)
	bindHover(navButton, function()
		if not (self.SectionFocused and self.SelectedSection == section) then
			tween(navButton, 0.12, { BackgroundColor3 = Theme.PaperShadow })
		end
	end, function()
		if not (self.SectionFocused and self.SelectedSection == section) then
			tween(navButton, 0.12, { BackgroundColor3 = Theme.PaperDark })
		end
	end)
	if #self.Sections == 1 then
		self:SelectSection(section, false, false)
	end
	return section
end

local function createControlRow(tab, height)
	tab.Order = tab.Order + 1
	local rowHeight = height or 38
	local row = create("Frame", {
		Name = "ControlRow",
		BackgroundColor3 = Theme.PaperDark,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		LayoutOrder = tab.Order,
		Size = UDim2.new(1, 0, 0, rowHeight),
		ZIndex = 7,
		Parent = tab.ActiveSection and tab.ActiveSection.Body or tab.Page,
	})
	create("Frame", {
		Name = "RailGutter",
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 12, 1, 0),
		ZIndex = 8,
		Parent = row,
	})
	create("Frame", {
		Name = "AccentA",
		BackgroundColor3 = Theme.PaperDark,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 6, 1, 0),
		ZIndex = 9,
		Parent = row,
	})
	local hoverArrow = create("TextLabel", {
		Name = "HoverArrow",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(-20, 0),
		Size = UDim2.fromOffset(16, rowHeight),
		Text = utf8.char(9654),
		TextColor3 = Theme.Ink,
		TextSize = 16,
		TextTransparency = 1,
		ZIndex = 10,
		Parent = row,
	})
	local topLine = create("Frame", {
		Name = "HoverTop",
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, -6),
		Size = UDim2.new(0, 0, 0, 2),
		ZIndex = 10,
		Parent = row,
	})
	local bottomLine = create("Frame", {
		Name = "HoverBottom",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, 6),
		Size = UDim2.new(0, 0, 0, 2),
		ZIndex = 10,
		Parent = row,
	})
	bindHover(row, function()
		tween(hoverArrow, 0.14, { Position = UDim2.fromOffset(-16, 0), TextTransparency = 0 }, Enum.EasingStyle.Quart)
		tween(topLine, 0.16, { Size = UDim2.new(1, 0, 0, 2) }, Enum.EasingStyle.Quart)
		tween(bottomLine, 0.16, { Size = UDim2.new(1, 0, 0, 2) }, Enum.EasingStyle.Quart)
	end, function()
		tween(hoverArrow, 0.12, { Position = UDim2.fromOffset(-20, 0), TextTransparency = 1 })
		tween(topLine, 0.12, { Size = UDim2.new(0, 0, 0, 2) })
		tween(bottomLine, 0.12, { Size = UDim2.new(0, 0, 0, 2) })
	end)
	return row
end

local function setControlRowColor(row, color)
	row.BackgroundColor3 = color
	local accent = row:FindFirstChild("AccentA")
	if accent then accent.BackgroundColor3 = color end
end

local function tweenControlRowColor(row, duration, color)
	tween(row, duration, { BackgroundColor3 = color })
	local accent = row:FindFirstChild("AccentA")
	if accent then tween(accent, duration, { BackgroundColor3 = color }) end
end

-- Public escape hatch for feature panels that need richer content than a
-- single control row while still remaining owned, themed, and laid out by
-- Int3UI. The builder receives the panel and the active theme palette.
function Tab:AddCustom(options)
	options = type(options) == "table" and options or {}
	local height = math.max(tonumber(options.Height) or 120, 24)
	local row = createControlRow(self, height)
	row.Name = options.Name or "CustomPanel"
	row.ClipsDescendants = options.ClipsDescendants ~= false
	for _, ornamentName in ipairs({ "RailGutter", "AccentA", "HoverArrow", "HoverTop", "HoverBottom" }) do
		local ornament = row:FindFirstChild(ornamentName)
		if ornament then ornament.Visible = false end
	end
	corner(row, tonumber(options.CornerRadius) or 2)
	stroke(row, Theme.Line, 1, 0.55)
	if type(options.Builder) == "function" then
		invokeCallback(options.Builder, row, Theme)
	end
	return {
		Instance = row,
		Theme = Theme,
		SetVisible = function(_, visible)
			row.Visible = visible == true
		end,
	}
end

function Tab:AddButton(options)
	options = type(options) == "table" and options or { Name = tostring(options) }
	local row = createControlRow(self, 38)
	local button = create("TextButton", {
		Name = "Button",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -32, 1, 0),
		Text = options.Name or "Button",
		TextColor3 = Theme.InkSoft,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = row,
	})

	bindHover(row, function()
		tweenControlRowColor(row, 0.12, Theme.Ink)
		tween(button, 0.12, { TextColor3 = Theme.White })
	end, function()
		tweenControlRowColor(row, 0.12, Theme.PaperDark)
		tween(button, 0.12, { TextColor3 = Theme.InkSoft })
	end)

	button.MouseButton1Down:Connect(function()
		tweenControlRowColor(row, 0.06, Theme.Black)
	end)
	button.MouseButton1Up:Connect(function()
		tweenControlRowColor(row, 0.08, HoverEnabled and Theme.Ink or Theme.PaperDark)
	end)
	button.MouseButton1Click:Connect(function()
		invokeCallback(options.Callback)
	end)

	return {
		Instance = row,
		SetName = function(_, value)
			button.Text = tostring(value)
		end,
		Fire = function()
			invokeCallback(options.Callback)
		end,
	}
end

function Tab:AddToggle(options)
	options = options or {}
	local value = options.Default == true
	local row = createControlRow(self, 38)
	local button = create("TextButton", {
		Name = "Toggle",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -32, 1, 0),
		Text = options.Name or "Toggle",
		TextColor3 = Theme.InkSoft,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = row,
	})
	local state = create("TextLabel", {
		Name = "State",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(48, 38),
		Text = value and "ON" or "OFF",
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 10,
		Parent = row,
	})

	local function render(animate)
		state.Text = value and "ON" or "OFF"
		local properties = { BackgroundColor3 = value and Theme.Ink or Theme.PaperDark }
		local textColor = value and Theme.White or Theme.InkSoft
		if animate then
			tweenControlRowColor(row, 0.14, properties.BackgroundColor3)
			tween(button, 0.14, { TextColor3 = textColor })
			tween(state, 0.14, { TextColor3 = textColor })
		else
			setControlRowColor(row, properties.BackgroundColor3)
			button.TextColor3 = textColor
			state.TextColor3 = textColor
		end
	end

	local function set(nextValue, fire)
		value = nextValue == true
		render(true)
		if fire ~= false then
			invokeCallback(options.Callback, value)
		end
	end

	button.MouseButton1Click:Connect(function()
		set(not value, true)
	end)
	render(false)

	return {
		Instance = row,
		Set = function(_, nextValue, fire)
			set(nextValue, fire)
		end,
		Get = function()
			return value
		end,
	}
end

function Tab:AddSlider(options)
	options = options or {}
	local minimum = tonumber(options.Minimum or options.Min) or 0
	local maximum = tonumber(options.Maximum or options.Max) or 100
	local step = tonumber(options.Step) or 1
	local value = math.clamp(tonumber(options.Default) or minimum, minimum, maximum)

	local row = createControlRow(self, 38)
	local valueLabel = create("TextBox", {
		Name = "Value",
		AutoLocalize = false,
		BackgroundColor3 = Theme.InkSoft,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(24, 7),
		Size = UDim2.fromOffset(48, 24),
		Text = tostring(value),
		TextColor3 = Theme.White,
		TextSize = 10,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 10,
		Parent = row,
	})
	local label = create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(80, 0),
		Size = UDim2.new(0.58, -80, 1, 0),
		Text = options.Name or "Slider",
		TextColor3 = Theme.InkSoft,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = row,
	})

	local track = create("TextButton", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(74, 26),
		Text = "",
		ZIndex = 9,
		Parent = row,
	})

	local bladeSegments = {}
	local segmentCount = self.Window.LowDetail and 12 or 18
	for index = 1, segmentCount do
		local segment = create("Frame", {
			Name = "BladeSegment",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Line,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Position = UDim2.new((index - 1) / (segmentCount - 1), 0, 0.5, 0),
			Rotation = 0,
			Size = UDim2.fromOffset(3, 9),
			ZIndex = 10,
			Parent = track,
		})
		bladeSegments[index] = segment
	end

	local cursor = create("Frame", {
		Name = "SliderCursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.5),
		Rotation = 0,
		Size = UDim2.fromOffset(4, 26),
		ZIndex = 12,
		Parent = track,
	})

	local function normalize(nextValue)
		nextValue = math.clamp(nextValue, minimum, maximum)
		return math.floor((nextValue - minimum) / step + 0.5) * step + minimum
	end

	local function render()
		local ratio = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
		local activeSegments = math.floor(ratio * segmentCount + 0.5)
		for index, segment in ipairs(bladeSegments) do
			local active = index <= activeSegments
			segment.BackgroundColor3 = Theme.Ink
			segment.BackgroundTransparency = 0
			segment.Size = UDim2.fromOffset(3, active and 13 or 9)
		end
		cursor.Position = UDim2.fromScale(ratio, 0.5)
		valueLabel.Text = string.format(options.Format or "%g", value) .. tostring(options.Suffix or "")
	end

	local function set(nextValue, fire)
		local normalized = normalize(tonumber(nextValue) or minimum)
		if normalized == value then
			return
		end
		value = normalized
		render()
		if fire ~= false then
			invokeCallback(options.Callback, value)
		end
	end

	local function updateFromInput(input)
		local ratio = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		set(minimum + (maximum - minimum) * ratio, true)
	end

	valueLabel.FocusLost:Connect(function()
		local typed = valueLabel.Text:match("[-+]?%d*%.?%d+")
		if typed and tonumber(typed) then
			set(tonumber(typed), true)
		end
		render()
	end)
	valueLabel.Focused:Connect(function()
		valueLabel.Text = string.format(options.Format or "%g", value)
		valueLabel.CursorPosition = #valueLabel.Text + 1
	end)

	table.insert(
		self.Window.Connections,
		track.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				updateFromInput(input)
				tween(cursor, 0.08, { Size = UDim2.fromOffset(6, 30) }, Enum.EasingStyle.Quad)
				self.Window:CapturePointer(input, updateFromInput, function()
					if cursor.Parent then
						tween(cursor, 0.12, { Size = UDim2.fromOffset(4, 26) }, Enum.EasingStyle.Back)
					end
				end)
			end
		end)
	)

	render()
	return {
		Instance = row,
		Set = function(_, nextValue, fire)
			set(nextValue, fire)
		end,
		Get = function()
			return value
		end,
	}
end

function Tab:AddInput(options)
	options = options or {}
	local value = tostring(options.Default or "")
	local row = createControlRow(self, 42)

	local label = create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(0.43, -32, 1, 0),
		Text = options.Name or "Input",
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = row,
	})

	local box = create("TextBox", {
		Name = "InputBox",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		ClearTextOnFocus = options.ClearTextOnFocus == true,
		Font = Enum.Font.Code,
		PlaceholderColor3 = Theme.Line,
		PlaceholderText = tostring(options.Placeholder or ""),
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.new(0.55, 0, 0, 26),
		Text = value,
		TextColor3 = Theme.Ink,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 9,
		Parent = row,
	})
	corner(box, 1)
	stroke(box, Theme.Line, 1, 0.45)
	padding(box, 7, 7, 0, 0)

	local function set(nextValue, fire)
		local nextText = tostring(nextValue or "")
		if options.Numeric and nextText ~= "" and tonumber(nextText) == nil then
			box.Text = value
			return
		end
		value = nextText
		box.Text = value
		if fire ~= false then
			invokeCallback(options.Callback, value)
		end
	end

	box.FocusLost:Connect(function()
		set(box.Text, true)
	end)
	box.Focused:Connect(function()
		tweenControlRowColor(row, 0.12, Theme.PaperShadow)
	end)
	box.FocusLost:Connect(function()
		tweenControlRowColor(row, 0.12, Theme.PaperDark)
	end)

	return {
		Instance = row,
		Set = function(_, nextValue, fire)
			set(nextValue, fire)
		end,
		Get = function()
			return value
		end,
	}
end

function Tab:AddDropdown(options)
	options = options or {}
	local values = table.clone(options.Values or {})
	local disabled = {}
	for _, item in ipairs(options.DisabledValues or {}) do
		disabled[tostring(item)] = true
	end
	local value = options.Default or values[1] or ""
	local open = false
	local built = false
	local row = createControlRow(self, 40)

	local label = create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(0.42, -32, 0, 40),
		Text = options.Name or "Dropdown",
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = row,
	})

	local selector = create("TextButton", {
		Name = "Selector",
		AnchorPoint = Vector2.new(1, 0),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		Position = UDim2.new(1, -9, 0, 7),
		Size = UDim2.new(0.56, 0, 0, 26),
		Text = tostring(value) .. "  " .. utf8.char(9662),
		TextColor3 = Theme.Ink,
		TextSize = 10,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 10,
		Parent = row,
	})
	corner(selector, 1)
	stroke(selector, Theme.Line, 1, 0.45)

	local list = create("ScrollingFrame", {
		Name = "Options",
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(8, 40),
		ScrollBarImageColor3 = Theme.InkSoft,
		ScrollBarThickness = 2,
		Size = UDim2.new(1, -16, 0, 0),
		Visible = false,
		ZIndex = 15,
		Parent = row,
	})
	corner(list, 1)
	stroke(list, Theme.Line, 1, 0.35)
	local layout = create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})

	local function setOpen(nextOpen)
		open = nextOpen == true
		local height = math.min(#values, 6) * 26
		list.Visible = open
		selector.Text = tostring(value) .. "  " .. (open and utf8.char(9652) or utf8.char(9662))
		tween(row, 0.16, { Size = UDim2.new(1, 0, 0, open and (44 + height) or 40) }, Enum.EasingStyle.Quart)
		list.Size = UDim2.new(1, -16, 0, height)
	end

	local function set(nextValue, fire)
		if disabled[tostring(nextValue)] then
			return
		end
		value = nextValue
		selector.Text = tostring(value) .. "  " .. (open and utf8.char(9652) or utf8.char(9662))
		if fire ~= false then
			invokeCallback(options.Callback, value)
		end
	end

	local function rebuild()
		built = true
		for _, child in ipairs(list:GetChildren()) do
			if child ~= layout and child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for index, item in ipairs(values) do
			local blocked = disabled[tostring(item)] == true
			local itemButton = create("TextButton", {
				AutoButtonColor = false,
				BackgroundColor3 = Theme.Paper,
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
				Font = Enum.Font.Code,
				LayoutOrder = index,
				Size = UDim2.new(1, -2, 0, 26),
				Text = tostring(item),
				TextColor3 = blocked and Theme.Line or Theme.InkSoft,
				TextSize = 10,
				ZIndex = 16,
				Parent = list,
			})
			itemButton.MouseButton1Click:Connect(function()
				if not blocked then
					set(item, true)
					setOpen(false)
				end
			end)
			bindHover(itemButton, function()
				if not blocked then
					tween(itemButton, 0.1, { BackgroundColor3 = Theme.PaperShadow })
				end
			end, function()
				tween(itemButton, 0.1, { BackgroundColor3 = Theme.Paper })
			end)
		end
		if open then
			setOpen(true)
		end
	end

	selector.MouseButton1Click:Connect(function()
		if not built then rebuild() end
		setOpen(not open)
	end)

	return {
		Instance = row,
		Set = function(_, nextValue, fire)
			set(nextValue, fire)
		end,
		Get = function()
			return value
		end,
		SetValues = function(_, nextValues)
			values = table.clone(nextValues or {})
			if #values > 0 and not table.find(values, value) then
				set(values[1], false)
			end
			built = false
			if open then rebuild() end
		end,
		SetDisabledValues = function(_, nextDisabled)
			table.clear(disabled)
			for _, item in ipairs(nextDisabled or {}) do
				disabled[tostring(item)] = true
			end
			built = false
			if open then rebuild() end
		end,
	}
end

function Tab:AddColorPicker(options)
	options = options or {}
	local value = typeof(options.Default) == "Color3" and options.Default or Color3.new(1, 1, 1)
	local hue, saturation, brightness = value:ToHSV()
	local open = false
	local row = createControlRow(self, 42)

	create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -145, 0, 42),
		Text = options.Name or "Color",
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = row,
	})

	local swatch = create("TextButton", {
		Name = "Swatch",
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = value,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		Position = UDim2.new(1, -9, 0, 21),
		Size = UDim2.fromOffset(116, 25),
		Text = "#FFFFFF  " .. utf8.char(9662),
		TextColor3 = Theme.White,
		TextSize = 10,
		ZIndex = 9,
		Parent = row,
	})
	corner(swatch, 1)
	stroke(swatch, Theme.Ink, 1, 0.25)

	local panel = create("Frame", {
		Name = "PickerPanel",
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 47),
		Size = UDim2.new(1, -16, 0, 140),
		Visible = false,
		ZIndex = 14,
		Parent = row,
	})
	corner(panel, 1)
	stroke(panel, Theme.Line, 1, 0.4)

	local svArea = create("Frame", {
		Name = "SaturationValue",
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -48, 0, 99),
		ZIndex = 15,
		Parent = panel,
	})
	corner(svArea, 1)

	local whiteLayer = create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 16,
		Parent = svArea,
	})
	create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = whiteLayer,
	})

	local blackLayer = create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 17,
		Parent = svArea,
	})
	create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = blackLayer,
	})

	local svInput = create("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 19,
		Parent = svArea,
	})
	local svCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(saturation, 1 - brightness),
		Size = UDim2.fromOffset(11, 11),
		ZIndex = 20,
		Parent = svArea,
	})
	corner(svCursor, 999)
	stroke(svCursor, Theme.White, 2, 0)

	local hueArea = create("Frame", {
		Name = "Hue",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Position = UDim2.new(1, -31, 0, 8),
		Size = UDim2.fromOffset(18, 99),
		ZIndex = 15,
		Parent = panel,
	})
	corner(hueArea, 1)
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = hueArea,
	})
	local hueInput = create("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 19,
		Parent = hueArea,
	})
	local hueCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.White,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, hue),
		Size = UDim2.fromOffset(24, 3),
		ZIndex = 20,
		Parent = hueArea,
	})
	stroke(hueCursor, Theme.Ink, 1, 0.1)

	local hexBox = create("TextBox", {
		Name = "Hex",
		BackgroundColor3 = Theme.PaperDark,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(8, 114),
		Size = UDim2.new(1, -16, 0, 19),
		Text = "#FFFFFF",
		TextColor3 = Theme.Ink,
		TextSize = 10,
		ZIndex = 15,
		Parent = panel,
	})
	corner(hexBox, 1)

	local function toHex(color)
		return string.format(
			"#%02X%02X%02X",
			math.floor(color.R * 255 + 0.5),
			math.floor(color.G * 255 + 0.5),
			math.floor(color.B * 255 + 0.5)
		)
	end

	local function render()
		local hex = toHex(value)
		swatch.BackgroundColor3 = value
		swatch.Text = hex .. "  " .. (open and utf8.char(9652) or utf8.char(9662))
		swatch.TextColor3 = brightness > 0.62 and Theme.Ink or Theme.White
		hexBox.Text = hex
		svArea.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svCursor.Position = UDim2.fromScale(saturation, 1 - brightness)
		hueCursor.Position = UDim2.fromScale(0.5, hue)
	end

	local function set(nextValue, fire)
		if typeof(nextValue) == "Color3" then
			value = nextValue
			hue, saturation, brightness = value:ToHSV()
		end
		render()
		if fire ~= false then
			invokeCallback(options.Callback, value)
		end
	end

	local function setOpen(nextOpen)
		open = nextOpen == true
		panel.Visible = open
		tween(row, 0.18, { Size = UDim2.new(1, 0, 0, open and 195 or 42) }, Enum.EasingStyle.Quart)
		render()
	end

	local function updateSV(input)
		saturation = math.clamp((input.Position.X - svArea.AbsolutePosition.X) / svArea.AbsoluteSize.X, 0, 1)
		brightness = 1 - math.clamp((input.Position.Y - svArea.AbsolutePosition.Y) / svArea.AbsoluteSize.Y, 0, 1)
		value = Color3.fromHSV(hue, saturation, brightness)
		render()
		invokeCallback(options.Callback, value)
	end

	local function updateHue(input)
		hue = math.clamp((input.Position.Y - hueArea.AbsolutePosition.Y) / hueArea.AbsoluteSize.Y, 0, 1)
		value = Color3.fromHSV(hue, saturation, brightness)
		render()
		invokeCallback(options.Callback, value)
	end

	swatch.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)
	svInput.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			updateSV(input)
			self.Window:CapturePointer(input, updateSV)
		end
	end)
	hueInput.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			updateHue(input)
			self.Window:CapturePointer(input, updateHue)
		end
	end)
	hexBox.FocusLost:Connect(function()
		local hex = hexBox.Text:gsub("#", "")
		if hex:match("^[%x][%x][%x][%x][%x][%x]$") then
			local r = tonumber(hex:sub(1, 2), 16)
			local g = tonumber(hex:sub(3, 4), 16)
			local b = tonumber(hex:sub(5, 6), 16)
			set(Color3.fromRGB(r, g, b), true)
		else
			render()
		end
	end)
	render()

	return {
		Instance = row,
		Set = function(_, nextValue, fire)
			set(nextValue, fire)
		end,
		Get = function()
			return value
		end,
	}
end

function Tab:AddKeybind(options)
	options = options or {}
	local defaultName = tostring(options.Default or "RightShift")
	local value = Enum.KeyCode[defaultName] or Enum.KeyCode.RightShift
	local capturing = false
	local row = createControlRow(self, 42)

	create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -154, 1, 0),
		Text = options.Name or "Keybind",
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = row,
	})

	local bindButton = create("TextButton", {
		Name = "BindButton",
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Paper,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(116, 26),
		Text = value.Name,
		TextColor3 = Theme.Ink,
		TextSize = 11,
		ZIndex = 10,
		Parent = row,
	})
	corner(bindButton, 1)
	stroke(bindButton, Theme.Line, 1, 0.45)

	local function finishCapture()
		capturing = false
		self.Window.CapturingKeybind = false
		bindButton.Text = value.Name
		bindButton.BackgroundColor3 = Theme.Paper
	end

	local function set(nextValue, fire)
		local keyCode = typeof(nextValue) == "EnumItem" and nextValue or Enum.KeyCode[tostring(nextValue)]
		if not keyCode or keyCode == Enum.KeyCode.Unknown then
			return false
		end
		value = keyCode
		finishCapture()
		if fire ~= false then
			invokeCallback(options.Callback, value.Name, value)
		end
		return true
	end

	bindButton.MouseButton1Click:Connect(function()
		capturing = true
		self.Window.CapturingKeybind = true
		bindButton.Text = "PRESS A KEY"
		bindButton.BackgroundColor3 = Theme.PaperShadow
	end)

	table.insert(
		self.Window.Connections,
		UserInputService.InputBegan:Connect(function(input)
			if not capturing or input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape then
				finishCapture()
				return
			end
			set(input.KeyCode, true)
		end)
	)

	return {
		Instance = row,
		Set = function(_, nextValue, fire)
			return set(nextValue, fire)
		end,
		Get = function()
			return value.Name
		end,
	}
end

function Tab:AddLabel(text)
	self.Order = self.Order + 1
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		LayoutOrder = self.Order,
		Size = UDim2.new(1, 0, 0, 30),
		Text = tostring(text or "Label"),
		TextColor3 = Theme.InkSoft,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = self.ActiveSection and self.ActiveSection.Body or self.Page,
	})
	return label
end

function Window:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	for _, connection in ipairs(self.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self.Connections)
	if self.Screen then
		self.Screen:Destroy()
		self.Screen = nil
	end
	if self.Environment and self.Environment[ACTIVE_WINDOW_KEY] == self then
		self.Environment[ACTIVE_WINDOW_KEY] = nil
	end
end

Int3UI.Theme = Theme
return Int3UI
