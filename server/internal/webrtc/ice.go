package webrtc

type ICEConfig struct {
	IceServers []ICEServer `json:"iceServers"`
}

type ICEServer struct {
	URLs       []string `json:"urls"`
	Username   string   `json:"username,omitempty"`
	Credential string   `json:"credential,omitempty"`
}

func DefaultICEConfig() *ICEConfig {
	return &ICEConfig{
		IceServers: []ICEServer{
			{
				URLs: []string{
					"stun:stun.l.google.com:19302",
					"stun:stun1.l.google.com:19302",
					"stun:stun2.l.google.com:19302",
				},
			},
		},
	}
}

func GetICEConfig(turnURL, turnUser, turnPass string) *ICEConfig {
	cfg := DefaultICEConfig()

	if turnURL != "" {
		cfg.IceServers = append(cfg.IceServers, ICEServer{
			URLs:       []string{turnURL},
			Username:   turnUser,
			Credential: turnPass,
		})
	}

	return cfg
}
