# Plan: Modularizar «Universal Camera Pro v6» y cargarlo con `loadstring`

> Objetivo: partir el script monolítico de **6291 líneas / 235 KB** (`Universal Camera.lua`) en varios archivos `.lua` alojados en un repo de GitHub, y cargarlos desde un **Loader** pequeño mediante `loadstring(game:HttpGet("...raw..."))()`.
>
> Así el script que pegas en el juego mide ~40 líneas en vez de 6000, y para la IA cada parte entra holgada en contexto.

---

## 1. Cómo funciona la arquitectura (concepto)

```
┌─────────────────────────────────────────────────────────────┐
│  Lo único que pegas en el juego (Loader.lua)                │
│  ─ define un namespace _G.UCam (tabla compartida)           │
│  ─ descarga y ejecuta cada parte en orden desde GitHub raw   │
│  ─ arranca la UI al final                                    │
└─────────────────────────────────────────────────────────────┘
        │ HttpGet + loadstring  (en orden, hay dependencias)
        ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ...
│ 00_config.lua │  │ 10_funs.lua   │  │ 20_spectate…  │
│ (estado +     │  │ (funciones    │  │ (espectador +  │
│  servicios)  │  │  auxiliares)   │  │  director)    │
└───────────────┘  └───────────────┘  └───────────────┘
        │ todos escriben en _G.UCam.* que el Loader pasa como entorno
        ▼
┌─────────────────────────────────────────────────────────────┐
│  90_init.lua  → arma el namespace final y define buildUI()  │
│  99_run.lua   → llama buildUI() y notifica "Listo"          │
└─────────────────────────────────────────────────────────────┘
```

**Mecanismo de comunicación entre partes:**
- El Loader crea una tabla `local UCam = {}` y la expone también como `_G.UCam` (por si acaso).
- Cada parte se carga con `setfenv`/entorno controlado donde `UCam` ya existe, de modo que hacer `UCam.Saved`, `UCam.startSpectate`, etc. funciona entre archivos como si fueran locales del mismo script.
- Las dependencias se respetan **por orden de carga**: un archivo solo puede referenciar funciones definidas en archivos cargados antes que él.

---

## 2. Convención de nombres y orden de carga

Los archivos se nombran con prefijo numérico para que el orden de dependencia sea evidente y estable:

| # | Archivo | Contenido | Líneas aprox. |
|---|---|---|---|
| 00 | `00_config.lua` | Servicios, Rayfield, `notify`, constantes, tablas de estado (`Saved`, `Hud`, `CamModes`, `Orbit`, `Fun`, `Filters`, `CustomFilters`, …) | 530 |
| 10 | `10_utils.lua` | Utilidades de cámara/character: `clamp`, `getEasingFn`, `syncFreeLookFromCFrame`, `buildFreeCameraCFrame`, `applyCameraRotation`, `getKeyboardDirection`, `moveCamera`, control de personaje (freeze/zero-root), path visualizer, green screen | 480 |
| 20 | `20_filters.lua` | Color correction, bloom, DOF, sunrays, vignette, letterbox (con `destroy*` centralizados), lighting tweaks | 500 |
| 30 | `30_fun.lua` | Módulo **Fun** completo (montar, física, escala, poses, efectos visuales: trail, disco floor, rainbow, neon) | 665 |
| 40 | `40_slowmo.lua` | **Bullet Time universal** (require PlayerModule, CFrame-lerp, toggle, update) | 500 |
| 50 | `50_spectate.lua` | Spectate (9 modos) + auto-ciclo + navegación | 480 |
| 60 | `60_director.lua` | Waypoints del modo Director + `updateDirector` | 120 |
| 70 | `70_camcore.lua` | `toggleFreeCam`, CrashZoom, Shake, Handheld, Dutch, AutoFocus, **`updateCamera`** (núcleo de render), `enforceCameraState` | 470 |
| 80 | `80_ui.lua` | **`buildUI()`** partido en bloques por pestaña (ver §5) | 2580 |
| 90 | `90_init.lua` | Llamada `buildUI()` + notificación de arranque | 20 |

> Si alguna parte queda demasiado grande para la IA, se puede subdividir aún más (ej. `80a_inicio.lua`, `80b_camaras.lua`, …). Las pestañas de UI son el mejor candidato porque son **independientes entre sí** una vez roto el scope.

