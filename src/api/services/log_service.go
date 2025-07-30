// log_service.go - Log Collection and Forwarding Service
// Version: 1.0.0
// Description: ログ収集・転送サービス

package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/sirupsen/logrus"
)

// LogService ログサービス
type LogService struct {
	endpoint     string
	logDir       string
	logFile      *os.File
	mu           sync.Mutex
	buffer       []LogEntry
	bufferSize   int
	flushInterval time.Duration
	maxFileSize  int64
	logger       *logrus.Logger
	stopChan     chan struct{}
	wg           sync.WaitGroup
}

// LogEntry ログエントリ
type LogEntry struct {
	Timestamp   time.Time `json:"ts"`
	Host        string    `json:"host"`
	Path        string    `json:"path"`
	ClientIP    string    `json:"ip"`
	Method      string    `json:"method"`
	Status      int       `json:"status"`
	BytesSent   int64     `json:"bytes"`
	SiteName    string    `json:"sitename"`
	UserAgent   string    `json:"user_agent,omitempty"`
	Referer     string    `json:"referer,omitempty"`
	Duration    float64   `json:"duration_ms"`
}

// NewLogService ログサービスを作成
func NewLogService(endpoint string, logger *logrus.Logger) *LogService {
	ls := &LogService{
		endpoint:      endpoint,
		logDir:        "/var/log/lpg",
		bufferSize:    1000,
		flushInterval: 15 * time.Minute,
		maxFileSize:   300 * 1024, // 300KB
		logger:        logger,
		stopChan:      make(chan struct{}),
		buffer:        make([]LogEntry, 0, 1000),
	}

	// ログディレクトリ作成
	if err := os.MkdirAll(ls.logDir, 0755); err != nil {
		logger.Errorf("ログディレクトリ作成エラー: %v", err)
	}

	// ログファイルを開く
	if err := ls.openLogFile(); err != nil {
		logger.Errorf("ログファイルオープンエラー: %v", err)
	}

	// バックグラウンドワーカーを開始
	ls.wg.Add(1)
	go ls.worker()

	return ls
}

// LogAccess アクセスログを記録
func (ls *LogService) LogAccess(entry LogEntry) {
	// タイムスタンプをJSTに設定
	entry.Timestamp = time.Now().In(time.FixedZone("JST", 9*60*60))

	ls.mu.Lock()
	defer ls.mu.Unlock()

	// バッファに追加
	ls.buffer = append(ls.buffer, entry)

	// ファイルに書き込み
	if ls.logFile != nil {
		data, _ := json.Marshal(entry)
		fmt.Fprintf(ls.logFile, "%s\n", data)
		
		// ファイルサイズチェック
		if info, err := ls.logFile.Stat(); err == nil && info.Size() > ls.maxFileSize {
			ls.rotateLogFile()
		}
	}

	// バッファがいっぱいになったら送信
	if len(ls.buffer) >= ls.bufferSize {
		ls.flushBuffer()
	}
}

// worker バックグラウンドワーカー
func (ls *LogService) worker() {
	defer ls.wg.Done()
	
	ticker := time.NewTicker(ls.flushInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			ls.mu.Lock()
			ls.flushBuffer()
			ls.mu.Unlock()
		case <-ls.stopChan:
			ls.mu.Lock()
			ls.flushBuffer()
			ls.mu.Unlock()
			return
		}
	}
}

// flushBuffer バッファを送信（mutexは呼び出し側で取得済み）
func (ls *LogService) flushBuffer() {
	if len(ls.buffer) == 0 {
		return
	}

	// バッファをコピー
	logs := make([]LogEntry, len(ls.buffer))
	copy(logs, ls.buffer)
	ls.buffer = ls.buffer[:0]

	// 非同期で送信
	go ls.sendLogs(logs)
}

