-- Attacking: el dibujo de la carga del golpe.
-- Cuatro estilos: «icon» (el icono se rellena), «clock» (reloj sobre el icono), «bar» (barra
-- fina) y «pips» (puntos que se encienden). Cada pieza (mano derecha, mano izquierda, disparo)
-- se coloca por separado en modo mover.
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
local WHITE = "Interface\\Buttons\\WHITE8X8"
local PIPS = 5

-- Color de cada mano: dorada la derecha, azul la izquierda, verde el disparo
local COLORS = {
  mh = { 1, 0.78, 0.25 },
  oh = { 0.45, 0.75, 1 },
  ranged = { 0.5, 0.9, 0.45 },
}

local LABELS = { mh = "Mano derecha", oh = "Mano izquierda", ranged = "Disparo" }

-- Resultado del golpe: texto y color
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
local DEMO_RESULT = { mh = "MISS", oh = "PARRY", ranged = "DODGE" } -- en la vista previa
local RESULT_HOLD, RESULT_FADE = 0.8, 0.5
local MATCH_WINDOW = 0.35 -- un resultado es tuyo si tu barra se reinició a menos de esto (s)

-- Sitio de partida de cada pieza: { punto de la pieza, punto de la pantalla, x, y }.
-- Iconos en fila; barras y puntos uno debajo de otro (son anchos).
local function defaultPos(key)
  local style = ns.db.style
  if style == "bar" or style == "pips" then
    local y = { mh = -160, oh = -180, ranged = -200 }
    return { "CENTER", "CENTER", 0, y[key] }
  end
  local x = { mh = -50, oh = 0, ranged = 50 }
  return { "CENTER", "CENTER", x[key], -160 }
end

local function isIconStyle()
  local s = ns.db.style
  return s == "icon" or s == "clock"
end

local built
local pieces = {}

---------------------------------------------------------------------------
-- Cuadrícula del modo mover
---------------------------------------------------------------------------
-- Líneas cada gridSize píxeles desde el centro de la pantalla (las centrales en rojo).
local grid
local function buildGrid()
  if not grid then
    grid = CreateFrame("Frame", nil, UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("BACKGROUND")
    grid.lines = {}
    grid:Hide()
  end
  for _, t in ipairs(grid.lines) do t:Hide() end
  local size = ns.db.gridSize or 32
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  local n = 0
  local function line(vertical, offset)
    n = n + 1
    local t = grid.lines[n]
    if not t then
      t = grid:CreateTexture(nil, "BACKGROUND")
      grid.lines[n] = t
    end
    t:ClearAllPoints()
    if vertical then
      t:SetSize(1, h)
      t:SetPoint("CENTER", grid, "CENTER", offset, 0)
    else
      t:SetSize(w, 1)
      t:SetPoint("CENTER", grid, "CENTER", 0, offset)
    end
    if offset == 0 then
      t:SetColorTexture(1, 0.3, 0.2, 0.6)  -- líneas centrales
    else
      t:SetColorTexture(1, 1, 1, 0.12)
    end
    t:Show()
  end
  line(true, 0)
  line(false, 0)
  for k = 1, math.ceil(w / 2 / size) do
    line(true, k * size)
    line(true, -k * size)
  end
  for k = 1, math.ceil(h / 2 / size) do
    line(false, k * size)
    line(false, -k * size)
  end
  grid.builtFor = size .. ":" .. w .. "x" .. h
end

local function showGrid(on)
  if on then
    local size = ns.db.gridSize or 32
    local key = size .. ":" .. UIParent:GetWidth() .. "x" .. UIParent:GetHeight()
    if not grid or grid.builtFor ~= key then buildGrid() end
    grid:Show()
  elseif grid then
    grid:Hide()
  end
end

-- Imán: en un eje, cuánto hay que mover la pieza para que su borde inicial, su centro o su
-- borde final (lo que esté más cerca) caiga justo en una línea de la cuadrícula.
local function snapShift(lo, hi, size)
  local best
  for _, v in ipairs({ lo, (lo + hi) / 2, hi }) do
    local d = math.floor(v / size + 0.5) * size - v
    if not best or math.abs(d) < math.abs(best) then best = d end
  end
  return best
end

-- Al soltar una pieza: se ajusta a la cuadrícula (salvo con Mayús pulsada). Se guarda por su centro.
local function snapPosition(f)
  local cx, cy = UIParent:GetCenter()
  local l, r = f:GetLeft() - cx, f:GetRight() - cx
  local b, t = f:GetBottom() - cy, f:GetTop() - cy
  local dx, dy = 0, 0
  if ns.db.snap and not IsShiftKeyDown() then
    local size = ns.db.gridSize or 32
    dx, dy = snapShift(l, r, size), snapShift(b, t, size)
  end
  return { "CENTER", "CENTER", (l + r) / 2 + dx, (b + t) / 2 + dy }
end

---------------------------------------------------------------------------
-- Piezas movibles
---------------------------------------------------------------------------
function ns.PlaceMover(key)
  local f = pieces[key]
  local pt = ns.db.pos[key] or defaultPos(key)
  f:ClearAllPoints()
  f:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
end

local function makeMover(key, f)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.db.pos[key] = snapPosition(self)
    ns.PlaceMover(key)
  end)
  -- clic derecho mientras se mueve: fijarlo todo
  f:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ns.SetLocked(true) end
  end)
  -- recuadro azul (del tamaño exacto de la pieza) y nombre, solo en modo mover
  f.moverBG = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  f.moverBG:SetColorTexture(0.1, 0.4, 0.8, 0.35)
  f.moverBG:SetAllPoints(f)
  f.moverBG:Hide()
  f.moverLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.moverLabel:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 4)
  f.moverLabel:SetText(LABELS[key])
  f.moverLabel:Hide()
  f:EnableMouse(false)
