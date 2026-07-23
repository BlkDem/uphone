package chat

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"github.com/uphone/server/internal/fcm"
	"github.com/uphone/server/internal/middleware"
	"github.com/uphone/server/internal/shared"
	"github.com/uphone/server/internal/users"
)

type APIHandler struct {
	repo     *Repository
	userRepo *users.Repository
	hub      *Hub
	fcm      *fcm.Service
}

func NewAPIHandler(repo *Repository, userRepo *users.Repository, hub *Hub, fcm *fcm.Service) *APIHandler {
	return &APIHandler{repo: repo, userRepo: userRepo, hub: hub, fcm: fcm}
}

func (h *APIHandler) resolveMembers(r *http.Request, members []string, selfID string) ([]string, error) {
	resolved := make([]string, 0, len(members))
	for _, m := range members {
		if strings.Contains(m, "@") {
			user, err := h.userRepo.GetByEmail(r.Context(), m)
			if err != nil {
				return nil, err
			}
			resolved = append(resolved, user.ID)
		} else {
			resolved = append(resolved, m)
		}
	}
	return resolved, nil
}

func (h *APIHandler) CreateChat(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var req CreateChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Type == "" {
		shared.WriteError(w, http.StatusBadRequest, "type is required")
		return
	}

	resolvedMembers, err := h.resolveMembers(r, req.Members, userID)
	if err != nil {
		shared.WriteError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.Type == ChatTypePersonal {
		if len(resolvedMembers) != 1 {
			shared.WriteError(w, http.StatusBadRequest, "personal chat requires exactly 1 other member")
			return
		}
		existing, _ := h.repo.GetPersonalChat(r.Context(), userID, resolvedMembers[0])
		if existing != nil {
			shared.WriteJSON(w, http.StatusOK, existing)
			return
		}
	}

	chat := &Chat{
		Type:      req.Type,
		Name:      req.Name,
		CreatedBy: userID,
		Members:   make([]Member, 0),
	}

	chat.Members = append(chat.Members, Member{UserID: userID})
	for _, memberID := range resolvedMembers {
		if memberID != userID {
			chat.Members = append(chat.Members, Member{UserID: memberID})
		}
	}

	if err := h.repo.CreateChat(r.Context(), chat); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to create chat")
		return
	}

	shared.WriteJSON(w, http.StatusCreated, chat)
}

func (h *APIHandler) GetChats(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)

	chats, err := h.repo.GetUserChats(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to get chats")
		return
	}

	if chats == nil {
		chats = []Chat{}
	}

	shared.WriteJSON(w, http.StatusOK, chats)
}

func (h *APIHandler) GetChat(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	chatID := r.PathValue("id")

	isMember, err := h.repo.IsMember(r.Context(), chatID, userID)
	if err != nil || !isMember {
		shared.WriteError(w, http.StatusForbidden, "not a member")
		return
	}

	chat, err := h.repo.GetByID(r.Context(), chatID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "chat not found")
		return
	}

	shared.WriteJSON(w, http.StatusOK, chat)
}

func (h *APIHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	chatID := r.PathValue("id")

	isMember, err := h.repo.IsMember(r.Context(), chatID, userID)
	if err != nil || !isMember {
		shared.WriteError(w, http.StatusForbidden, "not a member")
		return
	}

	var req SendMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Content == "" && req.FileURL == "" {
		shared.WriteError(w, http.StatusBadRequest, "content or file_url is required")
		return
	}

	msg := &Message{
		ChatID:   chatID,
		SenderID: userID,
		Content:  req.Content,
		Type:     req.Type,
		FileURL:  req.FileURL,
		ReplyTo:  req.ReplyTo,
	}

	if err := h.repo.SendMessage(r.Context(), msg); err != nil {
		log.Printf("SendMessage error: chatID=%s userID=%s err=%v", chatID, userID, err)
		shared.WriteError(w, http.StatusInternalServerError, "failed to send message")
		return
	}

	sender, _ := h.repo.getSenderInfo(r.Context(), userID)
	if sender != nil {
		msg.Sender = sender
	}

	members, err := h.repo.GetMembers(r.Context(), chatID)
	if err == nil && len(members) > 0 {
		userIDs := make([]string, len(members))
		for i, m := range members {
			userIDs[i] = m.UserID
		}
		h.hub.BroadcastToUsers(userIDs, &Envelope{
			Type:    "message.new",
			Payload: msg,
		})

		senderName := ""
		if sender != nil {
			senderName = sender.DisplayName
			if senderName == "" {
				senderName = sender.Username
			}
		}
		chatName := ""
		if chat, err := h.repo.GetByID(r.Context(), chatID); err == nil {
			chatName = chat.Name
		}
		for _, uid := range userIDs {
			if uid == userID {
				continue
			}
			h.fcm.SendMessageNotification(r.Context(), h.repo.db, uid, &fcm.MessageNotification{
				SenderName: senderName,
				ChatName:   chatName,
				Content:    req.Content,
				ChatID:     chatID,
			})
		}
	}

	shared.WriteJSON(w, http.StatusCreated, msg)
}

