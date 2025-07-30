// domains.go - Domain Management Handlers
// Version: 1.0.0
// Description: ドメイン管理のAPIハンドラー

package handlers

import (
	"net"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/lacis/lpg/src/api/models"
	"github.com/lacis/lpg/src/api/services"
	"github.com/sirupsen/logrus"
)

// DomainHandler ドメインハンドラー
type DomainHandler struct {
	config *services.ConfigManager
	caddy  *services.CaddyClient
	logger *logrus.Logger
}

// NewDomainHandler ドメインハンドラーを作成
func NewDomainHandler(config *services.ConfigManager, caddy *services.CaddyClient, logger *logrus.Logger) *DomainHandler {
	return &DomainHandler{
		config: config,
		caddy:  caddy,
		logger: logger,
	}
}

// DomainInfo ドメイン情報
type DomainInfo struct {
	Domain     string              `json:"domain"`
	Subnet     string              `json:"subnet"`
	Devices    int                 `json:"devices"`
	CertStatus string              `json:"cert_status"`
	Routes     map[string]models.Route `json:"routes,omitempty"`
}

// GetDomains ドメイン一覧を取得
func (h *DomainHandler) GetDomains(c *gin.Context) {
	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// ドメイン情報を構築
	domains := []DomainInfo{}
	for domain, subnet := range config.HostDomains {
		info := DomainInfo{
			Domain:     domain,
			Subnet:     subnet,
			CertStatus: "unknown", // TODO: Caddyから証明書状態を取得
		}

		// デバイス数をカウント
		if routes, exists := config.HostingDevice[domain]; exists {
			info.Devices = len(routes)
			if c.Query("include_routes") == "true" {
				info.Routes = routes
			}
		}

		domains = append(domains, info)
	}

	c.JSON(http.StatusOK, gin.H{
		"domains": domains,
		"total":   len(domains),
	})
}

// GetDomain 特定のドメイン情報を取得
func (h *DomainHandler) GetDomain(c *gin.Context) {
	domain := c.Param("domain")
	
	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	subnet, exists := config.HostDomains[domain]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "ドメインが見つかりません",
		})
		return
	}

	info := DomainInfo{
		Domain:     domain,
		Subnet:     subnet,
		CertStatus: "unknown",
	}

	// ルート情報を含める
	if routes, exists := config.HostingDevice[domain]; exists {
		info.Routes = routes
		info.Devices = len(routes)
	}

	// 証明書情報を取得
	certs, err := h.caddy.GetCertificates()
	if err == nil {
		for _, cert := range certs {
			for _, san := range cert.SANs {
				if san == domain {
					info.CertStatus = cert.Status
					break
				}
			}
		}
	}

	c.JSON(http.StatusOK, info)
}

// CreateDomainRequest ドメイン作成リクエスト
type CreateDomainRequest struct {
	Domain string `json:"domain" binding:"required,hostname"`
	Subnet string `json:"subnet" binding:"required"`
}

// CreateDomain ドメインを作成
func (h *DomainHandler) CreateDomain(c *gin.Context) {
	var req CreateDomainRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なリクエスト形式です",
		})
		return
	}

	// サブネットの妥当性を確認
	_, _, err := net.ParseCIDR(req.Subnet)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なサブネット形式です",
		})
		return
	}

	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// 既存チェック
	if _, exists := config.HostDomains[req.Domain]; exists {
		c.JSON(http.StatusConflict, gin.H{
			"error": "ドメインは既に存在します",
		})
		return
	}

	// ドメインを追加
	config.HostDomains[req.Domain] = req.Subnet

	// 空のルーティングエントリを作成
	if config.HostingDevice == nil {
		config.HostingDevice = make(map[string]map[string]models.Route)
	}
	config.HostingDevice[req.Domain] = make(map[string]models.Route)

	// 設定を保存
	if err := h.config.Save(config); err != nil {
		h.logger.Errorf("設定保存エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の保存に失敗しました",
		})
		return
	}

	h.logger.Infof("ドメインを作成しました: %s", req.Domain)

	c.JSON(http.StatusCreated, gin.H{
		"message": "ドメインを作成しました",
		"domain":  req.Domain,
	})
}

// UpdateDomainRequest ドメイン更新リクエスト
type UpdateDomainRequest struct {
	Subnet string `json:"subnet" binding:"required"`
}

// UpdateDomain ドメインを更新
func (h *DomainHandler) UpdateDomain(c *gin.Context) {
	domain := c.Param("domain")
	
	var req UpdateDomainRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なリクエスト形式です",
		})
		return
	}

	// サブネットの妥当性を確認
	_, _, err := net.ParseCIDR(req.Subnet)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "無効なサブネット形式です",
		})
		return
	}

	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// 存在チェック
	if _, exists := config.HostDomains[domain]; !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "ドメインが見つかりません",
		})
		return
	}

	// サブネットを更新
	config.HostDomains[domain] = req.Subnet

	// 設定を保存
	if err := h.config.Save(config); err != nil {
		h.logger.Errorf("設定保存エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の保存に失敗しました",
		})
		return
	}

	h.logger.Infof("ドメインを更新しました: %s", domain)

	c.JSON(http.StatusOK, gin.H{
		"message": "ドメインを更新しました",
		"domain":  domain,
	})
}

// DeleteDomain ドメインを削除
func (h *DomainHandler) DeleteDomain(c *gin.Context) {
	domain := c.Param("domain")
	
	config := h.config.Get()
	if config == nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の取得に失敗しました",
		})
		return
	}

	// 存在チェック
	if _, exists := config.HostDomains[domain]; !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "ドメインが見つかりません",
		})
		return
	}

	// 関連するルーティングがあるか確認
	if routes, exists := config.HostingDevice[domain]; exists && len(routes) > 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "ドメインに関連するルーティングが存在します",
			"routes": len(routes),
		})
		return
	}

	// ドメインを削除
	delete(config.HostDomains, domain)
	delete(config.HostingDevice, domain)

	// 設定を保存
	if err := h.config.Save(config); err != nil {
		h.logger.Errorf("設定保存エラー: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "設定の保存に失敗しました",
		})
		return
	}

	h.logger.Infof("ドメインを削除しました: %s", domain)

	c.JSON(http.StatusOK, gin.H{
		"message": "ドメインを削除しました",
		"domain":  domain,
	})
} 