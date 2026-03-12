/**
 * TCP 文件传输协议实现
 * 基于 TCP Socket，处理大文件（>2MB）的分块传输
 */
import { TransferProtocolInterface, TransferConfig, TransferState, TransferProgress } from '../protocol/TransferProtocolInterface';
import { FileTransferSocketManager, MessageCallback } from '../socket/FileTransferSocketManager';
import { ChunkData, FileInfo } from '../model/TransferDataModels';
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
}

export class TCPTransferProtocol implements TransferProtocolInterface {
  private socketManager: FileTransferSocketManager;
  private eventManager: TransferEventManager;
  private progressMap: Map<string, TransferProgress> = new Map();
  private chunkBuffers: Map<string, ChunkData[]> = new Map(); // 接收分块缓存
  private receiveStates: Map<string, ReceiveState> = new Map(); // 接收状态管理

  // 配置参数
  private readonly DEFAULT_CHUNK_SIZE = 128 * 1024; // 128KB
  private readonly DEFAULT_TIMEOUT = 30000; // 30 秒
  private readonly MAX_RETRIES = 3; // 最多重试 3 次
  private readonly DEFAULT_PORT = 8888; // 默认监听端口
  private readonly RECEIVE_TIMEOUT = 300000; // 接收超时 5 分钟

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
   * 连接到远程设备（作为客户端）
   * @param host - 远程主机 IP
   * @param port - 远程端口
   * @param config - 传输配置
   */
  async connect(host: string, port: number = this.DEFAULT_PORT, config?: TransferConfig): Promise<boolean> {
    try {
      const timeout = config?.timeout || this.DEFAULT_TIMEOUT;
      
      console.info(`[TCPTransferProtocol] 开始连接到 ${host}:${port}`);
      
      const connectionId = await this.socketManager.connectToServer(host, port, timeout);
      
      if (connectionId) {
        console.info(`[TCPTransferProtocol] 连接成功，connectionId=${connectionId}`);
        return true;
      } else {
        console.error('[TCPTransferProtocol] 连接失败');
        return false;
      }
    } catch (error) {
      console.error('[TCPTransferProtocol] 连接异常:', error);
      return false;
    }
  }

  /**
   * 启动服务器监听（作为服务端）
   * @param host - 本机 IP（可选）
   * @param port - 监听端口
   * @param config - 传输配置
   */
  async startServer(port: number = this.DEFAULT_PORT, config?: TransferConfig): Promise<boolean> {
    try {
      console.info(`[TCPTransferProtocol] 启动服务器监听，端口=${port}`);
      const result = await this.socketManager.startServer(port);
      
      if (result) {
        console.info('[TCPTransferProtocol] 服务器启动成功');
        return true;
      } else {
        console.error('[TCPTransferProtocol] 服务器启动失败');
        return false;
      }
    } catch (error) {
      console.error('[TCPTransferProtocol] 服务器启动异常:', error);
      return false;
    }
  }

  /**
   * 断开连接
   */
  async disconnect(): Promise<boolean> {
    console.info('[TCPTransferProtocol] 断开所有连接');
    
    // 停止服务器
    await this.socketManager.stopServer();
    
    return true;
  }

  /**
   * 检查连接状态
   */
  isConnected(): boolean {
    return this.socketManager.isServerListening() || this.socketManager.getActiveConnections() > 0;
  }

