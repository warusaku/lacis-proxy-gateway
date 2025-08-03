// TopologyView.tsx - Network Topology Visualization Component
// Version: 1.0.0
// Description: ネットワーク構成を視覚化するトポロジービューコンポーネント

import React, { useRef, useEffect, useState } from 'react'
import {
  Box,
  Card,
  Heading,
  Text,
  Button,
  Octicon,
  Label,
  Tooltip,
} from '@primer/react'
import {
  ServerIcon,
  GlobeIcon,
  ShieldIcon,
  LinkIcon,
  DeviceMobileIcon,
  HomeIcon,
  ToolsIcon,
} from '@primer/octicons-react'
import styled from 'styled-components'

interface NetworkNode {
  id: string
  type: 'gateway' | 'proxy' | 'device' | 'vlan' | 'internet'
  label: string
  ip?: string
  status: 'active' | 'inactive' | 'warning'
  description?: string
  position: { x: number; y: number }
}

interface NetworkLink {
  source: string
  target: string
  type: 'ethernet' | 'wifi' | 'proxy' | 'vlan'
  status: 'active' | 'inactive'
  label?: string
}

const TopologyContainer = styled(Card)`
  padding: 20px;
  min-height: 500px;
  position: relative;
  overflow: hidden;
`

const SVGContainer = styled.svg`
  width: 100%;
  height: 400px;
  border: 1px solid var(--color-border-default);
  border-radius: 6px;
  background: var(--color-canvas-subtle);
`

const NodeElement = styled.g`
  cursor: pointer;
  transition: all 0.2s ease;
  
  &:hover {
    filter: brightness(1.1);
  }
`

const LinkElement = styled.line`
  stroke: var(--color-border-default);
  stroke-width: 2;
  transition: all 0.2s ease;
  
  &.active {
    stroke: var(--color-success-fg);
  }
  
  &.inactive {
    stroke: var(--color-danger-fg);
    stroke-dasharray: 5,5;
  }
`

const LegendContainer = styled(Box)`
  display: flex;
  gap: 16px;
  margin-top: 16px;
  flex-wrap: wrap;
`

const LegendItem = styled(Box)`
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: var(--color-canvas-subtle);
  border: 1px solid var(--color-border-default);
  border-radius: 6px;
  font-size: 12px;
`

