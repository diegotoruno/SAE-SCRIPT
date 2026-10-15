# Estilo de Mistake Hub

Mistake Hub y el acceso rapido Server Hop son herramientas de consulta dentro de Roblox.
Su prioridad es leer el estado de la busqueda y los ingresos sin competir con
el mapa del juego. El lenguaje visual sigue a macOS (Finder y Ajustes del
Sistema): barra lateral con iconos y capsula de seleccion, superficies de
vidrio, un solo acento azul para seleccion y acciones, colores semanticos solo
para estados y ningun texto sobre otro. Hay tema Claro, Oscuro y Sistema. Cada
texto tiene su propia caja y se corta con puntos suspensivos en lugar de
desbordarse. Las opciones, textos y acciones son las de la version anterior del
hub; el rediseno solo cambia la presentacion y agrega el selector de tema.

## Superficies y color

`support.THEMES` en `hopper_runtime.luau` es la unica fuente de color: los
mismos tokens en claro y oscuro (RGB). El runtime los convierte en
`hubTheme.colors`; el hub los usa como `C` y el runtime como `COLORS` (alias
que leen el token en el momento). La tarjeta flotante usa su paleta de manga. CI comprueba que ambos temas
tienen los mismos tokens, que el cambio de tema es inequivoco y los contrastes
de la tabla.

| Token | Claro | Oscuro | Uso |
| --- | --- | --- | --- |
| `window` | `#FAFAF9` al 4 % | `#1E1E20` al 4 % | Area principal, tarjeta flotante, boton M, hojas |
| `sidebar` | `#E9EAED` al 12 % | `#28282B` al 12 % | Barra lateral de vidrio |
| `raised` / `field` | `#FFFFFF` | `#2C2C2F` | Tarjetas, grupos, filas con interruptor, campos |
| `control` / `controlHover` | `#FCFCFC` / `#F0F0F3` | `#3A3A3D` / `#46464A` | Botones con borde; pestana al pasar |
| `separator` | `#3C3C43` | `#E5E5EA` | Bordes al 78 % de transparencia (40 % al pasar) |
| `text` | `#1D1D1F` | `#F5F5F7` | Titulos, nombres, valores (7:1 o mas) |
| `secondary` / `tertiary` | `#636368` / `#8E8E93` | `#A4A4AA` / `#7C7C82` | Etiquetas y ayuda (4.5:1); terciario solo iconos y asas |
| `accent` | `#007AFF` | `#0A84FF` | Interruptor encendido, borde seleccionado, anillo de foco, logo |
| `accentStrong` + `onAccent` | `#006EE6` + blanco | `#0062CC` + blanco | Acciones principales: Server Hop, Aplicar filtros, Listo, Guardar |
| `accentText` / `selection` | `#0064D6` / `#DBEBFF` | `#64ACFF` / `#1C3A60` | Texto e icono seleccionados sobre la capsula azul suave |
| `green` / `greenDot` / `successTint` | `#1A7534` / `#34C759` / `#E3F5E8` | `#4AD678` / `#30D158` / `#183422` | AUTO activo, Cumple, capturado |
| `orange` / `orangeDot` / `orangeTint` | `#A84A00` / `#FF9500` / `#FFF2E0` | `#FFAA3C` / `#FF9F0A` / `#3A2A10` | Mejor del ciclo, cambios sin aplicar, saltos sin confirmar |
| `red` | `#C41E28` | `#FF8A82` | Errores y Borrar |
| `fill` | `#787880` | `#808088` | Relleno gris al pasar (90 %) y pulsar (82 %), pista de los segmentados (88 %) |
| `yellow` / `yellowEdge` / `yellowGlyph` | `#FFBD2E` / `#DEA123` / `#995700` | iguales | Semaforo de minimizar |
| `trackOff`, `knob`, `scrim` | | | Interruptor apagado, perilla blanca, velo negro y sombras |

El tema oscuro no es una inversion: fondos grafito, superficies en tres grises
(`raised`, `control`, `controlHover`), texto claro y azules mas luminosos. El
color de rareza viene del juego y se acerca al texto del tema hasta 4.5:1 sobre
tarjeta, control, seleccion y coincidencia. Los nombres van en el color de
texto; la rareza aparece en su color dentro de la linea de etiquetas.