func (h *APIHandler) GetMessages(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	chatID := r.PathValue("id")

	isMember, err := h.repo.IsMember(r.Context(), chatID, userID)
	if err != nil || !isMember {
		shared.WriteError(w, http.StatusForbidden, "not a member")
		return
	}

	messages, err := h.repo.GetMessages(r.Context(), chatID, 50, 0)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to get messages")
		return
	}

	if messages == nil {
		messages = []Message{}
	}

	shared.WriteJSON(w, http.StatusOK, messages)
}

func (h *APIHandler) EditMessage(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	msgID := r.PathValue("msgId")

	msg, err := h.repo.GetMessageByID(r.Context(), msgID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "message not found")
		return
	}

	if msg.SenderID != userID {
		shared.WriteError(w, http.StatusForbidden, "not your message")
		return
	}

	var req EditMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if err := h.repo.EditMessage(r.Context(), msgID, req.Content); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to edit message")
		return
	}

	msg.Content = req.Content
	shared.WriteJSON(w, http.StatusOK, msg)
}

func (h *APIHandler) DeleteMessage(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	msgID := r.PathValue("msgId")

	msg, err := h.repo.GetMessageByID(r.Context(), msgID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "message not found")
		return
	}

	if msg.SenderID != userID {
		shared.WriteError(w, http.StatusForbidden, "not your message")
		return
	}

	if err := h.repo.DeleteMessage(r.Context(), msgID); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to delete message")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}

func (h *APIHandler) AddReaction(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	msgID := r.PathValue("msgId")

	var req ReactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if err := h.repo.AddReaction(r.Context(), msgID, userID, req.Emoji); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to add reaction")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "reaction added"})
}

func (h *APIHandler) UpdateChat(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	chatID := r.PathValue("id")

	role, err := h.repo.GetMemberRole(r.Context(), chatID, userID)
	if err != nil || (role != "owner" && role != "admin") {
		shared.WriteError(w, http.StatusForbidden, "not authorized")
		return
	}

	var req UpdateChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	chat, err := h.repo.GetByID(r.Context(), chatID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "chat not found")
		return
	}

	if req.Name != nil {
		chat.Name = *req.Name
	}
	if req.Description != nil {
		chat.Description = *req.Description
	}
	if req.AvatarURL != nil {
		chat.AvatarURL = *req.AvatarURL
	}

	if err := h.repo.UpdateChat(r.Context(), chat); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to update chat")
		return
	}

	shared.WriteJSON(w, http.StatusOK, chat)
}

