package config

import (
	"os"
	"strconv"
)

type Config struct {
	ServerPort     int
	DB             DBConfig
	JWTSecret      string
	UploadDir      string
	UploadBaseURL  string
	GoogleClientID string
	FCMCredentials string
	MinIOEndpoint  string
	MinIOAccessKey string
	MinIOSecretKey string
	MinIOBucket    string
	MinIOUseSSL    bool
}

type DBConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	Name     string
}

func Load() *Config {
	return &Config{
		ServerPort: getEnvInt("SERVER_PORT", 8080),
		DB: DBConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnvInt("DB_PORT", 3306),
			User:     getEnv("DB_USER", "uphone"),
			Password: getEnv("DB_PASSWORD", "uphone_secret"),
			Name:     getEnv("DB_NAME", "uphone"),
		},
		JWTSecret:      getEnv("JWT_SECRET", "change-me-in-production"),
		UploadDir:      getEnv("UPLOAD_DIR", "./uploads"),
		UploadBaseURL:  getEnv("UPLOAD_BASE_URL", ""),
		GoogleClientID: getEnv("GOOGLE_CLIENT_ID", ""),
		FCMCredentials: getEnv("FCM_CREDENTIALS", ""),
		MinIOEndpoint:  getEnv("MINIO_ENDPOINT", ""),
		MinIOAccessKey: getEnv("MINIO_ACCESS_KEY", ""),
		MinIOSecretKey: getEnv("MINIO_SECRET_KEY", ""),
		MinIOBucket:    getEnv("MINIO_BUCKET", "uphone-uploads"),
		MinIOUseSSL:    getEnv("MINIO_USE_SSL", "") == "true",
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}
