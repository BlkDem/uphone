ALTER TABLE chat_members ADD COLUMN IF NOT EXISTS last_read_at DATETIME(3) NULL;

CREATE TABLE IF NOT EXISTS message_reads (
    message_id CHAR(36) NOT NULL,
    user_id CHAR(36) NOT NULL,
    read_at DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (message_id, user_id),
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX IF NOT EXISTS idx_message_reads_user ON message_reads(user_id, read_at DESC);
