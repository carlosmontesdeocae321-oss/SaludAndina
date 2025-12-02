-- Migration: add email column to doctor_profiles
ALTER TABLE `doctor_profiles`
  ADD COLUMN `email` VARCHAR(255) DEFAULT NULL AFTER `telefono`;