// sendLogs ログを外部エンドポイントに送信
func (ls *LogService) sendLogs(logs []LogEntry) {
	if ls.endpoint == "" {
		return
	}

	data, err := json.Marshal(map[string]interface{}{
		"logs": logs,
		"host": getHostname(),
		"timestamp": time.Now().In(time.FixedZone("JST", 9*60*60)).Format("2006-01-02 15:04:05"),
	})
	if err != nil {
		ls.logger.Errorf("ログJSON生成エラー: %v", err)
		return
	}

	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	req, err := http.NewRequest("POST", ls.endpoint, bytes.NewReader(data))
	if err != nil {
		ls.logger.Errorf("ログ送信リクエスト作成エラー: %v", err)
		return
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		ls.logger.Errorf("ログ送信エラー: %v", err)
		// 送信失敗時はローカルバックアップに保存
		ls.saveFailedLogs(logs)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		ls.logger.Errorf("ログ送信エラー: %s - %s", resp.Status, body)
		ls.saveFailedLogs(logs)
	} else {
		ls.logger.Infof("ログを正常に送信しました: %d件", len(logs))
	}
}

// saveFailedLogs 送信失敗したログを保存
func (ls *LogService) saveFailedLogs(logs []LogEntry) {
	backupFile := filepath.Join(ls.logDir, fmt.Sprintf("failed_%d.json", time.Now().Unix()))
	
	data, err := json.MarshalIndent(logs, "", "  ")
	if err != nil {
		ls.logger.Errorf("失敗ログJSON生成エラー: %v", err)
		return
	}

	if err := os.WriteFile(backupFile, data, 0600); err != nil {
		ls.logger.Errorf("失敗ログ保存エラー: %v", err)
		return
	}

	// 100MBを超えたら古いファイルを削除
	ls.cleanupFailedLogs()
}

// openLogFile ログファイルを開く
func (ls *LogService) openLogFile() error {
	logPath := filepath.Join(ls.logDir, "access.log")
	
	file, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return fmt.Errorf("ログファイルオープンエラー: %w", err)
	}

	ls.logFile = file
	return nil
}

// rotateLogFile ログファイルをローテーション
func (ls *LogService) rotateLogFile() {
	if ls.logFile == nil {
		return
	}

	// 現在のファイルを閉じる
	ls.logFile.Close()

	// ファイルサイズを取得
	logPath := filepath.Join(ls.logDir, "access.log")
	info, err := os.Stat(logPath)
	if err != nil {
		ls.logger.Errorf("ログファイル情報取得エラー: %v", err)
		ls.openLogFile()
		return
	}

	// 新しいログファイルの最初の20%を保持
	keepSize := int64(float64(ls.maxFileSize) * 0.2)
	if err := ls.truncateLogFile(logPath, info.Size()-keepSize); err != nil {
		ls.logger.Errorf("ログファイル切り詰めエラー: %v", err)
	}

	// ファイルを再度開く
	ls.openLogFile()
}

// truncateLogFile ログファイルの先頭部分を削除
func (ls *LogService) truncateLogFile(path string, skipBytes int64) error {
	// ファイルを読み込み
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	// スキップ位置にシーク
	if _, err := file.Seek(skipBytes, 0); err != nil {
		return err
	}

	// 残りの内容を読み込み
	remaining, err := io.ReadAll(file)
	if err != nil {
		return err
	}

	// ファイルを上書き
	return os.WriteFile(path, remaining, 0644)
}

// cleanupFailedLogs 失敗ログのクリーンアップ
func (ls *LogService) cleanupFailedLogs() {
	files, err := os.ReadDir(ls.logDir)
	if err != nil {
		return
	}

	var totalSize int64
	var fileInfos []os.DirEntry

	// failed_で始まるファイルを収集
	for _, file := range files {
		if !file.IsDir() && len(file.Name()) > 7 && file.Name()[:7] == "failed_" {
			fileInfos = append(fileInfos, file)
			if info, err := file.Info(); err == nil {
				totalSize += info.Size()
			}
		}
	}

	// 100MBを超えている場合、古いファイルから削除
	if totalSize > 100*1024*1024 {
		for _, file := range fileInfos {
			os.Remove(filepath.Join(ls.logDir, file.Name()))
			if info, err := file.Info(); err == nil {
				totalSize -= info.Size()
				if totalSize <= 100*1024*1024 {
					break
				}
			}
		}
	}
}

// Close ログサービスを終了
func (ls *LogService) Close() {
	close(ls.stopChan)
	ls.wg.Wait()

	ls.mu.Lock()
	defer ls.mu.Unlock()

	if ls.logFile != nil {
		ls.logFile.Close()
	}
}

// getHostname ホスト名を取得
func getHostname() string {
	hostname, err := os.Hostname()
	if err != nil {
		return "unknown"
	}
	return hostname
} 