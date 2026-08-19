# Universal Camera Pro v9 · Modular

Camara libre cinematografica para Roblox. **14 modos de camara, 30 filtros, Bullet Time universal, espectador con 9 estilos, modo Director con waypoints, post-procesado completo, efectos de diversion, nuevas funciones v8.1 y una UI expandida** — todo envuelto en una UI de 12+ pestanas de Rayfield.

> Versión actual: tag `v9.0.0`.
> La versión anterior quedó preservada en la rama `legacy/v6` y en el tag `v6.0.0`.
> Script original: `Universal Camera.lua` (6292 lineas, 235 KB).
> Refactorizado en varios archivos siguiendo el plan del documento `PLAN_MODULARIZACION.md`.

---

## Como se usa

### 1. Pegar el script en el juego

Copia el contenido de `Loader.lua` y pegalo en tu executor / Studio.

El Loader descarga todas las partes desde GitHub raw (o jsdelivr como fallback), las ejecuta en orden y construye la UI. **NO necesitas pegar el script gigante de 6000 lineas** — solo este Loader (~150 lineas).

### 2. Configurar el repo

Antes de usarlo, edita la primera linea del Loader:

```lua
local BASE = "https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/src/"
local FALLBACK_BASE = "https://cdn.jsdelivr.net/gh/TU_USUARIO/TU_REPO@main/src/"
```

Sube el contenido de `src/` (incluyendo la subcarpeta `ui/`) a tu repo en la rama `main`. Las URLs raw son publicas, asi que el repo puede ser publico.

### 3. Versionar

Para produccion, **fija la URL a un tag** en vez de `@main`:

```lua
local BASE = "https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/v7.0.0/src/"
```

La rama `main` contiene la version principal actual. Si necesitas la antigua, usa la rama `legacy/v6` o el tag `v6.0.0`.

---

## Estructura del repo

```
universal-camera/
├── README.md                 ← este archivo
├── Loader.lua                ← el unico script que pegas en el juego
├── PLAN_MODULARIZACION.md    ← el plan original con la justificacion
├── Universal Camera.lua      ← script original (6292 lineas, conservado como referencia)
└── src/
    ├── 00_config.lua         ← servicios, Rayfield, notify, TODAS las tablas de estado
    ├── 10_utils.lua          ← refresh refs, freeze/unfreeze, clamp, easing, path viz, croma, lighting tweaks
    ├── 20_filters.lua        ← color correction, bloom, DOF, sun rays, vignette, letterbox
    ├── 30_fun.lua            ← modulo de diversion: montar, noclip, escala, poses, trail, disco, etc.
    ├── 88_v9extras.lua       ← gamepad, escenas, keyframes, plugins v2 y timelapse
    ├── 50_spectate.lua       ← espectador (9 modos) + navegacion Q/E
    ├── 60_director.lua       ← waypoints + reproduccion con easing
    ├── 70_camcore.lua        ← toggleFreeCam, CrashZoom, Shake, updateCamera (14 modos), input
    ├── 80_ui.lua             ← orquestador de la UI (arma la Window de Rayfield)
    ├── 90_init.lua           ← llamada final a buildUI() + notificacion
    └── ui/
        ├── inicio.lua        ← Camara libre, HUD, captura, teletransporte, Restablecer todo
        ├── camaras.lua       ← los 14 modos y todos sus parametros
        ├── espectador.lua    ← jugadores, auto-ciclo, 9 estilos
        ├── slowmo.lua        ← Bullet Time (toggle + ajustes)
        ├── cinematic.lua     ← letterbox, vignette, shake, FOV pulse, director, post-procesado
        ├── filters.lua       ← 30 built-in + editor custom
        ├── light.lua         ← mezclador de iluminacion / clima
        ├── estudio.lua       ← pantalla verde / croma
        ├── gimbal.lua        ← LookAt Lock (bloqueo de objetivo)
        ├── fun.lua           ← diversion
        ├── config.lua        ← keybinds
        └── info.lua          ← ayuda / documentacion
```

### Tamanos (aprox.)

| Archivo | Lineas |
|---|---|
| `Loader.lua` | 150 |
| `00_config.lua` | 530 |
| `10_utils.lua` | 480 |
| `20_filters.lua` | 320 |
| `30_fun.lua` | 580 |
| `40_slowmo.lua` | 380 |
| `50_spectate.lua` | 410 |
| `60_director.lua` | 120 |
| `70_camcore.lua` | 760 |
| `80_ui.lua` | 60 |
| `90_init.lua` | 30 |
| `ui/*.lua` | 100–400 cada uno |

