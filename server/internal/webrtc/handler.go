package webrtc

import (
	"encoding/json"
	"net/http"
)

func NewICEConfigHandler(turnURL, turnUser, turnPass string) http.HandlerFunc {
	cfg := GetICEConfig(turnURL, turnUser, turnPass)
	data, _ := json.Marshal(cfg)
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(data)
	}
}
