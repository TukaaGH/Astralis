export type Geometry = { cframe: CFrame, size: Vector3 }
export type State = {
    model: Instance?,
    parts: { BasePart | Geometry }?,
    bounds: Geometry?,
    position: Vector3?,
    name: string?,
    weapon: any?,
    health: number?,
    maxHealth: number?,
    distance: number?,
    color: Color3?,
    active: boolean?,
    [string]: any,
}
export type Adapter = { resolve: (target: any, handle: any) -> State? }
export type Source = {
    list: () -> { any },
    subscribe: ((add: (any) -> (), remove: (any) -> ()) -> any)?,
}

local ESP = { version = 4, adapters = {}, sources = {}, utils = {} }
local Controller = {}
Controller.__index = Controller
local Handle = {}
Handle.__index = Handle
local Context = {}
Context.__index = Context

local CORNERS = {
    { -1, -1, -1 },
    { 1, -1, -1 },
    { -1, 1, -1 },
    { 1, 1, -1 },
    { -1, -1, 1 },
    { 1, -1, 1 },
    { -1, 1, 1 },
    { 1, 1, 1 },
}
local EDGES = {
    { 1, 2 },
    { 1, 3 },
    { 2, 4 },
    { 3, 4 },
    { 5, 6 },
    { 5, 7 },
    { 6, 8 },
    { 7, 8 },
    { 1, 5 },
    { 2, 6 },
    { 3, 7 },
    { 4, 8 },
}

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function merge(base, patch)
    local result = table.clone(base or {})
    for key, value in pairs(patch or {}) do
        result[key] = value
    end
    return result
end

local function read(value, context, fallback)
    if type(value) == "function" then
        return value(context)
    end
    if value ~= nil then
        return value
    end
    return fallback
end

local function geometryOf(item)
    if typeof(item) == "Instance" then
        if item:IsA("BasePart") then
            return { cframe = item.CFrame, size = item.Size }
        end
        return nil
    end
    if type(item) == "table" and item.cframe and item.size then
        return item
    end
    return nil
end

local function cornersOf(geometry)
    local result = {}
    for index, signs in ipairs(CORNERS) do
        result[index] = geometry.cframe
            * Vector3.new(
                geometry.size.X * signs[1] / 2,
                geometry.size.Y * signs[2] / 2,
                geometry.size.Z * signs[3] / 2
            )
    end
    return result
end
function ESP.utils.findPath(root, path)
    local current = root
    for _, name in ipairs(path) do
        if not current then
            return nil
        end
        current = current:FindFirstChild(name)
    end
    return current
end

function ESP.utils.selectParts(root, options)
    options = options or {}
    if not root then
        return {}
    end
    local result, seen = {}, {}
    local function include(part)
        if part and part:IsA("BasePart") and not seen[part] and (not options.predicate or options.predicate(part)) then
            seen[part] = true
            table.insert(result, part)
        end
    end
    if options.paths then
        for _, path in ipairs(options.paths) do
            include(ESP.utils.findPath(root, path))
        end
    else
        include(root)
        local children = options.recursive == false and root:GetChildren() or root:GetDescendants()
        for _, child in ipairs(children) do
            include(child)
        end
    end
    return result
end
function ESP.utils.boundsOfParts(parts, reference)
    reference = reference or CFrame.new()
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    for _, item in ipairs(parts) do
        local geometry = geometryOf(item)
        if geometry then
            for _, corner in ipairs(cornersOf(geometry)) do
                local point = reference:PointToObjectSpace(corner)
                minX, minY, minZ = math.min(minX, point.X), math.min(minY, point.Y), math.min(minZ, point.Z)
                maxX, maxY, maxZ = math.max(maxX, point.X), math.max(maxY, point.Y), math.max(maxZ, point.Z)
            end
        end
    end
    if minX == math.huge then
        return nil
    end
    local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
    return {
        cframe = reference * CFrame.new(center),
        size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ),
    }
