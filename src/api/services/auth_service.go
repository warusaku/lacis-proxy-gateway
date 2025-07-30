// auth_service.go - Authentication Service
// Version: 1.0.0
// Description: JWT認証とパスワード管理

package services

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/sirupsen/logrus"
	"golang.org/x/crypto/argon2"
)

// AuthService 認証サービス
type AuthService struct {
	jwtSecret     []byte
	tokenDuration time.Duration
	logger        *logrus.Logger
}

// Claims JWTクレーム
type Claims struct {
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// NewAuthService 認証サービスを作成
func NewAuthService(jwtSecret string, expiresInHours int, logger *logrus.Logger) *AuthService {
	return &AuthService{
		jwtSecret:     []byte(jwtSecret),
		tokenDuration: time.Duration(expiresInHours) * time.Hour,
		logger:        logger,
	}
}

// GenerateToken JWTトークンを生成
func (as *AuthService) GenerateToken(username string) (string, error) {
	now := time.Now()
	
	claims := &Claims{
		Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(as.tokenDuration)),
			IssuedAt:  jwt.NewNumericDate(now),
			Issuer:    "lpg",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	
	tokenString, err := token.SignedString(as.jwtSecret)
	if err != nil {
		return "", fmt.Errorf("トークン生成エラー: %w", err)
	}

	as.logger.Infof("JWTトークンを生成しました: user=%s", username)
	return tokenString, nil
}

// ValidateToken JWTトークンを検証
func (as *AuthService) ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("不正な署名方式: %v", token.Header["alg"])
		}
		return as.jwtSecret, nil
	})

	if err != nil {
		return nil, fmt.Errorf("トークン解析エラー: %w", err)
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, fmt.Errorf("無効なトークン")
}

// HashPassword Argon2idでパスワードをハッシュ化
func (as *AuthService) HashPassword(password string) (string, error) {
	// ソルト生成（16バイト）
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("ソルト生成エラー: %w", err)
	}

	// Argon2idパラメータ
	time := uint32(3)       // 反復回数
	memory := uint32(65536) // メモリ使用量 (64 MiB)
	threads := uint8(4)     // 並列度
	keyLen := uint32(32)    // ハッシュ長

	// ハッシュ生成
	hash := argon2.IDKey([]byte(password), salt, time, memory, threads, keyLen)

	// フォーマット: $argon2id$v=19$m=65536,t=3,p=4$salt$hash
	hashStr := fmt.Sprintf("$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
		argon2.Version,
		memory,
		time,
		threads,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(hash),
	)

	return hashStr, nil
}

// VerifyPassword パスワードを検証
func (as *AuthService) VerifyPassword(password, hashStr string) (bool, error) {
	var version int
	var memory, time uint32
	var threads uint8
	var salt, hash string

	// ハッシュ文字列のパース
	_, err := fmt.Sscanf(hashStr, "$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
		&version, &memory, &time, &threads, &salt, &hash)
	if err != nil {
		return false, fmt.Errorf("ハッシュ形式エラー: %w", err)
	}

	// Base64デコード
	saltBytes, err := base64.RawStdEncoding.DecodeString(salt)
	if err != nil {
		return false, fmt.Errorf("ソルトデコードエラー: %w", err)
	}

	hashBytes, err := base64.RawStdEncoding.DecodeString(hash)
	if err != nil {
		return false, fmt.Errorf("ハッシュデコードエラー: %w", err)
	}

	// パスワードをハッシュ化して比較
	keyLen := uint32(len(hashBytes))
	compHash := argon2.IDKey([]byte(password), saltBytes, time, memory, threads, keyLen)

	// タイミング攻撃対策のため、固定時間で比較
	if len(compHash) != len(hashBytes) {
		return false, nil
	}

	var diff byte
	for i := range compHash {
		diff |= compHash[i] ^ hashBytes[i]
	}

	return diff == 0, nil
}

// RefreshToken トークンをリフレッシュ
func (as *AuthService) RefreshToken(oldToken string) (string, error) {
	claims, err := as.ValidateToken(oldToken)
	if err != nil {
		return "", fmt.Errorf("元のトークンが無効です: %w", err)
	}

	// 有効期限が1時間以内の場合のみリフレッシュ許可
	if time.Until(claims.ExpiresAt.Time) > time.Hour {
		return "", fmt.Errorf("トークンはまだ有効です")
	}

	return as.GenerateToken(claims.Username)
}

// Logout ログアウト処理（クライアント側でトークンを削除）
func (as *AuthService) Logout(username string) {
	as.logger.Infof("ユーザーがログアウトしました: %s", username)
	// サーバー側でのトークン無効化が必要な場合は、
	// RedisやメモリにブラックリストとしてトークンIDを保存
} 