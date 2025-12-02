-- 005_create_compras_doctores.sql
-- Crea la tabla compras_doctores usada por vinculacion de doctores
CREATE TABLE IF NOT EXISTS `compras_doctores` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `clinica_id` INT NOT NULL,
  `usuario_id` INT NOT NULL,
  `fecha_compra` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `monto` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (`id`),
  INDEX `idx_compras_doctores_clinica_id` (`clinica_id`),
  INDEX `idx_compras_doctores_usuario_id` (`usuario_id`),
  CONSTRAINT `fk_compras_doctores_clinica` FOREIGN KEY (`clinica_id`) REFERENCES `clinicas`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_compras_doctores_usuario` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios`(`id`) ON DELETE CASCADE ON UPDATE CASCADE
);
