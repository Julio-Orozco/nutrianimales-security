# Riesgos de NutriAnimales

Activos: datos de producción, clientes ficticios, inventario, servidor PostgreSQL, flujos n8n, respaldos y credenciales. CIA significa confidencialidad, integridad y disponibilidad.

Escala acordada con la guía: probabilidad e impacto 1–5; riesgo = P×I. 1–8 bajo, 9–14 medio, 15–19 alto, 20–25 crítico. Se corrige el ejemplo que etiquetaba todo como alto sin respetar su propia fórmula. Estas valoraciones son una estimación académica, no un análisis cuantitativo de una empresa real.

| Amenaza | CIA | P | I | Producto/nivel | Controles | Riesgo residual y respuesta |
|---|---|---:|---:|---|---|---|
| Acceso de red no autorizado a PostgreSQL | C/I | 3 | 5 | 15 alto | Sin publicación, redes internas, TLS/SCRAM, H4 | Credenciales robadas dentro de red: revisar sesión, revocar credencial y permisos |
| Cambio silencioso de fórmulas/lotes | I | 2 | 5 | 10 medio | Triggers fila/sentencia, D6, mínimo privilegio | Superusuario puede alterar auditoría; considerar envío externo inmutable |
| Exposición de tokens o contraseñas | C/I | 3 | 4 | 12 medio | .env600, .gitignore, secretos fuera de JSON, rotación | Copias/screenshots pueden filtrarlos: revocar en proveedor, no solo borrar commit |
| Degradación de autenticación/TLS | C/I | 2 | 5 | 10 medio | Baseline, H2/H5, clientes verify-full | Si TLS cae, n8n pierde el canal de monitoreo: tratar la indisponibilidad como incidente |
| Lectura masiva de clientes/ventas | C | 2 | 5 | 10 medio | Catálogo bot, SELECT acotado por reportes, D7, separación de roles | SELECT permitido puede ser abusado fuera del bot: revisar contexto y limitar vistas/datos |

Se añaden controles de disponibilidad: R1/R2/D5 y copias D3 con restauración. Cada decisión debe explicar qué reduce y qué no elimina.
