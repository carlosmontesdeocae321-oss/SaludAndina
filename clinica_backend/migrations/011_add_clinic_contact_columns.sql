ALTER TABLE clinicas
  ADD COLUMN imagen_url VARCHAR(255) NULL AFTER direccion,
  ADD COLUMN telefono_contacto VARCHAR(40) NULL AFTER imagen_url;