---

## 3. Cambio de arquitectura clave: romper el scope de `buildUI()`

Hoy `buildUI()` es **una sola función de 2580 líneas** (líneas 3707→6289). Esto impide partir la UI porque todo comparte el mismo scope local (`Window`, `InicioTab`, `CamTab`, etc.).

**Solución:** convertir las pestañas en funciones separadas que reciben `Window` y devuelven/devuelven las refs que otras pestañas necesitan.

```lua
-- ANTES (todo dentro de buildUI):
local function buildUI()
    local Window = Rayfield:CreateWindow({...})
    local InicioTab = Window:CreateTab("🎬 Inicio", "home")
    InicioTab:CreateButton{...}
    ...
    local CamTab = Window:CreateTab("🎥 Cámaras", "camera")
    ...2580 líneas...
end

-- DESPUÉS:
local function buildUI()
    local Window = Rayfield:CreateWindow({...})
   buildInicioTab(Window)
    buildCamarasTab(Window)
    buildEspectadorTab(Window)
    buildSlowMoTab(Window)
    buildCinematicTab(Window)
    buildFiltersTab(Window)
    buildLightTab(Window)
    buildEstudioTab(Window)
    buildGimbalTab(Window)
    buildFunTab(Window)
    buildConfigTab(Window)
    buildInfoTab(Window)
    UCam.initBoot()  -- notificación inicial
end
```

Cada `buildXxxTab(Window)` vive en su propio archivo y registra en `UCam.UIRefs` los elementos que otras pestañas/controladores necesitan leer o escribir.

**Refs compartidas hoy (`UIRefs`), a mantener centralizadas en `UCam.UIRefs`:**
`PlayerDropdown`, `FilterDropdown`, `CustomFilterDropdown`, y sliders como `speedSlider`, `sprintSlider`, `fovSlider`, `vertigoMin/Max/Speed/Fov`, `slowMoIntensitySlider`, `lookAtPlayerDropdown`, `funMountDropdown`, `orbitDist/Height/Speed`, etc. (todos los `local` que hoy usa la lógica de `70_camcore` / `40_slowmo`).

---

## 4. El Loader (lo único que pegas en el juego)

```lua
-- Universal Camera PRO · Loader
-- By Cocoa Feliz · v6 modular

local BASE = "https://raw.githubusercontent.com/USUARIO/REPO/main/src/"

-- Namespace compartido entre TODAS las partes.
local UCam = {}
_G.UCam = UCam        -- por si alguna parte usa _G (legacy/safety)

-- Carga una parte desde GitHub y la ejecuta inyectando UCam + servicios.
local function loadPart(name)
    local url = BASE .. name
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if not ok or not src then
        warn(("[UCam] Error descargando %s: %s"):format(name, tostring(src)))
        return false
    end
    -- Compila y ejecuta dando acceso a UCam y al entorno global de Roblox.
    local fn, err = loadstring(src, name)
    if not fn then
        warn(("[UCam] Error de sintaxis en %s: %s"):format(name, err))
        return false
    end
    setfenv(fn, getfenv())  -- hereda servicios (game, workspace, importe de partes previas)
    fn()                    -- la parte declara sus locals UCam.X = ...
    return true
end

-- Orden estricto: cada parte puede usar UCam.* de las anteriores.
local ORDER = {
    "00_config.lua",
    "10_utils.lua",
    "20_filters.lua",
    "30_fun.lua",
    "40_slowmo.lua",
    "50_spectate.lua",
    "60_director.lua",
    "70_camcore.lua",
    "80_ui.lua",
    "90_init.lua",
}

local failed = 0
for _, part in ipairs(ORDER) do
    if not loadPart(part) then
        failed = failed + 1
        if failed >= 2 then                -- si fallan 2 seguidas, aborta
            warn("[UCam] Demasiados fallos, abortando carga.")
            break
        end
    end
end

if failed == 0 then
    print("[UCam] Universal Camera Pro v6 cargado OK.")
else
    warn(("[UCam] Carga completada con %d errores."):format(failed))
end
```

