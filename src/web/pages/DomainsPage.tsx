// DomainsPage.tsx - Domains Management Page
// Version: 1.0.0
// Description: ドメイン管理ページコンポーネント

import React, { useState, useEffect } from 'react'
import {
  Box,
  Button,
  DataTable,
  Dialog,
  FormControl,
  TextInput,
  IconButton,
  Flash,
  Label,
  Heading,
  ActionMenu,
  ActionList,
  Spinner,
  Octicon,
} from '@primer/react'
import {
  PlusIcon,
  GlobeIcon,
  PencilIcon,
  TrashIcon,
  CheckIcon,
  XIcon,
  AlertIcon,
  ShieldCheckIcon,
} from '@primer/octicons-react'
import { domainsAPI } from '@services/api'
import toast from 'react-hot-toast'
import styled from 'styled-components'

interface Domain {
  domain: string
  subnet: string
  devices: number
  cert_status: string
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

const DomainsPage: React.FC = () => {
  const [domains, setDomains] = useState<Domain[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [showAddDialog, setShowAddDialog] = useState(false)
  const [showEditDialog, setShowEditDialog] = useState(false)
  const [selectedDomain, setSelectedDomain] = useState<Domain | null>(null)
  const [formData, setFormData] = useState({ domain: '', subnet: '' })
  const [isSubmitting, setIsSubmitting] = useState(false)

  // ドメイン一覧を取得
  const fetchDomains = async () => {
    try {
      setIsLoading(true)
      const response = await domainsAPI.list()
      setDomains(response.data.domains)
    } catch (error) {
      toast.error('ドメイン一覧の取得に失敗しました')
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    fetchDomains()
  }, [])

  // ドメインを追加
  const handleAddDomain = async () => {
    if (!formData.domain || !formData.subnet) {
      toast.error('すべての項目を入力してください')
      return
    }

    setIsSubmitting(true)
    try {
      await domainsAPI.create(formData.domain, formData.subnet)
      toast.success('ドメインを追加しました')
      setShowAddDialog(false)
      setFormData({ domain: '', subnet: '' })
      fetchDomains()
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'ドメインの追加に失敗しました')
    } finally {
      setIsSubmitting(false)
    }
  }

  // ドメインを更新
  const handleUpdateDomain = async () => {
    if (!selectedDomain || !formData.subnet) {
      return
    }

    setIsSubmitting(true)
    try {
      await domainsAPI.update(selectedDomain.domain, formData.subnet)
      toast.success('ドメインを更新しました')
      setShowEditDialog(false)
      setSelectedDomain(null)
      fetchDomains()
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'ドメインの更新に失敗しました')
    } finally {
      setIsSubmitting(false)
    }
  }

