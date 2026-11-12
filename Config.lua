-- Attacking: página en Opciones > AddOns y comando /attacking
local ADDON, ns = ...

local panel = CreateFrame("Frame")
panel.name = "Attacking"
panel:Hide()

-- Vista previa del icono mientras haya alguna página de Attacking abierta
-- (se cuentan las abiertas para que al pasar de una a otra no parpadee)
local openPages = {}
local function setPageOpen(page, open)
  openPages[page] = open or nil
  if ns.SetPreview then ns.SetPreview(next(openPages) ~= nil) end
end

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
  sub:SetWidth(560)
  sub:SetJustifyH("LEFT")
  sub:SetText("Un icono que se va rellenando hasta tu siguiente golpe. Mientras esta página está abierta "
    .. "se ve una vista previa. /attacking abre esta página, /attacking mover lo desbloquea para "
    .. "colocarlo y /attacking prueba enciende la vista previa sin abrir los ajustes.")

  -- Colocar
  panel.lockB = button(panel, "", 200, function() ns.SetLocked(not db.locked) end)
  panel.lockB:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
  local reset = button(panel, "Volver a su sitio", 150, function() ns.ResetPosition() end)
  reset:SetPoint("LEFT", panel.lockB, "RIGHT", 8, 0)

  -- Tamaño
  local slider = makeSlider(panel, "Tamaño: %d", 24, 80, 2, function(v)
    if v ~= db.size then
      db.size = v
      ns.Refresh()
    end
  end)
  slider:SetPoint("TOPLEFT", panel.lockB, "BOTTOMLEFT", 4, -30)
  panel.slider = slider

  -- Opacidad (iconos y filas de buffos)
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
  local function place(c, indent)
    c:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4 + (indent or 0), y)
    y = y - 26
  end

  -- Cuándo se ve
  local whenL = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  whenL:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, y - 4)
  whenL:SetText("Cuándo se ve:")
  panel.when = {}
  local WHEN = {
    { key = "attack", t = "Mientras atacas", tip = "Solo mientras tienes el ataque automático puesto (o disparas)." },
    { key = "combat", t = "En combate", tip = "Desde que entras en combate hasta que sales, aunque no estés pegando." },
    { key = "always", t = "Siempre", tip = "También fuera de combate. Sin atacar, el icono se ve lleno: el golpe está listo." },
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
  panel.showText = check(panel, "Mostrar los segundos que faltan (debajo del icono)", nil, function(self)
    db.showText = self:GetChecked() and true or false
  end)
  place(panel.showText)
  panel.flash = check(panel, "Destello cuando el golpe está listo", nil, function(self)
    db.flash = self:GetChecked() and true or false
  end)
  place(panel.flash)
  panel.showOff = check(panel, "Icono de la mano izquierda (si llevas dos armas)",
    "Un segundo icono, algo más pequeño, para el arma de la mano izquierda.", function(self)
      db.showOff = self:GetChecked() and true or false
      changed()
    end)
  place(panel.showOff)
  panel.showRanged = check(panel, "Icono de Disparo automático y varitas",
    "Aparece mientras disparas: Disparo automático del cazador o «Disparar» con varita.", function(self)
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
    "Junto a cada icono sale un momento qué ha pasado con el golpe: fallo, esquivado, parado, "
    .. "bloqueado, resistido… Los golpes normales no enseñan nada.", function(self)
      db.showResult = self:GetChecked() and true or false
      changed()
    end)
  place(panel.showResult)
  panel.resultCrit = check(panel, "También críticos y golpes rozados", nil, function(self)
    db.resultCrit = self:GetChecked() and true or false
  end)
  place(panel.resultCrit, 24)
  panel.posSide = check(panel, "Al lado del icono", nil, function()
    db.resultPos = "side"
    changed()
  end)
  place(panel.posSide, 24)
  panel.posTop = check(panel, "Encima del icono", nil, function()
    db.resultPos = "top"
    changed()
  end)
  place(panel.posTop, 24)

  y = y - 10
  local iconL = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  iconL:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4, y)
  iconL:SetText("Icono")
  y = y - 18
  panel.styleWeapon = check(panel, "El arma que llevas equipada", nil, function()
    db.iconStyle = "weapon"
    changed()
  end)
  place(panel.styleWeapon)
  panel.styleSword = check(panel, "Una espada (y un arco para disparar)", nil, function()
    db.iconStyle = "sword"
    changed()
  end)
  place(panel.styleSword)
end

