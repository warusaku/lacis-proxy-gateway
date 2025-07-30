// devices.go - Device Routing Management Handlers
// Version: 1.0.0
// Description: デバイスルーティング管理のAPIハンドラー

package handlers

import (
	"fmt"
	"net"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/lacis/lpg/src/api/models"
	"github.com/lacis/lpg/src/api/services"
	"github.com/sirupsen/logrus"
)

// DeviceHandler デバイスハンドラー
type DeviceHandler struct {
	config *services.ConfigManager
	caddy  *services.CaddyClient
	logger *logrus.Logger
}

// NewDeviceHandler デバイスハンドラーを作成
func NewDeviceHandler(config *services.ConfigManager, caddy *services.CaddyClient, logger *logrus.Logger) *DeviceHandler {
	return &DeviceHandler{
		config: config,
		caddy:  caddy,
		logger: logger,
	}
}

// RouteInfo ルート情報（拡張版）
type RouteInfo struct {
	Domain   string   `json:"domain"`
	Path     string   `json:"path"`
	DeviceIP string   `json:"device_ip"`
	Port     []int    `json:"port"`
	SiteName string   `json:"sitename"`
	IPs      []string `json:"ips"`
	Status   string   `json:"status"`
}

// GetRoutes 全ルーティングルールを取得
func (h *DeviceHandler) GetRoutes(c *gin.Context) {
	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	routes := []RouteInfo{}
	
	// ドメインごとのルートを収集
	for domain, domainRoutes := range config.HostingDevice {
		for path, route := range domainRoutes {
			info := RouteInfo{
				Domain:   domain,
				Path:     path,
				DeviceIP: route.DeviceIP,
				Port:     route.Port,
				SiteName: route.SiteName,
				IPs:      route.IPs,
				Status:   "active", // TODO: 実際の接続状態を確認
			}
			routes = append(routes, info)
		}
	}

	// フィルタリング
	if domain := c.Query("domain"); domain != "" {
		filtered := []RouteInfo{}
		for _, route := range routes {
			if route.Domain == domain {
				filtered = append(filtered, route)
			}
		}
		routes = filtered
	}

	c.JSON(http.StatusOK, gin.H{
		"routes": routes,
		"total":  len(routes),
	})
}

// GetRoute 特定のルートを取得
func (h *DeviceHandler) GetRoute(c *gin.Context) {
	domain := c.Param("domain")
	path := c.Param("path")
	if path == "" {
		path = "/"
	}

	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// ドメインの存在確認
	domainRoutes, exists := config.HostingDevice[domain]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "ドメインが見つかりません",
		})
		return
	}

	// ルートの存在確認
	route, exists := domainRoutes[path]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "ルートが見つかりません",
		})
		return
	}

	info := RouteInfo{
		Domain:   domain,
		Path:     path,
		DeviceIP: route.DeviceIP,
		Port:     route.Port,
		SiteName: route.SiteName,
		IPs:      route.IPs,
		Status:   "active",
	}

	// 接続テスト
	if c.Query("test_connection") == "true" && route.DeviceIP != "" {
		testAddr := fmt.Sprintf("%s:%d", route.DeviceIP, 80)
		if len(route.Port) > 0 {
			testAddr = fmt.Sprintf("%s:%d", route.DeviceIP, route.Port[0])
		}
		
		if err := h.caddy.TestUpstream(testAddr); err != nil {
			info.Status = "unreachable"
		}
	}

	c.JSON(http.StatusOK, info)
}

// CreateRouteRequest ルート作成リクエスト
type CreateRouteRequest struct {
	Path     string   `json:"path" binding:"required"`
	DeviceIP string   `json:"device_ip"`
	Port     []int    `json:"port"`
	SiteName string   `json:"sitename"`
	IPs      []string `json:"ips"`
}

