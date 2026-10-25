local repositoryRoot = "https://raw.githubusercontent.com/TukaaGH/Astralis/"

local function fail(message)
	error("Astralis: " .. message, 0)
end

if type(loadstring) ~= "function" or type(getgenv) ~= "function" then
	fail("this executor must provide loadstring and getgenv.")
end

local identify = identifyexecutor or getexecutorname
local identified, executor = false, nil
if type(identify) == "function" then
	identified, executor = pcall(identify)
end
if not identified or type(executor) ~= "string" then
	fail("could not identify the executor.")
end

local requestFunction = request or http_request or httprequest
if type(requestFunction) ~= "function" then
	for _, provider in pairs({ syn = syn, http = http, fluxus = fluxus }) do
		if type(provider) == "table" and type(provider.request) == "function" then
			requestFunction = provider.request
			break
		end
	end
end

local function fetch(url)
	local ok, body
	if type(requestFunction) == "function" then
		local response
		ok, response = pcall(requestFunction, { Url = url, Method = "GET" })
		if not ok then
			fail("download failed. Check your connection and retry.")
		end
		local status = type(response) == "table" and tonumber(response.StatusCode)
		if not status or status < 200 or status >= 300 or response.Success == false then
			fail("download returned HTTP " .. tostring(status or "unknown") .. ".")
		end
		body = response.Body
	else
		ok, body = pcall(function()
			return game:HttpGet(url)
		end)
		if not ok then
			fail("download failed. Check your connection and retry.")
		end
	end
	if type(body) ~= "string" or not body:find("%S") or body:match("^%s*<") then
		fail("the server returned an invalid script response.")
	end
	return body
end

local function execute(url, ...)
	local compiled, chunk = pcall(loadstring, fetch(url), "=Astralis/loader")
	if not compiled or type(chunk) ~= "function" then
		fail("the downloaded script could not be compiled.")
	end
	local ok, result = pcall(chunk, ...)
	if not ok then
		fail("initialization failed: " .. tostring(result))
	end
	return result
end

local deadline = os.clock() + 60
while not game:IsLoaded() do
	if os.clock() >= deadline then
		fail("the game has not finished loading. Retry after joining.")
	end
	task.wait(0.1)
end
local players = game:GetService("Players")
deadline = os.clock() + 30
while not players.LocalPlayer do
	if os.clock() >= deadline then
		fail("the local player is not ready. Retry after joining.")
	end
	task.wait(0.1)
end

local registry = execute(repositoryRoot .. "main/supportedGames.lua")
if type(registry) ~= "table" or registry.schemaVersion ~= 1 or type(registry.games) ~= "table" then
	fail("the game registry is invalid.")
end

local selected
for _, entry in ipairs(registry.games) do
	if type(entry) == "table" then
		local gameMatches = type(entry.gameIDs) == "table" and table.find(entry.gameIDs, game.GameId)
		local placeMatches = type(entry.placeIDs) == "table" and table.find(entry.placeIDs, game.PlaceId)
		if gameMatches or placeMatches then
			selected = entry
			break
		end
	end
end
if not selected then
	fail("this game is not supported.")
end
if selected.enabled ~= true then
	fail(selected.gameName .. " is temporarily unavailable.")
end

local normalized = executor:lower():gsub("[%s%p]", "")
local canonical = type(selected.executorAliases) == "table" and selected.executorAliases[normalized]
if not canonical or type(selected.executors) ~= "table" or not table.find(selected.executors, canonical) then
	fail("unsupported executor: " .. executor .. ".")
end

local requirements = {
	{ "getgc", getgc },
	{ "getfenv", getfenv },
	{ "getupvalues", getupvalues or (debug and debug.getupvalues) },
	{ "setupvalue", setupvalue or (debug and debug.setupvalue) },
	{ "debug.getinfo", debug and debug.getinfo },
	{ "Drawing.new", Drawing and Drawing.new },
}
for _, requirement in ipairs(requirements) do
	if type(requirement[2]) ~= "function" then
		fail(canonical .. " is missing " .. requirement[1] .. ".")
	end
end

if type(selected.releaseRef) ~= "string" or not selected.releaseRef:match("^[%w_.-]+$") then
	fail("the release reference is invalid.")
end
if type(selected.gitPath) ~= "string" or not selected.gitPath:match("^[%w_-]+$") then
	fail("the game path is invalid.")
end
local releaseRoot = repositoryRoot .. selected.releaseRef .. "/"
return execute(releaseRoot .. selected.gitPath .. "/main.lua", {
	schemaVersion = 1,
	executor = canonical,
	game = selected,
	root = releaseRoot,
	load = execute,
})
