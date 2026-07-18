package webrtc

import (
	"encoding/json"
	"testing"
)

func TestSignalMessageJSON(t *testing.T) {
	msg := SignalMessage{
		Type:     SignalCallRequest,
		CallID:   "call-123",
		FromUser: "user-1",
		ToUser:   "user-2",
		Payload:  json.RawMessage(`{"call_type":"video","chat_id":"chat-1","from_name":"Alice"}`),
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("marshal error: %v", err)
	}

	var decoded SignalMessage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal error: %v", err)
	}

	if decoded.Type != SignalCallRequest {
		t.Errorf("expected call-request, got %s", decoded.Type)
	}
	if decoded.CallID != "call-123" {
		t.Errorf("expected call-123, got %s", decoded.CallID)
	}
	if decoded.ToUser != "user-2" {
		t.Errorf("expected user-2, got %s", decoded.ToUser)
	}
}

func TestDefaultICEConfig(t *testing.T) {
	cfg := DefaultICEConfig()

	if len(cfg.IceServers) == 0 {
		t.Error("expected at least one ICE server")
	}

	hasSTUN := false
	for _, server := range cfg.IceServers {
		for _, url := range server.URLs {
			if url == "stun:stun.l.google.com:19302" {
				hasSTUN = true
			}
		}
	}
	if !hasSTUN {
		t.Error("expected Google STUN server")
	}
}

func TestCallLifecycle(t *testing.T) {
	hub := NewSignalHub()

	sent := make(map[string][]SignalMessage)

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType: "video",
		ChatID:   "chat-1",
		FromName: "Alice",
	})

	hub.HandleSignal("user-1", &SignalMessage{
		Type:     SignalCallRequest,
		CallID:   "call-001",
		ToUser:   "user-2",
		Payload:  payload,
	}, sendTo)

	if _, ok := sent["user-2"]; !ok {
		t.Error("expected call-request to be sent to user-2")
	}

	hub.HandleSignal("user-2", &SignalMessage{
		Type:   SignalCallAccept,
		CallID: "call-001",
		ToUser: "user-1",
	}, sendTo)

	if _, ok := sent["user-1"]; !ok {
		t.Error("expected call-accept to be sent to user-1")
	}

	hub.mu.RLock()
	call, ok := hub.calls["call-001"]
	hub.mu.RUnlock()

	if ok && call.Status != "active" {
		t.Errorf("expected status active, got %s", call.Status)
	}

	hub.HandleSignal("user-1", &SignalMessage{
		Type:   SignalCallEnd,
		CallID: "call-001",
	}, sendTo)

	hub.mu.RLock()
	_, stillExists := hub.calls["call-001"]
	hub.mu.RUnlock()

	if stillExists {
		t.Error("expected call to be removed after end")
	}
}

func TestCallReject(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType: "audio",
		ChatID:   "chat-2",
		FromName: "Bob",
	})

	hub.HandleSignal("user-3", &SignalMessage{
		Type:     SignalCallRequest,
		CallID:   "call-002",
		ToUser:   "user-4",
		Payload:  payload,
	}, sendTo)

	hub.HandleSignal("user-4", &SignalMessage{
		Type:   SignalCallReject,
		CallID: "call-002",
		ToUser: "user-3",
	}, sendTo)

	hub.mu.RLock()
	_, exists := hub.calls["call-002"]
	hub.mu.RUnlock()

	if exists {
		t.Error("expected call to be removed after reject")
	}
}

func TestSignalRelay(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalOffer,
		CallID:  "call-003",
		ToUser:  "user-2",
		Payload: json.RawMessage(`{"sdp":"v=0\r\n..."}`),
	}, sendTo)

	if msgs, ok := sent["user-2"]; !ok || len(msgs) == 0 {
		t.Error("expected offer relayed to user-2")
	}

	hub.HandleSignal("user-2", &SignalMessage{
		Type:    SignalAnswer,
		CallID:  "call-003",
		ToUser:  "user-1",
		Payload: json.RawMessage(`{"sdp":"v=0\r\n..."}`),
	}, sendTo)

	if msgs, ok := sent["user-1"]; !ok || len(msgs) == 0 {
		t.Error("expected answer relayed to user-1")
	}
}
