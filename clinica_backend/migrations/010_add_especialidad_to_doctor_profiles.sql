-- Migration: add especialidad column to doctor_profiles
ALTER TABLE `doctor_profiles`
  ADD COLUMN `especialidad` VARCHAR(200) DEFAULT NULL AFTER `nombre`;
