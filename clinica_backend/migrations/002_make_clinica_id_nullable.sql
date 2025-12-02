-- Migration 002: Permitir NULL en la columna `clinica_id` de la tabla `pacientes`
-- Esto permite que pacientes pertenecientes sólo a un doctor (doctor_id) no fallen por falta de clinica_id.

ALTER TABLE pacientes MODIFY clinica_id INT NULL;

-- FIN
