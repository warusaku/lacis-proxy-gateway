// App.tsx - Main Application Component
// Version: 1.0.0
// Description: LacisProxyGateway管理UIのメインコンポーネント

import React, { useEffect } from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { BaseStyles, ThemeProvider, theme } from '@primer/react'
import { Toaster } from 'react-hot-toast'

// Contexts
import { AuthProvider } from '@contexts/AuthContext'
import { ThemeProvider as AppThemeProvider } from '@contexts/ThemeContext'
import { ConfigProvider } from '@contexts/ConfigContext'

// Components
import PrivateRoute from '@components/PrivateRoute'
import Layout from '@components/Layout'

// Pages
import LoginPage from '@pages/LoginPage'
import DomainsPage from '@pages/DomainsPage'
import DevicesPage from '@pages/DevicesPage'
import LogsPage from '@pages/LogsPage'
import NetworkPage from '@pages/NetworkPage'
import SettingsPage from '@pages/SettingsPage'
import NotFoundPage from '@pages/NotFoundPage'

// Styles
import GlobalStyle from '@styles/GlobalStyle'

const App: React.FC = () => {
  useEffect(() => {
    // ダークモードの初期設定
    const savedTheme = localStorage.getItem('lpg-theme') || 'dark'
    document.documentElement.setAttribute('data-color-mode', savedTheme)
  }, [])

  return (
    <Router>
      <AppThemeProvider>
        <ThemeProvider theme={theme} colorMode="auto">
          <BaseStyles>
            <GlobalStyle />
            <AuthProvider>
              <ConfigProvider>
                <Toaster
                  position="top-right"
                  toastOptions={{
                    duration: 4000,
                    style: {
                      background: 'var(--color-canvas-subtle)',
                      color: 'var(--color-fg-default)',
                      border: '1px solid var(--color-border-default)',
                    },
                    success: {
                      iconTheme: {
                        primary: 'var(--color-success-fg)',
                        secondary: 'var(--color-canvas-subtle)',
                      },
                    },
                    error: {
                      iconTheme: {
                        primary: 'var(--color-danger-fg)',
                        secondary: 'var(--color-canvas-subtle)',
                      },
                    },
                  }}
                />
                
                <Routes>
                  {/* ログインページ */}
                  <Route path="/login" element={<LoginPage />} />
                  
                  {/* 保護されたルート */}
                  <Route element={<PrivateRoute />}>
                    <Route element={<Layout />}>
                      {/* ルートパスはドメイン管理へリダイレクト */}
                      <Route path="/" element={<Navigate to="/domains" replace />} />
                      
                      {/* 各管理ページ */}
                      <Route path="/domains" element={<DomainsPage />} />
                      <Route path="/devices" element={<DevicesPage />} />
                      <Route path="/logs" element={<LogsPage />} />
                      <Route path="/network" element={<NetworkPage />} />
                      <Route path="/settings/*" element={<SettingsPage />} />
                    </Route>
                  </Route>
                  
                  {/* 404ページ */}
                  <Route path="*" element={<NotFoundPage />} />
                </Routes>
              </ConfigProvider>
            </AuthProvider>
          </BaseStyles>
        </ThemeProvider>
      </AppThemeProvider>
    </Router>
  )
}

export default App 