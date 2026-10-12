# Decisiones de producto e implementacion

## Vigente = la pasada mas reciente no lo contradice (2026-10-12)

Se mantiene "1/7 vigentes antes de 2/7" y los TTL 180/90 s; cambia que cuenta
como vigente. Un 1/7 que la pasada nueva debia volver a listar y no listo
gana a un 2/7 fresco solo por su TTL, y es el destino mas disputado. Muestra
real: los 13 servidores 1-2/7 ausentes con margen 100 estaban cerrados o
volvieron con 3+ jugadores; ninguno volvio en 1-2/7. Perder un 1/7 que solo
se movio cuesta una opcion; mantener uno lleno cuesta un GameFull (y con
Auto Rejoin de Chilli, ~20 s de reentrada). Sin consultas nuevas.

## Memoria valida entre servidores con 1 s de tolerancia (2026-10-12)

La observacion del ciclo debe sobrevivir al salto (flujo acordado, paso 7).
Igualdad exacta de tiempos la invalidaba en casi todos los destinos reales.
La identidad del ciclo es el periodIndex; la tolerancia de 1 s cubre el ancla
por servidor sin aceptar otro periodo ni overrides de reloj.

## Saltar servidores con modulos rotos (2026-10-12)

Peticion del usuario: que nadie con el hopper y Chilli quede atascado cuando el
juego no carga. Un modulo que fallo al cargarse no se recupera en esa sesion
del cliente, asi que esperar es inutil. Excepcion explicita a "un fallo de
datos espera": con AUTO, un servidor marcado roto inicia hop sin evidencia de
huevos y sin modificar la memoria del ciclo. Limite de 3 seguidos en 10 min
para no saltar sin fin si el juego falla en todos los servidores.

## Completitud demostrada en lugar de 10 s fijos (2026-10-12)

Reemplaza "Barrera de carga sin cambios hasta medir". Las mediciones reales
muestran que el campo se entrega en un lote atomico; esperar 10 s tras una
lectura que ya cubre las 13 zonas y no contiene huevos del periodo anterior
no agrega certeza. Se conserva la ventana de 3 s sin cambios para todos los
casos y los 10 s como respaldo cuando falta una zona, hay una zona
desconocida o sobrevive un Uid del periodo anterior. No se exige el mismo
numero de nidos por zona: los reclamos retiran registros a mitad del dia.
Rareza minima, Slot, zonas, ingreso exacto y flujo wait/hop/match no cambian.

## Barrera de carga sin cambios hasta medir (2026-10-11)

La espera minima de 10 s ocupa la mayor parte del tiempo por servidor, pero
evita saltar antes de que replique un huevo valido. No se acorta sin evidencia:
cada servidor registra settleSeconds/readySeconds para decidir con datos. Las
optimizaciones de esta fecha no cambian ninguna decision del detector ni del
hopper.

## Firma solo en el boton (2026-10-11)

La etiqueta By Mistake fija en pantalla duplicaba la firma del boton y se
percibia como un texto flotante sobre el juego. El usuario elige quitarla en
lugar de atarla al panel o hacerla mas discreta. Reemplaza "Firma visual By
Mistake" del 2026-10-09 en lo que respecta a la pantalla.

## Boton grafito con un solo rojo (2026-10-11)

Para un estilo sencillo y elegante el boton deja el rojo brillante con
degradado, brillo y contorno multiple, y adopta la paleta del panel. El rojo se
conserva solo en la accion Server Hop para que siga reconocible. Reemplaza el
layout 340x114/210x60 con texto principal a todo el ancho del boton: AUTO,
accion y plegado ahora son hermanos en una fila y no se solapan.

## Chilli fuera del bundle (2026-10-11)

El cargador integrado a veces no usaba la version mas reciente de Chilli y
acoplaba su arranque, reintentos y guardas al boton. El usuario elige eliminarlo
del repositorio en lugar de mantener un cargador propio en otro archivo: se
pierden prefetch, reintentos, el filtro `chilli_client.json` y el aplazamiento
por auto-test, y se gana que Chilli se descargue siempre con su linea original.
Reemplaza la integracion "Mantener su cargador" y la distribucion de una sola
linea de autoexec: ahora son dos lineas independientes.

## Solo zonas elegidas activan hop (2026-10-09)

El usuario reporta hop por Lava Dragon de Volcano con las ultimas tres zonas
seleccionadas y aclara que no debe saltar. Reemplaza el alcance global anterior:
solo spawns Slot de rareza minima o superior dentro de las zonas seleccionadas
pueden iniciar y guardar la busqueda del ciclo. Una observacion vigente de ese
mismo conjunto permite continuar cuando faltan en el destino. Cambiar zonas o
rareza cierra la memoria; ingreso, nombre y mutacion siguen siendo filtros de
calidad. Version2 guarda zonas y descarta evidencia global version1.

## Zona restringe candidatos; no selecciona todos sus pets (2026-10-08)

