package users

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
)

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Create(ctx context.Context, user *User) error {
	user.ID = uuid.New().String()
	user.CreatedAt = time.Now().UTC()
	user.UpdatedAt = time.Now().UTC()

	_, err := r.db.ExecContext(ctx,
		`INSERT INTO users (id, username, email, password_hash, display_name, status, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		user.ID, user.Username, user.Email, user.PasswordHash,
		user.DisplayName, "offline", user.CreatedAt, user.UpdatedAt)

	return err
}

func (r *Repository) GetByID(ctx context.Context, id string) (*User, error) {
	user := &User{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, username, email, password_hash, COALESCE(display_name,''), COALESCE(avatar_url,''),
		        status, COALESCE(last_seen,'0001-01-01'), created_at, updated_at
		 FROM users WHERE id = ?`, id).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.DisplayName, &user.AvatarURL, &user.Status,
		&user.LastSeen, &user.CreatedAt, &user.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found")
	}
	return user, err
}

func (r *Repository) GetByEmail(ctx context.Context, email string) (*User, error) {
	user := &User{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, username, email, password_hash, COALESCE(display_name,''), COALESCE(avatar_url,''),
		        status, COALESCE(last_seen,'0001-01-01'), created_at, updated_at
		 FROM users WHERE email = ?`, email).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.DisplayName, &user.AvatarURL, &user.Status,
		&user.LastSeen, &user.CreatedAt, &user.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found")
	}
	return user, err
}

func (r *Repository) GetByUsername(ctx context.Context, username string) (*User, error) {
	user := &User{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, username, email, password_hash, COALESCE(display_name,''), COALESCE(avatar_url,''),
		        status, COALESCE(last_seen,'0001-01-01'), created_at, updated_at
		 FROM users WHERE username = ?`, username).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.DisplayName, &user.AvatarURL, &user.Status,
		&user.LastSeen, &user.CreatedAt, &user.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found")
	}
	return user, err
}

func (r *Repository) Update(ctx context.Context, user *User) error {
	user.UpdatedAt = time.Now().UTC()
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET display_name = ?, avatar_url = ?, status = ?, updated_at = ? WHERE id = ?`,
		user.DisplayName, user.AvatarURL, user.Status, user.UpdatedAt, user.ID)
	return err
}

func (r *Repository) UpdateStatus(ctx context.Context, userID, status string) error {
	now := time.Now().UTC()
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET status = ?, last_seen = ?, updated_at = ? WHERE id = ?`,
		status, now, now, userID)
	return err
}

func (r *Repository) Search(ctx context.Context, query string, limit int) ([]User, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT id, username, email, '', COALESCE(display_name,''), COALESCE(avatar_url,''),
		        status, COALESCE(last_seen,'0001-01-01'), created_at, updated_at
		 FROM users
		 WHERE username LIKE ? OR display_name LIKE ? OR email LIKE ?
		 LIMIT ?`,
		"%"+query+"%", "%"+query+"%", "%"+query+"%", limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var u User
		if err := rows.Scan(
			&u.ID, &u.Username, &u.Email, &u.PasswordHash,
			&u.DisplayName, &u.AvatarURL, &u.Status,
			&u.LastSeen, &u.CreatedAt, &u.UpdatedAt); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	return users, nil
}