**Notas técnicas del Loader:**
- `setfenv(fn, getfenv())` deja que cada archivo declare `local camera = workspace.CurrentCamera` o use `game:*` normalmente, y que acceda a `UCam` porque lo dejamos en `_G` y en el entorno heredado.
- En Luau moderno (Roblox) `setfenv` existe para scripts cargados con `loadstring`; funciona como esperas.
- El orden garantiza que, p.ej., `70_camcore.lua` ya tenga `UCam.toggleFreeCam` disponible antes de que `80_ui.lua` asigne el callback de un botón a esa función.

**Atajo con `require` (alternativa más limpia):** si usas un repo tipo paquete (con `wally`/rojo) o modelos de GitHub, podrías usar `require(repo:HttpGet...)`, pero `loadstring` en cadena es el método estándar y más portable para exploits/Studio.

---

## 5. Subdivisión opcional de `80_ui.lua` (recomendada)

Como `80_ui.lua` serían ~2580 líneas y es lo que justamente queríamos aliviar, vale la pena partirla en una subcarpeta:

```
src/ui/
  80_ui.lua            ← solo buildUI() que llama a cada sub-builder
  inicio.lua
  camaras.lua
  espectador.lua
  slowmo.lua
  cinematic.lua
  filters.lua
  light.lua
  estudio.lua
  gimbal.lua
  fun.lua
  config.lua
  info.lua
```

`80_ui.lua` quedaría solo como:

```lua
local function buildUI()
    local Window = Rayfield:CreateWindow({...})
    for _, name in ipairs({"inicio","camaras","espectador","slowmo","cinematic",
                           "filters","light","estudio","gimbal","fun","config","info"}) do
        UCam["build_" .. name](Window)   -- cada sub-builder registrado en UCam
    end
end
UCam.buildUI = buildUI
```

> Cada sub-builder a su vez podría cargarse con `loadstring` para no incluirlos todos en `80_ui.lua`. Es la decisión que mejor escala: el contexto de la IA siempre ve **una pestaña a la vez**.

---

## 6. Qué mueve cada `local` al namespace `UCam`

Casi todos los `local` del script hoy son **compartidos** entre bloques. Pasan a `UCam.*`:

| Bloque | Locales que se vuelven `UCam.*` |
|---|---|
| config | `UserInputService`, `RunService`, `Players`, `Lighting`, `TweenService`, `Rayfield`, `notify`, `player`, `camera`, todas las constantes (`MOUSE_SENSITIVITY`, `MIN_FOV`, …), `freeCamEnabled`, `camCFrame`, `currentVelocity`, `camMode`, `CamModes`, `Saved`, `Hud`, `Fun`, `Filters`, `CustomFilters`, `UIRefs` |
| utils | `refreshCharacterRefs`, `disableControls`, `enableControls`, `disableCharacterCollision`, `restoreCharacterCollision`, `freezeCharacter`, `unfreezeCharacter`, `clamp`, `getKeyboard`, etc. |
| slowmo | `toggleBulletTime`, `updateSlowMo`, `startSlowMoTracking`, `stopSlowMoTracking` |
| spectate | `startSpectate`, `stopSpectate`, `updateSpectateCamera`, `spectateNextPlayer`, `spectatePrevPlayer` |
| director | `directorAddWaypoint`, `directorUndoWaypoint`, `directorTogglePlay`, `updateDirector` |
| camcore | `toggleFreeCam`, `updateCamera`, `enforceCameraState`, `applyShakeToCF`, `triggerShake` |
| ui | `buildUI` + los doce `buildXxxTab` |

> **Regla práctica para renombrar:** toda función/variable que se referencia en **más de un archivo** se prefija `UCam.`. Las que solo vive dentro de un archivo se queda como `local` privado.

---

## 7. Procedimiento de migración paso a paso

1. **Crear repo** en GitHub (público, para servir raw) con estructura `src/`.
2. **Generar `00_config.lua`** tomando las líneas 1–528 y reemplazando la carga de Rayfield para que use `UCam.Rayfield`. Dejar todas las tablas como `UCam.Saved`, etc.
3. **Ir bloque por bloque** (en el orden del §2): copiar el rango de líneas, anteponer `local UCam = _G.UCam`, reemplazar referencias locales cruzadas por `UCam.*`.
4. **Romper `buildUI()`**:
   - Mover líneas 3707→3895 (Window + Inicio) a `inicio.lua` como `UCam.build_inicio = function(Window) ... end`.
   - Repetir por cada pestaña (los rangos están marcados por `:CreateTab(...)`).
