package chat

import "time"

type ChatType string

const (
	ChatTypePersonal ChatType = "personal"
	ChatTypeGroup   ChatType = "group"
	ChatTypeChannel ChatType = "channel"
)

type Chat struct {
	ID          string    `json:"id"`
	Type        ChatType  `json:"type"`
	Name        string    `json:"name,omitempty"`
	Description string    `json:"description,omitempty"`
	AvatarURL   string    `json:"avatar_url,omitempty"`
	CreatedBy   string    `json:"created_by"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	Members     []Member  `json:"members,omitempty"`
	LastMessage *Message  `json:"last_message,omitempty"`
	UnreadCount int       `json:"unread_count"`
}

type Member struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	Role     string `json:"role"`
}

type CreateChatRequest struct {
	Type    ChatType `json:"type"`
	Name    string   `json:"name,omitempty"`
	Members []string `json:"members"`
}

type UpdateChatRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	AvatarURL   *string `json:"avatar_url"`
}

type Message struct {
	ID        string    `json:"id"`
	ChatID    string    `json:"chat_id"`
	SenderID  string    `json:"sender_id"`
	Content   string    `json:"content"`
	Type      string    `json:"type"`
	FileURL   string    `json:"file_url,omitempty"`
	ReplyTo   string    `json:"reply_to,omitempty"`
	IsPinned  bool      `json:"is_pinned"`
	IsDeleted bool      `json:"is_deleted"`
	Status    string    `json:"status,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Sender    *Sender   `json:"sender,omitempty"`
}

type Sender struct {
	ID          string `json:"id"`
	Username    string `json:"username"`
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url"`
}

type SendMessageRequest struct {
	Content string `json:"content"`
	Type    string `json:"type"`
	FileURL string `json:"file_url,omitempty"`
	ReplyTo string `json:"reply_to,omitempty"`
}

type EditMessageRequest struct {
	Content string `json:"content"`
}

type ReactionRequest struct {
	Emoji string `json:"emoji"`
}
