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

	hasGoogleSTUN := false
	hasCloudflareSTUN := false
	for _, server := range cfg.IceServers {
		for _, url := range server.URLs {
			switch url {
			case "stun:stun.l.google.com:19302":
				hasGoogleSTUN = true
			case "stun:stun.cloudflare.com:3478":
				hasCloudflareSTUN = true
			}
		}
	}
	if !hasGoogleSTUN {
		t.Error("expected Google STUN server")
	}
	if !hasCloudflareSTUN {
		t.Error("expected Cloudflare STUN server")
	}
}

func TestGetICEConfigWithTURN(t *testing.T) {
	cfg := GetICEConfig("turn:turn.example.com:3478", "user", "pass")

	if len(cfg.IceServers) != 2 {
		t.Errorf("expected 2 ICE servers (STUN + TURN), got %d", len(cfg.IceServers))
	}

	hasTURN := false
	for _, s := range cfg.IceServers {
		for _, u := range s.URLs {
			if u == "turn:turn.example.com:3478" {
				hasTURN = true
				if s.Username != "user" || s.Credential != "pass" {
					t.Error("TURN credentials not set correctly")
				}
			}
		}
	}
	if !hasTURN {
		t.Error("expected TURN server in config")
	}
}

func TestGetICEConfigWithMultipleTURN(t *testing.T) {
	cfg := GetICEConfig("turn:turn1.example.com:3478, turn:turn2.example.com:3478", "user", "pass")

	if len(cfg.IceServers) != 3 {
		t.Errorf("expected 3 ICE servers (STUN + 2 TURN), got %d", len(cfg.IceServers))
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

func TestConferenceCallInvite(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType:     "video",
		ChatID:       "chat-group-1",
		FromName:     "Alice",
		Participants: []string{"user-1", "user-2", "user-3"},
	})

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalCallRequest,
		CallID:  "conf-001",
		Payload: payload,
	}, sendTo)

	if _, ok := sent["user-2"]; !ok {
		t.Error("expected call-invite sent to user-2")
	}
	if _, ok := sent["user-3"]; !ok {
		t.Error("expected call-invite sent to user-3")
	}

	hub.mu.RLock()
	call, ok := hub.calls["conf-001"]
	hub.mu.RUnlock()

	if !ok {
		t.Fatal("expected call to exist")
	}
	if len(call.Participants) != 3 {
		t.Errorf("expected 3 participants, got %d", len(call.Participants))
	}
}

func TestConferenceCallJoin(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType:     "video",
		ChatID:       "chat-group-1",
		FromName:     "Alice",
		Participants: []string{"user-1", "user-2"},
	})

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalCallRequest,
		CallID:  "conf-002",
		Payload: payload,
	}, sendTo)

	hub.HandleSignal("user-3", &SignalMessage{
		Type:   SignalCallJoin,
		CallID: "conf-002",
	}, sendTo)

	hub.mu.RLock()
	call, ok := hub.calls["conf-002"]
	hub.mu.RUnlock()

	if !ok {
		t.Fatal("expected call to exist")
	}
	if len(call.Participants) != 3 {
		t.Errorf("expected 3 participants after join, got %d", len(call.Participants))
	}

	if msgs, ok := sent["user-1"]; !ok || len(msgs) == 0 {
		t.Error("expected participant-joined sent to user-1")
	}
	if msgs, ok := sent["user-2"]; !ok || len(msgs) == 0 {
		t.Error("expected participant-joined sent to user-2")
	}
}

func TestConferenceCallLeave(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType:     "video",
		ChatID:       "chat-group-1",
		FromName:     "Alice",
		Participants: []string{"user-1", "user-2", "user-3"},
	})

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalCallRequest,
		CallID:  "conf-003",
		Payload: payload,
	}, sendTo)

	hub.HandleSignal("user-2", &SignalMessage{
		Type:   SignalCallLeave,
		CallID: "conf-003",
	}, sendTo)

	hub.mu.RLock()
	call, ok := hub.calls["conf-003"]
	hub.mu.RUnlock()

	if !ok {
		t.Fatal("expected call to still exist")
	}
	if len(call.Participants) != 2 {
		t.Errorf("expected 2 participants after leave, got %d", len(call.Participants))
	}
	if call.hasParticipant("user-2") {
		t.Error("user-2 should not be a participant after leaving")
	}
}

