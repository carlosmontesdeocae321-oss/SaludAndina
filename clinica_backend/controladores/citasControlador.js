const citasModelo = require('../modelos/citasModelo');

async function listarCitas(req, res) {
    try {
        let citas;
        if (req.clinica_id === null && req.user && req.user.rol === 'doctor') {
            citas = await citasModelo.obtenerCitasPorDoctor(req.user.id);
        } else {
            citas = await citasModelo.obtenerCitasPorClinica(req.clinica_id);
        }
        res.json(citas);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function verCita(req, res) {
    try {
        const cita = await citasModelo.obtenerCitaPorId(req.params.id, req.clinica_id);
        if (!cita) return res.status(404).json({ message: 'Cita no encontrada' });
        // Si es doctor individual, verificar que el paciente pertenece a ese doctor
        if (req.clinica_id === null && req.user && req.user.rol === 'doctor') {
            // ya que obtenerCitaPorId devuelve la cita sin filtrar, comprobamos paciente.doctor_id
            const pacienteDoctorId = cita && cita.doctor_id ? cita.doctor_id : null;
            if (pacienteDoctorId && pacienteDoctorId !== req.user.id) {
                return res.status(403).json({ message: 'Acceso no permitido' });
            }
        }
        res.json(cita);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function crearCita(req, res) {
    try {
        // Si es doctor individual, no enviar clinica_id (dejar que el modelo inserte sin él)
        const data = { ...req.body };
        if (req.clinica_id) data.clinica_id = req.clinica_id;
        const nuevoId = await citasModelo.crearCita(data);
        res.status(201).json({ id: nuevoId });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function actualizarCita(req, res) {
    try {
        const doctor_id = req.user && req.user.rol === 'doctor' ? req.user.id : null;
        const filas = await citasModelo.actualizarCita(req.params.id, req.body, req.clinica_id, doctor_id);
        if (filas === 0) return res.status(404).json({ message: 'Cita no encontrada o sin permiso' });
        res.json({ message: 'Cita actualizada' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function eliminarCita(req, res) {
    try {
        const doctor_id = req.user && req.user.rol === 'doctor' ? req.user.id : null;
        const filas = await citasModelo.eliminarCita(req.params.id, req.clinica_id, doctor_id);
        if (filas === 0) return res.status(404).json({ message: 'Cita no encontrada o sin permiso' });
        res.json({ message: 'Cita eliminada' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

module.exports = {
    listarCitas,
    verCita,
    crearCita,
    actualizarCita,
    eliminarCita
};
