# Plan de Propuesta — Universal Camera Pro v9

> Documento de propuesta. **Nada de esto está implementado aún.**
> Se divide en: (0) resumen del estado de v8, (1) correcciones obligatorias antes de v9,
> (2) nueva función estrella: notificaciones silenciables, (3) pulido de opciones actuales,
> (4) opciones candidatas a eliminación, (5) módulos futuros opcionales, (6) orden de trabajo sugerido.

---

## 0. Estado de v8 (auditoría)

Se auditaron los 48 archivos (~19.000 líneas). La estructura modular está sana, pero la
auditoría encontró **~60 problemas reales**. Los más graves, agrupados:

### 🔴 Críticos (pérdida de datos o cuelgues)

| # | Ubicación | Problema |
|---|-----------|----------|
| 1 | `05_persistence.lua:277-289` + `33_poses.lua` | Las poses custom se guardan **vacías**: `deepCopy` descarta los CFrames, y al cargar sobrescriben las poses actuales con tablas vacías. Pérdida de datos garantizada. |
| 2 | `05_persistence.lua:277-289` + `32_bodycolor.lua` | Ídem: presets de BodyColor pierden `Color` (Color3) y material al guardar. |
| 3 | `05_persistence.lua:636-680` | `importConfig` **nunca restaura** `_replayRoutes` ni `_cameraPositions` aunque `exportConfig` sí los exporta. |
| 4 | `00_config.lua:968-971` | `WaitForChild("PlayerModule")` sin timeout dentro de pcall: si el juego no lo tiene, **toda la carga se cuelga para siempre**. |
| 5 | `45_timecontrol.lua:280-287` | `pairs(nil)` garantizado si se desactiva el control de tiempo sin haber aplicado audio slow-mo (crashea `stopTimeControl` y `Unload`). |
| 6 | `55_replay.lua:437-448` | `shareRoute` usa una firma de `HttpGet` que no existe → siempre falla al fallback. Función rota. |

### 🟠 Bugs funcionales importantes

- **`33_poses.lua:494,518`** — las poses no funcionan en R15 (busca "Torso", que no existe en R15). Solo sirven en R6.
- **`32_bodycolor.lua:229-253`** — los presets custom de BodyColor **no aplican nada** (el loop exige `preset.AllParts`, que los presets de usuario no tienen).
- **`65_macros.lua:193`** — PlaySpeed invertido: speed=2 reproduce el macro a la *mitad* de velocidad.
- **`65_macros.lua:205-207`** — la acción `toggle_cam` ignora el valor grabado (siempre alterna).
- **`ui/macros.lua:142-151`** — "Bullet Time en macro" setea `SlowMo.BulletTime` a pelo sin llamar `toggleBulletTime()` → nunca se activa realmente.
- **`ui/macros.lua:90-97`** — "Cambiar modo de cámara" en macros bypasea `triggerTransition()` → el modo queda sin inicializar (CableCam sin A/B, SecurityCam sin anchor, etc.).
- **`70_camcore.lua:736-745`** — MotionBlur solo **suma** FOV, nunca lo restaura → el FOV sube monótonamente hasta MAX_FOV y se queda ahí.
- **`40_slowmo.lua:183-210`** — al desactivar slow-mo físico, las partes quedan congeladas en su posición "renderizada", no se restaura el CFrame real.
- **`45_timecontrol.lua:369-380`** — si Bullet Time se apaga por otra vía, los sonidos quedan a 0.1x para siempre.
- **`60_director.lua:260-277`** — pausar el Director deja la cámara `Scriptable` congelada sin recuperación.
- **`30_fun.lua:960-962`** — en Fly, bajar usa la tecla **Sprint** en vez de **Down** (Ctrl).
- **`90_init.lua:42` + `70_camcore.lua:98-105`** — Unload dentro del debounce de toggleFreeCam deja cámara Scriptable + personaje anclado sin restaurar.
- **`55_replay.lua:573-599`** — serialización de rotación incompatible con `60_director` (roll 180°) y roundtrip de duración roto (submuestreo al serializar no se compensa al deserializar).
- **`57_profiles.lua:67`** — `S.Keybinds` puede contener EnumItem → `JSONEncode` explota → falla todo el guardado de config.
- **`50_spectate.lua:461-472`** — `Spectate.Favorites` guarda instancias Player (mismo riesgo JSON).
- **`75_audioreactive.lua:120-133`** — beat fantasma al cambiar de sonido objetivo (no se resetea `_prevLoudness`).

### 🟡 Fugas de memoria / conexiones

