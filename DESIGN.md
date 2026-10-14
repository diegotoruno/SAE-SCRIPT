# Estilo del Egg Finder

El panel y el boton Server Hop son herramientas de consulta dentro de Roblox.
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

## Boton Server Hop

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

## Panel

- 540 x 700, esquinas de 14 px, margen de 22 px y contenido de 496 px.
- Cabecera: titulo de 22 px y subtitulo de 11 px; a la derecha Opciones,
  AUTO (punto + `AUTO ON/OFF`) y minimizar.
- Tarjeta de estado: punto de color, titulo de 15 px, una linea explicativa
  y reloj a la derecha con su propia etiqueta (Renovacion en / Huevos /
  Ciclo).
- Seccion Filtros con resumen de los filtros guardados y boton
  Ocultar/Mostrar. Cada control tiene su etiqueta encima:
  - Fila 1, tres columnas de 160: Rareza minima, Ingreso minimo /s, Mutacion.
  - Fila 2, dos columnas de 244: Zonas (Todas, nombre de la zona o "N zonas")
    y Nombre contiene.
  - Fila 3: mensaje de dos lineas (guardado, pendiente, aplicado o error) y
    Aplicar filtros.
- Barra de lista: `Todos N` y `Cumplen N` como segmento, `Ver:` y `Orden:`.
- Tarjetas de 100 px separadas por 8 px, imagen de 76 px. Filas propias para
  nombre, ingreso (20 px), escala/peso y etiquetas (rareza en su color,
  mutaciones, zona). Insignia a la derecha: `Cumple` en verde o el motivo
  corto (Rareza baja, Otra zona, Otro nombre, Sin mutacion, Ingreso bajo).
  Toda la tarjeta abre el detalle; un chevron lo indica.
- Hojas modales (rareza, mutacion, zonas, detalle y opciones) sobre un velo
  que bloquea el panel; tocar el velo o la X cierra la hoja.
- Detalle: nombre, rareza y zona, veredicto, y filas etiqueta/valor para
  ingreso, ingreso exacto, minimo guardado, tamano y peso, mutaciones y zona.
  El mejor huevo del ciclo agrega el boton "Ver mejores de los ultimos ciclos".
- Historial de mejores: hasta 6 filas de 58 px (este ciclo con borde champan,
  luego los 5 ultimos ciclos terminados). Cada fila: antiguedad, nombre,
  rareza en su color, zona y mutaciones; a la derecha el ingreso, en verde si
  llega al minimo guardado, con "llega al minimo" o "bajo el minimo". Al pie,
  el minimo guardado. Solo informativo.
- Opciones: secciones Presets, Alertas y Servidores con estados explicitos
  ("Notificacion: activada").
- La misma asa de tres trazos del boton Server Hop, en la esquina inferior
  derecha, escala el panel entre 0.6 y 1.5 con la esquina superior izquierda
  fija. La pantalla manda: si no cabe, se reduce aunque baje de 0.6. Las
  hojas modales la cubren. El tamano elegido (`scale`), la posicion y las
  preferencias se guardan en `chilli_egg_panel_ui.json`.

## Interaccion

La firma `By Mistake` vive solo al pie de la tarjeta del boton Server Hop.
No hay etiqueta flotante en la pantalla (retirada el 2026-10-11).

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
