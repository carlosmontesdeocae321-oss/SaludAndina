-- Migration: add notas_html_full to historial
ALTER TABLE `historial`
ADD COLUMN `notas_html_full` TEXT NULL AFTER `notas_html`;
