--[[ Spiders Be Gone — arachnophobia addon for World of Warcraft Forever.

M2 skeleton (load verification only): proves the addon loads on the
1.60.1 client (## Interface: 16001), that SavedVariables register, and
that the /spider slash command dispatches.

Invariants (see docs/PLAN.md):
  * globals: SBeGone (state) and SBeGoneSettings (SavedVariables) only
  * Lua 5.1 compatible (5.0-safe subset; no //, goto, table.pack, bitops)
  * no per-frame work in this milestone

Client facts confirmed by in-client probes (2026-10-13, docs/PLAN.md §2):
  * GetBuildInfo() -> "1.60.1", "70374", "Oct 12 2026", "16001" (4 strings)
  * modern codebase: SlashCmdList present; classic SLASH_ vars NOT relied on
  * GetUnitFamily/WorldFramePoint3D/GetUnitPosition absent (3D path closed)
  * UnitCreatureFamily works: wild spider -> ("Spider", 3)
]]

SBeGone = SBeGone or {}
SBeGone.version = "0.1.0"

-- ---------------------------------------------------------------- settings
-- SBeGoneSettings is the SavedVariables table (see .toc). Fill defaults
-- lazily so existing saves never break.
local function EnsureSettings()
	SBeGoneSettings = SBeGoneSettings or {}
	SBeGoneSettings.enabled = (SBeGoneSettings.enabled == nil) and true or SBeGoneSettings.enabled
end
EnsureSettings()

-- ------------------------------------------------------------- selftest
-- M2 verification: type /spider in-game. Also reachable without any
-- slash plumbing via: /run SBeGone.Selftest()
local lastSelftest = 0

function SBeGone.Selftest()
	-- Dedupe: the client may route the command through both SlashCmdList
	-- and CHAT_COMMAND; print once per invocation.
	local now = GetTime()
	if now - lastSelftest < 0.25 then
		return
	end
	lastSelftest = now
	local major, minor, patch, build = GetBuildInfo()
	print(("SBG| v%s | build %s %s %s | Lua %s"):format(
		SBeGone.version, tostring(major), tostring(minor), tostring(patch), tostring(_VERSION)))
	print(("SBG| enabled=%s | settings=%s | interface=%s"):format(
		tostring(SBeGoneSettings.enabled), tostring(type(SBeGoneSettings)), tostring(build)))
end

-- ------------------------------------------------------- slash commands
-- Route 1 (modern): SlashCmdList entry. Route 2: CHAT_COMMAND event.
-- Both funnel into SBeGone.Selftest; the 0.25s dedupe keeps output clean
-- whichever route(s) this client actually uses.
SlashCmdList.SBeGone = SBeGone.Selftest

local cmdFrame = CreateFrame("Frame")
cmdFrame:RegisterEvent("CHAT_COMMAND")
cmdFrame:SetScript("OnEvent", function(self, event, arg)
	local cmd = string.match(arg or "", "^%s*(%S+)")
	if cmd == "spider" or cmd == "spidergone" then
		SBeGone.Selftest()
	end
end)
