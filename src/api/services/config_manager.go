// config_manager.go - Configuration Manager Service
// Version: 1.0.0
// Description: LPG設定ファイルの管理

package services

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
	"context"

	"github.com/lacis/lpg/src/api/models"
	"github.com/sirupsen/logrus"
	"github.com/xeipuuv/gojsonschema"
)

// ConfigManager 設定管理サービス
type ConfigManager struct {
	mu               sync.RWMutex
	config           *models.LPGConfig
	configPath       string
	schemaPath       string
	lastModified     time.Time
	logger           *logrus.Logger
	concurrent       int
	maxConcurrent    int
	rateLimitClients map[string]*time.Time
}

// NewConfigManager 設定マネージャーを作成
func NewConfigManager(configPath string, logger *logrus.Logger) *ConfigManager {
	return &ConfigManager{
		configPath:       configPath,
		schemaPath:       filepath.Join(filepath.Dir(configPath), "config.schema.json"),
		logger:           logger,
		maxConcurrent:    100,
		rateLimitClients: make(map[string]*time.Time),
	}
}

// Load 設定を読み込む
func (cm *ConfigManager) Load() error {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	cm.logger.Info("設定ファイルを読み込んでいます")

	// ファイルの存在確認
	if _, err := os.Stat(cm.configPath); os.IsNotExist(err) {
		cm.logger.Info("設定ファイルが存在しません。デフォルト設定を作成します")
		return cm.createDefaultConfig()
	}

	// ファイル読み込み
	data, err := os.ReadFile(cm.configPath)
	if err != nil {
		return fmt.Errorf("設定ファイルの読み込みエラー: %w", err)
	}

	// JSONスキーマ検証
	if err := cm.validateSchema(data); err != nil {
		return fmt.Errorf("スキーマ検証エラー: %w", err)
	}

	// JSONパース
	var config models.LPGConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return fmt.Errorf("JSONパースエラー: %w", err)
	}

	cm.config = &config
	cm.lastModified = time.Now()
	cm.logger.Info("設定ファイルを正常に読み込みました")

	return nil
}

// Save 設定を保存する
func (cm *ConfigManager) Save(config *models.LPGConfig) error {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	cm.logger.Info("設定ファイルを保存しています")

	// バックアップ作成
	if err := cm.createBackup(); err != nil {
		cm.logger.Warnf("バックアップ作成エラー: %v", err)
	}

	// メタデータ更新
	config.Metadata.Modified = time.Now()
	config.Metadata.Revision++

	// JSON生成
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("JSON生成エラー: %w", err)
	}

	// スキーマ検証
	if err := cm.validateSchema(data); err != nil {
		return fmt.Errorf("スキーマ検証エラー: %w", err)
	}

	// アトミック書き込み
	tempFile := cm.configPath + ".tmp"
	if err := os.WriteFile(tempFile, data, 0600); err != nil {
		return fmt.Errorf("一時ファイル書き込みエラー: %w", err)
	}

	if err := os.Rename(tempFile, cm.configPath); err != nil {
		os.Remove(tempFile)
		return fmt.Errorf("ファイル移動エラー: %w", err)
	}

	cm.config = config
	cm.lastModified = time.Now()
	cm.logger.Info("設定ファイルを正常に保存しました")

	return nil
}

// Get 現在の設定を取得
func (cm *ConfigManager) Get() *models.LPGConfig {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	return cm.config
}

// Deploy 設定を適用する
func (cm *ConfigManager) Deploy() error {
	cm.mu.RLock()
	defer cm.mu.RUnlock()

	cm.logger.Info("設定を適用しています")

	// Caddyに設定を適用
	if err := cm.applyCaddyConfig(); err != nil {
		return fmt.Errorf("Caddy設定適用エラー: %w", err)
	}

	cm.logger.Info("設定を正常に適用しました")
	return nil
}