func (h *APIHandler) AddMember(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	chatID := r.PathValue("id")

	chat, err := h.repo.GetByID(r.Context(), chatID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "chat not found")
		return
	}

	if chat.Type == ChatTypePersonal {
		shared.WriteError(w, http.StatusBadRequest, "cannot add members to personal chat")
		return
	}

	callerRole, err := h.repo.GetMemberRole(r.Context(), chatID, userID)
	if err != nil || (callerRole != "owner" && callerRole != "admin") {
		shared.WriteError(w, http.StatusForbidden, "not authorized to add members")
		return
	}

	var req struct {
		UserID string `json:"user_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if err := h.repo.AddMember(r.Context(), chatID, req.UserID, "member"); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to add member")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "member added"})
}

func (h *APIHandler) RemoveMember(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	chatID := r.PathValue("id")
	targetID := r.PathValue("memberId")

	chat, err := h.repo.GetByID(r.Context(), chatID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "chat not found")
		return
	}

	if chat.Type == ChatTypePersonal {
		shared.WriteError(w, http.StatusBadRequest, "cannot remove members from personal chat")
		return
	}

	callerRole, err := h.repo.GetMemberRole(r.Context(), chatID, userID)
	if err != nil {
		shared.WriteError(w, http.StatusForbidden, "not authorized")
		return
	}

	targetRole, err := h.repo.GetMemberRole(r.Context(), chatID, targetID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "member not found")
		return
	}

	if targetRole == "owner" {
		shared.WriteError(w, http.StatusForbidden, "cannot remove the owner")
		return
	}

	if callerRole != "owner" && callerRole != "admin" {
		shared.WriteError(w, http.StatusForbidden, "not authorized to remove members")
		return
	}

	if callerRole == "admin" && targetRole == "admin" {
		shared.WriteError(w, http.StatusForbidden, "admins cannot remove other admins")
		return
	}

	if err := h.repo.RemoveMember(r.Context(), chatID, targetID); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to remove member")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "member removed"})
}

func (h *APIHandler) LeaveChat(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	chatID := r.PathValue("id")

	chat, err := h.repo.GetByID(r.Context(), chatID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "chat not found")
		return
	}

	if chat.Type == ChatTypePersonal {
		shared.WriteError(w, http.StatusBadRequest, "cannot leave personal chat")
		return
	}

	role, _ := h.repo.GetMemberRole(r.Context(), chatID, userID)
	if role == "owner" {
		shared.WriteError(w, http.StatusBadRequest, "owner cannot leave. Transfer ownership or delete.")
		return
	}

	if err := h.repo.RemoveMember(r.Context(), chatID, userID); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to leave chat")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "left chat"})
}

func (h *APIHandler) GetMembers(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	chatID := r.PathValue("id")

	isMember, err := h.repo.IsMember(r.Context(), chatID, userID)
	if err != nil || !isMember {
		shared.WriteError(w, http.StatusForbidden, "not a member")
		return
	}

	members, err := h.repo.GetMembers(r.Context(), chatID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to get members")
		return
	}

	if members == nil {
		members = []Member{}
	}

	shared.WriteJSON(w, http.StatusOK, members)
}

func (h *APIHandler) DeleteChat(w http.ResponseWriter, r *http.Request) {
	userID := 	middleware.GetUserID(r)
	chatID := r.PathValue("id")

	role, err := h.repo.GetMemberRole(r.Context(), chatID, userID)
	if err != nil || role != "owner" {
		shared.WriteError(w, http.StatusForbidden, "only owner can delete chat")
		return
	}

	if err := h.repo.DeleteChat(r.Context(), chatID); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to delete chat")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "chat deleted"})
}

func (h *APIHandler) MarkAsRead(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	chatID := r.PathValue("id")

	isMember, err := h.repo.IsMember(r.Context(), chatID, userID)
	if err != nil || !isMember {
		shared.WriteError(w, http.StatusForbidden, "not a member")
		return
	}

	var req struct {
		MessageID string `json:"message_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if err := h.repo.MarkAsRead(r.Context(), chatID, userID, req.MessageID); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to mark as read")
		return
	}

	// Broadcast read receipt to other members
	members, err := h.repo.GetMembers(r.Context(), chatID)
	if err == nil {
		for _, m := range members {
			if m.UserID != userID {
				h.hub.SendToUser(m.UserID, mustMarshal(&Envelope{
					Type:    "message.read",
					Payload: map[string]string{"chatId": chatID, "userId": userID, "messageId": req.MessageID},
				}))
			}
		}
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func mustMarshal(v interface{}) []byte {
	data, _ := json.Marshal(v)
	return data
}

func (h *APIHandler) GetMediaMessages(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	chatID := r.PathValue("id")

	isMember, err := h.repo.IsMember(r.Context(), chatID, userID)
	if err != nil || !isMember {
		shared.WriteError(w, http.StatusForbidden, "not a member")
		return
	}

	mediaType := r.URL.Query().Get("type")
	limit := 50
	offset := 0

	messages, err := h.repo.GetMediaMessages(r.Context(), chatID, mediaType, limit, offset)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to get media messages")
		return
	}

	if messages == nil {
		messages = []Message{}
	}

	shared.WriteJSON(w, http.StatusOK, messages)
}

func (h *APIHandler) ForwardMessage(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	chatID := r.PathValue("id")
	msgID := r.PathValue("msgId")

	isMember, err := h.repo.IsMember(r.Context(), chatID, userID)
	if err != nil || !isMember {
		shared.WriteError(w, http.StatusForbidden, "not a member")
		return
	}

	msg, err := h.repo.GetMessageByID(r.Context(), msgID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "message not found")
		return
	}

	var req struct {
		ChatID string `json:"chat_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	isTargetMember, err := h.repo.IsMember(r.Context(), req.ChatID, userID)
	if err != nil || !isTargetMember {
		shared.WriteError(w, http.StatusForbidden, "not a member of target chat")
		return
	}

	newMsg := &Message{
		SenderID: userID,
		Content:  msg.Content,
		Type:     msg.Type,
		FileURL:  msg.FileURL,
	}

	if err := h.repo.ForwardMessage(r.Context(), req.ChatID, newMsg); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to forward message")
		return
	}

	sender, _ := h.repo.getSenderInfo(r.Context(), userID)
	if sender != nil {
		newMsg.Sender = sender
	}

	members, err := h.repo.GetMembers(r.Context(), req.ChatID)
	if err == nil && len(members) > 0 {
		userIDs := make([]string, len(members))
		for i, m := range members {
			userIDs[i] = m.UserID
		}
		h.hub.BroadcastToUsers(userIDs, &Envelope{
			Type:    "message.new",
			Payload: newMsg,
		})

		senderName := ""
		if sender != nil {
			senderName = sender.DisplayName
			if senderName == "" {
				senderName = sender.Username
			}
		}
		chatName := ""
		if chat, err := h.repo.GetByID(r.Context(), req.ChatID); err == nil {
			chatName = chat.Name
		}
		content := msg.Content
		if len(content) > 200 {
			content = content[:200] + "..."
		}
		for _, uid := range userIDs {
			if uid == userID {
				continue
			}
			h.fcm.SendMessageNotification(r.Context(), h.repo.db, uid, &fcm.MessageNotification{
				SenderName: senderName,
				ChatName:   chatName,
				Content:    content,
				ChatID:     req.ChatID,
			})
		}
	}

	shared.WriteJSON(w, http.StatusCreated, newMsg)
}
