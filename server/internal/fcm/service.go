package fcm

import (
	"context"
	"database/sql"
	"log"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type Service struct {
	client *messaging.Client
}

func NewService(credentialsFile string) *Service {
	ctx := context.Background()

	var app *firebase.App
	var err error

	if credentialsFile != "" {
		opt := option.WithCredentialsFile(credentialsFile)
		app, err = firebase.NewApp(ctx, nil, opt)
	} else {
		app, err = firebase.NewApp(ctx, nil)
	}

	if err != nil {
		log.Printf("FCM: failed to initialize Firebase app: %v (push notifications disabled)", err)
		return &Service{}
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		log.Printf("FCM: failed to get messaging client: %v (push notifications disabled)", err)
		return &Service{}
	}

	log.Println("FCM: initialized successfully")
	return &Service{client: client}
}

type CallNotification struct {
	CallID     string
	FromUser   string
	FromName   string
	CallType   string
	IsGroup    bool
	ChatName   string
}

func (s *Service) SendCallNotification(ctx context.Context, db *sql.DB, userID string, notif *CallNotification) {
	if s.client == nil {
		return
	}

	var token string
	err := db.QueryRowContext(ctx, `SELECT fcm_token FROM users WHERE id = ?`, userID).Scan(&token)
	if err != nil || token == "" {
		return
	}

	notifType := "call-request"
	title := "Incoming call"
	body := notif.FromName + " is calling..."

	if notif.IsGroup {
		notifType = "call-invite"
		title = "Group " + notif.CallType + " call"
		body = notif.FromName + " is calling in " + notif.ChatName
	}

	msg := &messaging.Message{
		Token: token,
		Data: map[string]string{
			"type":      notifType,
			"call_id":   notif.CallID,
			"from_user": notif.FromUser,
			"from_name": notif.FromName,
			"call_type": notif.CallType,
			"title":     title,
			"body":      body,
		},
		Android: &messaging.AndroidConfig{
			Priority: "high",
		},
	}

	_, err = s.client.Send(ctx, msg)
	if err != nil {
		log.Printf("FCM: failed to send to %s: %v", userID, err)
	} else {
		log.Printf("FCM: sent call notification to %s", userID)
	}
}

type MessageNotification struct {
	SenderName string
	ChatName   string
	Content    string
	ChatID     string
}

func (s *Service) SendMessageNotification(ctx context.Context, db *sql.DB, userID string, notif *MessageNotification) {
	if s.client == nil {
		return
	}

	var token string
	err := db.QueryRowContext(ctx, `SELECT fcm_token FROM users WHERE id = ?`, userID).Scan(&token)
	if err != nil || token == "" {
		return
	}

	title := notif.SenderName
	if notif.ChatName != "" {
		title = notif.SenderName + " в " + notif.ChatName
	}
	body := notif.Content
	if len(body) > 200 {
		body = body[:200] + "..."
	}

	msg := &messaging.Message{
		Token: token,
		Data: map[string]string{
			"type":    "new_message",
			"chat_id": notif.ChatID,
			"title":   title,
			"body":    body,
		},
		Android: &messaging.AndroidConfig{
			Priority: "normal",
			Notification: &messaging.AndroidNotification{
				Title:    title,
				Body:     body,
				ChannelID: "uphone_messages",
			},
		},
	}

	_, err = s.client.Send(ctx, msg)
	if err != nil {
		log.Printf("FCM: failed to send message to %s: %v", userID, err)
	} else {
		log.Printf("FCM: sent message notification to %s", userID)
	}
}
