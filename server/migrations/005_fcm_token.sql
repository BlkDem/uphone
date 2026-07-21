ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(512) NULL;
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token);
