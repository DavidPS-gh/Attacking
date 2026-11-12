-- Attacking: seguimiento de buffos propios y debuffos del objetivo.
-- Dos filas de iconos bajo el temporizador de golpe; cada icono se vacía según se acaba.
local ADDON, ns = ...

local MAX_ICONS = 12
local GAP = 4
local CROP = 0.08
local DEBUFF_BORDER = { 0.8, 0.1, 0.1 }
local BUFF_BORDER = { 0, 0, 0 }

-- Lista de partida por clase: { id de hechizo, solo míos }. Los nombres se sacan del cliente,
-- así salen en el idioma del juego. Si algún id no existe en Forever, simplemente no aparece.
local CLASS_DEFAULTS = {
  WARRIOR = {
    buffs = { 6673, 12880, 12966, 2687, 1719, 12292 },  -- Grito de batalla, Enfurecer, Ira desatada, Sed de sangre, Temeridad, Deseo de muerte
    debuffs = { { 7386 }, { 1160 }, { 6343 }, { 772, true }, { 1715, true } }, -- Hender, Grito desm., Atronar, Desgarrar, Seccionar
  },
  ROGUE = {
    buffs = { 5171, 13750, 13877, 5277 },
    debuffs = { { 1943, true }, { 703, true }, { 8647 }, { 2818, true } },
  },
  HUNTER = {
    buffs = { 3045, 13165, 6150 },
    debuffs = { { 1130 }, { 1978, true }, { 3043, true } },
  },
  PALADIN = {
    buffs = { 20375, 21084, 19740 },
    debuffs = { { 21183 }, { 20186 }, { 20185 } },
  },
  SHAMAN = {
    buffs = { 16257, 324 },
    debuffs = { { 8050, true }, { 17364 } },
  },
  DRUID = {
    buffs = { 5217, 1126, 16870 },
    debuffs = { { 1079, true }, { 1822, true }, { 16857 }, { 99 } },
  },
  MAGE = {
    buffs = { 12042, 12536 },
    debuffs = { { 12579 }, { 22959 } },
  },
  PRIEST = {
    buffs = { 588, 10060 },
    debuffs = { { 589, true }, { 15258 } },
  },
  WARLOCK = {
    buffs = { 706 },
    debuffs = { { 172, true }, { 980, true }, { 348, true }, { 1490 } },
  },
}

