const pacientesModelo = require('../modelos/pacientesModelo');

async function listarPacientes(req, res) {
    try {
        // Soporte de vista: ?view=individual|clinica|both
        const view = (req.query.view || '').toString().toLowerCase();

        // Si el usuario es doctor individual SIN clínica, ignorar view y devolver solo sus pacientes
        if (req.user && req.user.rol === 'doctor' && !req.user.clinica_id) {
            const pacientes = await pacientesModelo.obtenerPacientesPorDoctor(req.user.id);
            return res.json(pacientes);
        }

        // Usuario con clínica (dueño o doctor vinculado)
        // Obtener clinica_id del request (middleware filtroClinica)
        const clinicaId = req.clinica_id || null;

        if (view === 'individual') {
            // Solo pacientes del doctor autenticado dentro de la clínica (o sin clínica)
            if (!req.user || req.user.rol !== 'doctor') return res.status(403).json({ message: 'Solo doctores pueden ver vista individual' });
            const pacientes = await pacientesModelo.obtenerPacientesPorDoctor(req.user.id);
            return res.json(pacientes);
        }

        if (view === 'clinica') {
            // Solo pacientes de la clínica
            const pacientes = await pacientesModelo.obtenerPacientesPorClinica(clinicaId);
            return res.json(pacientes);
        }

        if (view === 'both') {
            // Unión: pacientes de la clínica + pacientes individuales del doctor
            const pacientesClinica = await pacientesModelo.obtenerPacientesPorClinica(clinicaId);
            let pacientesDoctor = [];
            if (req.user && req.user.rol === 'doctor') {
                pacientesDoctor = await pacientesModelo.obtenerPacientesPorDoctor(req.user.id);
            }
            // Merge avoiding duplicates by id
            const mapa = new Map();
            pacientesClinica.forEach(p => mapa.set(p.id, p));
            pacientesDoctor.forEach(p => mapa.set(p.id, p));
            return res.json(Array.from(mapa.values()));
        }

        // Default: si tiene clínica, devolver pacientes de la clínica
        const pacientes = await pacientesModelo.obtenerPacientesPorClinica(clinicaId);
        res.json(pacientes);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function verPaciente(req, res) {
    try {
        let paciente;
        if (req.user && req.user.rol === 'doctor' && !req.user.clinica_id) {
            paciente = await pacientesModelo.obtenerPacientePorId(req.params.id, null);
            // verificar que el paciente pertenezca al doctor
            if (!paciente || paciente.doctor_id !== req.user.id) return res.status(404).json({ message: 'Paciente no encontrado' });
        } else {
            paciente = await pacientesModelo.obtenerPacientePorId(req.params.id, req.clinica_id);
            if (!paciente) return res.status(404).json({ message: 'Paciente no encontrado' });
        }
        res.json(paciente);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function crearPaciente(req, res) {
    try {
        const { validarLimitePacientes } = require('../utils/validacionLimites');
        const { cambiarPlanAClinicaVIP } = require('../utils/cambioPlanVIP');
        const clinicaId = req.clinica_id || null;
        // Determinar si la creación debe ser como paciente "individual" (doctor_id)
        // Permitimos que un doctor vinculado a una clínica cree pacientes individuales
        // si envía en el body `doctor_id` igual a su propio id.
        const bodyDoctorId = req.body && (typeof req.body.doctor_id !== 'undefined') ? Number(req.body.doctor_id) : null;
        const wantsIndividual = (req.user && req.user.rol === 'doctor' && bodyDoctorId && req.user.id === bodyDoctorId);

        // Si no se está creando un paciente individual (wantsIndividual===false), aplicar límites por clínica
        if (!wantsIndividual) {
            // Si es doctor individual sin clínica, tampoco aplicamos límite de clínica (es handled by model)
            if (!(req.user && req.user.rol === 'doctor' && !req.user.clinica_id)) {
                const validacion = await validarLimitePacientes(clinicaId);
                if (!validacion.permitido) {
                    // Si el total supera el límite base, cambiar a VIP
                    const planBaseLimite = (validacion.plan?.pacientes_max || 0);
                    if (validacion.totalPacientes >= planBaseLimite) {
                        await cambiarPlanAClinicaVIP(clinicaId);
                        // Revalidar con el nuevo plan
                        const nuevaValidacion = await validarLimitePacientes(clinicaId);
                        if (!nuevaValidacion.permitido) {
                            return res.status(403).json({ message: 'Límite de pacientes alcanzado incluso en VIP. Compre más extras.' });
                        }
                    } else {
                        return res.status(403).json({ message: 'Límite de pacientes alcanzado para su plan. Compre más extras o cambie de plan.' });
                    }
                }
            }
        }
        // Preparar datos de paciente
        const pacienteData = { ...req.body };
        if (wantsIndividual) {
            // Crear paciente individual a nombre del doctor autenticado
            pacienteData.doctor_id = req.user.id;
            pacienteData.clinica_id = null;
        } else if (req.user && req.user.rol === 'doctor' && !req.user.clinica_id) {
            // Doctor individual (sin clínica) crea paciente individual
            pacienteData.doctor_id = req.user.id;
            pacienteData.clinica_id = null;
        } else {
            // Por defecto, el paciente pertenece a la clínica del request (middleware filtroClinica)
            pacienteData.clinica_id = clinicaId;
        }
        const nuevoId = await pacientesModelo.crearPaciente(pacienteData);
        res.status(201).json({ id: nuevoId });
        } catch (err) {
            // Manejar errores de límite de paciente de forma amigable
            if (err && (err.code === 'LIMIT_DOCTOR_PACIENTES' || err.message && err.message.includes('Límite de pacientes'))) {
                return res.status(403).json({ message: err.message });
            }
            res.status(500).json({ message: err.message });
        }
}

async function actualizarPaciente(req, res) {
    try {
        const clinicaId = req.clinica_id || null;
        const doctorId = (req.user && req.user.rol === 'doctor' && !req.user.clinica_id) ? req.user.id : null;
        const filas = await pacientesModelo.actualizarPaciente(req.params.id, req.body, clinicaId, doctorId);
        if (filas === 0) return res.status(404).json({ message: 'Paciente no encontrado o sin permiso' });
        res.json({ message: 'Paciente actualizado' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

async function eliminarPaciente(req, res) {
    try {
        const clinicaId = req.clinica_id || null;
        const doctorId = (req.user && req.user.rol === 'doctor' && !req.user.clinica_id) ? req.user.id : null;
        const filas = await pacientesModelo.eliminarPaciente(req.params.id, clinicaId, doctorId);
        if (filas === 0) return res.status(404).json({ message: 'Paciente no encontrado o sin permiso' });
        res.json({ message: 'Paciente eliminado' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

module.exports = {
    listarPacientes,
    verPaciente,
    crearPaciente,
    actualizarPaciente,
    eliminarPaciente
};
