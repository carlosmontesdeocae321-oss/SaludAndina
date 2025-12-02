-- Migration 003: Permitir NULL en la columna `clinica_id` de la tabla `citas`
-- Esto permite que citas creadas por doctores individuales no necesiten `clinica_id`.

ALTER TABLE citas MODIFY clinica_id INT NULL;

-- FIN
