// models.go - Data Models
// Version: 1.0.0
// Description: LPGのデータモデル定義

package models

import (
	"time"
)

// LPGConfig LPG設定構造体
type LPGConfig struct {
	Schema        string                      `json:"$schema,omitempty"`
	Version       string                      `json:"version"`
	Metadata      Metadata                    `json:"metadata"`
	HostDomains   map[string]string           `json:"hostdomains"`
	HostingDevice map[string]map[string]Route `json:"hostingdevice"`
	AdminUser     map[string]string           `json:"adminuser"`
	Endpoint      Endpoint                    `json:"endpoint"`
	Options       Options                     `json:"options"`
}

// Metadata メタデータ
type Metadata struct {
	Created    time.Time `json:"created"`
	Modified   time.Time `json:"modified"`
	ModifiedBy string    `json:"modifiedBy"`
	Revision   int       `json:"revision"`
}

// Route ルーティングルール
type Route struct {
	DeviceIP string   `json:"deviceip"`
	Port     []int    `json:"port"`
	SiteName string   `json:"sitename"`
	IPs      []string `json:"ips"`
}

// Endpoint エンドポイント設定
type Endpoint struct {
	LogServer string `json:"logserver"`
}

// Options オプション設定
type Options struct {
	WebSocketTimeout  int       `json:"websocket_timeout"`
	LogRetentionDays  int       `json:"log_retention_days"`
	SessionTimeout    int       `json:"session_timeout"`
	MaxRequestSize    int       `json:"max_request_size"`
	RateLimit         RateLimit `json:"rate_limit"`
}

// RateLimit レート制限設定
type RateLimit struct {
	RequestsPerMinute int `json:"requests_per_minute"`
	Burst             int `json:"burst"`
}

// User ユーザー情報
type User struct {
	Username             string    `json:"username"`
	PasswordHash         string    `json:"-"`
	RequirePasswordChange bool      `json:"requirePasswordChange"`
	LastLogin            time.Time `json:"lastLogin"`
	FailedAttempts       int       `json:"failedAttempts"`
	LockedUntil          time.Time `json:"lockedUntil"`
}

// Session セッション情報
type Session struct {
	Token     string    `json:"token"`
	Username  string    `json:"username"`
	ExpiresAt time.Time `json:"expiresAt"`
	CreatedAt time.Time `json:"createdAt"`
}

// Domain ドメイン情報
type Domain struct {
	Name       string      `json:"domain"`
	Subnet     string      `json:"subnet"`
	PathCount  int         `json:"pathCount"`
	Enabled    bool        `json:"enabled"`
	Certificate Certificate `json:"certificate,omitempty"`
}

// Certificate 証明書情報
type Certificate struct {
	Issuer        string    `json:"issuer"`
	NotBefore     time.Time `json:"notBefore"`
	NotAfter      time.Time `json:"notAfter"`
	DaysRemaining int       `json:"daysRemaining"`
	Status        string    `json:"status"`
	AutoRenew     bool      `json:"autoRenew"`
}

// Device デバイス（ルーティングルール）
type Device struct {
	ID         string     `json:"id"`
	Domain     string     `json:"domain"`
	Path       string     `json:"path"`
	DeviceIP   string     `json:"deviceip"`
	Port       []int      `json:"port"`
	SiteName   string     `json:"sitename"`
	IPs        []string   `json:"ips"`
	Enabled    bool       `json:"enabled"`
	Statistics Statistics `json:"statistics,omitempty"`
}

// Statistics 統計情報
type Statistics struct {
	Requests24h   int       `json:"requests24h"`
	LastAccess    time.Time `json:"lastAccess"`
	TotalRequests int64     `json:"totalRequests"`
	TotalBytes    int64     `json:"totalBytes"`
}

// LogEntry ログエントリ
type LogEntry struct {
	Timestamp time.Time     `json:"timestamp"`
	Host      string        `json:"host"`
	Path      string        `json:"path"`
	Method    string        `json:"method"`
	Status    int           `json:"status"`
	Bytes     int64         `json:"bytes"`
	Duration  int           `json:"duration"`
	IP        string        `json:"ip"`
	UserAgent string        `json:"userAgent"`
	SiteName  string        `json:"sitename"`
	Upstream  string        `json:"upstream"`
	Protocol  string        `json:"protocol"`
	TLS       TLSInfo       `json:"tls,omitempty"`
}

