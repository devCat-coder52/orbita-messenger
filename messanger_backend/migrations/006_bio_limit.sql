-- «О себе» ограничено 100 символами на уровне БД.
-- Сначала подрезаем существующие записи, иначе ALTER TYPE не пройдёт.
UPDATE user_info
SET bio = left(bio, 100)
WHERE char_length(bio) > 100;

ALTER TABLE user_info
  ALTER COLUMN bio TYPE VARCHAR(100);
