// DevicesPage.tsx - Devices/Routing Management Page
// Version: 1.0.0
// Description: デバイス（ルーティング）管理ページコンポーネント

import React, { useState, useEffect } from 'react'
import {
  Box,
  Button,
  DataTable,
  Dialog,
  FormControl,
  TextInput,
  Select,
  IconButton,
  Flash,
  Label,
  Heading,
  Text,
  Spinner,
  Octicon,
  ActionMenu,
  ActionList,
} from '@primer/react'
import {
  PlusIcon,
  ServerIcon,
  PencilIcon,
  TrashIcon,
  GlobeIcon,
  LinkIcon,
  ShieldIcon,
  CodeIcon,
} from '@primer/octicons-react'
import { devicesAPI, domainsAPI } from '@services/api'
import toast from 'react-hot-toast'
import styled from 'styled-components'

interface Device {
  domain: string
  path: string
  deviceip: string
  port: number[]
  sitename: string
  ips: string[]
}

interface Domain {
  domain: string
  subnet: string
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

const FilterSection = styled(Box)`
  display: flex;
  gap: 16px;
  margin-bottom: 24px;
`

const DevicesPage: React.FC = () => {
  const [devices, setDevices] = useState<Device[]>([])
  const [domains, setDomains] = useState<Domain[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [showAddDialog, setShowAddDialog] = useState(false)
  const [showEditDialog, setShowEditDialog] = useState(false)
  const [selectedDevice, setSelectedDevice] = useState<Device | null>(null)
  const [selectedDomain, setSelectedDomain] = useState<string>('')
  const [formData, setFormData] = useState({
    domain: '',
    path: '',
    deviceip: '',
    port: '',
    sitename: '',
    ips: ''
  })
  const [isSubmitting, setIsSubmitting] = useState(false)

  // データを取得
  const fetchData = async () => {
    try {
      setIsLoading(true)
      const [devicesRes, domainsRes] = await Promise.all([
        devicesAPI.list(),
        domainsAPI.list()
      ])
      setDevices(devicesRes.data.devices || [])
      setDomains(domainsRes.data.domains || [])
    } catch (error) {
      toast.error('データの取得に失敗しました')
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    fetchData()
  }, [])

  // デバイスを追加
  const handleAddDevice = async () => {
    if (!formData.domain || !formData.path || !formData.deviceip) {
      toast.error('必須項目を入力してください')
      return
    }

    setIsSubmitting(true)
    try {
      const data = {
        ...formData,
        port: formData.port ? formData.port.split(',').map(p => parseInt(p.trim())) : [],
        ips: formData.ips ? formData.ips.split(',').map(ip => ip.trim()) : ['any']
      }
      
      await devicesAPI.create(data)
      toast.success('ルーティングルールを追加しました')
      setShowAddDialog(false)
      resetForm()
      fetchData()
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'ルールの追加に失敗しました')
    } finally {
      setIsSubmitting(false)
    }
  }

  // デバイスを更新
  const handleUpdateDevice = async () => {
    if (!selectedDevice || !formData.deviceip) {
      return
    }

    setIsSubmitting(true)
    try {
      const data = {
        ...formData,
        port: formData.port ? formData.port.split(',').map(p => parseInt(p.trim())) : [],
        ips: formData.ips ? formData.ips.split(',').map(ip => ip.trim()) : ['any']
      }
      
      await devicesAPI.update(
        selectedDevice.domain,
        selectedDevice.path,
        data
      )
      toast.success('ルーティングルールを更新しました')
      setShowEditDialog(false)
      setSelectedDevice(null)
      fetchData()
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'ルールの更新に失敗しました')
    } finally {
      setIsSubmitting(false)
    }
  }