function ns.ClassDefaults(kind)
  local _, class = UnitClass("player")
  local d = CLASS_DEFAULTS[class]
  local out, seen = {}, {}
  if not d then return out end
  for _, e in ipairs(d[kind] or {}) do
    local id, mine = e, nil
    if type(e) == "table" then id, mine = e[1], e[2] end
    local name = ns.SpellName(id)
    if name and not seen[name:lower()] then
      seen[name:lower()] = true
      out[#out + 1] = { name = name, mine = mine or nil }
    end
  end
  return out
end

-- Añade a una lista por nombre o por número de hechizo. Devuelve el nombre o nil + motivo.
function ns.AddAura(kind, text)
  text = strtrim(text or "")
  if text == "" then return nil, "Escribe el nombre (o el número) del hechizo." end
  local name = text
  if tonumber(text) then
    name = ns.SpellName(tonumber(text))
    if not name then return nil, "No hay ningún hechizo con ese número." end
  end
  local list = ns.char[kind]
  if #list >= MAX_ICONS then return nil, ("Caben como mucho %d."):format(MAX_ICONS) end
  for _, e in ipairs(list) do
    if e.name:lower() == name:lower() then return nil, "Ya está en la lista." end
  end
  list[#list + 1] = { name = name }
  ns.UpdateAuras()
  return name
end

---------------------------------------------------------------------------
-- Lectura de auras
---------------------------------------------------------------------------
-- Leer la aura n.º i: con C_UnitAuras en los clientes nuevos; si no, UnitBuff/UnitDebuff.
-- Devuelve lo mismo que UnitBuff: nombre, icono, acumulaciones, tipo, duración, fin, quién la puso
local function auraGetter(filter)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    return function(unit, i)
      local a = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
      if a then
        return a.name, a.icon, a.applications, a.dispelName, a.duration, a.expirationTime, a.sourceUnit
      end
    end
  end
  return filter == "HELPFUL" and UnitBuff or UnitDebuff
end
local getBuff, getDebuff = auraGetter("HELPFUL"), auraGetter("HARMFUL")

-- [nombre en minúsculas] = aura (cualquiera) y, aparte, las puestas por ti
local function scan(unit, getter)
  local any, mine = {}, {}
  for i = 1, 40 do
    local name, icon, count, _, duration, expires, source = getter(unit, i)
    if not name then break end
    local k = name:lower()
    local a = { icon = icon, count = count or 0, duration = duration or 0, expires = expires or 0 }
    if not any[k] then any[k] = a end
    if source == "player" and not mine[k] then mine[k] = a end
  end
  return any, mine
end

---------------------------------------------------------------------------
-- Iconos
---------------------------------------------------------------------------
local rows = {}

local function newIcon(row)
  local f = CreateFrame("Frame", nil, row, "BackdropTemplate")
  f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  f.base = f:CreateTexture(nil, "BACKGROUND")
  f.base:SetPoint("TOPLEFT", 1, -1)
  f.base:SetPoint("BOTTOMRIGHT", -1, 1)
  f.base:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
  f.base:SetDesaturated(true)
  f.base:SetVertexColor(0.4, 0.4, 0.4)
  f.fill = f:CreateTexture(nil, "ARTWORK")
  f.fill:SetPoint("BOTTOMLEFT", 1, 1)
  f.fill:SetPoint("BOTTOMRIGHT", -1, 1)
  f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  f.count:SetPoint("BOTTOMRIGHT", 0, 1)
  f.time = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  f.time:SetPoint("TOP", f, "BOTTOM", 0, -1)
  f:Hide()
  return f
end

local function newRow(kind)
  local row = CreateFrame("Frame", "Attacking_" .. kind, UIParent)
  row:SetSize(1, 1)
  row.kind = kind
  row.icons = {}
  for i = 1, MAX_ICONS do row.icons[i] = newIcon(row) end
  ns.MakeMover(kind, row) -- cada fila se coloca por separado en modo mover
  return row
end

-- Parte a color = lo que queda (1 = recién puesto, 0 = a punto de acabarse)
local function setFill(f, p)
  local inner = f:GetHeight() - 2
  if p <= 0.01 or inner <= 0 then f.fill:Hide() return end
  f.fill:SetHeight(inner * p)
  local span = 1 - 2 * CROP
  f.fill:SetTexCoord(CROP, 1 - CROP, (1 - CROP) - span * p, 1 - CROP)
  f.fill:Show()
end

local function fmtTime(s)
  if s >= 60 then return ("%dm"):format(math.floor(s / 60 + 0.5)) end
  if s >= 10 then return ("%d"):format(s) end
  return ("%.1f"):format(s)
end

local function paintIcon(f, a, now)
  if a.duration > 0 and a.expires > 0 then
    local left = math.max(0, a.expires - now)
    setFill(f, left / a.duration)
    f.time:SetText(fmtTime(left))
  else
    setFill(f, 1)
    f.time:SetText("")
  end
end

---------------------------------------------------------------------------
-- Qué se enseña
---------------------------------------------------------------------------
local function wanted()
  local db = ns.db
  if ns.IsDemo() then return true end
  if db.auraWhen == "always" then return true end
  if db.auraWhen == "combat" then
    return UnitAffectingCombat("player") or ns.attacking or ns.shooting
  end
  return ns.attacking or ns.shooting
end

-- Para el modo mover: los primeros de la lista, con un tiempo de prueba
local function demoList(list)
  local out, now = {}, GetTime()
  for i = 1, math.min(3, #list) do
    local icon = ns.SpellIcon(list[i].name)
    out[i] = { icon = icon or 134400, count = 0, duration = 30, expires = now + 30 - (now * 3 + i * 7) % 30 }
  end
  return out
end

local function collect(row, enabled, unit, getter)
  local db, list = ns.db, ns.char[row.kind]
  if not enabled then return {} end
  if ns.IsDemo() then return demoList(list) end
  if unit == "target" and (not UnitExists("target") or not UnitCanAttack("player", "target")) then return {} end
  local any, mine = scan(unit, getter)
  local out = {}
  for _, e in ipairs(list) do
    local a = (e.mine and mine or any)[e.name:lower()]
    if a then out[#out + 1] = a end
  end
  return out
end

-- Coloca los iconos de una fila. La fila se queda en su sitio (modo mover); aquí solo se
-- calcula su tamaño. En modo mover se ve aunque esté vacía, para poder colocarla.
local function layoutRow(row, auras, border, enabled)
  local s = ns.db.auraSize
  local x = 0
  for i, f in ipairs(row.icons) do
    local a = auras[i]
    if a then
      f:SetSize(s, s)
      f:SetBackdropBorderColor(border[1], border[2], border[3], 1)
      f.base:SetTexture(a.icon)
      f.fill:SetTexture(a.icon)
      f.count:SetText(a.count > 1 and a.count or "")
      f.aura = a
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
      x = x + s + GAP
      f:Show()
    else
      f.aura = nil
      f:Hide()
    end
  end
  local unlocked = not ns.db.locked
  if #auras > 0 then
    row:SetSize(x - GAP, s)
  else
    row:SetSize(s * 3 + GAP * 2, s) -- hueco para poder agarrarla en modo mover
  end
  row:SetShown(#auras > 0 or (unlocked and enabled))
end

-- Si algo de los buffos falla (en combate el juego puede volver «secretos» algunos datos de
-- las auras), se apaga esta parte durante la sesión y se avisa UNA vez con el error, en vez de
-- soltar un error en cada repaso y saturar el juego.
local aurasBroken
local function breakAuras(err)
  for _, row in pairs(rows) do row:Hide() end
  -- auras secretas: es lo normal en combate en Forever; no se apaga, solo se espera a salir
  if tostring(err):find("secret") then return end
  aurasBroken = true
  print("|cff33ccffAttacking|r: los buffos y debuffos han dado un error (" .. tostring(err)
    .. "). Los apago hasta que recargues. Pásale este mensaje a quien te hizo el addon.")
end

-- En combate Forever no deja a los addons leer las auras. Así que se guarda lo que había
-- al empezar el combate y se sigue contando a partir de ahí: los buffos que ya tenías se
-- vacían y desaparecen al acabarse; los que consigas en combate no se ven. Si cambias de
-- objetivo en combate, la fila de debuffos se vacía hasta salir de combate.
local snap = { buffs = {}, debuffs = {} }

-- Las del recuerdo que aún no se han acabado
local function alive(list, now)
  local out = {}
  for _, a in ipairs(list) do
    if a.duration == 0 or a.expires == 0 or a.expires > now then out[#out + 1] = a end
  end
  return out
end

function ns.ForgetTargetDebuffs()
  snap.debuffs = {}
end

local warnedCombat
local function inCombatMode()
  if not ns.inCombat or ns.IsDemo() then return false end
  if not warnedCombat and (ns.db.auraBuffs or ns.db.auraDebuffs) then
    warnedCombat = true
    print("|cff33ccffAttacking|r: en combate el juego no deja a los addons leer buffos ni debuffos. "
      .. "Se siguen mostrando los que tenías al empezar el combate (los nuevos no se ven).")
  end
  return true
end

local updateAurasImpl
function ns.UpdateAuras()
  if aurasBroken then return end
  local ok, err = pcall(updateAurasImpl)
  if not ok then breakAuras(err) end
end

updateAurasImpl = function()
  -- las listas se crean al entrar al juego, un instante después que el icono del golpe
  if not ns.built or not ns.char or not ns.char.buffs or not ns.char.debuffs then return end
  if not rows.buffs then
    rows.buffs = newRow("buffs")
    rows.debuffs = newRow("debuffs")
  end
  local db = ns.db
  local now = GetTime()
  local buffs, debuffs
  if inCombatMode() then
    -- en combate: lo que había al empezar, mientras dure
    buffs = db.auraBuffs and alive(snap.buffs, now) or {}
    debuffs = db.auraDebuffs and alive(snap.debuffs, now) or {}
  else
    -- fuera de combate se lee siempre (aunque no se vea), para tener el recuerdo al día
    buffs = collect(rows.buffs, db.auraBuffs, "player", getBuff)
    debuffs = collect(rows.debuffs, db.auraDebuffs, "target", getDebuff)
    if not ns.IsDemo() then snap.buffs, snap.debuffs = buffs, debuffs end
  end
  if not wanted() then buffs, debuffs = {}, {} end

  layoutRow(rows.buffs, buffs, BUFF_BORDER, db.auraBuffs)
  layoutRow(rows.debuffs, debuffs, DEBUFF_BORDER, db.auraDebuffs)

  for _, row in pairs(rows) do
    for _, f in ipairs(row.icons) do
      if f.aura then paintIcon(f, f.aura, now) end
    end
  end
end

---------------------------------------------------------------------------
-- Eventos y tiempos
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local elapsed = 0
local tick
ev:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed < 0.1 or aurasBroken then return end
  elapsed = 0
  local ok, err = pcall(tick)
  if not ok then breakAuras(err) end
end)

-- Repaso cada 0,1 s: aplicar cambios pendientes y avanzar los tiempos
tick = function()
  if ns.auraDirty then
    ns.auraDirty = false
    updateAurasImpl()
  end
  if not rows.buffs then return end
  local now, expired = GetTime(), false
  for _, row in pairs(rows) do
    if row:IsShown() then
      for _, f in ipairs(row.icons) do
        local a = f.aura
        if a then
          local demo = ns.IsDemo()
          if demo and a.expires <= now then a.expires = now + a.duration end -- prueba en bucle
          if not demo and a.duration > 0 and a.expires > 0 and a.expires <= now then expired = true end
          paintIcon(f, a, now)
        end
      end
    end
  end
  if expired then updateAurasImpl() end
end

ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, unit)
  if event == "PLAYER_LOGIN" then
    -- primera vez con este personaje: lista de su clase
    if not ns.char.buffs then ns.char.buffs = ns.ClassDefaults("buffs") end
    if not ns.char.debuffs then ns.char.debuffs = ns.ClassDefaults("debuffs") end
    for _, e in ipairs({ "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
      self:RegisterEvent(e)
    end
    ns.UpdateAuras()
  elseif event == "UNIT_AURA" then
    -- en combate llega muchísimas veces: se apunta y se actualiza en el siguiente repaso (0,1 s)
    if unit == "player" or unit == "target" then ns.auraDirty = true end
  elseif event == "PLAYER_TARGET_CHANGED" then
    -- en combate no se puede leer el objetivo nuevo: lo recordado era del anterior
    if ns.inCombat then ns.ForgetTargetDebuffs() end
    ns.auraDirty = true
  else
    ns.auraDirty = true
  end
end)