Roblox no ofrece desenfoque de fondo: el vidrio son superficies translucidas
(area principal al 4 %, barra lateral al 12 %) con borde fino y una sombra
suave de tres capas negras (90, 94 y 96.5 % de transparencia, separadas 2, 6 y
14 px). La ventana se construye con piezas que no se solapan (cuerpo, franjas y
cuartos de circulo recortados) para que la translucidez sea uniforme hasta en
las esquinas.

## Tema

Ajustes > Apariencia tiene un control segmentado `Claro / Oscuro / Sistema`
(292 x 32, pista gris y pastilla que marca la opcion elegida) con su explicacion a la
derecha. Se guarda como `theme` en `chilli_egg_panel_ui.json`; por defecto es
`system`.

- El runtime lee la preferencia antes de crear cualquier interfaz: la tarjeta
  flotante, el hub y el boton M nacen ya con el tema correcto, sin destello.
- Roblox no expone la apariencia del sistema operativo (no hay propiedad de
  tema en `UserGameSettings` ni en `GuiService`). `Sistema` sigue la hora local
  del dispositivo, como el modo automatico de macOS: claro de 7:00 a 19:00 y
  oscuro el resto. Se revisa cada 30 s y cambia sola; el bucle termina con la
  sesion.
- Cambiar de tema reemplaza en su sitio cada color de la interfaz por el del
  mismo token (fondos, textos, bordes, marcadores de posicion y barras de
  desplazamiento; las imagenes no). Despues se repintan los estados, se cierra
  la hoja abierta y se reconstruyen las tarjetas y la seccion visible, que
  mezclan colores calculados (rareza).
- API: `finder.Theme()` y `finder.SetTheme("light" | "dark" | "system")`.

## Acceso rapido Server Hop

Unica pieza flotante. El interruptor `Acceso rapido flotante` de la seccion
Server Hop la muestra u oculta; la preferencia se guarda como `quick` en
`server_hop_button_ui.json`.

Panel de manga con paleta propia (`support.MANGA`), igual con cualquier tema
del hub: `hubTheme.fixed` apunta a la tarjeta y el cambio de tema la salta. CI
comprueba sus contrastes. Tonos de Gojo: papel blanco frio `#F6F8FF`, tinta
azul noche `#0E1024`, acento azul `#2563EB` a violeta `#7C3AED`, trama lavanda
y sombra violeta `#4C1D95`.

- Una sola fila, sin plegado, estado ni firma: AUTO y el contador (el boton
  Server Hop, que muestra la accion o la cuenta atras). 250 x 60: AUTO en
  (8, 8) de 56 x 44 y contador desde x = 70 hasta 20 px del borde derecho, de
  44 px de alto. El estado completo sigue en la seccion Server Hop del hub.
- Superficie de papel con borde de tinta de 3 px, esquinas de 4 px y sombra
  solida violeta desplazada 5 px abajo a la derecha (sin sombra difusa).
- Fondo: la vineta de los ojos (`mistake_hop_banner.jpg`, recorte 4:1 de un
  panel de manga) cubre la tarjeta, recortada al centro, tenida de lavanda
  (`backdrop`) y al 78 % de transparencia. Se descarga de `stable` como el
  icono; sin ella, una trama de puntos lavanda en la esquina inferior
  izquierda.
- Contador: vineta con degradado azul a violeta, borde de tinta de 2.5 px y
  rotulo en Bangers 21, blanco con contorno de tinta. Lineas de velocidad
  blancas, quietas y tenues en reposo; mientras hay un salto se aclaran y
  corren en bucle (0.45 s, lineal), y el boton baja al 85 % de opacidad. Con
  movimiento reducido no corren. Pulsar atenua el degradado al instante y baja
  el rotulo 1 px.
- AUTO: etiqueta en Bangers 14 (azul si esta activo, azul gris si no) e
  interruptor cuadrado de 38 x 20 con borde de tinta: pista azul o lavanda
  palida y perilla de tinta.
- Asa de tamano de 18 x 18 en la esquina inferior derecha, fuera del
  contador: tres trazos diagonales de 1.5 px (3, 7 y 11 px) dentro del borde, trama lavanda al 60 % y azul al pasar o
  arrastrar (120 ms, Quad Out). Escala la tarjeta entera (UIScale) entre
  0.75 y 1.75, sin pasar del ancho/alto de la pantalla, y fija el borde
  izquierdo. Las medidas de arriba son a escala 1.
