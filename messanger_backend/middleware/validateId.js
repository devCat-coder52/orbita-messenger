/**
 * Проверяет, что параметр маршрута — положительное целое.
 *
 * Без этого `GET /api/users/abc` уходил в PostgreSQL и падал с 500
 * («invalid input syntax for type integer») вместо понятной ошибки 400.
 */
function validateId(paramName = 'id') {
  return (req, res, next) => {
    const id = Number(req.params[paramName]);
    if (!Number.isInteger(id) || id <= 0) {
      return res
        .status(400)
        .json({ success: false, error: 'Некорректный идентификатор' });
    }
    req.params[paramName] = String(id);
    return next();
  };
}

module.exports = validateId;
