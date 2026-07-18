package webrtc

import (
	"encoding/json"
	"log"
	"sync"
)

type SignalType string

const (
	SignalOffer       SignalType = "offer"
	SignalAnswer      SignalType = "answer"
	SignalICECandidate SignalType = "ice-candidate"
	SignalCallRequest SignalType = "call-request"
	SignalCallAccept  SignalType = "call-accept"
	SignalCallReject  SignalType = "call-reject"
	SignalCallEnd     SignalType = "call-end"
)

type SignalMessage struct {
	Type     SignalType      `json:"type"`
	CallID   string          `json:"call_id"`
	FromUser string          `json:"from_user"`
	ToUser   string          `json:"to_user"`
	Payload  json.RawMessage `json:"payload,omitempty"`
}

type OfferPayload struct {
	SDP string `json:"sdp"`
}

type AnswerPayload struct {
	SDP string `json:"sdp"`
}

type ICECandidatePayload struct {
	Candidate     string `json:"candidate"`
	SDPMid        string `json:"sdpMid"`
	SDPMLineIndex int    `json:"sdpMLineIndex"`
}

type CallRequestPayload struct {
	CallType   string `json:"call_type"`
	ChatID     string `json:"chat_id"`
	FromName   string `json:"from_name"`
}

type Call struct {
	ID       string
	ChatID   string
	CallType string
	CallerID string
	CalleeID string
	Status   string
}

type SignalHub struct {
	calls map[string]*Call
	mu    sync.RWMutex
}

func NewSignalHub() *SignalHub {
	return &SignalHub{
		calls: make(map[string]*Call),
	}
}

func (h *SignalHub) HandleSignal(fromUserID string, msg *SignalMessage, sendTo func(userID string, data []byte)) {
	msg.FromUser = fromUserID

	switch msg.Type {
	case SignalCallRequest:
		h.handleCallRequest(fromUserID, msg, sendTo)
	case SignalCallAccept:
		h.handleCallAccept(msg, sendTo)
	case SignalCallReject:
		h.handleCallReject(msg, sendTo)
	case SignalCallEnd:
		h.handleCallEnd(msg, sendTo)
	case SignalOffer, SignalAnswer, SignalICECandidate:
		h.handleRelay(msg, sendTo)
	}
}

func (h *SignalHub) handleCallRequest(callerID string, msg *SignalMessage, sendTo func(string, []byte)) {
	var payload CallRequestPayload
	if err := json.Unmarshal(msg.Payload, &payload); err != nil {
		log.Printf("call request payload error: %v", err)
		return
	}

	h.mu.Lock()
	h.calls[msg.CallID] = &Call{
		ID:       msg.CallID,
		ChatID:   payload.ChatID,
		CallType: payload.CallType,
		CallerID: callerID,
		CalleeID: msg.ToUser,
		Status:   "ringing",
	}
	h.mu.Unlock()

	data, _ := json.Marshal(msg)
	sendTo(msg.ToUser, data)
}

func (h *SignalHub) handleCallAccept(msg *SignalMessage, sendTo func(string, []byte)) {
	h.mu.Lock()
	if call, ok := h.calls[msg.CallID]; ok {
		call.Status = "active"
	}
	h.mu.Unlock()

	data, _ := json.Marshal(msg)
	sendTo(msg.ToUser, data)
}

func (h *SignalHub) handleCallReject(msg *SignalMessage, sendTo func(string, []byte)) {
	h.mu.Lock()
	if call, ok := h.calls[msg.CallID]; ok {
		call.Status = "rejected"
		delete(h.calls, msg.CallID)
	}
	h.mu.Unlock()

	data, _ := json.Marshal(msg)
	sendTo(msg.ToUser, data)
}

func (h *SignalHub) handleCallEnd(msg *SignalMessage, sendTo func(string, []byte)) {
	h.mu.Lock()
	if call, ok := h.calls[msg.CallID]; ok {
		data, _ := json.Marshal(msg)
		sendTo(call.CallerID, data)
		sendTo(call.CalleeID, data)
		delete(h.calls, msg.CallID)
	}
	h.mu.Unlock()
}

func (h *SignalHub) handleRelay(msg *SignalMessage, sendTo func(string, []byte)) {
	data, _ := json.Marshal(msg)
	sendTo(msg.ToUser, data)
}
