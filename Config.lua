-- Attacking: página en Opciones > AddOns y comando /attacking
local ADDON, ns = ...

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
local function makeSlider(parent, label, minV, maxV, step, onChange)
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
  low:SetText(minV)
  local high = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  high:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, 2)
  high:SetText(maxV)
  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v / step + 0.5) * step
    self.text:SetText(label:format(v))
    onChange(v)
  end)
  -- poner un valor desde fuera (y su texto, aunque no cambie)
  function s:SetTo(v)
    self:SetValue(v)
    self.text:SetText(label:format(v))
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
  sub:SetWidth(580)
  sub:SetJustifyH("LEFT")
  sub:SetText("Cuánto falta para tu siguiente golpe. Mientras esta página está abierta se ve una vista "
    .. "previa. /attacking abre esta página y /attacking mover desbloquea las piezas para colocarlas.")

  -- Estilo
  local styleL = heading("Estilo:")
  styleL:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
  panel.styles = {}
  local STYLES = {
    { key = "icon", t = "Icono", tip = "El icono del arma se rellena de abajo arriba hasta el golpe." },
    { key = "clock", t = "Reloj", tip = "El icono del arma con una sombra que gira, como el tiempo de reutilización de una habilidad." },
    { key = "bar", t = "Barra", tip = "Una barra fina con un brillo que avanza. La más discreta." },
    { key = "pips", t = "Puntos", tip = "Cinco puntos que se van encendiendo según carga el golpe." },
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
  local reset = button(panel, "Volver a su sitio", 150, function() ns.ResetPosition() end)
  reset:SetPoint("LEFT", panel.lockB, "RIGHT", 8, 0)

  -- Cuadrícula del modo mover
  panel.grid = check(panel, "Cuadrícula al mover",
    "Al desbloquear para mover se ve una cuadrícula en pantalla (las líneas centrales en rojo) "
    .. "para colocar las piezas simétricas.", function(self)
      db.grid = self:GetChecked() and true or false
      ns.StyleMovers()
    end)
  panel.grid:SetPoint("TOPLEFT", panel.lockB, "BOTTOMLEFT", -4, -6)
  panel.snap = check(panel, "Imán",
    "Al soltar una pieza, su borde o su centro (lo que esté más cerca) se pega a la línea más "
    .. "cercana. Mantén Mayús al soltarla para dejarla exactamente donde está.", function(self)
      db.snap = self:GetChecked() and true or false
    end)
  panel.snap:SetPoint("LEFT", panel.grid, "LEFT", 170, 0)
  local gridS = makeSlider(panel, "Casillas: %d px", 8, 64, 8, function(v)
    if v ~= db.gridSize then
      db.gridSize = v
      ns.StyleMovers()
    end
  end)
  gridS:SetWidth(160)
  gridS:SetPoint("LEFT", panel.snap, "LEFT", 90, -2)
  panel.gridS = gridS

  -- Tamaño y opacidad
  local slider = makeSlider(panel, "Tamaño: %d", 24, 80, 2, function(v)
    if v ~= db.size then
      db.size = v
      ns.Refresh()
    end
  end)
  slider:SetPoint("TOPLEFT", panel.grid, "BOTTOMLEFT", 8, -28)
  panel.slider = slider
  local alphaS = makeSlider(panel, "Opacidad: %d %%", 20, 100, 5, function(v)
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

  local whenL = heading("Cuándo se ve:")
  whenL:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, y - 4)
  panel.when = {}
  local WHEN = {
    { key = "attack", t = "Mientras atacas", tip = "Solo mientras tienes el ataque automático puesto (o disparas)." },
    { key = "combat", t = "En combate", tip = "Desde que entras en combate hasta que sales, aunque no estés pegando." },
    { key = "always", t = "Siempre", tip = "También fuera de combate. Sin atacar se ve lleno: el golpe está listo." },
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

  panel.showText = check(panel, "Mostrar los segundos que faltan", nil, function(self)
    db.showText = self:GetChecked() and true or false
  end)
  place(panel.showText)
  panel.flash = check(panel, "Destello cuando el golpe está listo", nil, function(self)
    db.flash = self:GetChecked() and true or false
  end)
  place(panel.flash)
  panel.showOff = check(panel, "Mano izquierda (si llevas dos armas)",
    "Una segunda pieza, algo más pequeña y de color azul, para el arma de la mano izquierda.", function(self)
      db.showOff = self:GetChecked() and true or false
      changed()
    end)
  place(panel.showOff)
  panel.showRanged = check(panel, "Disparo automático y varitas",
    "Una pieza verde que aparece mientras disparas: Disparo automático del cazador o «Disparar» con varita.",
    function(self)
      db.showRanged = self:GetChecked() and true or false
      changed()
    end)
  place(panel.showRanged)
  panel.hideBlizzard = check(panel, "Ocultar la barra de golpe de Blizzard (en pruebas)",
    "Attacking lee el avance de la barra de golpe del juego (tiene que estar activada en los "
    .. "ajustes del juego). Con esta casilla la barra se vuelve invisible pero sigue funcionando. "
    .. "Si al activarla notas tirones o el sonido se entrecorta, desactívala y avísame.",
    function(self)
      db.hideBlizzard = self:GetChecked() and true or false
      ns.ApplyBlizzardAlpha()
    end)
  place(panel.hideBlizzard)

  -- Resultado del golpe
  panel.showResult = check(panel, "Mostrar el resultado del golpe (¡Fallo!, Esquivado, Parado…)",
    "Junto a la pieza sale un momento qué le ha pasado a tu objetivo: fallo, esquivado, parado, "
    .. "bloqueado, resistido… Si coincide con tu golpe sale en la pieza de esa mano. Los golpes "
    .. "normales no enseñan nada.", function(self)
      db.showResult = self:GetChecked() and true or false
      changed()
    end)
  place(panel.showResult)
  local function sub(c)
    c:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 20, y)
    y = y - 26
  end
  panel.resultCrit = check(panel, "También críticos y golpes rozados", nil, function(self)
    db.resultCrit = self:GetChecked() and true or false
  end)
  sub(panel.resultCrit)
  panel.resultGroup = check(panel, "En grupo, también los que no coinciden con un golpe tuyo",
    "Yendo en grupo, un fallo que no coincide con tu golpe (por ejemplo, de una habilidad) podría "
    .. "ser de otro jugador, así que no se enseña. Con esta casilla se enseña igualmente.", function(self)
      db.resultGroup = self:GetChecked() and true or false
    end)
  sub(panel.resultGroup)
  panel.posSide = check(panel, "Al lado", nil, function()
    db.resultPos = "side"
    changed()
  end)
  panel.posSide:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 20, y)
  panel.posTop = check(panel, "Encima", nil, function()
    db.resultPos = "top"
    changed()
  end)
  panel.posTop:SetPoint("LEFT", panel.posSide, "LEFT", 120, 0)
  y = y - 26

  -- Dibujo del icono (solo en los estilos Icono y Reloj)
  y = y - 8
  panel.iconL = heading("Dibujo del icono:")
  panel.iconL:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, y - 4)
  panel.styleWeapon = check(panel, "El arma que llevas", nil, function()
    db.iconStyle = "weapon"
    changed()
  end)
  panel.styleWeapon:SetPoint("LEFT", panel.iconL, "RIGHT", 10, 0)
  panel.styleSword = check(panel, "Una espada (y un arco)", nil, function()
    db.iconStyle = "sword"
    changed()
  end)
  panel.styleSword:SetPoint("LEFT", panel.iconL, "RIGHT", 170, 0)
