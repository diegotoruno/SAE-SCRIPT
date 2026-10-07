# Estilo del Egg Finder

El panel es una herramienta de consulta y configuracion dentro de Roblox. Su
prioridad es leer el estado de la busqueda y los ingresos sin competir con el
mapa del juego. La refinacion premium conserva controles, contenido, datos y
reglas del detector; se concentra en jerarquia, espacio y respuesta visual.

## Superficies y color

Los tokens de `egg_filter_panel.luau` son la fuente ejecutable del estilo.

| Rol | Color | Uso |
| --- | --- | --- |
| Fondo | `#14181E` | Panel y selectores flotantes |
| Superficie | `#1E242C` | Controles y tarjetas de spawns |
| Entrada | `#10141A` | Campos de nombre y minimo |
| Borde | `#38414D` | Separadores y limites discretos |
| Texto | `#EFF3F7` | Titulos, nombres e ingresos |
| Secundario | `#AAB7C5` | Metadatos, etiquetas y ayuda |
| Acento | `#E0C595` | Aplicar filtros, minimo y foco de entrada |
| Exito | `#93D7BF` | AUTO activo, coincidencias y seleccion |
| Informacion | `#AECEE5` | Reloj y estado activo |
| Error | `#F0989F` | Minimo invalido y fallo al guardar |

El color de rareza viene del juego. Se aclara lo necesario para alcanzar
contraste 4.5:1 sobre las superficies de tarjeta, seleccion y coincidencia.
Los nombres son blancos; la rareza tiene su propia etiqueta de color.
No aplicar verde de coincidencia a todos los ingresos.

## Composicion y tipografia

- Panel de 540 x 700 con esquinas de 14 px y borde de 1 px.
- Cabecera sobria, sin degradado: titulo de 24 px y subtitulo de 11 px.
- Gotham Medium/Bold sin contorno. Botones de 12 px, nombres de 15 px,
  ingresos de 20 px y metadatos de 10-11 px.
- Estado y reloj separados de los filtros; los filtros usan espacio, sin
  otra tarjeta envolvente. El aviso de guardado/error tiene una fila propia.
- Tarjetas de 116 px, separadas por 8 px, con imagen oficial de 88 px.
  Nombre, ingreso, escala/peso y rareza/mutaciones/zona tienen filas distintas.
- Catalogo de especies separado del mapa. Ambos usan el mismo vocabulario
  de seleccion, tipografia y superficies.
- El escalado existente mantiene el panel dentro del viewport; posicion y
  preferencias conservan el archivo de persistencia existente.

## Interaccion

AUTO apagado es neutro; AUTO encendido usa verde suave y texto oscuro.
Aplicar filtros usa champan con texto oscuro. No confundir apagado con error.
Chevron, minimizar y marcas de seleccion usan geometria nativa de Roblox.

El borde responde al puntero en 120 ms con Quad Out, cancelando el tween
anterior. El foco por seleccion de teclado es inmediato. La pulsacion conserva
la respuesta nativa AutoButtonColor. No animar reloj, ingresos ni reconstruir
listas para producir efectos decorativos. Destruir cada objeto cancela su tween;
la limpieza de sesion sigue retirando panel, conexiones y bucles.

La fuente de spawns, el ingreso exacto, los filtros guardados y el flujo
esperar/hop/quedarse se documentan en `CONTEXT.md` y no dependen del estilo.

## Integracion con build 21

Se conservan virtualizacion, orden por rareza e ingreso, Alt izquierdo, presets, alertas, detalle exacto y parser de sufijos k/m/b/t/q. Las constantes de tarjeta tambien gobiernan canvas y ventana visible; los recursos visuales siguen cargando con reintentos.
