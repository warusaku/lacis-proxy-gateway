// PrivateRoute.tsx - Private Route Component
// Version: 1.0.0
// Description: 認証が必要なルートを保護するコンポーネント

import React from 'react'
import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '@contexts/AuthContext'
import { Spinner, Box } from '@primer/react'

const PrivateRoute: React.FC = () => {
  const { isAuthenticated, isLoading } = useAuth()
  const location = useLocation()

  // ローディング中
  if (isLoading) {
    return (
      <Box
        display="flex"
        alignItems="center"
        justifyContent="center"
        height="100vh"
        backgroundColor="canvas.default"
      >
        <Spinner size="large" />
      </Box>
    )
  }

  // 未認証の場合はログインページへリダイレクト
  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />
  }

  // 認証済みの場合は子コンポーネントを表示
  return <Outlet />
}

export default PrivateRoute 