/**
 * TCP 文件传输协议实现
 * 基于 TCP Socket，处理大文件（>2MB）的分块传输
 */
import {
  TransferProtocolInterface,
  TransferConfig,
  TransferState,
  TransferProgress,
  CapableProtocolInterface,
  ProtocolCapabilities
} from '../protocol/TransferProtocolInterface';
import { FileTransferSocketManager, MessageCallback } from '../socket/FileTransferSocketManager';
import { ChunkData, FileInfo, TransferNotifyInfo } from '../model/TransferDataModels';
import {
  TCPNotifyInfo,
  TCPMessageType,
  TCPHandshakeMessage,
  TCPChunkMessage,
  TCPChunkAckMessage,
  TCPCompleteMessage,
  TCPErrorMessage,
  TCPMessage
} from '../model/TCPModels';
import { FileUtils } from '../utils/FileUtils';
import { TransferEventManager, TransferEventId } from '../event/TransferEvents';
import { NetworkUtils } from '../utils/NetworkUtils';
import {
  TransferResult,
  TransferErrorCode,
  createSuccessResult,
  createErrorResult,
  errorFromException,
  createTransferError
} from '../model/TransferResult';
import { sleep, generateUniqueId, calculateSpeed, calculateEstimatedTime } from '../utils/CommonUtils';

/**
 * 接收状态信息
 */
interface ReceiveState {
  taskId: string;
  fileInfo: FileInfo;
  totalChunks: number;
  receivedChunks: number;
  chunks: ChunkData[];
  fileHash: string;
  isComplete: boolean;
  resolve?: (chunks: ChunkData[]) => void;
  reject?: (error: Error) => void;
  timeoutId?: number;
  startTime: number;
  lastProgressTime: number;
}

/**
 * 发送状态信息
 */
interface SendState {
  taskId: string;
  fileInfo: FileInfo;
  totalChunks: number;
  sentChunks: number;
  fileHash: string;
  startTime: number;
  lastProgressTime: number;
  connectionId: string | null;
}

/**
 * TCP 协议能力定义
 */
const TCP_CAPABILITIES: ProtocolCapabilities = {
  supportsLargeFiles: true,
  maxFileSize: 0, // 无限制
  supportsChunking: true,
  defaultChunkSize: 128 * 1024, // 128KB
  supportsResume: false,
  supportsProgress: true,
  supportsCancellation: true,
  requiresActiveConnection: true
};

/**
 * TCP 文件传输协议实现类
 */
export class TCPTransferProtocol implements CapableProtocolInterface {
  private socketManager: FileTransferSocketManager;
  private eventManager: TransferEventManager;
  private progressMap: Map<string, TransferProgress> = new Map();
  private chunkBuffers: Map<string, ChunkData[]> = new Map();
  private receiveStates: Map<string, ReceiveState> = new Map();
  private sendStates: Map<string, SendState> = new Map();

  // 配置参数
  private readonly DEFAULT_CHUNK_SIZE = 128 * 1024; // 128KB
  private readonly DEFAULT_TIMEOUT = 30000; // 30秒
  private readonly MAX_RETRIES = 3;
  private readonly DEFAULT_PORT = 8888;
  private readonly RECEIVE_TIMEOUT = 300000; // 5分钟
  private readonly CONNECTION_WAIT_TIMEOUT = 30000; // 30秒

  constructor() {
    this.socketManager = FileTransferSocketManager.getInstance();
    this.eventManager = TransferEventManager.getInstance();
  }

  /**
   * 获取协议名称
   */
  getProtocolName(): string {
    return 'TCP';
  }