end

-- Ratón, recuadros, opacidad y nivel de dibujo de todas las piezas
function ns.StyleMovers()
  local db = ns.db
  local unlocked = not db.locked
  local strata = ns.preview and "FULLSCREEN_DIALOG" or "MEDIUM"
  showGrid(unlocked and db.grid)
  for _, f in pairs(pieces) do
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
  for key in pairs(pieces) do ns.PlaceMover(key) end
end

---------------------------------------------------------------------------
-- Cada pieza: tiene las partes de los cuatro estilos y enseña las del elegido
---------------------------------------------------------------------------
local function texFor(slot)
  if ns.db.iconStyle == "weapon" then
    local t = GetInventoryItemTexture("player", INV[slot])
    if t then return t end
    if slot == "mh" then return FIST end
  end
  return SWORD[slot]
end

local function alphaPulse(region, peak, up, down)
  local ag = region:CreateAnimationGroup()
  local a1 = ag:CreateAnimation("Alpha")
  a1:SetFromAlpha(0)
  a1:SetToAlpha(peak)
  a1:SetDuration(up)
  a1:SetOrder(1)
  local a2 = ag:CreateAnimation("Alpha")
  a2:SetFromAlpha(peak)
  a2:SetToAlpha(0)
  a2:SetDuration(down)
  a2:SetOrder(2)
  return ag
end

local function newPiece(slot)
  local c = COLORS[slot]
  local f = CreateFrame("Frame", "Attacking_" .. slot, UIParent, "BackdropTemplate")
  f:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropBorderColor(0, 0, 0, 1)
  f.slot = slot

  -- «icon»: el icono en gris y encima el mismo a color, que crece de abajo arriba
  f.base = f:CreateTexture(nil, "BACKGROUND")
  f.base:SetPoint("TOPLEFT", 1, -1)
  f.base:SetPoint("BOTTOMRIGHT", -1, 1)
  f.base:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
  f.fill = f:CreateTexture(nil, "ARTWORK")
  f.fill:SetPoint("BOTTOMLEFT", 1, 1)
  f.fill:SetPoint("BOTTOMRIGHT", -1, 1)

  -- «clock»: sombra que gira como el tiempo de reutilización de una habilidad
  f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
  f.cd:SetPoint("TOPLEFT", 1, -1)
  f.cd:SetPoint("BOTTOMRIGHT", -1, 1)
  f.cd:SetDrawEdge(true)
  if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(true) end
  if f.cd.SetDrawBling then f.cd:SetDrawBling(false) end
  f.cd:Hide()

  -- «bar»: fondo oscuro, relleno de color y un brillo en el extremo
  f.barBG = f:CreateTexture(nil, "BACKGROUND")
  f.barBG:SetPoint("TOPLEFT", 1, -1)
  f.barBG:SetPoint("BOTTOMRIGHT", -1, 1)
  f.barBG:SetColorTexture(0, 0, 0, 0.55)
  f.barFill = f:CreateTexture(nil, "ARTWORK")
  f.barFill:SetPoint("TOPLEFT", 1, -1)
  f.barFill:SetPoint("BOTTOMLEFT", 1, 1)
  f.barFill:SetTexture(WHITE)
  -- degradado de más oscuro a más claro (si el cliente no lo admite, color plano)
  local okGrad = pcall(function()
    f.barFill:SetGradient("HORIZONTAL", CreateColor(c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1),
      CreateColor(c[1], c[2], c[3], 1))
  end)
  if not okGrad then f.barFill:SetVertexColor(c[1], c[2], c[3]) end
  f.spark = f:CreateTexture(nil, "OVERLAY")
  f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  f.spark:SetBlendMode("ADD")

  -- «pips»: puntos que se encienden
  f.pips = {}
  for i = 1, PIPS do
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetTexture(WHITE)
    f.pips[i] = t
  end

  -- destello al estar listo: borde brillante en los iconos, fogonazo suave en barra y puntos
  f.glow = f:CreateTexture(nil, "OVERLAY")
  f.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  f.glow:SetBlendMode("ADD")
  f.glow:SetPoint("CENTER")
  f.glow:SetAlpha(0)
  f.glowAnim = alphaPulse(f.glow, 1, 0.08, 0.35)
  f.burst = f:CreateTexture(nil, "OVERLAY")
  f.burst:SetTexture(WHITE)
  f.burst:SetBlendMode("ADD")
  f.burst:SetVertexColor(c[1], c[2], c[3])
  f.burst:SetPoint("TOPLEFT", -2, 2)
  f.burst:SetPoint("BOTTOMRIGHT", 2, -2)
  f.burst:SetAlpha(0)
  f.burstAnim = alphaPulse(f.burst, 0.55, 0.06, 0.4)

  -- segundos que faltan
  f.text = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")

  -- resultado del golpe (al lado o encima; se coloca en applyStyle)
  f.result = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.result:SetShadowOffset(1, -1)
  f.result:Hide()

  f:Hide()
  makeMover(slot, f)
  return f
