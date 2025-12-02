const pagosService = require('../servicios/pagosService');

async function run() {
  const id = Number(process.argv[2]);
  if (!id) {
    console.error('Usage: node scripts/reconfirm_purchase.js <compraId>');
    process.exit(1);
  }
  try {
    console.log('Reconfirming compra', id);
    const ok = await pagosService.confirmarCompra({ compraId: id, provider_txn_id: 'manual-reconfirm' });
    console.log('Result:', ok);
    process.exit(0);
  } catch (err) {
    console.error('Error reconfirming:', err);
    process.exit(1);
  }
}

run();
