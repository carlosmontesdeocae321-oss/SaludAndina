Deploy / connect quick guide (Railway)

Objetivo: que tu backend `clinica_backend` use la base MySQL de Railway y quede disponible públicamente.

Pasos resumidos (ejecuta en este orden)

1) Añadir variables en Railway (UI)
- Ve a https://railway.app y entra en tu proyecto.
- Abre el Service que corresponde a tu backend (el que ejecuta `server.js`).
- Ve a `Settings` → `Environment Variables` → `Add variable` y crea las siguientes variables EXACTAS (pega los valores):
  - `MYSQLHOST` = ballast.proxy.rlwy.net
  - `MYSQLPORT` = 22018
  - `MYSQLUSER` = root
  - `MYSQLPASSWORD` = <PEGA_LA_CONTRASEÑA>
  - `MYSQLDATABASE` = railway
  - (opcional) `MYSQL_URL` = mysql://root:<PASSWORD>@ballast.proxy.rlwy.net:22018/railway
- Guarda los cambios.

2) Reiniciar / Deploy del Service
- En la página del Service haz click en el botón morado `Deploy` (o en `...` → `Restart`).
- Espera ~30-60s a que termine.

3) Verificar logs
- Abre la pestaña `Logs` del Service.
- Busca mensajes de inicio. Si ves errores, copia la línea de error (ej. "ER_ACCESS_DENIED_ERROR" o "ECONNREFUSED") y pégala en el chat.

4) Probar la API pública
- En la página del Service busca la `Live URL` (ej. `https://<tu-backend>.up.railway.app`).
- En tu PC prueba con curl:
  curl -i https://<tu-backend>.up.railway.app/health
  (o `curl -i https://<tu-backend>.up.railway.app/` si no existe `/health`)
- Si devuelve HTTP 200 / JSON, tu backend ya está funcionando con la DB remota.

5) Actualizar la app Flutter (cliente)
- Abre `lib/services/api_services.dart` y cambia `baseUrl` a la `Live URL` del backend.
- Rebuild del APK para instalar en tu teléfono:
  flutter clean
  flutter pub get
  flutter build apk --release

Comprobación local (sin deploy)
- Si quieres probar localmente contra la DB de Railway sin deployar, desde la carpeta `clinica_backend` ejecuta (PowerShell):
  $env:MYSQLHOST='ballast.proxy.rlwy.net'; $env:MYSQLPORT='22018'; $env:MYSQLUSER='root'; $env:MYSQLPASSWORD='ziJpZoNevgkApTnMHhgKOXyFgDZsyvny'; $env:MYSQLDATABASE='railway'; node server.js
- Luego en otra ventana:
  curl http://localhost:3000/

Notas de seguridad
- NO publiques las contraseñas. Si sospechas que la contraseña fue expuesta, regenera la contraseña desde Railway y actualiza las env vars.
- No subas archivos `.env` con secretos al repo.

Si quieres, puedo:
- Preparar el commit con `.env.example` y esta guía (ya lo hice).
- Generar un pequeño script `clinica_backend/tools/check_db.js` que pruebe la conexión con las env vars (dímelo y lo creo).

Siguiente paso: dime si quieres que te guíe desde la UI de Railway (te indico click a click) o si ya añadiste las env vars y rehiciste deploy — escribe “añadí vars” o “guíame por la UI”.
