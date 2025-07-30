// ThemeContext.tsx - Theme Context
// Version: 1.0.0
// Description: テーマコンテキスト

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react'

type ColorMode = 'light' | 'dark' | 'auto'

interface ThemeContextType {
  colorMode: ColorMode
  setColorMode: (mode: ColorMode) => void
  resolvedColorMode: 'light' | 'dark'
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined)

export const useTheme = () => {
  const context = useContext(ThemeContext)
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider')
  }
  return context
}

interface ThemeProviderProps {
  children: ReactNode
}

export const ThemeProvider: React.FC<ThemeProviderProps> = ({ children }) => {
  const [colorMode, setColorMode] = useState<ColorMode>(() => {
    const saved = localStorage.getItem('lpg-color-mode')
    return (saved as ColorMode) || 'auto'
  })

  const [systemPreference, setSystemPreference] = useState<'light' | 'dark'>(() => {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  })

  // システムのカラーモード設定を監視
  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    
    const handleChange = (e: MediaQueryListEvent) => {
      setSystemPreference(e.matches ? 'dark' : 'light')
    }

    mediaQuery.addEventListener('change', handleChange)
    return () => mediaQuery.removeEventListener('change', handleChange)
  }, [])

  // 実際に適用されるカラーモード
  const resolvedColorMode: 'light' | 'dark' = 
    colorMode === 'auto' ? systemPreference : colorMode

  // カラーモードをDOMに適用
  useEffect(() => {
    document.documentElement.setAttribute('data-color-mode', resolvedColorMode)
    
    // Primer CSSのカラースキームも更新
    const colorScheme = resolvedColorMode === 'dark' ? 'dark' : 'light'
    document.documentElement.style.colorScheme = colorScheme
  }, [resolvedColorMode])

  // カラーモードを設定
  const handleSetColorMode = (mode: ColorMode) => {
    setColorMode(mode)
    localStorage.setItem('lpg-color-mode', mode)
  }

  const value: ThemeContextType = {
    colorMode,
    setColorMode: handleSetColorMode,
    resolvedColorMode,
  }

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

export default ThemeContext 