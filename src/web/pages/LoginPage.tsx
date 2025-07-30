// LoginPage.tsx - Login Page Component
// Version: 1.0.0
// Description: ログインページコンポーネント

import React, { useState, useEffect } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import {
  Box,
  Button,
  FormControl,
  TextInput,
  Text,
  Flash,
  Heading,
  Octicon,
} from '@primer/react'
import { KeyIcon, PersonIcon, ShieldIcon } from '@primer/octicons-react'
import { useAuth } from '@contexts/AuthContext'
import styled from 'styled-components'

const LoginContainer = styled(Box)`
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-canvas-default);
`

const LoginCard = styled(Box)`
  width: 100%;
  max-width: 400px;
  padding: 32px;
  background: var(--color-canvas-subtle);
  border: 1px solid var(--color-border-default);
  border-radius: 12px;
  box-shadow: var(--color-shadow-medium);
`

const LogoContainer = styled(Box)`
  text-align: center;
  margin-bottom: 32px;
`

const Logo = styled.div`
  display: inline-flex;
  align-items: center;
  gap: 12px;
  font-size: 24px;
  font-weight: 600;
  color: var(--color-fg-default);
`

const LoginPage: React.FC = () => {
  const navigate = useNavigate()
  const location = useLocation()
  const { login, isAuthenticated } = useAuth()
  
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')
  const [showPasswordChange, setShowPasswordChange] = useState(false)
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')

  // リダイレクト元のパス
  const from = (location.state as any)?.from?.pathname || '/domains'

  // 既にログイン済みの場合はリダイレクト
  useEffect(() => {
    if (isAuthenticated) {
      navigate(from, { replace: true })
    }
  }, [isAuthenticated, navigate, from])

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setIsLoading(true)

    try {
      await login(username, password)
      
      // 初回ログインチェック（パスワードがデフォルトの場合）
      if (password === 'changeme' || password === '1234') {
        setShowPasswordChange(true)
        setIsLoading(false)
        return
      }
      
      navigate(from, { replace: true })
    } catch (err: any) {
      setError(err.message || 'ログインに失敗しました')
      setIsLoading(false)
    }
  }

  const handlePasswordChange = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (newPassword !== confirmPassword) {
      setError('新しいパスワードが一致しません')
      return
    }

    if (newPassword.length < 8) {
      setError('パスワードは8文字以上で設定してください')
      return
    }

    setIsLoading(true)

    try {
      // パスワード変更APIを呼び出す
      const { changePassword } = useAuth()
      await changePassword(password, newPassword)
      
      // 新しいパスワードで再ログイン
      await login(username, newPassword)
      navigate(from, { replace: true })
    } catch (err: any) {
      setError(err.message || 'パスワードの変更に失敗しました')
      setIsLoading(false)
    }
  }

  if (showPasswordChange) {
    return (
      <LoginContainer>
        <LoginCard>
          <LogoContainer>
            <Logo>
              <Octicon icon={ShieldIcon} size={32} />
              <span>パスワード変更</span>
            </Logo>
          </LogoContainer>

          <Flash variant="warning" sx={{ mb: 3 }}>
            初回ログインのため、パスワードを変更してください
          </Flash>

          <form onSubmit={handlePasswordChange}>
            <FormControl sx={{ mb: 3 }}>
              <FormControl.Label>新しいパスワード</FormControl.Label>
              <TextInput
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                placeholder="8文字以上で入力"
                required
                autoFocus
                block
              />
            </FormControl>

            <FormControl sx={{ mb: 3 }}>
              <FormControl.Label>新しいパスワード（確認）</FormControl.Label>
              <TextInput
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="もう一度入力"
                required
                block
              />
            </FormControl>

            {error && (
              <Flash variant="danger" sx={{ mb: 3 }}>
                {error}
              </Flash>
            )}

            <Button
              type="submit"
              variant="primary"
              disabled={isLoading}
              block
            >
              {isLoading ? 'パスワードを変更中...' : 'パスワードを変更'}
            </Button>
          </form>
        </LoginCard>
      </LoginContainer>
    )
  }

  return (
    <LoginContainer>
      <LoginCard>
        <LogoContainer>
          <Logo>
            <Octicon icon={ShieldIcon} size={32} />
            <span>LacisProxyGateway</span>
          </Logo>
          <Text as="p" color="fg.muted" mt={2}>
            管理コンソールにログイン
          </Text>
        </LogoContainer>

        <form onSubmit={handleLogin}>
          <FormControl sx={{ mb: 3 }}>
            <FormControl.Label>
              <Octicon icon={PersonIcon} /> ユーザー名
            </FormControl.Label>
            <TextInput
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="admin"
              required
              autoFocus
              autoComplete="username"
              block
            />
          </FormControl>

          <FormControl sx={{ mb: 3 }}>
            <FormControl.Label>
              <Octicon icon={KeyIcon} /> パスワード
            </FormControl.Label>
            <TextInput
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="パスワードを入力"
              required
              autoComplete="current-password"
              block
            />
          </FormControl>

          {error && (
            <Flash variant="danger" sx={{ mb: 3 }}>
              {error}
            </Flash>
          )}

          <Button
            type="submit"
            variant="primary"
            disabled={isLoading || !username || !password}
            block
          >
            {isLoading ? 'ログイン中...' : 'ログイン'}
          </Button>
        </form>

        <Box mt={4} textAlign="center">
          <Text as="p" fontSize={0} color="fg.muted">
            Version 1.0.0
          </Text>
        </Box>
      </LoginCard>
    </LoginContainer>
  )
}

export default LoginPage 