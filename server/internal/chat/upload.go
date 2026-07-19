package chat

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/uphone/server/internal/middleware"
	"github.com/uphone/server/internal/shared"
)

type UploadHandler struct {
	uploadDir string
	baseURL   string
}

func NewUploadHandler(uploadDir string, baseURL string) *UploadHandler {
	return &UploadHandler{uploadDir: uploadDir, baseURL: baseURL}
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
	destPath := filepath.Join(h.uploadDir, filename)

	dest, err := os.Create(destPath)
	if err != nil {
		log.Printf("Upload: failed to create file: %v", err)
		shared.WriteError(w, http.StatusInternalServerError, "failed to save file")
		return
	}
	defer dest.Close()

	if _, err := io.Copy(dest, file); err != nil {
		log.Printf("Upload: failed to write file: %v", err)
		shared.WriteError(w, http.StatusInternalServerError, "failed to write file")
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
	filePath := filepath.Join(h.uploadDir, filepath.Base(filename))

	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		http.NotFound(w, r)
		return
	}

	http.ServeFile(w, r, filePath)
}