- Los mensajes de estado empiezan con mayuscula, dicen que pasa y que hacer
  ("Salto sin confirmar. Pulsa Server Hop para reintentar."). No usan glifos
  como ✓ o ✗ que algunas fuentes no tienen.

## Mistake Hub

Una sola ventana reune todas las opciones; las unicas piezas flotantes son el
acceso rapido de Server Hop y el boton `M` del hub minimizado. Estructura inspirada en Chilli Hub (cabecera,
pestanas laterales, secciones con interruptores), con la paleta propia.

- 760 x 560, esquinas de 14 px. Cabecera de 56 px, barra lateral de 172 px y
  paginas de 548 x 472 con margen de 20 px.
- Estilo Finder: la barra lateral de vidrio ocupa toda la altura; la barra
  de herramientas (56 px) va sobre el area principal con una linea fina
  debajo. Lo alto de la barra lateral y la barra de herramientas arrastran el
  hub.
- Barra de herramientas: icono de 32 px (esquinas de 8), titulo `Mistake Hub`
  (17 px) y subtitulo `Steal An Egg` (11 px); a la derecha AUTO (108 px,
  etiqueta `AUTO` e interruptor de 44 x 24, sin borde, relleno gris al pasar).
- Icono: la imagen `mistake_hub_icon.jpg`, que CI publica en `stable` junto
  al script. El runtime la descarga una vez al workspace del executor y la
  carga con `getcustomasset` (Roblox no lee archivos locales); sin esa funcion,
  sin red o si la descarga no es un JPEG, se muestra la `M` blanca sobre azul.
- Minimizar es el semaforo amarillo de macOS (12 px) arriba a la izquierda
  de la barra lateral: el menos aparece al pasar el raton o con el foco, y
  siempre en pantallas tactiles.
- Minimizado: el hub se guarda y queda el boton `M`, independiente del hub
  (como el boton de Chilli Hub): un icono de app de 56 x 56, esquinas de
  14 px; la imagen llena todo el boton, con sombra suave, un brillo fino en el
  borde y un punto de 14 px sobre su esquina superior derecha (verde con AUTO
  activo, gris apagado; borde del color del fondo). Tiene su propia
  posicion (empieza al borde izquierdo, a media altura) y se arrastra solo.
  Sin teclado (movil, iPad) no hay Alt izquierdo: este boton es la forma de
  volver. Tocarlo abre el hub completo en su propio sitio, en la misma
  seccion, no desde el boton; un recorrido de mas de 10 px es arrastre, no
  toque. Pasar el raton o pulsar ilumina su borde en azul. Solo se ve con
  el hub minimizado. Las tarjetas y modelos se liberan mientras esta
  minimizado.
- Barra lateral: vidrio `sidebar` separado del area principal por una linea
  fina. Bajo el semaforo, entradas de 32 px separadas por 4, cada
  una con su icono de trazo fino a la izquierda: lupa (Egg Finder), embudo
  (Filtros), calculadora (Calculadora), flechas opuestas (Server Hop) y
  deslizadores (Ajustes). Una sola capsula azul suave `ActiveTab`
  (`selection`) se desliza a la pestana activa; su texto pasa a SemiBold y,
  como el icono, a `accentText`. El resto usa texto Regular e icono
  secundario. Pasar el puntero da un relleno `fill` suave y pulsar uno
  mas firme, al instante. Filtros muestra un punto naranja con cambios sin
  aplicar. Al pie, solo la tarjeta del TikTok (sin estado de AUTO ni firma:
  AUTO se lee en la barra de herramientas y el punto del boton minimizado).
- Tarjeta del TikTok (marca de agua): 148 x 92 en superficie con borde,
  etiqueta `TIKTOK` (10 px Bold, secundaria), el enlace a la vista
  `tiktok.com/@mistakeontt` (11 px, texto) y `Copiar enlace` (primario
  azul, 32 px). El boton copia `https://www.tiktok.com/@mistakeontt` con el
  portapapeles del executor (`setclipboard`; Roblox no tiene API de
  portapapeles) y dice `Copiado` en verde 1,6 s; sin portapapeles dice `Sin
  portapapeles` y el enlace sigue escrito.