**Total:** 23 archivos, ninguno mayor a 800 lineas, la mayoria por debajo de 400.

---

## Como funciona la arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│  Lo unico que pegas en el juego (Loader.lua)                │
│  ─ define un namespace _G.UCam (tabla compartida)           │
│  ─ descarga y ejecuta cada parte en orden desde GitHub raw   │
│  ─ si fallan 2 seguidas, aborta con warn                    │
└─────────────────────────────────────────────────────────────┘
        │ HttpGet + loadstring  (en orden, hay dependencias)
        ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ...
│ 00_config.lua │  │ 10_funs.lua   │  │ 20_spectate…  │
│ (estado +     │  │ (funciones    │  │ (espectador + │
│  servicios)   │  │  auxiliares)  │  │  director)    │
└───────────────┘  └───────────────┘  └───────────────┘
        │ todos escriben en UCam.* que el Loader pasa como entorno
        ▼
┌─────────────────────────────────────────────────────────────┐
│  80_ui.lua  → arma la Window y llama a cada build_xxx       │
│  90_init.lua → llama buildUI() y notifica "Listo"           │
└─────────────────────────────────────────────────────────────┘
```

**Mecanismo de comunicacion entre partes:**
- El Loader crea una tabla `local UCam = {}` y la expone tambien como `_G.UCam`.
- Cada parte se carga con `setfenv`/entorno controlado donde `UCam` ya existe, de modo que hacer `UCam.Saved`, `UCam.toggleFreeCam`, etc. funciona entre archivos como si fueran locales del mismo script.
- Las dependencias se respetan **por orden de carga**: un archivo solo puede referenciar funciones definidas en archivos cargados antes que el.

**Regla practica para renombrar:** toda funcion/variable que se referencia en mas de un archivo se prefija `UCam.`. Las que solo viven dentro de un archivo se quedan como `local` privado.

---

## Como editar / extender

Cada archivo abre con un encabezado estandar que documenta:
- sus **dependencias** (que partes debe haber cargado antes)
- lo que **expone** (que funciones/tablas registra en `UCam`)

```lua
-- Universal Camera Pro v6 · 30_fun
-- Modulo de diversion (Fun): montar, noclip, gravedad, ...
--
-- Dependencias: 00_config, 10_utils
-- Expone (UCam.*):
--   funAnyActive, funSnapshotCharacter, funRestorePartVisuals,
--   funRestoreHumanoid, funClearPartSnapshots, funEnsureHighlight,
--   ...
```

Para agregar una nueva pestana de UI:

1. Crea `src/ui/mi_pestana.lua` con `UCam.build_mi_pestana = function(Window) ... end`.
2. Anade `"mi_pestana"` al array `UCam._uiBuilders` en `src/80_ui.lua`.
3. Anade `"ui/mi_pestana.lua"` al `ORDER` en `Loader.lua`.

---

## Atajos en el juego

| Tecla | Accion |
|---|---|
| `F` | Activar / desactivar camara libre |
| `X` | Dejar de espectar |
| `E` | Siguiente jugador (espectar) |
| `Q` | Anterior jugador (espectar) |
| `Z` | Disparar Camera Shake (patron actual) |
| `Delete` | Mostrar / ocultar UI de Rayfield |
| `Clic der. + mouse` | Rotar camara |
| `Rueda del mouse` | Zoom (FOV) |
| `WASD` | Mover (modos Libre / Handheld) |
| `Shift` | Sprint |
| `Espacio / Ctrl` | Subir / bajar (Crane, modo libre) |

---

## Diferencias con el script original

El refactor es **funcionalmente identico** al `Universal Camera.lua` original:

- Mismas 14 modos de camara.
- Mismos 30 filtros built-in + editor custom.
- Mismo Bullet Time universal.
- Mismos 9 modos de espectador.
- Mismas 12 pestanas de UI con los mismos controles.
- Mismas teclas y atajos.

Los unicos cambios:
- Los `local` compartidos entre bloques pasaron a `UCam.*`.
- El `buildUI()` de 2580 lineas se partio en 12 sub-builders en `ui/*.lua`.
- El fix v4 de `triggerTransition` (NO usar `local function` que rompe el upvalue) se preserva.
- Se respeta la regla del compilador de Roblox: ningun chunk pasa de 200 locales.

---

## Licencia y creditos

- Script original: **Cocoa Feliz** · v6
- Refactor modular: generado a partir del plan `PLAN_MODULARIZACION.md`
- UI: [Rayfield](https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua) (Sirius Software)
