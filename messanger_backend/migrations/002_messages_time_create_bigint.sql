-- time_create должно быть BIGINT с epoch-миллисекундами.
--
-- Старая версия db/schema.sql объявляла TIMESTAMPTZ, но клиент, кэш и
-- дедупликация повторной отправки работают с числом миллисекунд. На базах,
-- созданных по старой схеме, колонку нужно конвертировать; на актуальных
-- базах миграция ничего не делает.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'messages'
       AND column_name = 'time_create'
       AND data_type = 'timestamp with time zone'
  ) THEN
    ALTER TABLE messages ALTER COLUMN time_create DROP DEFAULT;
    ALTER TABLE messages
      ALTER COLUMN time_create TYPE BIGINT
      USING (EXTRACT(EPOCH FROM time_create) * 1000)::BIGINT;
  END IF;
END $$;