- `20_filters.lua:283` — `_viewportResizeConn` no pasa por `trackConnection` → se acumula en cada recarga.
- `50_spectate.lua:653-665` — `_pipWheelConn` nunca se desconecta.
- `40_slowmo.lua:243-265` — conexiones `CharacterAdded` por jugador que nunca se limpian al salir.
- `30_fun.lua:1030` — modo Painting: partes ilimitadas en workspace sin destrucción.
- `25_filterspro.lua` — funciones globales sin `local` + entrada muerta en `_connections` por toggle de Film Grain.
- `35_playermod.lua:400-413` — Heartbeat permanente llamando una función vacía.
- `85_performance.lua:84-94` — el profiler capturó `updateCamera` por referencia antes del bind: reemplazarla no afecta al callback → el módulo principal jamás aparece en el reporte.

### 🟡 Bugs de UI

- `ui/bodycolor.lua:467`, `ui/poses.lua:195` — leen `.CurrentValue` del elemento Rayfield en vez de `UCam.Rayfield.Flags` → "Guardar preset/pose" responde siempre "Escribe un nombre...".
- `ui/inicio.lua:89-176` — "Restablecer todos los valores" no sincroniza los toggles visuales (UI muestra ON con estado OFF).
- `ui/profiles.lua:140-158` — párrafo de quick-slots con `Tag` no soportado y `Tab.quickLabel` que nunca existe → siempre vacío.
- `ui/timecontrol.lua:72,84` — el botón anuncia tecla N que no existe en config.
- `ui/config.lua:206-229` — "Abrir carpeta de plugins" es un no-op (`getcustomasset` no devuelve rutas).
- `ui/bodycolor.lua:155` — botones de preset en orden aleatorio (itera hash con `pairs`).
- `70_camcore.lua:906-914` — click derecho sobre la UI de Rayfield también rota la cámara (se ignora `gameProcessedEvent`).

---

## 1. Correcciones obligatorias para v9 (fase "v8.1")

Antes de añadir nada nuevo, v9 debe incluir estas correcciones en este orden:

1. **Serializador CFrame/Color3/EnumItem** en `05_persistence.lua` (to/from tabla compacta) y usarlo en:
   CustomPoses, BodyColor presets, `_profiles`, Keybinds, `Spectate.Favorites` (guardar nombres, no instancias). Arregla los críticos #1, #2, #5 y el riesgo de `S.Keybinds`.
