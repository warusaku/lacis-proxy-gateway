// ConfigContext.tsx - Configuration Context
// Version: 1.0.0
// Description: 設定管理コンテキスト

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react'
import { configAPI } from '@services/api'
import toast from 'react-hot-toast'

interface LPGConfig {
  hostdomains: Record<string, string>
  hostingdevice: Record<string, Record<string, Route>>
  adminuser: Record<string, string>
  endpoint: {
    logserver: string
  }
  options: Record<string, any>
  metadata?: {
    version: string
    revision: number
    updated_at: string
    updated_by: string
  }
}

interface Route {
  deviceip: string
  port: number[]
  sitename: string
  ips: string[]
}

interface ConfigContextType {
  config: LPGConfig | null
  isLoading: boolean
  error: string | null
  refreshConfig: () => Promise<void>
  updateConfig: (newConfig: LPGConfig) => Promise<void>
  deployConfig: () => Promise<void>
  rollbackConfig: (version: number) => Promise<void>
}

const ConfigContext = createContext<ConfigContextType | undefined>(undefined)

export const useConfig = () => {
  const context = useContext(ConfigContext)
  if (!context) {
    throw new Error('useConfig must be used within a ConfigProvider')
  }
  return context
}

interface ConfigProviderProps {
  children: ReactNode
}

export const ConfigProvider: React.FC<ConfigProviderProps> = ({ children }) => {
  const [config, setConfig] = useState<LPGConfig | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // 設定を取得
  const fetchConfig = async () => {
    try {
      setIsLoading(true)
      setError(null)
      const response = await configAPI.get()
      setConfig(response.data)
    } catch (err: any) {
      setError(err.message || '設定の取得に失敗しました')
      console.error('設定取得エラー:', err)
    } finally {
      setIsLoading(false)
    }
  }

  // 初回読み込み
  useEffect(() => {
    fetchConfig()
  }, [])

  // 設定をリフレッシュ
  const refreshConfig = async () => {
    await fetchConfig()
  }

  // 設定を更新
  const updateConfig = async (newConfig: LPGConfig) => {
    try {
      setIsLoading(true)
      setError(null)
      
      // 設定を検証
      const validationResponse = await configAPI.validate(newConfig)
      if (!validationResponse.data.valid) {
        throw new Error(validationResponse.data.errors?.join(', ') || '設定の検証に失敗しました')
      }

      // 設定を更新
      await configAPI.update(newConfig)
      
      // 更新後の設定を再取得
      await fetchConfig()
      
      toast.success('設定を更新しました')
    } catch (err: any) {
      setError(err.message || '設定の更新に失敗しました')
      toast.error(err.message || '設定の更新に失敗しました')
      throw err
    } finally {
      setIsLoading(false)
    }
  }

  // 設定をデプロイ
  const deployConfig = async () => {
    try {
      setIsLoading(true)
      setError(null)
      
      await configAPI.deploy()
      
      toast.success('設定を適用しました')
    } catch (err: any) {
      setError(err.message || '設定の適用に失敗しました')
      toast.error(err.message || '設定の適用に失敗しました')
      throw err
    } finally {
      setIsLoading(false)
    }
  }

  // 設定をロールバック
  const rollbackConfig = async (version: number) => {
    try {
      setIsLoading(true)
      setError(null)
      
      await configAPI.rollback(version)
      
      // ロールバック後の設定を再取得
      await fetchConfig()
      
      toast.success(`バージョン ${version} にロールバックしました`)
    } catch (err: any) {
      setError(err.message || 'ロールバックに失敗しました')
      toast.error(err.message || 'ロールバックに失敗しました')
      throw err
    } finally {
      setIsLoading(false)
    }
  }

  const value: ConfigContextType = {
    config,
    isLoading,
    error,
    refreshConfig,
    updateConfig,
    deployConfig,
    rollbackConfig,
  }

  return <ConfigContext.Provider value={value}>{children}</ConfigContext.Provider>
}

export default ConfigContext 