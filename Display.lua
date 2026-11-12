-- Attacking: los iconos que se rellenan
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
local GAP = 6
local SIDE_GAP = 80                               -- con el resultado al lado, sitio para el texto
local CROP = 0.08                                 -- recorte del borde de los iconos del juego

-- Resultados del golpe: texto y color
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
local DEMO = { mh = "MISS", oh = "PARRY", ranged = "DODGE" } -- en modo mover
local RESULT_HOLD, RESULT_FADE = 0.8, 0.5

local anchor, label
local icons = {}

local function texFor(slot)
  if ns.db.iconStyle == "weapon" then
    local t = GetInventoryItemTexture("player", INV[slot])
    if t then return t end
    if slot == "mh" then return FIST end
  end
  return SWORD[slot]
end

local function newIcon(slot)
  local f = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
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
  if not anchor then return end
  for _, slot in ipairs(SLOTS) do
    local tex = texFor(slot)
    icons[slot].base:SetTexture(tex)
    icons[slot].fill:SetTexture(tex)
  end
end

local function hasOffHand()
  local _, oh = UnitAttackSpeed("player")
  return oh ~= nil and oh > 0
end

-- Qué iconos se ven y dónde
function ns.Refresh()
  if not anchor then return end
  local db = ns.db
  local want
  if not db.locked then
    -- para colocarlo: se ven todos los que tengas activados, con un relleno de prueba
    want = { mh = true, oh = db.showOff, ranged = db.showRanged }
  else
    want = {
      mh = ns.attacking,
      oh = ns.attacking and db.showOff and hasOffHand(),
      ranged = ns.shooting and db.showRanged,
    }
  end

  local side = db.showResult and db.resultPos == "side"
  local gap = side and SIDE_GAP or GAP
  local x = 0
  for _, slot in ipairs(SLOTS) do
    local f = icons[slot]
    if want[slot] then
      local s = db.size * SCALE[slot]
      f:SetSize(s, s)
      f.glow:SetSize(s * 1.8, s * 1.8)
      f:ClearAllPoints()
      f:SetPoint("LEFT", anchor, "LEFT", x, 0)
      f.result:ClearAllPoints()
      if side then
        f.result:SetPoint("LEFT", f, "RIGHT", 6, 0)
      else
        f.result:SetPoint("BOTTOM", f, "TOP", 0, 3)
      end
      x = x + s + gap
      f:Show()
    else
      f:Hide()
    end
  end
  anchor:SetSize(math.max(x - gap, db.size), db.size)

  -- modo mover
  anchor:EnableMouse(not db.locked)
  if db.locked then
    anchor:SetBackdropColor(0, 0, 0, 0)
    anchor:SetBackdropBorderColor(0, 0, 0, 0)
    label:Hide()
  else
    anchor:SetBackdropColor(0.1, 0.4, 0.8, 0.25)
    anchor:SetBackdropBorderColor(0.3, 0.6, 1, 0.9)
    label:Show()
  end
end

local function setResult(f, kind)
  local r = RESULTS[kind]
  f.result:SetText(r.t)
  f.result:SetTextColor(r.c[1], r.c[2], r.c[3])
end

-- Llamado desde Attacking.lua con lo que ha pasado en el golpe
function ns.ShowResult(slot, kind)
  local db = ns.db
  local f = icons[slot]
  local r = RESULTS[kind]
  if not f or not r or not db.showResult or not db.locked then return end
  if r.minor and not db.resultCrit then return end
  setResult(f, kind)
  f.resultUntil = GetTime() + RESULT_HOLD + RESULT_FADE
  f.result:SetAlpha(1)
  f.result:Show()
end

function ns.SavePosition()
  local p, _, rp, x, y = anchor:GetPoint()
  ns.db.point = { p, rp, x, y }
end

function ns.ResetPosition()
  ns.db.point = { unpack(ns.DEFAULTS.point) }
  anchor:ClearAllPoints()
  anchor:SetPoint(ns.db.point[1], UIParent, ns.db.point[2], ns.db.point[3], ns.db.point[4])
end

function ns.SetLocked(locked)
  ns.db.locked = locked
  ns.Refresh()
  if ns.RefreshOptions then ns.RefreshOptions() end
end

local function onUpdate()
  local db = ns.db
  for _, slot in ipairs(SLOTS) do
    local f = icons[slot]
    if f:IsShown() then
      local p, rem
      if db.locked then
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
      elseif not db.locked then
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
      if db.locked and p >= 1 and not t.flashed then
        t.flashed = true
        if db.flash then f.flash:Play() end
      end
    end
  end
end

function ns.BuildDisplay()
  anchor = CreateFrame("Frame", "AttackingAnchor", UIParent, "BackdropTemplate")
  anchor:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
  })
  anchor:SetClampedToScreen(true)
  anchor:SetMovable(true)
  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", anchor.StartMoving)
  anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.SavePosition()
  end)
  -- clic derecho mientras se mueve: bloquear
  anchor:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ns.SetLocked(true) end
  end)
  local pt = ns.db.point
  anchor:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])

  label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("BOTTOM", anchor, "TOP", 0, 4)
  label:SetText("Attacking: arrastra para mover · clic derecho para fijar")

  for _, slot in ipairs(SLOTS) do icons[slot] = newIcon(slot) end
  anchor:SetScript("OnUpdate", onUpdate)
  ns.UpdateTextures()
  ns.Refresh()
end
