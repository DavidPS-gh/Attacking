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