end

-- Enseña las partes del estilo elegido y les da tamaño
local function applyStyle(f)
  local db, slot = ns.db, f.slot
  local style = db.style
  local s = db.size * SCALE[slot]
  local icon, clock, bar, pips = style == "icon", style == "clock", style == "bar", style == "pips"

  f.base:SetShown(icon or clock)
  f.fill:SetShown(icon)
  f.cd:SetShown(clock)
  f.barBG:SetShown(bar)
  f.barFill:SetShown(bar)
  f.spark:SetShown(bar)
  for _, t in ipairs(f.pips) do t:SetShown(pips) end

  -- el icono, en gris para «icon» (debajo del relleno) y a color para «clock»
  f.base:SetDesaturated(icon)
  if icon then f.base:SetVertexColor(0.45, 0.45, 0.45) else f.base:SetVertexColor(1, 1, 1) end

  f.text:ClearAllPoints()
  if icon or clock then
    f:SetSize(s, s)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f.glow:SetSize(s * 1.8, s * 1.8)
    f.text:SetPoint("TOP", f, "BOTTOM", 0, -2)
  elseif bar then
    local h = math.max(6, math.floor(s / 5 + 0.5))
    f:SetSize(math.floor(s * 3.2 + 0.5), h)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f.spark:SetSize(h * 2, h * 2.6)
    f.text:SetPoint("LEFT", f, "RIGHT", 6, 0)
  else -- pips
    local pip = math.max(6, math.floor(s / 4 + 0.5))
    local gap = math.max(2, math.floor(pip / 3 + 0.5))
    f:SetSize(PIPS * pip + (PIPS - 1) * gap, pip)
    f:SetBackdropBorderColor(0, 0, 0, 0) -- cada punto lleva su propio color, sin marco
    for i, t in ipairs(f.pips) do
      t:ClearAllPoints()
      t:SetSize(pip, pip)
      t:SetPoint("LEFT", f, "LEFT", (i - 1) * (pip + gap), 0)
    end
    f.text:SetPoint("LEFT", f, "RIGHT", 6, 0)
  end
  -- resultado: encima, o al lado (en barra y puntos, a continuación de los segundos)
  f.result:ClearAllPoints()
  if db.resultPos == "top" then
    f.result:SetPoint("BOTTOM", f, "TOP", 0, 3)
  elseif icon or clock then
    f.result:SetPoint("LEFT", f, "RIGHT", 6, 0)
  else
    f.result:SetPoint("LEFT", f.text, "RIGHT", 6, 0)
  end
  f.cdStart, f.cdDur = nil, nil
end

local function setResult(f, kind)
  local r = RESULTS[kind]
  f.result:SetText(r.t)
  f.result:SetTextColor(r.c[1], r.c[2], r.c[3])
