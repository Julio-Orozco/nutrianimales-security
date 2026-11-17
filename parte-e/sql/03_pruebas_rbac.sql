-- E03: pruebas reales del motor, dentro de una transacción que se revierte.
-- SET LOCAL ROLE prueba autorización; NO demuestra login ni contraseña de la cuenta.
\set ON_ERROR_STOP on
\pset pager off
\echo 'E03 | PRUEBAS DE AUTORIZACION | si hay un ERROR no controlado, NO declarar aprobado'
BEGIN;
SET LOCAL ROLE gerente_db;
SELECT session_user AS operador, current_user AS rol_evaluado;
SELECT count(*) AS grupos_en_reporte_ventas FROM public.reporte_ventas;
DO $$
BEGIN
 BEGIN
  PERFORM count(*) FROM public.auditoria_datos;
  RAISE EXCEPTION 'FALLO: gerente_db puede leer auditoria_datos';
 EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'PASS | gerente sin acceso a auditoria: %',SQLERRM;
 END;
END $$;
RESET ROLE;
SET LOCAL ROLE ti_db;
SELECT current_user AS rol_evaluado, count(*) AS registros_auditables FROM public.auditoria_datos;
-- INSERT controlado: NO se marca como backup ok, y ROLLBACK elimina esta fila.
INSERT INTO public.backups(estado,ruta)
VALUES ('prueba_rbac_no_respaldo','E03:transaccion_revertida') RETURNING id,estado;
DO $$
BEGIN
 BEGIN
  DELETE FROM public.auditoria_datos WHERE false;
  RAISE EXCEPTION 'FALLO: ti_db tiene permiso DELETE sobre auditoria';
 EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'PASS | TI no borra auditoria: %',SQLERRM;
 END;
END $$;
RESET ROLE;
SET LOCAL ROLE auditor_db;
SELECT current_user AS rol_evaluado, count(*) AS registros FROM public.auditoria_datos;
DO $$
BEGIN
 BEGIN
  DELETE FROM public.auditoria_datos WHERE false;
  RAISE EXCEPTION 'FALLO: auditor_db tiene permiso DELETE';
 EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'PASS | auditor de solo lectura: %',SQLERRM;
 END;
END $$;
RESET ROLE;
SET LOCAL ROLE agente_ia;
SELECT current_user AS rol_evaluado, count(*) AS clientes_visibles FROM public.clientes;
DO $$
BEGIN
 BEGIN
  INSERT INTO public.clientes(nombre,tipo,correo,segmento)
  SELECT 'RBAC_E','prueba','sin-envio@example.invalid','RBAC_E' WHERE false;
  RAISE EXCEPTION 'FALLO: agente_ia tiene permiso INSERT';
 EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'PASS | agente_ia sin INSERT: %',SQLERRM;
 END;
END $$;
RESET ROLE;
ROLLBACK;
\echo 'FIN E03 | si llegaron hasta aqui sin ERROR, las pruebas de autorizacion terminaron. La fila de backup fue revertida; la secuencia puede haber avanzado.'
