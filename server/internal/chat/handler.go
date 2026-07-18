package chat

import (
	"context"
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type Handler struct {
	repo *Repository
	hub  *Hub
}

func NewHandler(repo *Repository, hub *Hub) *Handler {
	return &Handler{repo: repo, hub: hub}
}

func (h *Handler) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	userID, _ := r.Context().Value("user_id").(string)
	if userID == "" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("websocket upgrade error: %v", err)
		return
	}

	client := &Client{
		hub:    h.hub,
		conn:   conn,
		userID: userID,
		send:   make(chan []byte, 256),
	}

	h.hub.register <- client
	go client.WritePump()
	go client.ReadPump(h.hub, h.handleWSMessage)
}

func (h *Handler) handleWSMessage(userID string, msgType string, raw json.RawMessage) {
	ctx := context.Background()
	switch msgType {
	case "message.send":
		var req struct {
			ChatID  string `json:"chatId"`
			Content string `json:"content"`
			ReplyTo string `json:"replyTo"`
		}
		if err := json.Unmarshal(raw, &req); err != nil {
			return
		}
		h.handleSendMessage(ctx, userID, req.ChatID, req.Content, req.ReplyTo)

	case "typing.start":
		var req struct {
			ChatID string `json:"chatId"`
		}
		if err := json.Unmarshal(raw, &req); err != nil {
			return
		}
		h.hub.BroadcastToAll(&Envelope{
			Type:    "typing.start",
			Payload: map[string]string{"chatId": req.ChatID, "userId": userID},
		})

	case "typing.stop":
		var req struct {
			ChatID string `json:"chatId"`
		}
		if err := json.Unmarshal(raw, &req); err != nil {
			return
		}
		h.hub.BroadcastToAll(&Envelope{
			Type:    "typing.stop",
			Payload: map[string]string{"chatId": req.ChatID, "userId": userID},
		})

	case "message.read":
		var req struct {
			ChatID string `json:"chatId"`
			MsgID  string `json:"msgId"`
		}
		if err := json.Unmarshal(raw, &req); err != nil {
			return
		}
		_ = req
	}
}

func (h *Handler) handleSendMessage(ctx context.Context, senderID, chatID, content, replyTo string) {
	isMember, err := h.repo.IsMember(ctx, chatID, senderID)
	if err != nil || !isMember {
		return
	}

	msg := &Message{
		ChatID:   chatID,
		SenderID: senderID,
		Content:  content,
		ReplyTo:  replyTo,
	}

	if err := h.repo.SendMessage(ctx, msg); err != nil {
		log.Printf("send message error: %v", err)
		return
	}

	sender, _ := h.repo.getSenderInfo(ctx, senderID)
	if sender != nil {
		msg.Sender = sender
	}

	members, err := h.repo.GetMembers(ctx, chatID)
	if err != nil {
		return
	}

	userIDs := make([]string, len(members))
	for i, m := range members {
		userIDs[i] = m.UserID
	}

	h.hub.BroadcastToUsers(userIDs, &Envelope{
		Type:    "message.new",
		Payload: msg,
	})
}