Usuario reporta checks en pets de cualquier rareza al elegir una zona. Esas
marcas representaban pertenencia a la zona, aunque row.match fuera false.
Se retiran checks/resaltado por zona de las tarjetas y el gesto que alternaba
la zona tocando un pet; el detalle reemplaza esa accion. Solo filtro se activa
al aplicar para mostrar la interseccion de TODAS las condiciones guardadas.
Los checks del catalogo de zonas permanecen. El usuario aclara que AUTO
mostraba Esperando huevos nuevos, no Objetivo encontrado: la espera acordada
sin Eternal+ no se cambia ni se interpreta como aceptar un pet inferior.

## Reemplazo de especies por zonas (2026-10-08)

Usuario quiere excluir eternals de Forest y buscar en Enchanted Forest.
Reemplazar categories por zones exactas del AreaId; lista de las 13 zonas del
catalogo oficial con checks y seleccion multiple. No limitar opciones a
spawns locales o rareza. Todas conserva la ausencia de restriccion previa;
un borrador vacio bloquea guardado/AUTO/presets. Migrar configuracion/presets
antiguos conservando los demas filtros y retirando la restriccion de especies.
La regla global original de presencia queda reemplazada por la aclaracion
2026-10-09: zona excluida no inicia busqueda; la evidencia es por rareza y zonas.

