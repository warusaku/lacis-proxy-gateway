// main.tsx - Application Entry Point
// Version: 1.0.0
// Description: LacisProxyGateway管理UIのエントリーポイント

import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

// グローバルスタイルのインポート
import '@primer/react/index.css'

// React 18のルート作成
ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
) 