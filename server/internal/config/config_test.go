package config

import (
	"os"
	"testing"
)

func TestLoadDefaults(t *testing.T) {
	os.Clearenv()

	cfg := Load()

	if cfg.ServerPort != 8080 {
		t.Errorf("expected ServerPort 8080, got %d", cfg.ServerPort)
	}
	if cfg.DB.Host != "localhost" {
		t.Errorf("expected DB.Host localhost, got %s", cfg.DB.Host)
	}
	if cfg.DB.Port != 3306 {
		t.Errorf("expected DB.Port 3306, got %d", cfg.DB.Port)
	}
	if cfg.DB.User != "uphone" {
		t.Errorf("expected DB.User uphone, got %s", cfg.DB.User)
	}
	if cfg.JWTSecret != "change-me-in-production" {
		t.Errorf("expected JWTSecret fallback, got %s", cfg.JWTSecret)
	}
}

func TestLoadFromEnv(t *testing.T) {
	os.Setenv("SERVER_PORT", "9090")
	os.Setenv("DB_HOST", "192.168.1.100")
	os.Setenv("DB_PORT", "3307")
	os.Setenv("DB_USER", "admin")
	os.Setenv("DB_PASSWORD", "secret123")
	os.Setenv("DB_NAME", "mydb")
	os.Setenv("JWT_SECRET", "my-super-secret")
	os.Setenv("UPLOAD_DIR", "/tmp/uploads")
	defer os.Clearenv()

	cfg := Load()

	if cfg.ServerPort != 9090 {
		t.Errorf("expected ServerPort 9090, got %d", cfg.ServerPort)
	}
	if cfg.DB.Host != "192.168.1.100" {
		t.Errorf("expected DB.Host 192.168.1.100, got %s", cfg.DB.Host)
	}
	if cfg.DB.Port != 3307 {
		t.Errorf("expected DB.Port 3307, got %d", cfg.DB.Port)
	}
	if cfg.DB.User != "admin" {
		t.Errorf("expected DB.User admin, got %s", cfg.DB.User)
	}
	if cfg.DB.Password != "secret123" {
		t.Errorf("expected DB.Password secret123, got %s", cfg.DB.Password)
	}
	if cfg.DB.Name != "mydb" {
		t.Errorf("expected DB.Name mydb, got %s", cfg.DB.Name)
	}
	if cfg.JWTSecret != "my-super-secret" {
		t.Errorf("expected JWTSecret my-super-secret, got %s", cfg.JWTSecret)
	}
	if cfg.UploadDir != "/tmp/uploads" {
		t.Errorf("expected UploadDir /tmp/uploads, got %s", cfg.UploadDir)
	}
}

func TestLoadInvalidPort(t *testing.T) {
	os.Clearenv()
	os.Setenv("SERVER_PORT", "not-a-number")
	defer os.Clearenv()

	cfg := Load()

	if cfg.ServerPort != 8080 {
		t.Errorf("expected fallback 8080 for invalid port, got %d", cfg.ServerPort)
	}
}