const TopologyView: React.FC = () => {
  const [selectedNode, setSelectedNode] = useState<NetworkNode | null>(null)
  const [showLabels, setShowLabels] = useState(true)

  // ネットワークトポロジーの定義（基本仕様書に基づく）
  const nodes: NetworkNode[] = [
    {
      id: 'internet',
      type: 'internet',
      label: 'Internet',
      status: 'active',
      description: 'ISP / WAN',
      position: { x: 300, y: 50 }
    },
    {
      id: 'gateway',
      type: 'gateway',
      label: 'Omada GW',
      ip: '192.168.3.1',
      status: 'active',
      description: 'ER7206 等',
      position: { x: 300, y: 120 }
    },
    {
      id: 'vlan1',
      type: 'vlan',
      label: 'VLAN1',
      ip: '192.168.3.0/24',
      status: 'active',
      description: '管理用VLAN',
      position: { x: 150, y: 200 }
    },
    {
      id: 'vlan555',
      type: 'vlan',
      label: 'VLAN555',
      ip: '192.168.234.0/24',
      status: 'active',
      description: 'lacisstack VLAN',
      position: { x: 450, y: 200 }
    },
    {
      id: 'lpg',
      type: 'proxy',
      label: 'LPG',
      ip: '192.168.234.2',
      status: 'active',
      description: 'Orange Pi Zero 3',
      position: { x: 450, y: 280 }
    },
    {
      id: 'lacisdrawboards',
      type: 'device',
      label: 'LacisDrawBoards',
      ip: '192.168.234.10',
      status: 'active',
      description: 'ホワイトボード',
      position: { x: 350, y: 350 }
    },
    {
      id: 'apiserver',
      type: 'device',
      label: 'API Server',
      ip: '192.168.234.11',
      status: 'active',
      description: 'APIサーバー',
      position: { x: 550, y: 350 }
    }
  ]

  const links: NetworkLink[] = [
    { source: 'internet', target: 'gateway', type: 'ethernet', status: 'active' },
    { source: 'gateway', target: 'vlan1', type: 'vlan', status: 'active', label: 'DNAT 80/443' },
    { source: 'gateway', target: 'vlan555', type: 'vlan', status: 'active' },
    { source: 'vlan555', target: 'lpg', type: 'ethernet', status: 'active' },
    { source: 'lpg', target: 'lacisdrawboards', type: 'proxy', status: 'active', label: ':8080' },
    { source: 'lpg', target: 'apiserver', type: 'proxy', status: 'active', label: ':3000' }
  ]

  const getNodeIcon = (type: string) => {
    switch (type) {
      case 'internet': return GlobeIcon
      case 'gateway': return ShieldIcon
      case 'proxy': return ServerIcon
      case 'device': return DeviceMobileIcon
      case 'vlan': return HomeIcon
      default: return ServerIcon
    }
  }

  const getNodeColor = (status: string) => {
    switch (status) {
      case 'active': return 'var(--color-success-fg)'
      case 'warning': return 'var(--color-attention-fg)'
      case 'inactive': return 'var(--color-danger-fg)'
      default: return 'var(--color-fg-default)'
    }
  }

  const getNodeBgColor = (status: string) => {
    switch (status) {
      case 'active': return 'var(--color-success-subtle)'
      case 'warning': return 'var(--color-attention-subtle)'
      case 'inactive': return 'var(--color-danger-subtle)'
      default: return 'var(--color-canvas-default)'
    }
  }

  return (
    <TopologyContainer>
      <Box display="flex" justifyContent="between" alignItems="center" mb={3}>
        <Heading as="h3" sx={{ fontSize: 2 }}>
          ネットワークトポロジー
        </Heading>
        <Box display="flex" gap={2}>
          <Button
            size="small"
            variant={showLabels ? 'primary' : 'default'}
            onClick={() => setShowLabels(!showLabels)}
          >
            {showLabels ? 'ラベル非表示' : 'ラベル表示'}
          </Button>
        </Box>
      </Box>

      <SVGContainer>
        {/* 接続線 */}
        <g>
          {links.map((link, index) => {
            const sourceNode = nodes.find(n => n.id === link.source)
            const targetNode = nodes.find(n => n.id === link.target)
            if (!sourceNode || !targetNode) return null

            return (
              <g key={index}>
                <LinkElement
                  x1={sourceNode.position.x}
                  y1={sourceNode.position.y}
                  x2={targetNode.position.x}
                  y2={targetNode.position.y}
                  className={link.status}
                />
                {showLabels && link.label && (
                  <text
                    x={(sourceNode.position.x + targetNode.position.x) / 2}
                    y={(sourceNode.position.y + targetNode.position.y) / 2 - 5}
                    textAnchor="middle"
                    fontSize="10"
                    fill="var(--color-fg-muted)"
                  >
                    {link.label}
                  </text>
                )}
              </g>
            )
          })}
        </g>

        {/* ノード */}
        <g>
          {nodes.map((node) => (
            <NodeElement
              key={node.id}
              onClick={() => setSelectedNode(node)}
            >
              {/* ノード背景 */}
              <circle
                cx={node.position.x}
                cy={node.position.y}
                r="20"
                fill={getNodeBgColor(node.status)}
                stroke={getNodeColor(node.status)}
                strokeWidth="2"
              />
              
              {/* ノードアイコン（簡易表示） */}
              <text
                x={node.position.x}
                y={node.position.y + 3}
                textAnchor="middle"
                fontSize="12"
                fill={getNodeColor(node.status)}
              >
                {node.type === 'internet' ? '🌐' :
                 node.type === 'gateway' ? '🛡️' :
                 node.type === 'proxy' ? '🖥️' :
                 node.type === 'device' ? '📱' :
                 node.type === 'vlan' ? '🏠' : '⚙️'}
              </text>

              {/* ノードラベル */}
              {showLabels && (
                <text
                  x={node.position.x}
                  y={node.position.y + 35}
                  textAnchor="middle"
                  fontSize="11"
                  fill="var(--color-fg-default)"
                  fontWeight="500"
                >
                  {node.label}
                </text>
              )}
              
              {/* IPアドレス */}
              {showLabels && node.ip && (
                <text
                  x={node.position.x}
                  y={node.position.y + 48}
                  textAnchor="middle"
                  fontSize="9"
                  fill="var(--color-fg-muted)"
                >
                  {node.ip}
                </text>
              )}
            </NodeElement>
          ))}
        </g>
      </SVGContainer>

      {/* 凡例 */}
      <LegendContainer>
        <LegendItem>
          <Box as="span" sx={{ fontSize: 0 }}>🌐</Box>
          <Text fontSize={0}>Internet</Text>
        </LegendItem>
        <LegendItem>
          <Box as="span" sx={{ fontSize: 0 }}>🛡️</Box>
          <Text fontSize={0}>Gateway</Text>
        </LegendItem>
        <LegendItem>
          <Box as="span" sx={{ fontSize: 0 }}>🖥️</Box>
          <Text fontSize={0}>Proxy</Text>
        </LegendItem>
        <LegendItem>
          <Box as="span" sx={{ fontSize: 0 }}>📱</Box>
          <Text fontSize={0}>Device</Text>
        </LegendItem>
        <LegendItem>
          <Box as="span" sx={{ fontSize: 0 }}>🏠</Box>
          <Text fontSize={0}>VLAN</Text>
        </LegendItem>
        <LegendItem>
          <Box 
            as="span" 
            sx={{ 
              width: '12px', 
              height: '2px', 
              backgroundColor: 'success.fg',
              display: 'inline-block'
            }}
          />
          <Text fontSize={0}>アクティブ</Text>
        </LegendItem>
        <LegendItem>
          <Box 
            as="span" 
            sx={{ 
              width: '12px', 
              height: '2px', 
              backgroundColor: 'danger.fg',
              display: 'inline-block',
              borderStyle: 'dashed'
            }}
          />
          <Text fontSize={0}>非アクティブ</Text>
        </LegendItem>
      </LegendContainer>

      {/* 選択ノード詳細 */}
      {selectedNode && (
        <Box 
          sx={{
            position: 'absolute',
            top: '20px',
            right: '20px',
            width: '200px',
            p: 3,
            bg: 'canvas.default',
            border: '1px solid',
            borderColor: 'border.default',
            borderRadius: 2,
            boxShadow: 'shadow.medium'
          }}
        >
          <Box display="flex" justifyContent="between" alignItems="start" mb={2}>
            <Heading as="h4" fontSize={1}>{selectedNode.label}</Heading>
            <Button
              size="small"
              variant="invisible"
              onClick={() => setSelectedNode(null)}
            >
              ×
            </Button>
          </Box>
          
          {selectedNode.ip && (
            <Box mb={2}>
              <Text fontSize={0} color="fg.muted">IP Address</Text>
              <Text fontSize={1} fontFamily="mono">{selectedNode.ip}</Text>
            </Box>
          )}
          
          <Box mb={2}>
            <Text fontSize={0} color="fg.muted">Status</Text>
            <Label variant={selectedNode.status === 'active' ? 'success' : 'danger'}>
              {selectedNode.status === 'active' ? 'アクティブ' : '非アクティブ'}
            </Label>
          </Box>
          
          {selectedNode.description && (
            <Box>
              <Text fontSize={0} color="fg.muted">Description</Text>
              <Text fontSize={1}>{selectedNode.description}</Text>
            </Box>
          )}
        </Box>
      )}
    </TopologyContainer>
  )
}

export default TopologyView