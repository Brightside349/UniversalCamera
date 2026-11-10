-- ============================================================
-- Universal Camera Pro v13 · UI builder
-- Construye la ventana, tabs estáticos/dinámicos y autosave.
--
-- v13.2: los builders se ejecutan primero contra una pestaña inerte para
-- conocer su título e icono; con eso se crean las 16 pestañas vacías
-- (baratas). El contenido se construía recién al abrir cada pestaña.
--
-- v13.6.4: ese "al abrir" era el problema: cada primer clic pagaba el costo
-- completo. Ahora el contenido de TODAS las pestañas se precarga en segundo
-- plano, una por frame, después de crear los cascarones: abrir la ventana y
-- recorrer cualquier pestaña es instantáneo, sin tirón al arrancar.
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
    -- FASE 2 · contenido de todas las pestañas
    -- v13.6.4: antes cada pestaña se armaba recién al abrirla, así que el
    -- primer clic en cada una pagaba el costo completo (y parecía que había
    -- que "cargar" cada módulo a mano). Ahora, después de crear los
    -- cascarones, un precargador arma una pestaña por frame en segundo plano:
    -- cuando el usuario abre la ventana, el contenido ya está listo.
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

    -- WindUI avisa del cambio con el ÍNDICE de la pestaña (no con el título).
    -- Se resuelve por índice y, por si una versión futura cambia la
    -- convención, también por título.
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

    -- La pestaña que se ve al abrir se construye ya, para que no haya hueco.
    if order[1] then
        buildTab(order[1])
    end

    -- El resto, una por frame. Si el usuario abre una pestaña que todavía no
    -- llegó, se arma en ese momento y el precargador la salta.
    task.spawn(function()
        for index = 2, #order do
            -- Si el script se descargo a mitad de la precarga, se corta.
            if not UCam._window then
                return
            end
            local visible = resolve(Window.CurrentTab)
            if visible and not built[visible] then
                buildTab(visible)
            end
            if not built[order[index]] then
                buildTab(order[index])
            end
            -- Un frame entre pestañas: los ~500 controles quedan repartidos y
            -- no hay ningún tirón visible al arrancar.
            task.wait()
        end

        -- Red de seguridad: cualquier pestaña que haya quedado pendiente.
        for _, name in ipairs(order) do
            if not built[name] then
                buildTab(name)
            end
        end

        UCam._uiReady = true
        print(("[UCam] UI completa: %d pestañas listas."):format(#order))
    end)

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
    print(("[UCam] UI lista en %.0f ms; contenido de %d pestañas en segundo plano. Aspecto: %s"):format(
        elapsed, #order, appearance
    ))
end
