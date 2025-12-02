-- Migration 001: Añadir columna doctor_id a la tabla `pacientes`
-- Nota: Reemplaza <tu_base_de_datos> o usa -D con el cliente mysql si hace falta.
-- Comando básico (MySQL):
-- ALTER TABLE pacientes ADD COLUMN doctor_id INT DEFAULT NULL;

ALTER TABLE pacientes ADD COLUMN doctor_id INT DEFAULT NULL;

-- FIN
