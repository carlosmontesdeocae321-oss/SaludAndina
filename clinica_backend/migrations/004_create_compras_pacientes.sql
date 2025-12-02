-- 004_create_compras_pacientes.sql
-- Crea la tabla compras_pacientes usada por comprasPacientesModelo.js
CREATE TABLE IF NOT EXISTS `compras_pacientes` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `clinica_id` INT NOT NULL,
  `fecha_compra` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `monto` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (`id`),
  INDEX `idx_compras_pacientes_clinica_id` (`clinica_id`),
  CONSTRAINT `fk_compras_pacientes_clinica`
    FOREIGN KEY (`clinica_id`) REFERENCES `clinicas`(`id`) ON DELETE CASCADE ON UPDATE CASCADE
);
