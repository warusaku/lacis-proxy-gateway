// config.go - Configuration Handlers
// Version: 1.0.0
// Description: 設定管理のAPIハンドラー

package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/lacis/lpg/src/api/models"
	"github.com/lacis/lpg/src/api/services"
	"github.com/sirupsen/logrus"
)

// ConfigHandler 設定ハンドラー
type ConfigHandler struct {
	config *services.ConfigManager
	caddy  *services.CaddyClient
	logger *logrus.Logger
}

// NewConfigHandler 設定ハンドラーを作成
func NewConfigHandler(config *services.ConfigManager, caddy *services.CaddyClient, logger *logrus.Logger) *ConfigHandler {
	return &ConfigHandler{
		config: config,
		caddy:  caddy,
		logger: logger,
	}
}

// GetConfig 設定を取得
func (h *ConfigHandler) GetConfig(c *gin.Context) {
	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	c.JSON(http.StatusOK, config)
}

// UpdateConfig 設定を更新
func (h *ConfigHandler) UpdateConfig(c *gin.Context) {
	var newConfig models.LPGConfig
	if err := c.ShouldBindJSON(&newConfig); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なリクエスト形式です",
			"details": err.Error(),
		})
		return
	}

	// 設定を保存
	if err := h.config.Save(&newConfig); err != nil {
		h.logger.Errorf("設定保存エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の保存に失敗しました",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "設定を更新しました",
		"revision": newConfig.Metadata.Revision,
	})
}

// DeployConfig 設定を適用
func (h *ConfigHandler) DeployConfig(c *gin.Context) {
	// 現在の設定を取得
	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// Caddyに設定を同期
	if err := h.caddy.SyncConfig(config); err != nil {
		h.logger.Errorf("Caddy設定同期エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の適用に失敗しました",
			"details": err.Error(),
		})
		return
	}

	// 設定マネージャーで適用処理
	if err := h.config.Deploy(); err != nil {
		h.logger.Errorf("設定適用エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の適用に失敗しました",
		})
		return
	}

	h.logger.Info("設定を正常に適用しました")

	c.JSON(http.StatusOK, gin.H{
		"message": "設定を適用しました",
	})
}

// RollbackConfig 設定をロールバック
func (h *ConfigHandler) RollbackConfig(c *gin.Context) {
	var req struct {
		Version int `json:"version" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なリクエスト形式です",
		})
		return
	}

	// ロールバック実行
	if err := h.config.Rollback(req.Version); err != nil {
		h.logger.Errorf("ロールバックエラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "ロールバックに失敗しました",
			"details": err.Error(),
		})
		return
	}

	// Caddyに新しい設定を同期
	config := h.config.Get()
	if err := h.caddy.SyncConfig(config); err != nil {
		h.logger.Errorf("Caddy設定同期エラー: %v", err)
		// ロールバックは成功したが、適用に失敗
		c.JSON(http.StatusPartialContent, gin.H{
			"message": "ロールバックは成功しましたが、設定の適用に失敗しました",
			"error": err.Error(),
		})
		return
	}

	h.logger.Infof("設定をバージョン %d にロールバックしました", req.Version)

	c.JSON(http.StatusOK, gin.H{
		"message": "設定をロールバックしました",
		"version": req.Version,
	})
}

// GetConfigHistory 設定履歴を取得
func (h *ConfigHandler) GetConfigHistory(c *gin.Context) {
	history, err := h.config.GetHistory()
	if err != nil {
		h.logger.Errorf("履歴取得エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "履歴の取得に失敗しました",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"history": history,
	})
}

// ValidateConfig 設定を検証
func (h *ConfigHandler) ValidateConfig(c *gin.Context) {
	var config models.LPGConfig
	if err := c.ShouldBindJSON(&config); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なリクエスト形式です",
			"valid": false,
		})
		return
	}

	// TODO: より詳細な検証を実装
	// - ホストドメインの形式確認
	// - IPアドレスの妥当性
	// - ポート番号の範囲確認
	// - 循環参照チェック

	errors := []string{}

	// 基本的な検証
	if len(config.HostDomains) == 0 {
		errors = append(errors, "ホストドメインが定義されていません")
	}

	if len(config.AdminUser) == 0 {
		errors = append(errors, "管理ユーザーが定義されていません")
	}

	if len(errors) > 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"valid": false,
			"errors": errors,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"valid": true,
		"message": "設定は有効です",
	})
}

// ExportConfig 設定をエクスポート
func (h *ConfigHandler) ExportConfig(c *gin.Context) {
	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// ダウンロード用のヘッダーを設定
	c.Header("Content-Type", "application/json")
	c.Header("Content-Disposition", "attachment; filename=lpg-config.json")

	c.JSON(http.StatusOK, config)
}

// ImportConfig 設定をインポート
func (h *ConfigHandler) ImportConfig(c *gin.Context) {
	var importConfig models.LPGConfig
	if err := c.ShouldBindJSON(&importConfig); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効な設定ファイル形式です",
		})
		return
	}

	// バックアップを作成してから保存
	if err := h.config.Save(&importConfig); err != nil {
		h.logger.Errorf("設定インポートエラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定のインポートに失敗しました",
		})
		return
	}

	h.logger.Info("設定をインポートしました")

	c.JSON(http.StatusOK, gin.H{
		"message": "設定をインポートしました",
		"revision": importConfig.Metadata.Revision,
	})
} 