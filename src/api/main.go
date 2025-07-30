// main.go - LacisProxyGateway API Server
// Version: 1.0.0
// Description: メインエントリーポイント

package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/lacis/lpg/src/api/config"
	"github.com/lacis/lpg/src/api/handlers"
	"github.com/lacis/lpg/src/api/middleware"
	"github.com/lacis/lpg/src/api/services"
	"github.com/sirupsen/logrus"
)

func main() {
	// 環境変数の読み込み
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found")
	}

	// ロガーの初期化
	logger := setupLogger()

	// 設定の読み込み
	cfg, err := config.Load()
	if err != nil {
		logger.Fatalf("設定の読み込みに失敗しました: %v", err)
	}

	// Ginモードの設定
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// サービスの初期化
	services := initializeServices(cfg, logger)

	// ルーターの設定
	router := setupRouter(cfg, services, logger)

	// HTTPSサーバーの設定
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      router,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// グレースフルシャットダウンの設定
	go func() {
		if err := srv.ListenAndServeTLS(cfg.TLS.CertFile, cfg.TLS.KeyFile); err != nil && err != http.ErrServerClosed {
			logger.Fatalf("サーバーの起動に失敗しました: %v", err)
		}
	}()

	logger.Infof("LacisProxyGateway APIサーバーがポート %d で起動しました", cfg.Port)

	// シグナル待機
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("サーバーをシャットダウンしています...")

	// グレースフルシャットダウン
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatalf("サーバーのシャットダウンに失敗しました: %v", err)
	}

	// サービスのクリーンアップ
	services.Cleanup()

	logger.Info("サーバーが正常に終了しました")
}

func setupLogger() *logrus.Logger {
	logger := logrus.New()
	
	// ログフォーマットの設定
	logger.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: "2006-01-02 15:04:05",
	})
	
	// ログレベルの設定
	level := os.Getenv("LOG_LEVEL")
	switch level {
	case "debug":
		logger.SetLevel(logrus.DebugLevel)
	case "info":
		logger.SetLevel(logrus.InfoLevel)
	case "warn":
		logger.SetLevel(logrus.WarnLevel)
	case "error":
		logger.SetLevel(logrus.ErrorLevel)
	default:
		logger.SetLevel(logrus.InfoLevel)
	}
	
	// ログファイルの設定
	logFile := "/var/log/lpg/api.log"
	if file, err := os.OpenFile(logFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666); err == nil {
		logger.SetOutput(file)
	} else {
		logger.Warnf("ログファイルを開けませんでした: %v", err)
	}
	
	return logger
}

func initializeServices(cfg *config.Config, logger *logrus.Logger) *services.Services {
	// 設定マネージャーの初期化
	configManager := services.NewConfigManager(cfg.ConfigPath, logger)
	
	// 認証サービスの初期化
	authService := services.NewAuthService(cfg.JWT.Secret, cfg.JWT.ExpiresIn, logger)
	
	// Caddyクライアントの初期化
	caddyClient := services.NewCaddyClient(cfg.Caddy.AdminAPI, logger)
	
	// ログサービスの初期化
	logService := services.NewLogService(cfg.Log.Endpoint, logger)
	
	// メトリクスコレクターの初期化
	metricsCollector := services.NewMetricsCollector(logger)
	
	// IPTablesマネージャーの初期化
	// 開発環境ではdryRun=trueに設定
	dryRun := cfg.Environment == "development"
	iptablesManager := services.NewIPTablesManager(logger, dryRun)
	
	// 起動時に基本的なセキュリティルールを適用
	if err := iptablesManager.ApplyBasicSecurityRules(); err != nil {
		logger.Warnf("基本セキュリティルールの適用に失敗: %v", err)
	}
	
	return &services.Services{
		Config:   configManager,
		Auth:     authService,
		Caddy:    caddyClient,
		Log:      logService,
		Metrics:  metricsCollector,
		IPTables: iptablesManager,
		Logger:   logger,
	}
}

