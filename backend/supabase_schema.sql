-- ====================================================================
-- SUPABASE POSTGRESQL DATABASE SCHEMA & ROW LEVEL SECURITY POLICIES
-- Project: Multi-Zone Campus Infrastructure Maintenance & Repair Dispatch
-- Target Institution: Bahir Dar University
-- ====================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. ENUM DEFINITIONS
CREATE TYPE user_role AS ENUM ('student', 'faculty', 'dispatcher', 'technician', 'admin');
CREATE TYPE zone_category AS ENUM ('Dorms', 'Classrooms', 'Labs', 'Grounds', 'Administrative');
CREATE TYPE ticket_priority AS ENUM ('Low', 'Medium', 'High', 'Emergency');
CREATE TYPE ticket_status AS ENUM ('Pending', 'Assigned', 'In Progress', 'Resolved', 'Rejected');

-- 2. PROFILES TABLE
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone_number TEXT,
  role user_role NOT NULL DEFAULT 'student',
  department TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ZONES DIRECTORY TABLE
CREATE TABLE public.zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campus_name TEXT NOT NULL,
  category zone_category NOT NULL,
  block_name TEXT NOT NULL,
  room_number TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. TICKETS TABLE
CREATE TABLE public.tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number SERIAL UNIQUE,
  reporter_id UUID NOT NULL REFERENCES public.profiles(id),
  zone_id UUID NOT NULL REFERENCES public.zones(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  room_number TEXT,
  latitude NUMERIC(9, 6),
  longitude NUMERIC(9, 6),
  priority ticket_priority NOT NULL DEFAULT 'Medium',
  status ticket_status NOT NULL DEFAULT 'Pending',
  photo_urls TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT tickets_coordinates_paired CHECK ((latitude IS NULL) = (longitude IS NULL)),
  CONSTRAINT tickets_latitude_range CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT tickets_longitude_range CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

-- 5. ASSIGNMENTS TABLE
CREATE TABLE public.assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  dispatcher_id UUID NOT NULL REFERENCES public.profiles(id),
  technician_id UUID NOT NULL REFERENCES public.profiles(id),
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT
);

-- 6. TICKET LOGS TABLE
CREATE TABLE public.ticket_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES public.profiles(id),
  previous_status ticket_status,
  new_status ticket_status NOT NULL,
  log_comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reporters read own tickets" ON public.tickets
  FOR SELECT USING (auth.uid() = reporter_id);

CREATE POLICY "Reporters create tickets" ON public.tickets
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Dispatchers full access" ON public.tickets
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role IN ('dispatcher', 'admin')
    )
  );

CREATE POLICY "Technicians view assigned" ON public.tickets
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.assignments 
      WHERE ticket_id = tickets.id AND technician_id = auth.uid()
    )
  );

-- 8. ROLE LOOKUP AND AUDIT TRIGGERS
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS public.user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.set_ticket_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_ticket_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.ticket_logs (ticket_id, actor_id, previous_status, new_status, log_comment)
  VALUES (
    NEW.id,
    COALESCE(auth.uid(), NEW.reporter_id),
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE OLD.status END,
    NEW.status,
    CASE WHEN TG_OP = 'INSERT' THEN 'Report submitted' ELSE NULL END
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER tickets_set_updated_at
  BEFORE UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.set_ticket_updated_at();

CREATE TRIGGER tickets_log_initial_status
  AFTER INSERT ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.log_ticket_status_change();

CREATE TRIGGER tickets_log_status_change
  AFTER UPDATE OF status ON public.tickets
  FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.log_ticket_status_change();

-- 9. ROW LEVEL SECURITY
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Reporters read own tickets" ON public.tickets;
DROP POLICY IF EXISTS "Reporters create tickets" ON public.tickets;
DROP POLICY IF EXISTS "Dispatchers full access" ON public.tickets;
DROP POLICY IF EXISTS "Technicians view assigned" ON public.tickets;

CREATE POLICY "Profiles read self or dispatch" ON public.profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid() OR public.current_user_role() IN ('dispatcher', 'admin'));

