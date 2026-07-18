package chat

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

type Hub struct {
	clients    map[string]map[*Client]bool
	broadcast  chan *Envelope
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

type Client struct {
	hub    *Hub
	conn   *websocket.Conn
	userID string
	send   chan []byte
}

type Envelope struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload"`
	UserIDs []string    `json:"-"`
}

type WSMessage struct {
	Type    string          `json:"type"`
	Raw     json.RawMessage `json:"-"`
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[string]map[*Client]bool),
		broadcast:  make(chan *Envelope, 256),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			if h.clients[client.userID] == nil {
				h.clients[client.userID] = make(map[*Client]bool)
			}
			h.clients[client.userID][client] = true
			h.mu.Unlock()

			h.broadcastOnlineStatus(client.userID, "online")

		case client := <-h.unregister:
			h.mu.Lock()
			if clients, ok := h.clients[client.userID]; ok {
				delete(clients, client)
				if len(clients) == 0 {
					delete(h.clients, client.userID)
				}
			}
			close(client.send)
			h.mu.Unlock()

			h.mu.RLock()
			remaining := len(h.clients[client.userID])
			h.mu.RUnlock()

			if remaining == 0 {
				h.broadcastOnlineStatus(client.userID, "offline")
			}

		case envelope := <-h.broadcast:
			h.mu.RLock()
			var stale []*Client
			for userID, clients := range h.clients {
				if len(envelope.UserIDs) > 0 {
					found := false
					for _, target := range envelope.UserIDs {
						if target == userID {
							found = true
							break
						}
					}
					if !found {
						continue
					}
				}

				data, err := json.Marshal(envelope)
				if err != nil {
					log.Printf("marshal error: %v", err)
					continue
				}
				for client := range clients {
					select {
					case client.send <- data:
					default:
						stale = append(stale, client)
					}
				}
			}
			h.mu.RUnlock()

			if len(stale) > 0 {
				for _, client := range stale {
					h.unregister <- client
				}
			}
		}
	}
}

func (h *Hub) BroadcastToUsers(userIDs []string, envelope *Envelope) {
	envelope.UserIDs = userIDs
	h.broadcast <- envelope
}

func (h *Hub) BroadcastToAll(envelope *Envelope) {
	h.broadcast <- envelope
}

func (h *Hub) IsOnline(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients[userID]) > 0
}

func (h *Hub) SendToUser(userID string, data []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	if clients, ok := h.clients[userID]; ok {
		for client := range clients {
			select {
			case client.send <- data:
			default:
			}
		}
	}
}

func (h *Hub) broadcastOnlineStatus(userID, status string) {
	msg := &Envelope{
		Type: "user." + status,
		Payload: map[string]string{
			"user_id": userID,
			"status":  status,
		},
	}
	data, _ := json.Marshal(msg)

	h.mu.RLock()
	defer h.mu.RUnlock()
	for uid, clients := range h.clients {
		if uid == userID {
			continue
		}
		for client := range clients {
			select {
			case client.send <- data:
			default:
			}
		}
	}
}

func (c *Client) ReadPump(hub *Hub, handler func(userID string, msgType string, data json.RawMessage)) {
	defer func() {
		hub.unregister <- c
		c.conn.Close()
	}()

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			break
		}

		var wsMsg WSMessage
		if err := json.Unmarshal(message, &wsMsg); err != nil {
			continue
		}

		handler(c.userID, wsMsg.Type, message)
	}
}

func (c *Client) WritePump() {
	for message := range c.send {
		if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
			break
		}
	}
}
