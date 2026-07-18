package database

import (
	"database/sql"
	"fmt"
	"os"
)

func Migrate(db *sql.DB) error {
	migrationPath := "migrations/001_init.sql"
	data, err := os.ReadFile(migrationPath)
	if err != nil {
		return fmt.Errorf("read migration file: %w", err)
	}

	if _, err := db.Exec(string(data)); err != nil {
		return fmt.Errorf("run migration: %w", err)
	}

	return nil
}
