const fs = require('fs');
const path = require('path');
const db = require('../src/db');

/**
 * Chạy một file .sql trên SQL Server, tách thành các lô theo dòng "GO" như SSMS.
 * Dùng một kết nối duy nhất (kết nối tới master) để lệnh USE BookHubDB có hiệu lực cho các lô sau.
 */
async function runSqlFile(file) {
  const text = fs.readFileSync(file, 'utf8');
  const batches = text
    .split(/^\s*GO\s*$/im)
    .map((b) => b.trim())
    .filter((b) => b && !/^\/\*[\s\S]*\*\/$/.test(b));

  const pool = new db.sql.ConnectionPool({ ...db.buildConfig('master'), pool: { max: 1, min: 1 } });
  await pool.connect();
  try {
    for (const batch of batches) {
      await pool.request().batch(batch);
    }
  } finally {
    await pool.close();
  }
  console.log(`[sql] Đã chạy ${batches.length} lô lệnh từ ${path.basename(file)}`);
  return batches.length;
}

module.exports = { runSqlFile };
