package webrtc

import (
	"encoding/json"
	"log"
	"sync"
	"time"
)

type SignalType string

const (
	SignalOffer            SignalType = "offer"
	SignalAnswer           SignalType = "answer"
	SignalICECandidate     SignalType = "ice-candidate"
	SignalCallRequest      SignalType = "call-request"
	SignalCallAccept       SignalType = "call-accept"
	SignalCallReject       SignalType = "call-reject"
	SignalCallEnd          SignalType = "call-end"
	SignalCallInvite       SignalType = "call-invite"
	SignalCallJoin         SignalType = "call-join"
	SignalCallLeave        SignalType = "call-leave"
	SignalParticipantJoined SignalType = "participant-joined"
	SignalParticipantLeft  SignalType = "participant-left"
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
	CallType     string   `json:"call_type"`
	ChatID       string   `json:"chat_id"`
	FromName     string   `json:"from_name"`
	Participants []string `json:"participants,omitempty"`
}

type CallInvitePayload struct {
	CallType   string `json:"call_type"`
	ChatID     string `json:"chat_id"`
	FromName   string `json:"from_name"`
	ChatName   string `json:"chat_name,omitempty"`
}

type ParticipantJoinedPayload struct {
	UserID string `json:"user_id"`
	Name   string `json:"name,omitempty"`
}

type ParticipantLeftPayload struct {
	UserID string `json:"user_id"`
}

type MissedCallInfo struct {
	CallID     string
	ChatID     string
	CallerID   string
	CallerName string
	CallType   string
	Callees    []string
	StartedAt  time.Time
}

type Call struct {
	ID           string
	ChatID       string
	CallType     string
	CallerID     string
	CallerName   string
	CalleeID     string
	Participants []string
	Status       string
	StartedAt    time.Time
	cancel       chan struct{}
}

func (c *Call) hasParticipant(userID string) bool {
	for _, id := range c.Participants {
		if id == userID {
			return true
		}
	}
	return false
}

func (c *Call) removeParticipant(userID string) {
	for i, id := range c.Participants {
		if id == userID {
			c.Participants = append(c.Participants[:i], c.Participants[i+1:]...)
			return
		}
	}
}

type SignalHub struct {
	calls         map[string]*Call
	mu            sync.RWMutex
	OnMissedCall  func(info *MissedCallInfo)
}

func NewSignalHub() *SignalHub {
	return &SignalHub{
		calls: make(map[string]*Call),
	}
}

const missedCallTimeout = 30 * time.Second

func (h *SignalHub) startCallTimeout(callID string) {
	call := &Call{}
	h.mu.RLock()
	if c, ok := h.calls[callID]; ok {
		*call = *c
	}
	h.mu.RUnlock()

	if call.cancel == nil {
		return
	}

	timer := time.NewTimer(missedCallTimeout)
	select {
	case <-timer.C:
		h.mu.Lock()
		c, ok := h.calls[callID]
		if ok && c.Status == "ringing" {
			delete(h.calls, callID)
			h.mu.Unlock()

			if h.OnMissedCall != nil {
				callees := []string{}
				if c.CalleeID != "" {
					callees = []string{c.CalleeID}
				} else {
					callees = c.Participants
				}
				h.OnMissedCall(&MissedCallInfo{
					CallID:     callID,
					ChatID:     c.ChatID,
					CallerID:   c.CallerID,
					CallerName: c.CallerName,
					CallType:   c.CallType,
					Callees:    callees,
					StartedAt:  c.StartedAt,
				})
			}
		} else {
			h.mu.Unlock()
		}
	case <-call.cancel:
		timer.Stop()
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
	case SignalCallJoin:
		h.handleCallJoin(fromUserID, msg, sendTo)
	case SignalCallLeave:
		h.handleCallLeave(fromUserID, msg, sendTo)
	case SignalOffer, SignalAnswer, SignalICECandidate:
		h.handleRelay(fromUserID, msg, sendTo)
	}
}

func (h *SignalHub) handleCallRequest(callerID string, msg *SignalMessage, sendTo func(string, []byte)) {
	var payload CallRequestPayload
	if err := json.Unmarshal(msg.Payload, &payload); err != nil {
		log.Printf("call request payload error: %v", err)
		return
	}

	h.mu.Lock()
	if payload.Participants != nil && len(payload.Participants) > 0 {
		participants := []string{callerID}
		for _, p := range payload.Participants {
			if p != callerID {
				participants = append(participants, p)
			}
		}
		cancel := make(chan struct{})
		h.calls[msg.CallID] = &Call{
			ID:           msg.CallID,
			ChatID:       payload.ChatID,
			CallType:     payload.CallType,
			CallerID:     callerID,
			CallerName:   payload.FromName,
			Participants: participants,
			Status:       "ringing",
			StartedAt:    time.Now().UTC(),
			cancel:       cancel,
		}
		h.mu.Unlock()

		go h.startCallTimeout(msg.CallID)

		invitePayload, _ := json.Marshal(CallInvitePayload{
			CallType: payload.CallType,
			ChatID:   payload.ChatID,
			FromName: payload.FromName,
		})
		inviteMsg, _ := json.Marshal(SignalMessage{
			Type:     SignalCallInvite,
			CallID:   msg.CallID,
			FromUser: callerID,
			Payload:  invitePayload,
		})
		for _, p := range payload.Participants {
			if p != callerID {
				sendTo(p, inviteMsg)
			}
		}
	} else {
		cancel := make(chan struct{})
		h.calls[msg.CallID] = &Call{
			ID:         msg.CallID,
			ChatID:     payload.ChatID,
			CallType:   payload.CallType,
			CallerID:   callerID,
			CallerName: payload.FromName,
			CalleeID:   msg.ToUser,
			Status:     "ringing",
			StartedAt:  time.Now().UTC(),
			cancel:     cancel,
		}
		h.mu.Unlock()

		go h.startCallTimeout(msg.CallID)

		data, _ := json.Marshal(msg)
		sendTo(msg.ToUser, data)
	}
}

