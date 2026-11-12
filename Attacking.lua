-- Attacking: cuánto falta para tu siguiente golpe (cuerpo a cuerpo y a distancia).
-- Aquí se lleva la cuenta de los golpes; el dibujo está en Display.lua y los ajustes en Config.lua.
--
-- Restricciones de WoW Forever (vistas probando en el juego):
--   · Los addons no pueden apuntarse a COMBAT_LOG_EVENT_UNFILTERED (aviso de «bloqueado»).
--   · En combate son «secretos» (no se puede operar ni comparar con ellos) UnitAttackSpeed y
--     las auras. Por eso Attacking lee el avance de las barras de golpe del propio juego.
--   · Todo lo que se hace en cada fotograma o evento va dentro de pcall: un error repetido
--     dispara el aviso de «tus addons dan muchos problemas».
local ADDON, ns = ...

ns.VERSION = 4 -- versión de los datos guardados
-- 2: «ocultar la barra de Blizzard» vuelve a estar desactivado (en la 1 causaba un bucle)
-- 3: cada pieza tiene su sitio (pos) en vez de un solo bloque (point)
-- 4: fuera buffos/debuffos y resultado del golpe; nuevo «style»

ns.DEFAULTS = {
  style = "icon",         -- "icon" (se rellena), "clock" (reloj), "bar" (barra) o "pips" (puntos)
  size = 40,              -- tamaño del icono principal (en barra y puntos, su alto de referencia)
  showText = true,        -- segundos que faltan, debajo
  iconStyle = "weapon",   -- dibujo del icono: "weapon" (el arma equipada) o "sword" (una espada)
  showOff = true,         -- pieza de la mano izquierda si llevas dos armas
  showRanged = true,      -- pieza de Disparo automático y varitas
  flash = true,           -- destello al estar listo el golpe
  iconWhen = "attack",    -- cuándo se ve: "attack" (mientras atacas), "combat" o "always"
  hideBlizzard = false,   -- volver invisibles las barras de golpe de Blizzard (ver Display.lua)
  alpha = 1,              -- opacidad (0,2 a 1)
  grid = true,            -- cuadrícula en pantalla al mover las piezas
  snap = true,            -- al soltar una pieza, ajustarla a la cuadrícula (Mayús = sin ajustar)
  gridSize = 32,          -- tamaño de las casillas, en píxeles
  locked = true,
  pos = {},               -- sitio de cada pieza (mh, oh, ranged); vacío = el de partida
}

-- Opciones que ya no existen (se borran de los datos guardados)
local OLD_KEYS = {
  "showResult", "resultCrit", "resultPos", "auraBuffs", "auraDebuffs", "auraWhen", "auraSize",
  "seenCombatAuraNote", "point",
}

local AUTO_SHOT, SHOOT = 75, 5019 -- Disparo automático, Disparar (varitas)

-- Cuenta propia de cada golpe (solo se usa para el disparo si no hay barra del juego):
-- start = cuándo empezó, dur = cuánto dura
local T = { mh = {}, oh = {}, ranged = {} }
ns.T = T
ns.attacking, ns.shooting, ns.inCombat = false, false, false

---------------------------------------------------------------------------
-- Velocidad de ataque
---------------------------------------------------------------------------
-- Segundos entre golpes de cada mano, o nil si no hay arma. En combate Forever la vuelve
-- «secreta», así que se guarda la última que se pudo leer (fuera de combate) y se usa esa.
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

-- Guardar ya la velocidad de las tres manos (fuera de combate), se vea el icono o no
function ns.WarmSpeeds()
  if ns.inCombat then return end
  speedOf("mh")
  speedOf("oh")
  speedOf("ranged")
end

local function startSwing(slot)
  local d = speedOf(slot)
  if not d or d <= 0 then return end
  local t = T[slot]
  t.start, t.dur, t.flashed = GetTime(), d, false
end

---------------------------------------------------------------------------
-- Barras de golpe de Blizzard (WoW Forever trae las suyas)
---------------------------------------------------------------------------
-- Tienen que estar activadas en los ajustes del juego. Van de 0 a 1.
local BLIZ = {
  mh = "SwingTimerMainHandFrame",
  oh = "SwingTimerOffHandFrame",   -- supuesto: si no existe, se ignora
  ranged = "SwingTimerRangedFrame",
}
ns.BLIZ = BLIZ

