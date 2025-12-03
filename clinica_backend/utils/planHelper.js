const pool = require('../config/db');
const planesModelo = require('../modelos/planesModelo');

const removeDiacritics = (str = '') => str
  .normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '')
  .toLowerCase();

const PLAN_SPECS = {
  clinica_pequena: {
    slug: 'clinica_pequena',
    nombre: 'Clínica Pequeña',
    precio: 20,
    pacientes_max: 165,
    doctores_max: 2,
    sucursales_incluidas: 0,
    descripcion: 'Plan para clínicas pequeñas: 165 pacientes y 2 doctores.',
    matches: ['clinica pequeña', 'clínica pequeña', 'plan pequeño'],
  },
  clinica_mediana: {
    slug: 'clinica_mediana',
    nombre: 'Clínica Mediana',
    precio: 40,
    pacientes_max: 300,
    doctores_max: 5,
    sucursales_incluidas: 1,
    descripcion: 'Plan para clínicas medianas: 300 pacientes y 5 doctores.',
    matches: ['clinica mediana', 'clínica mediana', 'plan mediano'],
  },
  clinica_grande: {
    slug: 'clinica_grande',
    nombre: 'Clínica Grande',
    precio: 100,
    pacientes_max: null,
    doctores_max: null,
    sucursales_incluidas: 1,
    descripcion: 'Plan para clínicas grandes con pacientes y doctores ilimitados.',
    matches: ['clinica grande', 'clínica grande', 'plan grande'],
  },
  combo_vip: {
    slug: 'combo_vip',
    nombre: 'Combo VIP Multi-Sucursal',
    precio: 150,
    pacientes_max: null,
    doctores_max: null,
    sucursales_incluidas: 2,
    descripcion: 'Plan VIP multi-sucursal con pacientes y doctores ilimitados y 2 sucursales incluidas.',
    matches: ['combo vip', 'vip multi-sucursal', 'vip multi sucursal'],
  },
};

const matcherToSlug = Object.values(PLAN_SPECS).reduce((acc, spec) => {
  spec.matches.forEach((needle) => acc.push({ slug: spec.slug, needle: removeDiacritics(needle) }));
  return acc;
}, []);

function resolvePlanFromTitle(title = '') {
  const normalized = removeDiacritics(title);
  const match = matcherToSlug.find(({ needle }) => normalized.includes(needle));
  if (!match) return null;
  return PLAN_SPECS[match.slug];
}

function getPlanSpecBySlug(slug) {
  return PLAN_SPECS[slug] || null;
}

async function ensurePlanExists(planSpec) {
  if (!planSpec) return null;
  const targetName = planSpec.nombre.trim().toLowerCase();
  const [rows] = await pool.query('SELECT id FROM planes WHERE LOWER(nombre) = ? LIMIT 1', [targetName]);
  if (rows && rows[0]) {
    return rows[0].id;
  }
  const planData = {
    nombre: planSpec.nombre,
    precio: planSpec.precio,
    pacientes_max: planSpec.pacientes_max,
    doctores_max: planSpec.doctores_max,
    sucursales_incluidas: planSpec.sucursales_incluidas,
    descripcion: planSpec.descripcion,
  };
  const createdId = await planesModelo.crearPlan(planData);
  return createdId;
}

async function assignPlanToClinic({ clinicaId, planSpec }) {
  if (!clinicaId || !planSpec) return null;
  const planId = await ensurePlanExists(planSpec);
  if (!planId) return null;
  await pool.query('UPDATE clinica_planes SET activo = false WHERE clinica_id = ? AND activo = true', [clinicaId]);
  await pool.query(
    'INSERT INTO clinica_planes (clinica_id, plan_id, fecha_inicio, fecha_fin, activo) VALUES (?, ?, ?, ?, ?)',
    [clinicaId, planId, new Date(), null, 1],
  );
  return planId;
}

module.exports = {
  PLAN_SPECS,
  resolvePlanFromTitle,
  getPlanSpecBySlug,
  ensurePlanExists,
  assignPlanToClinic,
};
