package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/uphone/server/internal/auth"
	"github.com/uphone/server/internal/chat"
	"github.com/uphone/server/internal/config"
	"github.com/uphone/server/internal/infrastructure/database"
	"github.com/uphone/server/internal/middleware"
	"github.com/uphone/server/internal/users"
)

func main() {
	cfg := config.Load()

	db, err := database.Connect(&cfg.DB)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	if err := database.Migrate(db); err != nil {
		log.Fatalf("failed to run migrations: %v", err)
	}

	os.MkdirAll(cfg.UploadDir, 0755)

	userRepo := users.NewRepository(db)
	authService := auth.NewService(userRepo, cfg.JWTSecret)
	authHandler := auth.NewHandler(authService)

	chatRepo := chat.NewRepository(db)
	chatHub := chat.NewHub()
	go chatHub.Run()
	chatAPI := chat.NewAPIHandler(chatRepo)
	chatWS := chat.NewHandler(chatRepo, chatHub)

	tokenValidator := func(tokenString string) (string, error) {
		return authService.ValidateToken(tokenString)
	}
	authMw := middleware.AuthMiddleware(tokenValidator)

	r := chi.NewRouter()
	r.Use(chimw.Logger)
	r.Use(chimw.Recoverer)
	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(chimw.Timeout(30 * time.Second))

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	r.Route("/api/v1", func(api chi.Router) {
		api.HandleFunc("POST /auth/register", authHandler.Register)
		api.HandleFunc("POST /auth/login", authHandler.Login)
		api.HandleFunc("POST /auth/refresh", authHandler.Refresh)

		api.Group(func(api chi.Router) {
			api.Use(authMw)
			api.HandleFunc("POST /auth/logout", authHandler.Logout)
			api.HandleFunc("GET /users/me", authHandler.GetMe)
			api.HandleFunc("PUT /users/me", authHandler.UpdateMe)
			api.HandleFunc("GET /users/search", authHandler.SearchUsers)
			api.HandleFunc("GET /users/{id}", authHandler.GetUser)

			api.HandleFunc("POST /chats", chatAPI.CreateChat)
			api.HandleFunc("GET /chats", chatAPI.GetChats)
			api.HandleFunc("GET /chats/{id}", chatAPI.GetChat)
			api.HandleFunc("POST /chats/{id}/messages", chatAPI.SendMessage)
			api.HandleFunc("GET /chats/{id}/messages", chatAPI.GetMessages)
			api.HandleFunc("PUT /chats/{id}/messages/{msgId}", chatAPI.EditMessage)
			api.HandleFunc("DELETE /chats/{id}/messages/{msgId}", chatAPI.DeleteMessage)
			api.HandleFunc("POST /chats/{id}/messages/{msgId}/react", chatAPI.AddReaction)

			api.HandleFunc("PUT /chats/{id}", chatAPI.UpdateChat)
			api.HandleFunc("DELETE /chats/{id}", chatAPI.DeleteChat)
			api.HandleFunc("GET /chats/{id}/members", chatAPI.GetMembers)
			api.HandleFunc("POST /chats/{id}/members", chatAPI.AddMember)
			api.HandleFunc("DELETE /chats/{id}/members/{memberId}", chatAPI.RemoveMember)
			api.HandleFunc("POST /chats/{id}/leave", chatAPI.LeaveChat)
		})
	})

	r.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		token := r.URL.Query().Get("token")
		if token == "" {
			http.Error(w, "missing token", http.StatusUnauthorized)
			return
		}
		userID, err := authService.ValidateToken(token)
		if err != nil {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}
		ctx := context.WithValue(r.Context(), "user_id", userID)
		chatWS.HandleWebSocket(w, r.WithContext(ctx))
	})

	addr := fmt.Sprintf(":%d", cfg.ServerPort)
	log.Printf("UPhone server starting on %s", addr)

	srv := &http.Server{
		Addr:         addr,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server failed: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("server shutting down...")
}