- Egg Finder: estado sin caja (punto, titulo de 15 px, linea explicativa y
  reloj a la derecha) con una linea fina debajo, fila `Filtros` con el resumen
  guardado y `Editar filtros`, barra con `Todos N` / `Cumplen N` como control
  segmentado (pastilla que se desliza) y los botones `Ver:` y `Orden:`, y la
  lista virtualizada debajo. AUTO, `Todos`/`Cumplen`,
  `Ver:` y `Orden:` se repintan en la misma pulsacion.
- Lista agrupada: un grupo blanco con filas de 100 px separadas por lineas
  finas (sangradas tras la imagen), imagen de 76 px. El fondo de la fila solo
  cambia para comunicar estado: verde suave si cumple, naranja suave el mejor
  del ciclo. Filas propias para
  nombre, ingreso (20 px), escala/peso y etiquetas (rareza en su color,
  mutaciones, zona). Insignia a la derecha: `Cumple` en verde o el motivo
  corto (Rareza baja, Otra zona, Otro nombre, Sin mutacion, Ingreso bajo),
  siempre opaca. Toda la tarjeta abre el detalle; un chevron lo indica.
- Filtros: titulo y ayuda; grupo de filas como Ajustes del Sistema (tres
  filas de 40 separadas por lineas finas, etiqueta a la izquierda y control a
  la derecha): Rareza minima e Ingreso minimo /s; Mutacion y Zonas; Nombre
  contiene. Rareza, mutacion y zonas son desplegables con doble chevron.
  Debajo, el mensaje junto a `Aplicar filtros`. Los presets son una lista
  agrupada. Debajo, separada por el margen y su
  titulo, la seccion Presets: nombre, `Guardar actuales` y la lista
  (Cargar / Borrar).
- Calculadora: especie y peso arriba; a la izquierda las mutaciones en dos
  columnas con su bono (medido una vez por especie); a la derecha la tarjeta
  de resultado (ingreso en
  `accentText` de 24 px, exacto, por minuto/hora/dia, multiplicador, tamano, sin
  mutaciones y una nota).
- Server Hop: tarjeta `Estado` con el mismo texto que la tarjeta flotante y
  el boton azul `Server Hop` (172 x 44) a la derecha; interruptores AUTO y
  `Acceso rapido flotante`; seccion Cuenta y Best Ping con estado a la
  derecha del titulo, campo oculto, ayudas y tres botones (Guardar y usar
  AUTO en azul, Solo esta sesion, Borrar cookie en rojo).
- Ajustes: seccion Apariencia (selector de tema), Alertas con los
  interruptores Notificacion y Sonido (cambian en su sitio, sin reconstruir
  la pagina) y `Probar alerta`, y la seccion Interfaz con los atajos
  (etiqueta 12, valor 13). `Restablecer tamano y posicion` es la accion de
  esa seccion: va en su encabezado, alineada a la derecha.
- Interruptor: fila de 52 px con titulo y detalle; pista de 44 x 24 a la
  derecha, azul si esta activo y `trackOff` si no, con perilla blanca de
  borde fino. Toda la fila lo cambia.
- Hojas modales (rareza, mutacion, zonas, especie, detalle, historial) sobre
  un velo que bloquea el hub; ocupan el area de paginas (548 de ancho, 480 de
  alto como maximo), con sombra suave y una X circular gris. Tocar el velo o
  la X cierra la hoja. Sus listas son grupos con filas separadas por lineas
  finas: rareza, mutacion y especie marcan la opcion elegida con una marca a
  la izquierda, como los menus de macOS; zonas usa casillas azules a la
  izquierda.
- Detalle: nombre, rareza y zona, veredicto, filas de 36 px etiqueta (12) /
  valor (14 SemiBold) dentro de un grupo con lineas finas (ingreso, exacto, minimo, tamano
  y peso, mutaciones, zona) y las acciones en una fila: `Mejores de los
  ultimos ciclos` (solo el mejor del ciclo) y `Calcular con otras
  mutaciones`.
