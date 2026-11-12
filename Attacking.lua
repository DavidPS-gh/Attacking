-- Attacking: cuánto falta para tu siguiente golpe (cuerpo a cuerpo y a distancia).
-- Aquí se lleva la cuenta de los golpes; el icono está en Display.lua y los ajustes en Config.lua.
local ADDON, ns = ...

ns.VERSION = 1 -- versión de los datos guardados

ns.DEFAULTS = {
  size = 40,              -- tamaño del icono principal
  showText = true,        -- segundos que faltan, debajo del icono
  iconStyle = "weapon",   -- "weapon" (el arma equipada) o "sword" (una espada)
  showOff = true,         -- icono de la mano izquierda si llevas dos armas
  showRanged = true,      -- icono de Disparo automático y varitas
  flash = true,           -- destello al estar listo el golpe
  showResult = true,      -- resultado del golpe junto al icono (¡Fallo!, Parado…)
  resultCrit = true,      -- …incluidos críticos y golpes rozados
  resultPos = "side",     -- "side" (a la derecha) o "top" (encima)
  locked = true,
  point = { "CENTER", "CENTER", 0, -160 },
}

-- Ataques que sustituyen al siguiente golpe: Golpe heroico, Rajar, Golpe de raptor, Magullar
-- (todos los rangos). El registro de combate de Classic da el nombre, no el número.
local NEXT_SWING_IDS = {
  78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286,
  845, 7369, 11608, 11609, 20569,
  2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266,
  6807, 6808, 6809, 8972, 9745, 9880, 9881,
}
local nextSwing = {}

local AUTO_SHOT, SHOOT = 75, 5019 -- Disparo automático, Disparar (varitas)

-- Cuenta de cada golpe: start = cuándo empezó, dur = cuánto dura
local T = { mh = {}, oh = {}, ranged = {} }
ns.T = T
ns.attacking, ns.shooting = false, false

local function speedOf(slot)
  if slot == "ranged" then return (UnitRangedDamage("player")) end
  local mh, oh = UnitAttackSpeed("player")
  if slot == "mh" then return mh end
  return oh
end

local function startSwing(slot)
  local d = speedOf(slot)
  if not d or d <= 0 then return end
  local t = T[slot]
  t.start, t.dur, t.flashed = GetTime(), d, false
end

-- Avance del golpe (0 = acaba de golpear, 1 = listo) y segundos que faltan
function ns.Progress(slot)
  local t = T[slot]
  if not t.start then return 1, 0 end
  local e = GetTime() - t.start
  if e >= t.dur then return 1, 0 end
  return e / t.dur, t.dur - e
end

-- La velocidad cambió a mitad de golpe (Ira desatada, abalorios…): se conserva lo que llevas
local function rescale()
  local mh, oh = UnitAttackSpeed("player")
  local speeds = { mh = mh, oh = oh }
  for slot, d in pairs(speeds) do
    local t = T[slot]
    if t.start and d and d > 0 and d ~= t.dur then
      local frac = math.min(1, (GetTime() - t.start) / t.dur)
      t.start, t.dur = GetTime() - frac * d, d
    end
  end
end

-- Al parar un ataque, tu siguiente golpe se adelanta: un 40 % de tu velocidad,
-- sin bajar del 20 % restante.
local function parryHaste()
  local t = T.mh
  if not t.start then return end
  local d = t.dur
  local rem = d - (GetTime() - t.start)
  if rem > 0.6 * d then
    rem = rem - 0.4 * d
  elseif rem > 0.2 * d then
    rem = 0.2 * d
  else
    return
  end
  t.start = GetTime() - (d - rem)
end

