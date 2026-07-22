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
	if user.Role == "" {
		user.Role = "user"
	}

	_, err := r.db.ExecContext(ctx,
		`INSERT INTO users (id, username, email, password_hash, google_id, display_name, avatar_url, role, status, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		user.ID, user.Username, user.Email, user.PasswordHash,
		user.GoogleID, user.DisplayName, user.AvatarURL, user.Role, "offline", user.CreatedAt, user.UpdatedAt)

	return err
}

func (r *Repository) GetByID(ctx context.Context, id string) (*User, error) {
	user := &User{}
	var lastSeen sql.NullTime
	err := r.db.QueryRowContext(ctx,
		`SELECT id, username, email, password_hash, google_id, COALESCE(display_name,''), COALESCE(avatar_url,''),
		        COALESCE(role,'user'), status, last_seen, created_at, updated_at
		 FROM users WHERE id = ?`, id).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.GoogleID, &user.DisplayName, &user.AvatarURL, &user.Role, &user.Status,
		&lastSeen, &user.CreatedAt, &user.UpdatedAt)
	if lastSeen.Valid {
		user.LastSeen = lastSeen.Time
	}

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found")
	}
	return user, err
}

func (r *Repository) GetByEmail(ctx context.Context, email string) (*User, error) {
	user := &User{}
	var lastSeen sql.NullTime
	err := r.db.QueryRowContext(ctx,
		`SELECT id, username, email, password_hash, google_id, COALESCE(display_name,''), COALESCE(avatar_url,''),
		        COALESCE(role,'user'), status, last_seen, created_at, updated_at
		 FROM users WHERE email = ?`, email).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.GoogleID, &user.DisplayName, &user.AvatarURL, &user.Role, &user.Status,
		&lastSeen, &user.CreatedAt, &user.UpdatedAt)
	if lastSeen.Valid {
		user.LastSeen = lastSeen.Time
	}

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found")
	}
	return user, err
}

func (r *Repository) GetByUsername(ctx context.Context, username string) (*User, error) {
	user := &User{}
	var lastSeen sql.NullTime
	err := r.db.QueryRowContext(ctx,
		`SELECT id, username, email, password_hash, google_id, COALESCE(display_name,''), COALESCE(avatar_url,''),
		        COALESCE(role,'user'), status, last_seen, created_at, updated_at
		 FROM users WHERE username = ?`, username).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.GoogleID, &user.DisplayName, &user.AvatarURL, &user.Role, &user.Status,
		&lastSeen, &user.CreatedAt, &user.UpdatedAt)
	if lastSeen.Valid {
		user.LastSeen = lastSeen.Time
	}

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
		`SELECT id, username, email, '', google_id, COALESCE(display_name,''), COALESCE(avatar_url,''),
		        COALESCE(role,'user'), status, last_seen, created_at, updated_at
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
		var lastSeen sql.NullTime
		if err := rows.Scan(
			&u.ID, &u.Username, &u.Email, &u.PasswordHash,
			&u.GoogleID, &u.DisplayName, &u.AvatarURL, &u.Role, &u.Status,
			&lastSeen, &u.CreatedAt, &u.UpdatedAt); err != nil {
			return nil, err
		}
		if lastSeen.Valid {
			u.LastSeen = lastSeen.Time
		}
		users = append(users, u)
	}
	return users, nil
}

func (r *Repository) GetByGoogleID(ctx context.Context, googleID string) (*User, error) {
	user := &User{}
	var lastSeen sql.NullTime
	err := r.db.QueryRowContext(ctx,
		`SELECT id, username, email, password_hash, google_id, COALESCE(display_name,''), COALESCE(avatar_url,''),
		        COALESCE(role,'user'), status, last_seen, created_at, updated_at
		 FROM users WHERE google_id = ?`, googleID).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.GoogleID, &user.DisplayName, &user.AvatarURL, &user.Role, &user.Status,
		&lastSeen, &user.CreatedAt, &user.UpdatedAt)
	if lastSeen.Valid {
		user.LastSeen = lastSeen.Time
	}

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("user not found")
	}
	return user, err
}

func (r *Repository) LinkGoogleID(ctx context.Context, userID, googleID string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET google_id = ?, updated_at = ? WHERE id = ?`,
		googleID, time.Now().UTC(), userID)
	return err
}

func (r *Repository) UpdatePassword(ctx context.Context, userID, passwordHash string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?`,
		passwordHash, time.Now().UTC(), userID)
	return err
}

func (r *Repository) UpdateRole(ctx context.Context, userID, role string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET role = ?, updated_at = ? WHERE id = ?`,
		role, time.Now().UTC(), userID)
	return err
}

func (r *Repository) Delete(ctx context.Context, userID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM users WHERE id = ?`, userID)
	return err
}

func (r *Repository) UpdateFCMToken(ctx context.Context, userID, fcmToken string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET fcm_token = ?, updated_at = ? WHERE id = ?`,
		fcmToken, time.Now().UTC(), userID)
	return err
}

func (r *Repository) GetFCMToken(ctx context.Context, userID string) (string, error) {
	var token sql.NullString
	err := r.db.QueryRowContext(ctx,
		`SELECT fcm_token FROM users WHERE id = ?`, userID).Scan(&token)
	if err != nil {
		return "", err
	}
	if token.Valid {
		return token.String, nil
	}
	return "", nil
}

func (r *Repository) ListAll(ctx context.Context) ([]User, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT id, username, email, '', google_id, COALESCE(display_name,''), COALESCE(avatar_url,''),
		        COALESCE(role,'user'), status, last_seen, created_at, updated_at
		 FROM users ORDER BY created_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var u User
		var lastSeen sql.NullTime
		if err := rows.Scan(
			&u.ID, &u.Username, &u.Email, &u.PasswordHash,
			&u.GoogleID, &u.DisplayName, &u.AvatarURL, &u.Role, &u.Status,
			&lastSeen, &u.CreatedAt, &u.UpdatedAt); err != nil {
			return nil, err
		}
		if lastSeen.Valid {
			u.LastSeen = lastSeen.Time
		}
		users = append(users, u)
	}
	return users, nil
}
