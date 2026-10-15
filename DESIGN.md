# Estilo de Mistake Hub

Mistake Hub y el acceso rapido Server Hop son herramientas de consulta dentro de Roblox.
Su prioridad es leer el estado de la busqueda y los ingresos sin competir con
el mapa del juego. El estilo es sobrio: superficies grafito planas, un solo
acento champan para acciones, colores semanticos para estados y ningun texto
sobre otro. Cada texto tiene su propia caja y se corta con puntos suspensivos
en lugar de desbordarse.

## Superficies y color

Los tokens de `egg_filter_panel.luau` (`C`) y de `hopper_runtime.luau`
(`COLORS`) son la fuente ejecutable del estilo y comparten valores.

| Rol | Color | Uso |
| --- | --- | --- |
| Fondo | `#14181E` | Panel, tarjeta del boton, hojas modales y lanzador |
| Superficie | `#1E242C` | Controles, tarjeta de estado y tarjetas de spawns |
| Entrada | `#10141A` | Campos de nombre e ingreso minimo |
| Borde | `#38414D` | Separadores y limites discretos |
| Texto | `#EFF3F7` | Titulos, nombres e ingresos |
| Secundario | `#AAB7C5` | Etiquetas, metadatos y ayuda |
| Acento | `#E0C595` | Aplicar filtros, Listo, guardar preset, ingreso minimo, firma |
| Exito | `#93D7BF` | AUTO activo, coincidencias y seleccion |
| Informacion | `#AECEE5` | Reloj del ciclo y busqueda activa |
| Error | `#F0989F` | Ingreso invalido, zona vacia, fallo al guardar, Borrar |
| Accion Server Hop | `#C03942` | Unico rojo: boton principal del salto |
| Aviso del boton | `#F2BE7A` | Saltos sin confirmar y reintentos |
| Velo | `#06080B` al 35 % | Fondo detras de las hojas modales |

El color de rareza viene del juego. Se aclara lo necesario para alcanzar
contraste 4.5:1 sobre las superficies de tarjeta, seleccion y coincidencia.
Los nombres son blancos; la rareza aparece en su color dentro de la linea de
etiquetas. No aplicar verde de coincidencia a todos los ingresos.

## Acceso rapido Server Hop

Unica pieza flotante. El interruptor `Acceso rapido flotante` de la seccion
Server Hop la muestra u oculta; la preferencia se guarda como `quick` en
`server_hop_button_ui.json`.

Tarjeta grafito con borde de 1 px y esquinas de 14 px. Sin degradado, brillo
ni contornos duplicados del texto.

- Expandido 320 x 116. Fila superior de 44 px: AUTO (60 px), boton rojo
  Server Hop (flexible, GothamBold 18) y plegado (32 px). Debajo, el estado
  en dos lineas de 11 px como maximo y, al pie, la firma By Mistake en champan.
- Plegado 232 x 66. La misma fila con 34 px de alto (AUTO 52, plegado 28,
  texto 14) y la firma debajo. El estado se oculta.
- AUTO muestra `AUTO / ON` en verde con texto oscuro o `AUTO / OFF` neutro.
- El plegado usa un chevron geometrico: arriba para plegar, abajo para abrir.
- Mientras hay un salto en curso el boton rojo baja al 50 % de opacidad.
- Asa de tamano en la esquina inferior derecha: tres trazos diagonales de
  1.5 px dentro del borde redondeado, gris al 60 % y champan al pasar o
  arrastrar (120 ms, Quad Out). Escala la tarjeta entera (UIScale) entre
  0.75 y 1.75, sin pasar del ancho/alto de la pantalla, y fija el borde
  izquierdo. Las medidas de arriba son a escala 1.
- Los mensajes de estado empiezan con mayuscula, dicen que pasa y que hacer
  ("Salto sin confirmar. Pulsa Server Hop para reintentar."). No usan glifos
  como ✓ o ✗ que algunas fuentes no tienen.

## Mistake Hub

Una sola ventana reune todas las opciones; las unicas piezas flotantes son el
acceso rapido de Server Hop y el propio hub minimizado (boton `M`). Estructura inspirada en Chilli Hub (cabecera,
pestanas laterales, secciones con interruptores), con la paleta propia.

- 760 x 560, esquinas de 14 px. Cabecera de 56 px, barra lateral de 172 px y
  paginas de 548 x 472 con margen de 20 px.