-- Qué ha pasado con el golpe (para el texto junto al icono): un fallo (MISS, DODGE, PARRY…),
-- un crítico, un golpe rozado o un bloqueo parcial. Un golpe normal no enseña nada.
local function outcome(slot, missType, crit, glancing, blocked)
  if missType then
    ns.ShowResult(slot, missType)
  elseif crit then
    ns.ShowResult(slot, "CRIT")
  elseif glancing then
    ns.ShowResult(slot, "GLANCING")
  elseif blocked and blocked > 0 then
    ns.ShowResult(slot, "BLOCK")
  end
end

-- Posición de los datos en el registro de combate (desde el 12):
--   SWING_DAMAGE: cantidad, sobrante, escuela, resistido(15), bloqueado(16), absorbido, crítico(18),
--                 rozado(19), aplastante, mano izquierda(21)
--   SWING_MISSED: tipo de fallo(12), mano izquierda(13)
--   SPELL_/RANGE_DAMAGE: id, nombre(13), escuela, cantidad, sobrante, escuela, resistido,
--                 bloqueado(19), absorbido, crítico(21), rozado(22)
--   SPELL_/RANGE_MISSED: id, nombre(13), escuela, tipo de fallo(15)
local playerGUID
local function onCombatLog()
  local _, sub, _, src, _, _, _, dst, _, _, _,
    a12, a13, _, a15, a16, _, a18, a19, _, a21, a22 = CombatLogGetCurrentEventInfo()
  if src == playerGUID then
    if sub == "SWING_DAMAGE" then
      local slot = a21 and "oh" or "mh"
      startSwing(slot)
      outcome(slot, nil, a18, a19, a16)
    elseif sub == "SWING_MISSED" then
      local slot = a13 and "oh" or "mh"
      startSwing(slot)
      outcome(slot, a12)
    elseif (sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED") and nextSwing[a13] then
      startSwing("mh")
      if sub == "SPELL_DAMAGE" then outcome("mh", nil, a21, a22, a19) else outcome("mh", a15) end
    elseif sub == "RANGE_DAMAGE" then
      outcome("ranged", nil, a21, a22, a19)
    elseif sub == "RANGE_MISSED" then
      outcome("ranged", a15)
    end
  elseif dst == playerGUID then
    if (sub == "SWING_MISSED" and a12 == "PARRY") or (sub == "SPELL_MISSED" and a15 == "PARRY") then
      parryHaste()
    end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    AttackingDB = AttackingDB or {}
    for k, v in pairs(ns.DEFAULTS) do
      if AttackingDB[k] == nil then AttackingDB[k] = type(v) == "table" and { unpack(v) } or v end
    end
    AttackingDB.version = ns.VERSION
    ns.db = AttackingDB

  elseif event == "PLAYER_LOGIN" then
    playerGUID = UnitGUID("player")
    for _, id in ipairs(NEXT_SWING_IDS) do
      local name = GetSpellInfo(id)
      if name then nextSwing[name] = true end
    end
    ns.BuildDisplay()
    for _, e in ipairs({
      "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_ATTACK_SPEED",
      "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
      "PLAYER_EQUIPMENT_CHANGED",
    }) do
      pcall(self.RegisterEvent, self, e)
    end

  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    onCombatLog()

  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit == "player" and (spellID == AUTO_SHOT or spellID == SHOOT) then startSwing("ranged") end

  elseif event == "UNIT_ATTACK_SPEED" then
    if ... == "player" then rescale() ns.Refresh() end

  elseif event == "PLAYER_ENTER_COMBAT" then -- empiezas a atacar cuerpo a cuerpo
    ns.attacking = true
    ns.Refresh()
  elseif event == "PLAYER_LEAVE_COMBAT" then
    ns.attacking = false
    ns.Refresh()
  elseif event == "START_AUTOREPEAT_SPELL" then -- empiezas a disparar
    ns.shooting = true
    ns.Refresh()
  elseif event == "STOP_AUTOREPEAT_SPELL" then
    ns.shooting = false
    ns.Refresh()

  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    ns.UpdateTextures()
    ns.Refresh()
  end
end)
