// LogsPage.tsx - Logs Viewer Page
// Version: 1.0.0
// Description: ログ表示ページコンポーネント

import React, { useState, useEffect, useRef } from 'react'
import {
  Box,
  Button,
  DataTable,
  FormControl,
  Select,
  TextInput,
  Label,
  Heading,
  Text,
  Spinner,
  Octicon,
  SegmentedControl,
  IconButton,
} from '@primer/react'
import {
  FileIcon,
  SearchIcon,
  DownloadIcon,
  SyncIcon,
  FilterIcon,
  XIcon,
  CheckIcon,
  AlertIcon,
} from '@primer/octicons-react'
import { logsAPI } from '@services/api'
import toast from 'react-hot-toast'
import styled from 'styled-components'

interface LogEntry {
  id: string
  timestamp: string
  host: string
  path: string
  method: string
  status: number
  bytes: number
  duration: number
  ip: string
  user_agent: string
  sitename: string
}

const PageContainer = styled(Box)`
  padding: 24px;
  max-width: 1400px;
  margin: 0 auto;
`

const HeaderSection = styled(Box)`
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24px;
`

const FilterSection = styled(Box)`
  display: flex;
  gap: 16px;
  margin-bottom: 24px;
  flex-wrap: wrap;
`

const LogTable = styled(DataTable)`
  font-size: 14px;
  
  td {
    font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
  }
`

const StatusLabel = ({ status }: { status: number }) => {
  let variant: 'success' | 'danger' | 'attention' | 'accent' = 'accent'
  let icon = CheckIcon
  
  if (status >= 200 && status < 300) {
    variant = 'success'
    icon = CheckIcon
  } else if (status >= 400 && status < 500) {
    variant = 'attention'
    icon = AlertIcon
  } else if (status >= 500) {
    variant = 'danger'
    icon = XIcon
  }
  
  return (
    <Label variant={variant}>
      <Octicon icon={icon} /> {status}
    </Label>
  )
}

