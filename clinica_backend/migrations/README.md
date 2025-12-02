Instrucciones para migraciones (en español)

Este directorio contiene archivos SQL de migración que cambian el esquema de la base de datos.

Archivos actuales:
- 001_add_doctor_id_to_pacientes.sql  -> Añade la columna `doctor_id` (si no existe).
- 002_make_clinica_id_nullable.sql    -> Hace `clinica_id` NULLABLE (permite pacientes sin clínica).

Uso recomendado (desde la raíz del proyecto):
1) Asegúrate de que `clinica_backend/config/db.js` contiene las credenciales correctas para tu MySQL local.
   - En este repositorio `db.js` usa: host `localhost`, user `root`, password `ivar`, database `clinica_db`.

2) Ejecuta el script de migraciones con Node.js:

   Abrir PowerShell y ejecutar:

   ```powershell
   cd "c:\Users\DarthRoberth\clinica_app\clinica_backend"
   node run_migrations.js
   ```

   - El script leerá todos los `.sql` en este directorio `migrations/` y los ejecutará en orden alfabético.
   - Si alguna migración falla, el script se detendrá y mostrará el error.

3) Verifica el esquema si quieres:

   ```powershell
   mysql -u root -p -D clinica_db -e "SELECT COLUMN_NAME, IS_NULLABLE, COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='pacientes';"
   ```

Notas de seguridad:
- Este script usa las credenciales en `config/db.js`. No subas `config/db.js` a repositorios públicos con credenciales reales.
- Haz backup de la base de datos antes de ejecutar migraciones en producción.

Si necesitas que ejecute algo por ti, puedo generar un comando exacto con las credenciales que ya tienes en `config/db.js` (pero no puedo ejecutarlo por ti desde aquí).