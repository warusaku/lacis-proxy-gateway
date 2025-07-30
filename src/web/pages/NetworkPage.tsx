// NetworkPage.tsx - Network Status Page
// Version: 1.0.0
// Description: ネットワーク状態表示ページコンポーネント

import React, { useState, useEffect } from 'react'
import {
  Box,
  Button,
  Card,
  FormControl,
  TextInput,
  Label,
  Heading,
  Text,
  Spinner,
  Octicon,
  ProgressBar,
  Timeline,
  Alert,
} from '@primer/react'
import {
  GraphIcon,
  ServerIcon,
  ClockIcon,
  CpuIcon,
  DatabaseIcon,
  LinkIcon,
  CheckIcon,
  XIcon,
  SyncIcon,
} from '@primer/octicons-react'
import { systemAPI } from '@services/api'
import toast from 'react-hot-toast'
import styled from 'styled-components'

interface SystemInfo {
  hostname: string
  uptime: number
  load_average: number[]
  cpu_count: number
  memory: {
    total: number
    used: number
    free: number
    percent: number
  }
  disk: {
    total: number
    used: number
    free: number
    percent: number
  }
}

interface NetworkInterface {
  name: string
  ip_address: string
  mac_address: string
  status: string
  rx_bytes: number
  tx_bytes: number
}

interface ServiceStatus {
  name: string
  status: 'running' | 'stopped' | 'error'
  uptime?: number
  message?: string
}

const PageContainer = styled(Box)`
  padding: 24px;
  max-width: 1200px;
  margin: 0 auto;
`

const HeaderSection = styled(Box)`
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24px;
`

const MetricsGrid = styled(Box)`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 24px;
  margin-bottom: 24px;
`

const MetricCard = styled(Card)`
  padding: 20px;
`

const ServiceCard = styled(Card)`
  padding: 16px;
  margin-bottom: 12px;
  display: flex;
  align-items: center;
  justify-content: space-between;
`

