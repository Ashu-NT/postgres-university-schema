-- Create a read-only login role for demos (CHANGE THE PASSWORD)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'uni_readonly') THEN
    CREATE ROLE uni_readonly LOGIN PASSWORD 'PostgreUniDbPass';
  END IF;
END $$;

GRANT CONNECT ON DATABASE neondb TO uni_readonly;
GRANT USAGE ON SCHEMA public TO uni_readonly;

-- Existing objects
GRANT SELECT ON ALL TABLES    IN SCHEMA public TO uni_readonly;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO uni_readonly;

-- Future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO uni_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO uni_readonly;

-- Extra safety (no writes)
REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM uni_readonly;