# 文件传输模块使用指南

## 概述

本模块为 OpenHarmony 多终端推理框架提供了**可扩展的混合协议文件传输解决方案**，支持 MQTT 和 TCP 两种传输协议，自动根据文件大小选择最优传输方式。

## 核心特性

### ✅ 1. 开放性协议集成接口
- **标准化接口**: `TransferProtocolInterface` 定义了 send、receive、connect、disconnect、isConnected 等标准方法
- **协议注册中心**: `ProtocolRegistry` 支持动态注册和管理不同传输协议
- **易于扩展**: 用户无需修改核心代码即可轻松集成新的传输协议（如 HTTP、WebSocket 等）

### ✅ 2. 数据传输协议自适应选择
- **智能判断**: 自动检测文件大小（阈值可配置，默认 2MB）
- **自动切换**: 
  - ≤2MB 的文件 → 使用 MQTT协议直接传输
  - >2MB 的文件 → 使用 TCP 协议分块传输
- **透明处理**: 调用方无需关心底层协议细节

### ✅ 3. TCP 大文件传输实现
- **分块传输**: 128KB 分块大小（可配置），优化大文件传输性能
- **断点续传**: 支持失败分块自动重试（最多 3 次）
- **哈希校验**: SHA-256 文件完整性验证
- **进度跟踪**: 实时传输进度监控

### ✅ 4. 文件传输管理器
- **统一管理**: `FileTransferManager` 提供一站式文件传输管理
- **状态管理**: IDLE、CONNECTING、TRANSFERRING、COMPLETED、FAILED
- **功能丰富**: 传输进度监控、任务取消、状态查询
- **网络集成**: 自动获取设备 IP 地址用于 TCP 连接

### ✅ 5. 完善的错误处理与恢复
- **超时检测**: 30 秒连接超时（可配置）
- **自动重试**: 失败任务自动重试机制
- **资源回收**: 传输完成后自动清理资源
- **异常安全**: 完善的 try-catch-finally 保护

## 模块架构

```
transfer/
├── protocol/                    # 协议层
│   ├── TransferProtocolInterface.ets  # 协议接口定义
│   ├── ProtocolRegistry.ets           # 协议注册中心
│   ├── MQTTTransferProtocol.ets       # MQTT协议实现
│   └── TCPTransferProtocol.ets        # TCP 协议实现
├── socket/                      # Socket 层
│   └── FileTransferSocketManager.ets  # TCP Socket 管理器
├── model/                       # 数据模型
│   └── TransferDataModels.ets         # 数据传输对象
├── utils/                       # 工具类
│   ├── FileUtils.ets                  # 文件处理工具
│   └── NetworkUtils.ets               # 网络工具
├── event/                       # 事件系统
│   └── TransferEvents.ets             # 传输事件定义
├── FileTransferManager.ets      # 核心管理器
└── index.ets                    # 统一导出
```

## 快速开始

### 1. 基本使用（小文件传输）

```typescript
import { FileTransferManager, FileInfo, FileUtils } from '../manager/transfer/index';

async function transferSmallFile() {
  const transferManager = FileTransferManager.getInstance();
  
  // 准备文件数据（1KB 图片）
  const fileData = new ArrayBuffer(1024);
  const fileInfo: FileInfo = {
    fileId: FileUtils.generateFileId(),
    fileName: 'test_image.jpg',
    size: fileData.byteLength,
    fileType: 'image/jpeg'
  };
  
  // 发起传输（自动使用 MQTT协议）
  const taskId = await transferManager.transferFile(fileData, fileInfo, 'target_device');
  console.info(`传输完成，taskId=${taskId}`);
}
```

### 2. 大文件传输（自动 TCP）

```typescript
async function transferLargeFile() {
  const transferManager = FileTransferManager.getInstance();
  
  // 准备大文件（3MB 模型文件）
  const largeFileData = new ArrayBuffer(3 * 1024 * 1024);
  const fileInfo: FileInfo = {
    fileId: FileUtils.generateFileId(),
    fileName: 'model.ms',
    size: largeFileData.byteLength
  };
  
  // 发起传输（自动使用 TCP 协议）
  const taskId = await transferManager.transferFile(largeFileData, fileInfo, 'device_B');
  console.info(`大文件传输已启动，使用 TCP 协议，taskId=${taskId}`);
}
```

### 3. 自定义配置

```typescript
// 设置自定义传输配置
transferManager.setDefaultOptions({
  sizeThreshold: 1 * 1024 * 1024,  // 1MB 阈值
  tcpChunkSize: 64 * 1024,         // 64KB 分块
  maxRetries: 5,                   // 最多重试 5 次
  timeout: 60000,                  // 60 秒超时
  tcpPort: 9999                    // TCP 监听端口
});
```

### 4. 进度监控与任务管理

