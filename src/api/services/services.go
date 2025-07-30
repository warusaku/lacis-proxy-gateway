// services.go - Services Container
// Version: 1.0.0
// Description: サービスコンテナ

package services

import (
	"github.com/sirupsen/logrus"
)

// Services サービスコンテナ
type Services struct {
	Config   *ConfigManager
	Auth     *AuthService
	Caddy    *CaddyClient
	Log      *LogService
	Metrics  *MetricsCollector
	IPTables *IPTablesManager
	Logger   *logrus.Logger
}

// Cleanup すべてのサービスをクリーンアップ
func (s *Services) Cleanup() {
	s.Logger.Info("サービスをクリーンアップしています")

	// ログサービスの終了
	if s.Log != nil {
		s.Log.Close()
	}

	// メトリクスコレクターの終了
	if s.Metrics != nil {
		s.Metrics.Close()
	}

	s.Logger.Info("サービスのクリーンアップが完了しました")
} 