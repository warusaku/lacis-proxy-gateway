# Makefile - LacisProxyGateway Development Commands
# Version: 1.0.0

.PHONY: help
help: ## ヘルプを表示
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# 開発環境コマンド
.PHONY: dev
dev: ## 開発環境を起動
	docker-compose up -d

.PHONY: dev-logs
dev-logs: ## 開発環境のログを表示
	docker-compose logs -f

.PHONY: dev-stop
dev-stop: ## 開発環境を停止
	docker-compose stop

.PHONY: dev-down
dev-down: ## 開発環境を削除
	docker-compose down

.PHONY: dev-restart
dev-restart: ## 開発環境を再起動
	docker-compose restart

# ビルドコマンド
.PHONY: build
build: ## 本番用ビルドを実行
	docker build -t lpg:latest .

.PHONY: build-api
build-api: ## APIサーバーをビルド
	cd src/api && go build -o ../../bin/lpg-api .

.PHONY: build-web
build-web: ## Webフロントエンドをビルド
	cd src/web && npm run build

# セットアップコマンド
.PHONY: setup
setup: setup-certs setup-config ## 開発環境をセットアップ
	@echo "セットアップが完了しました。"

.PHONY: setup-certs
setup-certs: ## 開発用証明書を生成
	chmod +x scripts/generate-certs.sh
	./scripts/generate-certs.sh

.PHONY: setup-config
setup-config: ## 初期設定ファイルを作成
	@if [ ! -f config/config.json ]; then \
		cp config/config.example.json config/config.json; \
		echo "config/config.json を作成しました"; \
	else \
		echo "config/config.json は既に存在します"; \
	fi

# テストコマンド
.PHONY: test
test: test-api test-web ## すべてのテストを実行

.PHONY: test-api
test-api: ## APIテストを実行
	cd src/api && go test -v ./...

.PHONY: test-web
test-web: ## Webテストを実行
	cd src/web && npm test

.PHONY: test-e2e
test-e2e: ## E2Eテストを実行
	cd tests && npm run test:e2e

# 開発ツール
.PHONY: api-shell
api-shell: ## APIコンテナに接続
	docker-compose exec api sh

.PHONY: caddy-reload
caddy-reload: ## Caddy設定をリロード
	docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile

.PHONY: db-shell
db-shell: ## データベースに接続（full profileの場合）
	docker-compose --profile full exec postgres psql -U lpg

# クリーンアップ
.PHONY: clean
clean: ## ビルド成果物をクリーンアップ
	rm -rf bin/ dist/ node_modules/ src/api/tmp/
	docker-compose down -v

