package config

import (
	"net/url"
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
	S3             S3Config
	TurnURL        string
	TurnUser       string
	TurnPass       string
	ThumbnailWidth int
}

// S3Config holds S3-compatible storage settings. It supports both AWS-style
// env vars (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, ...) and the legacy
// MinIO-style ones (MINIO_ENDPOINT, MINIO_ACCESS_KEY, ...).
type S3Config struct {
	Endpoint     string
	AccessKey    string
	SecretKey    string
	Bucket       string
	Region       string
	UseSSL       bool
	UsePathStyle bool
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
		S3:             loadS3Config(),
		TurnURL:        getEnv("TURN_URL", ""),
		TurnUser:       getEnv("TURN_USER", ""),
		TurnPass:       getEnv("TURN_PASS", ""),
		ThumbnailWidth: getEnvInt("THUMBNAIL_WIDTH", 360),
	}
}

func loadS3Config() S3Config {
	endpoint := getEnv("AWS_ENDPOINT", getEnv("AWS_URL", getEnv("MINIO_ENDPOINT", "")))

	// minio.New expects a bare host[:port]; extract the scheme if present.
	useSSL := getEnv("MINIO_USE_SSL", "") == "true"
	if u, err := url.Parse(endpoint); err == nil && u.Host != "" {
		switch u.Scheme {
		case "https":
			useSSL = true
		case "http":
			useSSL = false
		}
		endpoint = u.Host
	}

	return S3Config{
		Endpoint:     endpoint,
		AccessKey:    getEnv("AWS_ACCESS_KEY_ID", getEnv("MINIO_ACCESS_KEY", "")),
		SecretKey:    getEnv("AWS_SECRET_ACCESS_KEY", getEnv("MINIO_SECRET_KEY", "")),
		Bucket:       getEnv("AWS_BUCKET", getEnv("MINIO_BUCKET", "uphone-uploads")),
		Region:       getEnv("AWS_DEFAULT_REGION", getEnv("AWS_REGION", "")),
		UseSSL:       useSSL,
		UsePathStyle: getEnv("AWS_USE_PATH_STYLE_ENDPOINT", "true") == "true",
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
