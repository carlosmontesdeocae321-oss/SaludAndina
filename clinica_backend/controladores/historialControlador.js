const historialModelo = require('../modelos/historialModelo');

async function listarHistorial(req, res) {
    try {
        if (req.clinica_id === null && req.user && req.user.rol === 'doctor') {
            const registros = await historialModelo.obtenerHistorialPorDoctor(req.user.id);
            return res.json(registros);
        }
        const registros = await historialModelo.obtenerHistorialPorClinica(req.clinica_id);
        res.json(registros);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function listarHistorialPorPaciente(req, res) {
    try {
        const pacienteId = req.params.id;
        const registros = await historialModelo.obtenerHistorialPorPaciente(pacienteId);
        res.json(registros);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function verHistorial(req, res) {
    try {
        const registro = await historialModelo.obtenerHistorialPorId(req.params.id, req.clinica_id);
        if (!registro) return res.status(404).json({ message: 'Registro no encontrado' });
        if (req.clinica_id === null && req.user && req.user.rol === 'doctor') {
            if (registro.doctor_id && registro.doctor_id !== req.user.id) {
                return res.status(403).json({ message: 'Acceso no permitido' });
            }
        }
        res.json(registro);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function crearHistorial(req, res) {
    try {
        // Depuración: imprimir body y files
        console.log('🔔 crearHistorial - req.body:', req.body);
        console.log('🔔 crearHistorial - files:', (req.files || []).length);

        // Si se subieron archivos con multer, subir a Cloudinary o Firebase y construir array de URLs
        const files = req.files || [];
        const imagenes = [];
        const useFirebase = process.env.USE_FIREBASE_STORAGE === 'true';
        const { uploadFile: uploadToCloudinary } = require('../servicios/cloudinaryService');
        const { uploadFile: uploadToFirebase } = require('../servicios/firebaseService');
        for (const f of files) {
            try {
                if (useFirebase) {
                    const dest = `clinica/historial/${Date.now()}_${f.originalname}`;
                    const r = await uploadToFirebase(f.path, dest);
                    imagenes.push(r.publicUrl);
                } else {
                    const r = await uploadToCloudinary(f.path, { folder: 'clinica/historial' });
                    imagenes.push(r.secure_url);
                }
            } catch (e) {
                console.error('Error subiendo imagen historial', e);
            }
        }

        // req.body contiene los campos de texto (multer los conserva)
        const payload = Object.assign({}, req.body);
        // Normalizar nombres: si cliente usó 'motivo' o 'motivo_consulta'
        if (payload.motivo && !payload.motivo_consulta) payload.motivo_consulta = payload.motivo;
        // Asegurar campos numéricos/strings estén presentes; imagenes como array
        payload.imagenes = imagenes;

        console.log('🔔 crearHistorial - payload final para BD:', payload);

        const nuevoId = await historialModelo.crearHistorial(payload);
        console.log('🔔 crearHistorial - insertId:', nuevoId);
        res.status(201).json({ id: nuevoId });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function actualizarHistorial(req, res) {
    try {
        console.log('🔔 actualizarHistorial - req.body:', req.body);
        console.log('🔔 actualizarHistorial - files:', (req.files || []).length);

        const files = req.files || [];
        const imagenesNuevas = [];
        const useFirebase2 = process.env.USE_FIREBASE_STORAGE === 'true';
        const { uploadFile: uploadToCloudinary2 } = require('../servicios/cloudinaryService');
        const { uploadFile: uploadToFirebase2 } = require('../servicios/firebaseService');
        for (const f of files) {
            try {
                if (useFirebase2) {
                    const dest = `clinica/historial/${Date.now()}_${f.originalname}`;
                    const r = await uploadToFirebase2(f.path, dest);
                    imagenesNuevas.push(r.publicUrl);
                } else {
                    const r = await uploadToCloudinary2(f.path, { folder: 'clinica/historial' });
                    imagenesNuevas.push(r.secure_url);
                }
            } catch (e) {
                console.error('Error subiendo imagen historial', e);
            }
        }

        const body = Object.assign({}, req.body);
        if (body.motivo && !body.motivo_consulta) body.motivo_consulta = body.motivo;

        // Si el cliente envió imagenes existentes en body.imagenes (JSON), concatenarlas
        let imagenesExistentes = [];
        if (body.imagenes) {
            try {
                imagenesExistentes = typeof body.imagenes === 'string' ? JSON.parse(body.imagenes) : body.imagenes;
            } catch (e) {
                imagenesExistentes = [];
            }
        }
        body.imagenes = [...imagenesExistentes, ...imagenesNuevas];

        console.log('🔔 actualizarHistorial - payload final:', body);

        const doctor_id = req.user && req.user.rol === 'doctor' ? req.user.id : null;
        const filas = await historialModelo.actualizarHistorial(req.params.id, body, req.clinica_id, doctor_id);
        if (filas === 0) return res.status(404).json({ message: 'Registro no encontrado o sin permiso' });
        res.json({ message: 'Registro actualizado' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function eliminarHistorial(req, res) {
    try {
        const doctor_id = req.user && req.user.rol === 'doctor' ? req.user.id : null;
        const filas = await historialModelo.eliminarHistorial(req.params.id, req.clinica_id, doctor_id);
        if (filas === 0) return res.status(404).json({ message: 'Registro no encontrado o sin permiso' });
        res.json({ message: 'Registro eliminado' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

module.exports = {
    listarHistorial,
    listarHistorialPorPaciente,
    verHistorial,
    crearHistorial,
    actualizarHistorial,
    eliminarHistorial
};
