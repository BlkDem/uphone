package admin

import (
	"encoding/json"
	"net/http"

	"github.com/uphone/server/internal/middleware"
	"github.com/uphone/server/internal/shared"
	"github.com/uphone/server/internal/users"
	"golang.org/x/crypto/bcrypt"
)

type Handler struct {
	userRepo *users.Repository
}

func NewHandler(userRepo *users.Repository) *Handler {
	return &Handler{userRepo: userRepo}
}

func (h *Handler) ListUsers(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	admin, err := h.userRepo.GetByID(r.Context(), userID)
	if err != nil || admin.Role != "admin" {
		shared.WriteError(w, http.StatusForbidden, "admin access required")
		return
	}

	usersList, err := h.userRepo.ListAll(r.Context())
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, usersList)
}

func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	admin, err := h.userRepo.GetByID(r.Context(), userID)
	if err != nil || admin.Role != "admin" {
		shared.WriteError(w, http.StatusForbidden, "admin access required")
		return
	}

	var req users.AdminCreateUserRequest
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

	role := req.Role
	if role != "admin" {
		role = "user"
	}

	existing, _ := h.userRepo.GetByEmail(r.Context(), req.Email)
	if existing != nil {
		shared.WriteError(w, http.StatusConflict, "email already exists")
		return
	}

	existing, _ = h.userRepo.GetByUsername(r.Context(), req.Username)
	if existing != nil {
		shared.WriteError(w, http.StatusConflict, "username already exists")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	hashStr := string(hash)
	user := &users.User{
		Username:     req.Username,
		Email:        req.Email,
		PasswordHash: &hashStr,
		DisplayName:  req.DisplayName,
		Role:         role,
		Status:       "offline",
	}

	if user.DisplayName == "" {
		user.DisplayName = user.Username
	}

	if err := h.userRepo.Create(r.Context(), user); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusCreated, user)
}

func (h *Handler) DeleteUser(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	admin, err := h.userRepo.GetByID(r.Context(), userID)
	if err != nil || admin.Role != "admin" {
		shared.WriteError(w, http.StatusForbidden, "admin access required")
		return
	}

	targetID := r.PathValue("id")
	if targetID == "" {
		shared.WriteError(w, http.StatusBadRequest, "user id is required")
		return
	}

	if targetID == userID {
		shared.WriteError(w, http.StatusBadRequest, "cannot delete yourself")
		return
	}

	if err := h.userRepo.Delete(r.Context(), targetID); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "user deleted"})
}

func (h *Handler) ChangeUserRole(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	admin, err := h.userRepo.GetByID(r.Context(), userID)
	if err != nil || admin.Role != "admin" {
		shared.WriteError(w, http.StatusForbidden, "admin access required")
		return
	}

	targetID := r.PathValue("id")
	if targetID == "" {
		shared.WriteError(w, http.StatusBadRequest, "user id is required")
		return
	}

	var req users.AdminChangeRoleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Role != "admin" && req.Role != "user" {
		shared.WriteError(w, http.StatusBadRequest, "role must be 'admin' or 'user'")
		return
	}

	if err := h.userRepo.UpdateRole(r.Context(), targetID, req.Role); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "role updated"})
}

func (h *Handler) ChangeUserPassword(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	admin, err := h.userRepo.GetByID(r.Context(), userID)
	if err != nil || admin.Role != "admin" {
		shared.WriteError(w, http.StatusForbidden, "admin access required")
		return
	}

	targetID := r.PathValue("id")
	if targetID == "" {
		shared.WriteError(w, http.StatusBadRequest, "user id is required")
		return
	}

	var req users.AdminChangePasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if len(req.Password) < 6 {
		shared.WriteError(w, http.StatusBadRequest, "password must be at least 6 characters")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	if err := h.userRepo.UpdatePassword(r.Context(), targetID, string(hash)); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "password updated"})
}
