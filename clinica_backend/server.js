require('dotenv').config();
const express = require('express');
const app = express();
const cors = require('cors');
const path = require('path');

// Middleware global
app.use(cors());
app.use(express.json()); // Para recibir JSON en body

// Servir archivos estáticos subidos
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
// Servir páginas públicas del backend (paneles simples)
app.use('/admin', express.static(path.join(__dirname, 'public')));

// Importar rutas
const pacientesRutas = require('./rutas/pacientes');
const citasRutas = require('./rutas/citas');
const historialRutas = require('./rutas/historial');
const usuariosRutas = require('./rutas/usuarios');
const usuariosAdicionales = require('./rutas/usuarios_adicionales');
const clinicasRutas = require('./rutas/clinicas');
const usuariosAdminRutas = require('./rutas/usuarios_admin');
const vinculacionDoctorRutas = require('./rutas/vinculacion_doctor');
const comprasPromocionesRutas = require('./rutas/compras_promociones');
const comprasPacientesRutas = require('./rutas/compras_pacientes');
const comprasDoctoresRutas = require('./rutas/compras_doctores');
const doctorProfilesRutas = require('./rutas/doctor_profiles');
const pagosRutas = require('./rutas/pagos');
const debugRutas = require('./rutas/debug');

// Montar rutas
app.use('/api/pacientes', pacientesRutas);
app.use('/api/citas', citasRutas);
app.use('/api/historial', historialRutas);
// Montar rutas adicionales de usuarios antes de las rutas con parámetro /:id
app.use('/api/usuarios', usuariosAdicionales);
app.use('/api/usuarios', usuariosRutas);
app.use('/api/clinicas', clinicasRutas);
app.use('/api/usuarios_admin', usuariosAdminRutas);
app.use('/api/vinculacion_doctor', vinculacionDoctorRutas);
app.use('/api/compras_promociones', comprasPromocionesRutas);
app.use('/api/compras_pacientes', comprasPacientesRutas);
app.use('/api/compras_doctores', comprasDoctoresRutas);
app.use('/api/doctor_profiles', doctorProfilesRutas);
app.use('/api/pagos', pagosRutas);
app.use('/api/debug', debugRutas);

// Ruta de prueba
app.get('/', (req, res) => {
    res.send('Backend de clínica funcionando ✅');
});

app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

// Iniciar servidor
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Servidor escuchando en puerto ${PORT}`);
    // Cloudinary removed: file uploads are served locally from /uploads
    console.log('File uploads served from /uploads (local storage)');
});
