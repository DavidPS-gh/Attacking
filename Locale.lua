-- Attacking - idiomas
-- Los textos se escriben en español en el código y se pasan por L("…"). Cada archivo
-- Locales\xxXX.lua rellena ns.T.xxXX con [texto en español] = traducción. Lo que falte
-- en una traducción sale en español.
local ADDON, ns = ...

ns.T = {}

-- Idiomas que se pueden elegir en los ajustes (cada uno con su propio nombre)
ns.LANGS = {
  { code = "esES", label = "Español" },
  { code = "enUS", label = "English" },
  { code = "frFR", label = "Français" },
  { code = "deDE", label = "Deutsch" },
  { code = "ptBR", label = "Português" },
  { code = "itIT", label = "Italiano" },
  { code = "ruRU", label = "Русский" },
}

local ALIAS = { esMX = "esES", enGB = "enUS", ptPT = "ptBR" }

-- Idioma del juego, convertido a uno de los del addon (inglés si no hay traducción)
function ns.GameLang()
  local g = GetLocale and GetLocale() or "enUS"
  g = ALIAS[g] or g
  if g == "esES" or ns.T[g] then return g end
  return "enUS"
end

local current -- se fija al cargar los datos guardados (ADDON_LOADED)

local function pick()
  local choice = AttackingDB and AttackingDB.lang
  if choice == "esES" or (choice and ns.T[choice]) then return choice end
  return ns.GameLang()
end

function ns.Lang()
  return current or pick()
end

-- L("texto") o L("texto con %s", valor)
function ns.L(s, ...)
  local lang = current or pick()
  local t = lang ~= "esES" and ns.T[lang]
  local r = (t and t[s]) or s
  if select("#", ...) > 0 then return r:format(...) end
  return r
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, _, name)
  if name ~= ADDON then return end
  current = pick()
  self:UnregisterEvent("ADDON_LOADED")
end)
