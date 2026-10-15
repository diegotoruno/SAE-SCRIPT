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

Una sola ventana reune todas las opciones; la unica pieza flotante es el
acceso rapido de Server Hop. Estructura inspirada en Chilli Hub (cabecera,
pestanas laterales, secciones con interruptores), con la paleta propia.

- 760 x 560, esquinas de 14 px. Cabecera de 56 px, barra lateral de 172 px y
  paginas de 548 x 472 con margen de 20 px.
- Cabecera: logo cuadrado de 32 px en champan con la `M`, titulo
  `Mistake Hub` (17 px) y subtitulo `Steal An Egg` (11 px); a la derecha AUTO
  (punto + `AUTO ON/OFF`, 100 px) y plegar (32 px: menos para plegar, mas
  para desplegar). La cabecera arrastra el hub.
- Plegado: solo la cabecera, 340 x 56, con marca, AUTO y desplegar. Las
  tarjetas y modelos se liberan mientras esta plegado.
- Barra lateral: entradas de 40 px separadas por 6 (Egg Finder, Filtros,
  Calculadora, Server Hop, Ajustes). La activa tiene fondo de superficie,
  texto blanco y una barra champan de 3 x 20 a la izquierda; las demas,
  texto secundario sin fondo. Filtros muestra un punto champan con cambios
  sin aplicar. Al pie, el estado de AUTO (verde si esta activo) con su modo y
  la firma `By Mistake` en champan.
- Egg Finder: tarjeta de estado (punto, titulo de 15 px, linea explicativa y
  reloj a la derecha), fila `Filtros` con el resumen guardado y `Editar
  filtros`, barra `Todos N` / `Cumplen N` / `Ver:` / `Orden:` en cuatro
  columnas de 131 y la lista virtualizada debajo.
- Tarjetas de 100 px separadas por 8 px, imagen de 76 px. Filas propias para
  nombre, ingreso (20 px), escala/peso y etiquetas (rareza en su color,
  mutaciones, zona). Insignia a la derecha: `Cumple` en verde o el motivo
  corto (Rareza baja, Otra zona, Otro nombre, Sin mutacion, Ingreso bajo).
  Toda la tarjeta abre el detalle; un chevron lo indica.
- Filtros: titulo y ayuda; fila de tres columnas de 177 (Rareza minima,
  Ingreso minimo /s, Mutacion), fila de dos de 270 (Zonas, Nombre contiene) y
  el mensaje junto a `Aplicar filtros`. Debajo, separada por una linea, la
  seccion Presets: nombre, `Guardar actuales` y la lista (Cargar / Borrar).
- Calculadora: especie y peso arriba; a la izquierda las mutaciones en dos
  columnas con su bono; a la derecha la tarjeta de resultado (ingreso en
  champan de 24 px, exacto, por minuto/hora/dia, multiplicador, tamano, sin
  mutaciones y una nota).
- Server Hop: tarjeta `ESTADO` con el mismo texto que la tarjeta flotante y
  el boton rojo `Server Hop` (172 x 44) a la derecha; interruptores AUTO y
  `Acceso rapido flotante`; seccion Cuenta y Best Ping con estado a la
  derecha del titulo, campo oculto, ayudas y tres botones (Guardar y usar
  AUTO en champan, Solo esta sesion, Borrar cookie en rojo suave).
- Ajustes: interruptores Notificacion y Sonido, `Probar alerta`, y la
  seccion Interfaz con los atajos y `Restablecer tamano y posicion`.
- Interruptor: fila de 52 px con titulo y detalle; pista de 44 x 24 a la
  derecha, verde con perilla oscura si esta activo, entrada con perilla gris
  si no. Toda la fila lo cambia.
- Hojas modales (rareza, mutacion, zonas, especie, detalle, historial) sobre
  un velo que bloquea el hub; ocupan el area de paginas (548 de ancho, 480 de
  alto como maximo). Tocar el velo o la X cierra la hoja.
- Detalle: nombre, rareza y zona, veredicto, filas de 36 px etiqueta/valor
  (ingreso, exacto, minimo, tamano y peso, mutaciones, zona) y las acciones
  en una fila: `Mejores de los ultimos ciclos` (solo el mejor del ciclo) y
  `Calcular con otras mutaciones`.
- Historial de mejores: hasta 6 filas de 58 px (este ciclo con borde champan,
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

El borde responde al puntero en 120 ms con Quad Out, cancelando el tween
anterior. El foco por seleccion de teclado es inmediato. La pulsacion conserva
la respuesta nativa AutoButtonColor. No animar reloj, ingresos ni reconstruir
listas para producir efectos decorativos. Destruir cada objeto cancela su tween;
la limpieza de sesion sigue retirando panel, conexiones y bucles.

La fuente de spawns, el ingreso exacto, los filtros guardados y el flujo
esperar/hop/quedarse se documentan en `CONTEXT.md` y no dependen del estilo.

## Integracion con build 21

Se conservan virtualizacion, orden por rareza e ingreso, Alt izquierdo, presets, alertas, detalle exacto y parser de sufijos k/m/b/t/q. Las constantes de tarjeta tambien gobiernan canvas y ventana visible; los recursos visuales siguen cargando con reintentos.
