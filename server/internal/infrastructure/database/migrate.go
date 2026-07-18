package database

import (
	"database/sql"
	"fmt"
	"os"
	"strings"
)

func Migrate(db *sql.DB) error {
	migrationPath := "migrations/001_init.sql"
	data, err := os.ReadFile(migrationPath)
	if err != nil {
		return fmt.Errorf("read migration file: %w", err)
	}

	statements := splitStatements(string(data))
	for _, stmt := range statements {
		stmt = strings.TrimSpace(stmt)
		if stmt == "" {
			continue
		}
		if _, err := db.Exec(stmt); err != nil {
			return fmt.Errorf("run migration statement: %s: %w", truncate(stmt, 100), err)
		}
	}

	return nil
}

func splitStatements(sql string) []string {
	var stmts []string
	var current strings.Builder
	lines := strings.Split(sql, "\n")

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "--") {
			continue
		}
		current.WriteString(line)
		current.WriteString("\n")
		if strings.HasSuffix(trimmed, ";") {
			stmts = append(stmts, current.String())
			current.Reset()
		}
	}
	if current.Len() > 0 {
		s := strings.TrimSpace(current.String())
		if s != "" {
			stmts = append(stmts, s)
		}
	}
	return stmts
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
