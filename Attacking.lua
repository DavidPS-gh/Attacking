-- Attacking: cuánto falta para tu siguiente golpe (cuerpo a cuerpo y a distancia).
-- Aquí se lleva la cuenta de los golpes; el icono está en Display.lua y los ajustes en Config.lua.
local ADDON, ns = ...

ns.VERSION = 3 -- versión de los datos guardados
-- 2: «ocultar la barra de Blizzard» vuelve a estar desactivado (en la 1 causaba un bucle)
-- 3: cada pieza tiene su sitio (pos) en vez de un solo bloque (point)

-- Funciones de hechizos: los clientes nuevos usan C_Spell y algunos ya no traen GetSpellInfo.
-- Se prueba primero lo nuevo y, si no está, lo antiguo (igual que Forja de Macros).
function ns.SpellName(spell)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spell) end
  if GetSpellInfo then return (GetSpellInfo(spell)) end
end

function ns.SpellIcon(spell)
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell) end
  if GetSpellTexture then return (GetSpellTexture(spell)) end
  if GetSpellInfo then return (select(3, GetSpellInfo(spell))) end
end

ns.DEFAULTS = {
  size = 40,              -- tamaño del icono principal
  showText = true,        -- segundos que faltan, debajo del icono
  iconStyle = "weapon",   -- "weapon" (el arma equipada) o "sword" (una espada)
  showOff = true,         -- icono de la mano izquierda si llevas dos armas
  showRanged = true,      -- icono de Disparo automático y varitas
  flash = true,           -- destello al estar listo el golpe
  iconWhen = "attack",    -- cuándo se ve el icono: "attack" (mientras atacas), "combat" o "always"
  hideBlizzard = false,   -- volver invisibles las barras de golpe de Blizzard (ver Display.lua)
  showResult = true,      -- resultado del golpe junto al icono (¡Fallo!, Parado…)
  resultCrit = true,      -- …incluidos críticos y golpes rozados
  resultPos = "side",     -- "side" (a la derecha) o "top" (encima)
  auraBuffs = true,       -- fila de buffos propios
  auraDebuffs = true,     -- fila de debuffos del objetivo
  auraWhen = "attack",    -- "attack" (mientras atacas), "combat" o "always"
  auraSize = 24,
  alpha = 1,              -- opacidad de los iconos y las filas (0,2 a 1)
  locked = true,
  pos = {},               -- sitio de cada pieza (mh, oh, ranged, buffs, debuffs); vacío = el de partida
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
ns.attacking, ns.shooting, ns.inCombat = false, false, false

-- Velocidad de ataque de cada mano (segundos entre golpes), o nil si no hay arma.
-- En combate Forever la vuelve «secreta» (no se puede operar con ella), así que se guarda la
-- última que se pudo leer (fuera de combate) y en combate se usa esa.
local cachedSpeed = {}
local function readSpeed(slot)
  local s
  if slot == "ranged" then
    s = UnitRangedDamage("player")
  else
    local mh, oh = UnitAttackSpeed("player")
    if slot == "mh" then s = mh else s = oh end
  end
  if s == nil then return false end
  return s + 0 -- da error si es secreta
end

local function speedOf(slot)
  local ok, v = pcall(readSpeed, slot)
  if ok then
    if v and v > 0 then cachedSpeed[slot] = v else cachedSpeed[slot] = nil end
  end
  return cachedSpeed[slot]
end
ns.SpeedOf = speedOf

local function startSwing(slot)
  local d = speedOf(slot)
  if not d or d <= 0 then return end
  local t = T[slot]
  t.start, t.dur, t.flashed = GetTime(), d, false
end

---------------------------------------------------------------------------
-- Barras de golpe de Blizzard (WoW Forever trae las suyas)
---------------------------------------------------------------------------
-- En Forever los addons no pueden leer el registro de combate, así que no sabemos por
-- nuestra cuenta cuándo golpeas. Pero el juego sí lo calcula para sus barras: se lee su
-- avance de ahí. Tienen que estar activadas en los ajustes del juego.
local BLIZ = {
  mh = "SwingTimerMainHandFrame",
  oh = "SwingTimerOffHandFrame",   -- supuesto: si no existe, se ignora
  ranged = "SwingTimerRangedFrame",
}
ns.BLIZ = BLIZ

local dir = { mh = 1, oh = 1, ranged = 1 } -- 1 = la barra se llena, -1 = se vacía
local last = {}
local warnedSecret

function ns.BlizFrame(slot)
  return _G[BLIZ[slot]]
end

-- ¿La barra de Blizzard de ese golpe está en marcha (visible para el juego)?
function ns.BlizShown(slot)
  local f = _G[BLIZ[slot]]
  return f ~= nil and f:IsShown()
end

-- Avance 0..1 leído de la barra de Blizzard, o nil si no hay barra (o no se puede leer).
-- En combate el juego puede volver «secretos» algunos datos: se pueden pasar, pero
-- compararlos u operar con ellos da error. Por eso TODO el cálculo va dentro de pcall, y si
-- falla se deja de leer la barra durante la sesión (avisando una sola vez con el error).
local function readBar(slot, bar)
  local lo, hi = bar:GetMinMaxValues()
  local v = bar:GetValue()
  if not hi or not lo or hi <= lo then return nil end
  local p = (v - lo) / (hi - lo)
  -- En cada golpe la barra salta: si salta hacia abajo es que se llena; si salta hacia
  -- arriba, que se vacía. Así se sabe hacia dónde va sin depender de cómo esté hecha.
  local prev = last[slot]
  if prev and math.abs(p - prev) > 0.5 then
    dir[slot] = (p < prev) and 1 or -1
    T[slot].flashed = false -- nuevo golpe: el destello vuelve a estar disponible
  end
  last[slot] = p
  if dir[slot] == -1 then p = 1 - p end
  if p < 0 then p = 0 elseif p > 1 then p = 1 end
  return p + 0 -- número normal
end

local function blizProgress(slot)
  if ns.blizBroken then return nil end
  local f = _G[BLIZ[slot]]
  local bar = f and f.StatusBar
  if not bar or not f:IsShown() then return nil end
  local ok, p = pcall(readBar, slot, bar)
  if not ok then
    ns.blizBroken = true
    if not warnedSecret then
      warnedSecret = true
      print("|cff33ccffAttacking|r: no puedo leer la barra de golpe del juego (" .. tostring(p)
        .. "). Dejo de leerla hasta que recargues. Pásale este mensaje a quien te hizo el addon.")
    end
    return nil
  end
  return p
end

-- Avance del golpe (0 = acaba de golpear, 1 = listo) y segundos que faltan
function ns.Progress(slot)
  local p = blizProgress(slot)
  if p then
    local speed = speedOf(slot) or 0
    return p, (1 - p) * speed
  end
  local t = T[slot]
  if not t.start then return 1, 0 end
  local e = GetTime() - t.start
  if e >= t.dur then return 1, 0 end
  return e / t.dur, t.dur - e
end

-- La velocidad cambió a mitad de golpe (Ira desatada, abalorios…): se conserva lo que llevas
local function rescale()
  local speeds = { mh = speedOf("mh"), oh = speedOf("oh") }
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
local function onEvent(self, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    AttackingDB = AttackingDB or {}
    if (AttackingDB.version or 0) < 2 then AttackingDB.hideBlizzard = false end
    -- antes todo iba en un bloque (point): la mano derecha se queda donde estaba y el resto
    -- se coloca alrededor
    if (AttackingDB.version or 0) < 3 and AttackingDB.point and not AttackingDB.pos then
      local p, s = AttackingDB.point, AttackingDB.size or 40
      AttackingDB.pos = {
        mh = { p[1], p[2], p[3], p[4] },
        oh = { p[1], p[2], p[3] + s + 8, p[4] },
        ranged = { p[1], p[2], p[3] + 2 * s + 16, p[4] },
        buffs = { "TOPLEFT", p[2], p[3] - s / 2, p[4] - s / 2 - 24 },
        debuffs = { "TOPLEFT", p[2], p[3] - s / 2, p[4] - s / 2 - 64 },
      }
    end
    AttackingDB.point = nil
    for k, v in pairs(ns.DEFAULTS) do
      if AttackingDB[k] == nil then AttackingDB[k] = type(v) == "table" and { unpack(v) } or v end
    end
    AttackingDB.version = ns.VERSION
    ns.db = AttackingDB
    -- por personaje: qué buffos y debuffos seguir (las listas se rellenan al entrar, en Auras.lua)
    AttackingCharDB = AttackingCharDB or {}
    AttackingCharDB.version = ns.VERSION
    ns.char = AttackingCharDB

  elseif event == "PLAYER_LOGIN" then
    playerGUID = UnitGUID("player")
    ns.inCombat = UnitAffectingCombat("player") and true or false
    ns.BuildDisplay() -- lo primero: así el icono existe aunque falle algo de lo que sigue
    for _, id in ipairs(NEXT_SWING_IDS) do
      local name = ns.SpellName(id)
      if name then nextSwing[name] = true end
    end
    -- OJO: en WoW Forever los addons no pueden apuntarse a COMBAT_LOG_EVENT_UNFILTERED
    -- (el juego lo bloquea con un aviso). onCombatLog se queda sin usar hasta que tengamos
    -- otra forma de saber cuándo golpeas.
    for _, e in ipairs({
      "UNIT_SPELLCAST_SUCCEEDED", "UNIT_ATTACK_SPEED",
      "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
      "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
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

  elseif event == "PLAYER_REGEN_DISABLED" then -- entras en combate
    ns.inCombat = true
    ns.Refresh()
  elseif event == "PLAYER_REGEN_ENABLED" then
    ns.inCombat = false
    ns.Refresh()

  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    ns.UpdateTextures()
    ns.Refresh()
  end
end

-- Eventos protegidos: si alguno falla (datos «secretos» en combate…), se avisa una vez por
-- evento con el error, en vez de soltar errores sin parar.
local eventErrors = {}
ev:SetScript("OnEvent", function(self, event, ...)
  local ok, err = pcall(onEvent, self, event, ...)
  if not ok and not eventErrors[event] then
    eventErrors[event] = true
    print("|cff33ccffAttacking|r: error con " .. event .. " (" .. tostring(err)
      .. "). Pásale este mensaje a quien te hizo el addon.")
  end
end)
