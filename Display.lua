-- Attacking: los iconos que se rellenan.
-- Cada pieza (mano derecha, mano izquierda, disparo y las dos filas de Auras.lua) se coloca
-- por separado: en modo mover se arrastra cada una a su sitio.
local ADDON, ns = ...

local SLOTS = { "mh", "oh", "ranged" }
local INV = { mh = 16, oh = 17, ranged = 18 } -- ranuras de equipo
local SWORD = {
  mh = "Interface\\Icons\\INV_Sword_04",
  oh = "Interface\\Icons\\INV_Sword_05",
  ranged = "Interface\\Icons\\INV_Weapon_Bow_02",
}
local FIST = "Interface\\Icons\\INV_Gauntlets_04" -- sin arma
local SCALE = { mh = 1, oh = 0.75, ranged = 1 }   -- la mano izquierda, algo más pequeña
local CROP = 0.08                                 -- recorte del borde de los iconos del juego

-- Nombre de cada pieza en modo mover
local LABELS = {
  mh = "Mano derecha", oh = "Mano izquierda", ranged = "Disparo",
  buffs = "Mis buffos", debuffs = "Debuffos del objetivo",
}

-- Sitio de partida de cada pieza: { punto de la pieza, punto de la pantalla, x, y }
ns.DEFAULT_POS = {
  mh = { "CENTER", "CENTER", -50, -160 },
  oh = { "CENTER", "CENTER", 0, -160 },
  ranged = { "CENTER", "CENTER", 50, -160 },
  buffs = { "TOPLEFT", "CENTER", -70, -200 },
  debuffs = { "TOPLEFT", "CENTER", -70, -245 },
}

-- Resultados del golpe: texto y color (de momento sin datos en Forever: ver LEEME)
local RESULTS = {
  MISS     = { t = "¡Fallo!",   c = { 0.85, 0.85, 0.85 } },
  DODGE    = { t = "Esquivado", c = { 1, 0.85, 0.2 } },
  PARRY    = { t = "Parado",    c = { 1, 0.5, 0.15 } },
  BLOCK    = { t = "Bloqueado", c = { 0.55, 0.75, 1 } },
  DEFLECT  = { t = "Desviado",  c = { 1, 0.85, 0.2 } },
  ABSORB   = { t = "Absorbido", c = { 0.8, 0.8, 1 } },
  RESIST   = { t = "Resistido", c = { 0.75, 0.55, 1 } },
  REFLECT  = { t = "Reflejado", c = { 0.75, 0.55, 1 } },
  IMMUNE   = { t = "Inmune",    c = { 1, 1, 1 } },
  EVADE    = { t = "Evade",     c = { 1, 1, 1 } },
  CRIT     = { t = "¡Crítico!", c = { 1, 0.25, 0.2 }, minor = true },
  GLANCING = { t = "Rozado",    c = { 0.7, 0.7, 0.6 }, minor = true },
}
local DEMO = { mh = "MISS", oh = "PARRY", ranged = "DODGE" } -- en modo mover / vista previa
local RESULT_HOLD, RESULT_FADE = 0.8, 0.5

local built
local icons = {}

---------------------------------------------------------------------------
-- Piezas movibles (también las filas de Auras.lua)
---------------------------------------------------------------------------
local movers = {}

function ns.PlaceMover(key)
  local f = movers[key]
  local pt = ns.db.pos[key] or ns.DEFAULT_POS[key]
  f:ClearAllPoints()
  f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
end

function ns.MakeMover(key, f)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.pos[key] = { p, rp, x, y }
  end)
  -- clic derecho mientras se mueve: fijarlo todo
  f:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ns.SetLocked(true) end
  end)
  -- recuadro azul y nombre, solo en modo mover
  f.moverBG = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  f.moverBG:SetColorTexture(0.1, 0.4, 0.8, 0.35)
  f.moverBG:SetPoint("TOPLEFT", -3, 3)
  f.moverBG:SetPoint("BOTTOMRIGHT", 3, -3)
  f.moverBG:Hide()
  f.moverLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.moverLabel:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 4)
  f.moverLabel:SetText(LABELS[key] or key)
  f.moverLabel:Hide()
  f:EnableMouse(false)
  movers[key] = f
  ns.PlaceMover(key)
  if ns.StyleMovers then ns.StyleMovers() end