end

local function showResult(slot, kind)
  local db, f, r = ns.db, pieces[slot], RESULTS[kind]
  if not f or not r or not f:IsShown() then return end
  if r.minor and not db.resultCrit then return end
  setResult(f, kind)
  f.resultUntil = GetTime() + RESULT_HOLD + RESULT_FADE
  f.result:SetAlpha(1)
  f.result:Show()
end

-- Lo que ha pasado a tu objetivo (Attacking.lua) se reparte entre las piezas: si coincide con
-- el reinicio de tu barra de golpe, es tuyo y de esa mano. Si no coincide con nada, solo se
-- enseña yendo solo (en grupo podría ser de otro), salvo que se pida también en grupo.
local function processResults(now)
  local q = ns.pendingResults
  if not q or #q == 0 then return end
  local db = ns.db
  local i = 1
  while q[i] do
    local item = q[i]
    if now - item.t < MATCH_WINDOW then
      i = i + 1 -- aún puede llegar el reinicio de la barra: se espera un poco
    else
      table.remove(q, i)
      if db.showResult and not ns.IsDemo() then
        local slot, best
        for _, s in ipairs(SLOTS) do
          local r = ns.ResetAt(s)
          if r and pieces[s]:IsShown() then
            local d = math.abs(r - item.t)
            if d <= MATCH_WINDOW and (not best or d < best) then slot, best = s, d end
          end
        end
        if not slot and (db.resultGroup or not IsInGroup()) then
          slot = ns.shooting and "ranged" or "mh"
        end
        if slot then showResult(slot, item.kind) end
      end
    end
  end
end

-- p: 0 = acaba de golpear, 1 = listo. rem: segundos que faltan.
local function setProgress(f, p, rem)
  local style = ns.db.style
  local c = COLORS[f.slot]
  if style == "icon" then
    local inner = f:GetHeight() - 2
    if p <= 0.01 or inner <= 0 then
      f.fill:Hide()
    else
      f.fill:SetHeight(inner * p)
      local span = 1 - 2 * CROP
      f.fill:SetTexCoord(CROP, 1 - CROP, (1 - CROP) - span * p, 1 - CROP)
      f.fill:Show()
    end

  elseif style == "clock" then
    if p >= 1 or rem <= 0 then
      if f.cdStart then f.cd:SetCooldown(0, 0) f.cdStart = nil end
    else
      -- duración total estimada y cuándo empezó; solo se le pasa al reloj si cambia de verdad
      local dur = rem / (1 - p)
      local start = GetTime() - p * dur
      if not f.cdStart or math.abs(start - f.cdStart) > 0.05 or math.abs(dur - f.cdDur) > 0.05 then
        f.cd:SetCooldown(start, dur)
        f.cdStart, f.cdDur = start, dur
      end
    end

  elseif style == "bar" then
    local inner = f:GetWidth() - 2
    local w = math.max(0.001, inner * p)
    f.barFill:SetWidth(w)
    f.barFill:SetShown(p > 0.005)
    f.spark:ClearAllPoints()
    f.spark:SetPoint("CENTER", f, "LEFT", 1 + w, 0)
    f.spark:SetShown(p > 0.005 and p < 1)

  else -- pips
    local lit = p * PIPS
    for i, t in ipairs(f.pips) do
      if i <= lit then
        t:SetVertexColor(c[1], c[2], c[3], 1)               -- encendido
      elseif i - 1 < lit then
        local part = lit - (i - 1)                            -- encendiéndose
        t:SetVertexColor(c[1], c[2], c[3], 0.25 + 0.6 * part)
      else
        t:SetVertexColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 0.55) -- apagado
      end
    end
  end

  if ns.db.showText and rem > 0 then
    f.text:SetFormattedText("%.1f", rem)
  else
    f.text:SetText("")
  end
end

local function flash(f)
  if isIconStyle() then f.glowAnim:Play() else f.burstAnim:Play() end
end

function ns.UpdateTextures()
  if not built then return end
  for _, slot in ipairs(SLOTS) do
    local tex = texFor(slot)
    pieces[slot].base:SetTexture(tex)
    pieces[slot].fill:SetTexture(tex)
  end
end

---------------------------------------------------------------------------
-- Qué piezas se ven
---------------------------------------------------------------------------
local function hasOffHand()
  return ns.SpeedOf("oh") ~= nil -- (la velocidad en combate es secreta: ver Attacking.lua)
end

