package chat

import (
	"context"
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"github.com/uphone/server/internal/fcm"
	"github.com/uphone/server/internal/middleware"
	"github.com/uphone/server/internal/users"
	"github.com/uphone/server/internal/webrtc"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type Handler struct {
	repo      *Repository
	hub       *Hub
	signalHub *webrtc.SignalHub
	fcm       *fcm.Service
	userRepo  *users.Repository
}

func NewHandler(repo *Repository, hub *Hub, signalHub *webrtc.SignalHub, fcm *fcm.Service, userRepo *users.Repository) *Handler {
	return &Handler{repo: repo, hub: hub, signalHub: signalHub, fcm: fcm, userRepo: userRepo}
}

func (h *Handler) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
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
	log.Printf("WS message: userID=%s type=%s", userID, msgType)
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
		h.handleReadMessage(ctx, userID, req.ChatID, req.MsgID)

    case "call-request", "call-accept", "call-reject", "call-end",
        "call-join", "call-leave",
        "offer", "answer", "ice-candidate":
        var sigMsg webrtc.SignalMessage
        if err := json.Unmarshal(raw, &sigMsg); err != nil {
            return
        }
        h.signalHub.HandleSignal(userID, &sigMsg, func(targetUserID string, data []byte) {
            h.hub.SendToUser(targetUserID, data)
            // Always send FCM push for incoming calls (for lock screen / background)
            if sigMsg.Type == "call-request" || sigMsg.Type == "call-invite" {
                var payload webrtc.CallRequestPayload
                if err := json.Unmarshal(sigMsg.Payload, &payload); err == nil {
                    h.fcm.SendCallNotification(context.Background(), h.repo.db, targetUserID, &fcm.CallNotification{
                        CallID:   sigMsg.CallID,
                        FromUser: userID,
                        FromName: payload.FromName,
                        CallType: payload.CallType,
                        IsGroup:  len(payload.Participants) > 0,
                        ChatName: "",
                    })
                }
            }
        })
	}
}

func (h *Handler) handleReadMessage(ctx context.Context, userID, chatID, msgID string) {
	if err := h.repo.MarkAsRead(ctx, chatID, userID, msgID); err != nil {
		log.Printf("mark read error: %v", err)
		return
	}
	members, err := h.repo.GetMembers(ctx, chatID)
	if err != nil {
		return
	}
	for _, m := range members {
		if m.UserID != userID {
			h.hub.SendToUser(m.UserID, mustMarshal(&Envelope{
				Type:    "message.read",
				Payload: map[string]string{"chatId": chatID, "userId": userID, "messageId": msgID},
			}))
		}
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

	// Send FCM push to offline members
	senderName := ""
	if sender != nil {
		senderName = sender.DisplayName
		if senderName == "" {
			senderName = sender.Username
		}
	}
	chatName := ""
	if chat, err := h.repo.GetByID(ctx, chatID); err == nil {
		chatName = chat.Name
	}
	for _, uid := range userIDs {
		if uid == senderID {
			continue
		}
		if !h.hub.IsOnline(uid) {
			h.fcm.SendMessageNotification(ctx, h.repo.db, uid, &fcm.MessageNotification{
				SenderName: senderName,
				ChatName:   chatName,
				Content:    content,
				ChatID:     chatID,
			})
		}
	}
}