end

-- Ratón, recuadros, opacidad y nivel de dibujo de todas las piezas
function ns.StyleMovers()
  local db = ns.db
  local unlocked = not db.locked
  local strata = ns.preview and "FULLSCREEN_DIALOG" or "MEDIUM"
  for _, f in pairs(movers) do
    f:EnableMouse(unlocked)
    f.moverBG:SetShown(unlocked)
    f.moverLabel:SetShown(unlocked)
    -- moviendo se ve todo opaco para colocarlo bien; si no, con la opacidad elegida
    f:SetAlpha(unlocked and 1 or (db.alpha or 1))
    -- (cambiar el nivel de dibujo es caro: solo si de verdad cambia)
    if f:GetFrameStrata() ~= strata then f:SetFrameStrata(strata) end
  end
end

function ns.ResetPosition()
  ns.db.pos = {}
  for key in pairs(movers) do ns.PlaceMover(key) end
end

---------------------------------------------------------------------------
-- Iconos del golpe
---------------------------------------------------------------------------
local function texFor(slot)
  if ns.db.iconStyle == "weapon" then
    local t = GetInventoryItemTexture("player", INV[slot])
    if t then return t end
    if slot == "mh" then return FIST end
  end
  return SWORD[slot]
end

local function newIcon(slot)
  local f = CreateFrame("Frame", "Attacking_" .. slot, UIParent, "BackdropTemplate")
  f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  f:SetBackdropBorderColor(0, 0, 0, 1)

  -- abajo: el icono en gris; encima: el mismo a color, que crece de abajo arriba
  f.base = f:CreateTexture(nil, "BACKGROUND")
  f.base:SetPoint("TOPLEFT", 1, -1)
  f.base:SetPoint("BOTTOMRIGHT", -1, 1)
  f.base:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
  f.base:SetDesaturated(true)
  f.base:SetVertexColor(0.45, 0.45, 0.45)
  f.fill = f:CreateTexture(nil, "ARTWORK")
  f.fill:SetPoint("BOTTOMLEFT", 1, 1)
  f.fill:SetPoint("BOTTOMRIGHT", -1, 1)

  -- destello al estar listo
  f.glow = f:CreateTexture(nil, "OVERLAY")
  f.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  f.glow:SetBlendMode("ADD")
  f.glow:SetPoint("CENTER")
  f.glow:SetAlpha(0)
  local ag = f.glow:CreateAnimationGroup()
  local up = ag:CreateAnimation("Alpha")
  up:SetFromAlpha(0)
  up:SetToAlpha(1)
  up:SetDuration(0.08)
  up:SetOrder(1)
  local down = ag:CreateAnimation("Alpha")
  down:SetFromAlpha(1)
  down:SetToAlpha(0)
  down:SetDuration(0.35)
  down:SetOrder(2)
  f.flash = ag

  -- segundos que faltan, debajo del icono
  f.text = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  f.text:SetPoint("TOP", f, "BOTTOM", 0, -2)

  -- resultado del golpe (al lado o encima; se coloca en ns.Refresh)
  f.result = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.result:SetShadowOffset(1, -1)
  f.result:Hide()

  f.slot = slot
  f:Hide()
  ns.MakeMover(slot, f)
  return f
end

-- p: 0 = vacío, 1 = lleno
local function setFill(f, p)
  local inner = f:GetHeight() - 2
  if p <= 0.01 or inner <= 0 then
    f.fill:Hide()
    return
  end
  f.fill:SetHeight(inner * p)
  local span = 1 - 2 * CROP
  f.fill:SetTexCoord(CROP, 1 - CROP, (1 - CROP) - span * p, 1 - CROP)
  f.fill:Show()
