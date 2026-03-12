/**
 * 文件传输模块统一导出
 */

// 协议接口和类型
export {
  TransferProtocolInterface,
  TransferState,
  TransferConfig,
  TransferProgress,
  TransferNotifyCallback,
  CapableProtocolInterface,
  ProtocolCapabilities
} from './protocol/TransferProtocolInterface';

// 协议注册
export { ProtocolRegistry } from './protocol/ProtocolRegistry';

// 协议实现
export { MQTTTransferProtocol } from './protocol/MQTTTransferProtocol';
export { TCPTransferProtocol } from './protocol/TCPTransferProtocol';

// Socket 管理
export { FileTransferSocketManager, MessageCallback, TCPConnectionInfo } from './socket/FileTransferSocketManager';

// 数据模型
export {
  FileInfo,
  ChunkData,
  TransferTask,
  TransferOptions,
  TransferNotifyInfo,
  TransferTaskState,
  createFileInfo,
  generateFileId,
  isValidFileInfo
} from './model/TransferDataModels';

// TCP 专用数据模型
export {
  TCPNotifyInfo,
  TCPMessageType,
  TCPHandshakeMessage,
  TCPChunkMessage,
  TCPChunkAckMessage,
  TCPCompleteMessage,
  TCPErrorMessage,
  TCPMessage
} from './model/TCPModels';

// 传输结果类型
export {
  TransferResult,
  TransferErrorCode,
  TransferError,
  TransferTaskStatus,
  FileTransferCompleteResult,
  createSuccessResult,
  createErrorResult,
  createTransferError,
  errorFromException,
  getDefaultErrorMessage
} from './model/TransferResult';

// 工具类
export { FileUtils } from './utils/FileUtils';
export { NetworkUtils } from './utils/NetworkUtils';
export {
  sleep,
  generateUniqueId,
  formatBytes,
  formatDuration,
  calculateSpeed,
  calculateEstimatedTime,
  safeExecute,
  withTimeout,
  retry
} from './utils/CommonUtils';

// 事件系统
export {
  TransferEventManager,
  TransferEventId,
  TransferEventData,
  TransferStartEventData,
  TransferProgressEventData,
  TransferCompleteEventData,
  TransferFailedEventData,
  TransferEventListener
} from './event/TransferEvents';

// 核心管理器
export { FileTransferManager } from './FileTransferManager';