2. `importConfig` que restaure `_replayRoutes` y `_cameraPositions`.
3. Timeout en todos los `WaitForChild` de carga (`PlayerModule`, 5 s) — crítico #4.
4. Nil-check en `restoreAudioSlowMo` (crítico #5) + hook para restaurar audio cuando Bullet Time se apaga por cualquier vía.
5. Eliminar `shareRoute` o reescribirlo con `request`/`http_request` estándar.
6. Soporte R15 en poses (mapear Torso → UpperTorso/LowerTorso, joints R15).
7. Cablear correctamente macros: usar `UCam.toggleBulletTime()` y `UCam.triggerTransition()`; arreglar PlaySpeed (`* speed` en vez de `/ speed`) y respetar `value` en `toggle_cam`.
8. MotionBlur con restauración de FOV (guardar FOV base y lerp de vuelta).
9. `stopSlowMoTracking` restaura CFrames desde `RealPositions`; reset de `TickClock`; filtro de NPCs en Scope "Jugadores".
10. `directorTogglePlay(false)` restaura cámara; Unload de `90_init` fuerza restauración total sin pasar por debounces y también si solo Director/Replay estaban activos.
11. Pasar TODAS las conexiones por `trackConnection` (viewport resize, PiP wheel, CharacterAdded de slow-mo con limpieza en `PlayerRemoving`).
12. UI: leer valores vía `UCam.Rayfield.Flags[flag].CurrentValue`; sincronizar toggles en "Restablecer todo"; respetar `gameProcessedEvent` en InputBegan de camcore.
13. Unificar serialización de rotación Replay/Director y compensar el submuestreo en `deserializeRoute`.

---

## 2. ⭐ Nueva función principal v9: sistema de notificaciones silenciables

**Problema actual:** hay **~230 llamadas a `UCam.notify`** y **no existe ninguna opción de silencio**. Al activar/desactivar cualquier opción salta una notificación que puede arruinar una toma.

### Propuesta

#### 2.1 Tres niveles de modo (dropdown en pestaña Configuración)

| Modo | Comportamiento |
|------|----------------|
| **Todas** (default) | Como hoy. |
| **Solo importantes** | Se silencian las notificaciones "de confirmación" (ON/OFF de toggles, "lista actualizada", cambios de modo/filtro/target). Se mantienen: errores, avisos que requieren acción ("escribe un nombre", "perfil importado con error"), grabaciones iniciadas/finalizadas. |
| **Silencio total** | Nada se muestra, excepto errores críticos irreversibles (ej. fallo al guardar config). Pensado para hacer tomas limpias. |

#### 2.2 Implementación centralizada (cero cambios en los ~230 call-sites)

```lua
-- 00_config.lua
UCam.Config.NotificationMode = "all"   -- "all" | "important" | "silent"

function UCam.notify(title, msg, opts)
    opts = opts or {}
    local mode = UCam.Config.NotificationMode
    if mode == "silent" and not opts.critical then return end
    if mode == "important" and opts.trivial ~= false and not opts.important then return end
    Rayfield:Notify({ Title = title, Content = msg, Duration = opts.duration or 3 })
end
```

Luego basta un **pase único** por los call-sites etiquetando:
- `opts.important = true` → notificaciones que sobreviven a "solo importantes".
- `opts.critical = true` → las 2-3 que sobreviven a "silencio total".
- Todo lo demás queda implícitamente como trivial.

#### 2.3 Toggle rápido "Modo toma"

- Keybind configurable (sugerencia: **Ctrl+M**) que cicla `Todas → Solo importantes → Silencio total` **sin notificar el cambio** (excepto en modo "todas").
- Botón en la pestaña Inicio junto al HUD-toggle, visible siempre.
- El modo se persiste en el config (SCHEMA nuevo campo).

#### 2.4 Eliminar notificaciones por-step/per-frame (spam puro)

Independiente del modo, **eliminar o convertir en HUD temporal**:
- `45_timecontrol.lua:147` — notify en **cada frame avanzado** en frame-by-frame.
- `58_combos.lua:55` — "Step N → modo X" en cada step de combo.
- `55_replay.lua:339-361` — notify por cada marcador durante el playback.
- `70_camcore.lua:295` — `triggerShake` notifica cada disparo (y puede ser disparado por audio-reactive → spam).
- `50_spectate` — "perdió su personaje" en loop si el target parpadea (añadir cooldown de 3 s).

#### 2.5 Extras del sistema

- Duración configurable global (slider 1-8 s).
- Opción "No notificar durante Replay/Grabación": silencio automático mientras `Replay.Recording` o `Replay.Playing` estén activos.

---

## 3. Pulido de opciones actuales

1. **Un solo selector de jugador objetivo**: hoy hay 3 dropdowns (`TargetPlayerBodyColor`, `TargetPlayerPose`, `PlayerModTarget`) que escriben el mismo `PlayerMod.TargetPlayer` sin sincronizarse → un único dropdown global (en Inicio o Config) que las tres pestañas leen, o al menos sincronizar los tres vía flag compartido.
2. **Un solo toggle de Loop**: `camaras.lua:474` y `cinematic.lua:157` controlan el mismo `Waypoint.Loop` con dos toggles que divergen visualmente → dejar uno.
3. **Selector de ranura de perfiles**: quitar el slider 1-8 duplicado del dropdown de ranura.
4. **"Restablecer teclas por defecto"** debe actualizar los campos de los keybinds (hoy lo admite el propio notify).
5. **Keybind N para frame-by-frame** (el botón lo anuncia y no existe) — crear el keybind o quitar la mención.
6. **Slider de filtros en macros**: ampliar rango a `#UCam.Filters` real (35) y calcularlo dinámicamente.
7. **Doble handler de rueda en espectador**: la rueda cambia FOV (camcore) Y distancia (spectate) a la vez → en spectate, desactivar el zoom de FOV o usar modificador (Shift+rueda = FOV).
8. **Botón "Disparar Camera Shake"** en cinemático: duplicado de los 5 one-shot y del keybind Z → quitar el genérico.
9. **Consolidar quick-buttons de escala** (Diminuto/Gigante/...) con el slider custom de escala en Diversión.
10. **Filtros custom por nombre**: arreglar `applyFilterByName` con índice `-i` que `applyFilter` clampa a 1.
11. **`toggleFrameByFrame(false)`** no debe apagar un Bullet Time que estaba activo antes (guardar y restaurar estado previo); ídem fast-forward con `AdjustSpeed(1)` forzado.
12. **Restaurar `AutoRotate`** desde `UCam.Saved.AutoRotate` en vez de forzar `true`.
13. **Cache de partes de Fun tras respawn**: reconectar listeners en `CharacterAdded`.
14. **Botones de preset de BodyColor** con orden fijo (`ipairs` sobre array).
15. **Beat fantasma en audio-reactive**: reset `_prevLoudness = nil` al cambiar de target.
16. **Doble definición** de `spectateNextPlayer/PrevPlayer` (50:325 y 497) y `funUpdate` (30:616 y 1135): borrar las versiones muertas.

---

## 4. Opciones candidatas a ELIMINACIÓN (rotas o inútiles)

| Candidata | Motivo |
|---|---|
| `shareRoute` (replay) | Roto: firma HTTP inexistente. Eliminar o reescribir. |
| PiP del espectador (`50_spectate.lua:558-648`) | `Character:Clone()` ajeno casi siempre falla en cliente → pantalla en negro. Eliminar. |
| Pixelify / RadialBlur / TiltShift (filterspro) | No hacen lo que dicen: son overlays oscuros sin efecto real. Eliminar o reescribir de verdad con post-processing. |
| ChromaticAberration (filters) | Dos frames tintados casi invisibles. Eliminar. |
| `applyTransitionBlend` (70:354) | Función muerta. |
| `UCam.Plugins.Disabled` | Nunca consultado. |
| `Combos.Enabled` | Flag sin efecto. |
| `wpSpeed` por waypoint (Director) | Serializado pero nunca aplicado: implementar **o** eliminar. |
| Monitor de performance | El hook principal no mide nada (bind por referencia): arreglar o eliminar el módulo. |
| `TickRate` vs `TickStep` vs `BatchSize` (slow-mo) | Tres knobs de throttling que se pisan → dejar uno. |
| `customHudPaths` (70:18-28) | Hardcodeado para un juego específico, no-op en el resto → mover a plugin. |
| "Abrir carpeta de plugins" (config UI) | No-op. Eliminar. |
| Párrafo quick-labels de profiles | Roto (Tag no soportado). Eliminar o arreglar. |
| Doble botón "Restaurar Jugador Seleccionado" (bodycolor 349 y 424) | Idénticos. Dejar uno. |
| Sistema de poses de Fun (T-Pose/Sentado/Flotando) | Duplicado del de 33_poses y **pelean** entre sí. Conservar solo 33_poses. |
| Botones espectador Siguiente/Anterior/Dejar | Duplican los keybinds E/Q/X (opcional: mantener por accesibilidad). |

> Nota: la suma de eliminaciones reduce ~1.500-2.000 líneas y quita features que hoy solo generan confusión.

---

## 5. Módulos futuros propuestos para v9 (opcionales, priorizados)

1. **📸 Modo Toma Limpia (Clean Shot)** — un solo toggle que: silencia notificaciones (modo total), oculta UI Rayfield, activa Auto-HUD, opcionalmente oculta el nombre de usuario/nametags locales y desactiva el cursor al no moverse. Sinergia total con la función estrella de notificaciones.
2. **🖱️ Control de cámara con gamepad** — sticks para mover/orbitar, gatillos para velocidad/FOV. Reusa el sistema de keybinds.
3. **🎛️ Presets de "Escena"** — guardar en un solo clic: filtro + filterspro + iluminación + hora del día + FOV + modo de cámara (hoy hay que recrearlas a mano; los perfiles guardan estado pero no son "escenas rápidas" intercambiables en caliente).
4. **🎥 Export de replay a keyframes legibles** — reemplazo del shareRoute roto: exportar la ruta serializada a portapapeles/archivo con formato documentado, e importar. Sin servidor.
5. **🌗 Tema de UI / compact mode** — Rayfield soporta temas; un dropdown con 3-4 temas y densidad compacta para no tapar la vista.
6. **🔌 API de plugins v2** — exponer `UCam.notify` con niveles, eventos (`onToggle`, `onFilterChanged`) y sandbox real (hoy `Plugins.Disabled` no existe y no hay forma de deshabilitar un plugin individual).
7. **⏱️ Timelapse programado** — capturar posición/rotación cada N s y reproducirlas como replay acelerado (aprovecha el motor de replay existente).

Prioridad sugerida: 1 (Clean Shot) en v9.0 junto a notificaciones; 2-3 en v9.1; el resto backlog.

---

## 6. Orden de trabajo sugerido

1. **v8.1 — estabilización** (sección 1 completa + fixes de fugas). Sin features nuevas.
2. **v9.0 — notificaciones + limpieza** (secciones 2 y 4). La estrella de la versión.
3. **v9.0 — pulido** (sección 3).
4. **v9.1+ — módulos futuros** (sección 5, por prioridad).

Cada fase debería poder probarse de forma independiente (cargar en un juego base tipo Raig, espectar, grabar replay, guardar config y recargar el executor para validar persistencia).
