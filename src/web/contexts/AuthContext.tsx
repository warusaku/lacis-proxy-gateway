// AuthContext.tsx - Authentication Context
// Version: 1.0.0
// Description: 認証コンテキスト

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { authAPI } from '@services/api'
import toast from 'react-hot-toast'

interface User {
  username: string
  role?: string
}

interface AuthContextType {
  user: User | null
  isAuthenticated: boolean
  isLoading: boolean
  login: (username: string, password: string) => Promise<void>
  logout: () => Promise<void>
  changePassword: (currentPassword: string, newPassword: string) => Promise<void>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export const useAuth = () => {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}

interface AuthProviderProps {
  children: ReactNode
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const navigate = useNavigate()

  // トークンからユーザー情報を復元
  useEffect(() => {
    const initAuth = async () => {
      const token = localStorage.getItem('lpg-token')
      if (token) {
        try {
          // トークンをデコードしてユーザー情報を取得
          const payload = JSON.parse(atob(token.split('.')[1]))
          
          // トークンの有効期限をチェック
          if (payload.exp * 1000 > Date.now()) {
            setUser({ username: payload.username, role: payload.role })
          } else {
            // 期限切れの場合はリフレッシュを試みる
            try {
              await authAPI.refreshToken()
              setUser({ username: payload.username, role: payload.role })
            } catch {
              localStorage.removeItem('lpg-token')
            }
          }
        } catch (error) {
          console.error('トークンの解析に失敗しました:', error)
          localStorage.removeItem('lpg-token')
        }
      }
      setIsLoading(false)
    }

    initAuth()
  }, [])

  const login = async (username: string, password: string) => {
    try {
      const response = await authAPI.login(username, password)
      const { token } = response
      
      // トークンからユーザー情報を取得
      const payload = JSON.parse(atob(token.split('.')[1]))
      setUser({ username: payload.username, role: payload.role })
      
      toast.success('ログインしました')
      navigate('/domains')
    } catch (error: any) {
      if (error.response?.status === 401) {
        throw new Error('ユーザー名またはパスワードが正しくありません')
      }
      throw new Error('ログインに失敗しました')
    }
  }

  const logout = async () => {
    try {
      await authAPI.logout()
    } catch (error) {
      console.error('ログアウトエラー:', error)
    } finally {
      setUser(null)
      localStorage.removeItem('lpg-token')
      toast.success('ログアウトしました')
      navigate('/login')
    }
  }

  const changePassword = async (currentPassword: string, newPassword: string) => {
    try {
      await authAPI.changePassword(currentPassword, newPassword)
      toast.success('パスワードを変更しました')
    } catch (error: any) {
      if (error.response?.status === 401) {
        throw new Error('現在のパスワードが正しくありません')
      }
      throw new Error('パスワードの変更に失敗しました')
    }
  }

  const value: AuthContextType = {
    user,
    isAuthenticated: !!user,
    isLoading,
    login,
    logout,
    changePassword,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export default AuthContext 