-- Fuera del disparo, la pieza de disparo solo tiene sentido para cazadores con arma a distancia
local function hunterWithRanged()
  local _, class = UnitClass("player")
  return class == "HUNTER" and GetInventoryItemID("player", INV.ranged) ~= nil
end

-- Según «Cuándo se ve».
-- OJO: en Forever las barras de golpe de Blizzard pueden estar visibles aunque no estés en
-- combate (la de disparo, incluso sin disparar): visible solo cuenta si además estás en combate,
-- y para el disparo solo vale el aviso del juego de que empiezas a disparar.
local function wantedByMode()
  local db, mode = ns.db, ns.db.iconWhen
  local attacking = ns.attacking or (ns.inCombat and ns.BlizShown("mh"))
  local shooting = ns.shooting
  local melee, ranged
  if mode == "always" then
    melee = true
    ranged = shooting or hunterWithRanged()
  elseif mode == "combat" then
    melee = ns.inCombat
    ranged = ns.inCombat and (shooting or hunterWithRanged())
  else -- "attack": mientras atacas
    melee = attacking
    ranged = shooting
  end
  return {
    mh = melee,
    oh = melee and db.showOff and hasOffHand(),
    ranged = db.showRanged and ranged,
  }
end

local lastStyle
function ns.Refresh()
  if not built then return end
  local db = ns.db
  local want
  if ns.IsDemo() then
    -- para colocarlo o en la vista previa: se ven todas las que tengas activadas
    want = { mh = true, oh = db.showOff, ranged = db.showRanged }
  else
    want = wantedByMode()
  end
  -- al cambiar de estilo, las piezas sin sitio propio van al de partida de ese estilo
  if db.style ~= lastStyle then
    lastStyle = db.style
    for _, slot in ipairs(SLOTS) do ns.PlaceMover(slot) end
  end
  for _, slot in ipairs(SLOTS) do
    local f = pieces[slot]
    if want[slot] then
      applyStyle(f)
      f:Show()
    else
      f:Hide()
    end
  end
  ns.StyleMovers()
end

-- Prueba en marcha (relleno en bucle): al desbloquear para mover, o con los ajustes abiertos
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
-- Forever (sonido entrecortado y aviso de rendimiento). Solo se toca su transparencia cuando
-- cambia la opción o aparece una barra nueva, nunca en bucle.
local touched = {}
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

-- Cada 0,1 s se mira si alguna barra del juego aparece o desaparece (y se recoloca como
-- mucho 5 veces por segundo). Cada segundo, fuera de combate, se guarda la velocidad de ataque.
local lastBliz, watchT, lastRefresh, warmT = nil, 0, 0, 0
local function watchBlizzard(dt)
  warmT = warmT + dt
  if warmT >= 1 then
    warmT = 0
    ns.WarmSpeeds()
  end
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
-- Cada fotograma (protegido: si falla, se avisa una vez y se para, sin soltar errores en bucle)
---------------------------------------------------------------------------
local DEMO_OFFSET = { mh = 0, oh = 0.8, ranged = 1.6 }

local function onUpdateImpl(_, dt)
  watchBlizzard(dt or 0)
  local demo = ns.IsDemo()
  processResults(GetTime())
  for _, slot in ipairs(SLOTS) do
    local f = pieces[slot]
    if f:IsShown() then
      local p, rem
      if demo then
        -- prueba: se rellena en bucle cada 2,5 s
        local d = 2.5
        local e = (GetTime() + DEMO_OFFSET[slot]) % d
        p, rem = e / d, d - e
      else
        p, rem = ns.Progress(slot)
      end
      setProgress(f, p, rem)
      -- resultado del golpe: se queda un momento y se desvanece
      if not ns.db.showResult then
        f.result:Hide()
      elseif demo then
        setResult(f, DEMO_RESULT[slot])
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
        if ns.db.flash then flash(f) end
      end
    end
  end
end

local updateBroken
local function onUpdate(self, dt)
  if updateBroken then return end
  local ok, err = pcall(onUpdateImpl, self, dt)
  if not ok then
    updateBroken = true
    print("|cff33ccffAttacking|r: error al dibujar (" .. tostring(err)
      .. "). Lo paro hasta que recargues. Pásale este mensaje a quien te hizo el addon.")
  end
end

function ns.BuildDisplay()
  for _, slot in ipairs(SLOTS) do pieces[slot] = newPiece(slot) end
  built = true
  ns.built = true
  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", onUpdate)
  ns.UpdateTextures()
  ns.Refresh()
end