end
function ESP.utils.project(camera, geometries, nearPlane)
    nearPlane = nearPlane or 0.05
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local function include(point)
        if finite(point.X) and finite(point.Y) then
            minX, minY = math.min(minX, point.X), math.min(minY, point.Y)
            maxX, maxY = math.max(maxX, point.X), math.max(maxY, point.Y)
        end
    end
    for _, item in ipairs(geometries) do
        local geometry = geometryOf(item)
        if geometry then
            local world, projected = cornersOf(geometry), {}
            for index, corner in ipairs(world) do
                local point = camera:WorldToViewportPoint(corner)
                projected[index] = point
                if point.Z >= nearPlane then
                    include(point)
                end
            end
            for _, edge in ipairs(EDGES) do
                local first, second = projected[edge[1]], projected[edge[2]]
                if (first.Z >= nearPlane) ~= (second.Z >= nearPlane) then
                    local alpha = (nearPlane - first.Z) / (second.Z - first.Z)
                    include(camera:WorldToViewportPoint(world[edge[1]]:Lerp(world[edge[2]], alpha)))
                end
            end
        end
    end
    local viewport = camera.ViewportSize
    if
        minX == math.huge
        or maxX <= minX
        or maxY <= minY
        or maxX < 0
        or maxY < 0
        or minX > viewport.X
        or minY > viewport.Y
    then
        return nil
    end
    return { position = Vector2.new(minX, minY), size = Vector2.new(maxX - minX, maxY - minY) }
end
function ESP.adapters.model(options)
    options = options or {}
    return {
        resolve = function(target, handle)
            local model
            if options.getModel then
                model = options.getModel(target, handle)
            else
                model = target
            end
            if not model then
                return nil
            end
            local function provider(name, fallback)
                if options[name] then
                    return options[name](target, model, handle)
                end
                return fallback()
            end
            local state = { model = model }
            state.bounds = provider("getBounds", function()
                return nil
            end)
            if not state.bounds then
                state.parts = provider("getParts", function()
                    return ESP.utils.selectParts(model, options.parts)
                end)
            end
            local root = provider("getRoot", function()
                if model:IsA("BasePart") then
                    return model
                end
                return model:IsA("Model") and model.PrimaryPart or nil
            end)
            state.position = provider("getPosition", function()
                return root and root.Position or nil
            end)
            state.name = provider("getName", function()
                return model.Name
            end)
            state.weapon = provider("getWeapon", function()
                return nil
            end)
            state.color = provider("getColor", function()
                return nil
            end)
            state.distance = provider("getDistance", function()
                return nil
            end)
            if options.getHealth then
                state.health, state.maxHealth = options.getHealth(target, model, handle)
            elseif options.useHumanoid ~= false then
                local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
                if humanoid then
                    state.health, state.maxHealth = humanoid.Health, humanoid.MaxHealth
                end
            end
            state.active = provider("isActive", function()
                return state.health == nil or state.health > 0
            end)
            return state
        end,
    }
end

function ESP.adapters.player(options)
    options = table.clone(options or {})
    if not options.getModel then
        options.getModel = function(player)
            return player.Character
        end
    end
    if not options.getName then
        options.getName = function(player)
            return player.DisplayName
        end
    end
    if not options.getWeapon then
        options.getWeapon = function(_, model)
            local tool = model:FindFirstChildWhichIsA("Tool")
            return tool and tool.Name or nil
        end
    end
    return ESP.adapters.model(options)
end

function ESP.adapters.snapshot(resolve)
    assert(type(resolve) == "function", "snapshot adapter requires a resolver")
    return { resolve = resolve }
end

function ESP.sources.players(players, includeLocalPlayer)
    players = players or game:GetService("Players")
    local function accept(player)
        return includeLocalPlayer == true or player ~= players.LocalPlayer
    end
    return {
        list = function()
            local result = {}
            for _, player in ipairs(players:GetPlayers()) do
                if accept(player) then
                    table.insert(result, player)
                end
            end
            return result
        end,
        subscribe = function(add, remove)
            local added = players.PlayerAdded:Connect(function(player)
                if accept(player) then
                    add(player)
                end
            end)
            local removed = players.PlayerRemoving:Connect(remove)
            return function()
                added:Disconnect()
                removed:Disconnect()
            end
        end,
    }
