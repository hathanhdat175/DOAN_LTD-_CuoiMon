/**
 * Nâng cấp CSDL BookHubDB đang có mà KHÔNG xóa dữ liệu:
 * chạy lần lượt các file trong ../ebook_reader_demo/database/migrations (theo tên file).
 * Mỗi file migration tự kiểm tra trước khi thêm nên chạy lại nhiều lần vẫn an toàn.
 *
 * Cách chạy:  npm run migrate
 * (Muốn tạo lại toàn bộ CSDL và dữ liệu mẫu thì dùng: npm run setup-db)
 */
const fs = require('fs');
const path = require('path');
const db = require('../src/db');
const { runSqlFile } = require('./sql-runner');

const DIR = path.resolve(__dirname, '..', '..', 'ebook_reader_demo', 'database', 'migrations');

(async () => {
  try {
    const files = fs
      .readdirSync(DIR)
      .filter((f) => f.toLowerCase().endsWith('.sql'))
      .sort();
    for (const f of files) {
      await runSqlFile(path.join(DIR, f));
    }
    console.log(`[migrate] Hoàn tất ${files.length} file migration.`);
  } catch (err) {
    console.error('[migrate] Lỗi:', err.message);
    process.exitCode = 1;
  } finally {
    await db.close();
  }
})();
