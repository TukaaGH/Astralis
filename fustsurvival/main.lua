local context = ...
if type(context) ~= "table" or context.schemaVersion ~= 1 or type(context.load) ~= "function" then
	error("Astralis: start this game through mainloader.lua.", 0)
end
if game.GameId ~= 10769082317 then
	error("Astralis: this build requires Fust Survival.", 0)
end

return context.load(context.root .. "fustsurvival/obfuscated.lua")
