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
local L = function(...) return ns.L(...) end

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
  showResult = true,      -- resultado del golpe junto a la pieza (¡Fallo!, Parado…)
  resultCrit = true,      -- …incluidos críticos y golpes rozados
  resultPos = "side",     -- "side" (al lado) o "top" (encima)
  resultGroup = false,    -- en grupo, enseñar también los que no coinciden con un golpe tuyo
  resultSize = 14,        -- tamaño del texto de resultado
  resultOutline = "outline", -- contraste: "shadow" (sombra), "outline" (contorno) o "thick" (contorno grueso)
  resultAlpha = 1,        -- opacidad del texto de resultado (aparte de la de las piezas)
  resultTime = 1.3,       -- segundos que se ve (incluido el desvanecido)
  locked = true,
  pos = {},               -- sitio de cada pieza (mh, oh, ranged); vacío = el de partida
}

-- Opciones que ya no existen (se borran de los datos guardados)
local OLD_KEYS = {
  "auraBuffs", "auraDebuffs", "auraWhen", "auraSize", "seenCombatAuraNote", "point",
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
local movedAt = {} -- última vez que la barra se movió (para saber si se ha quedado parada)
local movedFrom = {} -- valor de la barra la última vez que se vio moverse

-- ¿Tienes puesto el ataque automático? El aviso del juego (PLAYER_ENTER_COMBAT) puede perderse
-- (p. ej. si ya atacabas al hacer /reload), así que también se pregunta por el hechizo «Atacar».
local AUTO_ATTACK = 6603
function ns.IsAttacking()
  if ns.attacking then return true end
  local fn = (C_Spell and C_Spell.IsCurrentSpell) or IsCurrentSpell
  if not fn then return false end
  local ok, cur = pcall(function() return fn(AUTO_ATTACK) == true end) -- (por si fuera «secreto»)
  return ok and cur
end

function ns.BlizFrame(slot)
  return _G[BLIZ[slot]]
end

-- Cuándo empezó el golpe actual de esa mano (la barra del juego se reinicia en cada golpe tuyo)
function ns.ResetAt(slot)
  return resetAt[slot]
end

-- Segundos que lleva quieta la barra del juego de ese golpe (para /attacking debug)
function ns.StillFor(slot)
  return movedAt[slot] and (GetTime() - movedAt[slot]) or -1
end

-- ¿La barra de Blizzard de ese golpe está visible?
function ns.BlizShown(slot)
  local f = _G[BLIZ[slot]]
  return f ~= nil and f:IsShown()
end

-- ¿Es un valor «secreto»? (en combate Forever a veces vuelve secretos los datos de la barra de
-- golpe: no se pueden comparar ni operar). Si el cliente no trae issecretvalue, nunca lo es.
local function isSecret(v)
  return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- Avance 0..1 leído de la barra de Blizzard. Va dentro de pcall (por si algún dato fuera
-- «secreto» sin que issecretvalue lo diga). Si no se puede leer, devuelve nil y se usa el reloj
-- propio; se vuelve a intentar en el siguiente fotograma.
local function readBar(slot, bar)
  local v = bar:GetValue()
  if isSecret(v) then return nil end
  local lo, hi = bar:GetMinMaxValues()
  if isSecret(lo) or isSecret(hi) then lo, hi = 0, 1 end -- va de 0 a 1
  if v == nil or not hi or not lo or hi <= lo then return nil end
  local p = (v - lo) / (hi - lo)
  -- En cada golpe la barra salta: si salta hacia abajo es que se llena; si salta hacia
  -- arriba, que se vacía. Así se sabe hacia dónde va sin depender de cómo esté hecha.
  local prev = last[slot]
  -- Se compara con el valor de la última vez que se movió (no con el fotograma anterior): así
  -- cuenta aunque avance a pasitos muy pequeños por fotograma o se actualice a saltos.
  local from = movedFrom[slot]
  if not from or math.abs(p - from) > 0.002 then
    if from then movedAt[slot] = GetTime() end
    movedFrom[slot] = p
  end
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
  local f = _G[BLIZ[slot]]
  local bar = f and f.StatusBar
  -- Se lee aunque el juego la tenga oculta: si sigue avanzando, vale; si no, la detección de
  -- barra quieta (más abajo) deja la pieza llena.
  if not bar then return nil end
  local ok, p = pcall(readBar, slot, bar)
  if not ok then
    ns.blizErrAt, ns.blizErr = GetTime(), tostring(p) -- para /attacking debug
    resetAt[slot] = nil -- sin leerla no se ve el próximo reinicio: la medida ya no vale
    return nil
  end
  return p
end

-- Avance del golpe (0 = acaba de golpear, 1 = listo) y segundos que faltan.
-- Los segundos se sacan midiendo el ritmo de la propia barra: si desde el último golpe han
-- pasado «t» segundos y va por «p», le quedan t·(1−p)/p. Así nota los cambios de velocidad
-- (Aluvión…). Al principio del golpe, con poco recorrido para medir, se usa la velocidad guardada.
local MIN_MEASURE = 0.15
local STALL = 0.5 -- mientras golpeas la barra no para de moverse; quieta más de esto = no golpeas
function ns.Progress(slot)
  local p = blizProgress(slot)
  if p then
    if p >= 1 then return 1, 0 end
    -- Manda la propia barra del juego: si se está moviendo, el golpe está cargando (aunque el
    -- addon no se haya enterado de que atacas, p. ej. tras un /reload). Si lleva quieta más de
    -- STALL, no estás golpeando (sin atacar, objetivo fuera de alcance, huyendo…): el golpe
    -- está listo y la pieza se ve llena.
    local still = movedAt[slot] and (GetTime() - movedAt[slot]) or math.huge
    if still > STALL then
      resetAt[slot] = nil -- parada: el próximo golpe se medirá desde su propio reinicio
      -- Barra del juego congelada pero sigues atacando: se usa el reloj propio (ver backupSwing)
      local t = T[slot]
      if slot == "mh" and t.start and ns.IsAttacking() then
        local e = GetTime() - t.start
        if e < t.dur then return e / t.dur, t.dur - e end
      end
      return 1, 0
    end
    local d = speedOf(slot)
    local t0 = resetAt[slot]
    if t0 and p >= MIN_MEASURE then
      local t = GetTime() - t0
      -- Solo si la medida es razonable: si el último reinicio visto es viejo (la barra estuvo
      -- congelada o secreta y no se vio el salto), t es enorme y salían segundos absurdos.
      if not d or t <= d * 1.6 then
        local rem = t * (1 - p) / p
        if d then rem = math.min(rem, (1 - p) * d * 1.6) end
        return p, rem
      end
      resetAt[slot] = nil
    end
    return p, (1 - p) * (d or 0)
  end
  -- sin barra del juego (solo el disparo puede contarse por su cuenta)
  local active
  if slot == "ranged" then active = ns.shooting else active = ns.IsAttacking() end
  if not active then return 1, 0 end
  local t = T[slot]
  if not t.start then return 1, 0 end
  local e = GetTime() - t.start
  if e >= t.dur then return 1, 0 end
  return e / t.dur, t.dur - e
end

---------------------------------------------------------------------------
-- Resultado del golpe (UNIT_COMBAT sí está permitido en Forever)
---------------------------------------------------------------------------
-- UNIT_COMBAT dice qué le pasa a tu objetivo (esquiva, para, fallo, crítico…) pero no quién le
-- ha atacado. Se apunta aquí y Display.lua decide de quién es: si coincide con el reinicio de
-- tu barra de golpe, es tuyo (y de esa mano).
local MISSES = {
  MISS = true, DODGE = true, PARRY = true, BLOCK = true, DEFLECT = true, ABSORB = true,
  RESIST = true, REFLECT = true, IMMUNE = true, EVADE = true,
}
ns.pendingResults = {}

-- (dentro de pcall: si algún dato fuera «secreto», compararlo daría error)
local function resultKind(action, flag)
  if MISSES[action] then return action end
  if action == "WOUND" then
    if flag == "CRITICAL" then return "CRIT" end
    if flag == "GLANCING" then return "GLANCING" end
    if flag == "BLOCK_REDUCED" then return "BLOCK" end
  end
end

-- ¿Es un golpe cuerpo a cuerpo sobre tu objetivo? (fallo, esquiva… o daño físico)
local function isMeleeHit(action, school)
  if MISSES[action] then return true end
  return action == "WOUND" and (school == nil or school == 1)
end

-- Reloj propio de respaldo para la mano derecha: a veces la barra de golpe del juego se
-- congela (se queda quieta con «0.0» aunque sigas pegando). Yendo solo, lo que le pasa a tu
-- objetivo es casi siempre tuyo, así que cada golpe sobre él reinicia este reloj. Lo que llega
-- muy pronto después de otro golpe (una habilidad instantánea) no cuenta.
-- Habilidades que SON un golpe del arma (salen con el golpe o lo reinician): Golpe heroico,
-- Rajar, Golpe de raptor, Abatir y Embate. Se comparan por nombre (así valen todos los rangos).
local SWING_SPELLS = { 78, 845, 2973, 6807, 1464 }
local swingNames
local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  if C_Spell and C_Spell.GetSpellInfo then
    local i = C_Spell.GetSpellInfo(id)
    return i and i.name
  end
end

-- Lanzas una habilidad: si no es de las que son un golpe, su daño no debe reiniciar el reloj
local lastCast = 0
local function onPlayerCast(spellID)
  if not swingNames then
    swingNames = {}
    for _, id in ipairs(SWING_SPELLS) do
      local n = spellName(id)
      if n then swingNames[n] = true end
    end
  end
  local n = spellName(spellID)
  if n and not swingNames[n] then lastCast = GetTime() end
end

local CAST_WINDOW = 0.4 -- lo que le pase al objetivo hasta esto después de una habilidad es de ella
local function backupSwing(action, school)
  if IsInGroup() or ns.shooting or not ns.IsAttacking() then return end
  local ok, hit = pcall(isMeleeHit, action, school)
  if not ok or not hit then return end
  local now = GetTime()
  if now - lastCast < CAST_WINDOW then return end -- es el golpe de una habilidad, no el tuyo
  local d = speedOf("mh")
  if not d then return end
  local t = T.mh
  local gap = t.start and (now - t.start)
  if gap and gap < d * 0.6 then return end
  -- Ritmo real: en combate la velocidad es secreta y la guardada no nota la celeridad (Arrebato,
  -- Aluvión…). El tiempo entre dos golpes seguidos, si es razonable, la sustituye.
  if gap and gap <= d * 1.5 then t.learned = gap end
  startSwing("mh")
  if t.learned then t.dur = t.learned end
end

local function onUnitCombat(unit, action, flag, _, school)
  if unit ~= "target" then return end
  backupSwing(action, school)
  local ok, kind = pcall(resultKind, action, flag)
  if ok and kind then
    local q = ns.pendingResults
    q[#q + 1] = { kind = kind, t = GetTime() }
    if #q > 10 then table.remove(q, 1) end
  end
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
      "UNIT_COMBAT",
    }) do
      pcall(self.RegisterEvent, self, e)
    end

  elseif event == "UNIT_COMBAT" then
    onUnitCombat(...)

  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellID = ...
    if unit == "player" and (spellID == AUTO_SHOT or spellID == SHOOT) then startSwing("ranged") end
    if unit == "player" then pcall(onPlayerCast, spellID) end

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
    T.mh.learned = nil -- fuera de combate se vuelve a la velocidad leída
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
    print("|cff33ccffAttacking|r: " .. L("error con %s (%s). Pásale este mensaje a quien te hizo el addon.", event, tostring(err)))
  end
end)