5. **Crear `90_init.lua`** con la llamada `UCam.buildUI()` + notificación (líneas 6287–6292).
6. **Probar localmente** antes de subir: usar el Loader apuntando a `file://` no vale (Roblox no permite); en su lugar, crear un script de prueba en Studio que haga `require` de cada archivo local con `loadfile`-like, o simular una a una con `loadstring(readfile("src/00_config.lua"))()`.
7. **Subir a GitHub** y obtener las URLs raw: `https://raw.githubusercontent.com/USUARIO/REPO/main/src/00_config.lua`.
8. **Pegar el Loader** en el destino y verificar notificación de arranque + operaciones clave (free cam, spectate, slowmo, un filtro, fun).
9. **Cachear** (opcional): el Loader puede guardar `src` en una tabla por sesión para no re-descargar; o usar `cache` de Rayfield.

---

## 8. Riesgos y cómo mitigarlos

| Riesgo | Mitigación |
|---|---|
| Un archivo se carga antes que una dependencia → nil error | Orden `ORDER` estricto + pruebas por bloque; comentarios de dependencia al inicio de cada archivo |
| `setfenv` no expone `UCam` | Lo dejas también en `_G.UCam`; fallback a `local UCam = _G.UCam` al inicio de cada archivo |
| GitHub caído / rate limit | Fallback con `jsdelivr.net` (`cdn.jsdelivr.net/gh/USUARIO/REPO@main/src/...`) como segunda URL en el Loader |
| Alguien edita el repo y rompe una parte | Fijar `@v6.0.0` (tag/release) en la URL, no `@main`, para producción |
| `loadstring` restringido en Studio | Usar `HttpService.HttpEnabled` + exploits; en Studio solo con `loadstring` habilitado. Para end-users de exploit, `loadstring` está disponible |
| Duplicar estado | Asegurar que **solo `00_config.lua`** crea `UCam`; el resto solo lo lee/escribe |
| `90_init.lua` corre pero `buildUI` no existió → error | El Loader reporta `failed`; además `90_init` hace `if UCam.buildUI then ... else warn end` |

---

## 9. Estructura final del repo

```
universal-camera/
├─ README.md                 ← URLs raw + instrucciones de uso del Loader
├─ Loader.lua                ← el script que se pega en el juego
└─ src/
   ├─ 00_config.lua
   ├─ 10_utils.lua
   ├─ 20_filters.lua
   ├─ 30_fun.lua
   ├─ 40_slowmo.lua
   ├─ 50_spectate.lua
   ├─ 60_director.lua
   ├─ 70_camcore.lua
   ├─ 80_ui.lua
   └─ 90_init.lua
      (si se subdivide UI:)
      ui/ inicio.lua  camaras.lua  espectador.lua  slowmo.lua
          cinematic.lua  filters.lua  light.lua  estudio.lua
          gimbal.lua  fun.lua  config.lua  info.lua
```

**Tamaños resultantes estimados:**
- Loader: ~60 líneas.
- Cada parte de lógica: 120–665 líneas (todas manejan fácilmente en contexto de IA).
- Cada sub-pestaña de UI: 100–350 líneas.

**Resultado:** en vez de 1 archivo de 6291 líneas, ~22 archivos, ninguno mayor a ~700 líneas y la mayoría por debajo de 400. La IA podrá leer/ editar **una parte** sin arrastrar las demás.

---

## 10. Próximos pasos sugeridos (orden de ejecución)

1. Crear el repo + carpetas.
2. Generar `00_config.lua` y `Loader.lua` (esqueletos) y subirlos.
3. Migrar bloque a bloque **validando** que cada parte carga sin error antes de seguir (parar Rayfield-Notify: «Parte X cargada»).
4. Romper `buildUI()` al final, cuando la lógica ya funciona modular.
5. Etiquetar `v6.0.0` y apuntar el Loader a ese tag.

> Conveniencia para la IA: cada archivo abre con un **encabezado estándar**:
> ```lua
> -- Universal Camera Pro v6 ·parte · dependencias: 00, 10
> local UCam = _G.UCam
> ...
> ```
> así generar / editar una parte sabe siempre qué necesita antes.