end

function ns.UpdateTextures()
  if not built then return end
  for _, slot in ipairs(SLOTS) do
    local tex = texFor(slot)
    icons[slot].base:SetTexture(tex)
    icons[slot].fill:SetTexture(tex)
  end
end

local function hasOffHand()
  return ns.SpeedOf("oh") ~= nil -- (la velocidad en combate es secreta: ver Attacking.lua)
end

-- Fuera del disparo, el icono de disparo solo tiene sentido para cazadores con arma a distancia
local function hunterWithRanged()
  local _, class = UnitClass("player")
  return class == "HUNTER" and GetInventoryItemID("player", INV.ranged) ~= nil
end

-- Según «Cuándo se ve»: ¿toca enseñar los iconos aunque no estés atacando?
local function shownByMode()
  local mode = ns.db.iconWhen
  return mode == "always" or (mode == "combat" and ns.inCombat)
end

-- Qué iconos se ven y cómo
function ns.Refresh()
  if not built then return end
  local db = ns.db
  local want
  if ns.IsDemo() then
    -- para colocarlo o en la vista previa: se ven todos los que tengas activados
    want = { mh = true, oh = db.showOff, ranged = db.showRanged }
  else
    local byMode = shownByMode()
    -- «atacando» = el juego lo dice, o su barra de golpe está en marcha
    local melee = ns.attacking or ns.BlizShown("mh") or byMode
    local shooting = ns.shooting or ns.BlizShown("ranged")
    want = {
      mh = melee,
      oh = (melee or ns.BlizShown("oh")) and db.showOff and hasOffHand(),
      ranged = db.showRanged and (shooting or (byMode and hunterWithRanged())),
    }
  end

  local side = db.resultPos == "side"
  for _, slot in ipairs(SLOTS) do
    local f = icons[slot]
    if want[slot] then
      local s = db.size * SCALE[slot]
      f:SetSize(s, s)
      f.glow:SetSize(s * 1.8, s * 1.8)
      f.result:ClearAllPoints()
      if side then
        f.result:SetPoint("LEFT", f, "RIGHT", 6, 0)
      else
        f.result:SetPoint("BOTTOM", f, "TOP", 0, 3)
      end
      f:Show()
    else
      f:Hide()
    end
  end
  ns.StyleMovers()
  if ns.UpdateAuras then ns.UpdateAuras() end
end

local function setResult(f, kind)
  local r = RESULTS[kind]
  f.result:SetText(r.t)
  f.result:SetTextColor(r.c[1], r.c[2], r.c[3])
end

-- Llamado con lo que ha pasado en el golpe (de momento no hay de dónde sacarlo en Forever)
function ns.ShowResult(slot, kind)
  local db = ns.db
  local f = icons[slot]
  local r = RESULTS[kind]
  if not f or not r or not db.showResult or ns.IsDemo() then return end
  if r.minor and not db.resultCrit then return end
  setResult(f, kind)
  f.resultUntil = GetTime() + RESULT_HOLD + RESULT_FADE
  f.result:SetAlpha(1)
  f.result:Show()
end

-- Prueba en marcha (relleno en bucle y textos de ejemplo): al desbloquear para mover,
-- o mientras están abiertos los ajustes (vista previa)
function ns.IsDemo()
  return not ns.db.locked or ns.preview == true
end

function ns.SetPreview(on)
  on = on and true or false
  if ns.preview == on then return end
  ns.preview = on
  ns.Refresh()
end

function ns.SetLocked(locked)
  ns.db.locked = locked
  if not locked then
    print("|cff33ccffAttacking|r: arrastra cada pieza a su sitio. Clic derecho en cualquiera para fijarlas.")
  end
  ns.Refresh()
  if ns.RefreshOptions then ns.RefreshOptions() end
end

