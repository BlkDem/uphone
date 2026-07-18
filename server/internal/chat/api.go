package chat

import (
	"encoding/json"
	"net/http"

	"github.com/uphone/server/internal/shared"
)

type APIHandler struct {
	repo *Repository
}

func NewAPIHandler(repo *Repository) *APIHandler {
	return &APIHandler{repo: repo}
}

func (h *APIHandler) CreateChat(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(string)

	var req CreateChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Type == "" {
		shared.WriteError(w, http.StatusBadRequest, "type is required")
		return
	}

	if req.Type == ChatTypePersonal {
		if len(req.Members) != 1 {
			shared.WriteError(w, http.StatusBadRequest, "personal chat requires exactly 1 other member")
			return
		}
		existing, _ := h.repo.GetPersonalChat(r.Context(), userID, req.Members[0])
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
	for _, memberID := range req.Members {
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
	userID := r.Context().Value("user_id").(string)

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
	userID := r.Context().Value("user_id").(string)
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
	userID := r.Context().Value("user_id").(string)
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
		shared.WriteError(w, http.StatusInternalServerError, "failed to send message")
		return
	}

	shared.WriteJSON(w, http.StatusCreated, msg)
}

func (h *APIHandler) GetMessages(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(string)
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
	userID := r.Context().Value("user_id").(string)
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
	userID := r.Context().Value("user_id").(string)
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
	userID := r.Context().Value("user_id").(string)
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