  // デバイスを削除
  const handleDeleteDevice = async (device: Device) => {
    if (!window.confirm(`本当に "${device.domain}${device.path}" のルールを削除しますか？`)) {
      return
    }

    try {
      await devicesAPI.delete(device.domain, device.path)
      toast.success('ルーティングルールを削除しました')
      fetchData()
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'ルールの削除に失敗しました')
    }
  }

  const resetForm = () => {
    setFormData({
      domain: '',
      path: '',
      deviceip: '',
      port: '',
      sitename: '',
      ips: ''
    })
  }

  // フィルタリング
  const filteredDevices = selectedDomain
    ? devices.filter(d => d.domain === selectedDomain)
    : devices

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
            <Octicon icon={ServerIcon} size={24} />
            デバイス管理
          </Heading>
          <Text as="p" color="fg.muted" mt={1}>
            ドメインごとのルーティングルールを管理
          </Text>
        </Box>
        <Button
          leadingIcon={PlusIcon}
          onClick={() => setShowAddDialog(true)}
        >
          ルールを追加
        </Button>
      </HeaderSection>

      <FilterSection>
        <FormControl>
          <FormControl.Label visuallyHidden>ドメインでフィルタ</FormControl.Label>
          <Select
            value={selectedDomain}
            onChange={(e) => setSelectedDomain(e.target.value)}
          >
            <Select.Option value="">すべてのドメイン</Select.Option>
            {domains.map((domain) => (
              <Select.Option key={domain.domain} value={domain.domain}>
                {domain.domain}
              </Select.Option>
            ))}
          </Select>
        </FormControl>
      </FilterSection>

      {filteredDevices.length === 0 ? (
        <Flash>
          <Octicon icon={ServerIcon} />
          {selectedDomain
            ? `${selectedDomain} にはルーティングルールがありません`
            : 'まだルーティングルールが登録されていません'}
        </Flash>
      ) : (
        <DataTable
          data={filteredDevices}
          columns={[
            {
              header: 'ドメイン',
              field: 'domain',
              renderCell: (row) => (
                <Box display="flex" alignItems="center" gap={2}>
                  <Octicon icon={GlobeIcon} />
                  <Text fontWeight="semibold">{row.domain}</Text>
                </Box>
              ),
            },
            {
              header: 'パス',
              field: 'path',
              renderCell: (row) => (
                <Text fontFamily="mono" fontSize={1}>
                  {row.path || '/'}
                </Text>
              ),
            },
            {
              header: 'デバイスIP',
              field: 'deviceip',
              renderCell: (row) => (
                <Text fontFamily="mono" fontSize={1}>
                  {row.deviceip || '-'}
                </Text>
              ),
            },
            {
              header: 'ポート',
              field: 'port',
              renderCell: (row) => (
                <Text fontFamily="mono" fontSize={1}>
                  {row.port.length > 0 ? row.port.join(', ') : 'any'}
                </Text>
              ),
            },
            {
              header: 'サイト名',
              field: 'sitename',
              renderCell: (row) => (
                <Text>{row.sitename || '-'}</Text>
              ),
            },
            {
              header: '許可IP',
              field: 'ips',
              renderCell: (row) => {
                if (row.ips.includes('any')) {
                  return <Label>すべて許可</Label>
                }
                return (
                  <Label variant="accent">
                    {row.ips.length} IP制限
                  </Label>
                )
              },
            },
            {
              header: '操作',
              field: 'actions',
              renderCell: (row) => (
                <Box display="flex" gap={1}>
                  <IconButton
                    icon={PencilIcon}
                    aria-label="編集"
                    size="small"
                    onClick={() => {
                      setSelectedDevice(row)
                      setFormData({
                        domain: row.domain,
                        path: row.path,
                        deviceip: row.deviceip,
                        port: row.port.join(', '),
                        sitename: row.sitename,
                        ips: row.ips.join(', ')
                      })
                      setShowEditDialog(true)
                    }}
                  />
                  <IconButton
                    icon={TrashIcon}
                    aria-label="削除"
                    size="small"
                    variant="danger"
                    onClick={() => handleDeleteDevice(row)}
                  />
                </Box>
              ),
            },
          ]}
        />
      )}

      {/* ルール追加ダイアログ */}
      <Dialog
        isOpen={showAddDialog}
        onDismiss={() => {
          setShowAddDialog(false)
          resetForm()
        }}
        aria-labelledby="add-device-dialog"
      >
        <Dialog.Header id="add-device-dialog">ルーティングルールを追加</Dialog.Header>
        <Box p={3}>
          <FormControl required sx={{ mb: 3 }}>
            <FormControl.Label>ドメイン</FormControl.Label>
            <Select
              value={formData.domain}
              onChange={(e) => setFormData({ ...formData, domain: e.target.value })}
              block
            >
              <Select.Option value="">選択してください</Select.Option>
              {domains.map((domain) => (
                <Select.Option key={domain.domain} value={domain.domain}>
                  {domain.domain}
                </Select.Option>
              ))}
            </Select>
          </FormControl>

          <FormControl required sx={{ mb: 3 }}>
            <FormControl.Label>パス</FormControl.Label>
            <TextInput
              value={formData.path}
              onChange={(e) => setFormData({ ...formData, path: e.target.value })}
              placeholder="/app"
              leadingVisual="/"
              block
            />
            <FormControl.Caption>
              ルートパスの場合は空欄のままにしてください
            </FormControl.Caption>
          </FormControl>

          <FormControl required sx={{ mb: 3 }}>
            <FormControl.Label>デバイスIP</FormControl.Label>
            <TextInput
              value={formData.deviceip}
              onChange={(e) => setFormData({ ...formData, deviceip: e.target.value })}
              placeholder="192.168.234.10"
              block
            />
            <FormControl.Caption>
              転送先のデバイスIPアドレス（空の場合は接続拒否）
            </FormControl.Caption>
          </FormControl>

          <FormControl sx={{ mb: 3 }}>
            <FormControl.Label>ポート</FormControl.Label>
            <TextInput
              value={formData.port}
              onChange={(e) => setFormData({ ...formData, port: e.target.value })}
              placeholder="8080, 8443"
              block
            />
            <FormControl.Caption>
              転送先のポート番号（カンマ区切り、空の場合はany）
            </FormControl.Caption>
          </FormControl>

          <FormControl sx={{ mb: 3 }}>
            <FormControl.Label>サイト名</FormControl.Label>
            <TextInput
              value={formData.sitename}
              onChange={(e) => setFormData({ ...formData, sitename: e.target.value })}
              placeholder="whiteboard"
              block
            />
            <FormControl.Caption>
              ログ記録用の識別名
            </FormControl.Caption>
          </FormControl>

          <FormControl>
            <FormControl.Label>許可IP</FormControl.Label>
            <TextInput
              value={formData.ips}
              onChange={(e) => setFormData({ ...formData, ips: e.target.value })}
              placeholder="192.168.1.0/24, 10.0.0.1"
              block
            />
            <FormControl.Caption>
              アクセスを許可するIPアドレス（カンマ区切り、空の場合はany）
            </FormControl.Caption>
          </FormControl>
        </Box>
        <Dialog.Footer>
          <Dialog.Buttons>
            <Button onClick={() => setShowAddDialog(false)}>
              キャンセル
            </Button>
            <Button
              variant="primary"
              onClick={handleAddDevice}
              disabled={isSubmitting}
            >
              {isSubmitting ? '追加中...' : '追加'}
            </Button>
          </Dialog.Buttons>
        </Dialog.Footer>
      </Dialog>

      {/* ルール編集ダイアログ */}
      <Dialog
        isOpen={showEditDialog}
        onDismiss={() => {
          setShowEditDialog(false)
          setSelectedDevice(null)
        }}
        aria-labelledby="edit-device-dialog"
      >
        <Dialog.Header id="edit-device-dialog">ルーティングルールを編集</Dialog.Header>
        <Box p={3}>
          <FormControl disabled sx={{ mb: 3 }}>
            <FormControl.Label>ドメイン</FormControl.Label>
            <TextInput value={formData.domain} disabled block />
          </FormControl>

          <FormControl disabled sx={{ mb: 3 }}>
            <FormControl.Label>パス</FormControl.Label>
            <TextInput value={formData.path || '/'} disabled block />
          </FormControl>

          <FormControl required sx={{ mb: 3 }}>
            <FormControl.Label>デバイスIP</FormControl.Label>
            <TextInput
              value={formData.deviceip}
              onChange={(e) => setFormData({ ...formData, deviceip: e.target.value })}
              placeholder="192.168.234.10"
              block
            />
          </FormControl>

          <FormControl sx={{ mb: 3 }}>
            <FormControl.Label>ポート</FormControl.Label>
            <TextInput
              value={formData.port}
              onChange={(e) => setFormData({ ...formData, port: e.target.value })}
              placeholder="8080, 8443"
              block
            />
          </FormControl>

          <FormControl sx={{ mb: 3 }}>
            <FormControl.Label>サイト名</FormControl.Label>
            <TextInput
              value={formData.sitename}
              onChange={(e) => setFormData({ ...formData, sitename: e.target.value })}
              placeholder="whiteboard"
              block
            />
          </FormControl>

          <FormControl>
            <FormControl.Label>許可IP</FormControl.Label>
            <TextInput
              value={formData.ips}
              onChange={(e) => setFormData({ ...formData, ips: e.target.value })}
              placeholder="192.168.1.0/24, 10.0.0.1"
              block
            />
          </FormControl>
        </Box>
        <Dialog.Footer>
          <Dialog.Buttons>
            <Button onClick={() => setShowEditDialog(false)}>
              キャンセル
            </Button>
            <Button
              variant="primary"
              onClick={handleUpdateDevice}
              disabled={isSubmitting}
            >
              {isSubmitting ? '更新中...' : '更新'}
            </Button>
          </Dialog.Buttons>
        </Dialog.Footer>
      </Dialog>
    </PageContainer>
  )
}

export default DevicesPage 