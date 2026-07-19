package contacts

import (
	"encoding/csv"
	"fmt"
	"io"
	"strings"
)

func ContactsToCSV(contacts []Contact) (string, error) {
	var sb strings.Builder
	w := csv.NewWriter(&sb)

	w.Write([]string{"display_name", "email", "phone", "notes"})

	for _, c := range contacts {
		row := []string{c.DisplayName}
		row = append(row, ptrValue(c.Email))
		row = append(row, ptrValue(c.Phone))
		row = append(row, ptrValue(c.Notes))
		if err := w.Write(row); err != nil {
			return "", fmt.Errorf("write csv row: %w", err)
		}
	}
	w.Flush()
	if err := w.Error(); err != nil {
		return "", fmt.Errorf("flush csv: %w", err)
	}
	return sb.String(), nil
}

func ParseCSV(r io.Reader) ([]CreateContactRequest, error) {
	cr := csv.NewReader(r)
	records, err := cr.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("read csv: %w", err)
	}

	if len(records) < 1 {
		return nil, fmt.Errorf("csv must have a header row")
	}

	header := make(map[string]int)
	for i, h := range records[0] {
		header[strings.ToLower(strings.TrimSpace(h))] = i
	}

	nameIdx, ok := header["display_name"]
	if !ok {
		nameIdx, ok = header["name"]
	}
	if !ok {
		return nil, fmt.Errorf("csv must have a 'display_name' or 'name' column")
	}

	emailIdx := header["email"]
	phoneIdx := header["phone"]
	notesIdx := header["notes"]

	var results []CreateContactRequest
	for _, row := range records[1:] {
		if nameIdx >= len(row) || strings.TrimSpace(row[nameIdx]) == "" {
			continue
		}
		req := CreateContactRequest{
			DisplayName: strings.TrimSpace(row[nameIdx]),
		}
		if emailIdx < len(row) && strings.TrimSpace(row[emailIdx]) != "" {
			v := strings.TrimSpace(row[emailIdx])
			req.Email = &v
		}
		if phoneIdx < len(row) && strings.TrimSpace(row[phoneIdx]) != "" {
			v := strings.TrimSpace(row[phoneIdx])
			req.Phone = &v
		}
		if notesIdx < len(row) && strings.TrimSpace(row[notesIdx]) != "" {
			v := strings.TrimSpace(row[notesIdx])
			req.Notes = &v
		}
		results = append(results, req)
	}
	return results, nil
}

func ptrValue(p *string) string {
	if p != nil {
		return *p
	}
	return ""
}
