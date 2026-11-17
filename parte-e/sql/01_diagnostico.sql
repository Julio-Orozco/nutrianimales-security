-- E01: solo lectura. No obtiene contraseñas, hashes de contraseñas ni valores JSON de clientes.
\set ON_ERROR_STOP on
\pset pager off
\echo 'E01 | DIAGNOSTICO DE LA BASE | resultado observado, no esperado'
SELECT current_database() AS base, current_user AS ejecutor, version() AS motor,
       clock_timestamp() AS instante;
-- to_regclass devuelve NULL si falta un objeto: permite diagnosticar sin modificarlo.
SELECT objeto, to_regclass('public.'||objeto) IS NOT NULL AS existe
FROM unnest(ARRAY['clientes','ventas','lotes_produccion','auditoria_datos',
 'auditoria_sentencias','backups','alertas_auditoria','pg_settings_baseline',
 'reporte_ventas','reporte_inventario','reporte_produccion']) AS t(objeto);
SELECT rolname, rolcanlogin, rolsuper, rolcreatedb, rolcreaterole
FROM pg_roles WHERE rolname IN ('rol_gerente','rol_ti','rol_auditor',
 'gerente_db','ti_db','auditor_db','agente_ia','monitor_db','n8n_app') ORDER BY rolname;
-- Membresías: distingue grupos NOLOGIN de cuentas LOGIN.
SELECT miembro.rolname AS cuenta, grupo.rolname AS grupo
FROM pg_auth_members m JOIN pg_roles miembro ON miembro.oid=m.member
JOIN pg_roles grupo ON grupo.oid=m.roleid
WHERE miembro.rolname IN ('gerente_db','ti_db','auditor_db') ORDER BY cuenta;
SELECT nspname, pg_get_userbyid(nspowner) AS propietario
FROM pg_namespace WHERE nspname IN ('public','n8n');
SELECT tgrelid::regclass AS tabla, tgname, tgenabled
FROM pg_trigger WHERE NOT tgisinternal AND tgname LIKE 'trg_auditoria_%' ORDER BY tabla;
-- Estado activo del motor; no expone hashes de contrasenas ni el contenido de .env.
SELECT name, setting FROM pg_settings WHERE name IN
 ('ssl','password_encryption','shared_preload_libraries','log_connections') ORDER BY name;
SELECT line_number, type, database, user_name, address, auth_method, error
FROM pg_hba_file_rules ORDER BY line_number;
\echo 'FIN E01: si faltan objetos/roles, detenerse y pedir correccion al DBA antes de probar E02/E03.'