```typescript
// 查询进度
const progress = transferManager.getTransferProgress(taskId);
console.info(`传输进度：${progress.progress}%`);

// 获取状态
const state = transferManager.getTransferState(taskId);
console.info(`当前状态：${state}`);

// 取消任务
await transferManager.cancelTransfer(taskId);

// 查看活动任务
const activeTasks = transferManager.getActiveTasks();
activeTasks.forEach(task => {
  console.info(`任务 ${task.taskId}: ${task.state}`);
});
```

### 5. 文件处理工具

```typescript
import { FileUtils } from '../manager/transfer/index';

// 计算文件哈希
const hash = await FileUtils.calculateHash(fileData);
console.info(`文件哈希：${hash}`);

// 验证哈希
const isValid = await FileUtils.verifyHash(fileData, hash);

// 文件分块
const chunks = FileUtils.chunkFile(fileData, 128 * 1024, taskId);

// 文件重组
const reassembled = FileUtils.reassembleChunks(chunks);

// 格式转换
const base64 = FileUtils.arrayBufferToBase64(buffer);
const buffer = FileUtils.base64ToArrayBuffer(base64);
```

## 高级用法

### 1. 注册自定义协议

```typescript
import { TransferProtocolInterface } from '../manager/transfer/index';

// 实现自定义协议
class CustomProtocol implements TransferProtocolInterface {
  getProtocolName(): string { return 'CUSTOM'; }
  async connect(host: string, port: number): Promise<boolean> { /* ... */ }
  async disconnect(): Promise<boolean> { /* ... */ }
  isConnected(): boolean { /* ... */ }
  async send(data: ArrayBuffer, taskId: string): Promise<boolean> { /* ... */ }
  async receive(taskId: string): Promise<ArrayBuffer> { /* ... */ }
  getProgress(taskId: string): TransferProgress { /* ... */ }
  async cancel(taskId: string): Promise<boolean> { /* ... */ }
}

// 注册协议
const customProtocol = new CustomProtocol();
transferManager.registerCustomProtocol('CUSTOM', customProtocol);
```

### 2. 与 TaskDispatch 集成

TaskDispatch 已自动集成文件传输功能：

```typescript
// TaskDispatch 会自动判断文件大小并选择合适的协议
const taskDispatch = new TaskDispatch();

const taskInfo = {
  taskId: 'task_001',
  fromClient: 'device_A',
  toClient: 'device_B',
  params: { /* ... */ },
  sourceIp: '192.168.1.100',  // TCP 传输时需要
  transferType: 'tcp'          // 自动设置
};

// 发送任务（大文件会自动走 TCP）
await taskDispatch.sendTask(taskInfo);
```

## 配置参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `sizeThreshold` | 2MB | 文件大小阈值，超过此值使用 TCP |
| `tcpChunkSize` | 128KB | TCP 分块大小 |
| `maxRetries` | 3 | 最大重试次数 |
| `timeout` | 30000ms | 连接超时时间 |
| `tcpPort` | 8888 | TCP 监听端口 |

## 传输流程图

```
发起传输
    ↓
判断文件大小
    ↓
≤2MB? ──是──→ MQTT协议 ──→ 直接发送
    │
   否
    ↓
TCP 协议
    ↓
获取本机 IP ──→ 启动服务器监听
    ↓
通过 MQTT 通知目标设备（包含 sourceIp）
    ↓
目标设备发起 TCP 连接
    ↓
分块传输文件（128KB/块）
    ↓
哈希校验
    ↓
传输完成
```

## 最佳实践

### 1. 性能优化
- 对于频繁的小文件传输，保持默认 2MB 阈值
- 对于稳定的 WiFi 环境，可以增大分块大小到 256KB
- 对于不稳定的网络，增加重试次数到 5 次

### 2. 内存管理
- 大文件传输时注意内存占用
- 及时清理已完成的任务：`transferManager.cleanupCompletedTasks()`
- 避免同时发起过多大文件传输任务

### 3. 错误处理
```typescript
try {
  const taskId = await transferManager.transferFile(data, info, target);
  const progress = await waitForCompletion(taskId);
  
  if (progress.state === 'completed') {
    console.info('传输成功');
  } else {
    console.error('传输失败:', progress.error);
  }
} catch (error) {
  console.error('传输异常:', error);
  // 实现重试逻辑或其他处理
}
```

## 注意事项

1. **权限要求**: 需要网络访问权限和 WiFi 状态读取权限
2. **端口占用**: 确保 TCP 端口（默认 8888）未被占用
3. **防火墙**: 确保设备间可以互相访问指定端口
4. **内存限制**: 大文件传输时注意设备内存限制
5. **连接管理**: 传输完成后及时关闭 TCP 连接

## 示例代码

完整示例请参考：
- `entry/src/main/ets/manager/transfer/examples/TransferExamples.ets`

## 后续开发计划

- [ ] 完善 TCP 握手机制的完整实现
- [ ] 添加更多传输协议（HTTP、WebSocket）
- [ ] 支持并发传输和优先级队列
- [ ] 添加传输历史记录和统计功能
- [ ] 优化弱网环境下的传输性能

## 技术支持

如有问题或建议，请联系开发团队。