CREATE POLICY "Profiles insert self" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY "Profiles update self" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Automatically create or update a profile when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, phone_number, role, department)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.email,
    NEW.raw_user_meta_data->>'phone_number',
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student'::user_role),
    NEW.raw_user_meta_data->>'department'
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone_number = COALESCE(EXCLUDED.phone_number, profiles.phone_number),
    department = COALESCE(EXCLUDED.department, profiles.department);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE POLICY "Authenticated users read zones" ON public.zones
  FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Dispatchers manage zones" ON public.zones
  FOR ALL TO authenticated
  USING (public.current_user_role() IN ('dispatcher', 'admin'))
  WITH CHECK (public.current_user_role() IN ('dispatcher', 'admin'));

CREATE POLICY "Reporters read own tickets" ON public.tickets
  FOR SELECT TO authenticated
  USING (reporter_id = auth.uid());

CREATE POLICY "Dispatchers read all tickets" ON public.tickets
  FOR SELECT TO authenticated
  USING (public.current_user_role() IN ('dispatcher', 'admin'));

CREATE POLICY "Technicians read assigned tickets" ON public.tickets
  FOR SELECT TO authenticated
  USING (
    public.current_user_role() = 'technician'
    AND EXISTS (
      SELECT 1 FROM public.assignments
      WHERE assignments.ticket_id = tickets.id
        AND assignments.technician_id = auth.uid()
    )
  );

CREATE POLICY "Reporters create own tickets" ON public.tickets
  FOR INSERT TO authenticated
  WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Dispatchers update tickets" ON public.tickets
  FOR UPDATE TO authenticated
  USING (public.current_user_role() IN ('dispatcher', 'admin'))
  WITH CHECK (public.current_user_role() IN ('dispatcher', 'admin'));

CREATE POLICY "Assigned technicians update tickets" ON public.tickets
  FOR UPDATE TO authenticated
  USING (
    public.current_user_role() = 'technician'
    AND EXISTS (
      SELECT 1 FROM public.assignments
      WHERE assignments.ticket_id = tickets.id
        AND assignments.technician_id = auth.uid()
    )
  )
  WITH CHECK (
    public.current_user_role() = 'technician'
    AND EXISTS (
      SELECT 1 FROM public.assignments
      WHERE assignments.ticket_id = tickets.id
        AND assignments.technician_id = auth.uid()
    )
  );

CREATE POLICY "Dispatchers manage assignments" ON public.assignments
  FOR ALL TO authenticated
  USING (public.current_user_role() IN ('dispatcher', 'admin'))
  WITH CHECK (
    public.current_user_role() IN ('dispatcher', 'admin')
    AND dispatcher_id = auth.uid()
  );

CREATE POLICY "Technicians read own assignments" ON public.assignments
  FOR SELECT TO authenticated
  USING (technician_id = auth.uid());

CREATE POLICY "Users read related ticket logs" ON public.ticket_logs
  FOR SELECT TO authenticated
  USING (
    public.current_user_role() IN ('dispatcher', 'admin')
    OR EXISTS (
      SELECT 1 FROM public.tickets
      WHERE tickets.id = ticket_logs.ticket_id
        AND tickets.reporter_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.assignments
      WHERE assignments.ticket_id = ticket_logs.ticket_id
        AND assignments.technician_id = auth.uid()
    )
  );

-- Keep report images private. The first path segment must be the uploader's user ID.
INSERT INTO storage.buckets (id, name, public)
VALUES ('hazard-photos', 'hazard-photos', FALSE)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users upload own hazard photos" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'hazard-photos'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

CREATE POLICY "Authenticated users read hazard photos" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'hazard-photos');

CREATE INDEX IF NOT EXISTS tickets_reporter_created_idx
  ON public.tickets (reporter_id, created_at DESC);
CREATE INDEX IF NOT EXISTS tickets_status_priority_idx
  ON public.tickets (status, priority);
CREATE INDEX IF NOT EXISTS assignments_technician_idx
  ON public.assignments (technician_id, ticket_id);
