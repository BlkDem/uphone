package admin

import (
	"embed"
	"html/template"
	"net/http"

	"github.com/uphone/server/internal/middleware"
	"github.com/uphone/server/internal/users"
	"golang.org/x/crypto/bcrypt"
)

//go:embed templates/*
var templateFS embed.FS

type LoginFormData struct {
	Error string
}

type WebHandler struct {
	userRepo      *users.Repository
	generateToken func(userID string) (string, error)
	templates     *template.Template
}

func NewWebHandler(userRepo *users.Repository, generateToken func(userID string) (string, error)) *WebHandler {
	tmpl := template.Must(template.ParseFS(templateFS, "templates/*.html"))
	return &WebHandler{
		userRepo:      userRepo,
		generateToken: generateToken,
		templates:     tmpl,
	}
}

func (wh *WebHandler) LoginPage(w http.ResponseWriter, r *http.Request) {
	data := LoginFormData{}
	if r.URL.Query().Get("error") != "" {
		data.Error = "Неверный email или пароль"
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	wh.templates.ExecuteTemplate(w, "login.html", data)
}

func (wh *WebHandler) LoginPost(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Redirect(w, r, "/admin/login?error=1", http.StatusFound)
		return
	}

	email := r.FormValue("email")
	password := r.FormValue("password")

	if email == "" || password == "" {
		http.Redirect(w, r, "/admin/login?error=1", http.StatusFound)
		return
	}

	user, err := wh.userRepo.GetByEmail(r.Context(), email)
	if err != nil || user.PasswordHash == nil {
		http.Redirect(w, r, "/admin/login?error=1", http.StatusFound)
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(*user.PasswordHash), []byte(password)); err != nil {
		http.Redirect(w, r, "/admin/login?error=1", http.StatusFound)
		return
	}

	if user.Role != "admin" {
		http.Redirect(w, r, "/admin/login?error=1", http.StatusFound)
		return
	}

	token, err := wh.generateToken(user.ID)
	if err != nil {
		http.Redirect(w, r, "/admin/login?error=1", http.StatusFound)
		return
	}

	middleware.SetAdminCookie(w, token)
	http.Redirect(w, r, "/admin/dashboard", http.StatusFound)
}

func (wh *WebHandler) Logout(w http.ResponseWriter, r *http.Request) {
	middleware.ClearAdminCookie(w, r)
	http.Redirect(w, r, "/admin/login", http.StatusFound)
}

func (wh *WebHandler) Dashboard(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	wh.templates.ExecuteTemplate(w, "dashboard.html", nil)
}

func (wh *WebHandler) RedirectRoot(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "/admin/dashboard", http.StatusFound)
}
