-- Migration: create doctor_profiles table
-- Added by migration to store extended doctor profile info (isolated from usuarios)
CREATE TABLE IF NOT EXISTS `doctor_profiles` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL UNIQUE,
  `nombre` VARCHAR(200) DEFAULT NULL,
  `apellido` VARCHAR(200) DEFAULT NULL,
  `direccion` TEXT DEFAULT NULL,
  `telefono` VARCHAR(50) DEFAULT NULL,
  `bio` TEXT DEFAULT NULL,
  `avatar_url` VARCHAR(1024) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_doctor_profiles_user` FOREIGN KEY (`user_id`) REFERENCES `usuarios`(`id`) ON DELETE CASCADE
);
