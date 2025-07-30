// iptables_manager.go - Basic Security Rules Service
// Version: 2.0.0
// Description: LPG自体の基本的なセキュリティルール管理（VLANポリシーはOmada側で管理）

package services

import (
	"fmt"
	"os/exec"
	"sync"

	"github.com/sirupsen/logrus"
)

// IPTablesManager 基本的なセキュリティルール管理
type IPTablesManager struct {
	mu       sync.Mutex
	logger   *logrus.Logger
	dryRun   bool
}

// NewIPTablesManager セキュリティルール管理サービスを作成
func NewIPTablesManager(logger *logrus.Logger, dryRun bool) *IPTablesManager {
	return &IPTablesManager{
		logger: logger,
		dryRun: dryRun,
	}
}

// ApplyBasicSecurityRules LPG自体の基本的なセキュリティルールを適用
// 注: VLANポリシーはOmada ACLで管理するため、ここでは最小限のルールのみ
func (im *IPTablesManager) ApplyBasicSecurityRules() error {
	im.mu.Lock()
	defer im.mu.Unlock()

	im.logger.Info("基本的なセキュリティルールを適用しています")

	// ループバックの許可
	if err := im.executeCommand("iptables -A INPUT -i lo -j ACCEPT"); err != nil {
		im.logger.Warn("ループバックルールの適用に失敗（既に存在する可能性があります）")
	}

	// 確立済み接続の許可
	if err := im.executeCommand("iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT"); err != nil {
		im.logger.Warn("確立済み接続ルールの適用に失敗（既に存在する可能性があります）")
	}

	// 無効なパケットのドロップ
	if err := im.executeCommand("iptables -A INPUT -m state --state INVALID -j DROP"); err != nil {
		im.logger.Warn("無効パケットルールの適用に失敗（既に存在する可能性があります）")
	}

	// SYN flood対策
	if err := im.executeCommand("iptables -A INPUT -p tcp --syn -m limit --limit 25/sec --limit-burst 50 -j ACCEPT"); err != nil {
		im.logger.Warn("SYN flood対策ルールの適用に失敗（既に存在する可能性があります）")
	}

	im.logger.Info("基本的なセキュリティルールを適用しました")
	return nil
}

// executeCommand コマンドを実行
func (im *IPTablesManager) executeCommand(command string) error {
	if im.dryRun {
		im.logger.Debugf("[DRY-RUN] %s", command)
		return nil
	}

	im.logger.Debugf("実行: %s", command)
	
	cmd := exec.Command("sh", "-c", command)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("コマンド実行エラー: %s - %s", err, output)
	}

	return nil
} 