// Rollback 設定をロールバック
func (cm *ConfigManager) Rollback(version int) error {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	cm.logger.Infof("設定をバージョン %d にロールバックしています", version)

	backupDir := filepath.Join(filepath.Dir(cm.configPath), "backups")
	backupFile := filepath.Join(backupDir, fmt.Sprintf("config_v%d.json", version))

	// バックアップファイルの存在確認
	if _, err := os.Stat(backupFile); os.IsNotExist(err) {
		return fmt.Errorf("バックアップファイルが見つかりません: v%d", version)
	}

	// バックアップファイル読み込み
	data, err := os.ReadFile(backupFile)
	if err != nil {
		return fmt.Errorf("バックアップファイル読み込みエラー: %w", err)
	}

	// スキーマ検証
	if err := cm.validateSchema(data); err != nil {
		return fmt.Errorf("バックアップファイルのスキーマ検証エラー: %w", err)
	}

	// 現在の設定をバックアップ
	if err := cm.createBackup(); err != nil {
		cm.logger.Warnf("現在の設定のバックアップ作成エラー: %v", err)
	}

	// ロールバック実行
	if err := os.WriteFile(cm.configPath, data, 0600); err != nil {
		return fmt.Errorf("ロールバック書き込みエラー: %w", err)
	}

	// 設定再読み込み
	if err := cm.Load(); err != nil {
		return fmt.Errorf("ロールバック後の設定読み込みエラー: %w", err)
	}

	cm.logger.Infof("設定を正常にバージョン %d にロールバックしました", version)
	return nil
}

// GetHistory 設定履歴を取得
func (cm *ConfigManager) GetHistory() ([]models.ConfigHistory, error) {
	backupDir := filepath.Join(filepath.Dir(cm.configPath), "backups")
	
	files, err := os.ReadDir(backupDir)
	if err != nil {
		if os.IsNotExist(err) {
			return []models.ConfigHistory{}, nil
		}
		return nil, fmt.Errorf("バックアップディレクトリ読み込みエラー: %w", err)
	}

	var history []models.ConfigHistory
	for _, file := range files {
		if file.IsDir() || !filepath.HasExt(file.Name(), ".json") {
			continue
		}

		var version int
		if _, err := fmt.Sscanf(file.Name(), "config_v%d.json", &version); err != nil {
			continue
		}

		info, err := file.Info()
		if err != nil {
			continue
		}

		history = append(history, models.ConfigHistory{
			Version:    version,
			ModifiedAt: info.ModTime(),
			ModifiedBy: "system", // TODO: ユーザー情報を保存
			Changes:    []string{}, // TODO: 変更内容を記録
		})
	}

	return history, nil
}

// createBackup バックアップを作成
func (cm *ConfigManager) createBackup() error {
	// 現在の設定ファイルが存在しない場合はスキップ
	if _, err := os.Stat(cm.configPath); os.IsNotExist(err) {
		return nil
	}

	// バックアップディレクトリ作成
	backupDir := filepath.Join(filepath.Dir(cm.configPath), "backups")
	if err := os.MkdirAll(backupDir, 0700); err != nil {
		return fmt.Errorf("バックアップディレクトリ作成エラー: %w", err)
	}

	// 現在の設定を読み込み
	current, err := os.ReadFile(cm.configPath)
	if err != nil {
		return fmt.Errorf("現在の設定読み込みエラー: %w", err)
	}

	// バックアップファイル名生成
	revision := 1
	if cm.config != nil {
		revision = cm.config.Metadata.Revision
	}
	backupFile := filepath.Join(backupDir, fmt.Sprintf("config_v%d.json", revision))

	// バックアップ作成
	if err := os.WriteFile(backupFile, current, 0600); err != nil {
		return fmt.Errorf("バックアップ書き込みエラー: %w", err)
	}

	// 古いバックアップを削除（5世代保持）
	return cm.cleanOldBackups(backupDir, 5)
}

// cleanOldBackups 古いバックアップを削除
func (cm *ConfigManager) cleanOldBackups(backupDir string, keepCount int) error {
	files, err := os.ReadDir(backupDir)
	if err != nil {
		return err
	}

	// バックアップファイルのみフィルタリング
	var backups []os.DirEntry
	for _, file := range files {
		if !file.IsDir() && filepath.HasExt(file.Name(), ".json") {
			backups = append(backups, file)
		}
	}

	// 保持数を超えている場合は古いものから削除
	if len(backups) > keepCount {
		for i := 0; i < len(backups)-keepCount; i++ {
			oldFile := filepath.Join(backupDir, backups[i].Name())
			if err := os.Remove(oldFile); err != nil {
				cm.logger.Warnf("古いバックアップの削除エラー: %v", err)
			}
		}
	}

	return nil
}