func TestConferenceCallLeaveLastRemovesCall(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType:     "audio",
		ChatID:       "chat-group-2",
		FromName:     "Bob",
		Participants: []string{"user-1", "user-2"},
	})

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalCallRequest,
		CallID:  "conf-004",
		Payload: payload,
	}, sendTo)

	hub.HandleSignal("user-1", &SignalMessage{
		Type:   SignalCallLeave,
		CallID: "conf-004",
	}, sendTo)

	hub.HandleSignal("user-2", &SignalMessage{
		Type:   SignalCallLeave,
		CallID: "conf-004",
	}, sendTo)

	hub.mu.RLock()
	_, exists := hub.calls["conf-004"]
	hub.mu.RUnlock()

	if exists {
		t.Error("expected call to be removed when all participants leave")
	}
}

func TestCallEndedHook(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	var ended *CallEndedInfo
	hub.OnCallEnded = func(info *CallEndedInfo) {
		ended = info
	}

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
		Type:    SignalCallRequest,
		CallID:  "call-010",
		ToUser:  "user-2",
		Payload: payload,
	}, sendTo)

	hub.HandleSignal("user-2", &SignalMessage{
		Type:   SignalCallAccept,
		CallID: "call-010",
		ToUser: "user-1",
	}, sendTo)

	hub.HandleSignal("user-2", &SignalMessage{
		Type:   SignalCallEnd,
		CallID: "call-010",
	}, sendTo)

	if ended == nil {
		t.Fatal("expected OnCallEnded to be called")
	}
	if ended.ChatID != "chat-1" || ended.CallerID != "user-1" || ended.CallerName != "Alice" {
		t.Errorf("unexpected ended info: %+v", ended)
	}
	if ended.CalleeID != "user-2" {
		t.Errorf("expected callee user-2, got %s", ended.CalleeID)
	}
	if ended.AnsweredAt.IsZero() {
		t.Error("expected AnsweredAt to be set")
	}
	if ended.EndedAt.Before(ended.AnsweredAt) {
		t.Error("expected EndedAt not before AnsweredAt")
	}
}

func TestCallEndHookNotFiredOnMissed(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	var missed *MissedCallInfo
	var ended *CallEndedInfo
	hub.OnMissedCall = func(info *MissedCallInfo) {
		missed = info
	}
	hub.OnCallEnded = func(info *CallEndedInfo) {
		ended = info
	}

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType: "audio",
		ChatID:   "chat-1",
		FromName: "Alice",
	})

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalCallRequest,
		CallID:  "call-011",
		ToUser:  "user-2",
		Payload: payload,
	}, sendTo)

	hub.HandleSignal("user-1", &SignalMessage{
		Type:   SignalCallEnd,
		CallID: "call-011",
	}, sendTo)

	if missed == nil {
		t.Fatal("expected OnMissedCall to be called")
	}
	if ended != nil {
		t.Fatal("expected OnCallEnded NOT to be called for a missed call")
	}
}

func TestConferenceCallEndedOnLastLeave(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	var ended *CallEndedInfo
	hub.OnCallEnded = func(info *CallEndedInfo) {
		ended = info
	}

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType:     "video",
		ChatID:       "chat-group-3",
		FromName:     "Alice",
		Participants: []string{"user-1", "user-2"},
	})

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalCallRequest,
		CallID:  "conf-010",
		Payload: payload,
	}, sendTo)

	hub.HandleSignal("user-3", &SignalMessage{
		Type:   SignalCallJoin,
		CallID: "conf-010",
	}, sendTo)

	hub.HandleSignal("user-1", &SignalMessage{
		Type:   SignalCallLeave,
		CallID: "conf-010",
	}, sendTo)

	if ended != nil {
		t.Fatal("expected OnCallEnded not fired until all participants leave")
	}

	hub.HandleSignal("user-2", &SignalMessage{
		Type:   SignalCallLeave,
		CallID: "conf-010",
	}, sendTo)

	hub.HandleSignal("user-3", &SignalMessage{
		Type:   SignalCallLeave,
		CallID: "conf-010",
	}, sendTo)

	if ended == nil {
		t.Fatal("expected OnCallEnded to be called when last participant leaves")
	}
	if ended.ChatID != "chat-group-3" || ended.CallerID != "user-1" || ended.CallerName != "Alice" {
		t.Errorf("unexpected ended info: %+v", ended)
	}
	if ended.AnsweredAt.IsZero() {
		t.Error("expected AnsweredAt to be set after join")
	}
}

