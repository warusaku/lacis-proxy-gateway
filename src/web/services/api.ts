// api.ts - API Client Service
// Version: 1.0.0
// Description: APIクライアントサービス

import axios, { AxiosInstance, AxiosError, InternalAxiosRequestConfig } from 'axios'
import toast from 'react-hot-toast'

// API基本設定
const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://localhost:8443/api/v1'
const API_TIMEOUT = 30000

// APIクライアントインスタンス
const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: API_TIMEOUT,
  headers: {
    'Content-Type': 'application/json',
  },
})

// トークン管理
const tokenManager = {
  getToken: (): string | null => {
    return localStorage.getItem('lpg-token')
  },
  
  setToken: (token: string): void => {
    localStorage.setItem('lpg-token', token)
  },
  
  removeToken: (): void => {
    localStorage.removeItem('lpg-token')
  },
  
  getRefreshToken: (): string | null => {
    return localStorage.getItem('lpg-refresh-token')
  },
  
  setRefreshToken: (token: string): void => {
    localStorage.setItem('lpg-refresh-token', token)
  },
}

// リクエストインターセプター
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = tokenManager.getToken()
    if (token && config.headers) {
      config.headers['Authorization'] = `Bearer ${token}`
    }
    return config
  },
  (error: AxiosError) => {
    return Promise.reject(error)
  }
)

// レスポンスインターセプター
apiClient.interceptors.response.use(
  (response) => {
    return response
  },
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean }

    // 401エラーでトークンリフレッシュを試みる
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true

      try {
        const refreshToken = tokenManager.getRefreshToken()
        if (refreshToken) {
          const response = await axios.post(`${API_BASE_URL}/auth/refresh`, {
            refresh_token: refreshToken,
          })

          const { token, refresh_token } = response.data
          tokenManager.setToken(token)
          if (refresh_token) {
            tokenManager.setRefreshToken(refresh_token)
          }

          // 元のリクエストを再実行
          if (originalRequest.headers) {
            originalRequest.headers['Authorization'] = `Bearer ${token}`
          }
          return apiClient(originalRequest)
        }
      } catch (refreshError) {
        // リフレッシュ失敗時はログイン画面へ
        tokenManager.removeToken()
        window.location.href = '/login'
        return Promise.reject(refreshError)
      }
    }

    // エラーメッセージの表示
    if (error.response) {
      const errorMessage = error.response.data?.error || 'エラーが発生しました'
      
      // 特定のステータスコードに対する処理
      switch (error.response.status) {
        case 400:
          toast.error(`入力エラー: ${errorMessage}`)
          break
        case 403:
          toast.error('権限がありません')
          break
        case 404:
          toast.error('リソースが見つかりません')
          break
        case 500:
          toast.error('サーバーエラーが発生しました')
          break
        default:
          toast.error(errorMessage)
      }
    } else if (error.request) {
      toast.error('ネットワークエラーが発生しました')
    } else {
      toast.error('予期せぬエラーが発生しました')
    }

    return Promise.reject(error)
  }
)

// 認証API
export const authAPI = {
  login: async (username: string, password: string) => {
    const response = await apiClient.post('/auth/login', { username, password })
    const { token, expires_in } = response.data
    tokenManager.setToken(token)
    return response.data
  },

  logout: async () => {
    await apiClient.post('/auth/logout')
    tokenManager.removeToken()
  },

  changePassword: async (currentPassword: string, newPassword: string) => {
    return apiClient.put('/auth/password', {
      current_password: currentPassword,
      new_password: newPassword,
    })
  },

  refreshToken: async () => {
    const response = await apiClient.post('/auth/refresh')
    const { token } = response.data
    tokenManager.setToken(token)
    return response.data
  },
}

// 設定管理API
export const configAPI = {
  get: async () => {
    return apiClient.get('/config')
  },

  update: async (config: any) => {
    return apiClient.put('/config', config)
  },

  deploy: async () => {
    return apiClient.post('/config/deploy')
  },

  rollback: async (version: number) => {
    return apiClient.post('/config/rollback', { version })
  },

  getHistory: async () => {
    return apiClient.get('/config/history')
  },

  validate: async (config: any) => {
    return apiClient.post('/config/validate', config)
  },

  export: async () => {
    return apiClient.get('/config/export', {
      responseType: 'blob',
    })
  },

  import: async (config: any) => {
    return apiClient.post('/config/import', config)
  },
}

// ドメイン管理API
export const domainsAPI = {
  list: async (includeRoutes = false) => {
    return apiClient.get('/domains', {
      params: { include_routes: includeRoutes },
    })
  },

  get: async (domain: string) => {
    return apiClient.get(`/domains/${domain}`)
  },

  create: async (domain: string, subnet: string) => {
    return apiClient.post('/domains', { domain, subnet })
  },

  update: async (domain: string, subnet: string) => {
    return apiClient.put(`/domains/${domain}`, { subnet })
  },

  delete: async (domain: string) => {
    return apiClient.delete(`/domains/${domain}`)
  },
}

// ルーティング管理API
export const routesAPI = {
  list: async (domain?: string) => {
    return apiClient.get('/routes', {
      params: domain ? { domain } : undefined,
    })
  },

  get: async (domain: string, path: string) => {
    return apiClient.get(`/domains/${domain}/routes/${path}`)
  },

  create: async (domain: string, route: any) => {
    return apiClient.post(`/domains/${domain}/routes`, route)
  },

  update: async (domain: string, path: string, route: any) => {
    return apiClient.put(`/domains/${domain}/routes/${path}`, route)
  },

  delete: async (domain: string, path: string) => {
    return apiClient.delete(`/domains/${domain}/routes/${path}`)
  },

  testConnection: async (deviceIP: string, port?: number) => {
    return apiClient.post('/routes/test', { device_ip: deviceIP, port })
  },
}

// システム情報API
export const systemAPI = {
  getInfo: async () => {
    return apiClient.get('/system/info')
  },

  getMetrics: async () => {
    return apiClient.get('/system/metrics')
  },

  getNetwork: async () => {
    return apiClient.get('/system/network')
  },

  getLogs: async (limit = 100) => {
    return apiClient.get('/system/logs', {
      params: { limit },
    })
  },

  getHealth: async (detailed = false) => {
    return apiClient.get('/health', {
      params: { detailed },
    })
  },

  getVersion: async () => {
    return apiClient.get('/version')
  },
}

export default apiClient 