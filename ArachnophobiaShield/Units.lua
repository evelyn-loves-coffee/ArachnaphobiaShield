-- Arachnophobia Shield — Units.lua: the single spider predicate (M3).
-- Every "is this unit a spider?" decision goes through U.IsSpider.
ArachnophobiaShield = ArachnophobiaShield or {}

local U = {}
ArachnophobiaShield.Units = U
local A = ArachnophobiaShield.Access

-- Built-in name fragments (owner-maintained): generic spider vocabulary,
-- matched case-insensitively. They back up the primary family check for
-- units whose family read is unavailable. settings.namePatterns ADDS to this
-- list, never replaces it. Fail-open bias: covering a non-spider costs a
-- disc, missing a spider costs the whole point of the addon.
U.NAME_PATTERNS = {
	"spider", "tarantula", "webspinner", "silkspinner",
	"venomfang", "darkfang", "widow", "recluse",
	"skitterer", "creeper", "smolderweb", "webwood",
	"nerub", "crypt fiend", "Gloomweaver",
}

-- settings.namePatterns is ADDITIVE, never a replacement: the owner's
-- SavedVariables already holds the old two-entry list and settings migration
-- deliberately keeps valid user data, so treating it as the whole list would
-- silently drop "webwood", "skitterer", "nerub" and friends.
-- Cached because IsSpider runs ~10 Hz over every visible plate (Performance):
-- rebuilt only when the user list changes length.
local patCache, patStamp
local function namePatterns()
	local s = ArachnophobiaShieldSettings or {}
	local user = (type(s.namePatterns) == "table") and s.namePatterns or {}
	if patCache and patStamp == #user then return patCache end
	local out, seen = {}, {}
	local function add(frag)
		if type(frag) ~= "string" or frag == "" then return end
		frag = frag:lower()
		if not seen[frag] then
			seen[frag] = true
			out[#out + 1] = frag
		end
	end
	-- Built-in fragments first, then whatever the user added.
	for _, pat in ipairs(U.NAME_PATTERNS) do add(pat) end
	for _, pat in ipairs(user) do add(pat) end
	patCache, patStamp = out, #user
	return out
end

-- Spider predicate (PLAN §3.1). `unit` is a tracked unit token.
function U.IsSpider(unit)
	local s = ArachnophobiaShieldSettings or {}
	if not A.UnitReadable(unit) then return false end

	-- 1. Never cover players.
	--    AS14 (in-game 2026-10-15, probe P3): UnitClass on this client
	--    returns the unit's NAME for non-player units — hovering the test
	--    spider reported class="Young Night Web Spider". The old "UnitClass is
	--    non-nil => player" guard therefore rejected EVERY spider (P4:
	--    IsSpider=false on a confirmed family-3 unit). Guards now, in order:
	--    a) UnitIsPlayer, accepted only on a strict boolean `true` so an
	--       implementation that (like UnitClass) returns a name can never
	--       false-reject a spider;
	--    b) name equality with our own name (catches players when
	--       UnitIsPlayer is absent).
	if A.Query(UnitIsPlayer, unit) == true then
		return false
	end
	if UnitName then
		local uName = A.Query(UnitName, unit)
		if uName ~= nil and uName == A.Query(UnitName, "player") then
			return false
		end
	end

	-- 2. Primary: creature family "Spider" (id 3) — confirmed in-client
	--    (AS4) and on nameplate tokens (NP1, 2026-10-15). Language-
	--    independent; covers every creature the game itself files as Spider.
	local isSpider = false
	if UnitCreatureFamily then
		local _, famId = A.Query(UnitCreatureFamily, unit)
		if famId == 3 then
			isSpider = true
		end
	end

	-- 3. Fallback: name fragments + user extraNames (units reporting no
	--    family). Matching is case-INsensitive (the built-in fragments are
	--    lowercase, unit names are not) and uses plain find, never Lua pattern
	--    matching - these lists contain user data, "%", "-" and "(" are common
	--    in NPC names.
	if not isSpider then
		local name
		if UnitName then
			name = A.Query(UnitName, unit)
		elseif GetUnitName then
			name = A.Query(GetUnitName, unit)
		end
		if type(name) == "string" then
			local lower = name:lower()
			for _, pat in ipairs(namePatterns()) do
				if lower:find(pat, 1, true) then
					isSpider = true
					break
				end
			end
			if not isSpider then
				for _, extra in ipairs(s.extraNames or {}) do
					if type(extra) == "string" and lower == extra:lower() then
						isSpider = true
						break
					end
				end
			end
		end
	end

	if not isSpider then
		return false
	end

	-- 4. Level window.
	local lvl = A.Query(UnitLevel, unit)
	if type(lvl) ~= "number" then return false end
	local minL = (type(s.minLevel) == "number") and s.minLevel or 1
	local maxL = (type(s.maxLevel) == "number") and s.maxLevel or 99
	if lvl < minL or lvl > maxL then
		return false
	end

	-- 5. Optional hostile-only gate. UnitCanAttack is TWO-ARG on this client
	--    (AS5): UnitCanAttack("player", unit) = "can I attack it".
	if s.requireHostile then
		if A.Query(UnitCanAttack, "player", unit) ~= true then
			return false
		end
	end

	return true
end
