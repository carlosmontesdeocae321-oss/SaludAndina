-- 006_create_compras_pacientes_individual.sql
-- Tabla para registrar compras de pacientes por doctores individuales
CREATE TABLE IF NOT EXISTS `compras_pacientes_individual` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `doctor_id` INT NOT NULL,
  `fecha_compra` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `monto` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (`id`),
  INDEX `idx_compras_pacientes_individual_doctor` (`doctor_id`),
  CONSTRAINT `fk_compras_pacientes_individual_doctor` FOREIGN KEY (`doctor_id`) REFERENCES `usuarios`(`id`) ON DELETE CASCADE ON UPDATE CASCADE
);
