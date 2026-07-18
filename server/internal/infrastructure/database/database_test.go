package database

import (
	"testing"

	"github.com/uphone/server/internal/config"
)

func TestConnectInvalidHost(t *testing.T) {
	cfg := &config.DBConfig{
		Host:     "nonexistent-host",
		Port:     3306,
		User:     "test",
		Password: "test",
		Name:     "test",
	}

	_, err := Connect(cfg)
	if err == nil {
		t.Error("expected error for invalid host")
	}
}

func TestConnectInvalidPort(t *testing.T) {
	cfg := &config.DBConfig{
		Host:     "localhost",
		Port:     19999,
		User:     "test",
		Password: "test",
		Name:     "test",
	}

	_, err := Connect(cfg)
	if err == nil {
		t.Error("expected error for invalid port")
	}
}

func TestDSNFormat(t *testing.T) {
	cfg := &config.DBConfig{
		Host:     "127.0.0.1",
		Port:     3306,
		User:     "admin",
		Password: "p@ss",
		Name:     "mydb",
	}

	dsn := buildDSN(cfg)

	if dsn == "" {
		t.Error("DSN should not be empty")
	}

	expected := "admin:p@ss@tcp(127.0.0.1:3306)/mydb?charset=utf8mb4&collation=utf8mb4_unicode_ci&parseTime=true&loc=UTC"
	if dsn != expected {
		t.Errorf("expected DSN:\n  %s\ngot:\n  %s", expected, dsn)
	}
}

func buildDSN(cfg *config.DBConfig) string {
	return cfg.User + ":" + cfg.Password + "@tcp(" + cfg.Host + ":" + itoa(cfg.Port) + ")/" + cfg.Name +
		"?charset=utf8mb4&collation=utf8mb4_unicode_ci&parseTime=true&loc=UTC"
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	result := ""
	for n > 0 {
		result = string(rune('0'+n%10)) + result
		n /= 10
	}
	return result
}
