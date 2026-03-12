/**
 * 文件传输管理器
 * 统一管理所有文件传输任务，由调用方显式指定传输协议，提供完整的传输管理功能
 */
import {
  TransferProtocolInterface,
  TransferState,
  TransferProgress,
  TransferConfig,
  TransferNotifyCallback,
  CapableProtocolInterface,
  ProtocolCapabilities
} from './protocol/TransferProtocolInterface';
import { ProtocolRegistry } from './protocol/ProtocolRegistry';
import { MQTTTransferProtocol } from './protocol/MQTTTransferProtocol';
import { TCPTransferProtocol } from './protocol/TCPTransferProtocol';
import { FileInfo, TransferTask, TransferOptions, TransferNotifyInfo } from './model/TransferDataModels';
import { NetworkUtils } from './utils/NetworkUtils';
import { TransferEventManager } from './event/TransferEvents';
import {
  TransferResult,
  TransferErrorCode,
  createSuccessResult,
  createErrorResult,
  errorFromException,
  FileTransferCompleteResult,
  TransferTaskStatus
} from './model/TransferResult';
import { sleep, generateUniqueId, cleanupExpiredEntries } from './utils/CommonUtils';

/**
 * 传输就绪通知回调类型——重新导出以保持向后兼容
 */
export { TransferNotifyCallback };

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

  /** 任务重试计数 */
  private retryCountMap: Map<string, number> = new Map();

  /** 默认配置 */
  private defaultOptions: TransferOptions = {
    sizeThreshold: 2 * 1024 * 1024, // 2MB
    tcpChunkSize: 128 * 1024,       // 128KB
    maxRetries: 3,
    timeout: 30000,
    tcpPort: 8888
  };

  /** 任务清理间隔（毫秒） */
  private readonly CLEANUP_INTERVAL = 60 * 60 * 1000; // 1小时

  /** 任务过期时间（毫秒） */
  private readonly TASK_EXPIRY_TIME = 60 * 60 * 1000; // 1小时

  private constructor() {
    this.protocolRegistry = ProtocolRegistry.getInstance();
    this.eventManager = TransferEventManager.getInstance();

    // 初始化时注册默认协议
    this.registerDefaultProtocols();

    // 启动定期清理任务
    this.startCleanupTask();
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
      // 注册 MQTT 协议
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
   * 启动定期清理任务
   */
  private startCleanupTask(): void {
    setInterval(() => {
      this.cleanupCompletedTasks();
    }, this.CLEANUP_INTERVAL);
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
   * 获取默认配置
   * @returns 当前默认配置
   */
  getDefaultOptions(): TransferOptions {
    const result: TransferOptions = {
      sizeThreshold: this.defaultOptions.sizeThreshold,
      tcpChunkSize: this.defaultOptions.tcpChunkSize,
      maxRetries: this.defaultOptions.maxRetries,
      timeout: this.defaultOptions.timeout,
      tcpPort: this.defaultOptions.tcpPort
    };
    return result;
  }

  /**
   * 发起文件传输
   * 调用方通过 protocolName 显式指定协议，协议内部自行处理传输全流程
   * @param fileData - 文件数据
   * @param fileInfo - 文件信息
   * @param targetDevice - 目标设备标识
   * @param protocolName - 指定使用的传输协议名称
   * @param notifyCallback - 传输就绪后的通知回调（可选）
   * @returns 传输结果
   */
  async transferFile(
    fileData: ArrayBuffer | string,
    fileInfo: FileInfo,
    targetDevice: string,
    protocolName: string,
    notifyCallback?: TransferNotifyCallback
  ): Promise<TransferResult<FileTransferCompleteResult>> {
    // 生成或使用传入的 taskId
    const taskId = fileInfo.fileId && fileInfo.fileId.length > 0
      ? fileInfo.fileId
      : generateUniqueId('task');

    console.info(`[FileTransferManager] 任务 ${taskId} 使用协议：${protocolName}`);

    // 创建任务记录
    const task: TransferTask = {
      taskId,
      fileInfo,
      sourceDevice: NetworkUtils.getIpAddress(),
      targetDevice,
      protocol: protocolName,
      state: TransferState.PENDING,
      createdAt: Date.now()
    };
    this.taskQueue.set(taskId, task);
    this.retryCountMap.set(taskId, 0);

    // 获取协议实例
    const protocol = this.protocolRegistry.getProtocol(protocolName);
    if (!protocol) {
      task.state = TransferState.FAILED;
      const error = createErrorResult(
        taskId,
        TransferErrorCode.PROTOCOL_NOT_FOUND,
        `协议 ${protocolName} 未找到`
      );
      this.eventManager.emitTransferFailed(taskId, error.error!.message);
      return error;
    }

    // 触发开始事件
    this.eventManager.emitTransferStart(taskId, protocolName);
    task.state = TransferState.TRANSFERRING;
    task.startedAt = Date.now();

    try {
      // 构造传输配置
      const sendConfig: TransferConfig = {
        chunkSize: this.defaultOptions.tcpChunkSize,
        maxRetries: this.defaultOptions.maxRetries,
        timeout: this.defaultOptions.timeout,
        notifyCallback,
        fileInfo,
        sourceDevice: task.sourceDevice,
        targetDevice
      };

      // 执行传输
      const sendResult = await protocol.send(fileData, taskId, sendConfig);

      if (sendResult.success) {
        // 传输成功
        task.state = TransferState.COMPLETED;
        task.completedAt = Date.now();

        const duration = task.completedAt - (task.startedAt ?? task.completedAt);
        const completeResult: FileTransferCompleteResult = {
          fileInfo,
          duration,
          transferredBytes: fileInfo.size,
          averageSpeed: fileInfo.size / (duration / 1000),
          protocol: protocolName
        };

        this.eventManager.emitTransferComplete(taskId, completeResult);
        console.info(`[FileTransferManager] 传输完成，taskId=${taskId}`);

        return createSuccessResult(taskId, completeResult);
      } else {
        // 传输失败
        task.state = TransferState.FAILED;
        const errorMsg = sendResult.error?.message || '传输失败';
        this.eventManager.emitTransferFailed(taskId, errorMsg);
        console.error(`[FileTransferManager] 传输失败，taskId=${taskId}`);

        return createErrorResult(
          taskId,
          sendResult.error?.code || TransferErrorCode.TRANSFER_FAILED,
          errorMsg,
          sendResult.error?.details
        );
      }
    } catch (error) {
      // 处理异常
      const transferError = errorFromException(error, TransferErrorCode.TRANSFER_FAILED);
      task.state = TransferState.FAILED;
      this.eventManager.emitTransferFailed(taskId, transferError.message);
      console.error('[FileTransferManager] 传输异常:', transferError.message);

      return createErrorResult(
        taskId,
        transferError.code,
        transferError.message,
        transferError.details,
        transferError.cause
      );
    } finally {
      // 传输完成后断开连接，释放资源
      // 对于 TCP 等需要长连接的协议，这一步尤为重要
      try {
        const disconnectResult = await protocol.disconnect();
        if (disconnectResult.success) {
          console.info(`[FileTransferManager] 连接已断开，taskId=${taskId}, protocol=${protocolName}`);
        } else {
          console.warn(`[FileTransferManager] 断开连接失败，taskId=${taskId}, error=${disconnectResult.error?.message}`);
        }
      } catch (disconnectError) {
        console.warn('[FileTransferManager] 断开连接时发生异常:', disconnectError);
      }
    }
  }

  /**
   * 接收文件（接收端入口）
   * 调用方通过 protocolName 显式指定协议，协议内部自行处理接收全流程
   * FileTransferManager 层无需感知具体协议实现细节
   * @param taskId - 任务 ID
   * @param sourceDevice - 源设备标识（如 IP 地址或设备 ID，具体含义由协议决定）
   * @param fileInfo - 文件元数据
   * @param protocolName - 指定使用的传输协议名称（需已在 ProtocolRegistry 中注册）
   * @param options - 可选传输配置
   * @returns 接收结果，包含文件数据
   */
  async receiveFile(
    taskId: string,
    sourceDevice: string,
    fileInfo: FileInfo,
    protocolName: string,
    options?: TransferOptions
  ): Promise<TransferResult<ArrayBuffer | string>> {
    console.info(`[FileTransferManager] 开始接收文件，taskId=${taskId}, protocol=${protocolName}, sourceDevice=${sourceDevice}`);

    // 记录接收任务
    const task: TransferTask = {
      taskId,
      fileInfo,
      sourceDevice: sourceDevice,
      targetDevice: NetworkUtils.getIpAddress(),
      protocol: protocolName,
      state: TransferState.CONNECTING,
      createdAt: Date.now(),
      startedAt: Date.now()
    };
    this.taskQueue.set(taskId, task);

    // 获取指定协议实例
    const protocol = this.protocolRegistry.getProtocol(protocolName);
    if (!protocol) {
      task.state = TransferState.FAILED;
      const error = createErrorResult(
        taskId,
        TransferErrorCode.PROTOCOL_NOT_FOUND,
        `协议 ${protocolName} 未注册`
      );
      this.eventManager.emitTransferFailed(taskId, error.error!.message);
      return error;
    }

    this.eventManager.emitTransferStart(taskId, protocolName);

    try {
      // 构造传输配置
      // 所有连接参数都通过 TransferConfig 传递，协议实现自行解析所需参数
      const config: TransferConfig = {
        taskId,
        chunkSize: options?.tcpChunkSize ?? this.defaultOptions.tcpChunkSize,
        maxRetries: options?.maxRetries ?? this.defaultOptions.maxRetries,
        timeout: options?.timeout ?? this.defaultOptions.timeout,
        fileInfo,
        sourceDevice,
        targetDevice: NetworkUtils.getIpAddress(),
        host: sourceDevice,  // 对于 TCP 等协议，sourceDevice 即为 host
        port: options?.tcpPort ?? this.defaultOptions.tcpPort ?? 8888,
      };


      // 调用协议实现的 connect 方法
      // 协议实现从 config 中获取连接所需的参数
      const connectResult = await protocol.connect(config);

      if (!connectResult.success) {
        task.state = TransferState.FAILED;
        const errorMsg = connectResult.error?.message || `无法连接到源设备 ${sourceDevice}`;
        this.eventManager.emitTransferFailed(taskId, errorMsg);
        return createErrorResult(
          taskId,
          connectResult.error?.code || TransferErrorCode.CONNECTION_FAILED,
          errorMsg
        );
      }

      task.state = TransferState.TRANSFERRING;

      // 接收文件数据
      const receiveResult = await protocol.receive(taskId);

      if (receiveResult.success) {
        // 接收成功
        task.state = TransferState.COMPLETED;
        task.completedAt = Date.now();

        const duration = task.completedAt - (task.startedAt ?? task.completedAt);
        const completeResult: FileTransferCompleteResult = {
          fileInfo,
          duration,
          transferredBytes: fileInfo.size,
          averageSpeed: fileInfo.size / (duration / 1000),
          protocol: protocolName
        };

        this.eventManager.emitTransferComplete(taskId, completeResult);
        console.info(`[FileTransferManager] 文件接收完成，taskId=${taskId}`);

        return createSuccessResult(taskId, receiveResult.data);
      } else {
        // 接收失败
        task.state = TransferState.FAILED;
        const errorMsg = receiveResult.error?.message || '文件接收失败';
        this.eventManager.emitTransferFailed(taskId, errorMsg);
        return createErrorResult(
          taskId,
          receiveResult.error?.code || TransferErrorCode.RECEIVE_FAILED,
          errorMsg
        );
      }
    } catch (error) {
      const transferError = errorFromException(error, TransferErrorCode.RECEIVE_FAILED);
      task.state = TransferState.FAILED;
      this.eventManager.emitTransferFailed(taskId, transferError.message);
      console.error('[FileTransferManager] 文件接收失败:', transferError.message);

      return createErrorResult(
        taskId,
        transferError.code,
        transferError.message,
        transferError.details,
        transferError.cause
      );
    } finally {
      // 接收完成后断开连接，释放资源
      // 对于 TCP 等需要长连接的协议，这一步尤为重要
      try {
        const disconnectResult = await protocol.disconnect();
        if (disconnectResult.success) {
          console.info(`[FileTransferManager] 连接已断开，taskId=${taskId}, protocol=${protocolName}`);
        } else {
          console.warn(`[FileTransferManager] 断开连接失败，taskId=${taskId}, error=${disconnectResult.error?.message}`);
        }
      } catch (disconnectError) {
        console.warn('[FileTransferManager] 断开连接时发生异常:', disconnectError);
      }
    }
  }

  /**
   * 取消传输任务
   * @param taskId - 任务 ID
   * @returns 取消操作结果
   */
  async cancelTransfer(taskId: string): Promise<TransferResult<boolean>> {
    const task = this.taskQueue.get(taskId);
    if (!task) {
      console.warn(`[FileTransferManager] 任务不存在：${taskId}`);
      return createErrorResult(
        taskId,
        TransferErrorCode.INVALID_PARAMETER,
        `任务 ${taskId} 不存在`
      );
    }

    try {
      // 获取协议实例
      const protocol = this.protocolRegistry.getProtocol(task.protocol);
      if (protocol) {
        const cancelResult = await protocol.cancel(taskId);
        if (!cancelResult.success) {
          console.warn(`[FileTransferManager] 协议层取消任务失败：${cancelResult.error?.message}`);
        }
      }

      // 更新任务状态
      task.state = TransferState.CANCELLED;

      // 触发取消事件
      this.eventManager.emitTransferCancelled(taskId);

      console.info(`[FileTransferManager] 任务已取消，taskId=${taskId}`);
      return createSuccessResult(taskId, true);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      console.error('[FileTransferManager] 取消任务失败:', errMsg);
      return createErrorResult(
        taskId,
        TransferErrorCode.UNKNOWN_ERROR,
        `取消任务失败: ${errMsg}`
      );
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
  getTransferState(taskId: string): TransferState | null {
    const task = this.taskQueue.get(taskId);
    return task ? task.state as TransferState : null;
  }

  /**
   * 获取任务完整状态信息
   * @param taskId - 任务 ID
   * @returns 任务状态信息
   */
  getTaskStatus(taskId: string): TransferTaskStatus | null {
    const task = this.taskQueue.get(taskId);
    if (!task) {
      return null;
    }

    const progress = this.getTransferProgress(taskId);
    const retryCount = this.retryCountMap.get(taskId) ?? 0;

    return {
      taskId,
      state: task.state as TransferState,
      progress: progress ?? {
        taskId,
        state: task.state as TransferState,
        transferredBytes: 0,
        totalBytes: task.fileInfo.size,
        progress: 0
      },
      startedAt: task.startedAt,
      completedAt: task.completedAt,
      retryCount
    };
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
      task => task.state === TransferState.PENDING || task.state === TransferState.TRANSFERRING
    );
  }

  /**
   * 清理已完成的任务
   * @param maxAge - 最大保留时间（毫秒），默认 1 小时
   * @returns 清理的任务数量
   */
  cleanupCompletedTasks(maxAge: number = this.TASK_EXPIRY_TIME): number {
    const now = Date.now();

    const cleanedCount = cleanupExpiredEntries(this.taskQueue, (task) => {
      if (task.state === TransferState.COMPLETED ||
          task.state === TransferState.CANCELLED ||
          task.state === TransferState.FAILED) {
        return task.completedAt !== undefined && (now - task.completedAt > maxAge);
      }
      return false;
    });

    // 同时清理重试计数
    this.taskQueue.forEach((task, taskId) => {
      if (!this.taskQueue.has(taskId)) {
        this.retryCountMap.delete(taskId);
      }
    });

    if (cleanedCount > 0) {
      console.info(`[FileTransferManager] 清理了 ${cleanedCount} 个已完成任务`);
    }

    return cleanedCount;
  }

  /**
   * 注册自定义协议
   * @param protocolName - 协议名称
   * @param protocol - 协议实现
   * @returns 注册结果
   */
  registerCustomProtocol(protocolName: string, protocol: TransferProtocolInterface): TransferResult<boolean> {
    try {
      this.protocolRegistry.registerProtocol(protocolName, protocol);
      console.info(`[FileTransferManager] 自定义协议 ${protocolName} 注册成功`);
      return createSuccessResult('register', true);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      console.error(`[FileTransferManager] 注册协议 ${protocolName} 失败:`, errMsg);
      return createErrorResult(
        'register',
        TransferErrorCode.PROTOCOL_INITIALIZATION_FAILED,
        `注册协议失败: ${errMsg}`
      );
    }
  }

  /**
   * 注销协议
   * @param protocolName - 协议名称
   * @returns 注销结果
   */
  unregisterProtocol(protocolName: string): TransferResult<boolean> {
    try {
      this.protocolRegistry.unregisterProtocol(protocolName);
      console.info(`[FileTransferManager] 协议 ${protocolName} 已注销`);
      return createSuccessResult('unregister', true);
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      console.error(`[FileTransferManager] 注销协议 ${protocolName} 失败:`, errMsg);
      return createErrorResult(
        'unregister',
        TransferErrorCode.UNKNOWN_ERROR,
        `注销协议失败: ${errMsg}`
      );
    }
  }

  /**
   * 列出所有可用协议
   * @returns 协议名称数组
   */
  listProtocols(): string[] {
    return this.protocolRegistry.listProtocols();
  }

  /**
   * 获取协议能力信息
   * @param protocolName - 协议名称
   * @returns 协议能力信息，如果协议不存在或不可查询能力则返回 null
   */
  getProtocolCapabilities(protocolName: string): ProtocolCapabilities | null {
    const protocol = this.protocolRegistry.getProtocol(protocolName);
    if (!protocol) {
      return null;
    }

    // 检查协议是否实现了能力查询接口
    const capableProtocol = protocol as CapableProtocolInterface;
    if (typeof capableProtocol.getCapabilities === 'function') {
      return capableProtocol.getCapabilities();
    }

    return null;
  }

  /**
   * 检查协议是否支持特定功能
   * @param protocolName - 协议名称
   * @param capability - 能力名称
   * @returns 是否支持
   */
  isCapabilitySupported(protocolName: string, capability: string): boolean {
    const capabilities = this.getProtocolCapabilities(protocolName);
    if (!capabilities) {
      return false;
    }
    // 根据 capability 名称返回对应的能力值
    if (capability === 'supportsLargeFiles') {
      return capabilities.supportsLargeFiles === true;
    } else if (capability === 'supportsChunking') {
      return capabilities.supportsChunking === true;
    } else if (capability === 'supportsResume') {
      return capabilities.supportsResume === true;
    } else if (capability === 'supportsProgress') {
      return capabilities.supportsProgress === true;
    } else if (capability === 'supportsCancellation') {
      return capabilities.supportsCancellation === true;
    } else if (capability === 'requiresActiveConnection') {
      return capabilities.requiresActiveConnection === true;
    }
    return false;
  }
}
