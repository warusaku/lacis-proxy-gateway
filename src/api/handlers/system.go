// system.go - System Information Handlers
// Version: 1.0.0
// Description: システム情報とメトリクスのAPIハンドラー

package handlers

import (
	"fmt"
	"net/http"
	"os"
	"runtime"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/lacis/lpg/src/api/services"
	"github.com/sirupsen/logrus"
)

// SystemHandler システムハンドラー
type SystemHandler struct {
	metrics *services.MetricsCollector
	config  *services.ConfigManager
	logger  *logrus.Logger
	startTime time.Time
}

// NewSystemHandler システムハンドラーを作成
func NewSystemHandler(metrics *services.MetricsCollector, config *services.ConfigManager, logger *logrus.Logger) *SystemHandler {
	return &SystemHandler{
		metrics:   metrics,
		config:    config,
		logger:    logger,
		startTime: time.Now(),
	}
}

// SystemInfo システム情報
type SystemInfo struct {
	Hostname    string    `json:"hostname"`
	OS          string    `json:"os"`
	Arch        string    `json:"arch"`
	CPUCount    int       `json:"cpu_count"`
	GoVersion   string    `json:"go_version"`
	Uptime      string    `json:"uptime"`
	UptimeHours float64   `json:"uptime_hours"`
	StartTime   time.Time `json:"start_time"`
}

// GetSystemInfo システム情報を取得
func (h *SystemHandler) GetSystemInfo(c *gin.Context) {
	hostname, _ := os.Hostname()
	
	uptime := time.Since(h.startTime)
	uptimeHours := uptime.Hours()
	
	info := SystemInfo{
		Hostname:    hostname,
		OS:          runtime.GOOS,
		Arch:        runtime.GOARCH,
		CPUCount:    runtime.NumCPU(),
		GoVersion:   runtime.Version(),
		Uptime:      formatDuration(uptime),
		UptimeHours: uptimeHours,
		StartTime:   h.startTime,
	}

	c.JSON(http.StatusOK, info)
}

// GetMetrics メトリクスを取得
func (h *SystemHandler) GetMetrics(c *gin.Context) {
	metrics := h.metrics.Get()
	if metrics == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "メトリクスの取得に失敗しました",
		})
		return
	}

	c.JSON(http.StatusOK, metrics)
}

// HealthCheck ヘルスチェック
func (h *SystemHandler) HealthCheck(c *gin.Context) {
	health := gin.H{
		"status": "healthy",
		"timestamp": time.Now(),
		"uptime": formatDuration(time.Since(h.startTime)),
	}

	// 詳細チェック
	if c.Query("detailed") == "true" {
		checks := gin.H{}
		
		// 設定ファイルチェック
		if h.config.Get() != nil {
			checks["config"] = "ok"
		} else {
			checks["config"] = "error"
			health["status"] = "degraded"
		}

		// メトリクスチェック
		if metrics := h.metrics.Get(); metrics != nil {
			checks["metrics"] = "ok"
			
			// CPU使用率チェック
			if metrics.CPU.UsagePercent > 90 {
				checks["cpu"] = "warning"
				health["status"] = "degraded"
			} else {
				checks["cpu"] = "ok"
			}

			// メモリ使用率チェック
			if metrics.Memory.UsedPercent > 90 {
				checks["memory"] = "warning"
				health["status"] = "degraded"
			} else {
				checks["memory"] = "ok"
			}

			// ディスク使用率チェック
			if metrics.Disk.UsedPercent > 90 {
				checks["disk"] = "warning"
				health["status"] = "degraded"
			} else {
				checks["disk"] = "ok"
			}
		} else {
			checks["metrics"] = "error"
		}

		health["checks"] = checks
	}

	statusCode := http.StatusOK
	if health["status"] != "healthy" {
		statusCode = http.StatusServiceUnavailable
	}

	c.JSON(statusCode, health)
}

// GetVersion バージョン情報を取得
func (h *SystemHandler) GetVersion(c *gin.Context) {
	version := gin.H{
		"version": "1.0.0",
		"api_version": "v1",
		"build_date": "2025-01-11",
		"go_version": runtime.Version(),
	}

	c.JSON(http.StatusOK, version)
}

// GetNetworkInfo ネットワーク情報を取得
func (h *SystemHandler) GetNetworkInfo(c *gin.Context) {
	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// ネットワーク設定情報を構築
	networkInfo := gin.H{
		"domains": len(config.HostDomains),
		"routes": 0,
		"vlans": []gin.H{},
	}

	// ルート数をカウント
	routeCount := 0
	for _, routes := range config.HostingDevice {
		routeCount += len(routes)
	}
	networkInfo["routes"] = routeCount

	// VLAN情報を構築
	vlanMap := make(map[string][]string)
	for domain, subnet := range config.HostDomains {
		vlanMap[subnet] = append(vlanMap[subnet], domain)
	}

	vlans := []gin.H{}
	for subnet, domains := range vlanMap {
		vlans = append(vlans, gin.H{
			"subnet": subnet,
			"domains": domains,
			"domain_count": len(domains),
		})
	}
	networkInfo["vlans"] = vlans

	c.JSON(http.StatusOK, networkInfo)
}

// GetLogs 最近のログを取得
func (h *SystemHandler) GetLogs(c *gin.Context) {
	// TODO: ログサービスから最近のログを取得
	// 現在は簡易実装
	
	logs := []gin.H{
		{
			"timestamp": time.Now().Add(-5 * time.Minute),
			"level": "info",
			"message": "設定を更新しました",
			"source": "config",
		},
		{
			"timestamp": time.Now().Add(-10 * time.Minute),
			"level": "warning",
			"message": "接続テストに失敗しました: 192.168.234.10",
			"source": "caddy",
		},
	}

	limit := 100
	if limitParam := c.Query("limit"); limitParam != "" {
		// パース処理（省略）
	}

	c.JSON(http.StatusOK, gin.H{
		"logs": logs,
		"total": len(logs),
		"limit": limit,
	})
}

// formatDuration 時間を読みやすい形式にフォーマット
func formatDuration(d time.Duration) string {
	days := int(d.Hours() / 24)
	hours := int(d.Hours()) % 24
	minutes := int(d.Minutes()) % 60

	if days > 0 {
		return fmt.Sprintf("%d日 %d時間 %d分", days, hours, minutes)
	} else if hours > 0 {
		return fmt.Sprintf("%d時間 %d分", hours, minutes)
	} else {
		return fmt.Sprintf("%d分", minutes)
	}
} 