function ns.RefreshOptions()
  if not built then return end
  local db = ns.db
  panel.lockB:SetText(db.locked and "Desbloquear para mover" or "Fijar las piezas")
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
  panel.posSide:SetChecked(db.resultPos == "side")
  panel.posTop:SetChecked(db.resultPos == "top")
  for _, c in ipairs({ panel.resultCrit, panel.posSide, panel.posTop }) do
    c:SetEnabled(db.showResult)
    c.label:SetFontObject(db.showResult and "GameFontHighlight" or "GameFontDisable")
  end
  panel.styleWeapon:SetChecked(db.iconStyle == "weapon")
  panel.styleSword:SetChecked(db.iconStyle == "sword")
end

panel:SetScript("OnShow", function(self)
  setPageOpen(self, true) -- lo primero: la vista previa sale aunque algo de la página falle
  build()
  ns.RefreshOptions()
end)
panel:SetScript("OnHide", function(self) setPageOpen(self, false) end)
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

---------------------------------------------------------------------------
-- Página «Buffos y debuffos»
---------------------------------------------------------------------------
local auraPanel = CreateFrame("Frame")
auraPanel.name = "Buffos y debuffos"
auraPanel.parent = panel.name
auraPanel:Hide()

local MAX_ROWS = 12
local lists = {}

local function refreshList(col)
  local list = ns.char[col.kind] or {}
  for i, r in ipairs(col.rows) do
    local e = list[i]
    if e then
      r.entry = e
      r.text:SetText(e.name)
      if r.mine then r.mine:SetChecked(e.mine and true or false) end
      r:Show()
    else
      r.entry = nil
      r:Hide()
    end
  end
  col.empty:SetShown(#list == 0)
end

local function buildList(kind, title, x)
  local col = { kind = kind, rows = {} }
  local h = auraPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  h:SetPoint("TOPLEFT", x, -232)
  h:SetText(title)

  local input = CreateFrame("EditBox", nil, auraPanel, "InputBoxTemplate")
  input:SetSize(170, 20)
  input:SetPoint("TOPLEFT", x + 6, -250)
  input:SetAutoFocus(false)
  input:SetScript("OnEscapePressed", input.ClearFocus)
  local msg = auraPanel:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
  msg:SetPoint("TOPLEFT", x, -274)
  local function add()
    local name, err = ns.AddAura(kind, input:GetText())
    if name then
      input:SetText("")
      msg:SetText("")
    else
      msg:SetText(err)
    end
    refreshList(col)
  end
  input:SetScript("OnEnterPressed", add)
  local addB = button(auraPanel, "Añadir", 70, add)
  addB:SetPoint("LEFT", input, "RIGHT", 6, 0)
  addB:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Escribe el nombre del hechizo tal y como sale en el juego, o su número.", 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  addB:SetScript("OnLeave", function() GameTooltip:Hide() end)

  for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, auraPanel)
    r:SetSize(270, 22)
    r:SetPoint("TOPLEFT", x, -290 - (i - 1) * 22)
    r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", 4, 0)
    r.text:SetWidth(kind == "debuffs" and 150 or 220)
    r.text:SetJustifyH("LEFT")
    if kind == "debuffs" then
      r.mine = check(r, "solo míos",
        "Solo cuenta si lo has puesto tú (por ejemplo, tu Desgarrar y no el de otro guerrero).", function(self)
          if r.entry then
            r.entry.mine = self:GetChecked() and true or nil
            ns.UpdateAuras()
          end
        end)
      r.mine:SetPoint("LEFT", 156, 0)
      r.mine.label:SetFontObject("GameFontHighlightSmall")
    end
    local x2 = CreateFrame("Button", nil, r, "UIPanelCloseButton")
    x2:SetSize(22, 22)
    x2:SetPoint("RIGHT", 0, 0)
    x2:SetScript("OnClick", function()
      local list = ns.char[kind]
      for j, e in ipairs(list) do
        if e == r.entry then table.remove(list, j) break end
      end
      ns.UpdateAuras()
      refreshList(col)
    end)
    r:Hide()
    col.rows[i] = r
  end
  col.empty = auraPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  col.empty:SetPoint("TOPLEFT", x + 4, -296)
  col.empty:SetText("Lista vacía.")

  local reset = button(auraPanel, "Lista de mi clase", 140, function()
    ns.char[kind] = ns.ClassDefaults(kind)
    ns.UpdateAuras()
    refreshList(col)
  end)
  reset:SetPoint("TOPLEFT", x, -290 - MAX_ROWS * 22 - 6)
  lists[#lists + 1] = col
end

local auraBuilt
local function buildAuras()
  if auraBuilt then return end
  auraBuilt = true
  local db = ns.db

  local title = auraPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Attacking: buffos y debuffos")
  local sub = auraPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetWidth(580)
  sub:SetJustifyH("LEFT")
  sub:SetText("Debajo del icono del golpe, una fila con tus buffos y otra (borde rojo) con los debuffos de tu "
    .. "objetivo. Solo salen los de las listas y solo mientras están puestos; cada icono se vacía según se "
    .. "acaba. Las listas son de este personaje.")

  auraPanel.buffs = check(auraPanel, "Seguir mis buffos", nil, function(self)
    db.auraBuffs = self:GetChecked() and true or false
    ns.UpdateAuras()
  end)
  auraPanel.buffs:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -4, -12)
  auraPanel.debuffs = check(auraPanel, "Seguir los debuffos del objetivo", nil, function(self)
    db.auraDebuffs = self:GetChecked() and true or false
    ns.UpdateAuras()
  end)
  auraPanel.debuffs:SetPoint("LEFT", auraPanel.buffs, "LEFT", 300, 0)

  local whenL = auraPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  whenL:SetPoint("TOPLEFT", auraPanel.buffs, "BOTTOMLEFT", 4, -12)
  whenL:SetText("Cuándo se ven:")
  auraPanel.when = {}
  local WHEN = {
    { key = "attack", t = "Mientras atacas" },
    { key = "combat", t = "En combate" },
    { key = "always", t = "Siempre" },
  }
  for i, w in ipairs(WHEN) do
    local c = check(auraPanel, w.t, nil, function()
      db.auraWhen = w.key
      ns.UpdateAuras()
      ns.RefreshAuraOptions()
    end)
    c:SetPoint("LEFT", whenL, "RIGHT", 10 + (i - 1) * 150, 0)
    c.key = w.key
    auraPanel.when[i] = c
  end

  local slider = makeSlider(auraPanel, "Tamaño de los iconos: %d", 16, 48, 2, function(v)
    if v ~= db.auraSize then
      db.auraSize = v
      ns.UpdateAuras()
    end
  end)
  slider:SetPoint("TOPLEFT", whenL, "BOTTOMLEFT", 4, -26)
  auraPanel.slider = slider

  buildList("buffs", "Mis buffos", 16)
  buildList("debuffs", "En el objetivo", 320)