---------------------------------------------------------------------------
-- Barras de golpe de Blizzard
---------------------------------------------------------------------------
-- OJO (0.4.0): ponerlas invisibles EN CADA FOTOGRAMA provocó un tira y afloja con la barra de
-- Forever (sonido entrecortado y aviso de rendimiento). Ahora solo se toca su transparencia
-- cuando cambia la opción o aparece una barra nueva, nunca en bucle.
local touched = {}   -- [marco] = transparencia que le pusimos
function ns.ApplyBlizzardAlpha()
  for _, slot in ipairs(SLOTS) do
    local f = ns.BlizFrame(slot)
    if f then
      if ns.db.hideBlizzard then
        if touched[f] ~= 0 then f:SetAlpha(0) touched[f] = 0 end
      elseif touched[f] then
        f:SetAlpha(1)   -- solo si la habíamos tocado nosotros
        touched[f] = nil
      end
    end
  end
end

-- Si alguna barra del juego aparece o desaparece, se recolocan los iconos.
-- Se mira 10 veces por segundo y se recoloca como mucho 5 veces por segundo.
local lastBliz, watchT, lastRefresh = nil, 0, 0
local function watchBlizzard(dt)
  watchT = watchT + dt
  if watchT < 0.1 then return end
  watchT = 0
  local key = ""
  for _, slot in ipairs(SLOTS) do
    local f = ns.BlizFrame(slot)
    key = key .. ((f and f:IsShown()) and "1" or "0")
  end
  if key ~= lastBliz and GetTime() - lastRefresh >= 0.2 then
    lastBliz = key
    lastRefresh = GetTime()
    ns.ApplyBlizzardAlpha()
    ns.Refresh()
  end
end

---------------------------------------------------------------------------
-- Cada fotograma
---------------------------------------------------------------------------
local onUpdateImpl

-- Lo que se hace en cada fotograma, protegido: si falla, NO se suelta un error por fotograma
-- (eso satura el juego y salta el aviso de «tus addons dan muchos problemas»). Se avisa una
-- vez con el error y el icono se queda quieto.
local updateBroken
local function onUpdate(self, dt)
  if updateBroken then return end
  local ok, err = pcall(onUpdateImpl, self, dt)
  if not ok then
    updateBroken = true
    print("|cff33ccffAttacking|r: error al dibujar el icono (" .. tostring(err)
      .. "). Lo paro hasta que recargues. Pásale este mensaje a quien te hizo el addon.")
  end
end

onUpdateImpl = function(_, dt)
  local db = ns.db
  watchBlizzard(dt or 0)
  local demo = ns.IsDemo()
  for _, slot in ipairs(SLOTS) do
    local f = icons[slot]
    if f:IsShown() then
      local p, rem
      if not demo then
        p, rem = ns.Progress(slot)
      else
        -- prueba: se rellena en bucle cada 2,5 s
        local d = 2.5
        local e = (GetTime() + (slot == "oh" and 0.8 or slot == "ranged" and 1.6 or 0)) % d
        p, rem = e / d, d - e
      end
      setFill(f, p)
      if db.showText and rem > 0 then
        f.text:SetFormattedText("%.1f", rem)
      else
        f.text:SetText("")
      end
      -- resultado del golpe: se queda un momento y se desvanece
      if not db.showResult then
        f.result:Hide()
      elseif demo then
        setResult(f, DEMO[slot])
        f.result:SetAlpha(1)
        f.result:Show()
      elseif f.resultUntil then
        local left = f.resultUntil - GetTime()
        if left <= 0 then
          f.resultUntil = nil
          f.result:Hide()
        else
          f.result:SetAlpha(math.min(1, left / RESULT_FADE))
        end
      else
        f.result:Hide()
      end

      -- destello una vez por golpe, al llenarse
      local t = ns.T[slot]
      if not demo and p >= 1 and not t.flashed then
        t.flashed = true
        if db.flash then f.flash:Play() end
      end
    end
  end
end

function ns.BuildDisplay()
  for _, slot in ipairs(SLOTS) do icons[slot] = newIcon(slot) end
  built = true
  ns.built = true
  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", onUpdate)
  ns.UpdateTextures()
  ns.Refresh()
end