.PHONY: clean-logs
clean-logs: ## ログファイルをクリーンアップ
	rm -rf logs/*.log
	docker-compose exec api rm -rf /var/log/lpg/*

# ドキュメント生成
.PHONY: docs
docs: ## APIドキュメントを生成
	cd src/api && swag init

# リンター
.PHONY: lint
lint: lint-api lint-web ## すべてのリンターを実行

.PHONY: lint-api
lint-api: ## Go linterを実行
	cd src/api && golangci-lint run

.PHONY: lint-web
lint-web: ## ESLintを実行
	cd src/web && npm run lint

# フォーマット
.PHONY: fmt
fmt: fmt-api fmt-web ## コードをフォーマット

.PHONY: fmt-api
fmt-api: ## Goコードをフォーマット
	cd src/api && go fmt ./...

.PHONY: fmt-web
fmt-web: ## JavaScriptコードをフォーマット
	cd src/web && npm run format

# 依存関係
.PHONY: deps
deps: deps-api deps-web ## 依存関係を更新

.PHONY: deps-api
deps-api: ## Go依存関係を更新
	cd src/api && go mod tidy && go mod vendor

.PHONY: deps-web
deps-web: ## npm依存関係を更新
	cd src/web && npm install

# FTPサーバー関連
.PHONY: ftp-setup
ftp-setup: ## FTPサーバーの初期設定
	@echo "=== FTPサーバーをセットアップしています ==="
	@docker exec -it lpg-api /usr/local/bin/setup-ftp.sh

.PHONY: ftp-status
ftp-status: ## FTPサーバーの状態確認
	@echo "=== FTPサーバーの状態 ==="
	@docker exec -it lpg-api sh -c "ps aux | grep vsftpd | grep -v grep || echo 'vsftpdは起動していません'"
	@echo ""
	@echo "=== FTPデプロイ監視の状態 ==="
	@docker exec -it lpg-api sh -c "ps aux | grep ftp-deploy-watcher | grep -v grep || echo 'デプロイ監視は起動していません'"

.PHONY: ftp-logs
ftp-logs: ## FTPログの表示
	@echo "=== FTPアクセスログ ==="
	@docker exec -it lpg-api tail -n 20 /var/log/lpg/vsftpd.log 2>/dev/null || echo "ログファイルがありません"
	@echo ""
	@echo "=== デプロイメントログ ==="
	@docker exec -it lpg-api tail -n 20 /var/log/lpg/ftp-deploy.log 2>/dev/null || echo "ログファイルがありません"

# 運用管理コマンド
.PHONY: monitor
monitor: ## 監視状態の確認
	@echo "=== システム監視状態 ==="
	@echo ""
	@echo "Telegrafの状態:"
	@docker exec -it lpg-api sh -c 'ps aux | grep telegraf | grep -v grep || echo "Telegraf is not running"'
	@echo ""
	@echo "最新のヘルスチェック結果:"
	@docker exec -it lpg-api cat /var/log/lpg/health-check.json 2>/dev/null | jq '.' || echo "ヘルスチェック結果がありません"
	@echo ""
	@echo "メトリクス収集状態:"
	@docker exec -it lpg-api tail -n 10 /var/log/lpg/telegraf.log 2>/dev/null || echo "Telegrafログがありません"

.PHONY: backup
backup: ## 手動バックアップの実行
	@echo "=== 手動バックアップを実行しています ==="
	@docker exec -it lpg-api /usr/local/bin/backup-lpg.sh
	@echo ""
	@echo "バックアップ一覧:"
	@docker exec -it lpg-api ls -lh /var/backups/lpg/

.PHONY: backup-list
backup-list: ## バックアップ一覧の表示
	@echo "=== 利用可能なバックアップ ==="
	@docker exec -it lpg-api ls -lh /var/backups/lpg/ | grep -E "lpg-backup-.*\.tar\.gz"

.PHONY: backup-restore
backup-restore: ## バックアップからの復元（対話式）
	@echo "=== バックアップからの復元 ==="
	@echo "利用可能なバックアップ:"
	@docker exec -it lpg-api ls -1 /var/backups/lpg/ | grep -E "lpg-backup-.*\.tar\.gz"
	@echo ""
	@echo "復元するバックアップファイル名を入力してください:"
	@read BACKUP_FILE; \
	docker exec -it lpg-api sh -c "cd /var/backups/lpg && tar -xzf $$BACKUP_FILE && echo 'バックアップを展開しました: $$BACKUP_FILE'"

.PHONY: security
security: ## セキュリティ設定の適用
	@echo "=== セキュリティ設定を適用しています ==="
	@echo "注: 一部のセキュリティ設定はDockerコンテナ内では適用できません"
	@docker exec -it lpg-api /usr/local/bin/security-hardening.sh || true
	@echo ""
	@echo "セキュリティレポート:"
	@docker exec -it lpg-api cat /etc/lpg/security-report.txt 2>/dev/null || echo "セキュリティレポートがありません"

.PHONY: health-check
health-check: ## ヘルスチェックの実行
	@echo "=== ヘルスチェックを実行しています ==="
	@docker exec -it lpg-api /usr/local/bin/lpg-health-check.sh | jq '.' || docker exec -it lpg-api /usr/local/bin/lpg-health-check.sh

.PHONY: cron-setup
cron-setup: ## 定期タスクの設定
	@echo "=== 定期タスクを設定しています ==="
	@docker exec -it lpg-api /usr/local/bin/lpg-cron-setup.sh

.PHONY: logs-all
logs-all: ## すべてのログを表示
	@echo "=== LPGシステムログ ==="
	@echo ""
	@echo "--- APIログ ---"
	@docker exec -it lpg-api tail -n 20 /var/log/lpg/api.log 2>/dev/null || echo "APIログがありません"
	@echo ""
	@echo "--- Caddyログ ---"
	@docker exec -it lpg-api tail -n 20 /var/log/lpg/caddy.log 2>/dev/null || echo "Caddyログがありません"
	@echo ""
	@echo "--- アクセスログ ---"
	@docker exec -it lpg-api tail -n 20 /var/log/lpg/access.log 2>/dev/null || echo "アクセスログがありません"
	@echo ""
	@echo "--- バックアップログ ---"
	@docker exec -it lpg-api tail -n 20 /var/log/lpg/backup.log 2>/dev/null || echo "バックアップログがありません"

.PHONY: system-info
system-info: ## システム情報の表示
	@echo "=== システム情報 ==="
	@docker exec -it lpg-api sh -c "echo 'ホスト名:' && hostname"
	@docker exec -it lpg-api sh -c "echo '' && echo 'ディスク使用状況:' && df -h | grep -E '(Filesystem|/$$)'"
	@docker exec -it lpg-api sh -c "echo '' && echo 'メモリ使用状況:' && free -h"
	@docker exec -it lpg-api sh -c "echo '' && echo '実行中のサービス:' && ps aux | grep -E '(caddy|lpg-api|vsftpd|telegraf)' | grep -v grep"

# バージョン表示
.PHONY: version
version: ## バージョン情報を表示
	@echo "LacisProxyGateway Development Environment"
	@echo "API Version: 1.0.0"
	@echo "Web Version: 1.0.0"
	@docker --version
	@docker-compose --version 