end
function ESP.sources.children(container, predicate)
    return {
        list = function()
            local result = {}
            for _, child in ipairs(container:GetChildren()) do
                if not predicate or predicate(child) then
                    table.insert(result, child)
                end
            end
            return result
        end,
    }
end

local DEFAULT_FEATURES = {
    box = { enabled = true },
    name = { enabled = true },
    distance = { enabled = true },
    healthbar = { enabled = true },
    weapon = { enabled = false },
}

function Context:createDrawing(kind, properties)
    assert(self._group, "createDrawing is only available during feature.create")
    local drawing = self.controller._drawingFactory(kind)
    table.insert(self._group.all, drawing)
    drawing.Visible = false
    for key, value in pairs(properties or {}) do
        drawing[key] = value
    end
    return drawing
end

function Context:reserveLabel(side, height, gap)
    assert(side == "above" or side == "below", "label side must be above or below")
    local top, size = self.rect.position, self.rect.size
    local offset = self._layout[side]
    self._layout[side] = offset + height + (gap or 2)
    if side == "above" then
        return Vector2.new(top.X + size.X / 2, top.Y - offset - height)
    end
    return Vector2.new(top.X + size.X / 2, top.Y + size.Y + offset)
end

local function applyText(drawing, context, options, text, side)
    local fontSize = options.size or context.controller.textSize
    drawing.Text = tostring(text)
    drawing.Size = fontSize
    drawing.Font = options.font or context.controller.font
    drawing.Center = true
    drawing.Outline = options.outline ~= false
    drawing.OutlineColor = read(options.outlineColor, context, Color3.new(0, 0, 0))
    drawing.Color = read(options.color, context, context.state.color or Color3.new(1, 1, 1))
    drawing.Transparency = options.transparency or 1
    drawing.Position = context:reserveLabel(options.side or side, fontSize, options.gap)
        + (options.offset or Vector2.new())
    drawing.Visible = true
end

local function textFeature(order, resolve, side)
    return {
        order = order,
        managesVisibility = true,
        create = function(context)
            return { text = context:createDrawing("Text", { ZIndex = 2 }) }
        end,
        render = function(context, drawings, options)
            local text = resolve(context, options)
            if text ~= nil and text ~= "" then
                applyText(drawings.text, context, options, text, side)
            else
                drawings.text.Visible = false
            end
        end,
    }
end

