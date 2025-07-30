// SettingsPage.tsx - Settings Management Page
// Version: 1.0.0
// Description: 設定管理ページコンポーネント

import React, { useState, useEffect } from 'react'
import { Routes, Route, useNavigate, useLocation } from 'react-router-dom'
import {
  Box,
  Button,
  Card,
  FormControl,
  TextInput,
  Textarea,
  Select,
  Label,
  Heading,
  Text,
  Spinner,
  Octicon,
  TabNav,
  Dialog,
  Flash,
  IconButton,
} from '@primer/react'
import {
  GearIcon,
  PersonIcon,
  KeyIcon,
  DownloadIcon,
  UploadIcon,
  ShieldIcon,
  ServerIcon,
  FileIcon,
  CheckIcon,
  TrashIcon,
} from '@primer/octicons-react'
import { settingsAPI, authAPI } from '@services/api'
import { useAuth } from '@contexts/AuthContext'
import toast from 'react-hot-toast'
import styled from 'styled-components'
import { Editor } from '@monaco-editor/react'

const PageContainer = styled(Box)`
  padding: 24px;
  max-width: 1200px;
  margin: 0 auto;
`

const HeaderSection = styled(Box)`
  margin-bottom: 24px;
`

const TabContent = styled(Box)`
  margin-top: 24px;
`

const SettingCard = styled(Card)`
  padding: 24px;
  margin-bottom: 24px;
`

const SettingsPage: React.FC = () => {
  const navigate = useNavigate()
  const location = useLocation()
  const currentTab = location.pathname.split('/').pop() || 'general'

  return (
    <PageContainer>
      <HeaderSection>
        <Heading as="h1" sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
          <Octicon icon={GearIcon} size={24} />
          設定
        </Heading>
        
        <TabNav aria-label="設定タブ">
          <TabNav.Link
            href="/settings/general"
            selected={currentTab === 'general'}
            onClick={(e) => {
              e.preventDefault()
              navigate('/settings/general')
            }}
          >
            <Octicon icon={ServerIcon} /> 一般
          </TabNav.Link>
          <TabNav.Link
            href="/settings/users"
            selected={currentTab === 'users'}
            onClick={(e) => {
              e.preventDefault()
              navigate('/settings/users')
            }}
          >
            <Octicon icon={PersonIcon} /> ユーザー
          </TabNav.Link>
          <TabNav.Link
            href="/settings/backup"
            selected={currentTab === 'backup'}
            onClick={(e) => {
              e.preventDefault()
              navigate('/settings/backup')
            }}
          >
            <Octicon icon={FileIcon} /> バックアップ
          </TabNav.Link>
          <TabNav.Link
            href="/settings/advanced"
            selected={currentTab === 'advanced'}
            onClick={(e) => {
              e.preventDefault()
              navigate('/settings/advanced')
            }}
          >
            <Octicon icon={ShieldIcon} /> 詳細設定
          </TabNav.Link>
        </TabNav>
      </HeaderSection>

      <Routes>
        <Route path="general" element={<GeneralSettings />} />
        <Route path="users" element={<UserSettings />} />
        <Route path="backup" element={<BackupSettings />} />
        <Route path="advanced" element={<AdvancedSettings />} />
        <Route path="*" element={<GeneralSettings />} />
      </Routes>
    </PageContainer>
  )
}

// 一般設定タブ
const GeneralSettings: React.FC = () => {
  const [settings, setSettings] = useState({
    logserver: '',
    websocket_timeout: 600,
    log_retention_days: 30,
  })
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)

  useEffect(() => {
    fetchSettings()
  }, [])

  const fetchSettings = async () => {
    try {
      const response = await settingsAPI.getGeneral()
      setSettings(response.data)
    } catch (error) {
      toast.error('設定の取得に失敗しました')
    } finally {
      setIsLoading(false)
    }
  }

  const handleSave = async () => {
    setIsSaving(true)
    try {
      await settingsAPI.updateGeneral(settings)
      toast.success('設定を保存しました')
    } catch (error) {
      toast.error('設定の保存に失敗しました')
    } finally {
      setIsSaving(false)
    }
  }

  if (isLoading) {
    return <Spinner size="large" />
  }

  return (
    <TabContent>
      <SettingCard>
        <Heading as="h2" sx={{ mb: 3, fontSize: 3 }}>
          一般設定
        </Heading>
        
        <FormControl sx={{ mb: 3 }}>
          <FormControl.Label>ログサーバーURL</FormControl.Label>
          <TextInput
            value={settings.logserver}
            onChange={(e) => setSettings({ ...settings, logserver: e.target.value })}
            placeholder="https://example.com/logs"
            block
          />
          <FormControl.Caption>
            ログをバッチ送信する外部サーバーのURL
          </FormControl.Caption>
        </FormControl>

        <FormControl sx={{ mb: 3 }}>
          <FormControl.Label>WebSocketタイムアウト（秒）</FormControl.Label>
          <TextInput
            type="number"
            value={settings.websocket_timeout}
            onChange={(e) => setSettings({ ...settings, websocket_timeout: parseInt(e.target.value) })}
            block
          />
        </FormControl>

        <FormControl sx={{ mb: 3 }}>
          <FormControl.Label>ログ保持期間（日）</FormControl.Label>
          <TextInput
            type="number"
            value={settings.log_retention_days}
            onChange={(e) => setSettings({ ...settings, log_retention_days: parseInt(e.target.value) })}
            block
          />
        </FormControl>

        <Button
          variant="primary"
          onClick={handleSave}
          disabled={isSaving}
        >
          {isSaving ? '保存中...' : '設定を保存'}
        </Button>
      </SettingCard>
    </TabContent>
  )
}

