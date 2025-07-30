// auth.go - Authentication Handlers
// Version: 1.0.0
// Description: 認証関連のAPIハンドラー

package handlers

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/lacis/lpg/src/api/services"
	"github.com/sirupsen/logrus"
)

// AuthHandler 認証ハンドラー
type AuthHandler struct {
	auth   *services.AuthService
	config *services.ConfigManager
	logger *logrus.Logger
}

// NewAuthHandler 認証ハンドラーを作成
func NewAuthHandler(auth *services.AuthService, config *services.ConfigManager, logger *logrus.Logger) *AuthHandler {
	return &AuthHandler{
		auth:   auth,
		config: config,
		logger: logger,
	}
}

// LoginRequest ログインリクエスト
type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// LoginResponse ログインレスポンス
type LoginResponse struct {
	Token     string `json:"token"`
	ExpiresIn int    `json:"expires_in"`
}

// Login ログイン処理
func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なリクエスト形式です",
		})
		return
	}

	// 設定からユーザー情報を取得
	config := h.config.Get()
	if config == nil {
		h.logger.Error("設定の取得に失敗しました")
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "内部エラーが発生しました",
		})
		return
	}

	// ユーザーが存在するか確認
	hashedPassword, exists := config.AdminUser[req.Username]
	if !exists {
		h.logger.Warnf("存在しないユーザー: %s", req.Username)
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "ユーザー名またはパスワードが正しくありません",
		})
		return
	}

	// パスワードを検証
	valid, err := h.auth.VerifyPassword(req.Password, hashedPassword)
	if err != nil {
		h.logger.Errorf("パスワード検証エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "認証処理中にエラーが発生しました",
		})
		return
	}

	if !valid {
		h.logger.Warnf("パスワード検証失敗: %s", req.Username)
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "ユーザー名またはパスワードが正しくありません",
		})
		return
	}

	// JWTトークンを生成
	token, err := h.auth.GenerateToken(req.Username)
	if err != nil {
		h.logger.Errorf("トークン生成エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "トークン生成に失敗しました",
		})
		return
	}

	h.logger.Infof("ログイン成功: %s", req.Username)

	c.JSON(http.StatusOK, LoginResponse{
		Token:     token,
		ExpiresIn: 86400, // 24時間
	})
}

// ChangePasswordRequest パスワード変更リクエスト
type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" binding:"required"`
	NewPassword     string `json:"new_password" binding:"required,min=8"`
}

// ChangePassword パスワード変更処理
func (h *AuthHandler) ChangePassword(c *gin.Context) {
	username := c.GetString("username")
	if username == "" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "認証が必要です",
		})
		return
	}

	var req ChangePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なリクエスト形式です",
		})
		return
	}

	// 現在の設定を取得
	config := h.config.Get()
	if config == nil {
		h.logger.Error("設定の取得に失敗しました")
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "内部エラーが発生しました",
		})
		return
	}

	// 現在のパスワードを確認
	currentHash, exists := config.AdminUser[username]
	if !exists {
		h.logger.Errorf("ユーザーが見つかりません: %s", username)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "ユーザー情報の取得に失敗しました",
		})
		return
	}

	valid, err := h.auth.VerifyPassword(req.CurrentPassword, currentHash)
	if err != nil || !valid {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "現在のパスワードが正しくありません",
		})
		return
	}

	// 新しいパスワードをハッシュ化
	newHash, err := h.auth.HashPassword(req.NewPassword)
	if err != nil {
		h.logger.Errorf("パスワードハッシュ化エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "パスワードの処理に失敗しました",
		})
		return
	}

	// 設定を更新
	config.AdminUser[username] = newHash
	if err := h.config.Save(config); err != nil {
		h.logger.Errorf("設定保存エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の保存に失敗しました",
		})
		return
	}

	h.logger.Infof("パスワード変更成功: %s", username)

	c.JSON(http.StatusOK, gin.H{
		"message": "パスワードを変更しました",
	})
}

// RefreshToken トークンリフレッシュ処理
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	// Authorizationヘッダーからトークンを取得
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "認証トークンが必要です",
		})
		return
	}

	// Bearer プレフィックスを削除
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	if tokenString == authHeader {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "無効なトークン形式です",
		})
		return
	}

	// トークンをリフレッシュ
	newToken, err := h.auth.RefreshToken(tokenString)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "トークンのリフレッシュに失敗しました",
		})
		return
	}

	c.JSON(http.StatusOK, LoginResponse{
		Token:     newToken,
		ExpiresIn: 86400,
	})
}

// Logout ログアウト処理
func (h *AuthHandler) Logout(c *gin.Context) {
	username := c.GetString("username")
	if username != "" {
		h.auth.Logout(username)
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "ログアウトしました",
	})
} 