local function builtins()
    return {
        box = {
            order = 10,
            managesVisibility = true,
            create = function(context)
                return {
                    outline = context:createDrawing("Square", { ZIndex = 1, Filled = false }),
                    box = context:createDrawing("Square", { ZIndex = 2, Filled = false }),
                }
            end,
            render = function(context, drawings, options)
                local thickness = options.thickness or 1
                for _, drawing in pairs(drawings) do
                    drawing.Position, drawing.Size = context.rect.position, context.rect.size
                end
                drawings.box.Color = read(options.color, context, context.state.color or Color3.new(1, 1, 1))
                drawings.box.Thickness, drawings.box.Filled = thickness, options.filled == true
                drawings.box.Transparency = options.transparency or 1
                drawings.box.Visible = true
                drawings.outline.Color = read(options.outlineColor, context, Color3.new(0, 0, 0))
                drawings.outline.Thickness = thickness + 2
                drawings.outline.Transparency = options.transparency or 1
                drawings.outline.Visible = options.outline ~= false
            end,
        },
        name = textFeature(30, function(context, options)
            return read(options.text, context, context.state.name)
        end, "above"),
        weapon = textFeature(40, function(context, options)
            local value = read(options.text, context, context.state.weapon)
            if value == nil then
                value = options.emptyText or "none"
            end
            if typeof(value) == "Instance" then
                value = value.Name
            end
            value = tostring(value)
            return options.lowerCase == false and value or string.lower(value)
        end, "below"),
        distance = textFeature(50, function(context, options)
            local value = read(options.value, context, context.distance)
            if not finite(value) then
                return nil
            end
            if options.format then
                return options.format(value, context)
            end
            return string.format("[%d]", math.round(value))
        end, "below"),
        healthbar = {
            order = 20,
            managesVisibility = true,
            create = function(context)
                return {
                    background = context:createDrawing("Square", { Filled = true, ZIndex = 1 }),
                    bar = context:createDrawing("Square", { Filled = true, ZIndex = 2 }),
                }
            end,
            render = function(context, drawings, options)
                local health, maximum = context.state.health, context.state.maxHealth
                if options.value then
                    health, maximum = options.value(context)
                end
                if not finite(health) or not finite(maximum) or maximum <= 0 then
                    drawings.background.Visible = false
                    drawings.bar.Visible = false
                    return
                end
                local ratio = math.clamp(health / maximum, 0, 1)
                local width, gap = options.width or 3, options.gap or 3
                local height = context.rect.size.Y
                local x = context.rect.position.X - gap - width
                if options.side == "right" then
                    x = context.rect.position.X + context.rect.size.X + gap
                end
                local top = Vector2.new(x, context.rect.position.Y) + (options.offset or Vector2.new())
                local inset = math.min(1, width / 2, height / 2)
                local length = math.max(0, height - inset * 2) * ratio
                drawings.background.Position, drawings.background.Size = top, Vector2.new(width, height)
                drawings.background.Color = read(options.backgroundColor, context, Color3.new(0.24, 0.24, 0.24))
                drawings.background.Transparency = options.backgroundTransparency or 0.7
                drawings.background.Visible = true
                drawings.bar.Position = top + Vector2.new(inset, height - inset - length)
                drawings.bar.Size = Vector2.new(math.max(0, width - inset * 2), length)
                local low = read(options.lowColor, context, Color3.new(1, 0, 0))
                local high = read(options.highColor, context, Color3.new(0, 1, 0))
                drawings.bar.Color = read(options.color, context, low:Lerp(high, ratio))
                drawings.bar.Transparency = options.transparency or 1
                drawings.bar.Visible = length > 0
            end,
        },
    }
end

local function hideGroup(group)
    for _, drawing in ipairs(group.all) do
        pcall(function()
            drawing.Visible = false
        end)
    end
end

local function destroyGroup(group)
    for _, drawing in ipairs(group.all) do
        pcall(function()
            drawing.Visible = false
        end)
        pcall(function()
            drawing:Remove()
        end)
    end
    table.clear(group.all)
end

function Controller:_report(stage, problem, handle, feature)
    local cache = handle and handle._errors or self._errors
    local key = stage .. ":" .. (feature or "")
    local prior = cache[key]
    if prior and self._time - prior.time < 1 and prior.problem == tostring(problem) then
        return
    end
    cache[key] = { time = self._time, problem = tostring(problem) }
    if self.onError then
        pcall(self.onError, stage, problem, handle and handle.target, feature)
    end
end

function ESP.new(options)
    options = options or {}
    local self = setmetatable({
        adapter = options.adapter or ESP.adapters.model(),
        source = options.source,
        features = {},
        _definitions = {},
        _ordered = {},
        _handles = {},
        _sourceTargets = {},
        _time = 0,
        _reconcileElapsed = 0,
        _errors = {},
        _running = false,
        _destroyed = false,
        _renderConnection = nil,
        _sourceCleanup = nil,
        enabled = options.enabled ~= false,
        resolveInterval = options.resolveInterval == nil and 0.1 or options.resolveInterval,
        reconcileInterval = options.reconcileInterval == nil and 1 or options.reconcileInterval,
        nearPlane = options.nearPlane or 0.05,
        maxDistance = options.maxDistance or math.huge,
        filter = options.filter,
        onError = options.onError,
        cameraProvider = options.cameraProvider or function()
            return workspace.CurrentCamera
        end,
        runService = options.runService,
        _drawingFactory = options.drawingFactory or function(kind)
            return Drawing.new(kind)
        end,
        font = options.font or 1,
        textSize = options.textSize or 13,
    }, Controller)
    assert(type(self.adapter.resolve) == "function", "adapter.resolve is required")
    assert(finite(self.resolveInterval) and self.resolveInterval >= 0, "resolveInterval must be nonnegative")
    assert(finite(self.reconcileInterval) and self.reconcileInterval >= 0, "reconcileInterval must be nonnegative")
    assert(finite(self.nearPlane) and self.nearPlane > 0, "nearPlane must be positive")
    for name, definition in pairs(builtins()) do
        self:registerFeature(name, definition)
    end
    for name, settings in pairs(DEFAULT_FEATURES) do
        self.features[name] = table.clone(settings)
    end
    for name, settings in pairs(options.features or {}) do
        self:setFeature(name, settings)
    end
    return self
