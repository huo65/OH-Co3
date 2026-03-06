/**
 * 文件传输管理器
 * 统一管理所有文件传输任务，自动选择传输协议，提供完整的传输管理功能
 */
import { TransferProtocolInterface, TransferState, TransferProgress, TransferConfig } from './protocol/TransferProtocolInterface';
import { ProtocolRegistry } from './protocol/ProtocolRegistry';
import { MQTTTransferProtocol } from './protocol/MQTTTransferProtocol';
import { TCPTransferProtocol } from './protocol/TCPTransferProtocol';
import { FileInfo, TransferTask, TransferOptions } from './model/TransferDataModels';
import { NetworkUtils } from './utils/NetworkUtils';
import { TransferEventManager } from './event/TransferEvents';

/**
 * 文件传输管理器类
 * 提供统一的文件传输管理接口
 */
export class FileTransferManager {
  private static instance: FileTransferManager;
  
  /** 协议注册中心 */
  private protocolRegistry: ProtocolRegistry;
  
  /** 事件管理器 */
  private eventManager: TransferEventManager;
  
  /** 传输任务队列 */
  private taskQueue: Map<string, TransferTask> = new Map();
  
  /** 默认配置 */
  private defaultOptions: TransferOptions = {
    sizeThreshold: 2 * 1024 * 1024, // 2MB
    tcpChunkSize: 128 * 1024,       // 128KB
    maxRetries: 3,
    timeout: 30000,
    tcpPort: 8888
  };

  private constructor() {
    this.protocolRegistry = ProtocolRegistry.getInstance();
    this.eventManager = TransferEventManager.getInstance();
    
    // 初始化时注册默认协议
    this.registerDefaultProtocols();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): FileTransferManager {
    if (!FileTransferManager.instance) {
      FileTransferManager.instance = new FileTransferManager();
    }
    return FileTransferManager.instance;
  }

  /**
   * 注册默认协议
   */
  private registerDefaultProtocols(): void {
    try {
      // 注册 MQTT协议
      const mqttProtocol = new MQTTTransferProtocol();
      this.protocolRegistry.registerProtocol('MQTT', mqttProtocol);
      
      // 注册 TCP 协议
      const tcpProtocol = new TCPTransferProtocol();
      this.protocolRegistry.registerProtocol('TCP', tcpProtocol);
      
      console.info('[FileTransferManager] 默认协议注册完成');
    } catch (error) {
      console.error('[FileTransferManager] 协议注册失败:', error);
    }
  }

  /**
   * 设置默认配置
   * @param options - 配置选项
   */
  setDefaultOptions(options: TransferOptions): void {
    if (options.sizeThreshold !== undefined) {
      this.defaultOptions.sizeThreshold = options.sizeThreshold;
    }
    if (options.tcpChunkSize !== undefined) {
      this.defaultOptions.tcpChunkSize = options.tcpChunkSize;
    }
    if (options.maxRetries !== undefined) {
      this.defaultOptions.maxRetries = options.maxRetries;
    }
    if (options.timeout !== undefined) {
      this.defaultOptions.timeout = options.timeout;
    }
    if (options.tcpPort !== undefined) {
      this.defaultOptions.tcpPort = options.tcpPort;
    }
    console.info('[FileTransferManager] 默认配置已更新');
  }