const LogsPage: React.FC = () => {
  const [logs, setLogs] = useState<LogEntry[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isStreaming, setIsStreaming] = useState(false)
  const [filters, setFilters] = useState({
    level: 'all',
    search: '',
    host: '',
    status: '',
  })
  const [timeRange, setTimeRange] = useState('1h')
  const streamRef = useRef<EventSource | null>(null)

  // ログを取得
  const fetchLogs = async () => {
    try {
      setIsLoading(true)
      const params = new URLSearchParams()
      if (filters.search) params.append('search', filters.search)
      if (filters.host) params.append('host', filters.host)
      if (filters.status) params.append('status', filters.status)
      params.append('range', timeRange)
      
      const response = await logsAPI.list(params.toString())
      setLogs(response.data.logs || [])
    } catch (error) {
      toast.error('ログの取得に失敗しました')
    } finally {
      setIsLoading(false)
    }
  }

  // ログのストリーミング
  const startStreaming = () => {
    if (streamRef.current) return
    
    setIsStreaming(true)
    const eventSource = new EventSource('/api/v1/logs/stream')
    
    eventSource.onmessage = (event) => {
      const newLog = JSON.parse(event.data)
      setLogs((prev) => [newLog, ...prev].slice(0, 1000)) // 最新1000件を保持
    }
    
    eventSource.onerror = () => {
      toast.error('ログストリーミングが切断されました')
      stopStreaming()
    }
    
    streamRef.current = eventSource
  }

  const stopStreaming = () => {
    if (streamRef.current) {
      streamRef.current.close()
      streamRef.current = null
    }
    setIsStreaming(false)
  }

  useEffect(() => {
    fetchLogs()
    return () => {
      stopStreaming()
    }
  }, [filters, timeRange])

  // ログのエクスポート
  const handleExport = async () => {
    try {
      const response = await logsAPI.export(timeRange)
      const blob = new Blob([response.data], { type: 'text/csv' })
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `lpg-logs-${new Date().toISOString()}.csv`
      a.click()
      window.URL.revokeObjectURL(url)
      toast.success('ログをエクスポートしました')
    } catch (error) {
      toast.error('ログのエクスポートに失敗しました')
    }
  }

  // フィルタリング
  const filteredLogs = logs.filter(log => {
    if (filters.level !== 'all') {
      if (filters.level === 'error' && log.status < 400) return false
      if (filters.level === 'warning' && (log.status < 400 || log.status >= 500)) return false
    }
    return true
  })

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
            <Octicon icon={FileIcon} size={24} />
            アクセスログ
          </Heading>
          <Text as="p" color="fg.muted" mt={1}>
            リバースプロキシのアクセスログを表示
          </Text>
        </Box>
        <Box display="flex" gap={2}>
          <Button
            leadingIcon={isStreaming ? XIcon : SyncIcon}
            variant={isStreaming ? 'danger' : 'default'}
            onClick={isStreaming ? stopStreaming : startStreaming}
          >
            {isStreaming ? 'ストリーミング停止' : 'リアルタイム'}
          </Button>
          <Button
            leadingIcon={DownloadIcon}
            onClick={handleExport}
          >
            エクスポート
          </Button>
        </Box>
      </HeaderSection>

      <FilterSection>
        <SegmentedControl
          aria-label="ログレベル"
          onChange={(index) => {
            const levels = ['all', 'error', 'warning']
            setFilters({ ...filters, level: levels[index] })
          }}
        >
          <SegmentedControl.Button defaultSelected>すべて</SegmentedControl.Button>
          <SegmentedControl.Button>エラー</SegmentedControl.Button>
          <SegmentedControl.Button>警告</SegmentedControl.Button>
        </SegmentedControl>

        <FormControl>
          <FormControl.Label visuallyHidden>期間</FormControl.Label>
          <Select
            value={timeRange}
            onChange={(e) => setTimeRange(e.target.value)}
          >
            <Select.Option value="1h">過去1時間</Select.Option>
            <Select.Option value="24h">過去24時間</Select.Option>
            <Select.Option value="7d">過去7日間</Select.Option>
            <Select.Option value="30d">過去30日間</Select.Option>
          </Select>
        </FormControl>

        <FormControl sx={{ flex: 1 }}>
          <FormControl.Label visuallyHidden>検索</FormControl.Label>
          <TextInput
            leadingVisual={SearchIcon}
            placeholder="検索..."
            value={filters.search}
            onChange={(e) => setFilters({ ...filters, search: e.target.value })}
          />
        </FormControl>
      </FilterSection>

      {filteredLogs.length === 0 ? (
        <Box textAlign="center" py={6}>
          <Text color="fg.muted">ログがありません</Text>
        </Box>
      ) : (
        <LogTable
          data={filteredLogs}
          columns={[
            {
              header: '時刻',
              field: 'timestamp',
              renderCell: (row) => (
                <Text fontSize={0}>
                  {new Date(row.timestamp).toLocaleString('ja-JP')}
                </Text>
              ),
            },
            {
              header: 'ホスト',
              field: 'host',
              renderCell: (row) => (
                <Text fontWeight="semibold">{row.host}</Text>
              ),
            },
            {
              header: 'パス',
              field: 'path',
              renderCell: (row) => (
                <Text>{row.path}</Text>
              ),
            },
            {
              header: 'メソッド',
              field: 'method',
              renderCell: (row) => (
                <Label variant={row.method === 'GET' ? 'success' : 'accent'}>
                  {row.method}
                </Label>
              ),
            },
            {
              header: 'ステータス',
              field: 'status',
              renderCell: (row) => <StatusLabel status={row.status} />,
            },
            {
              header: 'サイズ',
              field: 'bytes',
              renderCell: (row) => (
                <Text>{formatBytes(row.bytes)}</Text>
              ),
            },
            {
              header: '応答時間',
              field: 'duration',
              renderCell: (row) => (
                <Text>{row.duration}ms</Text>
              ),
            },
            {
              header: 'IP',
              field: 'ip',
              renderCell: (row) => (
                <Text fontSize={0}>{row.ip}</Text>
              ),
            },
            {
              header: 'サイト',
              field: 'sitename',
              renderCell: (row) => (
                <Text>{row.sitename || '-'}</Text>
              ),
            },
          ]}
        />
      )}
    </PageContainer>
  )
}

// バイト数をフォーマット
const formatBytes = (bytes: number): string => {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

export default LogsPage 