end

function Controller:registerFeature(name, definition)
    assert(not self._destroyed, "controller is destroyed")
    assert(type(name) == "string" and not self._definitions[name], "feature name must be new")
    assert(
        type(definition.create) == "function" and type(definition.render) == "function",
        "feature requires create and render"
    )
    self._definitions[name] = definition
    table.insert(self._ordered, name)
    table.sort(self._ordered, function(a, b)
        local first, second = self._definitions[a].order or 100, self._definitions[b].order or 100
        return first == second and a < b or first < second
    end)
    return self
end

function Controller:unregisterFeature(name)
    self._definitions[name], self.features[name] = nil, nil
    local index = table.find(self._ordered, name)
    if index then
        table.remove(self._ordered, index)
    end
    for _, handle in pairs(self._handles) do
        local group = handle._groups[name]
        if group then
            destroyGroup(group)
            handle._groups[name] = nil
        end
        handle.features[name] = nil
    end
    return self
end

function Controller:setFeature(name, settings)
    assert(not self._destroyed, "controller is destroyed")
    assert(self._definitions[name], "register a feature before configuring it: " .. name)
    if settings == nil then
        self.features[name] = table.clone(DEFAULT_FEATURES[name] or { enabled = false })
    elseif type(settings) == "boolean" then
        self.features[name] = merge(self.features[name], { enabled = settings })
    else
        assert(type(settings) == "table", "feature settings must be a boolean or table")
        self.features[name] = merge(self.features[name], settings)
    end
    return self
end

function Controller:_add(target, options, manual)
    assert(not self._destroyed, "controller is destroyed")
    assert(target ~= nil, "target cannot be nil")
    local existing = self._handles[target]
    if existing then
        if manual then
            existing._manual = true
        end
        if options then
            existing:configure(options)
        end
        return existing
    end
    options = options or {}
    local handle = setmetatable({
        controller = self,
        target = target,
        data = options.data or {},
        features = {},
        adapter = options.adapter,
        filter = options.filter,
        enabled = options.enabled ~= false,
        maxDistance = options.maxDistance,
        resolveInterval = options.resolveInterval,
        state = nil,
        _manual = manual,
        _pushed = false,
        _dirty = true,
        _elapsed = 0,
        _groups = {},
        _errors = {},
        _removed = false,
    }, Handle)
    self._handles[target] = handle
    local ok, problem = pcall(function()
        handle:configure(options)
    end)
    if not ok then
        self._handles[target] = nil
        error(problem, 2)
    end
    return handle
end

function Controller:add(target, options)
    return self:_add(target, options, true)
end
function Controller:get(target)
    return self._handles[target]
end
function Controller:getHandles()
    local result = {}
    for _, handle in pairs(self._handles) do
        table.insert(result, handle)
    end
    return result
end

function Controller:remove(target)
    local handle = self._handles[target]
    if not handle then
        return
    end
    self._handles[target], self._sourceTargets[target] = nil, nil
    handle._removed = true
    handle:hide()
    for _, group in pairs(handle._groups) do
        destroyGroup(group)
    end
    table.clear(handle._groups)
    handle.state = nil
end

function Handle:configure(options)
    assert(not self._removed, "target is removed")
    if options.adapter then
        assert(type(options.adapter.resolve) == "function", "adapter.resolve is required")
        self.adapter = options.adapter
    end
    if options.enabled ~= nil then
        self.enabled = options.enabled
    end
    if options.data then
        self.data = options.data
    end
    if options.filter then
        self.filter = options.filter
    end
    if options.maxDistance ~= nil then
        self.maxDistance = options.maxDistance
    end
    if options.resolveInterval ~= nil then
        assert(finite(options.resolveInterval) and options.resolveInterval >= 0, "resolveInterval must be nonnegative")
        self.resolveInterval = options.resolveInterval
    end
    for name, settings in pairs(options.features or {}) do
        self:setFeature(name, settings)
    end
    self:refresh()
    return self
