package contacts

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/google/uuid"
)

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Create(ctx context.Context, ownerID string, req CreateContactRequest) (*Contact, error) {
	c := &Contact{
		ID:          uuid.New().String(),
		OwnerID:     ownerID,
		DisplayName: req.DisplayName,
		Email:       req.Email,
		Phone:       req.Phone,
		Notes:       req.Notes,
		AvatarURL:   req.AvatarURL,
	}

	_, err := r.db.ExecContext(ctx,
		`INSERT INTO contacts (id, owner_id, display_name, email, phone, notes, avatar_url)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		c.ID, c.OwnerID, c.DisplayName, c.Email, c.Phone, c.Notes, c.AvatarURL,
	)
	if err != nil {
		return nil, fmt.Errorf("insert contact: %w", err)
	}

	return c, nil
}

func (r *Repository) GetByID(ctx context.Context, id string) (*Contact, error) {
	c := &Contact{}
	var contactUserID sql.NullString
	var email, phone, notes, avatarURL sql.NullString

	err := r.db.QueryRowContext(ctx,
		`SELECT id, owner_id, contact_user_id, display_name, email, phone, notes, avatar_url, created_at, updated_at
		 FROM contacts WHERE id = ?`, id,
	).Scan(&c.ID, &c.OwnerID, &contactUserID, &c.DisplayName, &email, &phone, &notes, &avatarURL, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("get contact: %w", err)
	}

	c.ContactUserID = nullStringPtr(contactUserID)
	c.Email = nullStringPtr(email)
	c.Phone = nullStringPtr(phone)
	c.Notes = nullStringPtr(notes)
	c.AvatarURL = nullStringPtr(avatarURL)
	return c, nil
}

func (r *Repository) List(ctx context.Context, ownerID, query string) ([]Contact, error) {
	var rows *sql.Rows
	var err error

	if query != "" {
		like := "%" + strings.ToLower(query) + "%"
		rows, err = r.db.QueryContext(ctx,
			`SELECT id, owner_id, contact_user_id, display_name, email, phone, notes, avatar_url, created_at, updated_at
			 FROM contacts WHERE owner_id = ? AND (LOWER(display_name) LIKE ? OR LOWER(email) LIKE ? OR LOWER(phone) LIKE ?)
			 ORDER BY display_name`, ownerID, like, like, like,
		)
	} else {
		rows, err = r.db.QueryContext(ctx,
			`SELECT id, owner_id, contact_user_id, display_name, email, phone, notes, avatar_url, created_at, updated_at
			 FROM contacts WHERE owner_id = ?
			 ORDER BY display_name`, ownerID,
		)
	}
	if err != nil {
		return nil, fmt.Errorf("list contacts: %w", err)
	}
	defer rows.Close()

	var contacts []Contact
	for rows.Next() {
		var c Contact
		var contactUserID, email, phone, notes, avatarURL sql.NullString
		if err := rows.Scan(&c.ID, &c.OwnerID, &contactUserID, &c.DisplayName, &email, &phone, &notes, &avatarURL, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan contact: %w", err)
		}
		c.ContactUserID = nullStringPtr(contactUserID)
		c.Email = nullStringPtr(email)
		c.Phone = nullStringPtr(phone)
		c.Notes = nullStringPtr(notes)
		c.AvatarURL = nullStringPtr(avatarURL)
		contacts = append(contacts, c)
	}
	return contacts, nil
}

func (r *Repository) Update(ctx context.Context, id string, req UpdateContactRequest) (*Contact, error) {
	c, err := r.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if req.DisplayName != nil {
		c.DisplayName = *req.DisplayName
	}
	if req.Email != nil {
		c.Email = req.Email
	}
	if req.Phone != nil {
		c.Phone = req.Phone
	}
	if req.Notes != nil {
		c.Notes = req.Notes
	}
	if req.AvatarURL != nil {
		c.AvatarURL = req.AvatarURL
	}

	_, err = r.db.ExecContext(ctx,
		`UPDATE contacts SET display_name = ?, email = ?, phone = ?, notes = ?, avatar_url = ? WHERE id = ?`,
		c.DisplayName, c.Email, c.Phone, c.Notes, c.AvatarURL, id,
	)
	if err != nil {
		return nil, fmt.Errorf("update contact: %w", err)
	}

	return c, nil
}

func (r *Repository) Delete(ctx context.Context, id string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM contacts WHERE id = ?`, id)
	if err != nil {
		return fmt.Errorf("delete contact: %w", err)
	}
	return nil
}

func (r *Repository) BulkCreate(ctx context.Context, ownerID string, contacts []CreateContactRequest) (int, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	stmt, err := tx.PrepareContext(ctx,
		`INSERT INTO contacts (id, owner_id, display_name, email, phone, notes, avatar_url)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
	)
	if err != nil {
		return 0, fmt.Errorf("prepare: %w", err)
	}
	defer stmt.Close()

	count := 0
	for _, req := range contacts {
		if strings.TrimSpace(req.DisplayName) == "" {
			continue
		}
		id := uuid.New().String()
		if _, err := stmt.ExecContext(ctx, id, ownerID, req.DisplayName, req.Email, req.Phone, req.Notes, req.AvatarURL); err != nil {
			return count, fmt.Errorf("insert contact %q: %w", req.DisplayName, err)
		}
		count++
	}

	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("commit: %w", err)
	}
	return count, nil
}

func nullStringPtr(ns sql.NullString) *string {
	if ns.Valid {
		return &ns.String
	}
	return nil
}