// validateSchema JSONスキーマ検証
func (cm *ConfigManager) validateSchema(data []byte) error {
	// スキーマファイルが存在しない場合はスキップ
	if _, err := os.Stat(cm.schemaPath); os.IsNotExist(err) {
		cm.logger.Warn("スキーマファイルが存在しないため、検証をスキップします")
		return nil
	}

	schemaLoader := gojsonschema.NewReferenceLoader("file://" + cm.schemaPath)
	documentLoader := gojsonschema.NewBytesLoader(data)

	result, err := gojsonschema.Validate(schemaLoader, documentLoader)
	if err != nil {
		return fmt.Errorf("スキーマ検証実行エラー: %w", err)
	}

	if !result.Valid() {
		var errors []string
		for _, err := range result.Errors() {
			errors = append(errors, err.String())
		}
		return fmt.Errorf("スキーマ検証失敗: %v", errors)
	}

	return nil
}

// createDefaultConfig デフォルト設定を作成
func (cm *ConfigManager) createDefaultConfig() error {
	config := &models.LPGConfig{
		Version: "1.0.0",
		Metadata: models.Metadata{
			Created:    time.Now(),
			Modified:   time.Now(),
			ModifiedBy: "system",
			Revision:   1,
		},
		HostDomains:   make(map[string]string),
		HostingDevice: make(map[string]map[string]models.Route),
		AdminUser: map[string]string{
			"lacisadmin": "$argon2id$v=19$m=65536,t=3,p=4$...", // TODO: 実際のハッシュ値
		},
		Endpoint: models.Endpoint{
			LogServer: "",
		},
		Options: models.Options{
			WebSocketTimeout: 600,
			LogRetentionDays: 30,
			SessionTimeout:   86400,
			MaxRequestSize:   10485760,
			RateLimit: models.RateLimit{
				RequestsPerMinute: 60,
				Burst:             120,
			},
		},
	}

	cm.config = config
	return cm.Save(config)
}

// applyCaddyConfig Caddyに設定を適用
func (cm *ConfigManager) applyCaddyConfig() error {
	// TODO: Caddy Admin APIを使用して設定を適用
	cm.logger.Info("Caddy設定の適用（未実装）")
	return nil
}

// CheckConcurrentLimit 同時接続数制限をチェック
func (cm *ConfigManager) CheckConcurrentLimit(clientIP string) bool {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	
	// 現在の同時接続数をチェック
	if cm.concurrent >= cm.maxConcurrent {
		cm.logger.Warnf("同時接続数上限に達しました: %d/%d (クライアント: %s)", cm.concurrent, cm.maxConcurrent, clientIP)
		return false
	}
	
	cm.concurrent++
	cm.logger.Debugf("同時接続数: %d/%d (クライアント: %s)", cm.concurrent, cm.maxConcurrent, clientIP)
	return true
}

// ReleaseConcurrentLimit 同時接続数制限を解放
func (cm *ConfigManager) ReleaseConcurrentLimit(clientIP string) {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	
	if cm.concurrent > 0 {
		cm.concurrent--
		cm.logger.Debugf("同時接続数解放: %d/%d (クライアント: %s)", cm.concurrent, cm.maxConcurrent, clientIP)
	}
}

// CheckRateLimit レート制限をチェック
func (cm *ConfigManager) CheckRateLimit(clientIP string) bool {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	
	now := time.Now()
	if lastRequest, exists := cm.rateLimitClients[clientIP]; exists {
		if now.Sub(*lastRequest) < time.Minute/time.Duration(cm.config.Options.RateLimit.RequestsPerMinute) {
			cm.logger.Warnf("レート制限に抵触: %s", clientIP)
			return false
		}
	}
	
	cm.rateLimitClients[clientIP] = &now
	
	// 古いエントリをクリーンアップ
	go cm.cleanupRateLimitClients()
	
	return true
}

// cleanupRateLimitClients 古いレート制限エントリをクリーンアップ
func (cm *ConfigManager) cleanupRateLimitClients() {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	
	now := time.Now()
	for ip, lastRequest := range cm.rateLimitClients {
		if now.Sub(*lastRequest) > 5*time.Minute {
			delete(cm.rateLimitClients, ip)
		}
	}
} 