end

function Handle:setFeature(name, settings)
    assert(not self._removed, "target is removed")
    assert(self.controller._definitions[name], "unknown feature: " .. name)
    if settings == nil then
        self.features[name] = nil
    elseif type(settings) == "boolean" then
        self.features[name] = merge(self.features[name], { enabled = settings })
    else
        assert(type(settings) == "table", "feature settings must be a boolean or table")
        self.features[name] = merge(self.features[name], settings)
    end
    return self
end

function Handle:setState(state)
    assert(not self._removed, "target is removed")
    assert(state == nil or type(state) == "table", "state must be a table or nil")
    self._pushed, self._dirty, self.state = true, false, state
    return self
end

function Handle:useAdapter(adapter)
    assert(not self._removed, "target is removed")
    if adapter then
        assert(type(adapter.resolve) == "function", "adapter.resolve is required")
        self.adapter = adapter
    end
    self._pushed = false
    return self:refresh()
end

function Handle:refresh()
    assert(not self._removed, "target is removed")
    self._dirty = true
    return self
end
function Handle:hide()
    for _, group in pairs(self._groups) do
        hideGroup(group)
    end
end
function Handle:remove()
    if not self._removed then
        self.controller:remove(self.target)
    end
end

function Controller:reconcile()
    assert(not self._destroyed, "controller is destroyed")
    if not self.source then
        return
    end
    local ok, targets = pcall(self.source.list)
    if not ok or type(targets) ~= "table" then
        self:_report("source.list", ok and "list must return an array" or targets)
        return
    end
    local nextTargets = {}
    for _, target in ipairs(targets) do
        nextTargets[target] = true
        self:_add(target, nil, false)
    end
    local stale = {}
    for target in pairs(self._sourceTargets) do
        if not nextTargets[target] then
            table.insert(stale, target)
        end
    end
    for _, target in ipairs(stale) do
        local handle = self._handles[target]
        if handle and not handle._manual then
            self:remove(target)
        end
    end
    self._sourceTargets = nextTargets
    self._reconcileElapsed = 0
end

function Controller:_renderFeature(handle, name, context)
    local definition = self._definitions[name]
    if not definition then
        return
    end
    local options = merge(self.features[name], handle.features[name])
    local group = handle._groups[name]
    local ok, problem = pcall(function()
        if not read(options.enabled, context, false) then
            if group then
                hideGroup(group)
            end
            return
        end
        if handle._removed or self._definitions[name] ~= definition then
            return
        end
        if not group then
            group = { all = {} }
            handle._groups[name] = group
            context._group = group
            local created, drawings = pcall(definition.create, context)
            context._group = nil
            if not created then
                destroyGroup(group)
                if handle._groups[name] == group then
                    handle._groups[name] = nil
                end
                group = nil
                error(drawings, 0)
            end
            if handle._removed or self._definitions[name] ~= definition then
                destroyGroup(group)
                if handle._groups[name] == group then
                    handle._groups[name] = nil
                end
                return
            end
            group.drawings = drawings or {}
        end
        if not definition.managesVisibility then
            hideGroup(group)
        end
        definition.render(context, group.drawings, options)
    end)
    context._group = nil
    if not ok then
        if group then
            hideGroup(group)
        end
        self:_report("feature", problem, handle, name)
    end
end

