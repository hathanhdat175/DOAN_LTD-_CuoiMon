const config = require('./config');
const db = require('./db');
const { createApp } = require('./app');

async function main() {
  try {
    await db.getPool();
    console.log(`[db] Đã kết nối ${config.db.database} trên ${config.db.server} (driver: ${config.db.driver})`);
  } catch (err) {
    console.error(`[db] Không kết nối được SQL Server: ${err.message}`);
    console.error('     Kiểm tra file .env và chạy "npm run setup-db" để tạo cơ sở dữ liệu.');
  }

  createApp().listen(config.port, '0.0.0.0', () => {
    console.log(`[api] BookHub API đang chạy tại http://localhost:${config.port}`);
    console.log('      Máy ảo Android truy cập qua http://10.0.2.2:' + config.port);
  });
}

main();
