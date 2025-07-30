// NotFoundPage.tsx - 404 Not Found Page
// Version: 1.0.0
// Description: 404エラーページコンポーネント

import React from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Box,
  Button,
  Heading,
  Text,
  Octicon,
} from '@primer/react'
import { HomeIcon, SearchIcon } from '@primer/octicons-react'
import styled from 'styled-components'

const Container = styled(Box)`
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-canvas-default);
`

const Content = styled(Box)`
  text-align: center;
  max-width: 500px;
  padding: 32px;
`

const ErrorCode = styled(Text)`
  font-size: 120px;
  font-weight: 300;
  color: var(--color-fg-muted);
  line-height: 1;
  margin-bottom: 16px;
`

const NotFoundPage: React.FC = () => {
  const navigate = useNavigate()

  return (
    <Container>
      <Content>
        <ErrorCode as="div">404</ErrorCode>
        
        <Heading as="h1" sx={{ mb: 2, fontSize: 4 }}>
          ページが見つかりません
        </Heading>
        
        <Text as="p" color="fg.muted" sx={{ mb: 4 }}>
          お探しのページは存在しないか、移動した可能性があります。
          URLをご確認ください。
        </Text>
        
        <Box display="flex" justifyContent="center" gap={2}>
          <Button
            leadingIcon={HomeIcon}
            onClick={() => navigate('/')}
          >
            ホームに戻る
          </Button>
          <Button
            variant="primary"
            leadingIcon={SearchIcon}
            onClick={() => navigate('/domains')}
          >
            ドメイン管理へ
          </Button>
        </Box>
      </Content>
    </Container>
  )
}

export default NotFoundPage 