#!/bin/sh
cd clinica_backend || exit 1
npm install --production
echo "Ejecutando migraciones (si las hay)..."
node run_migrations.js || true
echo "Iniciando servidor..."
npm start