function Controller:_stepHandle(handle, camera, delta)
    if not self.enabled or not handle.enabled or handle._removed then
        return
    end
    handle._elapsed += delta
    local interval = handle.resolveInterval or self.resolveInterval
    if not handle._pushed and (handle._dirty or handle._elapsed >= interval) then
        handle._elapsed, handle._dirty = 0, false
        local adapter = handle.adapter or self.adapter
        local ok, state = pcall(adapter.resolve, handle.target, handle)
        if not ok or (state ~= nil and type(state) ~= "table") then
            handle.state = nil
            self:_report("adapter.resolve", ok and "resolver must return a table or nil" or state, handle)
            return
        end
        if handle._removed then
            return
        end
        handle.state = state
    end
    local state = handle.state
    if not state or state.active == false then
        return
    end
    if self.filter and not self.filter(handle.target, state, handle) then
        return
    end
    if handle.filter and not handle.filter(handle.target, state, handle) then
        return
    end
    if handle._removed then
        return
    end
    local geometries = state.bounds and { state.bounds } or state.parts or {}
    local rect = ESP.utils.project(camera, geometries, self.nearPlane)
    if not rect then
        return
    end
    local distance = state.distance
    if distance == nil then
        local position = state.position
        if not position then
            local bounds = state.bounds or ESP.utils.boundsOfParts(geometries)
            position = bounds and bounds.cframe.Position
        end
        if position then
            distance = (camera.CFrame.Position - position).Magnitude
        end
    end
    local limit = handle.maxDistance or self.maxDistance
    if finite(distance) and distance > limit then
        return
    end
    local context = setmetatable({
        controller = self,
        handle = handle,
        target = handle.target,
        data = handle.data,
        state = state,
        camera = camera,
        rect = rect,
        distance = distance,
        _layout = { above = 2, below = 2 },
    }, Context)
    for _, name in ipairs(table.clone(self._ordered)) do
        if handle._removed then
            break
        end
        self:_renderFeature(handle, name, context)
    end
    return true
end

function Controller:step(delta)
    assert(not self._destroyed, "controller is destroyed")
    delta = delta or 0
    assert(finite(delta) and delta >= 0, "delta must be nonnegative")
    self._time += delta
    self._reconcileElapsed += delta
    if self.source and self._reconcileElapsed >= self.reconcileInterval then
        self:reconcile()
    end
    local ok, camera = pcall(self.cameraProvider)
    if not ok then
        self:_report("camera", camera)
    end
    for _, handle in ipairs(self:getHandles()) do
        if not camera or not ok then
            handle:hide()
        else
            local rendered, result = pcall(self._stepHandle, self, handle, camera, delta)
            if not rendered then
                handle:hide()
                self:_report("target", result, handle)
            elseif result ~= true then
                handle:hide()
            end
        end
    end
end

local function cleanup(resource)
    if type(resource) == "function" then
        resource()
    elseif resource then
        resource:Disconnect()
    end
end

function Controller:start()
    assert(not self._destroyed, "controller is destroyed")
    if self._running then
        return self
    end
    self._running = true
    local ok, problem = pcall(function()
        if self.source and self.source.subscribe then
            self._sourceCleanup = self.source.subscribe(function(target)
                if not self._running or self._destroyed then
                    return
                end
                self._sourceTargets[target] = true
                self:_add(target, nil, false)
            end, function(target)
                if not self._running or self._destroyed then
                    return
                end
                self._sourceTargets[target] = nil
                local handle = self._handles[target]
                if handle and not handle._manual then
                    self:remove(target)
                end
            end)
        end
        self:reconcile()
        local service = self.runService or game:GetService("RunService")
        self._renderConnection = service.RenderStepped:Connect(function(delta)
            self:step(delta)
        end)
    end)
    if not ok then
        self:stop()
        error(problem, 2)
    end
    return self
end

function Controller:stop()
    self._running = false
    local render, subscription = self._renderConnection, self._sourceCleanup
    self._renderConnection, self._sourceCleanup = nil, nil
    local ok, problem = pcall(cleanup, render)
    if not ok then
        self:_report("cleanup.render", problem)
    end
    ok, problem = pcall(cleanup, subscription)
    if not ok then
        self:_report("cleanup.source", problem)
    end
    for _, handle in pairs(self._handles) do
        handle:hide()
    end
    return self
end

function Controller:destroy()
    if self._destroyed then
        return
    end
    self:stop()
    for _, handle in ipairs(self:getHandles()) do
        self:remove(handle.target)
    end
    table.clear(self._definitions)
    table.clear(self._ordered)
    table.clear(self._sourceTargets)
    table.clear(self._errors)
    self._destroyed = true
end

return ESP, ESP.version
