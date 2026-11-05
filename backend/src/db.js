const config = require('./config');

/**
 * Tầng truy cập dữ liệu: một pool kết nối SQL Server dùng chung cho cả ứng dụng.
 *
 * - DB_DRIVER=msnodesqlv8: xác thực Windows qua ODBC (không cần bật TCP/IP).
 * - DB_DRIVER=tedious: tài khoản SQL Server qua TCP (mặc định cổng 1433).
 */
const useOdbc = config.db.driver === 'msnodesqlv8';
const sql = useOdbc ? require('mssql/msnodesqlv8') : require('mssql');

// Cột DATETIME2 lưu giờ địa phương của máy chủ SQL (SYSDATETIME()); useUTC: false để driver
// hiểu đúng là giờ địa phương, JSON trả về sẽ là thời điểm UTC chính xác (không bị lệch +7 giờ).
function buildConfig(database) {
  if (useOdbc) {
    return {
      connectionString:
        `Driver={${config.db.odbcDriver}};Server=${config.db.server};Database=${database};` +
        'Trusted_Connection=yes;TrustServerCertificate=yes;',
      options: { useUTC: false },
    };
  }
  return {
    server: config.db.server,
    port: config.db.port,
    user: config.db.user,
    password: config.db.password,
    database,
    options: { encrypt: false, trustServerCertificate: true, useUTC: false },
  };
}

let poolPromise = null;

/** Lấy pool kết nối tới BookHubDB (tạo ở lần gọi đầu tiên). */
function getPool() {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(buildConfig(config.db.database))
      .connect()
      .catch((err) => {
        poolPromise = null;
        throw err;
      });
  }
  return poolPromise;
}

/**
 * Chạy câu lệnh SQL có tham số. `params` là object { tenThamSo: giaTri }.
 * Kiểu dữ liệu được suy ra tự động; dùng tham số nên an toàn trước SQL Injection.
 */
async function query(text, params = {}) {
  const pool = await getPool();
  const request = pool.request();
  for (const [name, value] of Object.entries(params)) {
    if (value !== null && typeof value === 'object' && value.type) {
      request.input(name, value.type, value.value);
    } else {
      request.input(name, value);
    }
  }
  return request.query(text);
}

/** Chạy nhiều câu lệnh trong một transaction. `work` nhận hàm `q(text, params)`. */
async function transaction(work) {
  const pool = await getPool();
  const tx = new sql.Transaction(pool);
  await tx.begin();
  try {
    const q = (text, params = {}) => {
      const request = new sql.Request(tx);
      for (const [name, value] of Object.entries(params)) {
        request.input(name, value);
      }
      return request.query(text);
    };
    const result = await work(q);
    await tx.commit();
    return result;
  } catch (err) {
    await tx.rollback();
    throw err;
  }
}

async function close() {
  if (poolPromise) {
    const pool = await poolPromise;
    poolPromise = null;
    await pool.close();
  }
}

module.exports = { sql, query, transaction, getPool, close, buildConfig };
