local context = ...
if type(context) ~= "table" or context.schemaVersion ~= 1 or type(context.load) ~= "function" then
	error("Astralis: start this game through betaloader.lua.", 0)
end
if game.GameId ~= 10769082317 then
	error("Astralis: this build requires Fust Survival.", 0)
end

local player = game:GetService("Players").LocalPlayer
local scripts = player and player:WaitForChild("PlayerScripts", 30)
if not scripts or not scripts:WaitForChild("FustGuns", 30) or not scripts:WaitForChild("FustGather", 30)
	or not scripts:WaitForChild("FustCombat", 30) then
	error("Astralis: Fust controllers are not ready. Retry after spawning.", 0)
end

return context.load(context.root .. "fustsurvival/obfuscated-beta.lua")
