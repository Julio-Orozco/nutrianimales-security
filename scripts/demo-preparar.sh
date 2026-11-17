#!/usr/bin/env bash
# Deja la base en un punto limpio ANTES de la demostración en vivo:
#  - Reinicia pg_stat_statements: R1, D1, D6 y D7 solo alertarán por lo que se
#    ejecute durante la demo (no por pruebas anteriores).
#  - Registra la baseline de hashes de archivos (H2) con la configuración actual.
#  - Restaura la ventana de horario no laboral de R3 (23:00-06:00).
#  - Verifica que agente_ia siga en solo lectura (H3).
# No borra auditoría ni alertas: el historial se conserva.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T postgres psql -X -q -v ON_ERROR_STOP=1 -U postgres -d nutrianimales <<'SQL'
\o /dev/null
SELECT pg_stat_statements_reset();
SELECT fn_registrar_baseline_archivos();
\o
UPDATE parametros_alerta SET valor = '23' WHERE clave = 'r3_hora_inicio';
UPDATE parametros_alerta SET valor = '6'  WHERE clave = 'r3_hora_fin';
\pset footer off
\echo '--- Privilegios de agente_ia (debe ser solo lectura: escritura = [] y miembro_de = []):'
SELECT security_snapshot()->'privilegios_agente' AS agente_ia;
\echo '--- Diferencias de configuración contra la baseline (debe estar vacío):'
SELECT s.name, b.valor_esperado, s.setting FROM pg_settings s JOIN pg_settings_baseline b USING (name)
WHERE s.setting IS DISTINCT FROM b.valor_esperado;
SQL
echo "OK: base lista para la demostración."
