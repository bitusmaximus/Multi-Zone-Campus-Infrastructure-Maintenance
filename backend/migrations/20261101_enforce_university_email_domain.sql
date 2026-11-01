-- Enforce that all registered users and profiles belong to Bahir Dar University (@bdu.edu.et)

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS check_university_email_domain;

ALTER TABLE public.profiles
  ADD CONSTRAINT check_university_email_domain
  CHECK (email ~* '^[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.)?bdu\.edu\.et$');

-- Trigger to block non-university emails during auth signup
CREATE OR REPLACE FUNCTION public.check_new_user_domain()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.email !~* '^[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.)?bdu\.edu\.et$' THEN
    RAISE EXCEPTION 'Registration rejected: Only official Bahir Dar University emails (@bdu.edu.et) are permitted.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_check_new_user_domain ON auth.users;
CREATE TRIGGER tr_check_new_user_domain
  BEFORE INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.check_new_user_domain();
