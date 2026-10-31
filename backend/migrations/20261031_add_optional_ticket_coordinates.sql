ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(9, 6),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(9, 6);

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.tickets'::regclass
      AND conname = 'tickets_coordinates_paired'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_coordinates_paired
      CHECK ((latitude IS NULL) = (longitude IS NULL));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.tickets'::regclass
      AND conname = 'tickets_latitude_range'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_latitude_range
      CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.tickets'::regclass
      AND conname = 'tickets_longitude_range'
  ) THEN
    ALTER TABLE public.tickets
      ADD CONSTRAINT tickets_longitude_range
      CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180);
  END IF;
END;
$migration$;