const path = require('path');
const config = require('../config');
const db = require('../db');

/**
 * Gửi thông báo đẩy qua Firebase Cloud Messaging (FCM).
 *
 * Tính năng này TÙY CHỌN: chỉ bật khi
 *   1. đã cài thư viện:  npm install firebase-admin
 *   2. file .env có FCM_SERVICE_ACCOUNT=đường dẫn file khóa tài khoản dịch vụ (JSON)
 *      tải từ Firebase Console → Project settings → Service accounts → Generate new private key.
 * Khi chưa bật, thông báo vẫn được lưu trong bảng Notifications và ứng dụng tự lấy về
 * (màn hình Thông báo, số chưa đọc) – chỉ không có thông báo đẩy khi ứng dụng đang đóng.
 * Lỗi gửi FCM không bao giờ làm hỏng thao tác chính (duyệt sách, gửi thông báo...).
 */
let messaging; // undefined = chưa khởi tạo, null = không dùng được
let reason = 'chưa khởi tạo';

function getMessaging() {
  if (messaging !== undefined) return messaging;
  messaging = null;
  if (!config.fcmServiceAccount) {
    reason = 'chưa cấu hình FCM_SERVICE_ACCOUNT trong .env';
    return messaging;
  }
  try {
    // eslint-disable-next-line global-require
    const admin = require('firebase-admin');
    // eslint-disable-next-line global-require, import/no-dynamic-require
    const serviceAccount = require(path.resolve(config.rootDir, config.fcmServiceAccount));
    const app = admin.apps.length ? admin.app() : admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    messaging = app.messaging();
    reason = `đã bật (project ${serviceAccount.project_id})`;
  } catch (err) {
    reason =
      err.code === 'MODULE_NOT_FOUND' && /firebase-admin/.test(err.message)
        ? 'chưa cài firebase-admin (chạy: npm install firebase-admin)'
        : `không khởi tạo được: ${err.message}`;
    console.warn(`[fcm] Tắt thông báo đẩy: ${reason}`);
  }
  return messaging;
}

/** Trạng thái hiển thị ở /api/health. */
function status() {
  getMessaging();
  return { enabled: !!messaging, detail: reason };
}

const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * Đẩy thông báo tới người nhận.
 * @param {number|null} recipientId  mã người dùng; null = mọi người dùng (thông báo hệ thống)
 */
async function sendPush(recipientId, title, body, data = {}) {
  const fcm = getMessaging();
  if (!fcm) return { sent: 0, failed: 0 };
  try {
    const r =
      recipientId == null
        ? await db.query(
            'SELECT t.Token FROM dbo.DeviceTokens t JOIN dbo.Users u ON u.UserId = t.UserId WHERE u.IsLocked = 0',
          )
        : await db.query('SELECT Token FROM dbo.DeviceTokens WHERE UserId = @uid', { uid: recipientId });
    const tokens = r.recordset.map((x) => x.Token);
    let sent = 0;
    let failed = 0;
    const stale = [];
    // FCM nhận tối đa 500 token mỗi lần gửi.
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      const res = await fcm.sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
        android: { priority: 'high', notification: { channelId: 'bookhub_notices' } },
      });
      sent += res.successCount;
      failed += res.failureCount;
      res.responses.forEach((x, j) => {
        if (!x.success && x.error && INVALID_TOKEN_CODES.has(x.error.code)) stale.push(chunk[j]);
      });
    }
    for (const token of stale) {
      await db.query('DELETE FROM dbo.DeviceTokens WHERE Token = @token', { token });
    }
    return { sent, failed };
  } catch (err) {
    console.warn(`[fcm] Gửi thông báo đẩy thất bại: ${err.message}`);
    return { sent: 0, failed: -1 };
  }
}

/** Gửi nền: không chờ, không ném lỗi ra ngoài. */
function sendPushInBackground(recipientId, title, body, data) {
  sendPush(recipientId, title, body, data).catch(() => {});
}

module.exports = { sendPush, sendPushInBackground, status };