- Cabecera: logo cuadrado de 32 px en champan con la `M`, titulo
  `Mistake Hub` (17 px) y subtitulo `Steal An Egg` (11 px); a la derecha AUTO
  (punto + `AUTO ON/OFF`, 100 px) y minimizar (32 px, un menos). La cabecera
  arrastra el hub. Sin linea bajo la cabecera: el cambio de tono de la barra
  lateral y el margen de 16 px separan.
- Minimizado: el hub se encoge hasta un boton de 56 x 56, esquinas de 14 px,
  con el logo `M` centrado y un punto de 10 px en su esquina superior derecha
  (verde con AUTO activo, gris apagado; borde del color del fondo). Sin
  teclado (movil, iPad) no hay Alt izquierdo: este boton es la forma de
  volver. Tocarlo abre el hub en la misma seccion; arrastrarlo lo mueve (un
  recorrido de mas de 10 px es arrastre, no toque). Pasar el raton o pulsar
  ilumina su borde en champan. Las tarjetas y modelos se liberan mientras
  esta minimizado.
- Barra lateral: superficie `Entrada` (#10141A), mas pesada que el contenido,
  sin borde lateral; solo su esquina inferior izquierda sigue la del hub.
  Entradas de 40 px separadas por 6 (Egg Finder, Filtros, Calculadora, Server
  Hop, Ajustes), 13 px SemiBold. Una sola seleccion `ActiveTab` (fondo de
  superficie con la barra champan de 3 x 20) se desliza a la pestana activa;
  su texto pasa a blanco y el resto queda secundario. Pasar el puntero da
  fondo al 40 % y pulsar al 70 %, al instante. Filtros muestra un punto
  champan con cambios sin aplicar. Al pie, el estado de AUTO (verde si esta
  activo) con su modo (11 px) y la firma `By Mistake` en champan.
- Egg Finder: tarjeta de estado (punto, titulo de 15 px, linea explicativa y
  reloj a la derecha), fila `Filtros` con el resumen guardado y `Editar
  filtros`, barra `Todos N` / `Cumplen N` / `Ver:` / `Orden:` en cuatro
  columnas de 131 y la lista virtualizada debajo. AUTO, `Todos`/`Cumplen`,
  `Ver:` y `Orden:` se repintan en la misma pulsacion.
- Tarjetas de 100 px separadas por 8 px, imagen de 76 px. Filas propias para
  nombre, ingreso (20 px), escala/peso y etiquetas (rareza en su color,
  mutaciones, zona). Insignia a la derecha: `Cumple` en verde o el motivo
  corto (Rareza baja, Otra zona, Otro nombre, Sin mutacion, Ingreso bajo),
  siempre opaca. Toda la tarjeta abre el detalle; un chevron lo indica.
- Filtros: titulo y ayuda; fila de tres columnas de 177 (Rareza minima,
  Ingreso minimo /s, Mutacion), fila de dos de 270 (Zonas, Nombre contiene) y
  el mensaje junto a `Aplicar filtros`. Debajo, separada por el margen y su
  titulo, la seccion Presets: nombre, `Guardar actuales` y la lista
  (Cargar / Borrar).
- Calculadora: especie y peso arriba; a la izquierda las mutaciones en dos
  columnas con su bono (medido una vez por especie); a la derecha la tarjeta
  de resultado (ingreso en
  champan de 24 px, exacto, por minuto/hora/dia, multiplicador, tamano, sin
  mutaciones y una nota).
- Server Hop: tarjeta `Estado` con el mismo texto que la tarjeta flotante y
  el boton rojo `Server Hop` (172 x 44) a la derecha; interruptores AUTO y
  `Acceso rapido flotante`; seccion Cuenta y Best Ping con estado a la
  derecha del titulo, campo oculto, ayudas y tres botones (Guardar y usar
  AUTO en champan, Solo esta sesion, Borrar cookie en rojo suave).
- Ajustes: interruptores Notificacion y Sonido (cambian en su sitio, sin
  reconstruir la pagina), `Probar alerta`, y la seccion Interfaz con los
  atajos (etiqueta 12, valor 13) y `Restablecer tamano y posicion`.
- Interruptor: fila de 52 px con titulo y detalle; pista de 44 x 24 a la
  derecha, verde con perilla oscura si esta activo, entrada con perilla gris
  si no. Toda la fila lo cambia.
- Hojas modales (rareza, mutacion, zonas, especie, detalle, historial) sobre
  un velo que bloquea el hub; ocupan el area de paginas (548 de ancho, 480 de
  alto como maximo). Tocar el velo o la X cierra la hoja.
- Detalle: nombre, rareza y zona, veredicto, filas de 36 px etiqueta (12) /
  valor (14 SemiBold) sin lineas entre ellas (ingreso, exacto, minimo, tamano
  y peso, mutaciones, zona) y las acciones en una fila: `Mejores de los
  ultimos ciclos` (solo el mejor del ciclo) y `Calcular con otras
  mutaciones`.
- Historial de mejores (`Mejores de los ultimos ciclos`): abierto desde el
  detalle muestra `Detalle` con un chevron a la izquierda de la X, que
  vuelve al detalle. Hasta 6 filas de 58 px (este ciclo con borde champan,
  luego los 5 ultimos ciclos terminados). Cada fila: antiguedad, nombre,
  rareza en su color, zona y mutaciones; a la derecha el ingreso, en verde si
  llega al minimo guardado, con "llega al minimo" o "bajo el minimo". Al pie,
  el minimo guardado. Solo informativo.
- La misma asa de tres trazos del acceso rapido, en la esquina inferior
  derecha, escala el hub entre 0.6 y 1.5 con la esquina superior izquierda
  fija. La pantalla manda: si no cabe, se reduce aunque baje de 0.6. Las
  hojas modales la cubren. Seccion, plegado, tamano (`scale`), posicion y
  preferencias se guardan en `chilli_egg_panel_ui.json`.

## Interaccion

La firma `By Mistake` vive al pie de la tarjeta de acceso rapido y de la
barra lateral del hub. No hay etiqueta flotante en la pantalla (retirada el
2026-10-11) ni lanzadores flotantes del panel o de la cuenta (retirados con
el hub, 2026-10-14).

AUTO apagado es neutro; AUTO encendido usa verde suave y texto oscuro.
Las acciones principales usan champan con texto oscuro. No confundir apagado
con error. Chevrones, minimizar, cerrar y marcas de seleccion usan geometria
nativa de Roblox.

El foco por seleccion de teclado es inmediato. La limpieza de sesion sigue
retirando panel, conexiones, resortes y bucles.

## Tipografia

Gotham en tres pesos (Bold, SemiBold via `FontFace`, Medium). Roblox no tiene
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
| Insignia, firma de la tarjeta | 10 | Bold |

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
| Minimizar / abrir el hub, el logo y su posicion en pantalla | 240 ms | Quint Out |
| Hoja: entra desde su origen, escala 0.9 a 1, velo hasta 35 % | 220 ms | Quint Out |
| Hoja: sale por el mismo camino | 160 ms | Quint In |
| Tarjeta flotante: plegar / desplegar | 220 ms | Quint Out |
| Asa de tamano: color al pasar o arrastrar | 120 ms | Quad Out |

- Pulsar: el borde se ilumina y AutoButtonColor oscurece el fondo al
  instante (`GuiState` cubre raton, toque y mando); el cambio se confirma al
  soltar. `UIScale` escala desde el `AnchorPoint` y empuja a los hermanos de
  un `UIListLayout`, asi que no se usa para la pulsacion; solo en hojas,
  que estan centradas.
- Origen de las hojas: rareza, mutacion, zonas y especie salen de su boton;
  el detalle, de su tarjeta; el historial abierto desde el detalle entra por
  la derecha y `Detalle` vuelve por la izquierda. Sin origen, la hoja sube
  12 px. La hoja que sale ya no bloquea el hub (`Interactable`).
- Minimizar encoge el hub hacia su logo con la esquina superior izquierda
  fija; titulo, AUTO y minimizar se van al empezar, el logo se centra (16 a
  12 px) en el mismo tween y la barra lateral y las paginas se ocultan al
  terminar. Abrir es el camino inverso y, si el hub entero no cabe donde
  estaba el boton, se desliza hasta caber en el mismo tiempo.
- Alt izquierdo sigue el mismo camino: con el hub abierto lo encoge hasta el
  boton y lo oculta al terminar; oculto o minimizado, lo muestra como boton y
  lo expande igual que al tocarlo. Otro Alt a mitad de camino lo invierte. La tarjeta flotante muestra su estado solo cuando termina de
  abrirse.
- Arrastre del hub y de la tarjeta flotante: 1:1 desde el punto de agarre.
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
