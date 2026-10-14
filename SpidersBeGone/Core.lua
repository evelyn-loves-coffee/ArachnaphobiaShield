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
  * slash commands = classic two-part registration (SLASH_<GROUP>N globals +
    SlashCmdList["<GROUP>"] handler) — proven by the working Spoken addon on
    this exact client (Spoken_Books/Commands.lua); no CHAT_COMMAND event
  * GetUnitFamily/WorldFramePoint3D/GetUnitPosition absent (3D path closed)
  * UnitCreatureFamily works: wild spider -> ("Spider", 3)
  * UnitCanAttack is TWO-ARG here: UnitCanAttack(unit, target)
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
	-- Defensive dedupe: print at most once per 0.25s regardless of how the
	-- command got invoked (slash, /run, double dispatch).
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
-- Registration is the classic two-part mechanism (confirmed by the working
-- Spoken addon on this exact client): SLASH_<GROUP>N globals declare the
-- typed command strings, SlashCmdList["<GROUP>"] is the handler and msg is
-- the rest of the line after the command word. Setting SlashCmdList alone
-- does NOT make the command known (client answers "Type /help..."), and
-- there is no CHAT_COMMAND event to register (RegisterEvent rejects it).
_G.SLASH_SPIDER1 = "/spider"
_G.SLASH_SPIDER2 = "/spidergone"

function SBeGone.Slash(msg)
	-- M2: bare command = selftest. Subcommands land with M3/M5
	-- (/spider clear, /spider off, /spider add <name>, ...).
	local first = string.match(msg or "", "^%s*(%S*)") or ""
	if first == "" then
		SBeGone.Selftest()
	elseif first == "clear" then
		print("SBG| nothing to clear yet (covers arrive in M3)")
	else
		print(("SBG| unknown subcommand '%s' — bare /spider = selftest"):format(first))
	end
end

SlashCmdList["SPIDER"] = function(msg)
	SBeGone.Slash(msg)
end