func setupRouter(cfg *config.Config, svc *services.Services, logger *logrus.Logger) *gin.Engine {
	router := gin.New()
	
	// グローバルミドルウェアの設定
	router.Use(middleware.RecoveryMiddleware(logger))
	router.Use(middleware.LoggerMiddleware(logger, svc.Log))
	router.Use(middleware.CORSMiddleware(cfg.Environment))
	router.Use(middleware.SecurityHeadersMiddleware())
	router.Use(middleware.RateLimitMiddleware(cfg.RateLimit.RequestsPerMinute))
	
	// ハンドラーの初期化
	authHandler := handlers.NewAuthHandler(svc.Auth, svc.Config, logger)
	configHandler := handlers.NewConfigHandler(svc.Config, svc.Caddy, logger)
	domainHandler := handlers.NewDomainHandler(svc.Config, svc.Caddy, logger)
	deviceHandler := handlers.NewDeviceHandler(svc.Config, svc.Caddy, logger)
	systemHandler := handlers.NewSystemHandler(svc.Metrics, svc.Config, logger)
	
	// ヘルスチェックエンドポイント（認証不要）
	router.GET("/health", systemHandler.HealthCheck)
	router.GET("/version", systemHandler.GetVersion)
	
	// APIグループ v1
	v1 := router.Group("/api/v1")
	{
		// 認証エンドポイント（認証不要）
		auth := v1.Group("/auth")
		{
			auth.POST("/login", authHandler.Login)
			auth.POST("/refresh", authHandler.RefreshToken)
		}
		
		// 認証が必要なエンドポイント
		protected := v1.Group("")
		protected.Use(middleware.AuthMiddleware(svc.Auth))
		{
			// 認証関連（認証済み）
			protected.POST("/auth/logout", authHandler.Logout)
			protected.PUT("/auth/password", authHandler.ChangePassword)
			
			// 設定管理
			config := protected.Group("/config")
			{
				config.GET("", configHandler.GetConfig)
				config.PUT("", configHandler.UpdateConfig)
				config.POST("/deploy", configHandler.DeployConfig)
				config.POST("/rollback", configHandler.RollbackConfig)
				config.GET("/history", configHandler.GetConfigHistory)
				config.POST("/validate", configHandler.ValidateConfig)
				config.GET("/export", configHandler.ExportConfig)
				config.POST("/import", configHandler.ImportConfig)
			}
			
			// ドメイン管理
			domains := protected.Group("/domains")
			{
				domains.GET("", domainHandler.GetDomains)
				domains.GET("/:domain", domainHandler.GetDomain)
				domains.POST("", domainHandler.CreateDomain)
				domains.PUT("/:domain", domainHandler.UpdateDomain)
				domains.DELETE("/:domain", domainHandler.DeleteDomain)
			}
			
			// デバイス（ルーティング）管理
			// ルートは /domains/:domain/routes パスで管理
			protected.GET("/routes", deviceHandler.GetRoutes)
			protected.POST("/routes/test", deviceHandler.TestConnection)
			
			routes := protected.Group("/domains/:domain/routes")
			{
				routes.POST("", deviceHandler.CreateRoute)
				routes.GET("/*path", deviceHandler.GetRoute)
				routes.PUT("/*path", deviceHandler.UpdateRoute)
				routes.DELETE("/*path", deviceHandler.DeleteRoute)
			}
			
			// システム情報
			system := protected.Group("/system")
			{
				system.GET("/info", systemHandler.GetSystemInfo)
				system.GET("/metrics", systemHandler.GetMetrics)
				system.GET("/network", systemHandler.GetNetworkInfo)
				system.GET("/logs", systemHandler.GetLogs)
			}
		}
	}
	
	// 静的ファイルの配信（WebUI）
	// 開発モードではViteの開発サーバーを使用するため、本番モードのみ
	if cfg.Environment == "production" {
		router.Static("/assets", "./dist/assets")
		router.StaticFile("/", "./dist/index.html")
		
		// SPAのためのフォールバック
		router.NoRoute(func(c *gin.Context) {
			// APIリクエストの場合は404を返す
			if strings.HasPrefix(c.Request.URL.Path, "/api/") {
				c.JSON(http.StatusNotFound, gin.H{
					"error": "エンドポイントが見つかりません",
					"path": c.Request.URL.Path,
				})
				return
			}
			// それ以外はindex.htmlを返す（SPAルーティング）
			c.File("./dist/index.html")
		})
	} else {
		// 開発モードでは404を返す
		router.NoRoute(func(c *gin.Context) {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "エンドポイントが見つかりません",
				"path": c.Request.URL.Path,
			})
		})
	}
	
	return router
} 