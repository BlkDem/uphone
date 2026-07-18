package chat

import (
	"testing"
	"time"
)

func TestChatModel(t *testing.T) {
	chat := &Chat{
		ID:        "chat-1",
		Type:      ChatTypePersonal,
		CreatedBy: "user-1",
		CreatedAt: time.Now(),
	}

	if chat.Type != ChatTypePersonal {
		t.Errorf("expected personal chat type, got %s", chat.Type)
	}
}

func TestChatTypes(t *testing.T) {
	tests := []struct {
		name     string
		chatType ChatType
	}{
		{"personal", ChatTypePersonal},
		{"group", ChatTypeGroup},
		{"channel", ChatTypeChannel},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			chat := &Chat{Type: tt.chatType}
			if string(chat.Type) != tt.name {
				t.Errorf("expected %s, got %s", tt.name, string(chat.Type))
			}
		})
	}
}

func TestMessageModel(t *testing.T) {
	msg := &Message{
		ID:       "msg-1",
		ChatID:   "chat-1",
		SenderID: "user-1",
		Content:  "Hello World",
		Type:     "text",
	}

	if msg.Type != "text" {
		t.Errorf("expected text type, got %s", msg.Type)
	}
	if msg.Content != "Hello World" {
		t.Errorf("expected Hello World, got %s", msg.Content)
	}
}

func TestSenderModel(t *testing.T) {
	sender := &Sender{
		ID:          "user-1",
		Username:    "testuser",
		DisplayName: "Test User",
		AvatarURL:   "https://example.com/avatar.jpg",
	}

	if sender.Username != "testuser" {
		t.Errorf("expected testuser, got %s", sender.Username)
	}
}

func TestCreateChatRequest(t *testing.T) {
	req := CreateChatRequest{
		Type:    ChatTypeGroup,
		Name:    "My Group",
		Members: []string{"user-1", "user-2", "user-3"},
	}

	if len(req.Members) != 3 {
		t.Errorf("expected 3 members, got %d", len(req.Members))
	}
}

func TestSendMessageRequest(t *testing.T) {
	req := SendMessageRequest{
		Content: "Hello",
		Type:    "text",
		ReplyTo: "msg-1",
	}

	if req.ReplyTo != "msg-1" {
		t.Errorf("expected reply to msg-1, got %s", req.ReplyTo)
	}
}
