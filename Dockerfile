FROM node:18-alpine

# Trabajamos desde /usr/src/app para evitar cds extra y rutas duplicadas
WORKDIR /usr/src/app

# Copiar sólo package.json y package-lock.json dentro de un subdirectorio para cache
RUN mkdir -p clinica_backend
COPY clinica_backend/package*.json ./clinica_backend/

# Instalar dependencias dentro de la carpeta del backend
RUN cd clinica_backend && npm install --production

# Copiar el resto del código del backend
COPY clinica_backend/ ./clinica_backend/

EXPOSE 3000

# Ejecutar directamente el server desde la ruta correcta
CMD ["node", "clinica_backend/server.js"]
