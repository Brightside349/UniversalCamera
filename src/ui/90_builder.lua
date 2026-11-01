-- ============================================================
-- Universal Camera Pro v13 · UI builder
-- Construye la ventana, tabs estáticos/dinámicos y autosave.
--
-- v13.2: las pestañas ya no se rellenan todas al arrancar. Cada builder se
-- ejecuta primero contra una pestaña inerte para conocer su título e icono:
-- con eso se crean las 16 pestañas vacías (baratas) y el contenido real se
-- construye la primera vez que el usuario abre esa pestaña. Antes se creaban
-- 527 controles de golpe, que era el tirón de varios segundos al iniciar y la
-- causa de los bajones de FPS al abrir la ventana.
--
-- Dependencias: core/00_config.lua, core/05_persistence.lua,
--               ui/00_registry.lua y todos los ui/tabs/*.lua.
-- ============================================================
local UCam = _G.UCam

function UCam.buildUI()
    local startedAt = os.clock()

    -- v13: la ventana, el tema y el fondo los arma ui/05_adapter.lua.
    local Window = UCam.UI and UCam.UI.createWindow and UCam.UI.createWindow()
    if not Window then
        warn("[UCam] UI no disponible: se cargan los modulos sin panel.")
        return
    end
    UCam._window = Window

    local UI = UCam.UI

    -- Refleja tema/fondo guardados en cuanto existe la ventana.
    if UCam.applyUISettings then
        pcall(UCam.applyUISettings)
    end

    -- ========================================================
    -- FASE 1 · cascarones
    -- ========================================================
    local meta, order = {}, {}

    for _, name in ipairs(UCam._uiBuilders) do
        local fn = UCam["build_" .. name]
        if type(fn) == "function" then
            local captured
            local recorder = {
                CreateTab = function(_, title, icon)
                    captured = { title, icon }
                    return UI.noopTab()
                end,
            }

            local ok, err = pcall(fn, recorder)

            if captured then
                meta[name] = captured
                table.insert(order, name)
                local shell = UI.makeTab(Window, captured[1], captured[2])
                if not shell then
                    warn(("[UCam] No se pudo crear la pestaña '%s'."):format(tostring(captured[1])))
                end
            else
                warn(("[UCam] Sub-builder '%s' no registrado. Carga ui/tabs/%s.lua antes de ui/90_builder.lua."):format(name, name))
            end

            if not ok then
                warn(("[UCam] Sub-builder '%s' falló al simularse: %s"):format(name, tostring(err)))
            end
        else
            warn(("[UCam] Sub-builder '%s' no registrado. Carga ui/tabs/%s.lua antes de ui/90_builder.lua."):format(name, name))
        end
    end

    -- ========================================================
    -- FASE 2 · contenido bajo demanda
    -- ========================================================
    local built = {}

    local function buildTab(name)
        if built[name] or not meta[name] then
            return false
        end
        built[name] = true

        -- El builder pide su pestaña otra vez: se le devuelve la ya creada.
        local proxy = {
            CreateTab = function(_, title)
                return UI.tabsByTitle[UI.cleanTitle(title)]
            end,
        }

        local ok, err = pcall(UCam["build_" .. name], proxy)
        if not ok then
            warn(("[UCam] Sub-builder '%s' falló: %s"):format(name, tostring(err)))
        end
        return true
    end

    -- La pestaña que se ve al abrir se construye ya, para que no haya hueco.
    local first = order[1]
    if first then
        buildTab(first)
    end

    if #order > 1 then
        -- WindUI avisa del cambio con el ÍNDICE de la pestaña (no con el
        -- título). Se resuelve por indice y, por si una version futura cambia
        -- la convencion, tambien por titulo.
        local byIndex, byTitle = {}, {}
        for index, name in ipairs(order) do
            byIndex[index] = name
            byTitle[UI.cleanTitle(meta[name][1])] = name
        end

        local function resolve(current)
            if type(current) == "number" then
                return byIndex[current]
            end
            if type(current) == "table" then
                current = current.Title
            end
            if type(current) == "string" then
                return byTitle[UI.cleanTitle(current)]
            end
            return nil
        end

        task.spawn(function()
            while true do
                local target = resolve(Window.CurrentTab)
                if target then
                    buildTab(target)
                end

                local remaining = 0
                for _, name in ipairs(order) do
                    if not built[name] then
                        remaining = remaining + 1
                    end
                end

                if remaining == 0 then
                    break
                end
                task.wait(0.05)
            end
        end)
    end

    -- ========================================================
    -- Pestañas dinámicas (plugins, etc.) — siguen siendo inmediatas.
    -- ========================================================
    for name, fn in pairs(UCam._dynamicTabBuilders) do
        if type(fn) == "function" then
            UCam._builtDynamicTabs[name] = true
            local ok, err = pcall(fn, Window)
            if not ok then
                warn(("[UCam] Tab dinámico '%s' falló: %s"):format(name, tostring(err)))
            end
        end
    end

    -- v11 FIX: el watcher antiguo comparaba un hash de tostring() de valores
    -- numéricos cada Heartbeat: con floats (3.0000001) disparaba saves falsos
    -- en bucle, y con valores estables nunca ahorraba nada real. El autosave
    -- real ya lo disparan los módulos (persistence: scheduleSave en cada
    -- mutación relevante, incluidos los props); aquí solo se garantiza un
    -- guardado tras construir la UI por si loadConfig cambió algo.
    if UCam.scheduleSave then
        UCam.scheduleSave()
    end

    -- Diagnóstico: con esto el log dice si el tema y el fondo llegaron de
    -- verdad a la ventana, sin tener que adivinar por la captura.
    local elapsed = (os.clock() - startedAt) * 1000
    local appearance = UI.describeAppearance and UI.describeAppearance() or "?"
    print(("[UCam] UI lista en %.0f ms, %d pestañas diferidas. Aspecto: %s"):format(
        elapsed, math.max(#order - 1, 0), appearance
    ))
end