// ユーザー設定タブ
const UserSettings: React.FC = () => {
  const { user, changePassword } = useAuth()
  const [showPasswordDialog, setShowPasswordDialog] = useState(false)
  const [passwords, setPasswords] = useState({
    current: '',
    new: '',
    confirm: '',
  })
  const [isChanging, setIsChanging] = useState(false)

  const handlePasswordChange = async () => {
    if (passwords.new !== passwords.confirm) {
      toast.error('新しいパスワードが一致しません')
      return
    }

    if (passwords.new.length < 8) {
      toast.error('パスワードは8文字以上で設定してください')
      return
    }

    setIsChanging(true)
    try {
      await changePassword(passwords.current, passwords.new)
      toast.success('パスワードを変更しました')
      setShowPasswordDialog(false)
      setPasswords({ current: '', new: '', confirm: '' })
    } catch (error) {
      toast.error('パスワードの変更に失敗しました')
    } finally {
      setIsChanging(false)
    }
  }

  return (
    <TabContent>
      <SettingCard>
        <Heading as="h2" sx={{ mb: 3, fontSize: 3 }}>
          ユーザー管理
        </Heading>

        <Box mb={3}>
          <Text fontSize={1} color="fg.muted">現在のユーザー</Text>
          <Text fontWeight="semibold" fontSize={2}>{user?.username}</Text>
        </Box>

        <Button
          leadingIcon={KeyIcon}
          onClick={() => setShowPasswordDialog(true)}
        >
          パスワードを変更
        </Button>
      </SettingCard>

      <Dialog
        isOpen={showPasswordDialog}
        onDismiss={() => setShowPasswordDialog(false)}
        aria-labelledby="password-dialog"
      >
        <Dialog.Header id="password-dialog">パスワードの変更</Dialog.Header>
        <Box p={3}>
          <FormControl required sx={{ mb: 3 }}>
            <FormControl.Label>現在のパスワード</FormControl.Label>
            <TextInput
              type="password"
              value={passwords.current}
              onChange={(e) => setPasswords({ ...passwords, current: e.target.value })}
              block
            />
          </FormControl>

          <FormControl required sx={{ mb: 3 }}>
            <FormControl.Label>新しいパスワード</FormControl.Label>
            <TextInput
              type="password"
              value={passwords.new}
              onChange={(e) => setPasswords({ ...passwords, new: e.target.value })}
              placeholder="8文字以上"
              block
            />
          </FormControl>

          <FormControl required>
            <FormControl.Label>新しいパスワード（確認）</FormControl.Label>
            <TextInput
              type="password"
              value={passwords.confirm}
              onChange={(e) => setPasswords({ ...passwords, confirm: e.target.value })}
              block
            />
          </FormControl>
        </Box>
        <Dialog.Footer>
          <Dialog.Buttons>
            <Button onClick={() => setShowPasswordDialog(false)}>
              キャンセル
            </Button>
            <Button
              variant="primary"
              onClick={handlePasswordChange}
              disabled={isChanging}
            >
              {isChanging ? '変更中...' : '変更'}
            </Button>
          </Dialog.Buttons>
        </Dialog.Footer>
      </Dialog>
    </TabContent>
  )
}

