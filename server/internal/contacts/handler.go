package contacts

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/uphone/server/internal/middleware"
	"github.com/uphone/server/internal/shared"
)

type Handler struct {
	repo *Repository
}

func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req CreateContactRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if strings.TrimSpace(req.DisplayName) == "" {
		shared.WriteError(w, http.StatusBadRequest, "display_name is required")
		return
	}
	req.DisplayName = strings.TrimSpace(req.DisplayName)

	contact, err := h.repo.Create(r.Context(), userID, req)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusCreated, contact)
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	id := r.PathValue("id")
	if id == "" {
		shared.WriteError(w, http.StatusBadRequest, "contact id is required")
		return
	}

	contact, err := h.repo.GetByID(r.Context(), id)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "contact not found")
		return
	}

	if contact.OwnerID != userID {
		shared.WriteError(w, http.StatusNotFound, "contact not found")
		return
	}

	shared.WriteJSON(w, http.StatusOK, contact)
}

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	query := r.URL.Query().Get("q")
	contacts, err := h.repo.List(r.Context(), userID, query)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	if contacts == nil {
		contacts = []Contact{}
	}
	shared.WriteJSON(w, http.StatusOK, contacts)
}

func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	id := r.PathValue("id")
	if id == "" {
		shared.WriteError(w, http.StatusBadRequest, "contact id is required")
		return
	}

	existing, err := h.repo.GetByID(r.Context(), id)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "contact not found")
		return
	}
	if existing.OwnerID != userID {
		shared.WriteError(w, http.StatusNotFound, "contact not found")
		return
	}

	var req UpdateContactRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.DisplayName != nil {
		v := strings.TrimSpace(*req.DisplayName)
		if v == "" {
			shared.WriteError(w, http.StatusBadRequest, "display_name cannot be empty")
			return
		}
		req.DisplayName = &v
	}

	contact, err := h.repo.Update(r.Context(), id, req)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, contact)
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	id := r.PathValue("id")
	if id == "" {
		shared.WriteError(w, http.StatusBadRequest, "contact id is required")
		return
	}

	existing, err := h.repo.GetByID(r.Context(), id)
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "contact not found")
		return
	}
	if existing.OwnerID != userID {
		shared.WriteError(w, http.StatusNotFound, "contact not found")
		return
	}

	if err := h.repo.Delete(r.Context(), id); err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}

func (h *Handler) Export(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	format := strings.ToLower(r.URL.Query().Get("format"))
	if format == "" {
		format = "vcard"
	}

	contacts, err := h.repo.List(r.Context(), userID, "")
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	switch format {
	case "csv":
		csvData, err := ContactsToCSV(contacts)
		if err != nil {
			shared.WriteError(w, http.StatusInternalServerError, "error generating csv")
			return
		}
		w.Header().Set("Content-Type", "text/csv; charset=utf-8")
		w.Header().Set("Content-Disposition", "attachment; filename=contacts.csv")
		w.Write([]byte(csvData))

	case "vcard", "vcf":
		vcard := ContactsToVCard(contacts)
		w.Header().Set("Content-Type", "text/vcard; charset=utf-8")
		w.Header().Set("Content-Disposition", "attachment; filename=contacts.vcf")
		w.Write([]byte(vcard))

	default:
		shared.WriteError(w, http.StatusBadRequest, "format must be 'vcard' or 'csv'")
	}
}

func (h *Handler) Import(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	if userID == "" {
		shared.WriteError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	format := strings.ToLower(r.URL.Query().Get("format"))
	if format == "" {
		format = "vcard"
	}

	contentType := r.Header.Get("Content-Type")

	if r.Body == nil {
		shared.WriteError(w, http.StatusBadRequest, "request body is required")
		return
	}
	defer r.Body.Close()

	var contacts []CreateContactRequest

	if strings.Contains(contentType, "multipart/form-data") || r.MultipartForm != nil {
		file, header, err := r.FormFile("file")
		if err != nil {
			shared.WriteError(w, http.StatusBadRequest, "file is required")
			return
		}
		defer file.Close()

		if format == "" {
			name := strings.ToLower(header.Filename)
			if strings.HasSuffix(name, ".csv") {
				format = "csv"
			} else {
				format = "vcard"
			}
		}

		contacts, err = parseImportData(file, format)
		if err != nil {
			shared.WriteError(w, http.StatusBadRequest, fmt.Sprintf("parse error: %v", err))
			return
		}
	} else {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			shared.WriteError(w, http.StatusBadRequest, "failed to read body")
			return
		}

		contacts, err = parseImportData(strings.NewReader(string(body)), format)
		if err != nil {
			shared.WriteError(w, http.StatusBadRequest, fmt.Sprintf("parse error: %v", err))
			return
		}
	}

	if len(contacts) == 0 {
		shared.WriteJSON(w, http.StatusOK, map[string]interface{}{"imported": 0})
		return
	}

	count, err := h.repo.BulkCreate(r.Context(), userID, contacts)
	if err != nil {
		if errors.Is(err, io.EOF) {
			shared.WriteJSON(w, http.StatusOK, map[string]interface{}{"imported": 0})
			return
		}
		shared.WriteError(w, http.StatusInternalServerError, "internal error")
		return
	}

	shared.WriteJSON(w, http.StatusOK, map[string]interface{}{"imported": count})
}

func parseImportData(r io.Reader, format string) ([]CreateContactRequest, error) {
	switch format {
	case "csv":
		return ParseCSV(r)
	case "vcard", "vcf":
		data, err := io.ReadAll(r)
		if err != nil {
			return nil, err
		}
		return ParseVCard(string(data)), nil
	default:
		return nil, fmt.Errorf("unsupported format: %s", format)
	}
}
