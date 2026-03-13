让我先查看 TCPTransferProtocol 的完整结构，以便给出准确的使用示例。
根据代码分析，以下是 `TransferEvents` 中**未使用事件**的具体使用示例：

---

## 未使用事件及添加位置

### 1. `TRANSFER_START` - 传输开始事件

**应添加位置**：`send()` 方法开始时、`receive()` 方法开始时

```typescript
// TCPTransferProtocol.ets - send() 方法中，第 324 行附近
async send(data: ArrayBuffer | string, taskId: string, config?: TransferConfig): Promise<TransferResult<boolean>> {
  // ... 现有代码 ...
  
  // 初始化发送状态后，添加：
  this.eventManager.emitTransferStart(taskId, 'TCP');
  
  // 更新进度为传输中
  this.updateProgress(taskId, TransferState.TRANSFERRING, 0, 0, fileData.byteLength);
}
```

```typescript
// TCPTransferProtocol.ets - receive() 方法中，第 463 行附近
async receive(taskId: string): Promise<TransferResult<ArrayBuffer | string>> {
  // ... 现有代码 ...
  
  // 初始化接收状态后，添加：
  this.eventManager.emitTransferStart(taskId, 'TCP');
  
  // 注册消息回调
  this.socketManager.registerMessageCallback(taskId, this.createMessageHandler(taskId));
}
```

---

### 2. `TRANSFER_COMPLETE` - 传输完成事件

**应添加位置**：`send()` 和 `receive()` 成功完成时

```typescript
// TCPTransferProtocol.ets - send() 方法中，第 435 行附近
// 更新进度为完成
this.updateProgress(taskId, TransferState.COMPLETED, 100, fileData.byteLength, fileData.byteLength);

// 添加：
const duration = Date.now() - sendState.startTime;
const completeData = {
  fileInfo: sendState.fileInfo,
  duration: duration,
  transferredBytes: fileData.byteLength,
  averageSpeed: fileData.byteLength / (duration / 1000),
  protocol: 'TCP'
};
this.eventManager.emitTransferComplete(taskId, completeData);

// 清理发送状态
this.sendStates.delete(taskId);
```

```typescript
// TCPTransferProtocol.ets - receive() 方法中，第 504 行附近
// 更新进度为完成
this.updateProgress(taskId, TransferState.COMPLETED, 100, fileData.byteLength, fileData.byteLength);

// 添加：
const duration = Date.now() - receiveState.startTime;
const completeData = {
  fileInfo: receiveState.fileInfo,
  duration: duration,
  transferredBytes: fileData.byteLength,
  averageSpeed: fileData.byteLength / (duration / 1000),
  protocol: 'TCP'
};
this.eventManager.emitTransferComplete(taskId, completeData);
```

---

### 3. `TRANSFER_FAILED` - 传输失败事件

**应添加位置**：`send()` 和 `receive()` 的 catch 块中

```typescript
// TCPTransferProtocol.ets - send() 方法中，第 442 行附近
catch (error) {
  const transferError = errorFromException(error, TransferErrorCode.TRANSFER_FAILED);
  console.error('[TCPTransferProtocol] 文件发送失败:', transferError.message);
  
  // 添加：
  this.eventManager.emitTransferFailed(taskId, transferError.message, transferError.code);
  
  this.updateProgress(taskId, TransferState.FAILED, 0, 0, 0, undefined, undefined, transferError.message);
  // ...
}
```

```typescript
// TCPTransferProtocol.ets - receive() 方法中，第 511 行附近
catch (error) {
  const transferError = errorFromException(error, TransferErrorCode.RECEIVE_FAILED);
  console.error('[TCPTransferProtocol] 文件接收失败:', transferError.message);
  
  // 添加：
  this.eventManager.emitTransferFailed(taskId, transferError.message, transferError.code);
  
  this.updateProgress(taskId, TransferState.FAILED, 0, 0, 0, undefined, undefined, transferError.message);
  // ...
}
```

---

### 4. `TRANSFER_CANCELLED` - 传输取消事件

**应添加位置**：`cancel()` 方法中

```typescript
// TCPTransferProtocol.ets - cancel() 方法中，第 563 行附近
async cancel(taskId: string): Promise<TransferResult<boolean>> {
  console.info(`[TCPTransferProtocol] 取消传输任务：${taskId}`);
  
  // ... 现有清理代码 ...
  
  this.updateProgress(taskId, TransferState.CANCELLED, 0, 0, 0);
  
  // 添加：
  this.eventManager.emitTransferCancelled(taskId);

  return createSuccessResult(taskId, true);
}
```

---

### 5. `TCP_CONNECTED` / `TCP_DISCONNECTED` - 连接状态事件

