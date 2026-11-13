-- Attacking: página en Opciones > AddOns y comando /attacking
local ADDON, ns = ...
local L = function(...) return ns.L(...) end

local panel = CreateFrame("Frame")
panel.name = "Attacking"
panel:Hide()

local P = "|cff33ccffAttacking|r: "

-- Vista previa mientras la página está abierta
local function setPageOpen(open)
  if ns.SetPreview then ns.SetPreview(open) end
end

---------------------------------------------------------------------------
-- Piezas de la página
---------------------------------------------------------------------------
local function check(parent, text, tip, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c.label = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  c.label:SetPoint("LEFT", c, "RIGHT", 2, 1)
  c.label:SetText(text)
  c:SetScript("OnClick", onClick)
  if tip then
    c:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return c
end

local function button(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 24)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function heading(text)
  local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  h:SetText(text)
  return h
end

-- Barra deslizante propia (no depende de OptionsSliderTemplate, que algunos clientes ya no traen)
-- label: texto con %d para el valor
-- div: el valor se enseña dividido entre esto (p. ej. 10 para décimas de segundo)
local function makeSlider(parent, label, minV, maxV, step, onChange, div)
  local function shown(v) return div and v / div or v end
  local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
  s:SetOrientation("HORIZONTAL")
  s:SetSize(220, 17)
  s:SetHitRectInsets(0, 0, -10, -10)
  s:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
  })
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s.text = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  s.text:SetPoint("BOTTOM", s, "TOP", 0, 2)
  local low = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  low:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 2, 2)
  low:SetText(shown(minV))
  local high = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  high:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, 2)
  high:SetText(shown(maxV))
  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v / step + 0.5) * step
    self.text:SetText(label:format(shown(v)))
    onChange(v)
  end)
  -- poner un valor desde fuera (y su texto, aunque no cambie)
  function s:SetTo(v)
    self:SetValue(v)
    self.text:SetText(label:format(shown(v)))
  end
  return s
end

