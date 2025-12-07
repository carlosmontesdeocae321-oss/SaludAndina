-- Migration: add notas_html column to historial
-- Run this on the MySQL database used by the app

ALTER TABLE historial
ADD COLUMN notas_html TEXT NULL;

-- Optional: you may want to update existing rows to aggregate examen_* fields into notas_html if needed.
-- Example (manual): UPDATE historial SET notas_html = CONCAT_WS('\n', examen_piel, examen_cabeza, examen_ojos) WHERE notas_html IS NULL;
