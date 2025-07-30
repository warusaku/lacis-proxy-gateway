// common.go - Common Middleware
// Version: 1.0.0
// Description: 共通ミドルウェア

package middleware

import (
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/lacis/lpg/src/api/services"
	"github.com/sirupsen/logrus"
)

// CORSMiddleware CORS設定ミドルウェア
func CORSMiddleware(environment string) gin.HandlerFunc {
	var allowOrigins []string
	
	// 環境に応じてCORS設定を変更
	if environment == "production" {
		// 本番環境では設定ファイルから読み込む
		allowOrigins = []string{"https://lpg.example.com:8443"}
	} else {
		// 開発環境
		allowOrigins = []string{"https://localhost:8443", "https://127.0.0.1:8443", "http://localhost:5173"}
	}
	
	config := cors.Config{
		AllowOrigins:     allowOrigins,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}

	return cors.New(config)
}

// LoggerMiddleware リクエストロギングミドルウェア
func LoggerMiddleware(logger *logrus.Logger, logService *services.LogService) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 開始時刻を記録
		start := time.Now()
		path := c.Request.URL.Path
		raw := c.Request.URL.RawQuery

		// リクエスト処理
		c.Next()

		// ログエントリを作成
		latency := time.Since(start)
		clientIP := c.ClientIP()
		method := c.Request.Method
		statusCode := c.Writer.Status()
		errorMessage := c.Errors.ByType(gin.ErrorTypePrivate).String()

		if raw != "" {
			path = path + "?" + raw
		}

		// アクセスログを記録
		entry := services.LogEntry{
			Host:      c.Request.Host,
			Path:      path,
			ClientIP:  clientIP,
			Method:    method,
			Status:    statusCode,
			BytesSent: int64(c.Writer.Size()),
			SiteName:  "admin", // 管理UI
			UserAgent: c.Request.UserAgent(),
			Referer:   c.Request.Referer(),
			Duration:  float64(latency.Milliseconds()),
		}

		logService.LogAccess(entry)

		// エラーログ
		if errorMessage != "" {
			logger.Errorf("[%s] %s %s - %d - %s",
				clientIP, method, path, statusCode, errorMessage)
		} else if statusCode >= 500 {
			logger.Errorf("[%s] %s %s - %d",
				clientIP, method, path, statusCode)
		} else if statusCode >= 400 {
			logger.Warnf("[%s] %s %s - %d",
				clientIP, method, path, statusCode)
		} else {
			logger.Infof("[%s] %s %s - %d - %s",
				clientIP, method, path, statusCode, latency)
		}
	}
}

// SecurityHeadersMiddleware セキュリティヘッダーミドルウェア
func SecurityHeadersMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// セキュリティヘッダーを設定
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		c.Header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none';")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Header("Permissions-Policy", "geolocation=(), microphone=(), camera=()")

		c.Next()
	}
}

// RateLimitMiddleware レート制限ミドルウェア
func RateLimitMiddleware(requestsPerMinute int) gin.HandlerFunc {
	// 簡易実装: 実際の実装では分散環境対応が必要
	clientLimits := make(map[string][]time.Time)

	return func(c *gin.Context) {
		clientIP := c.ClientIP()
		now := time.Now()
		
		// クライアントのリクエスト履歴を取得
		requests, exists := clientLimits[clientIP]
		if !exists {
			requests = []time.Time{}
		}

		// 1分以上前のリクエストを削除
		validRequests := []time.Time{}
		for _, reqTime := range requests {
			if now.Sub(reqTime) < time.Minute {
				validRequests = append(validRequests, reqTime)
			}
		}

		// リクエスト数をチェック
		if len(validRequests) >= requestsPerMinute {
			c.JSON(429, gin.H{
				"error": "リクエスト数が制限を超えています",
			})
			c.Abort()
			return
		}

		// 現在のリクエストを追加
		validRequests = append(validRequests, now)
		clientLimits[clientIP] = validRequests

		c.Next()
	}
}

// RecoveryMiddleware パニックリカバリーミドルウェア
func RecoveryMiddleware(logger *logrus.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				logger.Errorf("パニックが発生しました: %v", err)
				
				c.JSON(500, gin.H{
					"error": "内部エラーが発生しました",
				})
				c.Abort()
			}
		}()

		c.Next()
	}
} 