  /**
   * 获取协议能力信息
   */
  getCapabilities(): ProtocolCapabilities {
    const result: ProtocolCapabilities = {
      supportsLargeFiles: TCP_CAPABILITIES.supportsLargeFiles,
      maxFileSize: TCP_CAPABILITIES.maxFileSize,
      supportsChunking: TCP_CAPABILITIES.supportsChunking,
      defaultChunkSize: TCP_CAPABILITIES.defaultChunkSize,
      supportsResume: TCP_CAPABILITIES.supportsResume,
      supportsProgress: TCP_CAPABILITIES.supportsProgress,
      supportsCancellation: TCP_CAPABILITIES.supportsCancellation,
      requiresActiveConnection: TCP_CAPABILITIES.requiresActiveConnection
    };
    return result;
  }

  /**
   * 连接到远程设备（作为客户端）
   */
  async connect(host: string, port: number = this.DEFAULT_PORT, config?: TransferConfig): Promise<TransferResult<boolean>> {
    try {
      const timeout = config?.timeout || this.DEFAULT_TIMEOUT;

      console.info(`[TCPTransferProtocol] 开始连接到 ${host}:${port}`);

      const connectionId = await this.socketManager.connectToServer(host, port, timeout);

      if (connectionId) {
        console.info(`[TCPTransferProtocol] 连接成功，connectionId=${connectionId}`);
        return createSuccessResult('connect', true);
      } else {
        console.error('[TCPTransferProtocol] 连接失败');
        return createErrorResult(
          'connect',
          TransferErrorCode.CONNECTION_FAILED,
          `无法连接到 ${host}:${port}`
        );
      }
    } catch (error) {
      console.error('[TCPTransferProtocol] 连接异常:', error);
      return createErrorResult(
        'connect',
        TransferErrorCode.CONNECTION_FAILED,
        `连接异常: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  /**
   * 启动服务器监听（作为服务端）
   */
  async startServer(port: number = this.DEFAULT_PORT): Promise<TransferResult<boolean>> {
    try {
      console.info(`[TCPTransferProtocol] 启动服务器监听，端口=${port}`);
      const result = await this.socketManager.startServer(port);

      if (result) {
        console.info('[TCPTransferProtocol] 服务器启动成功');
        return createSuccessResult('startServer', true);
      } else {
        console.error('[TCPTransferProtocol] 服务器启动失败');
        return createErrorResult(
          'startServer',
          TransferErrorCode.SERVER_START_FAILED,
          `服务器启动失败，端口=${port}`
        );
      }
    } catch (error) {
      console.error('[TCPTransferProtocol] 服务器启动异常:', error);
      return createErrorResult(
        'startServer',
        TransferErrorCode.SERVER_START_FAILED,
        `服务器启动异常: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  /**
   * 断开连接
   */
  async disconnect(): Promise<TransferResult<boolean>> {
    console.info('[TCPTransferProtocol] 断开所有连接');

    try {
      await this.socketManager.stopServer();
      return createSuccessResult('disconnect', true);
    } catch (error) {
      console.error('[TCPTransferProtocol] 断开连接失败:', error);
      return createErrorResult(
        'disconnect',
        TransferErrorCode.UNKNOWN_ERROR,
        `断开连接失败: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  /**
   * 检查连接状态
   */
  isConnected(): boolean {
    return this.socketManager.isServerListening() || this.socketManager.getActiveConnections() > 0;
  }

  /**
   * 发送文件数据（支持分块传输）
   */
  async send(data: ArrayBuffer | string, taskId: string, config?: TransferConfig): Promise<TransferResult<boolean>> {
    try {
      // 转换数据格式
      let fileData: ArrayBuffer;
      if (typeof data === 'string') {
        fileData = FileUtils.stringToArrayBuffer(data);
      } else {
        fileData = data;
      }

      const chunkSize = config?.chunkSize || this.DEFAULT_CHUNK_SIZE;
      const maxRetries = config?.maxRetries || this.MAX_RETRIES;
      const port = this.DEFAULT_PORT;

      // 启动 TCP 服务器
      if (!this.isConnected()) {
        const serverResult = await this.startServer(port);
        if (!serverResult.success) {
          return createErrorResult(
            taskId,
            TransferErrorCode.SERVER_START_FAILED,
            `TCP 服务器启动失败，端口=${port}`
          );
        }
      }

      // 通知目标设备
      if (config?.notifyCallback) {
        const fileInfo: FileInfo = config.fileInfo || {
          fileId: taskId,
          fileName: `file_${taskId}`,
          size: fileData.byteLength
        };

        const notifyInfo: TCPNotifyInfo = {
          taskId,
          protocol: 'TCP',
          sourceDevice: NetworkUtils.getIpAddress(),
          fileInfo,
          sourceIp: NetworkUtils.getIpAddress(),
          port: port,
          timestamp: 0
        };

        await config.notifyCallback(notifyInfo);
        console.info(`[TCPTransferProtocol] 已通知目标设备发起 TCP 连接，taskId=${taskId}`);
      } else {
        console.warn(`[TCPTransferProtocol] 未提供 notifyCallback，目标设备可能无法得知需要发起连接`);
      }

      // 计算文件哈希
      const fileHash = await FileUtils.calculateHash(fileData);

      // 分块
      const chunks = FileUtils.chunkFile(fileData, chunkSize, taskId);
      console.info(`[TCPTransferProtocol] 文件分块完成，总块数=${chunks.length}, 大小=${fileData.byteLength}字节`);

      // 初始化发送状态
      const sendState: SendState = {
        taskId,
        fileInfo: config?.fileInfo || { fileId: taskId, fileName: `file_${taskId}`, size: fileData.byteLength },
        totalChunks: chunks.length,
        sentChunks: 0,
        fileHash,
        startTime: Date.now(),
        lastProgressTime: Date.now(),
        connectionId: null
      };
      this.sendStates.set(taskId, sendState);

      // 更新进度为传输中
      this.updateProgress(taskId, TransferState.TRANSFERRING, 0, 0, fileData.byteLength);

      // 等待客户端连接
      let connectionId: string | null = null;
      let waitTime = 0;
      while (waitTime < this.CONNECTION_WAIT_TIMEOUT) {
        const connectionIds = this.socketManager.getConnectionIds();
        if (connectionIds.length > 0) {
          connectionId = connectionIds[0];
          break;
        }
        await sleep(100);
        waitTime += 100;
      }

      if (!connectionId) {
        return createErrorResult(
          taskId,
          TransferErrorCode.CONNECTION_TIMEOUT,
          '等待客户端连接超时'
        );
      }

      sendState.connectionId = connectionId;
      console.info(`[TCPTransferProtocol] 客户端已连接，connectionId=${connectionId}`);

      // 发送握手消息
      const handshakeMessage: TCPHandshakeMessage = {
        type: TCPMessageType.HANDSHAKE,
        taskId,
        fileInfo: sendState.fileInfo,
        totalChunks: chunks.length,
        chunkSize,
        fileHash
      };

      const handshakeResult = await this.sendTCPMessage(connectionId, handshakeMessage);
      if (!handshakeResult.success) {
        return createErrorResult(
          taskId,
          TransferErrorCode.TCP_HANDSHAKE_FAILED,
          '握手消息发送失败'
        );
      }

      console.info(`[TCPTransferProtocol] 握手消息已发送，等待分块确认...`);

      // 逐块发送
      for (let i = 0; i < chunks.length; i++) {
        const chunk = chunks[i];

        const chunkMessage: TCPChunkMessage = {
          type: TCPMessageType.CHUNK,
          taskId,
          chunkIndex: i,
          data: chunk.data,
          isLastChunk: i === chunks.length - 1
        };

        // 重试机制
        let success = false;
        for (let retry = 0; retry < maxRetries; retry++) {
          const result = await this.sendTCPMessage(connectionId, chunkMessage);
          if (result.success) {
            success = true;
            break;
          }

          console.warn(`[TCPTransferProtocol] 分块 ${i} 发送失败，重试 (${retry + 1}/${maxRetries})`);
          await sleep(500 * (retry + 1));
        }

        if (!success) {
          return createErrorResult(
            taskId,
            TransferErrorCode.CHUNK_SEND_FAILED,
            `分块 ${i} 发送失败，超过最大重试次数`
          );
        }

        sendState.sentChunks++;
        const progress = Math.round((sendState.sentChunks / chunks.length) * 100);
        const now = Date.now();
        const speed = calculateSpeed(
          (i + 1) * chunkSize,
          now - sendState.startTime
        );
        const estimatedTime = calculateEstimatedTime(
          (i + 1) * chunkSize,
          fileData.byteLength,
          now - sendState.startTime
        );

        this.updateProgress(taskId, TransferState.TRANSFERRING, progress, (i + 1) * chunkSize, fileData.byteLength, speed, estimatedTime);

        // 触发分块接收事件
        this.eventManager.emit(TransferEventId.CHUNK_RECEIVED, taskId, `${i}/${chunks.length}`);
      }

      // 发送完成消息
      const completeMessage: TCPCompleteMessage = {
        type: TCPMessageType.COMPLETE,
        taskId,
        fileHash
      };
      await this.sendTCPMessage(connectionId, completeMessage);

      // 更新进度为完成
      this.updateProgress(taskId, TransferState.COMPLETED, 100, fileData.byteLength, fileData.byteLength);

      // 清理发送状态
      this.sendStates.delete(taskId);

      console.info(`[TCPTransferProtocol] 文件发送完成，taskId=${taskId}`);
      return createSuccessResult(taskId, true);
    } catch (error) {
      const transferError = errorFromException(error, TransferErrorCode.TRANSFER_FAILED);
      console.error('[TCPTransferProtocol] 文件发送失败:', transferError.message);
      this.updateProgress(taskId, TransferState.FAILED, 0, 0, 0, undefined, undefined, transferError.message);
      this.sendStates.delete(taskId);

      return createErrorResult(
        taskId,
        transferError.code,
        transferError.message,
        transferError.details,
        transferError.cause
      );
    }
  }

  /**
   * 接收文件数据
   */
  async receive(taskId: string): Promise<TransferResult<ArrayBuffer | string>> {
    try {
      console.info(`[TCPTransferProtocol] 开始接收文件，taskId=${taskId}`);

      // 初始化接收状态
      this.initReceiveState(taskId);

      // 注册消息回调
      this.socketManager.registerMessageCallback(taskId, this.createMessageHandler(taskId));

      // 等待所有分块接收完成
      const chunks = await this.waitForAllChunks(taskId);

      // 注销消息回调
      this.socketManager.unregisterMessageCallback(taskId);

      if (!chunks || chunks.length === 0) {
        return createErrorResult(
          taskId,
          TransferErrorCode.RECEIVE_FAILED,
          '未接收到任何分块'
        );
      }

      // 重组文件
      const fileData = FileUtils.reassembleChunks(chunks);

      // 验证哈希
      const receiveState = this.receiveStates.get(taskId);
      if (receiveState && receiveState.fileHash) {
        const receivedHash = await FileUtils.calculateHash(fileData);
        if (receivedHash !== receiveState.fileHash) {
          return createErrorResult(
            taskId,
            TransferErrorCode.FILE_HASH_MISMATCH,
            '文件哈希校验失败',
            `期望: ${receiveState.fileHash.substring(0, 16)}..., 实际: ${receivedHash.substring(0, 16)}...`
          );
        }
        console.info(`[TCPTransferProtocol] 文件哈希校验通过，哈希=${receivedHash.substring(0, 16)}...`);
      }

      // 更新进度为完成
      this.updateProgress(taskId, TransferState.COMPLETED, 100, fileData.byteLength, fileData.byteLength);

      // 清理接收状态
      this.receiveStates.delete(taskId);
      this.chunkBuffers.delete(taskId);

      return createSuccessResult(taskId, fileData);
    } catch (error) {
      const transferError = errorFromException(error, TransferErrorCode.RECEIVE_FAILED);
      console.error('[TCPTransferProtocol] 文件接收失败:', transferError.message);
      this.updateProgress(taskId, TransferState.FAILED, 0, 0, 0, undefined, undefined, transferError.message);

      // 清理资源
      this.socketManager.unregisterMessageCallback(taskId);
      this.receiveStates.delete(taskId);

      return createErrorResult(
        taskId,
        transferError.code,
        transferError.message,
        transferError.details,
        transferError.cause
      );
    }
  }

  /**
   * 获取传输进度
   */
  getProgress(taskId: string): TransferProgress {
    const progress = this.progressMap.get(taskId);
    if (!progress) {
      return {
        taskId,
        state: TransferState.IDLE,
        transferredBytes: 0,
        totalBytes: 0,
        progress: 0
      };
    }
    return progress;
  }

  /**
   * 取消传输任务
   */
  async cancel(taskId: string): Promise<TransferResult<boolean>> {
    console.info(`[TCPTransferProtocol] 取消传输任务：${taskId}`);

    // 清理该任务的缓存
    this.chunkBuffers.delete(taskId);
    this.sendStates.delete(taskId);

    const receiveState = this.receiveStates.get(taskId);
    if (receiveState && receiveState.reject) {
      receiveState.reject(new Error('传输已取消'));
    }
    this.receiveStates.delete(taskId);

    this.updateProgress(taskId, TransferState.CANCELLED, 0, 0, 0);

    return createSuccessResult(taskId, true);
  }

  /**
   * 初始化接收状态
   */
  private initReceiveState(taskId: string): void {
    const receiveState: ReceiveState = {
      taskId,
      fileInfo: { fileId: taskId, fileName: '', size: 0 },
      totalChunks: 0,
      receivedChunks: 0,
      chunks: [],
      fileHash: '',
      isComplete: false,
      startTime: Date.now(),
      lastProgressTime: Date.now()
    };
    this.receiveStates.set(taskId, receiveState);
    this.chunkBuffers.set(taskId, []);
  }

  /**
   * 创建消息处理器
   */
  private createMessageHandler(taskId: string): MessageCallback {
    return (connectionId: string, data: ArrayBuffer) => {
      try {
        this.handleIncomingMessage(taskId, connectionId, data);
      } catch (error) {
        console.error(`[TCPTransferProtocol] 消息处理失败，taskId=${taskId}:`, error);
      }
    };
  }

  /**
   * 处理接收到的 TCP 消息
   */
  private handleIncomingMessage(taskId: string, connectionId: string, data: ArrayBuffer): void {
    const receiveState = this.receiveStates.get(taskId);
    if (!receiveState) {
      console.warn(`[TCPTransferProtocol] 未找到接收状态，taskId=${taskId}`);
      return;
    }

    // 解析消息
    const message = this.parseTCPMessage(data);
    if (!message) {
      console.error(`[TCPTransferProtocol] 消息解析失败，taskId=${taskId}`);
      return;
    }

    console.info(`[TCPTransferProtocol] 收到消息，type=${message.type}, taskId=${taskId}`);

    switch (message.type) {
      case TCPMessageType.HANDSHAKE:
        this.handleHandshakeMessage(taskId, message as TCPHandshakeMessage);
        break;
      case TCPMessageType.CHUNK:
        this.handleChunkMessage(taskId, message as TCPChunkMessage);
        break;
      case TCPMessageType.COMPLETE:
        this.handleCompleteMessage(taskId, message as TCPCompleteMessage);
        break;
      case TCPMessageType.ERROR:
        this.handleErrorMessage(taskId, message as TCPErrorMessage);
        break;
      default:
        console.warn(`[TCPTransferProtocol] 未知消息类型，type=${message.type}`);
    }
  }

  /**
   * 解析 TCP 消息
   */
  private parseTCPMessage(data: ArrayBuffer): TCPMessage | null {
    try {
      if (data.byteLength < 4) {
        return null;
      }

      const headerLengthView = new DataView(data, 0, 4);
      const headerLength = headerLengthView.getInt32(0, false);

      if (headerLength <= 0 || headerLength > data.byteLength - 4) {
        console.error(`[TCPTransferProtocol] 无效的消息头长度：${headerLength}`);
        return null;
      }

      const headerBytes = new Uint8Array(data, 4, headerLength);
      const headerBuffer = new ArrayBuffer(headerLength);
      new Uint8Array(headerBuffer).set(headerBytes);
      const headerJson = FileUtils.arrayBufferToString(headerBuffer);
      const header = JSON.parse(headerJson) as TCPMessage;

      return header;
    } catch (error) {
      console.error('[TCPTransferProtocol] 消息解析失败:', error);
      return null;
    }
  }

  /**
   * 序列化并发送 TCP 消息
   */
  private async sendTCPMessage(connectionId: string, message: TCPMessage): Promise<TransferResult<boolean>> {
    try {
      let messageToSend: TCPMessage = message;

      if (message.type === TCPMessageType.CHUNK) {
        const chunkMessage = message as TCPChunkMessage;
        if (typeof chunkMessage.data !== 'string') {
          messageToSend = {
            type: chunkMessage.type,
            taskId: chunkMessage.taskId,
            chunkIndex: chunkMessage.chunkIndex,
            data: FileUtils.arrayBufferToBase64(chunkMessage.data),
            isLastChunk: chunkMessage.isLastChunk
          } as TCPMessage;
        }
      }

      const headerJson = JSON.stringify(messageToSend);
      const headerBytes = FileUtils.stringToArrayBuffer(headerJson);

      const totalLength = 4 + headerBytes.byteLength;
      const fullMessage = new ArrayBuffer(totalLength);
      const fullView = new Uint8Array(fullMessage);

      const lengthView = new DataView(fullMessage, 0, 4);
      lengthView.setInt32(0, headerBytes.byteLength, false);

      fullView.set(new Uint8Array(headerBytes), 4);

      const success = await this.socketManager.sendData(connectionId, fullMessage);
      if (success) {
        return createSuccessResult(message.taskId || 'send', true);
      } else {
        return createErrorResult(
          message.taskId || 'send',
          TransferErrorCode.SEND_FAILED,
          '消息发送失败'
        );
      }
    } catch (error) {
      console.error('[TCPTransferProtocol] 消息发送失败:', error);
      return createErrorResult(
        message.taskId || 'send',
        TransferErrorCode.SEND_FAILED,
        `消息发送异常: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  /**
   * 处理握手消息
   */
  private handleHandshakeMessage(taskId: string, message: TCPHandshakeMessage): void {
    const receiveState = this.receiveStates.get(taskId);
    if (!receiveState) return;

    receiveState.fileInfo = message.fileInfo;
    receiveState.totalChunks = message.totalChunks;
    receiveState.fileHash = message.fileHash;

    console.info(`[TCPTransferProtocol] 握手消息已接收，taskId=${taskId}, totalChunks=${message.totalChunks}`);

    this.updateProgress(taskId, TransferState.TRANSFERRING, 0, 0, message.fileInfo.size);
  }

  /**
   * 处理分块消息
   */
  private handleChunkMessage(taskId: string, message: TCPChunkMessage): void {
    const receiveState = this.receiveStates.get(taskId);
    if (!receiveState) return;

    let chunkData: ArrayBuffer;
    if (typeof message.data === 'string') {
      chunkData = FileUtils.base64ToArrayBuffer(message.data);
    } else {
      chunkData = message.data;
    }

    const chunk: ChunkData = {
      taskId,
      chunkIndex: message.chunkIndex,
      totalChunks: receiveState.totalChunks,
      data: chunkData,
      chunkSize: chunkData.byteLength,
      isLastChunk: message.isLastChunk
    };

    receiveState.chunks.push(chunk);
    receiveState.receivedChunks++;

    this.chunkBuffers.set(taskId, receiveState.chunks);

    const progress = receiveState.totalChunks > 0
      ? Math.round((receiveState.receivedChunks / receiveState.totalChunks) * 100)
      : 0;

    const now = Date.now();
    const speed = calculateSpeed(
      receiveState.receivedChunks * chunkData.byteLength,
      now - receiveState.startTime
    );
    const estimatedTime = calculateEstimatedTime(
      receiveState.receivedChunks * chunkData.byteLength,
      receiveState.fileInfo.size,
      now - receiveState.startTime
    );

    this.updateProgress(
      taskId,
      TransferState.TRANSFERRING,
      progress,
      receiveState.receivedChunks * chunkData.byteLength,
      receiveState.fileInfo.size,
      speed,
      estimatedTime
    );

    this.eventManager.emit(
      TransferEventId.CHUNK_RECEIVED,
      taskId,
      `${message.chunkIndex}/${receiveState.totalChunks}`
    );

    console.info(`[TCPTransferProtocol] 分块已接收，taskId=${taskId}, chunkIndex=${message.chunkIndex}`);
  }

  /**
   * 处理完成消息
   */
  private handleCompleteMessage(taskId: string, message: TCPCompleteMessage): void {
    const receiveState = this.receiveStates.get(taskId);
    if (!receiveState) return;

    receiveState.fileHash = message.fileHash;
    receiveState.isComplete = true;

    console.info(`[TCPTransferProtocol] 完成消息已接收，taskId=${taskId}`);

    if (receiveState.resolve) {
      receiveState.resolve(receiveState.chunks);
    }
  }

  /**
   * 处理错误消息
   */
  private handleErrorMessage(taskId: string, message: TCPErrorMessage): void {
    console.error(`[TCPTransferProtocol] 收到错误消息，taskId=${taskId}, error=${message.errorMessage}`);

    const receiveState = this.receiveStates.get(taskId);
    if (receiveState && receiveState.reject) {
      receiveState.reject(new Error(message.errorMessage));
    }
  }

  /**
   * 等待所有分块接收完成
   */
  private async waitForAllChunks(taskId: string): Promise<ChunkData[]> {
    return new Promise((resolve, reject) => {
      const receiveState = this.receiveStates.get(taskId);
      if (!receiveState) {
        reject(new Error('接收状态未初始化'));
        return;
      }

      if (receiveState.isComplete) {
        resolve(receiveState.chunks);
        return;
      }

      receiveState.resolve = resolve;
      receiveState.reject = reject;

      receiveState.timeoutId = setTimeout(() => {
        reject(new Error('接收分块超时'));
      }, this.RECEIVE_TIMEOUT);
    });
  }

  /**
   * 更新传输进度
   */
  private updateProgress(
    taskId: string,
    state: TransferState,
    percentage: number,
    transferredBytes: number,
    totalBytes: number,
    speed?: number,
    estimatedTime?: number,
    error?: string
  ): void {
    const progress: TransferProgress = {
      taskId,
      state,
      transferredBytes,
      totalBytes,
      progress: percentage,
      speed,
      estimatedTimeRemaining: estimatedTime,
      error
    };

    this.progressMap.set(taskId, progress);
    this.eventManager.emitTransferProgress(taskId, progress);

    // 清理已完成的进度记录
    if (state === TransferState.COMPLETED || state === TransferState.FAILED || state === TransferState.CANCELLED) {
      setTimeout(() => {
        this.progressMap.delete(taskId);
      }, 60000);
    }
  }
}
