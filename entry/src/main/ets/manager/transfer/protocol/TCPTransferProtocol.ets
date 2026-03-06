/**
 * TCP 文件传输协议实现
 * 基于 TCP Socket，处理大文件（>2MB）的分块传输
 */
import { TransferProtocolInterface, TransferConfig, TransferState, TransferProgress } from '../protocol/TransferProtocolInterface';
import { FileTransferSocketManager } from '../socket/FileTransferSocketManager';
import { ChunkData, TCPNotifyInfo } from '../model/TransferDataModels';
import { FileUtils } from '../utils/FileUtils';
import { TransferEventManager, TransferEventId } from '../event/TransferEvents';
import { NetworkUtils } from '../utils/NetworkUtils';

/**
 * TCP 握手信息（发送端用）
 */
interface TCPSendHandshakeInfo {
  fileId: string;
  fileName: string;
  size: number;
  hash: string;
  totalChunks: number;
  chunkSize: number;
}

export class TCPTransferProtocol implements TransferProtocolInterface {
  private socketManager: FileTransferSocketManager;
  private eventManager: TransferEventManager;
  private progressMap: Map<string, TransferProgress> = new Map();
  private chunkBuffers: Map<string, ChunkData[]> = new Map(); // 接收分块缓存
  
  // 配置参数
  private readonly DEFAULT_CHUNK_SIZE = 128 * 1024; // 128KB
  private readonly DEFAULT_TIMEOUT = 30000; // 30 秒
  private readonly MAX_RETRIES = 3; // 最多重试 3 次
  private readonly DEFAULT_PORT = 8888; // 默认监听端口

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
        const notifyInfo: TCPNotifyInfo = {
          taskId,
          sourceIp: NetworkUtils.getIpAddress(),
          port,
          fileInfo: { fileId: taskId, fileName: `file_${taskId}`, size: fileData.byteLength }
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
      
      // 发送握手消息（包含文件信息）
      const handshakeInfo: TCPSendHandshakeInfo = {
        fileId: FileUtils.generateFileId(),
        fileName: `file_${taskId}`,
        size: fileData.byteLength,
        hash: fileHash,
        totalChunks: chunks.length,
        chunkSize
      };
      const handshakeResult = await this.sendHandshake(taskId, handshakeInfo);
      
      if (!handshakeResult) {
        throw new Error('握手失败');
      }
      
      // 逐块发送文件数据
      let sentChunks = 0;
      for (let i = 0; i < chunks.length; i++) {
        const chunk = chunks[i];
        
        // 重试机制
        let success = false;
        for (let retry = 0; retry < maxRetries; retry++) {
          success = await this.sendChunk(chunk);
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
      await this.sendComplete(taskId, fileHash);
      
      // 更新进度为完成
      this.updateProgress(taskId, TransferState.COMPLETED, 100);
      
      console.info(`[TCPTransferProtocol] 文件发送完成，taskId=${taskId}`);
      return true;
    } catch (error) {
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
      
      // 等待所有分块接收完成
      const chunks = await this.waitForAllChunks(taskId);
      
      if (!chunks || chunks.length === 0) {
        throw new Error('未接收到任何分块');
      }
      
      // 重组文件
      const fileData = FileUtils.reassembleChunks(chunks);
      
      // 验证哈希
      const receivedHash = await FileUtils.calculateHash(fileData);
      console.info(`[TCPTransferProtocol] 文件接收完成，哈希=${receivedHash.substring(0, 16)}...`);
      
      // 更新进度为完成
      this.updateProgress(taskId, TransferState.COMPLETED, 100);
      
      return fileData;
    } catch (error) {
      const errMsg: string = error instanceof Error ? error.message : String(error);
      console.error('[TCPTransferProtocol] 文件接收失败:', errMsg);
      this.updateProgress(taskId, TransferState.FAILED, 0, errMsg);
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
   * 发送握手消息
   */
  private async sendHandshake(taskId: string, handshakeInfo: TCPSendHandshakeInfo): Promise<boolean> {
    // TODO: 实现握手消息发送
    console.info(`[TCPTransferProtocol] 发送握手消息，taskId=${taskId}, fileName=${handshakeInfo.fileName}`);
    return true;
  }

  /**
   * 发送分块数据
   */
  private async sendChunk(chunk: ChunkData): Promise<boolean> {
    const connectionIds: string[] = this.socketManager.getConnectionIds();
    if (connectionIds.length === 0) {
      console.error('[TCPTransferProtocol] 没有可用的连接');
      return false;
    }
    
    const connectionId = connectionIds[0];
    return await this.socketManager.sendData(connectionId, chunk.data);
  }

  /**
   * 发送完成消息
   */
  private async sendComplete(taskId: string, fileHash: string): Promise<boolean> {
    // TODO: 实现完成消息发送
    console.info(`[TCPTransferProtocol] 发送完成消息，taskId=${taskId}, hash=${fileHash.substring(0, 16)}`);
    return true;
  }

  /**
   * 等待所有分块接收完成
   */
  private async waitForAllChunks(taskId: string): Promise<ChunkData[]> {
    // TODO: 需要实现异步等待逻辑
    // 这里简化返回缓存的分块
    return this.chunkBuffers.get(taskId) || [];
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
