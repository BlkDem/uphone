package contacts

import (
	"fmt"
	"strings"
)

func ContactToVCard(c Contact) string {
	var sb strings.Builder
	sb.WriteString("BEGIN:VCARD\r\n")
	sb.WriteString("VERSION:3.0\r\n")
	sb.WriteString(fmt.Sprintf("FN:%s\r\n", c.DisplayName))

	if c.Email != nil && *c.Email != "" {
		sb.WriteString(fmt.Sprintf("EMAIL;TYPE=INTERNET:%s\r\n", *c.Email))
	}
	if c.Phone != nil && *c.Phone != "" {
		sb.WriteString(fmt.Sprintf("TEL;TYPE=CELL:%s\r\n", *c.Phone))
	}
	if c.Notes != nil && *c.Notes != "" {
		sb.WriteString(fmt.Sprintf("NOTE:%s\r\n", *c.Notes))
	}
	if c.AvatarURL != nil && *c.AvatarURL != "" {
		sb.WriteString(fmt.Sprintf("PHOTO;VALUE=uri:%s\r\n", *c.AvatarURL))
	}

	sb.WriteString("END:VCARD\r\n")
	return sb.String()
}

func ContactsToVCard(contacts []Contact) string {
	var sb strings.Builder
	for _, c := range contacts {
		sb.WriteString(ContactToVCard(c))
	}
	return sb.String()
}

func ParseVCard(data string) []CreateContactRequest {
	var results []CreateContactRequest
	var current CreateContactRequest
	inCard := false

	for _, line := range strings.Split(data, "\n") {
		line = strings.TrimRight(line, "\r")
		upper := strings.ToUpper(strings.TrimSpace(line))

		if upper == "BEGIN:VCARD" {
			inCard = true
			current = CreateContactRequest{}
			continue
		}
		if upper == "END:VCARD" {
			if inCard && current.DisplayName != "" {
				results = append(results, current)
			}
			inCard = false
			continue
		}
		if !inCard {
			continue
		}

		if key, val, ok := parseVCardLine(line); ok {
			switch {
			case strings.HasPrefix(key, "FN"):
				current.DisplayName = val
			case strings.HasPrefix(key, "N"):
				if current.DisplayName == "" && val != "" {
					parts := strings.Split(val, ";")
					name := strings.TrimSpace(strings.Join(reverse(parts), " "))
					current.DisplayName = name
				}
			case strings.HasPrefix(key, "EMAIL"):
				current.Email = &val
			case strings.HasPrefix(key, "TEL"):
				current.Phone = &val
			case strings.HasPrefix(key, "NOTE"):
				current.Notes = &val
			}
		}
	}
	return results
}

func parseVCardLine(line string) (string, string, bool) {
	idx := strings.Index(line, ":")
	if idx < 0 {
		return "", "", false
	}
	key := line[:idx]
	val := line[idx+1:]
	return key, val, true
}

func reverse(s []string) []string {
	for i, j := 0, len(s)-1; i < j; i, j = i+1, j-1 {
		s[i], s[j] = s[j], s[i]
	}
	return s
}