// TLSInfo TLS情報
type TLSInfo struct {
	Version string `json:"version"`
	Cipher  string `json:"cipher"`
}

// SystemStatus システム状態
type SystemStatus struct {
	Status   string             `json:"status"`
	Uptime   int64              `json:"uptime"`
	Version  string             `json:"version"`
	Services map[string]string  `json:"services"`
}

// SystemMetrics システムメトリクス
type SystemMetrics struct {
	CPU     CPUMetrics     `json:"cpu"`
	Memory  MemoryMetrics  `json:"memory"`
	Disk    DiskMetrics    `json:"disk"`
	Network NetworkMetrics `json:"network"`
}

// CPUMetrics CPU使用率
type CPUMetrics struct {
	Usage float64 `json:"usage"`
	Cores int     `json:"cores"`
}

// MemoryMetrics メモリ使用率
type MemoryMetrics struct {
	Total int64   `json:"total"`
	Used  int64   `json:"used"`
	Free  int64   `json:"free"`
	Usage float64 `json:"usage"`
}

// DiskMetrics ディスク使用率
type DiskMetrics struct {
	Total int64   `json:"total"`
	Used  int64   `json:"used"`
	Free  int64   `json:"free"`
	Usage float64 `json:"usage"`
}

// NetworkMetrics ネットワーク統計
type NetworkMetrics struct {
	RxBytes int64   `json:"rx_bytes"`
	TxBytes int64   `json:"tx_bytes"`
	RxRate  float64 `json:"rx_rate"`
	TxRate  float64 `json:"tx_rate"`
}

// Backup バックアップ情報
type Backup struct {
	ID        string    `json:"backupId"`
	Size      int64     `json:"size"`
	CreatedAt time.Time `json:"createdAt"`
	Version   int       `json:"version"`
}

// ConfigHistory 設定履歴
type ConfigHistory struct {
	Version    int       `json:"version"`
	ModifiedAt time.Time `json:"modifiedAt"`
	ModifiedBy string    `json:"modifiedBy"`
	Changes    []string  `json:"changes"`
}

// APIResponse API共通レスポンス
type APIResponse struct {
	Status    string      `json:"status"`
	Data      interface{} `json:"data,omitempty"`
	Error     *APIError   `json:"error,omitempty"`
	Timestamp time.Time   `json:"timestamp"`
}

// APIError APIエラー
type APIError struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

// LoginRequest ログインリクエスト
type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// LoginResponse ログインレスポンス
type LoginResponse struct {
	Token                 string `json:"token"`
	ExpiresIn             int    `json:"expiresIn"`
	ExpiresAt             string `json:"expiresAt"`
	RequirePasswordChange bool   `json:"requirePasswordChange"`
}

// ChangePasswordRequest パスワード変更リクエスト
type ChangePasswordRequest struct {
	CurrentPassword string `json:"currentPassword" binding:"required"`
	NewPassword     string `json:"newPassword" binding:"required,min=8"`
	ConfirmPassword string `json:"confirmPassword" binding:"required,eqfield=NewPassword"`
}

// CreateDomainRequest ドメイン作成リクエスト
type CreateDomainRequest struct {
	Domain string `json:"domain" binding:"required,hostname"`
	Subnet string `json:"subnet" binding:"required,cidr"`
}

// UpdateDomainRequest ドメイン更新リクエスト
type UpdateDomainRequest struct {
	Subnet  string `json:"subnet" binding:"omitempty,cidr"`
	Enabled *bool  `json:"enabled"`
}

// CreateDeviceRequest デバイス作成リクエスト
type CreateDeviceRequest struct {
	Domain   string   `json:"domain" binding:"required"`
	Path     string   `json:"path" binding:"required"`
	DeviceIP string   `json:"deviceip" binding:"required,ip"`
	Port     []int    `json:"port" binding:"required,min=1"`
	SiteName string   `json:"sitename" binding:"required"`
	IPs      []string `json:"ips" binding:"required,min=1"`
}

// TestConnectionRequest 接続テストリクエスト
type TestConnectionRequest struct {
	Target  string `json:"target" binding:"required,ip"`
	Port    int    `json:"port" binding:"required,min=1,max=65535"`
	Timeout int    `json:"timeout" binding:"omitempty,min=1,max=30"`
}

// TestConnectionResponse 接続テストレスポンス
type TestConnectionResponse struct {
	Reachable    bool   `json:"reachable"`
	ResponseTime int    `json:"responseTime"`
	Message      string `json:"message"`
} 