- Historial de mejores (`Mejores de los ultimos ciclos`): abierto desde el
  detalle muestra `Detalle` con un chevron a la izquierda de la X, que
  vuelve al detalle. Hasta 6 filas de 58 px (este ciclo con borde naranja,
  luego los 5 ultimos ciclos terminados). Cada fila: antiguedad, nombre,
  rareza en su color, zona y mutaciones; a la derecha el ingreso, en verde si
  llega al minimo guardado, con "llega al minimo" o "bajo el minimo". Al pie,
  el minimo guardado. Solo informativo.
- La misma asa de tres trazos del acceso rapido, en la esquina inferior
  derecha, escala el hub entre 0.6 y 1.5 con la esquina superior izquierda
  fija. La pantalla manda: si no cabe, se reduce aunque baje de 0.6. Las
  hojas modales la cubren. Seccion, plegado, tamano (`scale`), posicion y
  preferencias se guardan en `chilli_egg_panel_ui.json`.

## Toque anime

Sutil y siempre con los tokens del tema activo, asi que sigue a Claro y Oscuro
sin colores propios. Solo cambia el aspecto: no anade controles.

- Titulos (marca de la cabecera, encabezados de seccion, TIKTOK) en Bangers,
  la fuente de la tarjeta flotante; los textos de las opciones no cambian.
- Cabecera: la vineta de los ojos entre la marca y AUTO, 220 x 40, fundida por
  los lados (transparencia 0.45 en claro, 0.8 en oscuro), con lineas de
  velocidad de 1 px que corren hacia ella.
- Barra lateral: trama de puntos en el hueco sobre el TikTok, mas densa abajo
  a la izquierda.
- Bordes de tinta: la ventana y las tarjetas usan el color del texto en el
  borde (0.72) y una sombra plana desplazada (6 px la ventana, 4 px las
  tarjetas). Sin la imagen, todo lo demas se mantiene.

## Interaccion

Sin firma `By Mistake` visible (retirada de la tarjeta de acceso rapido el
2026-10-15); la marca de agua del TikTok vive solo al pie de la barra lateral. No hay etiqueta flotante en la pantalla (retirada el
2026-10-11) ni lanzadores flotantes del panel o de la cuenta (retirados con
el hub, 2026-10-14).

AUTO apagado es neutro; AUTO encendido usa verde suave con texto verde.
Las acciones principales usan azul con texto blanco. No confundir apagado
con error. Iconos, chevrones, minimizar, cerrar y marcas de seleccion usan
geometria nativa de Roblox.

Estados de los controles con borde: reposo (borde al 78 %), pasar y foco
(40 %), pulsado (al instante, con el oscurecido de `AutoButtonColor`) y
deshabilitado (formulario de cuenta mientras comprueba). Las selecciones usan
la capsula azul suave (`selection`) con texto `accentText` y borde azul; las
casillas de zonas son azules con marca blanca. Teclado y mando muestran un
anillo azul de 3 px (`SelectionImageObject`) en botones, pestanas, campos y el
boton M; los campos ademas pasan su borde a azul mientras se escribe.

El foco por seleccion de teclado es inmediato. La limpieza de sesion sigue
retirando panel, conexiones, resortes y bucles.

## Tipografia

Builder Sans (`rbxasset://fonts/families/BuilderSans.json`), la fuente de
sistema de Roblox, de la misma familia que SF Pro e Inter (Roblox no permite
cargar SF Pro). Pesos Bold, SemiBold y Medium via `FontFace`. Roblox no tiene
espaciado entre letras: los rotulos van en tipo oracion, no en mayusculas.

| Rol | Tamano | Peso |
| --- | --- | --- |
| Resultado de la calculadora | 24 | Bold |
| Ingreso de tarjeta | 20 | Bold |
| Titulo del hub y de hojas | 17 | Bold |
| Encabezado de seccion, nombre de tarjeta | 15 | Bold |
| Valor de fila del detalle | 14 | SemiBold |
| Control, valor de atajo | 13 | Medium (pestanas SemiBold) |
| Etiqueta de fila | 12 | Medium |
| Ayuda, rotulo (`Estado`, `Mutaciones`) | 11 | Medium / SemiBold |
| Insignia | 10 | Bold |

Los parrafos de ayuda usan `LineHeight` 1.1.

## Movimiento