const NetworkPage: React.FC = () => {
  const [systemInfo, setSystemInfo] = useState<SystemInfo | null>(null)
  const [networkInterfaces, setNetworkInterfaces] = useState<NetworkInterface[]>([])
  const [services, setServices] = useState<ServiceStatus[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [testTarget, setTestTarget] = useState('')
  const [testResult, setTestResult] = useState<string | null>(null)

  // データを取得
  const fetchData = async (showLoading = true) => {
    if (showLoading) setIsLoading(true)
    else setIsRefreshing(true)

    try {
      const [sysRes, netRes] = await Promise.all([
        systemAPI.getInfo(),
        systemAPI.getNetwork()
      ])
      
      setSystemInfo(sysRes.data)
      setNetworkInterfaces(netRes.data.interfaces || [])
      
      // サービスステータス（モック）
      setServices([
        { name: 'Caddy', status: 'running', uptime: systemInfo?.uptime || 0 },
        { name: 'LPG API', status: 'running', uptime: systemInfo?.uptime || 0 },
        { name: 'vsftpd', status: 'running', uptime: systemInfo?.uptime || 0 },
      ])
    } catch (error) {
      toast.error('システム情報の取得に失敗しました')
    } finally {
      setIsLoading(false)
      setIsRefreshing(false)
    }
  }

  useEffect(() => {
    fetchData()
    const interval = setInterval(() => fetchData(false), 10000) // 10秒ごとに更新
    return () => clearInterval(interval)
  }, [])

  // 接続テスト
  const handleConnectionTest = async () => {
    if (!testTarget) {
      toast.error('テスト対象を入力してください')
      return
    }

    setTestResult(null)
    try {
      const response = await systemAPI.testConnection(testTarget)
      setTestResult(response.data.result)
      toast.success('接続テストが完了しました')
    } catch (error) {
      setTestResult('接続テストに失敗しました')
      toast.error('接続テストに失敗しました')
    }
  }

  if (isLoading) {
    return (
      <PageContainer>
        <Box display="flex" justifyContent="center" py={6}>
          <Spinner size="large" />
        </Box>
      </PageContainer>
    )
  }

  return (
    <PageContainer>
      <HeaderSection>
        <Box>
          <Heading as="h1" sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
            <Octicon icon={GraphIcon} size={24} />
            ネットワーク状態
          </Heading>
          <Text as="p" color="fg.muted" mt={1}>
            システムとネットワークの状態を監視
          </Text>
        </Box>
        <Button
          leadingIcon={SyncIcon}
          onClick={() => fetchData(false)}
          disabled={isRefreshing}
        >
          {isRefreshing ? '更新中...' : '更新'}
        </Button>
      </HeaderSection>

      {/* システムメトリクス */}
      <MetricsGrid>
        <MetricCard>
          <Box display="flex" alignItems="center" mb={3}>
            <Octicon icon={ServerIcon} size={20} />
            <Heading as="h3" sx={{ ml: 2, fontSize: 2 }}>システム</Heading>
          </Box>
          {systemInfo && (
            <>
              <Box mb={2}>
                <Text fontSize={1} color="fg.muted">ホスト名</Text>
                <Text fontWeight="semibold">{systemInfo.hostname}</Text>
              </Box>
              <Box mb={2}>
                <Text fontSize={1} color="fg.muted">稼働時間</Text>
                <Text fontWeight="semibold">{formatUptime(systemInfo.uptime)}</Text>
              </Box>
              <Box>
                <Text fontSize={1} color="fg.muted">ロードアベレージ</Text>
                <Text fontFamily="mono">{systemInfo.load_average.join(', ')}</Text>
              </Box>
            </>
          )}
        </MetricCard>

        <MetricCard>
          <Box display="flex" alignItems="center" mb={3}>
            <Octicon icon={CpuIcon} size={20} />
            <Heading as="h3" sx={{ ml: 2, fontSize: 2 }}>メモリ</Heading>
          </Box>
          {systemInfo && (
            <>
              <Box mb={2}>
                <Text fontSize={1} color="fg.muted">使用率</Text>
                <Text fontWeight="semibold" fontSize={3}>{systemInfo.memory.percent}%</Text>
              </Box>
              <ProgressBar progress={systemInfo.memory.percent} />
              <Box mt={2}>
                <Text fontSize={0} color="fg.muted">
                  {formatBytes(systemInfo.memory.used)} / {formatBytes(systemInfo.memory.total)}
                </Text>
              </Box>
            </>
          )}
        </MetricCard>

        <MetricCard>
          <Box display="flex" alignItems="center" mb={3}>
            <Octicon icon={DatabaseIcon} size={20} />
            <Heading as="h3" sx={{ ml: 2, fontSize: 2 }}>ディスク</Heading>
          </Box>
          {systemInfo && (
            <>
              <Box mb={2}>
                <Text fontSize={1} color="fg.muted">使用率</Text>
                <Text fontWeight="semibold" fontSize={3}>{systemInfo.disk.percent}%</Text>
              </Box>
              <ProgressBar progress={systemInfo.disk.percent} />
              <Box mt={2}>
                <Text fontSize={0} color="fg.muted">
                  {formatBytes(systemInfo.disk.used)} / {formatBytes(systemInfo.disk.total)}
                </Text>
              </Box>
            </>
          )}
        </MetricCard>
      </MetricsGrid>

      {/* ネットワークインターフェース */}
      <Box mb={4}>
        <Heading as="h2" sx={{ mb: 3, fontSize: 3 }}>
          ネットワークインターフェース
        </Heading>
        {networkInterfaces.map((iface) => (
          <ServiceCard key={iface.name}>
            <Box>
              <Box display="flex" alignItems="center" gap={2}>
                <Octicon icon={LinkIcon} />
                <Text fontWeight="semibold">{iface.name}</Text>
                <Label variant={iface.status === 'up' ? 'success' : 'danger'}>
                  {iface.status}
                </Label>
              </Box>
              <Text fontSize={1} color="fg.muted" mt={1}>
                IP: {iface.ip_address} | MAC: {iface.mac_address}
              </Text>
              <Text fontSize={0} color="fg.muted">
                RX: {formatBytes(iface.rx_bytes)} | TX: {formatBytes(iface.tx_bytes)}
              </Text>
            </Box>
          </ServiceCard>
        ))}
      </Box>

      {/* サービスステータス */}
      <Box mb={4}>
        <Heading as="h2" sx={{ mb: 3, fontSize: 3 }}>
          サービスステータス
        </Heading>
        {services.map((service) => (
          <ServiceCard key={service.name}>
            <Box display="flex" alignItems="center" gap={2}>
              <Octicon
                icon={service.status === 'running' ? CheckIcon : XIcon}
                color={service.status === 'running' ? 'success.fg' : 'danger.fg'}
              />
              <Text fontWeight="semibold">{service.name}</Text>
            </Box>
            <Label
              variant={
                service.status === 'running' ? 'success' :
                service.status === 'stopped' ? 'attention' : 'danger'
              }
            >
              {service.status === 'running' ? '稼働中' :
               service.status === 'stopped' ? '停止' : 'エラー'}
            </Label>
          </ServiceCard>
        ))}
      </Box>

      {/* 接続テスト */}
      <Box>
        <Heading as="h2" sx={{ mb: 3, fontSize: 3 }}>
          接続テスト
        </Heading>
        <Card sx={{ p: 3 }}>
          <FormControl>
            <FormControl.Label>テスト対象（IPまたはホスト名）</FormControl.Label>
            <Box display="flex" gap={2}>
              <TextInput
                value={testTarget}
                onChange={(e) => setTestTarget(e.target.value)}
                placeholder="192.168.1.1 または example.com"
                sx={{ flex: 1 }}
              />
              <Button onClick={handleConnectionTest}>
                テスト実行
              </Button>
            </Box>
          </FormControl>
          {testResult && (
            <Alert variant="info" sx={{ mt: 3 }}>
              <pre style={{ margin: 0, whiteSpace: 'pre-wrap' }}>{testResult}</pre>
            </Alert>
          )}
        </Card>
      </Box>
    </PageContainer>
  )
}

// 稼働時間をフォーマット
const formatUptime = (seconds: number): string => {
  const days = Math.floor(seconds / 86400)
  const hours = Math.floor((seconds % 86400) / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  
  const parts = []
  if (days > 0) parts.push(`${days}日`)
  if (hours > 0) parts.push(`${hours}時間`)
  if (minutes > 0) parts.push(`${minutes}分`)
  
  return parts.join(' ') || '0分'
}

// バイト数をフォーマット
const formatBytes = (bytes: number): string => {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

export default NetworkPage 