// CreateRoute ルートを作成
func (h *DeviceHandler) CreateRoute(c *gin.Context) {
	domain := c.Param("domain")
	
	var req CreateRouteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なリクエスト形式です",
		})
		return
	}

	// IPアドレスの妥当性確認
	if req.DeviceIP != "" {
		if ip := net.ParseIP(req.DeviceIP); ip == nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "無効なIPアドレス形式です",
			})
			return
		}
	}

	// ポート番号の妥当性確認
	for _, port := range req.Port {
		if port < 1 || port > 65535 {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "無効なポート番号です",
			})
			return
		}
	}

	// アクセス許可IPの妥当性確認
	for _, ipStr := range req.IPs {
		if ipStr != "any" {
			if _, _, err := net.ParseCIDR(ipStr); err != nil {
				if ip := net.ParseIP(ipStr); ip == nil {
					c.JSON(http.StatusBadRequest, gin.H{
						"error": "無効なIP/CIDR形式です: " + ipStr,
					})
					return
				}
			}
		}
	}

	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// ドメインの存在確認
	if _, exists := config.HostDomains[domain]; !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "ドメインが見つかりません",
		})
		return
	}

	// ルートが既に存在するか確認
	if routes, exists := config.HostingDevice[domain]; exists {
		if _, exists := routes[req.Path]; exists {
			c.JSON(http.StatusConflict, gin.H{
				"error": "ルートは既に存在します",
			})
			return
		}
	} else {
		config.HostingDevice[domain] = make(map[string]models.Route)
	}

	// ルートを作成
	route := models.Route{
		DeviceIP: req.DeviceIP,
		Port:     req.Port,
		SiteName: req.SiteName,
		IPs:      req.IPs,
	}

	// デフォルト値の設定
	if len(route.IPs) == 0 {
		route.IPs = []string{"any"}
	}

	config.HostingDevice[domain][req.Path] = route

	// 設定を保存
	if err := h.config.Save(config); err != nil {
		h.logger.Errorf("設定保存エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の保存に失敗しました",
		})
		return
	}

	h.logger.Infof("ルートを作成しました: %s%s", domain, req.Path)

	c.JSON(http.StatusCreated, gin.H{
		"message": "ルートを作成しました",
		"domain":  domain,
		"path":    req.Path,
	})
}

// UpdateRouteRequest ルート更新リクエスト
type UpdateRouteRequest struct {
	DeviceIP string   `json:"device_ip"`
	Port     []int    `json:"port"`
	SiteName string   `json:"sitename"`
	IPs      []string `json:"ips"`
}

// UpdateRoute ルートを更新
func (h *DeviceHandler) UpdateRoute(c *gin.Context) {
	domain := c.Param("domain")
	path := c.Param("path")
	if path == "" {
		path = "/"
	}

	var req UpdateRouteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なリクエスト形式です",
		})
		return
	}

	// IPアドレスの妥当性確認
	if req.DeviceIP != "" {
		if ip := net.ParseIP(req.DeviceIP); ip == nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "無効なIPアドレス形式です",
			})
			return
		}
	}

	// ポート番号の妥当性確認
	for _, port := range req.Port {
		if port < 1 || port > 65535 {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "無効なポート番号です",
			})
			return
		}
	}

	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// ドメインとルートの存在確認
	domainRoutes, exists := config.HostingDevice[domain]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "ドメインが見つかりません",
		})
		return
	}

	if _, exists := domainRoutes[path]; !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "ルートが見つかりません",
		})
		return
	}

	// ルートを更新
	route := models.Route{
		DeviceIP: req.DeviceIP,
		Port:     req.Port,
		SiteName: req.SiteName,
		IPs:      req.IPs,
	}

	if len(route.IPs) == 0 {
		route.IPs = []string{"any"}
	}

	config.HostingDevice[domain][path] = route

	// 設定を保存
	if err := h.config.Save(config); err != nil {
		h.logger.Errorf("設定保存エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の保存に失敗しました",
		})
		return
	}

	h.logger.Infof("ルートを更新しました: %s%s", domain, path)

	c.JSON(http.StatusOK, gin.H{
		"message": "ルートを更新しました",
		"domain":  domain,
		"path":    path,
	})
}

// DeleteRoute ルートを削除
func (h *DeviceHandler) DeleteRoute(c *gin.Context) {
	domain := c.Param("domain")
	path := c.Param("path")
	if path == "" {
		path = "/"
	}

	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// ドメインとルートの存在確認
	domainRoutes, exists := config.HostingDevice[domain]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "ドメインが見つかりません",
		})
		return
	}

	if _, exists := domainRoutes[path]; !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "ルートが見つかりません",
		})
		return
	}

	// ルートを削除
	delete(config.HostingDevice[domain], path)

	// 設定を保存
	if err := h.config.Save(config); err != nil {
		h.logger.Errorf("設定保存エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の保存に失敗しました",
		})
		return
	}

	h.logger.Infof("ルートを削除しました: %s%s", domain, path)

	c.JSON(http.StatusOK, gin.H{
		"message": "ルートを削除しました",
		"domain":  domain,
		"path":    path,
	})
}

// TestConnection デバイスへの接続をテスト
func (h *DeviceHandler) TestConnection(c *gin.Context) {
	var req struct {
		DeviceIP string `json:"device_ip" binding:"required,ip"`
		Port     int    `json:"port"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なリクエスト形式です",
		})
		return
	}

	if req.Port == 0 {
		req.Port = 80
	}

	testAddr := fmt.Sprintf("%s:%d", req.DeviceIP, req.Port)
	
	err := h.caddy.TestUpstream(testAddr)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"reachable": false,
			"error":     err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"reachable": true,
		"address":   testAddr,
	})
} 