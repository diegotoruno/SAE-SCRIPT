# Decisiones de producto e implementacion

| Decision | Motivo y consecuencia |
| --- | --- |
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
| Catalogo separado de la lista Mapa | Elegir especies es configuracion; las tarjetas del mapa deben ser spawns reales. |
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