Cada animacion da feedback o contexto; ninguna decora. Reloj, ingresos,
listas y tarjetas no se animan. Todo tween parte del valor actual, cancela el
anterior de la misma propiedad (un tween por propiedad) y se cancela al
destruir su objeto o el hub. Otro toque a mitad de camino invierte desde
donde esta.

| Que | Duracion | Curva |
| --- | --- | --- |
| Borde al pasar y soltar | 120 ms | Quad Out (pulsar: inmediato) |
| Fondo de pestana o de AUTO flotante al pasar y soltar | 120 ms | Quad Out (pulsar: inmediato) |
| Perilla y color del interruptor, en el mismo frame | 160 ms | Quint Out |
| Pagina nueva: sube 8 px | 180 ms | Quint Out |
| `ActiveTab` hasta la pestana activa | 200 ms | Quint Out |
| Abrir el hub en su sitio: escala 0.85 a 1, centro fijo | 280 ms | Quint Out |
| Minimizar el hub: escala 1 a 0.85 y se oculta | 180 ms | Quint In |
| Volver el hub a la pantalla tras cambiar su tamano | 240 ms | Quint Out |
| Hoja: entra desde su origen, escala 0.9 a 1, velo hasta 35 % | 220 ms | Quint Out |
| Hoja: sale por el mismo camino | 160 ms | Quint In |
| Tarjeta flotante: plegar / desplegar | 220 ms | Quint Out |
| Asa de tamano: color al pasar o arrastrar | 120 ms | Quad Out |

- Pulsar: el borde se ilumina y AutoButtonColor oscurece el fondo al
  instante (`GuiState` cubre raton, toque y mando); el cambio se confirma al
  soltar. `UIScale` escala desde el `AnchorPoint` y empuja a los hermanos de
  un `UIListLayout`, asi que no se usa para la pulsacion; solo en hojas,
  que estan centradas, y en el hub al abrir y minimizar, con la posicion
  compensada en el mismo tween para que el centro no se mueva.
- Origen de las hojas: rareza, mutacion, zonas y especie salen de su boton;
  el detalle, de su tarjeta; el historial abierto desde el detalle entra por
  la derecha y `Detalle` vuelve por la izquierda. Sin origen, la hoja sube
  12 px. La hoja que sale ya no bloquea el hub (`Interactable`).
- El hub aparece y se va en su propio sitio, nunca desde el boton `M`. Como
  las hojas, abrir lo expande desde el 85 % con el centro fijo; minimizar lo
  encoge al 85 % por el mismo camino y lo oculta al terminar, y el boton
  aparece al empezar. Escala y posicion comparten curva y tiempo. Mientras se va no recibe toques (`Interactable`)
  ni se puede arrastrar. Otro toque a mitad de camino lo invierte.
- Alt izquierdo hace lo mismo que minimizar y tocar el boton: con el hub
  abierto lo minimiza y deja el boton `M`; con el boton, abre el hub en su
  sitio. Si estaba oculto (`Close`), lo abre.
- La tarjeta flotante muestra su estado solo cuando termina de abrirse.
- Arrastre del hub, del boton `M` y de la tarjeta flotante: 1:1 desde el punto de agarre.
  Pasado el margen de 8 px resiste cada vez mas (constante 0.55); al soltar
  fuera, un resorte criticamente amortiguado (respuesta 0.3 s, sin rebote)
  vuelve desde donde esta con la velocidad del dedo. Dentro de la pantalla no
  hay impulso. El resorte corre en `RenderStepped` solo mientras vuelve.
- `GuiService.ReducedMotionEnabled`: sin desplazamientos ni escalas; las
  hojas aparecen en su sitio con un fundido de 120 ms del velo, los colores
  del interruptor funden en 120 ms y minimizar y volver al borde son inmediatos.
- `GuiService.PreferredTransparency` lleva la transparencia del velo de 35 %
  hasta 10 %.

La fuente de spawns, el ingreso exacto, los filtros guardados y el flujo
esperar/hop/quedarse se documentan en `CONTEXT.md` y no dependen del estilo.

## Integracion con build 21

Se conservan virtualizacion, orden por rareza e ingreso, Alt izquierdo, presets, alertas, detalle exacto y parser de sufijos k/m/b/t/q. Las constantes de tarjeta tambien gobiernan canvas y ventana visible; los recursos visuales siguen cargando con reintentos.
