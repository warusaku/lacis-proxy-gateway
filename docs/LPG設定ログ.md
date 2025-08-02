---
title: LPG設定ログ
projects:
  - Lacis Proxy Gateway
tags:
  - '#proj-lpg'
  - '#setup'
  - '#network-configuration'
  - '#orangepi'
created: '2025-01-18'
updated: '2025-07-31'
author: Claude
status: active
---

# LPG設定ログ

このドキュメントは、Lacis Proxy Gateway (LPG) の初期設定作業の記録です。

## 関連ドキュメント
- [[基本仕様書|LPG基本仕様書]]
- [[セットアップ手順書|LPGセットアップ手順書]]
- [[クイックガイド|LPGクイックガイド]]
- [[開発タスク|LPG開発タスク]]

## 設定記録

### Orange Pi Zero3設定

#### 1. 初期OSインストール
- Armbianは公式イメージの入手が困難なため `Orangepizero3_1.0.2_ubuntu_jammy_server_linux6.1.31.img`を導入
- 設定インターフェース的にモニター接続は困難なためSSHでの接続に方針変更
- 今回は設定上1台のみ

#### 2. 接続直後の状態
| 項目 | 値 |
|------|-----|
| ホスト名 | orangepizero3 |
| IPアドレス | 192.168.3.109 (DHCP) |
| MACアドレス | 02-00-D8-46-8A-4A |
| VLAN | VLAN1 |

#### 3. SSH接続テスト（初回）
一旦この状態で接続を試行：

```bash
ED25519 key fingerprint is SHA256:/qsp9lmN65AGR0eZF1JbyDncP84CyCHimvtCR8Pgiig.

This key is not known by any other names.

Are you sure you want to continue connecting (yes/no/[fingerprint])? yes

Warning: Permanently added '192.168.3.109' (ED25519) to the list of known hosts.

root@192.168.3.109's password: 

Permission denied, please try again.

root@192.168.3.109's password: 

Permission denied, please try again.

root@192.168.3.109's password: 

root@192.168.3.109: Permission denied (publickey,password).
```

- SSH接続確認済み
- PASSを"1234"で試行、通らず
- 接続可能な状態であることまでは確認できたので、Omada側のVLAN設定、アクセス制御の設定後にLPGの設定を行うものとする

### Omada Cloud側設定

#### 1. ネットワーク構成
- **管理ネットワーク（VLAN1）**: 192.168.3.1/24
- **lacis_proxy_gatewayネットワーク**: 192.168.234.1
  - DHCP範囲: 192.168.234.100〜200設定済み
  - ER-605ルーター側4番をインターフェースに設定済み

#### 2. アクセス制御設定
- VLAN555→VLAN1へのアクセスを禁止
- VLAN1→VLAN555へのアクセスは可能
- DHCP予約: 02-00-D8-46-8A-4Aを192.168.234.2

#### 3. 実運用での注意点

##### NATループバックの挙動
- 管理PCがDDNSホスト名（グローバルIP）でアクセスする場合、ルーター内部で"一度WANへ出て戻る"Hair-Pin NATが必要
- ER605/7206は標準で有効なので通常は通る
- 別機種を使う場合はNAT → NAT Loopback設定を確認すること

##### 証明書名一致
- DDNSドメインを使うときはHostヘッダが外向けFQDNになるため、Caddy側サイト定義（hostdomains）にそのFQDNが登録済か要確認
- 管理PCからローカルIP直打ち（https://192.168.234.2）でアクセスする場合、証明書CNが一致せずブラウザ警告が出る
  - 対策: 自己署名 or SubjectAltNameに内部IPを入れる方法も検討

#### 4. MACアドレスバインド問題
- 02-00-D8-46-8A-4Aを192.168.234.2にバインドしたが192.168.3.109のIPから外れず
- 原因推測: PVIDの設定でポートが選択されていたため？

#### 5. SSH接続テスト（VLAN555）
```bash
(base) Mac-Studio-2:~ hideaikurata$ ssh root@192.168.234.2
The authenticity of host '192.168.234.2 (192.168.234.2)' can't be established.
ED25519 key fingerprint is SHA256:/qsp9lmN65AGR0eZF1JbyDncP84CyCHimvtCR8Pgiig.
This host key is known by the following other names/addresses:
    ~/.ssh/known_hosts:13: 192.168.3.109
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.234.2' (ED25519) to the list of known hosts.
root@192.168.234.2's password: 
```

SSHでVLAN555に配置されたOrange Pi Zeroへの接続が完了しました。

### Orange Pi Zeroのセットアップ

#### 管理者アカウント設定
管理パスワードの変更を実施し、以下に設定：

| 項目             | 値           |
| -------------- | ----------- |
| 管理者ID          | lacissystem |
| 管理者パスワード（sudo） | lacis12345@ |

## 次のステップ
- [[セットアップ手順書#基本設定|基本設定の継続]]
- [[セットアップ手順書#Caddy設定|Caddyのインストールと設定]]
- [[セットアップ手順書#セキュリティ設定|セキュリティ強化設定]]

## 2025年7月31日追記 - 仕様変更

### DDNS設定の変更
- **変更前**: 新規DDNS `lacisstack.ath.cx` を使用予定
- **変更後**: 既存DDNS `akb001yebraxfqsm9y.dyndns-web.com` を使用
- **理由**: Omadaの仕様により1つのWANポートに1つのDDNSしか設定できないため

### ルーティング方式の変更
- **変更前**: サブドメインベース（例: boards.lacisstack.ath.cx）
- **変更後**: パスベースルーティング（例: akb001yebraxfqsm9y.dyndns-web.com/lacisstack/boards）

### 実装状況
- Python3 HTTPServerによる簡易プロキシサーバーを実装し、ポート80で稼働中
- ルーティング設定: `/lacisstack/boards/*` → `192.168.234.10:8080/*`
- ヘルスチェックエンドポイント: `/health`

詳細は [[LPGセットアップログ_20250731]] を参照。

## 関連情報
- [[webUI仕様|Web UI仕様書]] - 管理画面の仕様
- [[API仕様書|LPG API仕様書]] - API設計の詳細
- [[データ管理仕様|データ管理仕様書]] - データ構造とストレージ設計
- [[FTPデプロイ手順書|FTPデプロイ手順]] - デプロイメント手順
