# Clinica App — Sitio promocional

Este directorio contiene una página estática mínima para mostrar la app como landing/demo.

Archivos:
- `index.html` — página principal.
- `styles.css` — estilos básicos.
- `images/` — capturas de pantalla (reemplaza `screenshot-placeholder.png` con tus pantallas).

Cómo ver localmente:

1. Abre PowerShell en la carpeta `promo`:
```
cd c:\Users\DarthRoberth\clinica_app\promo
```

2. Servir localmente (opciones):
- Usando Python 3 (simple):
```powershell
python -m http.server 8080
# luego abre http://localhost:8080
```
- Usando `dart` (si prefieres):
```powershell
dart pub global activate dhttpd
dhttpd --path . --port 8080
```

3. Reemplaza las imágenes en `images/` por capturas reales desde `assets/images/`.

Despliegue rápido:
- GitHub Pages: sube esta carpeta a un branch `gh-pages` o a la raíz y habilita Pages.
- Netlify / Vercel: arrastra la carpeta `promo` o conecta el repo y configura la carpeta de publicación.

Personalización sugerida:
- Cambia el correo de contacto en `index.html`.
- Añade capturas de pantalla reales en `images/`.
- Añade botones directos a Play Store / App Store si tienes builds.
