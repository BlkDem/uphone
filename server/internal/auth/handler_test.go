package auth

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHandler_Register_MissingFields(t *testing.T) {
	h := &Handler{service: nil}

	body := `{"username":"ab"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", bytes.NewBufferString(body))
	w := httptest.NewRecorder()

	h.Register(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}

	var resp map[string]string
	json.NewDecoder(w.Body).Decode(&resp)
	if resp["error"] == "" {
		t.Error("expected error message")
	}
}

func TestHandler_Register_ShortPassword(t *testing.T) {
	h := &Handler{service: nil}

	body := `{"username":"testuser","email":"test@test.com","password":"123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", bytes.NewBufferString(body))
	w := httptest.NewRecorder()

	h.Register(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestHandler_Register_InvalidJSON(t *testing.T) {
	h := &Handler{service: nil}

	req := httptest.NewRequest("POST", "/api/v1/auth/register", bytes.NewBufferString("not json"))
	w := httptest.NewRecorder()

	h.Register(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestHandler_Login_MissingFields(t *testing.T) {
	h := &Handler{service: nil}

	body := `{"email":"test@test.com"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/login", bytes.NewBufferString(body))
	w := httptest.NewRecorder()

	h.Login(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestHandler_Refresh_MissingToken(t *testing.T) {
	h := &Handler{service: nil}

	body := `{}`
	req := httptest.NewRequest("POST", "/api/v1/auth/refresh", bytes.NewBufferString(body))
	w := httptest.NewRecorder()

	h.Refresh(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}
