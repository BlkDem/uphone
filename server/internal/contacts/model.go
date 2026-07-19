package contacts

import "time"

type Contact struct {
	ID             string     `json:"id"`
	OwnerID        string     `json:"owner_id"`
	ContactUserID  *string    `json:"contact_user_id"`
	DisplayName    string     `json:"display_name"`
	Email          *string    `json:"email"`
	Phone          *string    `json:"phone"`
	Notes          *string    `json:"notes"`
	AvatarURL      *string    `json:"avatar_url"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

type CreateContactRequest struct {
	DisplayName string  `json:"display_name"`
	Email       *string `json:"email"`
	Phone       *string `json:"phone"`
	Notes       *string `json:"notes"`
	AvatarURL   *string `json:"avatar_url"`
}

type UpdateContactRequest struct {
	DisplayName *string `json:"display_name"`
	Email       *string `json:"email"`
	Phone       *string `json:"phone"`
	Notes       *string `json:"notes"`
	AvatarURL   *string `json:"avatar_url"`
}
