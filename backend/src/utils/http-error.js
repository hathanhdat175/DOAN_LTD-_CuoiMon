/** Lỗi nghiệp vụ kèm mã HTTP; middleware xử lý lỗi trả về JSON { message }. */
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const badRequest = (msg) => new HttpError(400, msg);
const unauthorized = (msg = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.') => new HttpError(401, msg);
const forbidden = (msg = 'Bạn không có quyền thực hiện thao tác này.') => new HttpError(403, msg);
const notFound = (msg = 'Không tìm thấy dữ liệu.') => new HttpError(404, msg);
const conflict = (msg) => new HttpError(409, msg);

/** Chuyển chuỗi id trên URL thành số nguyên dương, sai thì báo 400. */
function parseId(value, name = 'id') {
  const id = Number(value);
  if (!Number.isInteger(id) || id <= 0) {
    throw badRequest(`Tham số ${name} không hợp lệ.`);
  }
  return id;
}

module.exports = { HttpError, badRequest, unauthorized, forbidden, notFound, conflict, parseId };