func TestConferenceCallNoEndedOnUnansweredLeave(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	var ended *CallEndedInfo
	hub.OnCallEnded = func(info *CallEndedInfo) {
		ended = info
	}

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType:     "audio",
		ChatID:       "chat-group-4",
		FromName:     "Bob",
		Participants: []string{"user-1", "user-2"},
	})

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalCallRequest,
		CallID:  "conf-011",
		Payload: payload,
	}, sendTo)

	hub.HandleSignal("user-1", &SignalMessage{
		Type:   SignalCallLeave,
		CallID: "conf-011",
	}, sendTo)

	if ended != nil {
		t.Fatal("expected OnCallEnded not fired for unanswered call")
	}
}

func TestConferenceCallMissed(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	var ended *CallEndedInfo
	hub.OnCallEnded = func(info *CallEndedInfo) {
		ended = info
	}

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType:     "video",
		ChatID:       "chat-group-5",
		FromName:     "Alice",
		Participants: []string{"user-1", "user-2"},
	})

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalCallRequest,
		CallID:  "conf-012",
		Payload: payload,
	}, sendTo)

	hub.HandleSignal("user-2", &SignalMessage{
		Type:   SignalCallJoin,
		CallID: "conf-012",
	}, sendTo)

	hub.HandleSignal("user-2", &SignalMessage{
		Type:   SignalCallLeave,
		CallID: "conf-012",
	}, sendTo)

	if ended != nil {
		t.Fatal("expected OnCallEnded not fired while caller still in call")
	}
}

func TestOrphanAcceptNotRelayed(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	hub.HandleSignal("user-1", &SignalMessage{
		Type:   SignalCallAccept,
		CallID: "ghost-call-001",
		ToUser: "user-2",
	}, sendTo)

	if _, ok := sent["user-2"]; ok {
		t.Error("expected orphan call-accept NOT to be relayed")
	}
}

func TestOrphanRejectNotRelayed(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	hub.HandleSignal("user-1", &SignalMessage{
		Type:   SignalCallReject,
		CallID: "ghost-call-002",
		ToUser: "user-2",
	}, sendTo)

	if _, ok := sent["user-2"]; ok {
		t.Error("expected orphan call-reject NOT to be relayed")
	}
}

func TestOrphanAcceptAfterEndNotRelayed(t *testing.T) {
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
		Type:    SignalCallRequest,
		CallID:  "call-020",
		ToUser:  "user-2",
		Payload: payload,
	}, sendTo)

	hub.HandleSignal("user-2", &SignalMessage{
		Type:   SignalCallAccept,
		CallID: "call-020",
		ToUser: "user-1",
	}, sendTo)

	hub.HandleSignal("user-2", &SignalMessage{
		Type:   SignalCallEnd,
		CallID: "call-020",
	}, sendTo)

	beforeCallee := len(sent["user-2"])
	beforeCaller := len(sent["user-1"])

	hub.HandleSignal("user-1", &SignalMessage{
		Type:   SignalCallAccept,
		CallID: "call-020",
		ToUser: "user-2",
	}, sendTo)

	if len(sent["user-2"]) != beforeCallee {
		t.Error("expected late call-accept after call end NOT to be relayed")
	}
	if len(sent["user-1"]) != beforeCaller {
		t.Error("expected no extra messages to the caller")
	}
}

func TestConferenceRelay(t *testing.T) {
	hub := NewSignalHub()
	sent := make(map[string][]SignalMessage)

	sendTo := func(userID string, data []byte) {
		var msg SignalMessage
		json.Unmarshal(data, &msg)
		sent[userID] = append(sent[userID], msg)
	}

	payload, _ := json.Marshal(CallRequestPayload{
		CallType:     "video",
		ChatID:       "chat-group-1",
		FromName:     "Alice",
		Participants: []string{"user-1", "user-2", "user-3"},
	})

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalCallRequest,
		CallID:  "conf-005",
		Payload: payload,
	}, sendTo)

	hub.HandleSignal("user-1", &SignalMessage{
		Type:    SignalOffer,
		CallID:  "conf-005",
		Payload: json.RawMessage(`{"sdp":"v=0\r\n..."}`),
	}, sendTo)

	if msgs, ok := sent["user-2"]; !ok || len(msgs) < 2 {
		t.Error("expected offer relayed to user-2")
	}
	if msgs, ok := sent["user-3"]; !ok || len(msgs) < 2 {
		t.Error("expected offer relayed to user-3")
	}
}
