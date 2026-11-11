local support = {
    ["executors"] = {
        ["real"] = "Real",
        ["potassium"] = "Potassium",
        ["volt"] = "Volt",
        ["madium"] = "Madium",
    },
    ["games"] = {
        ["Fust Survival"] = {
            ["name"] = "Fust Survival",
            ["status"] = "Working",
            ["executors"] = {
                ["Real"] = "Broken",
                ["Potassium"] = "Working",
                ["Volt"] = "Broken",
                ["Madium"] = "Broken",
            },
        },
        ["Ink Game"] = {
            ["name"] = "Ink Game",
            ["status"] = "Working",
            ["executors"] = {
                ["Real"] = "Working",
                ["Potassium"] = "Working",
                ["Volt"] = "Working",
                ["Madium"] = "Working",
            },
        },
    },
}

return function(environment, gameName)
    local game = environment.game
    if not game:IsLoaded() then game.Loaded:Wait() end
    local players = game:GetService("Players")
    while not players.LocalPlayer do players:GetPropertyChangedSignal("LocalPlayer"):Wait() end
    local function stop(message)
        players.LocalPlayer:Kick(message)
    end
    local identify = environment.identifyexecutor or environment.getexecutorname
    local identified, detected = false, "Unknown"
    if type(identify) == "function" then identified, detected = pcall(identify) end
    local key = identified and type(detected) == "string" and (detected:lower():match("^%s*([%a]+)%s*$") or detected:lower():match("^%s*([%a]+)%s+v?%d[%w%.%-]*%s*$"))
    local executor = key and support.executors[key]
    if not executor then
        stop(tostring(type(detected) == "string" and detected or "Unknown") .. " is not supported by Astralis.")
        return
    end
    local gameInfo = support.games[gameName]
    if not gameInfo then error("Astralis: support configuration is unavailable.", 0) end
    local status = gameInfo.executors[executor]
    if status == "Broken" then
        stop(executor .. " is BROKEN for " .. gameName .. " in Astralis.")
        return
    end
    if status ~= "Working" then
        stop(executor .. " is not supported for " .. gameName .. " in Astralis.")
        return
    end
    if gameInfo.status ~= "Working" then
        stop(gameName .. " is currently " .. tostring(gameInfo.status) .. " in Astralis.")
        return
    end

    local createAdapter = assert(environment.loadstring(game:HttpGet("https://raw.githubusercontent.com/TukaaGH/Astralis/main/assets/executorApi.lua"), "=Astralis/Executor"))()
    local nativeEnvironment, missing = createAdapter(environment)
    if not nativeEnvironment then error("Astralis: " .. executor .. " is missing " .. tostring(missing) .. ".",0) end
    return nativeEnvironment
end