end

function ns.RefreshOptions()
  if not built then return end
  local db = ns.db
  for _, c in ipairs(panel.styles) do c:SetChecked(c.key == db.style) end
  panel.lockB:SetText(db.locked and "Desbloquear para mover" or "Fijar las piezas")
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
  for _, c in ipairs({ panel.resultCrit, panel.resultGroup, panel.posSide, panel.posTop }) do
    c:SetEnabled(db.showResult)
    c.label:SetFontObject(db.showResult and "GameFontHighlight" or "GameFontDisable")
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
    print(P .. "vista previa " .. (ns.preview and "encendida" or "apagada") .. ".")
  elseif msg == "debug" then
    -- 5 segundos escribiendo en el chat lo que se lee de las barras de golpe del juego
    local n = 0
    local ticker
    ticker = C_Timer.NewTicker(0.25, function()
      n = n + 1
      for _, slot in ipairs({ "mh", "oh", "ranged" }) do
        local f = ns.BlizFrame(slot)
        if f then
          local bar = f.StatusBar
          local ok, lo, hi, v = pcall(function()
            local a, b = bar:GetMinMaxValues()
            return a, b, bar:GetValue()
          end)
          local p, rem = ns.Progress(slot)
          print(("%s%d %s visible=%s | min=%s max=%s valor=%s | carga=%.2f quedan=%.2f"):format(
            P, n, slot, tostring(f:IsShown()),
            ok and tostring(lo) or "ERR", ok and tostring(hi) or "ERR", ok and tostring(v) or tostring(lo),
            p or -1, rem or -1))
        end
      end
      if n >= 20 then ticker:Cancel() end
    end)
  else
    openOptions()
  end
end
