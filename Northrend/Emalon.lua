﻿----------------------------------
--      Module Declaration      --
----------------------------------

local boss = BB["Emalon the Storm Watcher"]
local mod = BigWigs:New(boss, "$Revision$")
if not mod then return end
mod.zonename = BZ["Vault of Archavon"]
mod.otherMenu = "Northrend"
mod.enabletrigger = boss
mod.guid = 33993
mod.toggleoptions = {"nova", "overcharge", "icon", "bosskill"}

------------------------------
--      Are you local?      --
------------------------------

local db = nil
local started = nil
local UnitGUID = _G.UnitGUID
local GetNumRaidMembers = _G.GetNumRaidMembers
local fmt = _G.string.format
local guid

----------------------------
--      Localization      --
----------------------------

local L = AceLibrary("AceLocale-2.2"):new("BigWigs"..boss)

L:RegisterTranslations("enUS", function() return {
	cmd = "Emalon",

	nova = "Lightning Nova",
	nova_desc = "Warn when Emalon cast a Lightning Nova.",
	nova_message = "Casting Lightning Nova!",
	nova_next = "~Cooldown Lightning Nova",

	overcharge = "Overcharge",
	overcharge_desc = "Warn when Emalon overcharges a minion.",
	overcharge_message = "A minion is overcharged!",
	overcharge_bar = "Explosion",
	overcharge_next = "~Next Overcharge",

	icon = "Overcharge Icon",
	icon_desc = "Place a skull on the mob with Overcharge.",
} end )

L:RegisterTranslations("koKR", function() return {
	nova = "번개 회오리",
	nova_desc = "에말론의 번개 회오리 시전을 알립니다.",
	nova_message = "번개 회오리 시전!",
	nova_next = "~번개 대기시간",

	overcharge = "과충전",
	overcharge_desc = "에말론이 하수인에게 과충전 사용을 알립니다.",
	overcharge_message = "하수인 과충전!",
	overcharge_bar = "폭발",
	overcharge_next = "~다음 과충전",

	--icon = "Overcharge Icon",
	--icon_desc = "Place a skull on the mob with Overcharge",
} end )

L:RegisterTranslations("frFR", function() return {
	nova = "Nova de foudre",
	nova_desc = "Prévient quand Emalon incante une Nova de foudre.",
	nova_message = "Nova de foudre en incantation !",
	nova_next = "~Recharge Nova de foudre",

	overcharge = "Surcharger",
	overcharge_desc = "Prévient quand Emalon surcharge un séide.",
	overcharge_message = "Un séide est surchargé !",
	overcharge_bar = "Explosion",
	overcharge_next = "~Prochaine Surcharge",

	--icon = "Overcharge Icon",
	--icon_desc = "Place a skull on the mob with Overcharge",
} end )

L:RegisterTranslations("deDE", function() return {
	nova = "Blitzschlagnova",
	nova_desc = "Warnung und Timer für Blitzschlagnova.",
	nova_message = "Blitzschlagnova!",
	nova_next = "~Blitzschlagnova",

	overcharge = "Überladen",
	overcharge_desc = "Warnt, wann und wenn Emalon einen Sturmdiener überläd.",
	overcharge_message = "Sturmdiener überladen!",
	overcharge_bar = "Explosion",
	overcharge_next = "~Überladen",

	icon = "Schlachtzugs-Symbol",
	icon_desc = "Platziert ein Schlachtzugs-Symbol (Totenkopf) auf dem Sturmdiener, der von Überladen betroffen ist (benötigt Assistent oder höher).",
} end )

L:RegisterTranslations("ruRU", function() return {
	nova = "Вспышка молнии",
	nova_desc = "Предупреждать, когда эмалон применяет Вспышку молнии.",
	nova_message = "Вспышка молнии!",
	nova_next = "~Перезарядка Вспышки молнии",

	overcharge = "Перегрузка",
	overcharge_desc = "Предупреждать когда Эмалон применяет Перегрузку на Служителя бури.",
	overcharge_message = "Служитель бури перегружен!",
	overcharge_bar = "Взрыв Служителя бури",
	overcharge_next = "~Следующая Перегрузка",

	icon = "Иконка Перегрузки",
	icon_desc = "Отмечать черепом Служителя бури с эффектом Перегрузки.",
} end )

------------------------------
--      Initialization      --
------------------------------

function mod:OnEnable()
	self:AddCombatListener("SPELL_CAST_START", "Nova", 64216, 65279)
	self:AddCombatListener("SPELL_CAST_SUCCESS", "Overcharge", 64218)
	self:AddCombatListener("SPELL_HEAL", "OverchargeIcon", 64218)
	self:AddCombatListener("UNIT_DIED", "BossDeath")

	self:RegisterEvent("PLAYER_REGEN_ENABLED", "CheckForWipe")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "CheckForEngage")
	self:RegisterEvent("BigWigs_RecvSync")

	db = self.db.profile
end

------------------------------
--      Event Handlers      --
------------------------------

function mod:Nova()
	if db.nova then
		self:IfMessage(L["nova_message"], "Attention", 64216)
		self:Bar(L["nova"], 5, 64216)
		self:Bar(L["nova_next"], 25, 64216)
	end
end

function mod:Overcharge()
	if db.overcharge then
		self:IfMessage(L["overcharge_message"], "Attention", 64218)
		self:Bar(L["overcharge_bar"], 20, 64218)
		self:Bar(L["overcharge_next"], 45, 64218)
	end
end

local function ScanTarget()
	local target
	if UnitGUID("target") == guid then
		target = "target"
	elseif UnitGUID("focus") == guid then
		target = "focus"
	else
		local num = GetNumRaidMembers()
		for i = 1, num do
			local unitid = fmt("%s%d%s", "raid", i, "target")
			if UnitGUID(unitid) == guid then
				target = unitid
				break
			end
		end
	end
	if target then
		SetRaidTarget(target, 8)
		mod:CancelScheduledEvent("BWGetOverchargeTarget")
	end
end

function mod:OverchargeIcon(...)
	if not IsRaidLeader() and not IsRaidOfficer() then return end
	if not db.icon then return end
	guid = select(9, ...)
	self:ScheduleRepeatingEvent("BWGetOverchargeTarget", ScanTarget, 0.1)
end

function mod:BigWigs_RecvSync(sync, rest, nick)
	if self:ValidateEngageSync(sync, rest) and not started then
		started = true
		if self:IsEventRegistered("PLAYER_REGEN_DISABLED") then
			self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		end
	end
end
