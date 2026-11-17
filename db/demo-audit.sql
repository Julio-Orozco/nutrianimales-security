\set ON_ERROR_STOP on
BEGIN;
INSERT INTO clientes (nombre, tipo, correo, segmento)
VALUES ('Prueba auditoria controlada', 'prueba',
        'auditoria-delete@example.invalid', 'antes')
RETURNING id \gset

UPDATE clientes SET segmento = 'despues' WHERE id = :id;
DELETE FROM clientes WHERE id = :id;

SELECT tabla, operacion, usuario, fecha, fila_id,
       valor_antes->>'nombre' AS nombre_anterior,
       valor_antes->>'segmento' AS segmento_anterior,
       valor_nuevo->>'segmento' AS segmento_nuevo,
       (valor_nuevo IS NULL) AS valor_nuevo_es_null
FROM auditoria_datos
WHERE fila_id = :id
ORDER BY id;
COMMIT;
