package auth

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/uphone/server/internal/users"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUserExists         = errors.New("user already exists")
	ErrInvalidToken       = errors.New("invalid token")
	ErrExpiredToken       = errors.New("token expired")
	ErrGoogleAuthFailed   = errors.New("google authentication failed")
)

type Claims struct {
	UserID string `json:"user_id"`
	jwt.RegisteredClaims
}

type Service struct {
	userRepo       *users.Repository
	jwtSecret      []byte
	accessTTL      time.Duration
	refreshTTL     time.Duration
	googleClientID string
}

func NewService(userRepo *users.Repository, jwtSecret string, googleClientID string) *Service {
	return &Service{
		userRepo:       userRepo,
		jwtSecret:      []byte(jwtSecret),
		accessTTL:      15 * time.Minute,
		refreshTTL:     7 * 24 * time.Hour,
		googleClientID: googleClientID,
	}
}

func (s *Service) Register(ctx context.Context, req users.CreateUserRequest) (*users.AuthResponse, error) {
	existing, _ := s.userRepo.GetByEmail(ctx, req.Email)
	if existing != nil {
		return nil, ErrUserExists
	}

	existing, _ = s.userRepo.GetByUsername(ctx, req.Username)
	if existing != nil {
		return nil, ErrUserExists
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	hashStr := string(hash)
	user := &users.User{
		Username:     req.Username,
		Email:        req.Email,
		PasswordHash: &hashStr,
		DisplayName:  req.DisplayName,
		Status:       "offline",
	}

	if user.DisplayName == "" {
		user.DisplayName = user.Username
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	return s.generateTokens(user)
}

func (s *Service) Login(ctx context.Context, req users.LoginRequest) (*users.AuthResponse, error) {
	user, err := s.userRepo.GetByEmail(ctx, req.Email)
	if err != nil {
		return nil, ErrInvalidCredentials
	}

	if user.PasswordHash == nil {
		return nil, ErrInvalidCredentials
	}

	if err := bcrypt.CompareHashAndPassword([]byte(*user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	_ = s.userRepo.UpdateStatus(ctx, user.ID, "online")

	return s.generateTokens(user)
}

func (s *Service) GoogleSignIn(ctx context.Context, idToken string) (*users.AuthResponse, error) {
	googleUser, err := s.verifyGoogleToken(idToken)
	if err != nil {
		return nil, ErrGoogleAuthFailed
	}

	user, err := s.userRepo.GetByGoogleID(ctx, googleUser.Sub)
	if err == nil {
		if user.AvatarURL == "" && googleUser.Picture != "" {
			user.AvatarURL = googleUser.Picture
			_ = s.userRepo.Update(ctx, user)
		}
		_ = s.userRepo.UpdateStatus(ctx, user.ID, "online")
		return s.generateTokens(user)
	}

	user, err = s.userRepo.GetByEmail(ctx, googleUser.Email)
	if err == nil {
		if err := s.userRepo.LinkGoogleID(ctx, user.ID, googleUser.Sub); err != nil {
			return nil, fmt.Errorf("link google id: %w", err)
		}
		if user.AvatarURL == "" && googleUser.Picture != "" {
			user.AvatarURL = googleUser.Picture
			_ = s.userRepo.Update(ctx, user)
		}
		_ = s.userRepo.UpdateStatus(ctx, user.ID, "online")
		return s.generateTokens(user)
	}

	username := generateUsername(googleUser.Email, googleUser.Name)
	newUser := &users.User{
		Username:    username,
		Email:       googleUser.Email,
		GoogleID:    &googleUser.Sub,
		DisplayName: googleUser.Name,
		AvatarURL:   googleUser.Picture,
		Status:      "offline",
	}

	if err := s.userRepo.Create(ctx, newUser); err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	_ = s.userRepo.UpdateStatus(ctx, newUser.ID, "online")
	return s.generateTokens(newUser)
}

type googleTokenInfo struct {
	Sub     string `json:"sub"`
	Email   string `json:"email"`
	Name    string `json:"name"`
	Picture string `json:"picture"`
	Aud     string `json:"aud"`
}

func (s *Service) verifyGoogleToken(idToken string) (*googleTokenInfo, error) {
	resp, err := http.Get("https://oauth2.googleapis.com/tokeninfo?id_token=" + idToken)
	if err != nil {
		return nil, fmt.Errorf("google tokeninfo request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("google tokeninfo returned %d: %s", resp.StatusCode, string(body))
	}

	var info googleTokenInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		return nil, fmt.Errorf("decode tokeninfo: %w", err)
	}

	if s.googleClientID != "" && info.Aud != s.googleClientID {
		return nil, fmt.Errorf("audience mismatch: got %s", info.Aud)
	}

	return &info, nil
}

func generateUsername(email, name string) string {
	if name != "" {
		username := strings.ToLower(strings.ReplaceAll(name, " ", ""))
		username = strings.Map(func(r rune) rune {
			if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '_' {
				return r
			}
			return -1
		}, username)
		if len(username) >= 3 {
			if len(username) > 30 {
				username = username[:30]
			}
			return username
		}
	}

	parts := strings.SplitN(email, "@", 2)
	username := strings.ToLower(parts[0])
	username = strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '_' {
			return r
		}
		return -1
	}, username)
	if len(username) > 30 {
		username = username[:30]
	}
	return username
}

func (s *Service) Refresh(ctx context.Context, refreshToken string) (*users.AuthResponse, error) {
	userID, err := s.ValidateToken(refreshToken)
	if err != nil {
		return nil, ErrInvalidToken
	}

	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, ErrInvalidToken
	}

	return s.generateTokens(user)
}

func (s *Service) Logout(ctx context.Context, userID string) error {
	return s.userRepo.UpdateStatus(ctx, userID, "offline")
}

func (s *Service) GetUser(ctx context.Context, userID string) (*users.User, error) {
	return s.userRepo.GetByID(ctx, userID)
}

func (s *Service) ChangePassword(ctx context.Context, userID, oldPassword, newPassword string) error {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return ErrInvalidCredentials
	}

	if user.PasswordHash == nil {
		return ErrInvalidCredentials
	}

	if err := bcrypt.CompareHashAndPassword([]byte(*user.PasswordHash), []byte(oldPassword)); err != nil {
		return ErrInvalidCredentials
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}

	return s.userRepo.UpdatePassword(ctx, userID, string(hash))
}

