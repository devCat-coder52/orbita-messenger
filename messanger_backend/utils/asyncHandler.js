/**
 * Оборачивает async-хендлер, чтобы отклонённый промис попал в errorHandler.
 *
 * Логирование здесь не дублируется: уровень и стек пишет middleware/errorHandler.
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = asyncHandler;
