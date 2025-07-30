// config.go - Configuration Management
// Version: 1.0.0
// Description: アプリケーション設定の管理

package config

import (
	"fmt"
	"os"
	"time"

	"github.com/spf13/viper"
)

// Config アプリケーション設定
type Config struct {
	Environment string        `mapstructure:"environment"`
	Port        int           `mapstructure:"port"`
	ConfigPath  string        `mapstructure:"config_path"`
	TLS         TLSConfig     `mapstructure:"tls"`
	JWT         JWTConfig     `mapstructure:"jwt"`
	Caddy       CaddyConfig   `mapstructure:"caddy"`
	Log         LogConfig     `mapstructure:"log"`
	CORS        CORSConfig    `mapstructure:"cors"`
	RateLimit   RateLimitConfig `mapstructure:"rate_limit"`
}

// TLSConfig TLS設定
type TLSConfig struct {
	CertFile string `mapstructure:"cert_file"`
	KeyFile  string `mapstructure:"key_file"`
}

// JWTConfig JWT設定
type JWTConfig struct {
	Secret    string        `mapstructure:"secret"`
	ExpiresIn time.Duration `mapstructure:"expires_in"`
}

// CaddyConfig Caddy連携設定
type CaddyConfig struct {
	AdminAPI string `mapstructure:"admin_api"`
}

// LogConfig ログ設定
type LogConfig struct {
	Endpoint string        `mapstructure:"endpoint"`
	Interval time.Duration `mapstructure:"interval"`
}

// CORSConfig CORS設定
type CORSConfig struct {
	AllowOrigins     []string `mapstructure:"allow_origins"`
	AllowMethods     []string `mapstructure:"allow_methods"`
	AllowHeaders     []string `mapstructure:"allow_headers"`
	ExposeHeaders    []string `mapstructure:"expose_headers"`
	AllowCredentials bool     `mapstructure:"allow_credentials"`
	MaxAge           int      `mapstructure:"max_age"`
}

// RateLimitConfig レート制限設定
type RateLimitConfig struct {
	RequestsPerMinute int `mapstructure:"requests_per_minute"`
	Burst             int `mapstructure:"burst"`
}

// Load 設定を読み込む
func Load() (*Config, error) {
	viper.SetConfigName("app")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("./config")
	viper.AddConfigPath(".")
	
	// 環境変数の設定
	viper.SetEnvPrefix("LPG")
	viper.AutomaticEnv()
	
	// デフォルト値の設定
	setDefaults()
	
	// 設定ファイルの読み込み
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("設定ファイルの読み込みエラー: %w", err)
		}
	}
	
	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("設定のアンマーシャルエラー: %w", err)
	}
	
	// 必須項目の検証
	if err := validate(&config); err != nil {
		return nil, err
	}
	
	return &config, nil
}

// setDefaults デフォルト値を設定
func setDefaults() {
	// 基本設定
	viper.SetDefault("environment", "development")
	viper.SetDefault("port", 8443)
	viper.SetDefault("config_path", "/etc/lpg/config.json")
	
	// TLS設定
	viper.SetDefault("tls.cert_file", "./certs/server.crt")
	viper.SetDefault("tls.key_file", "./certs/server.key")
	
	// JWT設定
	viper.SetDefault("jwt.secret", generateRandomSecret())
	viper.SetDefault("jwt.expires_in", 24*time.Hour)
	
	// Caddy設定
	viper.SetDefault("caddy.admin_api", "http://localhost:2019")
	
	// ログ設定
	viper.SetDefault("log.endpoint", "")
	viper.SetDefault("log.interval", 15*time.Minute)
	
	// CORS設定
	viper.SetDefault("cors.allow_origins", []string{"*"})
	viper.SetDefault("cors.allow_methods", []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"})
	viper.SetDefault("cors.allow_headers", []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"})
	viper.SetDefault("cors.expose_headers", []string{"Link"})
	viper.SetDefault("cors.allow_credentials", true)
	viper.SetDefault("cors.max_age", 300)
	
	// レート制限設定
	viper.SetDefault("rate_limit.requests_per_minute", 60)
	viper.SetDefault("rate_limit.burst", 120)
}

// validate 設定を検証
func validate(config *Config) error {
	// ポート番号の検証
	if config.Port < 1 || config.Port > 65535 {
		return fmt.Errorf("無効なポート番号: %d", config.Port)
	}
	
	// TLS証明書の存在確認
	if _, err := os.Stat(config.TLS.CertFile); err != nil {
		return fmt.Errorf("TLS証明書ファイルが見つかりません: %s", config.TLS.CertFile)
	}
	if _, err := os.Stat(config.TLS.KeyFile); err != nil {
		return fmt.Errorf("TLS秘密鍵ファイルが見つかりません: %s", config.TLS.KeyFile)
	}
	
	// JWT秘密鍵の長さ確認
	if len(config.JWT.Secret) < 32 {
		return fmt.Errorf("JWT秘密鍵が短すぎます（最低32文字）")
	}
	
	// 設定ファイルパスの検証
	if config.ConfigPath == "" {
		return fmt.Errorf("設定ファイルパスが指定されていません")
	}
	
	return nil
}

// generateRandomSecret ランダムな秘密鍵を生成
func generateRandomSecret() string {
	// 本番環境では必ず環境変数で設定すること
	return "CHANGE_THIS_SECRET_IN_PRODUCTION_ENVIRONMENT_123"
}