func (s *Service) SeedAdmin(ctx context.Context) error {
	existing, _ := s.userRepo.GetByEmail(ctx, "blkdem@blkdem.ru")
	if existing != nil {
		return nil
	}

	hash, err := bcrypt.GenerateFromPassword([]byte("12345678"), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	hashStr := string(hash)
	admin := &users.User{
		Username:     "blkdem",
		Email:        "blkdem@blkdem.ru",
		PasswordHash: &hashStr,
		DisplayName:  "Admin",
		Role:         "admin",
		Status:       "offline",
	}

	return s.userRepo.Create(ctx, admin)
}

func (s *Service) ValidateToken(tokenString string) (string, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return s.jwtSecret, nil
	})

	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return "", ErrExpiredToken
		}
		return "", ErrInvalidToken
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return "", ErrInvalidToken
	}

	return claims.UserID, nil
}

func (s *Service) generateTokens(user *users.User) (*users.AuthResponse, error) {
	accessToken, err := s.createToken(user.ID, s.accessTTL)
	if err != nil {
		return nil, err
	}

	refreshToken, err := s.createToken(user.ID, s.refreshTTL)
	if err != nil {
		return nil, err
	}

	return &users.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         *user,
	}, nil
}

func (s *Service) createToken(userID string, ttl time.Duration) (string, error) {
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(ttl)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "uphone",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(s.jwtSecret)
}

func (s *Service) CreateAccessToken(userID string) (string, error) {
	return s.createToken(userID, s.accessTTL)
}
