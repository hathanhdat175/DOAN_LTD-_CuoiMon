const fs = require('fs');
const { PDFDocument } = require('pdf-lib');

/** Đếm số trang thật của file PDF; trả về null nếu file hỏng hoặc không đọc được. */
async function countPdfPages(fullPath) {
  try {
    const bytes = await fs.promises.readFile(fullPath);
    const doc = await PDFDocument.load(bytes, { ignoreEncryption: true, updateMetadata: false });
    return doc.getPageCount();
  } catch {
    return null;
  }
}

module.exports = { countPdfPages };
