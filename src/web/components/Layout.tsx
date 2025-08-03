// Layout.tsx - Application Layout Component
// Version: 1.0.0
// Description: アプリケーション全体のレイアウトコンポーネント

import React, { useState } from 'react'
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom'
import { 
  Box, 
  Header, 
  Avatar, 
  ActionMenu, 
  ActionList,
  IconButton,
  SplitPageLayout,
  NavList,
  Text,
  Octicon,
  Button,
} from '@primer/react'
import { 
  HomeIcon, 
  GlobeIcon, 
  ServerIcon, 
  FileIcon, 
  GearIcon,
  SignOutIcon,
  PersonIcon,
  MoonIcon,
  SunIcon,
  GraphIcon,
  RocketIcon,
} from '@primer/octicons-react'
import { useAuth } from '@contexts/AuthContext'
import { useConfig } from '@contexts/ConfigContext'
import styled from 'styled-components'
import toast from 'react-hot-toast'

const StyledHeader = styled(Header)`
  padding: 0 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--color-border-default);
`

const Logo = styled.div`
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 18px;
  font-weight: 600;
  color: var(--color-fg-default);
`

const Layout: React.FC = () => {
  const location = useLocation()
  const navigate = useNavigate()
  const { user, logout } = useAuth()
  const { deployConfig } = useConfig()
  const [isDarkMode, setIsDarkMode] = useState(
    document.documentElement.getAttribute('data-color-mode') === 'dark'
  )
  const [isDeploying, setIsDeploying] = useState(false)

  const toggleTheme = () => {
    const newMode = isDarkMode ? 'light' : 'dark'
    document.documentElement.setAttribute('data-color-mode', newMode)
    localStorage.setItem('lpg-theme', newMode)
    setIsDarkMode(!isDarkMode)
  }

  const handleLogout = async () => {
    await logout()
  }

  const handleDeploy = async () => {
    if (!confirm('設定を適用しますか？サービスが一時的に停止する可能性があります。')) {
      return
    }

    setIsDeploying(true)
    try {
      await deployConfig()
      toast.success('設定が正常に適用されました')
    } catch (error) {
      toast.error('デプロイに失敗しました: ' + (error as Error).message)
    } finally {
      setIsDeploying(false)
    }
  }

  const navigationItems = [
    { path: '/domains', label: 'Domains', icon: GlobeIcon },
    { path: '/devices', label: 'Devices', icon: ServerIcon },
    { path: '/logs', label: 'Logs', icon: FileIcon },
    { path: '/network', label: 'Network', icon: GraphIcon },
    { path: '/settings', label: 'Settings', icon: GearIcon },
  ]

  return (
    <Box height="100vh" display="flex" flexDirection="column">
      <StyledHeader>
        <Header.Item>
          <Logo>
            <Octicon icon={HomeIcon} size={24} />
            <span>LacisProxyGateway</span>
          </Logo>
        </Header.Item>

        <Header.Item>
          <Box display="flex" alignItems="center" gap={2}>
            <Button
              variant="primary"
              size="small"
              leadingIcon={RocketIcon}
              onClick={handleDeploy}
              loading={isDeploying}
              disabled={isDeploying}
            >
              {isDeploying ? 'Deploying...' : 'Deploy Changes'}
            </Button>

            <IconButton
              icon={isDarkMode ? SunIcon : MoonIcon}
              aria-label="Toggle theme"
              onClick={toggleTheme}
              variant="invisible"
            />

            <ActionMenu>
              <ActionMenu.Anchor>
                <IconButton
                  icon={() => (
                    <Avatar
                      size={32}
                      src={`https://github.com/identicons/${user?.username}.png`}
                    />
                  )}
                  aria-label="User menu"
                  variant="invisible"
                />
              </ActionMenu.Anchor>

              <ActionMenu.Overlay>
                <ActionList>
                  <ActionList.Item disabled>
                    <ActionList.LeadingVisual>
                      <PersonIcon />
                    </ActionList.LeadingVisual>
                    {user?.username}
                  </ActionList.Item>
                  
                  <ActionList.Divider />
                  
                  <ActionList.Item
                    onSelect={() => navigate('/settings/account')}
                  >
                    <ActionList.LeadingVisual>
                      <GearIcon />
                    </ActionList.LeadingVisual>
                    アカウント設定
                  </ActionList.Item>
                  
                  <ActionList.Divider />
                  
                  <ActionList.Item
                    variant="danger"
                    onSelect={handleLogout}
                  >
                    <ActionList.LeadingVisual>
                      <SignOutIcon />
                    </ActionList.LeadingVisual>
                    ログアウト
                  </ActionList.Item>
                </ActionList>
              </ActionMenu.Overlay>
            </ActionMenu>
          </Box>
        </Header.Item>
      </StyledHeader>

      <Box flex={1} overflow="hidden">
        <SplitPageLayout>
          <SplitPageLayout.Pane
            position="start"
            width="medium"
            divider="line"
            sticky
          >
            <Box p={3}>
              <NavList>
                {navigationItems.map((item) => (
                  <NavList.Item
                    key={item.path}
                    href={item.path}
                    aria-current={location.pathname.startsWith(item.path) ? 'page' : undefined}
                    onClick={(e) => {
                      e.preventDefault()
                      navigate(item.path)
                    }}
                  >
                    <NavList.LeadingVisual>
                      <Octicon icon={item.icon} />
                    </NavList.LeadingVisual>
                    {item.label}
                  </NavList.Item>
                ))}
              </NavList>
            </Box>
          </SplitPageLayout.Pane>

          <SplitPageLayout.Content>
            <Outlet />
          </SplitPageLayout.Content>
        </SplitPageLayout>
      </Box>
    </Box>
  )
}

export default Layout 