  /**
   * 发起文件传输
   * @param fileData - 文件数据
   * @param fileInfo - 文件信息
   * @param targetDevice - 目标设备标识
   * @returns 任务 ID
   */
  async transferFile(
    fileData: ArrayBuffer | string,
    fileInfo: FileInfo,
    targetDevice: string
  ): Promise<string> {
    try {
      // 生成任务 ID
      const taskId = `task_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      
      // 根据文件大小选择协议
      const protocolName = this.selectProtocol(fileInfo.size);
      console.info(`[FileTransferManager] 任务 ${taskId} 使用协议：${protocolName}`);
      
      // 创建传输任务
      const task: TransferTask = {
        taskId,
        fileInfo,
        sourceDevice: NetworkUtils.getIpAddress(),
        targetDevice,
        protocol: protocolName,
        state: 'pending',
        createdAt: Date.now()
      };
      
      // 保存任务
      this.taskQueue.set(taskId, task);
      
      // 获取协议实例
      const protocol = this.protocolRegistry.getProtocol(protocolName);
      if (!protocol) {
        throw new Error(`协议 ${protocolName} 未找到`);
      }
      
      // 触发传输开始事件
      this.eventManager.emitTransferStart(taskId, protocolName);
      
      // 更新任务状态
      task.state = 'transferring';
      task.startedAt = Date.now();
      
      // 执行传输
      let success = false;
      if (protocolName === 'TCP') {
        // TCP 传输需要额外参数
        success = await this.transferViaTCP(protocol as TCPTransferProtocol, fileData, taskId, targetDevice);
      } else {
        // MQTT 传输
        success = await protocol.send(fileData, taskId);
      }
      
      // 更新任务状态
      if (success) {
        task.state = 'completed';
        task.completedAt = Date.now();
        
        // 触发完成事件
        interface CompleteResult {
          fileInfo: FileInfo;
          duration: number;
        }
        const completeResult: CompleteResult = {
          fileInfo,
          duration: task.completedAt - (task.startedAt ?? task.completedAt)
        };
        this.eventManager.emitTransferComplete(taskId, completeResult);
        
        console.info(`[FileTransferManager] 传输完成，taskId=${taskId}`);
      } else {
        task.state = 'failed';
        
        // 触发失败事件
        this.eventManager.emitTransferFailed(taskId, '传输失败');
        
        console.error(`[FileTransferManager] 传输失败，taskId=${taskId}`);
      }
      
      return taskId;
    } catch (error) {
      const errMsg: string = error instanceof Error ? error.message : String(error);
      console.error('[FileTransferManager] 传输异常:', errMsg);
      throw new Error(errMsg);
    }
  }

  /**
   * 通过 TCP 协议传输文件
   */
  private async transferViaTCP(
    protocol: TCPTransferProtocol,
    fileData: ArrayBuffer | string,
    taskId: string,
    targetDevice: string
  ): Promise<boolean> {
    try {
      // 获取本机 IP
      const localIp = NetworkUtils.getIpAddress();
      const port = this.defaultOptions.tcpPort!;
      
      // 启动服务器监听（如果还没启动）
      if (!protocol.isConnected()) {
        await protocol.startServer(port);
      }
      
      // TODO: 这里需要先通过 MQTT 通知目标设备发起 TCP 连接
      // 目标设备收到后会主动连接到 localIp:port
      
      // 等待连接建立后发送数据
      const config: TransferConfig = {
        chunkSize: this.defaultOptions.tcpChunkSize,
        maxRetries: this.defaultOptions.maxRetries,
        timeout: this.defaultOptions.timeout
      };
      
      return await protocol.send(fileData, taskId, config);
    } catch (error) {
      console.error('[FileTransferManager] TCP 传输失败:', error);
      return false;
    }
  }

  /**
   * 选择传输协议
   * @param fileSize - 文件大小（字节）
   * @returns 协议名称
   */
  private selectProtocol(fileSize: number): string {
    const threshold = this.defaultOptions.sizeThreshold!;
    
    if (fileSize > threshold) {
      console.info(`[FileTransferManager] 文件大小 ${fileSize} 字节 > ${threshold} 字节，使用 TCP 协议`);
      return 'TCP';
    } else {
      console.info(`[FileTransferManager] 文件大小 ${fileSize} 字节 <= ${threshold} 字节，使用 MQTT协议`);
      return 'MQTT';
    }
  }

  /**
   * 取消传输任务
   * @param taskId - 任务 ID
   * @returns 是否取消成功
   */
  async cancelTransfer(taskId: string): Promise<boolean> {
    const task = this.taskQueue.get(taskId);
    if (!task) {
      console.warn(`[FileTransferManager] 任务不存在：${taskId}`);
      return false;
    }

    try {
      // 获取协议实例
      const protocol = this.protocolRegistry.getProtocol(task.protocol);
      if (protocol) {
        await protocol.cancel(taskId);
      }
      
      // 更新任务状态
      task.state = 'cancelled';
      
      // 触发取消事件
      this.eventManager.emitTransferCancelled(taskId);
      
      console.info(`[FileTransferManager] 任务已取消，taskId=${taskId}`);
      return true;
    } catch (error) {
      console.error('[FileTransferManager] 取消任务失败:', error);
      return false;
    }
  }

  /**
   * 获取传输进度
   * @param taskId - 任务 ID
   * @returns 传输进度信息
   */
  getTransferProgress(taskId: string): TransferProgress | null {
    const task = this.taskQueue.get(taskId);
    if (!task) {
      console.warn(`[FileTransferManager] 任务不存在：${taskId}`);
      return null;
    }

    // 获取协议实例
    const protocol = this.protocolRegistry.getProtocol(task.protocol);
    if (protocol) {
      return protocol.getProgress(taskId);
    }
    
    return null;
  }

  /**
   * 获取任务状态
   * @param taskId - 任务 ID
   * @returns 任务状态
   */
  getTransferState(taskId: string): string | null {
    const task = this.taskQueue.get(taskId);
    return task ? task.state : null;
  }

  /**
   * 获取所有任务
   * @returns 任务数组
   */
  getAllTasks(): TransferTask[] {
    return Array.from(this.taskQueue.values());
  }

  /**
   * 获取活动任务
   * @returns 活动任务数组
   */
  getActiveTasks(): TransferTask[] {
    return Array.from(this.taskQueue.values()).filter(
      task => task.state === 'pending' || task.state === 'transferring'
    );
  }

  /**
   * 清理已完成的任务
   */
  cleanupCompletedTasks(): void {
    const now = Date.now();
    const oneHourAgo = 60 * 60 * 1000; // 1 小时
    
    const taskIds: string[] = Array.from(this.taskQueue.keys());
    for (let i = 0; i < taskIds.length; i++) {
      const taskId = taskIds[i];
      const task = this.taskQueue.get(taskId);
      if (!task) {
        continue;
      }
      if (task.state === 'completed' || task.state === 'cancelled' || task.state === 'failed') {
        // 超过 1 小时的任务清理掉
        if (task.completedAt && (now - task.completedAt > oneHourAgo)) {
          this.taskQueue.delete(taskId);
          console.info(`[FileTransferManager] 清理已完成任务：${taskId}`);
        }
      }
    }
  }

  /**
   * 注册自定义协议
   * @param protocolName - 协议名称
   * @param protocol - 协议实现
   */
  registerCustomProtocol(protocolName: string, protocol: TransferProtocolInterface): void {
    this.protocolRegistry.registerProtocol(protocolName, protocol);
    console.info(`[FileTransferManager] 自定义协议 ${protocolName} 注册成功`);
  }

  /**
   * 注销协议
   * @param protocolName - 协议名称
   */
  unregisterProtocol(protocolName: string): void {
    this.protocolRegistry.unregisterProtocol(protocolName);
    console.info(`[FileTransferManager] 协议 ${protocolName} 已注销`);
  }

  /**
   * 列出所有可用协议
   * @returns 协议名称数组
   */
  listProtocols(): string[] {
    return this.protocolRegistry.listProtocols();
  }
}