  // ドメインを削除
  const handleDeleteDomain = async (domain: string) => {
    if (!window.confirm(`本当に "${domain}" を削除しますか？`)) {
      return
    }

    try {
      await domainsAPI.delete(domain)
      toast.success('ドメインを削除しました')
      fetchDomains()
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'ドメインの削除に失敗しました')
    }
  }

  // 証明書ステータスのラベル
  const getCertStatusLabel = (status: string) => {
    switch (status) {
      case 'active':
        return <Label variant="success"><Octicon icon={CheckIcon} /> 有効</Label>
      case 'expired':
        return <Label variant="danger"><Octicon icon={XIcon} /> 期限切れ</Label>
      case 'pending':
        return <Label variant="attention"><Octicon icon={AlertIcon} /> 取得中</Label>
      default:
        return <Label><Octicon icon={AlertIcon} /> 不明</Label>
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
            <Octicon icon={GlobeIcon} size={24} />
            ドメイン管理
          </Heading>
          <Text as="p" color="fg.muted" mt={1}>
            リバースプロキシで管理するドメインの設定
          </Text>
        </Box>
        <Button
          leadingIcon={PlusIcon}
          onClick={() => setShowAddDialog(true)}
        >
          ドメインを追加
        </Button>
      </HeaderSection>

      {domains.length === 0 ? (
        <Flash>
          <Octicon icon={GlobeIcon} />
          まだドメインが登録されていません。「ドメインを追加」ボタンから追加してください。
        </Flash>
      ) : (
        <DataTable
          data={domains}
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
              header: 'サブネット',
              field: 'subnet',
              renderCell: (row) => (
                <Text fontFamily="mono" fontSize={1}>
                  {row.subnet}
                </Text>
              ),
            },
            {
              header: 'デバイス数',
              field: 'devices',
              renderCell: (row) => (
                <Text>{row.devices} 台</Text>
              ),
            },
            {
              header: '証明書',
              field: 'cert_status',
              renderCell: (row) => getCertStatusLabel(row.cert_status),
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
                      setSelectedDomain(row)
                      setFormData({ domain: row.domain, subnet: row.subnet })
                      setShowEditDialog(true)
                    }}
                  />
                  <IconButton
                    icon={TrashIcon}
                    aria-label="削除"
                    size="small"
                    variant="danger"
                    disabled={row.devices > 0}
                    onClick={() => handleDeleteDomain(row.domain)}
                  />
                </Box>
              ),
            },
          ]}
        />
      )}

      {/* ドメイン追加ダイアログ */}
      <Dialog
        isOpen={showAddDialog}
        onDismiss={() => {
          setShowAddDialog(false)
          setFormData({ domain: '', subnet: '' })
        }}
        aria-labelledby="add-domain-dialog"
      >
        <Dialog.Header id="add-domain-dialog">ドメインを追加</Dialog.Header>
        <Box p={3}>
          <FormControl required sx={{ mb: 3 }}>
            <FormControl.Label>ドメイン名</FormControl.Label>
            <TextInput
              value={formData.domain}
              onChange={(e) => setFormData({ ...formData, domain: e.target.value })}
              placeholder="example.com"
              block
            />
            <FormControl.Caption>
              DDNSまたは独自ドメインを入力してください
            </FormControl.Caption>
          </FormControl>

          <FormControl required>
            <FormControl.Label>許可サブネット</FormControl.Label>
            <TextInput
              value={formData.subnet}
              onChange={(e) => setFormData({ ...formData, subnet: e.target.value })}
              placeholder="192.168.234.0/24"
              block
            />
            <FormControl.Caption>
              このドメインへのアクセスを許可するサブネット（CIDR形式）
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
              onClick={handleAddDomain}
              disabled={isSubmitting}
            >
              {isSubmitting ? '追加中...' : '追加'}
            </Button>
          </Dialog.Buttons>
        </Dialog.Footer>
      </Dialog>

      {/* ドメイン編集ダイアログ */}
      <Dialog
        isOpen={showEditDialog}
        onDismiss={() => {
          setShowEditDialog(false)
          setSelectedDomain(null)
        }}
        aria-labelledby="edit-domain-dialog"
      >
        <Dialog.Header id="edit-domain-dialog">ドメインを編集</Dialog.Header>
        <Box p={3}>
          <FormControl disabled sx={{ mb: 3 }}>
            <FormControl.Label>ドメイン名</FormControl.Label>
            <TextInput
              value={formData.domain}
              disabled
              block
            />
          </FormControl>

          <FormControl required>
            <FormControl.Label>許可サブネット</FormControl.Label>
            <TextInput
              value={formData.subnet}
              onChange={(e) => setFormData({ ...formData, subnet: e.target.value })}
              placeholder="192.168.234.0/24"
              block
            />
            <FormControl.Caption>
              このドメインへのアクセスを許可するサブネット（CIDR形式）
            </FormControl.Caption>
          </FormControl>
        </Box>
        <Dialog.Footer>
          <Dialog.Buttons>
            <Button onClick={() => setShowEditDialog(false)}>
              キャンセル
            </Button>
            <Button
              variant="primary"
              onClick={handleUpdateDomain}
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

export default DomainsPage 