/**
 * Tạo cơ sở dữ liệu BookHubDB và dữ liệu mẫu:
 *   1. Chạy script ../ebook_reader_demo/database/bookhub_sqlserver.sql (tách theo GO).
 *   2. Tạo file PDF mẫu cho các sách trong bảng Books (uploads/pdf/sample-*.pdf).
 *
 * Cách chạy:  npm run setup-db
 */
const fs = require('fs');
const path = require('path');
const PDFDocument = require('pdfkit');
const config = require('../src/config');
const db = require('../src/db');
const { runSqlFile } = require('./sql-runner');

const SQL_FILE = path.resolve(__dirname, '..', '..', 'ebook_reader_demo', 'database', 'bookhub_sqlserver.sql');

/** Font có dấu tiếng Việt (lấy từ Windows; máy khác thì dùng font mặc định). */
const FONT_CANDIDATES = [
  'C:/Windows/Fonts/arial.ttf',
  'C:/Windows/Fonts/segoeui.ttf',
  '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  '/Library/Fonts/Arial Unicode.ttf',
];
const FONT_BOLD_CANDIDATES = ['C:/Windows/Fonts/arialbd.ttf', 'C:/Windows/Fonts/segoeuib.ttf'];

function firstExisting(list) {
  return list.find((p) => fs.existsSync(p)) || null;
}

async function runSqlScript() {
  await runSqlFile(SQL_FILE);
}

const SAMPLE_TEXT = [
  'Đây là bản PDF mẫu do máy chủ BookHub tạo ra để minh họa chức năng đọc sách. Nội dung thật của sách sẽ do người đăng (Publisher) tải lên dưới dạng file PDF.',
  'Ứng dụng tự động ghi nhớ trang bạn đang đọc. Lần sau mở lại, sách sẽ tiếp tục đúng tại trang này, kể cả khi bạn đọc trên một thiết bị khác cùng tài khoản.',
  'Bạn có thể vuốt để lật trang, kéo thanh trượt bên dưới để chuyển nhanh tới một trang bất kỳ, phóng to hoặc thu nhỏ và đổi chế độ nền sáng, giấy hoặc tối.',
  'Sách đã tải về máy có thể đọc khi không có kết nối mạng. Tiến độ đọc khi ngoại tuyến được lưu cục bộ và đồng bộ lên máy chủ khi có mạng trở lại.',
];

function writeSamplePdf(book, fullPath, fonts) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A5', margin: 48, info: { Title: book.Title, Author: book.Author } });
    const out = fs.createWriteStream(fullPath);
    doc.pipe(out);
    if (fonts.regular) doc.registerFont('body', fonts.regular);
    doc.registerFont('bold', fonts.bold || fonts.regular || 'Helvetica-Bold');
    const body = fonts.regular ? 'body' : 'Helvetica';

    for (let page = 1; page <= book.TotalPages; page++) {
      if (page > 1) doc.addPage();
      if (page === 1) {
        doc.moveDown(4);
        doc.font('bold').fontSize(24).fillColor('#2F5D50').text(book.Title, { align: 'center' });
        doc.moveDown(0.6);
        doc.font(body).fontSize(14).fillColor('#555555').text(book.Author, { align: 'center' });
        doc.moveDown(2);
        doc.fontSize(11).fillColor('#333333').text(book.Description || '', { align: 'justify', lineGap: 4 });
        doc.moveDown(2);
        doc.fontSize(9).fillColor('#888888').text('BookHub · Nhóm 10', { align: 'center' });
      } else {
        doc.font('bold').fontSize(10).fillColor('#999999').text(`${book.Title.toUpperCase()} — TRANG ${page}`);
        doc.moveDown(1);
        doc.font('bold').fontSize(16).fillColor('#222222').text(`Chương ${Math.ceil(page / 4)} · Phần ${page}`);
        doc.moveDown(0.8);
        doc.font(body).fontSize(11.5).fillColor('#222222');
        for (let i = 0; i < SAMPLE_TEXT.length; i++) {
          doc.text(SAMPLE_TEXT[(page + i) % SAMPLE_TEXT.length], { align: 'justify', lineGap: 4 });
          doc.moveDown(0.8);
        }
        if (page === book.TotalPages) {
          doc.moveDown(1).font('bold').text('— HẾT —', { align: 'center' });
        }
      }
      // Chân trang nằm trong lề dưới: tạm bỏ lề để pdfkit không tự sang trang mới.
      const bottom = doc.page.margins.bottom;
      doc.page.margins.bottom = 0;
      doc
        .font(body)
        .fontSize(9)
        .fillColor('#999999')
        .text(`${page} / ${book.TotalPages}`, 0, doc.page.height - 36, { align: 'center', width: doc.page.width });
      doc.page.margins.bottom = bottom;
    }
    doc.end();
    out.on('finish', resolve);
    out.on('error', reject);
  });
}

async function generateSamplePdfs() {
  const fonts = { regular: firstExisting(FONT_CANDIDATES), bold: firstExisting(FONT_BOLD_CANDIDATES) };
  if (!fonts.regular) {
    console.warn('[setup] Không tìm thấy font tiếng Việt, PDF mẫu sẽ dùng font mặc định (có thể lỗi dấu).');
  }
  const result = await db.query('SELECT BookId, Title, Author, Description, TotalPages, PdfPath FROM dbo.Books');
  let count = 0;
  for (const book of result.recordset) {
    const fullPath = path.resolve(config.rootDir, book.PdfPath);
    fs.mkdirSync(path.dirname(fullPath), { recursive: true });
    await writeSamplePdf(book, fullPath, fonts);
    count++;
  }
  console.log(`[setup] Đã tạo ${count} file PDF mẫu trong ${path.join(config.uploadDir, 'pdf')}`);
}

(async () => {
  try {
    await runSqlScript();
    await generateSamplePdfs();
    console.log('[setup] Hoàn tất. Tài khoản mẫu: reader@demo.com / publisher@demo.com / admin@demo.com (mật khẩu Demo@123)');
  } catch (err) {
    console.error('[setup] Lỗi:', err.message);
    process.exitCode = 1;
  } finally {
    await db.close();
  }
})();