local dir = { mh = 1, oh = 1, ranged = 1 } -- 1 = la barra se llena, -1 = se vacía
local last = {}
local resetAt = {} -- momento en que la barra empezó el golpe actual (para medir su ritmo)
local warnedSecret

function ns.BlizFrame(slot)
  return _G[BLIZ[slot]]
end

-- ¿La barra de Blizzard de ese golpe está visible?
function ns.BlizShown(slot)
  local f = _G[BLIZ[slot]]
  return f ~= nil and f:IsShown()
end

-- Avance 0..1 leído de la barra de Blizzard. Todo el cálculo va dentro de pcall (por si algún
-- dato fuera «secreto»): si falla, se deja de leer la barra durante la sesión.
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
    resetAt[slot] = GetTime()
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

-- Avance del golpe (0 = acaba de golpear, 1 = listo) y segundos que faltan.
-- Los segundos se sacan midiendo el ritmo de la propia barra: si desde el último golpe han
-- pasado «t» segundos y va por «p», le quedan t·(1−p)/p. Así nota los cambios de velocidad
-- (Aluvión…). Al principio del golpe, con poco recorrido para medir, se usa la velocidad guardada.
local MIN_MEASURE = 0.15
function ns.Progress(slot)
  local p = blizProgress(slot)
  if p then
    if p >= 1 then return 1, 0 end
    local t0 = resetAt[slot]
    if t0 and p >= MIN_MEASURE then
      local t = GetTime() - t0
      return p, t * (1 - p) / p
    end
    return p, (1 - p) * (speedOf(slot) or 0)
  end
  -- sin barra del juego (solo el disparo puede contarse por su cuenta)
  local t = T[slot]
  if not t.start then return 1, 0 end
  local e = GetTime() - t.start
  if e >= t.dur then return 1, 0 end
  return e / t.dur, t.dur - e
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
local function onEvent(self, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    AttackingDB = AttackingDB or {}
    local db = AttackingDB
    if (db.version or 0) < 2 then db.hideBlizzard = false end
    -- antes todo iba en un bloque (point): la mano derecha se queda donde estaba
    if (db.version or 0) < 3 and db.point and not db.pos then
      local p, s = db.point, db.size or 40
      db.pos = {
        mh = { p[1], p[2], p[3], p[4] },
        oh = { p[1], p[2], p[3] + s + 8, p[4] },
        ranged = { p[1], p[2], p[3] + 2 * s + 16, p[4] },
      }
    end
    for _, k in ipairs(OLD_KEYS) do db[k] = nil end
    if db.pos then db.pos.buffs, db.pos.debuffs = nil, nil end
    for k, v in pairs(ns.DEFAULTS) do
      if db[k] == nil then db[k] = type(v) == "table" and { unpack(v) } or v end
    end
    db.version = ns.VERSION
    ns.db = db

  elseif event == "PLAYER_LOGIN" then
    ns.inCombat = UnitAffectingCombat("player") and true or false
    ns.BuildDisplay() -- lo primero: así el icono existe aunque falle algo de lo que sigue
    ns.WarmSpeeds()
    for _, e in ipairs({
      "UNIT_SPELLCAST_SUCCEEDED", "UNIT_ATTACK_SPEED",
      "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
      "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    }) do
      pcall(self.RegisterEvent, self, e)
    end

  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit == "player" and (spellID == AUTO_SHOT or spellID == SHOOT) then startSwing("ranged") end

  elseif event == "UNIT_ATTACK_SPEED" then
    if ... == "player" then ns.WarmSpeeds() ns.Refresh() end

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
    ns.WarmSpeeds()
    ns.Refresh()

  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    ns.WarmSpeeds()
    ns.UpdateTextures()
    ns.Refresh()
  end
end

-- Eventos protegidos: si alguno falla, se avisa una vez por evento con el error, en vez de
-- soltar errores sin parar.
local eventErrors = {}
ev:SetScript("OnEvent", function(self, event, ...)
  local ok, err = pcall(onEvent, self, event, ...)
  if not ok and not eventErrors[event] then
    eventErrors[event] = true
    print("|cff33ccffAttacking|r: error con " .. event .. " (" .. tostring(err)
      .. "). Pásale este mensaje a quien te hizo el addon.")
  end
end)
