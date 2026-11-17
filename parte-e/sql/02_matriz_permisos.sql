-- E02: privilegios efectivos (incluye herencia), no solo GRANT escritos en un archivo.
\set ON_ERROR_STOP on
\pset pager off
\echo 'E02 | MATRIZ EFECTIVA DE PERMISOS'
SELECT r AS cuenta, o AS objeto,
 has_table_privilege(r,'public.'||o,'SELECT') AS puede_leer,
 has_table_privilege(r,'public.'||o,'INSERT') AS puede_insertar,
 has_table_privilege(r,'public.'||o,'UPDATE') AS puede_actualizar,
 has_table_privilege(r,'public.'||o,'DELETE') AS puede_eliminar
FROM unnest(ARRAY['gerente_db','ti_db','auditor_db','agente_ia']) AS roles(r)
CROSS JOIN unnest(ARRAY['reporte_ventas','clientes','auditoria_datos','backups','alertas_auditoria']) AS objetos(o)
ORDER BY cuenta,objeto;
SELECT r AS cuenta,
 has_database_privilege(r,current_database(),'CONNECT') AS conectar,
 has_schema_privilege(r,'public','USAGE') AS usar_public,
 has_schema_privilege(r,'public','CREATE') AS crear_public
FROM unnest(ARRAY['gerente_db','ti_db','auditor_db','agente_ia']) AS t(r);
\echo 'FIN E02: comparar con MATRIZ_RBAC.md. Una columna true no equivale automaticamente a un fallo: depende del rol y del objeto.'