// バックアップ設定タブ
const BackupSettings: React.FC = () => {
  const [backups, setBackups] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    fetchBackups()
  }, [])

  const fetchBackups = async () => {
    try {
      const response = await settingsAPI.getBackups()
      setBackups(response.data.backups || [])
    } catch (error) {
      toast.error('バックアップ一覧の取得に失敗しました')
    } finally {
      setIsLoading(false)
    }
  }

  const handleBackup = async () => {
    try {
      await settingsAPI.createBackup()
      toast.success('バックアップを作成しました')
      fetchBackups()
    } catch (error) {
      toast.error('バックアップの作成に失敗しました')
    }
  }

  const handleRestore = async (filename: string) => {
    if (!window.confirm(`本当に "${filename}" から復元しますか？`)) {
      return
    }

    try {
      await settingsAPI.restoreBackup(filename)
      toast.success('設定を復元しました')
    } catch (error) {
      toast.error('復元に失敗しました')
    }
  }

  const handleExport = async () => {
    try {
      const response = await settingsAPI.exportConfig()
      const blob = new Blob([JSON.stringify(response.data, null, 2)], { type: 'application/json' })
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `lpg-config-${new Date().toISOString()}.json`
      a.click()
      window.URL.revokeObjectURL(url)
    } catch (error) {
      toast.error('エクスポートに失敗しました')
    }
  }

  if (isLoading) {
    return <Spinner size="large" />
  }

  return (
    <TabContent>
      <SettingCard>
        <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
          <Heading as="h2" sx={{ fontSize: 3 }}>
            バックアップ管理
          </Heading>
          <Box display="flex" gap={2}>
            <Button leadingIcon={DownloadIcon} onClick={handleExport}>
              エクスポート
            </Button>
            <Button variant="primary" leadingIcon={UploadIcon} onClick={handleBackup}>
              バックアップ作成
            </Button>
          </Box>
        </Box>

        <Text as="p" color="fg.muted" mb={3}>
          設定ファイルの世代管理（最新5世代を保持）
        </Text>

        {backups.length === 0 ? (
          <Flash>バックアップがありません</Flash>
        ) : (
          <Box>
            {backups.map((backup) => (
              <Card key={backup} sx={{ p: 3, mb: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                  <Text fontWeight="semibold">{backup}</Text>
                  <Text fontSize={0} color="fg.muted">
                    {new Date(backup.split('-')[1]).toLocaleString('ja-JP')}
                  </Text>
                </Box>
                <Button size="small" onClick={() => handleRestore(backup)}>
                  復元
                </Button>
              </Card>
            ))}
          </Box>
        )}
      </SettingCard>
    </TabContent>
  )
}

// 詳細設定タブ
const AdvancedSettings: React.FC = () => {
  const [config, setConfig] = useState('')
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)

  useEffect(() => {
    fetchConfig()
  }, [])

  const fetchConfig = async () => {
    try {
      const response = await settingsAPI.getConfigRaw()
      setConfig(JSON.stringify(response.data, null, 2))
    } catch (error) {
      toast.error('設定の取得に失敗しました')
    } finally {
      setIsLoading(false)
    }
  }

  const handleSave = async () => {
    try {
      const parsed = JSON.parse(config)
      setIsSaving(true)
      await settingsAPI.updateConfigRaw(parsed)
      toast.success('設定を保存しました')
    } catch (error) {
      if (error instanceof SyntaxError) {
        toast.error('JSONの形式が正しくありません')
      } else {
        toast.error('設定の保存に失敗しました')
      }
    } finally {
      setIsSaving(false)
    }
  }

  if (isLoading) {
    return <Spinner size="large" />
  }

  return (
    <TabContent>
      <SettingCard>
        <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
          <Heading as="h2" sx={{ fontSize: 3 }}>
            詳細設定（config.json）
          </Heading>
          <Button
            variant="primary"
            onClick={handleSave}
            disabled={isSaving}
          >
            {isSaving ? '保存中...' : '保存'}
          </Button>
        </Box>

        <Flash variant="warning" sx={{ mb: 3 }}>
          <Octicon icon={ShieldIcon} />
          この設定を変更すると、システムが正常に動作しなくなる可能性があります。
          変更前に必ずバックアップを作成してください。
        </Flash>

        <Box height={500} border="1px solid" borderColor="border.default" borderRadius={2}>
          <Editor
            height="100%"
            language="json"
            theme="vs-dark"
            value={config}
            onChange={(value) => setConfig(value || '')}
            options={{
              minimap: { enabled: false },
              fontSize: 14,
              wordWrap: 'on',
              automaticLayout: true,
            }}
          />
        </Box>
      </SettingCard>
    </TabContent>
  )
}

export default SettingsPage 