local function changed()
  ns.UpdateTextures()
  ns.Refresh()
  ns.RefreshOptions()
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------
local built
local function build()
  if built then return end
  built = true
  local db = ns.db

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Attacking")
  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetWidth(400)
  sub:SetJustifyH("LEFT")
  sub:SetText(L("Cuánto falta para tu siguiente golpe. Mientras esta página está abierta se ve una vista "
    .. "previa. /attacking abre esta página y /attacking mover desbloquea las piezas para colocarlas."))

  -- Estilo
  local styleL = heading(L("Estilo:"))
  styleL:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
  panel.styles = {}
  local STYLES = {
    { key = "icon", t = L("Icono"), tip = L("El icono del arma se rellena de abajo arriba hasta el golpe.") },
    { key = "clock", t = L("Reloj"), tip = L("El icono del arma con una sombra que gira, como el tiempo de reutilización de una habilidad.") },
    { key = "bar", t = L("Barra"), tip = L("Una barra fina con un brillo que avanza. La más discreta.") },
    { key = "pips", t = L("Puntos"), tip = L("Cinco puntos que se van encendiendo según carga el golpe.") },
  }
  for i, st in ipairs(STYLES) do
    local c = check(panel, st.t, st.tip, function()
      db.style = st.key
      changed()
    end)
    c:SetPoint("LEFT", styleL, "RIGHT", 10 + (i - 1) * 100, 0)
    c.key = st.key
    panel.styles[i] = c
  end

  -- Colocar
  panel.lockB = button(panel, "", 200, function() ns.SetLocked(not db.locked) end)
  panel.lockB:SetPoint("TOPLEFT", styleL, "BOTTOMLEFT", 0, -16)
  local reset = button(panel, L("Volver a su sitio"), 150, function() ns.ResetPosition() end)
  reset:SetPoint("LEFT", panel.lockB, "RIGHT", 8, 0)

  -- Cuadrícula del modo mover
  panel.grid = check(panel, L("Cuadrícula al mover"),
    L("Al desbloquear para mover se ve una cuadrícula en pantalla (las líneas centrales en rojo) "
    .. "para colocar las piezas simétricas."), function(self)
      db.grid = self:GetChecked() and true or false
      ns.StyleMovers()
    end)
  panel.grid:SetPoint("TOPLEFT", panel.lockB, "BOTTOMLEFT", -4, -6)
  panel.snap = check(panel, L("Imán"),
    L("Al soltar una pieza, su borde o su centro (lo que esté más cerca) se pega a la línea más "
    .. "cercana. Mantén Mayús al soltarla para dejarla exactamente donde está."), function(self)
      db.snap = self:GetChecked() and true or false
    end)
  panel.snap:SetPoint("LEFT", panel.grid, "LEFT", 170, 0)
  local gridS = makeSlider(panel, L("Casillas: %d px"), 8, 64, 8, function(v)
    if v ~= db.gridSize then
      db.gridSize = v
      ns.StyleMovers()
    end
  end)
  gridS:SetWidth(160)
  gridS:SetPoint("LEFT", panel.snap, "LEFT", 90, -2)
  panel.gridS = gridS

  -- Tamaño y opacidad
  local slider = makeSlider(panel, L("Tamaño: %d"), 24, 80, 2, function(v)
    if v ~= db.size then
      db.size = v
      ns.Refresh()
    end
  end)
  slider:SetPoint("TOPLEFT", panel.grid, "BOTTOMLEFT", 8, -28)
  panel.slider = slider
  local alphaS = makeSlider(panel, L("Opacidad: %d %%"), 20, 100, 5, function(v)
    if v / 100 ~= db.alpha then
      db.alpha = v / 100
      ns.StyleMovers()
    end
  end)
  alphaS:SetPoint("LEFT", slider, "RIGHT", 40, 0)
  panel.alphaS = alphaS

  -- Opciones
  local y = -34
  local function place(c)
    c:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4, y)
    y = y - 26
  end

  local whenL = heading(L("Cuándo se ve:"))
  whenL:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, y - 4)
  panel.when = {}
  local WHEN = {
    { key = "attack", t = L("Mientras atacas"), tip = L("Solo mientras tienes el ataque automático puesto (o disparas).") },
    { key = "combat", t = L("En combate"), tip = L("Desde que entras en combate hasta que sales, aunque no estés pegando.") },
    { key = "always", t = L("Siempre"), tip = L("También fuera de combate. Sin atacar se ve lleno: el golpe está listo.") },
  }
  for i, w in ipairs(WHEN) do
    local c = check(panel, w.t, w.tip, function()
      db.iconWhen = w.key
      changed()
    end)
    c:SetPoint("LEFT", whenL, "RIGHT", 10 + (i - 1) * 140, 0)
    c.key = w.key
    panel.when[i] = c
  end
  y = y - 32

  panel.showText = check(panel, L("Mostrar los segundos que faltan"), nil, function(self)
    db.showText = self:GetChecked() and true or false
  end)
  place(panel.showText)
  panel.flash = check(panel, L("Destello cuando el golpe está listo"), nil, function(self)
    db.flash = self:GetChecked() and true or false
  end)
  place(panel.flash)
  panel.showOff = check(panel, L("Mano izquierda (si llevas dos armas)"),
    L("Una segunda pieza, algo más pequeña y de color azul, para el arma de la mano izquierda."), function(self)
      db.showOff = self:GetChecked() and true or false
      changed()
    end)
  place(panel.showOff)
  panel.showRanged = check(panel, L("Disparo automático y varitas"),
    L("Una pieza verde que aparece mientras disparas: Disparo automático del cazador o «Disparar» con varita."),
    function(self)
      db.showRanged = self:GetChecked() and true or false
      changed()
    end)
  place(panel.showRanged)
  panel.hideBlizzard = check(panel, L("Ocultar la barra de golpe de Blizzard (en pruebas)"),
    L("Attacking lee el avance de la barra de golpe del juego (tiene que estar activada en los "
    .. "ajustes del juego). Con esta casilla la barra se vuelve invisible pero sigue funcionando. "
    .. "Si al activarla notas tirones o el sonido se entrecorta, desactívala y avísame."),
    function(self)
      db.hideBlizzard = self:GetChecked() and true or false
      ns.ApplyBlizzardAlpha()
    end)
  place(panel.hideBlizzard)

  -- Resultado del golpe
  panel.showResult = check(panel, L("Mostrar el resultado del golpe (¡Fallo!, Esquivado, Parado…)"),
    L("Junto a la pieza sale un momento qué le ha pasado a tu objetivo: fallo, esquivado, parado, "
    .. "bloqueado, resistido… Si coincide con tu golpe sale en la pieza de esa mano. Los golpes "
    .. "normales no enseñan nada."), function(self)
      db.showResult = self:GetChecked() and true or false
      changed()
    end)
  place(panel.showResult)
  local function sub(c)
    c:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 20, y)
    y = y - 26
  end
  panel.resultCrit = check(panel, L("También críticos y golpes rozados"), nil, function(self)
    db.resultCrit = self:GetChecked() and true or false
  end)
  sub(panel.resultCrit)
  panel.resultGroup = check(panel, L("En grupo, también los que no coinciden con un golpe tuyo"),
    L("Yendo en grupo, un fallo que no coincide con tu golpe (por ejemplo, de una habilidad) podría "
    .. "ser de otro jugador, así que no se enseña. Con esta casilla se enseña igualmente."), function(self)
      db.resultGroup = self:GetChecked() and true or false
    end)
  sub(panel.resultGroup)
  panel.posSide = check(panel, L("Al lado"), nil, function()
    db.resultPos = "side"
    changed()
  end)
  panel.posSide:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 20, y)
  panel.posTop = check(panel, L("Encima"), nil, function()
    db.resultPos = "top"
    changed()
  end)
  panel.posTop:SetPoint("LEFT", panel.posSide, "LEFT", 120, 0)
  y = y - 26

  -- Contraste del texto de resultado
  panel.outlineL = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  panel.outlineL:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 24, y - 5)
  panel.outlineL:SetText(L("Contraste:"))
  panel.outlines = {}
  local OUTLINES = {
    { key = "shadow", t = L("Sombra") },
    { key = "outline", t = L("Contorno") },
    { key = "thick", t = L("Contorno grueso") },
  }
  for i, o in ipairs(OUTLINES) do
    local c = check(panel, o.t, nil, function()
      db.resultOutline = o.key
      changed()
    end)
    c:SetPoint("LEFT", panel.outlineL, "RIGHT", 8 + (i - 1) * 110, 0)
    c.key = o.key
    panel.outlines[i] = c
  end
  y = y - 48

  -- Tamaño, opacidad y duración del texto de resultado
  panel.resSizeS = makeSlider(panel, L("Tamaño del texto: %d"), 8, 28, 1, function(v)
    if v ~= db.resultSize then
      db.resultSize = v
      ns.Refresh()
    end
  end)
  panel.resSizeS:SetWidth(150)
  panel.resSizeS:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 24, y + 10)
  panel.resAlphaS = makeSlider(panel, L("Opacidad del texto: %d %%"), 30, 100, 5, function(v)
    db.resultAlpha = v / 100
  end)
  panel.resAlphaS:SetWidth(150)
  panel.resAlphaS:SetPoint("LEFT", panel.resSizeS, "RIGHT", 30, 0)
  panel.resTimeS = makeSlider(panel, L("Duración: %.1f s"), 5, 30, 1, function(v)
    db.resultTime = v / 10
  end, 10)
  panel.resTimeS:SetWidth(150)
  panel.resTimeS:SetPoint("LEFT", panel.resAlphaS, "RIGHT", 30, 0)
  y = y - 22

  -- Dibujo del icono (solo en los estilos Icono y Reloj)
  y = y - 8
  panel.iconL = heading(L("Dibujo del icono:"))
  panel.iconL:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, y - 4)
  panel.styleWeapon = check(panel, L("El arma que llevas"), nil, function()
    db.iconStyle = "weapon"
    changed()
  end)
  panel.styleWeapon:SetPoint("LEFT", panel.iconL, "RIGHT", 10, 0)
  panel.styleSword = check(panel, L("Una espada (y un arco)"), nil, function()
    db.iconStyle = "sword"
    changed()
  end)
  panel.styleSword:SetPoint("LEFT", panel.iconL, "RIGHT", 170, 0)

  -- Idioma (arriba a la derecha): cada clic pasa al siguiente; se ve al recargar
  panel.langB = button(panel, "", 190, function()
    local order = { false }
    for _, l in ipairs(ns.LANGS) do order[#order + 1] = l.code end
    local cur = db.lang or false
    local nextCode = false
    for i, c in ipairs(order) do
      if c == cur then nextCode = order[i % #order + 1] break end
    end
    db.lang = nextCode or nil
    ns.RefreshOptions()
  end)
  panel.langB:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -12)
  panel.reloadB = button(panel, L("Recargar ahora"), 190, function() ReloadUI() end)
  panel.reloadB:SetPoint("TOPRIGHT", panel.langB, "BOTTOMRIGHT", 0, -4)
end

local function langLabel(code)
  if not code then return L("Automático") end
  for _, l in ipairs(ns.LANGS) do
    if l.code == code then return l.label end
  end
  return code
end

function ns.RefreshOptions()
  if not built then return end
  local db = ns.db
  for _, c in ipairs(panel.styles) do c:SetChecked(c.key == db.style) end
  panel.lockB:SetText(db.locked and L("Desbloquear para mover") or L("Fijar las piezas"))
  panel.grid:SetChecked(db.grid)
  panel.snap:SetChecked(db.snap)
  panel.gridS:SetTo(db.gridSize or 32)
  panel.slider:SetTo(db.size)
  panel.alphaS:SetTo(math.floor((db.alpha or 1) * 100 + 0.5))
  for _, c in ipairs(panel.when) do c:SetChecked(c.key == db.iconWhen) end
  panel.showText:SetChecked(db.showText)
  panel.flash:SetChecked(db.flash)
  panel.showOff:SetChecked(db.showOff)
  panel.showRanged:SetChecked(db.showRanged)
  panel.hideBlizzard:SetChecked(db.hideBlizzard)
  panel.showResult:SetChecked(db.showResult)
  panel.resultCrit:SetChecked(db.resultCrit)
  panel.resultGroup:SetChecked(db.resultGroup)
  panel.posSide:SetChecked(db.resultPos == "side")
  panel.posTop:SetChecked(db.resultPos == "top")
  for _, c in ipairs(panel.outlines) do c:SetChecked(c.key == (db.resultOutline or "outline")) end
  panel.resSizeS:SetTo(db.resultSize or 14)
  panel.resAlphaS:SetTo(math.floor((db.resultAlpha or 1) * 100 + 0.5))
  panel.resTimeS:SetTo(math.floor((db.resultTime or 1.3) * 10 + 0.5))
  local resultChecks = { panel.resultCrit, panel.resultGroup, panel.posSide, panel.posTop }
  for _, c in ipairs(panel.outlines) do resultChecks[#resultChecks + 1] = c end
  for _, c in ipairs(resultChecks) do
    c:SetEnabled(db.showResult)
    c.label:SetFontObject(db.showResult and "GameFontHighlight" or "GameFontDisable")
  end
  panel.outlineL:SetFontObject(db.showResult and "GameFontHighlight" or "GameFontDisable")
  for _, s in ipairs({ panel.resSizeS, panel.resAlphaS, panel.resTimeS }) do
    s:SetEnabled(db.showResult)
    s:SetAlpha(db.showResult and 1 or 0.5)
  end
  panel.styleWeapon:SetChecked(db.iconStyle == "weapon")
  panel.styleSword:SetChecked(db.iconStyle == "sword")
  -- el dibujo del icono solo importa en los estilos con icono
  local iconish = db.style == "icon" or db.style == "clock"
  panel.iconL:SetFontObject(iconish and "GameFontNormal" or "GameFontDisable")
  for _, c in ipairs({ panel.styleWeapon, panel.styleSword }) do
    c:SetEnabled(iconish)
    c.label:SetFontObject(iconish and "GameFontHighlight" or "GameFontDisable")
  end
  panel.langB:SetText(L("Idioma: %s", langLabel(db.lang)))
  panel.reloadB:SetShown((db.lang or ns.GameLang()) ~= ns.Lang())
end

panel:SetScript("OnShow", function()
  setPageOpen(true) -- lo primero: la vista previa sale aunque algo de la página falle
  build()
  ns.RefreshOptions()
end)
panel:SetScript("OnHide", function() setPageOpen(false) end)
panel.OnCommit = function() end
panel.OnDefault = function() end
panel.OnRefresh = function() end

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
  category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
  InterfaceOptions_AddCategory(panel)
end

local function openOptions()
  if Settings and Settings.OpenToCategory and category then
    Settings.OpenToCategory(category:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel) -- la primera vez a veces no llega a la página
  end
end

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
SLASH_ATTACKING1 = "/attacking"
SlashCmdList.ATTACKING = function(msg)
  msg = strtrim((msg or ""):lower())
  if msg == "mover" or msg == "move" then
    ns.SetLocked(not ns.db.locked)
  elseif msg == "reset" then
    ns.ResetPosition()
  elseif msg == "prueba" or msg == "test" then
    -- enciende/apaga la vista previa sin abrir los ajustes
    ns.SetPreview(not ns.preview)
    print(P .. (ns.preview and L("vista previa encendida.") or L("vista previa apagada.")))
  elseif msg == "barra" then
    -- De qué está hecha la barra de golpe de la mano derecha (para diagnosticar). Se escribe dos
    -- veces con medio segundo de diferencia: lo que cambie entre una y otra es lo que se mueve.
    local function dump(tag)
      local f = ns.BlizFrame("mh")
      if not f then print(P .. "no existe SwingTimerMainHandFrame") return end
      print(("%s[%s] marco %s visible=%s StatusBar=%s"):format(P, tag, tostring(f), tostring(f:IsVisible()),
        tostring(f.StatusBar)))
      local function info(o, depth)
        local ok, s = pcall(function()
          local t = o:GetObjectType()
          local r = ("%s%s %s %s vis=%s"):format(("  "):rep(depth), t, tostring(o:GetName() or ""),
            tostring(o), tostring(o:IsVisible()))
          if t == "StatusBar" then
            local lo, hi = o:GetMinMaxValues()
            r = r .. (" valor=%s (%s-%s)"):format(tostring(o:GetValue()), tostring(lo), tostring(hi))
          elseif t == "Texture" then
            r = r .. (" ancho=%.1f alto=%.1f"):format(o:GetWidth() or -1, o:GetHeight() or -1)
          elseif t == "FontString" then
            r = r .. " texto=" .. tostring(o:GetText())
          end
          return r
        end)
        print(ok and s or ("  error: " .. tostring(s)))
      end
      local function walk(o, depth)
        if depth > 2 then return end
        for _, r in ipairs({ o:GetRegions() }) do info(r, depth) end
        for _, c in ipairs({ o:GetChildren() }) do
          info(c, depth)
          walk(c, depth + 1)
        end
      end
      walk(f, 1)
    end
    dump("1")
    C_Timer.After(0.5, function() dump("2") end)
  elseif msg == "debug" then
    -- 5 segundos escribiendo en el chat lo que se lee de las barras de golpe del juego
    local n = 0
    local ticker
    ticker = C_Timer.NewTicker(0.25, function()
      n = n + 1
      print(("%s%d atacando: aviso=%s total=%s | disparando=%s | en combate=%s | sin leer hace=%s"):format(
        P, n, tostring(ns.attacking), tostring(ns.IsAttacking()), tostring(ns.shooting), tostring(ns.inCombat), ns.blizErrAt and ("%.1fs"):format(GetTime() - ns.blizErrAt) or "nunca"))
      for _, slot in ipairs({ "mh", "oh", "ranged" }) do
        local f = ns.BlizFrame(slot)
        if f then
          local bar = f.StatusBar
          local ok, lo, hi, v = pcall(function()
            local a, b = bar:GetMinMaxValues()
            return a, b, bar:GetValue()
          end)
          local p, rem = ns.Progress(slot)
          print(("%s%d %s visible=%s | min=%s max=%s valor=%s | carga=%.2f quedan=%.2f quieta=%.1fs"):format(
            P, n, slot, tostring(f:IsShown()),
            ok and tostring(lo) or "ERR", ok and tostring(hi) or "ERR", ok and tostring(v) or tostring(lo),
            p or -1, rem or -1, ns.StillFor(slot)))
        end
      end
      if n >= 20 then ticker:Cancel() end
    end)
  else
    openOptions()
  end
end