| Decision | Motivo y consecuencia |
| --- | --- |
| Explorar mas solo cuando escasea la reserva | Las primeras5 paginas reales a veces dejan1..6 opciones. Con menos16, continuar cursor hasta12 paginas/180s; stock suficiente termina a5/75s y24 nuevos detienen antes. Evita reiniciar siempre la misma muestra pobre sin acumular destinos vencidos ni recorrer indefinidamente. |
| Balance autorizado:1/7 listo, despues2/7 BestLatency | El huevo es el objetivo principal. Usuario autoriza2/7 al agotar la reserva rapida1/7 sin probar ausencia global. Hasta24 destinos; refill<16 o respaldo>=60s; TTL1=180s/2=90s y nuevo muestreo desde cabeza nativa. Evita que una busqueda larga de1/7 deje de revisar huevos. Solo DeviceCookie; grupos3..6/bridge/legacy mantienen guardas anteriores. |
| Precargar hasta ocho 1/7 con BestLatency | Click/AUTO usan reserva vigente sin HTTP, conservando orden nativo y excluyendo visitados/actual. Vencen registros, no el cursor incompleto. Cursor sanitizado por cuenta sobrevive hops durante 180s; grupos 2..6 requieren prueba nueva. Primera reserva puede tardar, ocupacion/ping al llegar no se garantizan. |
| Una distribucion comun para Delta y Potassium | Usuario solicita conservar main/chilli_hopper.luau en todas las PC y usarlo tambien en iPad. CI publica el mismo bundle en stable tras validar; cookies/filtros son locales. Un script abierto conserva su version hasta recargar. Previews o SHA de prueba no se usan como distribucion permanente. |
| Separar pausa propia, HTTP 429 y peticion pendiente | Usuario observa pausa al guardar desde Delta. La espera anterior de 35s no cubria cooldown 60s y descartaba el borrador. Prioridad a validacion, contador, un reintento 429 y borrador en memoria mientras formulario abierto. Una peticion colgada sigue bloqueada hasta terminar, sin forzar duplicados. |
| Cookie propia introducida en Delta/Potassium | Usuario quiere probar iPad como otra persona. Peticion directa al host Roblox desde cada dispositivo; el autor no recibe credenciales. No requiere su PC. |
| Guardado opcional local por cuenta y sin cifrado | Executor movil no ofrece almacen cifrado verificado. Guardar y usar AUTO informa el alcance; solo sesion no persiste al hop. Borrar elimina/sobrescribe el secreto y apaga AUTO, sin fallback. |
| Launcher fijo y segunda entrada en Opciones | Cerrar por accidente debe permitir reabrir, independientemente de plegado/arrastre del hopper. |
| Conectar Best Ping mediante proceso local | Cookie solo en PC/Roblox, fuera del cliente/bundle/Git. JSON sanitizado en workspace, sin listener de red. Configuracion explicita; error/ausencia de proceso esperan sin fallback silencioso. |
| OccupancyAsc confirma grupos menores antes de avanzar | Permite seleccionar 2..6 sin recorrer toda la lista BestLatency. Prueba ligada a exclusiones y maximo 90s; desempate siempre del orden nativo y filas con maximo 180s. |
| Instalacion local de prueba sustituida por cargador comun | Las pruebas previas usaron un bundle del workspace con autoexec respaldado. La distribucion solicitada usa main/stable mediante CI en todos los dispositivos. El proceso de PC existente debe reiniciarse despues de reiniciar Windows. |
| Ocupacion 1/7 -> 2/7 -> ... -> 6/7 entre hops | Aclaracion del usuario: la ocupacion manda antes de Best Ping. Pool de un solo grupo; al agotarse se consulta de nuevo. Antes de usar 2..6 se revisan otra vez grupos menores; caches antiguas/mezcladas invalidas. Actual y visitados recientes quedan excluidos. |
| Una muestra BestLatency no prueba agotamiento | Con paginas pendientes, agotar candidatos observados de 1/7 no autoriza avanzar a 2/7. OccupancyGroup exige evidencia de grupos menores completos para seleccionar 2..6. No interpretar maximo de paginas, cursor repetido o fallo HTTP como fin de la lista. |
| BestLatency debe venir del orden nativo | No sustituirlo por ping anunciado ascendente/descendente. V2 requiere autenticacion; el proceso privado ya conecta listas al runtime sin transmitir la cookie. |
| Solo huevos libres del mapa | El usuario excluyo bases. Usar FieldEggs/Slot, sin inventarios ni PlotState como fuente de candidatos. |
| Divine y minimo 7B/s por defecto | Requisito original; el panel permite ajustar los filtros sin alterar la precision de comparacion. |
| Sin Divine ni observacion vigente esperar; Divine insuficiente inicia hops | Una observacion en ese ciclo permite continuar aunque falte en otro servidor por robo/recogida. No inventar presencia actual ni aceptar bases/inventarios como evidencia. |
| Recordar rareza hasta empezar la noche siguiente | Mitiga huevo ausente y desconexion durante hop sin arrastrar decisiones al ciclo nuevo. Usar reloj y overrides reales. |
| Recuperar pendiente solo con prueba de llegada/reconexion | JobId diferente o nuevo ID de conexion permiten recuperacion. Reejecutar en la misma conexion no habilita otro salto de AUTO. |
| Reset durante hop repite el ciclo | Reemplaza el requisito anterior de detenerse totalmente al reset. |
| Reloj y snapshots del juego | La noche observada dura 10s en un periodo 300s; un temporizador local puede desincronizarse. |
| Espera de carga antes de decidir | La memoria de busqueda no permite hop con la primera lectura del destino. Exigir juego cargado, snapshot valido, minimo 10s desde su lectura y 3s sin cambios Slot/revision. Mantener loading si siguen llegando datos y reiniciar al renovarse o perderse. |
| Ingreso sin boosts personales | Comparar caracteristicas del egg de forma consistente entre servidores. |
| Zonas separadas de la lista Mapa | Elegir zonas es configuracion del catalogo oficial; las tarjetas del mapa deben ser spawns reales. |
| Recursos visuales replicados | Usar imagenes/modelos del juego; no hardcodear una lista de assets que se quede obsoleta. |
| Rareza minima inclusiva, opciones del catalogo ordenadas por Rank | Excluir IDs auxiliares sin especies del selector, pero aceptar candidatos del mismo Rank o superior al minimo seleccionado. Eternal acepta Divine si cumple el ingreso exacto y los demas filtros. Compartir esta regla con AUTO, cache, especies y explicaciones; no inventar una escala 0-7. |
| Tarjetas por mejor rareza primero | Usar Rank descendente del juego y desempatar por ingreso descendente; conservar Nombre A-Z como alternativa. |
| Minimo con k/m/b/t/q y numero sin sufijo por segundo | Usar el parser del juego con validacion previa y conservar el umbral numerico exacto al editar y persistir. |
| Modelos visibles y fallback a imagen | Reducir coste de render y funcionar cuando falta un modelo. |
| Integracion externa con Chilli | Mantener su cargador y evitar modificar fuentes protegidas no disponibles. |
| Fuentes modulares y bundle unico | Facilitar mantenimiento sin requerir varios archivos en el executor. |
| main para desarrollo, stable para distribucion | Un fallo en desarrollo no reemplaza el bundle aprobado. |
| Mantener URL corta anterior | main/chilli_hopper.luau carga stable para no reinstalar la linea en cada PC. |
| Releases por numero de build y SHA | Identificar artefactos y facilitar rollback sin inventar versiones semanticas. |

La referencia a un minimo 7B corresponde a ingreso por segundo, no precio de compra, dinero del jugador ni valor de venta. Mostrar este significado en cualquier control nuevo.

No asumir que Chilli realizo una accion solo porque el detector encontro match. El detector queda en el servidor y deja continuar la configuracion actual de Chilli.

## Robustez y opciones del finder

- Un teleport sin confirmar no habilita un segundo salto automatico. Conserva su estado hasta llegar o hasta un reintento manual explicito.
- Las caches no sustituyen la comprobacion fresca antes de cada teleport. Estado, mutacion base, configuracion y renovaciones invalidan los resultados pertinentes.
- Presets cargados quedan pendientes; no cambian AUTO ni los filtros efectivos por si solos. Guardan numeros exactos, sin etiquetas redondeadas.
- Las alertas son configurables; se conservan MATCH y apagado de AUTO aunque se desactiven notificacion y sonido.
- Un recurso 3D opcional no bloquea el panel. Se usa imagen y se reintenta sin atribuir acciones al codigo protegido de Chilli.
