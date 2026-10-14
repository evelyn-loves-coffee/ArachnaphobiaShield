-- Offline smoke test for SpidersBeGone (M2 skeleton).
-- Run from the repo root:  lua5.1 tools/test_core.lua
-- Stubs the minimal client API surface, loads the addon's Core.lua, and
-- exercises the slash dispatch paths. Exit code 0 = all pass.
local t = 0
GetBuildInfo = function() return "1.60.1", "70374", "Oct 12 2026", "16001" end
GetTime = function() t = t + 0.3; return t end
CreateFrame = function()
	return { RegisterEvent = function() end, SetScript = function() end }
end
SlashCmdList = {}
SBeGoneSettings = nil

dofile("SpidersBeGone/Core.lua")

-- Registration (two-part, Spoken-verified pattern; see docs/PLAN.md §4.3)
assert(SlashCmdList["SPIDER"], "SlashCmdList['SPIDER'] handler missing")
assert(_G.SLASH_SPIDER1 == "/spider", "SLASH_SPIDER1 missing")
assert(_G.SLASH_SPIDER2 == "/spidergone", "SLASH_SPIDER2 missing")

local function capture(fn)
	local out, real = {}, print
	print = function(s) out[#out + 1] = tostring(s) end
	fn()
	print = real
	return out
end

local out = capture(function() SlashCmdList["SPIDER"]("") end)
assert(#out == 2 and out[1]:find("^SBG| v") and out[2]:find("^SBG| enabled="),
	"bare /spider should print 2 selftest lines, got: " .. table.concat(out, " / "))
print("PASS: bare /spider -> 2 selftest lines")

out = capture(function() SlashCmdList["SPIDER"]("clear") end)
assert(#out == 1 and out[1]:find("nothing to clear"),
	"/spider clear wrong: " .. table.concat(out, " / "))
print("PASS: /spider clear")

out = capture(function() SlashCmdList["SPIDER"]("bogus") end)
assert(#out == 1 and out[1]:find("unknown subcommand"),
	"unknown subcommand wrong: " .. table.concat(out, " / "))
print("PASS: unknown subcommand")

out = capture(function() SlashCmdList["SPIDER"](nil) end)
assert(#out == 2, "nil msg (bare /spidergone) should selftest, got " .. #out .. " lines")
print("PASS: nil msg -> selftest")

assert(SBeGoneSettings and SBeGoneSettings.enabled == true, "settings defaults wrong")
print("PASS: SavedVariables defaults")

print("ALL CORE TESTS PASS")
