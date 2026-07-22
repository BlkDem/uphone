package auth

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/uphone/server/internal/middleware"
	"github.com/uphone/server/internal/shared"
	"github.com/uphone/server/internal/users"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req users.CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Username == "" || req.Email == "" || req.Password == "" {
		shared.WriteError(w, http.StatusBadRequest, "username, email and password are required")
		return
	}

	if len(req.Username) < 3 || len(req.Username) > 30 {
		shared.WriteError(w, http.StatusBadRequest, "username must be 3-30 characters")
		return
	}

	if len(req.Password) < 6 {
		shared.WriteError(w, http.StatusBadRequest, "password must be at least 6 characters")
		return
	}

	resp, err := h.service.Register(r.Context(), req)
	if err != nil {
		if errors.Is(err, ErrUserExists) {
			shared.WriteError(w, http.StatusConflict, "user already exists")
			return
		}
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusCreated, resp)
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req users.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Email == "" || req.Password == "" {
		shared.WriteError(w, http.StatusBadRequest, "email and password are required")
		return
	}

	resp, err := h.service.Login(r.Context(), req)
	if err != nil {
		if errors.Is(err, ErrInvalidCredentials) {
			shared.WriteError(w, http.StatusUnauthorized, "invalid credentials")
			return
		}
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, resp)
}

func (h *Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req users.RefreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.RefreshToken == "" {
		shared.WriteError(w, http.StatusBadRequest, "refresh_token is required")
		return
	}

	resp, err := h.service.Refresh(r.Context(), req.RefreshToken)
	if err != nil {
		if errors.Is(err, ErrInvalidToken) || errors.Is(err, ErrExpiredToken) {
			shared.WriteError(w, http.StatusUnauthorized, "invalid or expired token")
			return
		}
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, resp)
}

func (h *Handler) Logout(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	_ = h.service.Logout(r.Context(), userID)
	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "logged out"})
}

func (h *Handler) GetMe(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	user, err := h.service.GetUser(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "user not found")
		return
	}

	shared.WriteJSON(w, http.StatusOK, user)
}

func (h *Handler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	user, err := h.service.GetUser(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "user not found")
		return
	}

	var req users.UpdateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.DisplayName != nil {
		user.DisplayName = *req.DisplayName
	}
	if req.AvatarURL != nil {
		user.AvatarURL = *req.AvatarURL
	}

	if err := h.service.userRepo.Update(r.Context(), user); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, user)
}

func (h *Handler) SearchUsers(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	query := r.URL.Query().Get("q")
	if query == "" {
		shared.WriteError(w, http.StatusBadRequest, "query parameter 'q' is required")
		return
	}

	usersList, err := h.service.userRepo.Search(r.Context(), query, 20)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, usersList)
}

func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	targetID := r.PathValue("id")
	if targetID == "" {
		shared.WriteError(w, http.StatusBadRequest, "user id is required")
		return
	}

	user, err := h.service.GetUser(r.Context(), targetID)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "user not found")
		return
	}

	shared.WriteJSON(w, http.StatusOK, user)
}

func (h *Handler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req users.ChangePasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.OldPassword == "" || req.NewPassword == "" {
		shared.WriteError(w, http.StatusBadRequest, "old_password and new_password are required")
		return
	}

	if len(req.NewPassword) < 6 {
		shared.WriteError(w, http.StatusBadRequest, "new password must be at least 6 characters")
		return
	}

	if err := h.service.ChangePassword(r.Context(), userID, req.OldPassword, req.NewPassword); err != nil {
		if errors.Is(err, ErrInvalidCredentials) {
			shared.WriteError(w, http.StatusUnauthorized, "incorrect current password")
			return
		}
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "password changed"})
}

func (h *Handler) GoogleSignIn(w http.ResponseWriter, r *http.Request) {
	var req struct {
		IDToken string `json:"id_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.IDToken == "" {
		shared.WriteError(w, http.StatusBadRequest, "id_token is required")
		return
	}

	resp, err := h.service.GoogleSignIn(r.Context(), req.IDToken)
	if err != nil {
		if errors.Is(err, ErrGoogleAuthFailed) {
			shared.WriteError(w, http.StatusUnauthorized, "google authentication failed")
			return
		}
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, resp)
}

func (h *Handler) UpdateFCMToken(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Token == "" {
		shared.WriteError(w, http.StatusBadRequest, "token is required")
		return
	}

	if err := h.service.userRepo.UpdateFCMToken(r.Context(), userID, req.Token); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "token updated"})
}
