#!/usr/bin/env node
/*
 Interactive DB cleanup tool for local development.
 - Lists tables
 - Asks which tables to truncate (or ALL)
 - Requires explicit typed confirmation after you perform a backup
 - Disables FOREIGN_KEY_CHECKS, truncates tables, resets AUTO_INCREMENT
 Usage: node tools/clean_db.js
 WARNING: destructive. DO A BACKUP FIRST.
*/

const pool = require('../config/db');
const readline = require('readline');
const util = require('util');

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const question = (q) => new Promise((res) => rl.question(q, res));

// Support a non-interactive mode for automation: pass `--yes-all` or set env var `CLEAN_DB_AUTO=1`
const nonInteractive = process.argv.includes('--yes-all') || process.env.CLEAN_DB_AUTO === '1';

async function listTables() {
  const [rows] = await pool.query("SHOW TABLES");
  // rows will be array of objects with key like 'Tables_in_clinica_db'
  const key = Object.keys(rows[0] || {})[0];
  return rows.map(r => r[key]);
}

async function confirmBackup() {
  console.log('\n=== IMPORTANT: BACKUP YOUR DATABASE BEFORE PROCEEDING ===');
  console.log('Recommended example (PowerShell):');
  console.log("mysqldump -u <user> -p clinica_db > clinica_db_backup.sql\n");
  const ok = await question('Have you backed up your DB and want to continue? Type YES to continue: ');
  return ok.trim() === 'YES';
}

async function run() {
  try {
    console.log('Connecting to DB...');
    const tables = await listTables();
    if (!tables || tables.length === 0) {
      console.log('No tables found. Exiting.');
      process.exit(0);
    }
    console.log('\nFound tables:');
    tables.forEach((t, i) => console.log(`${i+1}. ${t}`));

    let toTruncate = [];
    if (nonInteractive) {
      console.log('\nNon-interactive mode enabled: truncating ALL tables');
      toTruncate = tables.slice();
    } else {
      const pick = await question('\nEnter comma-separated table names to TRUNCATE, or type ALL to truncate all tables: ');
      if (pick.trim().toUpperCase() === 'ALL') {
        toTruncate = tables.slice();
      } else {
        const picks = pick.split(',').map(s => s.trim()).filter(Boolean);
        toTruncate = picks.filter(p => tables.includes(p));
        const invalid = picks.filter(p => !tables.includes(p));
        if (invalid.length) {
          console.log('Ignored unknown tables:', invalid.join(', '));
        }
      }
    }

    if (toTruncate.length === 0) {
      console.log('No valid tables selected. Exiting.');
      process.exit(0);
    }

    console.log('\nTables to be truncated:');
    toTruncate.forEach(t => console.log(' -', t));

    let backed = true;
    let final = 'TRUNCATE';
    if (!nonInteractive) {
      backed = await confirmBackup();
      if (!backed) {
        console.log('Aborting. Please make a backup and run again.');
        process.exit(1);
      }

      final = await question('\nFINAL CONFIRMATION: type TRUNCATE to proceed: ');
      if (final.trim() !== 'TRUNCATE') {
        console.log('Confirmation not received. Exiting.');
        process.exit(1);
      }
    } else {
      console.log('\nNon-interactive: backup confirmation assumed and final confirmation auto-accepted.');
    }

    console.log('\nDisabling foreign key checks...');
    await pool.query('SET FOREIGN_KEY_CHECKS=0');

    for (const t of toTruncate) {
      console.log(`Truncating ${t} ...`);
      try {
        await pool.query(`TRUNCATE TABLE \`${t}\``);
        console.log(`Truncated ${t}`);
        try {
          await pool.query(`ALTER TABLE \`${t}\` AUTO_INCREMENT = 1`);
        } catch (e) {
          // ignore
        }
      } catch (err) {
        console.error(`Error truncating ${t}:`, err.message || err);
      }
    }

    console.log('Re-enabling foreign key checks...');
    await pool.query('SET FOREIGN_KEY_CHECKS=1');

    console.log('\nDone. Tables truncated.');
    process.exit(0);
  } catch (err) {
    console.error('Fatal error:', err);
    process.exit(2);
  }
}

run();