  /**
   * 发送文件数据（支持分块传输）
   * TCP 作为发送端的完整流程：启动服务器 → 通知目标设备（config.notifyCallback）→ 等待连接 → 分块发送
   * @param data - 文件数据
   * @param taskId - 任务 ID
   * @param config - 传输配置，config.notifyCallback 用于通知目标设备发起 TCP 连接
   */
  async send(data: ArrayBuffer | string, taskId: string, config?: TransferConfig): Promise<boolean> {
    try {
      // 如果是字符串，先转换为 ArrayBuffer
      let fileData: ArrayBuffer;
      if (typeof data === 'string') {
        fileData = FileUtils.stringToArrayBuffer(data);
      } else {
        fileData = data;
      }

      const chunkSize = config?.chunkSize || this.DEFAULT_CHUNK_SIZE;
      const maxRetries = config?.maxRetries || this.MAX_RETRIES;
      const port = this.DEFAULT_PORT;

      // 启动 TCP 服务器监听，等待目标设备主动连接
      if (!this.isConnected()) {
        const serverStarted = await this.startServer(port);
        if (!serverStarted) {
          throw new Error(`TCP 服务器启动失败，端口=${port}`);
        }
      }

      // 服务器就绪，通知目标设备发起连接
      if (config?.notifyCallback) {
        const fileInfo: FileInfo = {
          fileId: taskId,
          fileName: `file_${taskId}`,
          size: fileData.byteLength
        };
        const notifyInfo: TCPNotifyInfo = {
          sourceIp: NetworkUtils.getIpAddress(),
          port: port,
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
      
      // 更新进度为传输中
      this.updateProgress(taskId, TransferState.TRANSFERRING, 0);
      
      // 等待客户端连接（最多等待 30 秒）
      let connectionId: string | null = null;
      let waitTime = 0;
      while (waitTime < 30000) {
        const connectionIds = this.socketManager.getConnectionIds();
        if (connectionIds.length > 0) {
          connectionId = connectionIds[0];
          break;
        }
        await this.sleep(100);
        waitTime += 100;
      }

      if (!connectionId) {
        throw new Error('等待客户端连接超时');
      }

      console.info(`[TCPTransferProtocol] 客户端已连接，connectionId=${connectionId}`);

      // 发送握手消息（包含文件信息）
      const handshakeMessage: TCPHandshakeMessage = {
        type: TCPMessageType.HANDSHAKE,
        taskId,
        fileInfo: { fileId: taskId, fileName: `file_${taskId}`, size: fileData.byteLength },
        totalChunks: chunks.length,
        chunkSize,
        fileHash
      };
      const handshakeResult = await this.sendTCPMessage(connectionId, handshakeMessage);

      if (!handshakeResult) {
        throw new Error('握手消息发送失败');
      }

      console.info(`[TCPTransferProtocol] 握手消息已发送，等待分块确认...`);

      // 逐块发送文件数据
      let sentChunks = 0;
      for (let i = 0; i < chunks.length; i++) {
        const chunk = chunks[i];

        // 构建分块消息
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
          success = await this.sendTCPMessage(connectionId, chunkMessage);
          if (success) break;

          console.warn(`[TCPTransferProtocol] 分块 ${i} 发送失败，重试 (${retry + 1}/${maxRetries})`);
          await this.sleep(500 * (retry + 1));
        }

        if (!success) {
          throw new Error(`分块 ${i} 发送失败，超过最大重试次数`);
        }

        sentChunks++;
        const progress = Math.round((sentChunks / chunks.length) * 100);
        this.updateProgress(taskId, TransferState.TRANSFERRING, progress);

        // 触发分块接收事件
        this.eventManager.emit(
          TransferEventId.CHUNK_RECEIVED,
          taskId,
          `${i}/${chunks.length}`
        );
      }

      // 发送完成消息
      const completeMessage: TCPCompleteMessage = {
        type: TCPMessageType.COMPLETE,
        taskId,
        fileHash
      };
      await this.sendTCPMessage(connectionId, completeMessage);
      
      // 更新进度为完成
      this.updateProgress(taskId, TransferState.COMPLETED, 100);
      
      console.info(`[TCPTransferProtocol] 文件发送完成，taskId=${taskId}`);
      return true;
    } catch (error) {
      // TODO 错误消息返回客户端
      console.error('[TCPTransferProtocol] 文件发送失败:', error);
      this.updateProgress(taskId, TransferState.FAILED, 0, JSON.stringify(error));
      return false;
    }
  }

  /**
   * 接收文件数据
   * @param taskId - 任务 ID
   * @returns 接收到的完整数据
   */
  async receive(taskId: string): Promise<ArrayBuffer | string> {
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
        throw new Error('未接收到任何分块');
      }

      // 重组文件
      const fileData = FileUtils.reassembleChunks(chunks);

      // 验证哈希
      const receiveState = this.receiveStates.get(taskId);
      if (receiveState && receiveState.fileHash) {
        const receivedHash = await FileUtils.calculateHash(fileData);
        if (receivedHash !== receiveState.fileHash) {
          throw new Error('文件哈希校验失败');
        }
        console.info(`[TCPTransferProtocol] 文件哈希校验通过，哈希=${receivedHash.substring(0, 16)}...`);
      }

      // 更新进度为完成
      this.updateProgress(taskId, TransferState.COMPLETED, 100);

      // 清理接收状态
      this.receiveStates.delete(taskId);
      this.chunkBuffers.delete(taskId);

      return fileData;
    } catch (error) {
      const errMsg: string = error instanceof Error ? error.message : String(error);
      console.error('[TCPTransferProtocol] 文件接收失败:', errMsg);
      this.updateProgress(taskId, TransferState.FAILED, 0, errMsg);

      // 清理资源
      this.socketManager.unregisterMessageCallback(taskId);
      this.receiveStates.delete(taskId);

      throw new Error(errMsg);
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
  async cancel(taskId: string): Promise<boolean> {
    console.info(`[TCPTransferProtocol] 取消传输任务：${taskId}`);
    
    // 清理该任务的缓存
    this.chunkBuffers.delete(taskId);
    
    this.updateProgress(taskId, TransferState.CANCELLED, 0);
    return true;
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
      isComplete: false
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
   * 消息格式：前 4 字节为 JSON 头部长度，后面是 JSON 数据
   */
  private parseTCPMessage(data: ArrayBuffer): TCPMessage | null {
    try {
      if (data.byteLength < 4) {
        return null;
      }

      // 读取头部长度
      const headerLengthView = new DataView(data, 0, 4);
      const headerLength = headerLengthView.getInt32(0, false); // 大端序

      if (headerLength <= 0 || headerLength > data.byteLength - 4) {
        console.error(`[TCPTransferProtocol] 无效的消息头长度：${headerLength}`);
        return null;
      }

      // 解析 JSON 头部
      const headerBytes = new Uint8Array(data, 4, headerLength);
      // 创建一个新的 ArrayBuffer 拷贝，只包含头部数据
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
  private async sendTCPMessage(connectionId: string, message: TCPMessage): Promise<boolean> {
    try {
      // 构建消息头部（分块消息的数据单独处理，不包含在 JSON 中）
      let messageToSend: TCPMessage = message;
      let dataBytes: ArrayBuffer | null = null;

      if (message.type === TCPMessageType.CHUNK) {
        const chunkMessage = message as TCPChunkMessage;
        // 分块消息：将数据转为 Base64 放入 JSON，避免二进制序列化问题
        // 确保 data 是 ArrayBuffer 类型
        if (typeof chunkMessage.data !== 'string') {
          dataBytes = chunkMessage.data;
          messageToSend = {
            type: chunkMessage.type,
            taskId: chunkMessage.taskId,
            chunkIndex: chunkMessage.chunkIndex,
            data: FileUtils.arrayBufferToBase64(chunkMessage.data),
            isLastChunk: chunkMessage.isLastChunk
          } as TCPMessage;
        }
      }

      // 序列化消息头部
      const headerJson = JSON.stringify(messageToSend);
      const headerBytes = FileUtils.stringToArrayBuffer(headerJson);

      // 构建完整消息：4 字节头部长度 + JSON 头部
      const totalLength = 4 + headerBytes.byteLength;
      const fullMessage = new ArrayBuffer(totalLength);
      const fullView = new Uint8Array(fullMessage);

      // 写入头部长度（大端序）
      const lengthView = new DataView(fullMessage, 0, 4);
      lengthView.setInt32(0, headerBytes.byteLength, false);

      // 写入头部
      fullView.set(new Uint8Array(headerBytes), 4);

      return await this.socketManager.sendData(connectionId, fullMessage);
    } catch (error) {
      console.error('[TCPTransferProtocol] 消息发送失败:', error);
      return false;
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

    // 更新进度
    this.updateProgress(taskId, TransferState.TRANSFERRING, 0);
  }

  /**
   * 处理分块消息
   */
  private handleChunkMessage(taskId: string, message: TCPChunkMessage): void {
    const receiveState = this.receiveStates.get(taskId);
    if (!receiveState) return;

    // 解析分块数据（可能是 Base64 字符串或 ArrayBuffer）
    let chunkData: ArrayBuffer;
    if (typeof message.data === 'string') {
      // Python 端发送的是 Base64 字符串
      chunkData = FileUtils.base64ToArrayBuffer(message.data);
    } else {
      // ETS 端内部传递的是 ArrayBuffer
      chunkData = message.data;
    }

    // 创建分块数据
    const chunk: ChunkData = {
      taskId,
      chunkIndex: message.chunkIndex,
      totalChunks: receiveState.totalChunks,
      data: chunkData,
      chunkSize: chunkData.byteLength,
      isLastChunk: message.isLastChunk
    };

    // 缓存分块
    receiveState.chunks.push(chunk);
    receiveState.receivedChunks++;

    // 更新缓存
    this.chunkBuffers.set(taskId, receiveState.chunks);

    // 更新进度
    const progress = receiveState.totalChunks > 0
      ? Math.round((receiveState.receivedChunks / receiveState.totalChunks) * 100)
      : 0;
    this.updateProgress(taskId, TransferState.TRANSFERRING, progress);

    // 触发分块接收事件
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

    // 解析 Promise
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

      // 如果已经完成，直接返回
      if (receiveState.isComplete) {
        resolve(receiveState.chunks);
        return;
      }

      // 保存 resolve/reject 以便异步回调中使用
      receiveState.resolve = resolve;
      receiveState.reject = reject;

      // 设置超时
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
    error?: string
  ): void {
    const progress: TransferProgress = {
      taskId,
      state,
      transferredBytes: state === TransferState.COMPLETED ? 1 : 0,
      totalBytes: 1,
      progress: percentage,
      error
    };
    
    this.progressMap.set(taskId, progress);
    
    // 触发进度更新事件
    this.eventManager.emitTransferProgress(taskId, progress);
    
    // 如果任务完成或失败，清理进度记录
    if (state === TransferState.COMPLETED || state === TransferState.FAILED) {
      setTimeout(() => {
        this.progressMap.delete(taskId);
      }, 60000); // 1 分钟后清理
    }
  }

  /**
   * 延迟函数
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
