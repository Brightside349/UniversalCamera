-- ============================================================
-- Universal Camera Pro v6 · 90_init
-- Paso final: llama a UCam.buildUI() y notifica que arranco.
-- Si buildUI no existe (porque el orquestador 80_ui.lua fallo),
-- avisa y termina la carga.
-- ============================================================
local UCam = _G.UCam

if type(UCam.buildUI) ~= "function" then
    warn("[UCam] buildUI() no registrado. 80_ui.lua probablemente no se cargo.")
    return
end

local ok, err = pcall(function()
    UCam.buildUI()
end)

if ok then
    UCam.notify(
        "Universal Camera Pro v6 By Cocoa Feliz",
        "v6 modular: UI reorganizada en 12 pestañas, modo Vertigo, Camara Lenta con tab propio, Reset FOV, Auto-HUD y nuevos efectos en Diversion. Delete para alternar UI."
    )
    print("[UCam] Universal Camera Pro v6 cargado OK.")
else
    warn("[UCam] Error al construir la UI: " .. tostring(err))
end
