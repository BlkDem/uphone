package contacts

import (
	"strings"
	"testing"
)

func TestContactToVCard(t *testing.T) {
	email := "test@example.com"
	phone := "+1234567890"
	notes := "Important contact"

	c := Contact{
		ID:          "test-id",
		DisplayName: "John Doe",
		Email:       &email,
		Phone:       &phone,
		Notes:       &notes,
	}

	vcard := ContactToVCard(c)

	if !strings.Contains(vcard, "BEGIN:VCARD") {
		t.Error("vcard missing BEGIN:VCARD")
	}
	if !strings.Contains(vcard, "END:VCARD") {
		t.Error("vcard missing END:VCARD")
	}
	if !strings.Contains(vcard, "FN:John Doe") {
		t.Error("vcard missing FN:John Doe")
	}
	if !strings.Contains(vcard, "EMAIL;TYPE=INTERNET:test@example.com") {
		t.Error("vcard missing email")
	}
	if !strings.Contains(vcard, "TEL;TYPE=CELL:+1234567890") {
		t.Error("vcard missing phone")
	}
	if !strings.Contains(vcard, "NOTE:Important contact") {
		t.Error("vcard missing notes")
	}
}

func TestContactsToVCard(t *testing.T) {
	contacts := []Contact{
		{DisplayName: "Alice"},
		{DisplayName: "Bob"},
	}

	vcard := ContactsToVCard(contacts)

	count := strings.Count(vcard, "BEGIN:VCARD")
	if count != 2 {
		t.Errorf("expected 2 vcards, got %d", count)
	}
}

func TestParseVCard(t *testing.T) {
	data := "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Jane Doe\r\nEMAIL:jane@example.com\r\nTEL:+9876543210\r\nEND:VCARD\r\n"

	results := ParseVCard(data)
	if len(results) != 1 {
		t.Fatalf("expected 1 contact, got %d", len(results))
	}
	if results[0].DisplayName != "Jane Doe" {
		t.Errorf("expected display_name 'Jane Doe', got '%s'", results[0].DisplayName)
	}
	if results[0].Email == nil || *results[0].Email != "jane@example.com" {
		t.Errorf("expected email 'jane@example.com'")
	}
	if results[0].Phone == nil || *results[0].Phone != "+9876543210" {
		t.Errorf("expected phone '+9876543210'")
	}
}

func TestParseVCardMultiple(t *testing.T) {
	data := strings.Join([]string{
		"BEGIN:VCARD",
		"FN:Alice",
		"END:VCARD",
		"BEGIN:VCARD",
		"FN:Bob",
		"EMAIL:bob@test.com",
		"END:VCARD",
	}, "\r\n") + "\r\n"

	results := ParseVCard(data)
	if len(results) != 2 {
		t.Fatalf("expected 2 contacts, got %d", len(results))
	}
	if results[0].DisplayName != "Alice" {
		t.Errorf("expected 'Alice', got '%s'", results[0].DisplayName)
	}
	if results[1].DisplayName != "Bob" {
		t.Errorf("expected 'Bob', got '%s'", results[1].DisplayName)
	}
}

func TestContactsToCSV(t *testing.T) {
	email := "alice@test.com"
	contacts := []Contact{
		{DisplayName: "Alice", Email: &email},
	}

	csv, err := ContactsToCSV(contacts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(csv, "display_name,email,phone,notes") {
		t.Error("csv missing header")
	}
	if !strings.Contains(csv, "Alice,alice@test.com") {
		t.Error("csv missing data")
	}
}

func TestParseCSV(t *testing.T) {
	data := "display_name,email,phone\nAlice,alice@test.com,+123\nBob,bob@test.com,\n"
	r := strings.NewReader(data)

	results, err := ParseCSV(r)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("expected 2 contacts, got %d", len(results))
	}
	if results[0].DisplayName != "Alice" {
		t.Errorf("expected 'Alice', got '%s'", results[0].DisplayName)
	}
}

func TestParseCSVEmpty(t *testing.T) {
	data := "display_name,email,phone\nAlice,alice@test.com,+123\n"
	r := strings.NewReader(data)

	results, err := ParseCSV(r)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(results) != 1 {
		t.Errorf("expected 1 contact, got %d", len(results))
	}
}

func TestParseCSVMissingHeader(t *testing.T) {
	data := "email,phone\nAlice,alice@test.com\n"
	r := strings.NewReader(data)

	_, err := ParseCSV(r)
	if err == nil {
		t.Error("expected error for missing display_name column")
	}
}

func TestParseCSVNameColumn(t *testing.T) {
	data := "name,email\nCharlie,charlie@test.com\n"
	r := strings.NewReader(data)

	results, err := ParseCSV(r)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 contact, got %d", len(results))
	}
	if results[0].DisplayName != "Charlie" {
		t.Errorf("expected 'Charlie', got '%s'", results[0].DisplayName)
	}
}

func TestPtrValue(t *testing.T) {
	s := "hello"
	if ptrValue(&s) != "hello" {
		t.Error("expected 'hello'")
	}
	if ptrValue(nil) != "" {
		t.Error("expected empty string for nil")
	}
}
