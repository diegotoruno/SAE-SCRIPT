# Decisiones de producto e implementacion

| Decision | Motivo y consecuencia |
| --- | --- |
| Solo huevos libres del mapa | El usuario excluyo bases. Usar FieldEggs/Slot, sin inventarios ni PlotState como fuente de candidatos. |
| Divine y minimo 7B/s por defecto | Requisito original; el panel permite ajustar los filtros sin alterar la precision de comparacion. |
| Sin Divine esperar, con Divine insuficiente hop | Flujo final expresado por el usuario. No saltar simplemente porque no haya coincidencia. |
| Reset durante hop repite el ciclo | Reemplaza el requisito anterior de detenerse totalmente al reset. |
| Reloj y snapshots del juego | La noche observada dura 10s en un periodo 300s; un temporizador local puede desincronizarse. |
| Ingreso sin boosts personales | Comparar caracteristicas del egg de forma consistente entre servidores. |
| Catalogo separado de la lista Mapa | Elegir especies es configuracion; las tarjetas del mapa deben ser spawns reales. |
| Recursos visuales replicados | Usar imagenes/modelos del juego; no hardcodear una lista de assets que se quede obsoleta. |
| Rarezas usadas por el catalogo, ordenadas por Rank | Excluir IDs auxiliares sin especies; mantener seleccion exacta y no inventar una escala 0-7. |
| Minimo con k/m/b/t/q y numero sin sufijo por segundo | Usar el parser del juego con validacion previa y conservar el umbral numerico exacto al editar y persistir. |
| Modelos visibles y fallback a imagen | Reducir coste de render y funcionar cuando falta un modelo. |
| Integracion externa con Chilli | Mantener su cargador y evitar modificar fuentes protegidas no disponibles. |
| Fuentes modulares y bundle unico | Facilitar mantenimiento sin requerir varios archivos en el executor. |
| main para desarrollo, stable para distribucion | Un fallo en desarrollo no reemplaza el bundle aprobado. |
| Mantener URL corta anterior | main/chilli_hopper.luau carga stable para no reinstalar la linea en cada PC. |
| Releases por numero de build y SHA | Identificar artefactos y facilitar rollback sin inventar versiones semanticas. |

La referencia a un minimo 7B corresponde a ingreso por segundo, no precio de compra, dinero del jugador ni valor de venta. Mostrar este significado en cualquier control nuevo.

No asumir que Chilli realizo una accion solo porque el detector encontro match. El detector queda en el servidor y deja continuar la configuracion actual de Chilli.