end

function ns.RefreshAuraOptions()
  if not auraBuilt then return end
  local db = ns.db
  auraPanel.buffs:SetChecked(db.auraBuffs)
  auraPanel.debuffs:SetChecked(db.auraDebuffs)
  for _, c in ipairs(auraPanel.when) do c:SetChecked(c.key == db.auraWhen) end
  auraPanel.slider:SetTo(db.auraSize)
  for _, col in ipairs(lists) do refreshList(col) end
end

auraPanel:SetScript("OnShow", function(self)
  setPageOpen(self, true)
  buildAuras()
  ns.RefreshAuraOptions()
end)
auraPanel:SetScript("OnHide", function(self) setPageOpen(self, false) end)
auraPanel.OnCommit = function() end
auraPanel.OnDefault = function() end
auraPanel.OnRefresh = function() end

if Settings and Settings.RegisterCanvasLayoutSubcategory and category then
  Settings.RegisterCanvasLayoutSubcategory(category, auraPanel, auraPanel.name)
elseif InterfaceOptions_AddCategory then
  InterfaceOptions_AddCategory(auraPanel)
end

local function openOptions()
  if Settings and Settings.OpenToCategory and category then
    Settings.OpenToCategory(category:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel) -- la primera vez a veces no llega a la página
  end
end

SLASH_ATTACKING1 = "/attacking"
SlashCmdList.ATTACKING = function(msg)
  msg = strtrim((msg or ""):lower())
  if msg == "mover" or msg == "move" then
    ns.SetLocked(not ns.db.locked)
  elseif msg == "reset" then
    ns.ResetPosition()
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
          -- otra forma de medir el avance: cuánto ocupa el relleno dibujado frente a la barra entera
          local okW, fillW, barW = pcall(function()
            local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
            return tex and tex:GetWidth(), bar:GetWidth()
          end)
          local p, rem = ns.Progress(slot)
          print(("|cff33ccffAttacking|r %d %s visible=%s tipo=%s | min=%s max=%s valor=%s | relleno=%s/%s | icono=%.2f quedan=%.2f"):format(
            n, slot, tostring(f:IsShown()), bar and bar.GetObjectType and bar:GetObjectType() or "sin barra",
            ok and tostring(lo) or "ERR", ok and tostring(hi) or "ERR", ok and tostring(v) or tostring(lo),
            okW and tostring(fillW) or "ERR", okW and tostring(barW) or "ERR",
            p or -1, rem or -1))
        end
      end
      if n >= 20 then ticker:Cancel() end
    end)
  elseif msg == "prueba" or msg == "test" then
    -- enciende/apaga la vista previa sin abrir los ajustes (para comprobar que el icono se ve)
    ns.SetPreview(not ns.preview)
    print("|cff33ccffAttacking|r: vista previa " .. (ns.preview and "encendida" or "apagada") .. ".")
  else
    openOptions()
  end
end
