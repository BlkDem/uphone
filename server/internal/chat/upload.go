package chat

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/uphone/server/internal/middleware"
	"github.com/uphone/server/internal/shared"
	"github.com/uphone/server/internal/storage"
)

type UploadHandler struct {
	s3      storage.Storage
	baseURL string
}

func NewUploadHandler(s3 storage.Storage, baseURL string) *UploadHandler {
	return &UploadHandler{s3: s3, baseURL: baseURL}
}

func (h *UploadHandler) Storage() storage.Storage {
	return h.s3
}

func (h *UploadHandler) Upload(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	if err := r.ParseMultipartForm(32 << 20); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid multipart form")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		shared.WriteError(w, http.StatusBadRequest, "file is required")
		return
	}
	defer file.Close()

	ext := filepath.Ext(header.Filename)
	if ext == "" {
		contentType := header.Header.Get("Content-Type")
		switch contentType {
		case "image/jpeg":
			ext = ".jpg"
		case "image/png":
			ext = ".png"
		case "image/gif":
			ext = ".gif"
		case "image/webp":
			ext = ".webp"
		case "video/mp4":
			ext = ".mp4"
		case "video/webm":
			ext = ".webm"
		case "audio/mpeg":
			ext = ".mp3"
		case "audio/ogg":
			ext = ".ogg"
		default:
			ext = ".bin"
		}
	}

	randBytes := make([]byte, 8)
	rand.Read(randBytes)
	timestamp := time.Now().UnixMilli()
	filename := fmt.Sprintf("%s_%d_%s%s", userID[:8], timestamp, hex.EncodeToString(randBytes), ext)

	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	if err := h.s3.Upload(r.Context(), filename, file, header.Size, contentType); err != nil {
		log.Printf("Upload: failed to upload: %v", err)
		shared.WriteError(w, http.StatusInternalServerError, "failed to save file")
		return
	}

	fileURL := h.baseURL + "/uploads/" + filename

	shared.WriteJSON(w, http.StatusOK, map[string]string{
		"url":      fileURL,
		"filename": header.Filename,
	})
}

func (h *UploadHandler) ServeFile(w http.ResponseWriter, r *http.Request) {
	filename := strings.TrimPrefix(r.URL.Path, "/uploads/")
	if filename == "" {
		http.NotFound(w, r)
		return
	}
	storage.ServeFile(w, r, h.s3, filename)
}