func (h *SignalHub) handleCallAccept(msg *SignalMessage, sendTo func(string, []byte)) {
	h.mu.Lock()
	if call, ok := h.calls[msg.CallID]; ok {
		call.Status = "active"
		if call.cancel != nil {
			close(call.cancel)
			call.cancel = nil
		}
	}
	h.mu.Unlock()

	data, _ := json.Marshal(msg)
	sendTo(msg.ToUser, data)
}

func (h *SignalHub) handleCallReject(msg *SignalMessage, sendTo func(string, []byte)) {
	h.mu.Lock()
	if call, ok := h.calls[msg.CallID]; ok {
		call.Status = "rejected"
		if call.cancel != nil {
			close(call.cancel)
			call.cancel = nil
		}
		delete(h.calls, msg.CallID)
	}
	h.mu.Unlock()

	data, _ := json.Marshal(msg)
	sendTo(msg.ToUser, data)
}

func (h *SignalHub) handleCallEnd(msg *SignalMessage, sendTo func(string, []byte)) {
	h.mu.Lock()
	if call, ok := h.calls[msg.CallID]; ok {
		wasRinging := call.Status == "ringing"
		if call.cancel != nil {
			close(call.cancel)
			call.cancel = nil
		}

		data, _ := json.Marshal(msg)
		if call.CalleeID != "" {
			if call.CallerID != msg.FromUser {
				sendTo(call.CallerID, data)
			}
			if call.CalleeID != msg.FromUser {
				sendTo(call.CalleeID, data)
			}
		} else {
			for _, p := range call.Participants {
				if p != msg.FromUser {
					sendTo(p, data)
				}
			}
		}

		if wasRinging {
			callees := []string{}
			if call.CalleeID != "" {
				callees = []string{call.CalleeID}
			} else {
				callees = call.Participants
			}
			if h.OnMissedCall != nil {
				h.OnMissedCall(&MissedCallInfo{
					CallID:     msg.CallID,
					ChatID:     call.ChatID,
					CallerID:   call.CallerID,
					CallerName: call.CallerName,
					CallType:   call.CallType,
					Callees:    callees,
					StartedAt:  call.StartedAt,
				})
			}
		}
		delete(h.calls, msg.CallID)
	}
	h.mu.Unlock()
}

func (h *SignalHub) handleCallJoin(userID string, msg *SignalMessage, sendTo func(string, []byte)) {
	h.mu.Lock()
	call, ok := h.calls[msg.CallID]
	if !ok {
		h.mu.Unlock()
		return
	}

	if call.hasParticipant(userID) {
		h.mu.Unlock()
		return
	}
	call.Participants = append(call.Participants, userID)

	existingParticipants := make([]string, len(call.Participants)-1)
	copy(existingParticipants, call.Participants[:len(call.Participants)-1])
	h.mu.Unlock()

	for _, p := range existingParticipants {
		joinedPayload, _ := json.Marshal(ParticipantJoinedPayload{
			UserID: userID,
		})
		joinedMsg, _ := json.Marshal(SignalMessage{
			Type:     SignalParticipantJoined,
			CallID:   msg.CallID,
			FromUser: userID,
			ToUser:   p,
			Payload:  joinedPayload,
		})
		sendTo(p, joinedMsg)
	}

	participantsPayload, _ := json.Marshal(map[string]interface{}{
		"participants": existingParticipants,
	})
	participantsMsg, _ := json.Marshal(SignalMessage{
		Type:     SignalCallJoin,
		CallID:   msg.CallID,
		FromUser: userID,
		ToUser:   userID,
		Payload:  participantsPayload,
	})
	sendTo(userID, participantsMsg)
}

func (h *SignalHub) handleCallLeave(userID string, msg *SignalMessage, sendTo func(string, []byte)) {
	h.mu.Lock()
	call, ok := h.calls[msg.CallID]
	if !ok {
		h.mu.Unlock()
		return
	}

	call.removeParticipant(userID)
	isEmpty := len(call.Participants) == 0
	if isEmpty {
		delete(h.calls, msg.CallID)
	}
	h.mu.Unlock()

	leftPayload, _ := json.Marshal(ParticipantLeftPayload{
		UserID: userID,
	})
	leftMsg, _ := json.Marshal(SignalMessage{
		Type:     SignalParticipantLeft,
		CallID:   msg.CallID,
		FromUser: userID,
		Payload:  leftPayload,
	})

	h.mu.RLock()
	if call, ok := h.calls[msg.CallID]; ok {
		for _, p := range call.Participants {
			sendTo(p, leftMsg)
		}
	}
	h.mu.RUnlock()
}

func (h *SignalHub) handleRelay(fromUserID string, msg *SignalMessage, sendTo func(string, []byte)) {
	data, _ := json.Marshal(msg)

	h.mu.RLock()
	call, ok := h.calls[msg.CallID]
	if ok && call.CalleeID == "" && len(call.Participants) > 0 {
		for _, p := range call.Participants {
			if p != fromUserID {
				sendTo(p, data)
			}
		}
		h.mu.RUnlock()
		return
	}
	h.mu.RUnlock()

	if msg.ToUser != "" {
		sendTo(msg.ToUser, data)
	}
}
