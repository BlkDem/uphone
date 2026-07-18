package auth

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestValidateToken_Valid(t *testing.T) {
	secret := "test-secret"
	svc := &Service{jwtSecret: []byte(secret), accessTTL: time.Hour}

	userID := "user-123"
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("failed to sign token: %v", err)
	}

	got, err := svc.ValidateToken(tokenString)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != userID {
		t.Errorf("expected user ID %s, got %s", userID, got)
	}
}

func TestValidateToken_Expired(t *testing.T) {
	secret := "test-secret"
	svc := &Service{jwtSecret: []byte(secret), accessTTL: time.Hour}

	claims := &Claims{
		UserID: "user-123",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(-time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now().Add(-2 * time.Hour)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, _ := token.SignedString([]byte(secret))

	_, err := svc.ValidateToken(tokenString)
	if err != ErrExpiredToken {
		t.Errorf("expected ErrExpiredToken, got %v", err)
	}
}

func TestValidateToken_InvalidSignature(t *testing.T) {
	secret := "test-secret"
	wrongSecret := "wrong-secret"
	svc := &Service{jwtSecret: []byte(secret), accessTTL: time.Hour}

	claims := &Claims{
		UserID: "user-123",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, _ := token.SignedString([]byte(wrongSecret))

	_, err := svc.ValidateToken(tokenString)
	if err != ErrInvalidToken {
		t.Errorf("expected ErrInvalidToken, got %v", err)
	}
}

func TestValidateToken_Malformed(t *testing.T) {
	svc := &Service{jwtSecret: []byte("test"), accessTTL: time.Hour}

	_, err := svc.ValidateToken("not-a-jwt-token")
	if err != ErrInvalidToken {
		t.Errorf("expected ErrInvalidToken, got %v", err)
	}
}
