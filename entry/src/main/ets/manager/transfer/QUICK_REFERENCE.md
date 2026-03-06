# 文件传输模块 - 快速参考卡

## 📦 核心 API

### FileTransferManager (单例)
```typescript
import { FileTransferManager } from './manager/transfer/index';

const manager = FileTransferManager.getInstance();

// 发起传输
const taskId = await manager.transferFile(fileData, fileInfo, targetDevice);

// 查询进度
const progress = manager.getTransferProgress(taskId);

// 取消任务
await manager.cancelTransfer(taskId);

// 配置选项
manager.setDefaultOptions({
  sizeThreshold: 2 * 1024 * 1024,  // 2MB
  tcpChunkSize: 128 * 1024,        // 128KB
  maxRetries: 3,
  timeout: 30000,
  tcpPort: 8888
});
```

## 🔧 工具函数

### FileUtils
```typescript
import { FileUtils } from './manager/transfer/utils/FileUtils';

// 分块
const chunks = FileUtils.chunkFile(data, 128*1024, taskId);

// 重组
const reassembled = FileUtils.reassembleChunks(chunks);

// 哈希
const hash = await FileUtils.calculateHash(data);
const valid = await FileUtils.verifyHash(data, hash);

// 转换
const base64 = FileUtils.arrayBufferToBase64(buffer);
const buffer = FileUtils.base64ToArrayBuffer(base64);

// ID 生成
const fileId = FileUtils.generateFileId();
```

### NetworkUtils
```typescript
import { NetworkUtils } from './manager/transfer/utils/NetworkUtils';

const ip = NetworkUtils.getIpAddress();
const connected = NetworkUtils.isNetworkConnected();
const valid = NetworkUtils.isValidIpAddress('192.168.1.1');
const port = NetworkUtils.validatePort(8888, 9999);
```

## 📊 协议注册

```typescript
import { ProtocolRegistry } from './manager/transfer/protocol/ProtocolRegistry';

const registry = ProtocolRegistry.getInstance();

// 注册协议
registry.registerProtocol('CUSTOM', customProtocol);

// 获取协议
const protocol = registry.getProtocol('CUSTOM');

// 列出协议
const protocols = registry.listProtocols();

// 注销协议
registry.unregisterProtocol('CUSTOM');
```

## 🎯 事件监听

```typescript
import { TransferEventManager, TransferEventId } from './manager/transfer/event/TransferEvents';

const eventManager = TransferEventManager.getInstance();

// 监听
eventManager.on(TransferEventId.TRANSFER_PROGRESS, (eventData) => {
  console.info(`进度：${eventData.data.progress}%`);
});

// 发送事件
eventManager.emit(TransferEventId.TRANSFER_COMPLETE, taskId, { result: 'success' });

// 移除监听
eventManager.off(TransferEventId.TRANSFER_PROGRESS);
```

## 🔌 协议接口

```typescript
import { TransferProtocolInterface } from './manager/transfer/protocol/TransferProtocolInterface';

class MyProtocol implements TransferProtocolInterface {
  getProtocolName(): string { return 'MY_PROTOCOL'; }
  
  async connect(host: string, port: number): Promise<boolean> { /* ... */ }
  async disconnect(): Promise<boolean> { /* ... */ }
  isConnected(): boolean { /* ... */ }
  
  async send(data: ArrayBuffer, taskId: string): Promise<boolean> { /* ... */ }
  async receive(taskId: string): Promise<ArrayBuffer> { /* ... */ }
  
  getProgress(taskId: string): TransferProgress { /* ... */ }
  async cancel(taskId: string): Promise<boolean> { /* ... */ }
}
```

## 💡 常用模式

### 1. 小文件传输 (< 2MB)
```typescript
const smallFile = new ArrayBuffer(1024);
const taskId = await manager.transferFile(smallFile, fileInfo, 'device_A');
// 自动使用 MQTT协议
```

### 2. 大文件传输 (> 2MB)
```typescript
const largeFile = new ArrayBuffer(5 * 1024 * 1024);
const taskId = await manager.transferFile(largeFile, fileInfo, 'device_B');
// 自动使用 TCP 协议（分块传输）
```

### 3. 进度监控
```typescript
const taskId = await manager.transferFile(data, info, target);

// 轮询进度
const interval = setInterval(() => {
  const progress = manager.getTransferProgress(taskId);
  console.info(`${progress.progress}%`);
  
  if (progress.state === 'completed') {
    clearInterval(interval);
  }
}, 1000);
```

### 4. 批量传输
```typescript
const files = [file1, file2, file3];
const tasks = await Promise.all(
  files.map(f => manager.transferFile(f.data, f.info, target))
);
```

### 5. 错误处理
```typescript
try {
  const taskId = await manager.transferFile(data, info, target);
  const progress = await waitForCompletion(taskId);
  
  if (progress.state !== 'completed') {
    throw new Error(progress.error || '传输失败');
  }
} catch (error) {
  console.error('传输异常:', error);
  // 重试或其他处理
}
```

## ⚙️ 配置速查

| 参数 | 默认值 | 说明 | 建议调整场景 |
|------|--------|------|-------------|
| `sizeThreshold` | 2MB | MQTT/TCP切换阈值 | 频繁大文件可降至 1MB |
| `tcpChunkSize` | 128KB | TCP 分块大小 | WiFi 好可增至 256KB |
| `maxRetries` | 3 | 最大重试次数 | 网络差可增至 5-7 次 |
| `timeout` | 30s | 连接超时 | 远距离可增至 60s |
| `tcpPort` | 8888 | TCP 监听端口 | 冲突时更换 |

## 🚨 常见问题

### Q1: 如何更改协议切换阈值？
```typescript
manager.setDefaultOptions({ sizeThreshold: 1 * 1024 * 1024 });
```

### Q2: 如何查看当前活动任务？
```typescript
const tasks = manager.getActiveTasks();
tasks.forEach(t => console.info(t.taskId, t.state));
```

### Q3: 如何清理已完成任务？
```typescript
manager.cleanupCompletedTasks();
```

### Q4: 如何注册自定义协议？
```typescript
class MyProtocol implements TransferProtocolInterface { /* ... */ }
manager.registerCustomProtocol('MY_PROTO', new MyProtocol());
```

### Q5: 如何计算文件哈希？
```typescript
const hash = await FileUtils.calculateHash(fileData);
```

## 📝 TaskDispatch 集成

```typescript
import { taskDispatch } from './manager/broker/task/TaskDispatch';

const taskInfo = {
  taskId: 'task_001',
  fromClient: 'device_A',
  toClient: 'device_B',
  params: { /* ... */ },
  sourceIp: '192.168.1.100',      // >2MB 时自动设置
  transferType: 'direct',         // 或'tcp'
  fileHash: 'abc123...'           // 可选
};

await taskDispatch.sendTask(taskInfo);
// 自动判断文件大小并选择协议
```

## 🎯 最佳实践

1. **单例使用**: 始终使用 `getInstance()`
2. **及时清理**: 定期调用 `cleanupCompletedTasks()`
3. **合理配置**: 根据网络环境调整参数
4. **错误处理**: 始终包裹 try-catch
5. **资源管理**: 完成后取消不必要的监听

---

**完整文档**: README.md  
**实现总结**: IMPLEMENTATION_SUMMARY.md  
**示例代码**: examples/TransferExamples.ets
