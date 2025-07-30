// auth.go - Authentication Middleware
// Version: 1.0.0
// Description: JWT認証ミドルウェア

package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/lacis/lpg/src/api/services"
)

// AuthMiddleware JWT認証ミドルウェア
func AuthMiddleware(authService *services.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Authorizationヘッダーを取得
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "認証が必要です",
			})
			c.Abort()
			return
		}

		// Bearer トークンの形式を確認
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "無効な認証形式です",
			})
			c.Abort()
			return
		}

		// トークンを検証
		claims, err := authService.ValidateToken(parts[1])
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "無効なトークンです",
			})
			c.Abort()
			return
		}

		// コンテキストにユーザー情報を設定
		c.Set("username", claims.Username)
		c.Set("claims", claims)

		c.Next()
	}
}

// OptionalAuthMiddleware オプショナル認証ミドルウェア
// 認証があれば検証するが、なくても続行する
func OptionalAuthMiddleware(authService *services.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.Next()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) == 2 && parts[0] == "Bearer" {
			claims, err := authService.ValidateToken(parts[1])
			if err == nil {
				c.Set("username", claims.Username)
				c.Set("claims", claims)
			}
		}

		c.Next()
	}
} 