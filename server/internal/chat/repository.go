package chat

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

func (r *Repository) CreateChat(ctx context.Context, chat *Chat) error {
	chat.ID = uuid.New().String()
	chat.CreatedAt = time.Now().UTC()
	chat.UpdatedAt = time.Now().UTC()

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.ExecContext(ctx,
		`INSERT INTO chats (id, type, name, description, avatar_url, created_by, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		chat.ID, string(chat.Type), chat.Name, chat.Description, chat.AvatarURL,
		chat.CreatedBy, chat.CreatedAt, chat.UpdatedAt)
	if err != nil {
		return fmt.Errorf("insert chat: %w", err)
	}

	for i, member := range chat.Members {
		role := "member"
		if i == 0 {
			role = "owner"
		}
		_, err = tx.ExecContext(ctx,
			`INSERT INTO chat_members (chat_id, user_id, role, joined_at) VALUES (?, ?, ?, ?)`,
			chat.ID, member.UserID, role, time.Now().UTC())
		if err != nil {
			return fmt.Errorf("insert member: %w", err)
		}
	}

	return tx.Commit()
}

func (r *Repository) GetByID(ctx context.Context, chatID string) (*Chat, error) {
	chat := &Chat{}
	var chatType string
	var createdBy sql.NullString

	err := r.db.QueryRowContext(ctx,
		`SELECT id, type, COALESCE(name,''), COALESCE(description,''), COALESCE(avatar_url,''),
		        created_by, created_at, updated_at
		 FROM chats WHERE id = ?`, chatID).Scan(
		&chat.ID, &chatType, &chat.Name, &chat.Description, &chat.AvatarURL,
		&createdBy, &chat.CreatedAt, &chat.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("chat not found")
	}
	if err != nil {
		return nil, err
	}
	chat.Type = ChatType(chatType)
	if createdBy.Valid {
		chat.CreatedBy = createdBy.String
	}
	return chat, nil
}

func (r *Repository) GetUserChats(ctx context.Context, userID string) ([]Chat, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT c.id, c.type, COALESCE(c.name,''), COALESCE(c.description,''), COALESCE(c.avatar_url,''),
		        COALESCE(c.created_by,''), c.created_at, c.updated_at
		 FROM chats c
		 INNER JOIN chat_members cm ON c.id = cm.chat_id
		 WHERE cm.user_id = ?
		 ORDER BY c.updated_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var chats []Chat
	for rows.Next() {
		var c Chat
		var chatType string
		if err := rows.Scan(
			&c.ID, &chatType, &c.Name, &c.Description, &c.AvatarURL,
			&c.CreatedBy, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		c.Type = ChatType(chatType)
		chats = append(chats, c)
	}
	return chats, nil
}

func (r *Repository) GetPersonalChat(ctx context.Context, user1ID, user2ID string) (*Chat, error) {
	chat := &Chat{}
	var chatType string

	err := r.db.QueryRowContext(ctx,
		`SELECT c.id, c.type, COALESCE(c.name,''), COALESCE(c.description,''), COALESCE(c.avatar_url,''),
		        COALESCE(c.created_by,''), c.created_at, c.updated_at
		 FROM chats c
		 INNER JOIN chat_members cm1 ON c.id = cm1.chat_id AND cm1.user_id = ?
		 INNER JOIN chat_members cm2 ON c.id = cm2.chat_id AND cm2.user_id = ?
		 WHERE c.type = 'personal'`, user1ID, user2ID).Scan(
		&chat.ID, &chatType, &chat.Name, &chat.Description, &chat.AvatarURL,
		&chat.CreatedBy, &chat.CreatedAt, &chat.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("chat not found")
	}
	if err != nil {
		return nil, err
	}
	chat.Type = ChatType(chatType)
	return chat, nil
}

func (r *Repository) AddMember(ctx context.Context, chatID, userID, role string) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT IGNORE INTO chat_members (chat_id, user_id, role, joined_at) VALUES (?, ?, ?, ?)`,
		chatID, userID, role, time.Now().UTC())
	return err
}