**应添加位置**：`connect()` 成功后、`disconnect()` 完成后

```typescript
// TCPTransferProtocol.ets - connect() 方法中，第 147 行附近
if (connectionId) {
  console.info(`[TCPTransferProtocol] 连接成功，connectionId=${connectionId}`);
  
  // 添加：
  this.eventManager.emit(TransferEventId.TCP_CONNECTED, taskId || 'connect', { connectionId, host, port });
  
  return createSuccessResult('connect', true);
}
```

```typescript
// TCPTransferProtocol.ets - disconnect() 方法中，第 231 行附近
console.info('[TCPTransferProtocol] 所有连接已断开，资源已释放');

// 添加：
this.eventManager.emit(TransferEventId.TCP_DISCONNECTED, 'disconnect', { reason: '主动断开' });

return createSuccessResult('disconnect', true);
```

---

### 6. `FILE_REASSEMBLED` - 文件重组完成事件

**应添加位置**：`receive()` 方法中文件重组后

```typescript
// TCPTransferProtocol.ets - receive() 方法中，第 486 行附近
// 重组文件
const fileData = FileUtils.reassembleChunks(chunks);

// 添加：
this.eventManager.emit(TransferEventId.FILE_REASSEMBLED, taskId, {
  fileSize: fileData.byteLength,
  chunkCount: chunks.length
});

// 验证哈希
const receiveState = this.receiveStates.get(taskId);
```

---

### 7. `PROTOCOL_REGISTERED` / `PROTOCOL_UNREGISTERED` - 协议注册事件

**应添加位置**：`ProtocolRegistry` 中（非 TCPTransferProtocol）

```typescript
// ProtocolRegistry.ets 中注册协议时
registerProtocol(protocol: TransferProtocolInterface): void {
  // ... 注册逻辑 ...
  
  // 添加：
  TransferEventManager.getInstance().emitProtocolRegistered(protocol.getProtocolName());
}
```

---

## UI 层监听示例

```typescript
// 在 UI 组件中监听事件
import { TransferEventManager, TransferEventId } from '../manager/transfer/event/TransferEvents';

// 页面初始化时注册监听
aboutToAppear() {
  const eventManager = TransferEventManager.getInstance();
  
  // 监听传输开始
  eventManager.on(TransferEventId.TRANSFER_START, (data) => {
    console.info(`传输开始: ${data.taskId}, 协议: ${data.data?.protocol}`);
    this.showTransferDialog();
  });
  
  // 监听进度更新
  eventManager.on(TransferEventId.TRANSFER_PROGRESS, (data) => {
    const progress = data.data;
    this.progress = progress.progress; // 更新进度条
    this.speed = progress.speed; // 更新速度显示
  });
  
  // 监听传输完成
  eventManager.on(TransferEventId.TRANSFER_COMPLETE, (data) => {
    const result = data.data;
    this.showSuccess(`传输完成！耗时: ${result.duration}ms, 平均速度: ${result.averageSpeed}B/s`);
  });
  
  // 监听传输失败
  eventManager.on(TransferEventId.TRANSFER_FAILED, (data) => {
    const error = data.data;
    this.showError(`传输失败: ${error.error}, 错误码: ${error.errorCode}`);
  });
  
  // 监听连接状态
  eventManager.on(TransferEventId.TCP_CONNECTED, (data) => {
    this.connectionStatus = '已连接';
  });
  
  eventManager.on(TransferEventId.TCP_DISCONNECTED, (data) => {
    this.connectionStatus = '已断开';
  });
}

// 页面销毁时移除监听
aboutToDisappear() {
  TransferEventManager.getInstance().offAll();
}
```

---

## 事件流程图

```
┌──────────────────────────────────────────────────────────────┐
│                      传输生命周期                              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  connect() ──► TCP_CONNECTED                                 │
│       │                                                      │
│       ▼                                                      │
│  send/receive() ──► TRANSFER_START                           │
│       │                                                      │
│       ▼                                                      │
│  传输中 ──► TRANSFER_PROGRESS (多次)                          │
│       │               │                                      │
│       │               └──► CHUNK_RECEIVED (每块)              │
│       │                                                      │
│       ├──► 成功 ──► FILE_REASSEMBLED (接收端)                 │
│       │              │                                       │
│       │              ▼                                       │
│       │         TRANSFER_COMPLETE                            │
│       │                                                      │
│       ├──► 失败 ──► TRANSFER_FAILED                          │
│       │                                                      │
│       └──► 取消 ──► TRANSFER_CANCELLED                       │
│                                                              │
│  disconnect() ──► TCP_DISCONNECTED                           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

这样就能实现完整的事件驱动传输状态通知机制。