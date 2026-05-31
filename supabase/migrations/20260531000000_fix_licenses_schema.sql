-- Migración: schema completo de licenses (31 Mayo 2026)
-- Añade columnas necesarias para LicenseService Flutter

ALTER TABLE licenses ADD COLUMN IF NOT EXISTS device_id TEXT;
ALTER TABLE licenses ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'trial' CHECK (status IN ('trial', 'active', 'suspended', 'expired'));
ALTER TABLE licenses ADD COLUMN IF NOT EXISTS trial_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE licenses ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days');
ALTER TABLE licenses ADD COLUMN IF NOT EXISTS paid_until TIMESTAMPTZ;
ALTER TABLE licenses ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ;
ALTER TABLE licenses ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;
ALTER TABLE licenses ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE licenses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

UPDATE licenses SET
  status = CASE
    WHEN is_active = false THEN 'suspended'
    WHEN valid_until < NOW() THEN 'expired'
    ELSE 'active'
  END,
  paid_until = valid_until,
  trial_ends_at = COALESCE(valid_until, NOW() + INTERVAL '7 days');

ALTER TABLE licenses ADD CONSTRAINT licenses_business_id_unique UNIQUE (business_id);

CREATE INDEX IF NOT EXISTS idx_licenses_device ON licenses(device_id);
CREATE INDEX IF NOT EXISTS idx_licenses_business ON licenses(business_id);
CREATE INDEX IF NOT EXISTS idx_licenses_status ON licenses(status);

CREATE TRIGGER trg_licenses_updated_at
  BEFORE UPDATE ON licenses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
