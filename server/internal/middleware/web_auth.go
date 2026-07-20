package middleware

import (
	"net/http"
)

func CookieAuthMiddleware(validate TokenValidator, userRole func(userID string) (string, error)) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			cookie, err := r.Cookie("admin_token")
			if err != nil || cookie.Value == "" {
				http.Redirect(w, r, "/admin/login", http.StatusFound)
				return
			}

			userID, err := validate(cookie.Value)
			if err != nil || userID == "" {
				clearAdminCookie(w, r)
				http.Redirect(w, r, "/admin/login", http.StatusFound)
				return
			}

			role, err := userRole(userID)
			if err != nil || role != "admin" {
				clearAdminCookie(w, r)
				http.Redirect(w, r, "/admin/login", http.StatusFound)
				return
			}

			ctx := SetUserID(r.Context(), userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func SetAdminCookie(w http.ResponseWriter, token string) {
	http.SetCookie(w, &http.Cookie{
		Name:     "admin_token",
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   15 * 60, // 15 minutes, matches access token TTL
	})
}

func ClearAdminCookie(w http.ResponseWriter, r *http.Request) {
	clearAdminCookie(w, r)
}

func clearAdminCookie(w http.ResponseWriter, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     "admin_token",
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		MaxAge:   -1,
	})
}
