// caddy_client.go - Caddy Admin API Client
// Version: 1.0.0
// Description: Caddy Admin APIとの連携

package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/lacis/lpg/src/api/models"
	"github.com/sirupsen/logrus"
)

// CaddyClient Caddy Admin APIクライアント
type CaddyClient struct {
	adminAPI     string
	client       *http.Client
	logger       *logrus.Logger
	poolSize     int
	connPool     chan *http.Client
	rateLimiter  chan struct{}
}

// CaddyConfig Caddy設定構造
type CaddyConfig struct {
	Apps map[string]interface{} `json:"apps"`
}

// HTTPApp HTTP アプリケーション設定
type HTTPApp struct {
	Servers map[string]*Server `json:"servers"`
}

// Server サーバー設定
type Server struct {
	Listen []string       `json:"listen"`
	Routes []Route        `json:"routes"`
	TLSConnectionPolicies []interface{} `json:"tls_connection_policies,omitempty"`
}

// Route ルート設定
type Route struct {
	Match   []Match   `json:"match,omitempty"`
	Handle  []Handler `json:"handle"`
	Terminal bool     `json:"terminal,omitempty"`
}

// Match マッチ条件
type Match struct {
	Host []string `json:"host,omitempty"`
	Path []string `json:"path,omitempty"`
}

// Handler ハンドラー設定
type Handler struct {
	Handler   string            `json:"handler"`
	Upstreams []Upstream        `json:"upstreams,omitempty"`
	Headers   *HeaderOperations `json:"headers,omitempty"`
}

// Upstream アップストリーム設定
type Upstream struct {
	Dial string `json:"dial"`
}

// HeaderOperations ヘッダー操作
type HeaderOperations struct {
	Request *HeaderMods `json:"request,omitempty"`
}

// HeaderMods ヘッダー変更
type HeaderMods struct {
	Set map[string][]string `json:"set,omitempty"`
}

// NewCaddyClient Caddyクライアントを作成
func NewCaddyClient(adminAPI string, logger *logrus.Logger) *CaddyClient {
	poolSize := 20
	connPool := make(chan *http.Client, poolSize)
	rateLimiter := make(chan struct{}, 10) // 同時10接続制限
	
	// 接続プールを初期化
	for i := 0; i < poolSize; i++ {
		connPool <- &http.Client{
			Timeout: 10 * time.Second,
			Transport: &http.Transport{
				MaxIdleConns:        10,
				MaxIdleConnsPerHost: 2,
				IdleConnTimeout:     30 * time.Second,
			},
		}
	}
	
	return &CaddyClient{
		adminAPI:    adminAPI,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
		logger:      logger,
		poolSize:    poolSize,
		connPool:    connPool,
		rateLimiter: rateLimiter,
	}
}

// SyncConfig LPG設定をCaddyに同期
func (cc *CaddyClient) SyncConfig(lpgConfig *models.LPGConfig) error {
	cc.logger.Info("Caddy設定を同期しています")

	// LPG設定からCaddy設定を生成
	caddyConfig, err := cc.buildCaddyConfig(lpgConfig)
	if err != nil {
		return fmt.Errorf("Caddy設定生成エラー: %w", err)
	}

	// 設定を適用
	if err := cc.applyConfig(caddyConfig); err != nil {
		return fmt.Errorf("Caddy設定適用エラー: %w", err)
	}

	cc.logger.Info("Caddy設定を正常に同期しました")
	return nil
}

// buildCaddyConfig LPG設定からCaddy設定を構築
func (cc *CaddyClient) buildCaddyConfig(lpgConfig *models.LPGConfig) (*CaddyConfig, error) {
	httpApp := &HTTPApp{
		Servers: map[string]*Server{
			"srv0": {
				Listen: []string{":80", ":443"},
				Routes: cc.buildRoutes(lpgConfig),
			},
		},
	}

	config := &CaddyConfig{
		Apps: map[string]interface{}{
			"http": httpApp,
		},
	}

	return config, nil
}

