local context = ...
if type(context) ~= "table" or context.schemaVersion ~= 1 or type(context.load) ~= "function"
    or type(context.root) ~= "string" or type(context.setEnvironment) ~= "function" then
    error("Astralis: start this build through the Astralis loader.", 0)
end
if game.GameId ~= 10769082317 then error("Astralis: this build requires Fust Survival.", 0) end
local create = context.load(context.root .. "assets/executorApi.lua")
if type(create) ~= "function" then error("Astralis: executor adapter could not be loaded.", 0) end
local environment, missing = create(getfenv(1))
if not environment then error("Astralis: " .. tostring(context.executor) .. " is missing " .. tostring(missing) .. ".", 0) end
context.setEnvironment(environment)
local ready = context.load(context.root .. "fustsurvival/emulator.lua", context)
if ready ~= true then error("Astralis: emulator initialization did not complete.", 0) end
return context.load(context.root .. "fustsurvival/obfuscated.lua")
