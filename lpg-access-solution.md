# LPG (192.168.234.2) アクセス問題の解決策

## 現在の状況
- IPアドレス 192.168.234.2 は応答している
- SSHポート(22)は開いている
- 全てのログイン試行が失敗している

## 原因の可能性
1. **設定ログの情報が正確でない** - 実際のパスワードが記録と異なる
2. **別のデバイスの可能性** - 192.168.234.2が想定と異なるデバイス
3. **セキュリティ設定** - SSHがキー認証のみに制限されている

## 推奨される解決方法

### 方法1: 物理アクセスによる確認（推奨）
1. Orange Pi Zero 3にモニターとキーボードを接続
2. 直接ログインして現在の設定を確認
3. 必要に応じてパスワードをリセット

### 方法2: SDカードの再準備
1. 新しいSDカードを用意
2. 最新のArmbian/Ubuntu Server イメージをダウンロード
3. イメージを書き込んで最初からセットアップ

手順：
```bash
# イメージのダウンロード（例）
wget https://dl.armbian.com/orangepizero3/Armbian_24.5.0_Orangepizero3_jammy_current_6.6.31.img.xz

# 解凍
xz -d Armbian_24.5.0_Orangepizero3_jammy_current_6.6.31.img.xz

# SDカードへの書き込み（macOS）
sudo dd if=Armbian_24.5.0_Orangepizero3_jammy_current_6.6.31.img of=/dev/rdisk4 bs=4m

# 初回ログイン
ssh root@192.168.234.2
# パスワード: 1234
```

### 方法3: Omadaでの確認
1. Omada Cloud Controllerにログイン
2. Clients → VLAN555 のデバイスを確認
3. MACアドレスが想定通りか確認
4. 必要に応じてDHCP予約を再設定

## セットアップ後の手順

正常にアクセスできるようになったら：

1. **ユーザー作成**
```bash
# rootでログイン後
useradd -m -s /bin/bash lacissystem
echo "lacissystem:lacis12345@" | chpasswd
usermod -aG sudo lacissystem
```

2. **LPGセットアップ**
```bash
# ファイル転送
scp lpg-deploy-v2.tar.gz lacissystem@192.168.234.2:/home/lacissystem/

# セットアップ実行
ssh lacissystem@192.168.234.2
tar -xzf lpg-deploy-v2.tar.gz
sudo ./scripts/setup-lpg.sh
```

## 当面のテスト方法

LPGへのアクセスが難しい場合でも、Orange Pi 5 Plus (192.168.234.10) でテストサーバーを構築して、基本的な動作確認は可能です。

```bash
# Orange Pi 5 Plusでの簡易プロキシテスト
ssh root@192.168.234.10
# 初期設定を完了後、nginxなどでリバースプロキシを一時的に構築
```

## 注意事項
- パスワードは定期的に変更し、安全な場所に記録する
- SSH鍵認証の設定を検討する
- 物理的なアクセス方法を確保しておく