package chat

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/uphone/server/internal/middleware"
	"github.com/uphone/server/internal/shared"
	"github.com/uphone/server/internal/storage"
)

// maxUploadMemory is the in-memory threshold for multipart parsing; larger
// files spill to disk automatically.
const maxUploadMemory = 128 << 20

type UploadHandler struct {
	s3          storage.Storage
	baseURL     string
	thumbWidth  int
}

func NewUploadHandler(s3 storage.Storage, baseURL string, thumbWidth int) *UploadHandler {
	return &UploadHandler{s3: s3, baseURL: baseURL, thumbWidth: thumbWidth}
}

func (h *UploadHandler) Storage() storage.Storage {
	return h.s3
}

func (h *UploadHandler) Upload(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	if err := r.ParseMultipartForm(maxUploadMemory); err != nil {
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

	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	randBytes := make([]byte, 8)
	rand.Read(randBytes)
	timestamp := time.Now().UnixMilli()
	filename := fmt.Sprintf("%s_%d_%s%s", userID[:8], timestamp, hex.EncodeToString(randBytes), ext)

	// Spool the uploaded file to disk so we can also produce a thumbnail.
	tmp, err := os.CreateTemp("", "uphone-upload-*")
	if err != nil {
		log.Printf("Upload: failed to create temp file: %v", err)
		shared.WriteError(w, http.StatusInternalServerError, "failed to save file")
		return
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	defer tmp.Close()

	size, err := io.Copy(tmp, file)
	if err != nil {
		log.Printf("Upload: failed to read upload: %v", err)
		shared.WriteError(w, http.StatusInternalServerError, "failed to save file")
		return
	}

	if _, err := tmp.Seek(0, io.SeekStart); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "failed to save file")
		return
	}

	if err := h.s3.Upload(r.Context(), filename, tmp, size, contentType); err != nil {
		log.Printf("Upload: failed to upload: %v", err)
		shared.WriteError(w, http.StatusInternalServerError, "failed to save file")
		return
	}

	fileURL := h.baseURL + "/uploads/" + filename

	resp := map[string]interface{}{
		"url":      fileURL,
		"filename": header.Filename,
	}

	h.attachThumbnail(r, tmpName, contentType, filename, resp)

	shared.WriteJSON(w, http.StatusOK, resp)
}

// attachThumbnail generates and uploads a preview image for image/video files
// and enriches resp with thumbnail_url / thumbnail_width / thumbnail_height.
func (h *UploadHandler) attachThumbnail(r *http.Request, tmpName, contentType, filename string, resp map[string]interface{}) {
	thumbName := thumbnailName(filename)
	thumbURL := h.baseURL + "/uploads/" + thumbName

	ct := detectMediaType(contentType, filename)

	switch {
	case strings.HasPrefix(ct, "image/"):
		data, err := os.ReadFile(tmpName)
		if err != nil {
			log.Printf("Upload: read image for thumbnail: %v", err)
			return
		}
		thumb, tw, th, err := generateImageThumbnail(data, h.thumbWidth)
		if err != nil {
			log.Printf("Upload: generate image thumbnail: %v", err)
			return
		}
		if err := h.s3.Upload(r.Context(), thumbName, bytes.NewReader(thumb), int64(len(thumb)), "image/jpeg"); err != nil {
			log.Printf("Upload: upload image thumbnail: %v", err)
			return
		}
		resp["thumbnail_url"] = thumbURL
		resp["thumbnail_width"] = tw
		resp["thumbnail_height"] = th

	case strings.HasPrefix(ct, "video/"):
		thumbPath := tmpName + "_thumb.jpg"
		defer os.Remove(thumbPath)
		tw, th, err := generateVideoThumbnail(tmpName, thumbPath, h.thumbWidth)
		if err != nil {
			log.Printf("Upload: generate video thumbnail: %v", err)
			return
		}
		thumb, err := os.ReadFile(thumbPath)
		if err != nil {
			log.Printf("Upload: read video thumbnail: %v", err)
			return
		}
		if err := h.s3.Upload(r.Context(), thumbName, bytes.NewReader(thumb), int64(len(thumb)), "image/jpeg"); err != nil {
			log.Printf("Upload: upload video thumbnail: %v", err)
			return
		}
		resp["thumbnail_url"] = thumbURL
		resp["thumbnail_width"] = tw
		resp["thumbnail_height"] = th
	}
}

// detectMediaType resolves the actual media type when the multipart request
// declares a generic one (e.g. application/octet-stream). It prefers the
// declared type, then sniffs the file content, then falls back to the extension.
func detectMediaType(contentType, filename string) string {
	ct := strings.ToLower(strings.TrimSpace(contentType))
	if ct != "" && ct != "application/octet-stream" && ct != "binary/octet-stream" {
		return ct
	}
	if ext := filepath.Ext(filename); ext != "" {
		if t := mime.TypeByExtension(ext); t != "" {
			return strings.SplitN(t, ";", 2)[0]
		}
	}
	return ""
}

func (h *UploadHandler) ServeFile(w http.ResponseWriter, r *http.Request) {
	filename := strings.TrimPrefix(r.URL.Path, "/uploads/")
	if filename == "" {
		http.NotFound(w, r)
		return
	}
	storage.ServeFile(w, r, h.s3, filename)
}
