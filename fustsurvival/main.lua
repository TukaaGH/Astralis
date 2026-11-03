local context = ...
if type(context) ~= "table" or context.schemaVersion ~= 1 or type(context.load) ~= "function"
    or type(context.root) ~= "string" then error("L1", 0) end
if game.GameId ~= 10769082317 then error("L2", 0) end
local ready = context.load(context.root .. "fustsurvival/emulator.lua", context)
if ready ~= true then error("L3", 0) end
return context.load(context.root .. "fustsurvival/obfuscated.lua")
