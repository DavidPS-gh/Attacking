-- Attacking: página en Opciones > AddOns y comando /attacking
local ADDON, ns = ...

local panel = CreateFrame("Frame")
panel.name = "Attacking"
panel:Hide()

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
  sub:SetText("Un icono que se va rellenando hasta tu siguiente golpe. Solo aparece mientras atacas. "
    .. "/attacking abre esta página y /attacking mover lo desbloquea para colocarlo.")

  -- Colocar
  panel.lockB = button(panel, "", 200, function() ns.SetLocked(not db.locked) end)
  panel.lockB:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
  local reset = button(panel, "Volver a su sitio", 150, function() ns.ResetPosition() end)
  reset:SetPoint("LEFT", panel.lockB, "RIGHT", 8, 0)

  -- Tamaño
  local slider = CreateFrame("Slider", "AttackingSizeSlider", panel, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", panel.lockB, "BOTTOMLEFT", 4, -30)
  slider:SetWidth(220)
  slider:SetMinMaxValues(24, 80)
  slider:SetValueStep(2)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  local low = slider.Low or _G["AttackingSizeSliderLow"]
  local high = slider.High or _G["AttackingSizeSliderHigh"]
  local stext = slider.Text or _G["AttackingSizeSliderText"]
  if low then low:SetText("24") end
  if high then high:SetText("80") end
  slider:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v / 2 + 0.5) * 2
    if stext then stext:SetText("Tamaño: " .. v) end
    if v ~= db.size then
      db.size = v
      ns.Refresh()
    end
  end)
  panel.slider = slider

  -- Opciones
  local y = -34
  local function place(c, indent)
    c:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4 + (indent or 0), y)
    y = y - 26
  end
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
  panel.lockB:SetText(db.locked and "Desbloquear para mover" or "Fijar en su sitio")
  panel.slider:SetValue(db.size)
  panel.showText:SetChecked(db.showText)
  panel.flash:SetChecked(db.flash)
  panel.showOff:SetChecked(db.showOff)
  panel.showRanged:SetChecked(db.showRanged)
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

panel:SetScript("OnShow", function()
  build()
  ns.RefreshOptions()
end)
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

  local slider = CreateFrame("Slider", "AttackingAuraSizeSlider", auraPanel, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", whenL, "BOTTOMLEFT", 4, -26)
  slider:SetWidth(220)
  slider:SetMinMaxValues(16, 48)
  slider:SetValueStep(2)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  local low = slider.Low or _G["AttackingAuraSizeSliderLow"]
  local high = slider.High or _G["AttackingAuraSizeSliderHigh"]
  local stext = slider.Text or _G["AttackingAuraSizeSliderText"]
  if low then low:SetText("16") end
  if high then high:SetText("48") end
  slider:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / 2 + 0.5) * 2
    if stext then stext:SetText("Tamaño de los iconos: " .. v) end
    if v ~= db.auraSize then
      db.auraSize = v
      ns.UpdateAuras()
    end
  end)
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
  auraPanel.slider:SetValue(db.auraSize)
  for _, col in ipairs(lists) do refreshList(col) end
end

auraPanel:SetScript("OnShow", function()
  buildAuras()
  ns.RefreshAuraOptions()
end)
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
  else
    openOptions()
  end
end
