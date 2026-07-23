CREATE TABLE IF NOT EXISTS call_logs (
    id VARCHAR(36) PRIMARY KEY,
    call_id VARCHAR(64) NOT NULL,
    chat_id VARCHAR(36) NOT NULL,
    caller_id VARCHAR(36) NOT NULL,
    callee_id VARCHAR(36) DEFAULT NULL,
    call_type VARCHAR(16) NOT NULL DEFAULT 'video',
    status VARCHAR(16) NOT NULL DEFAULT 'ringing',
    started_at DATETIME(3) NOT NULL,
    answered_at DATETIME(3) DEFAULT NULL,
    ended_at DATETIME(3) DEFAULT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX idx_call_logs_chat (chat_id),
    INDEX idx_call_logs_caller (caller_id),
    INDEX idx_call_logs_callee (callee_id),
    INDEX idx_call_logs_started (started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