// buildRoutes ルーティングルールを構築
func (cc *CaddyClient) buildRoutes(lpgConfig *models.LPGConfig) []Route {
	var routes []Route

	// ホストドメインごとにルートを作成
	for host, deviceRoutes := range lpgConfig.HostingDevice {
		// ホストが許可されているか確認
		if _, ok := lpgConfig.HostDomains[host]; !ok {
			cc.logger.Warnf("未許可のホスト: %s", host)
			continue
		}

		// パスごとのルート
		for path, route := range deviceRoutes {
			if route.DeviceIP == "" {
				// 空の場合は拒否ルート
				routes = append(routes, cc.buildRejectRoute(host, path))
			} else {
				// プロキシルート
				routes = append(routes, cc.buildProxyRoute(host, path, route))
			}
		}
	}

	// デフォルトの拒否ルート
	routes = append(routes, Route{
		Handle: []Handler{
			{
				Handler: "error",
			},
		},
		Terminal: true,
	})

	return routes
}

// buildProxyRoute プロキシルートを構築
func (cc *CaddyClient) buildProxyRoute(host, path string, route models.Route) Route {
	match := Match{
		Host: []string{host},
	}
	
	if path != "" && path != "/" {
		match.Path = []string{path + "*"}
	}

	upstreams := []Upstream{}
	for _, port := range route.Port {
		upstreams = append(upstreams, Upstream{
			Dial: fmt.Sprintf("%s:%d", route.DeviceIP, port),
		})
	}

	// デフォルトポート80を追加
	if len(upstreams) == 0 {
		upstreams = append(upstreams, Upstream{
			Dial: fmt.Sprintf("%s:80", route.DeviceIP),
		})
	}

	return Route{
		Match: []Match{match},
		Handle: []Handler{
			{
				Handler:   "reverse_proxy",
				Upstreams: upstreams,
				Headers: &HeaderOperations{
					Request: &HeaderMods{
						Set: map[string][]string{
							"X-Real-IP":       {"{http.request.remote.host}"},
							"X-Forwarded-For": {"{http.request.remote.host}"},
						},
					},
				},
			},
		},
	}
}

// buildRejectRoute 拒否ルートを構築
func (cc *CaddyClient) buildRejectRoute(host, path string) Route {
	match := Match{
		Host: []string{host},
	}
	
	if path != "" {
		match.Path = []string{path + "*"}
	}

	return Route{
		Match: []Match{match},
		Handle: []Handler{
			{
				Handler: "error",
			},
		},
		Terminal: true,
	}
}

// applyConfig Caddyに設定を適用
func (cc *CaddyClient) applyConfig(config *CaddyConfig) error {
	// レート制限
	cc.rateLimiter <- struct{}{}
	defer func() { <-cc.rateLimiter }()
	
	// 接続プールから取得
	client := <-cc.connPool
	defer func() { cc.connPool <- client }()
	
	data, err := json.Marshal(config)
	if err != nil {
		return fmt.Errorf("JSON生成エラー: %w", err)
	}

	req, err := http.NewRequest("POST", cc.adminAPI+"/load", bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("リクエスト作成エラー: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("APIリクエストエラー: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("Caddy API エラー: %s - %s", resp.Status, body)
	}

	return nil
}

// GetCertificates 証明書情報を取得
func (cc *CaddyClient) GetCertificates() ([]models.Certificate, error) {
	resp, err := cc.client.Get(cc.adminAPI + "/pki/certificates")
	if err != nil {
		return nil, fmt.Errorf("証明書取得エラー: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Caddy API エラー: %s", resp.Status)
	}

	var certs []models.Certificate
	if err := json.NewDecoder(resp.Body).Decode(&certs); err != nil {
		return nil, fmt.Errorf("JSONデコードエラー: %w", err)
	}

	return certs, nil
}

// TestUpstream アップストリームの接続テスト
func (cc *CaddyClient) TestUpstream(address string) error {
	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	resp, err := client.Get("http://" + address)
	if err != nil {
		return fmt.Errorf("接続エラー: %w", err)
	}
	defer resp.Body.Close()

	cc.logger.Infof("アップストリームテスト成功: %s - %s", address, resp.Status)
	return nil
} 