func (r *Repository) RemoveMember(ctx context.Context, chatID, userID string) error {
	_, err := r.db.ExecContext(ctx,
		`DELETE FROM chat_members WHERE chat_id = ? AND user_id = ?`,
		chatID, userID)
	return err
}

func (r *Repository) IsMember(ctx context.Context, chatID, userID string) (bool, error) {
	var count int
	err := r.db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM chat_members WHERE chat_id = ? AND user_id = ?`,
		chatID, userID).Scan(&count)
	return count > 0, err
}

func (r *Repository) GetMembers(ctx context.Context, chatID string) ([]Member, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT cm.user_id, u.username, cm.role
		 FROM chat_members cm
		 INNER JOIN users u ON cm.user_id = u.id
		 WHERE cm.chat_id = ?`, chatID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []Member
	for rows.Next() {
		var m Member
		if err := rows.Scan(&m.UserID, &m.Username, &m.Role); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, nil
}

func (r *Repository) GetMemberRole(ctx context.Context, chatID, userID string) (string, error) {
	var role string
	err := r.db.QueryRowContext(ctx,
		`SELECT role FROM chat_members WHERE chat_id = ? AND user_id = ?`,
		chatID, userID).Scan(&role)
	if err == sql.ErrNoRows {
		return "", fmt.Errorf("not a member")
	}
	return role, err
}

func (r *Repository) UpdateChat(ctx context.Context, chat *Chat) error {
	chat.UpdatedAt = time.Now().UTC()
	_, err := r.db.ExecContext(ctx,
		`UPDATE chats SET name = ?, description = ?, avatar_url = ?, updated_at = ? WHERE id = ?`,
		chat.Name, chat.Description, chat.AvatarURL, chat.UpdatedAt, chat.ID)
	return err
}

func (r *Repository) DeleteChat(ctx context.Context, chatID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM chats WHERE id = ?`, chatID)
	return err
}

func (r *Repository) SendMessage(ctx context.Context, msg *Message) error {
	msg.ID = uuid.New().String()
	msg.CreatedAt = time.Now().UTC()
	msg.UpdatedAt = time.Now().UTC()
	if msg.Type == "" {
		msg.Type = "text"
	}

	var replyTo interface{} = nil
	if msg.ReplyTo != "" {
		replyTo = msg.ReplyTo
	}
	var fileURL interface{} = nil
	if msg.FileURL != "" {
		fileURL = msg.FileURL
	}

	_, err := r.db.ExecContext(ctx,
		`INSERT INTO messages (id, chat_id, sender_id, content, type, file_url, reply_to, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		msg.ID, msg.ChatID, msg.SenderID, msg.Content, msg.Type,
		fileURL, replyTo, msg.CreatedAt, msg.UpdatedAt)
	if err != nil {
		return fmt.Errorf("insert message: %w", err)
	}

	_, _ = r.db.ExecContext(ctx,
		`UPDATE chats SET updated_at = ? WHERE id = ?`,
		msg.UpdatedAt, msg.ChatID)

	return nil
}

func (r *Repository) GetMessages(ctx context.Context, chatID string, limit, offset int) ([]Message, error) {
	if limit <= 0 {
		limit = 50
	}

	rows, err := r.db.QueryContext(ctx,
		`SELECT m.id, m.chat_id, m.sender_id, COALESCE(m.content,''), m.type,
		        COALESCE(m.file_url,''), COALESCE(m.reply_to,''), m.is_pinned, m.is_deleted,
		        m.created_at, m.updated_at,
		        u.id, u.username, COALESCE(u.display_name,''), COALESCE(u.avatar_url,'')
		 FROM messages m
		 LEFT JOIN users u ON m.sender_id = u.id
		 WHERE m.chat_id = ?
		 ORDER BY m.created_at DESC
		 LIMIT ? OFFSET ?`, chatID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []Message
	for rows.Next() {
		var msg Message
		var senderID, username, displayName, avatarURL sql.NullString
		var replyTo sql.NullString

		if err := rows.Scan(
			&msg.ID, &msg.ChatID, &msg.SenderID, &msg.Content, &msg.Type,
			&msg.FileURL, &replyTo, &msg.IsPinned, &msg.IsDeleted,
			&msg.CreatedAt, &msg.UpdatedAt,
			&senderID, &username, &displayName, &avatarURL); err != nil {
			return nil, err
		}

		if replyTo.Valid {
			msg.ReplyTo = replyTo.String
		}
		if senderID.Valid {
			msg.Sender = &Sender{
				ID:          senderID.String,
				Username:    username.String,
				DisplayName: displayName.String,
				AvatarURL:   avatarURL.String,
			}
		}

		messages = append(messages, msg)
	}
	return messages, nil
}

func (r *Repository) GetMessageByID(ctx context.Context, msgID string) (*Message, error) {
	msg := &Message{}
	var replyTo sql.NullString

	err := r.db.QueryRowContext(ctx,
		`SELECT id, chat_id, sender_id, COALESCE(content,''), type,
		        COALESCE(file_url,''), reply_to, is_pinned, is_deleted, created_at, updated_at
		 FROM messages WHERE id = ?`, msgID).Scan(
		&msg.ID, &msg.ChatID, &msg.SenderID, &msg.Content, &msg.Type,
		&msg.FileURL, &replyTo, &msg.IsPinned, &msg.IsDeleted,
		&msg.CreatedAt, &msg.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("message not found")
	}
	if replyTo.Valid {
		msg.ReplyTo = replyTo.String
	}
	return msg, err
}

func (r *Repository) EditMessage(ctx context.Context, msgID, content string) error {
	result, err := r.db.ExecContext(ctx,
		`UPDATE messages SET content = ?, updated_at = ? WHERE id = ?`,
		content, time.Now().UTC(), msgID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("message not found")
	}
	return nil
}

func (r *Repository) DeleteMessage(ctx context.Context, msgID string) error {
	result, err := r.db.ExecContext(ctx,
		`UPDATE messages SET is_deleted = TRUE, content = '', updated_at = ? WHERE id = ?`,
		time.Now().UTC(), msgID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("message not found")
	}
	return nil
}

func (r *Repository) PinMessage(ctx context.Context, msgID string, pinned bool) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE messages SET is_pinned = ?, updated_at = ? WHERE id = ?`,
		pinned, time.Now().UTC(), msgID)
	return err
}

func (r *Repository) AddReaction(ctx context.Context, messageID, userID, emoji string) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT IGNORE INTO reactions (message_id, user_id, emoji, created_at) VALUES (?, ?, ?, ?)`,
		messageID, userID, emoji, time.Now().UTC())
	return err
}

func (r *Repository) RemoveReaction(ctx context.Context, messageID, userID, emoji string) error {
	_, err := r.db.ExecContext(ctx,
		`DELETE FROM reactions WHERE message_id = ? AND user_id = ? AND emoji = ?`,
		messageID, userID, emoji)
	return err
}

func (r *Repository) GetReactions(ctx context.Context, messageID string) (map[string]int, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT emoji, COUNT(*) as cnt FROM reactions WHERE message_id = ? GROUP BY emoji`,
		messageID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	reactions := make(map[string]int)
	for rows.Next() {
		var emoji string
		var cnt int
		if err := rows.Scan(&emoji, &cnt); err != nil {
			return nil, err
		}
		reactions[emoji] = cnt
	}
	return reactions, nil
}

func (r *Repository) getSenderInfo(_ context.Context, userID string) (*Sender, error) {
	s := &Sender{}
	err := r.db.QueryRow(
		`SELECT id, username, COALESCE(display_name,''), COALESCE(avatar_url,'')
		 FROM users WHERE id = ?`, userID).Scan(&s.ID, &s.Username, &s.DisplayName, &s.AvatarURL)
	if err != nil {
		return nil, err
	}
	return s, nil
}
