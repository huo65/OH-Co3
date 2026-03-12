/**
 * MQTT 文件传输协议实现
 * 基于现有 MQTT 客户端，处理小文件（≤2MB）的直接传输
 */
import {
  TransferProtocolInterface,
  TransferConfig,
  TransferState,
  TransferProgress,
  CapableProtocolInterface,
  ProtocolCapabilities
} from '../protocol/TransferProtocolInterface';
import { MQTTClient } from '../../broker/MQTTClient';
import { FileInfo } from '../model/TransferDataModels';
import { FileUtils } from '../utils/FileUtils';
import {
  TransferResult,
  TransferErrorCode,
  createSuccessResult,
  createErrorResult,
  errorFromException
} from '../model/TransferResult';
import { sleep, retry } from '../utils/CommonUtils';

/**
 * MQTT 协议能力定义
 */
const MQTT_CAPABILITIES: ProtocolCapabilities = {
  supportsLargeFiles: false,
  maxFileSize: 2 * 1024 * 1024, // 2MB
  supportsChunking: false,
  defaultChunkSize: 0,
  supportsResume: false,
  supportsProgress: false,
  supportsCancellation: true,
  requiresActiveConnection: false
};

/**
 * MQTT 传输配置
 */
interface MQTTTransferConfig {
  /** 文件传输主题 */
  topic: string;
  /** QoS 等级 */
  qos: number;
  /** 是否保留消息 */
  retain: boolean;
}

/**
 * MQTT 文件传输协议实现类
 */
export class MQTTTransferProtocol implements CapableProtocolInterface {
  private mqttClient: MQTTClient;
  private progressMap: Map<string, TransferProgress> = new Map();

  private readonly DEFAULT_TIMEOUT = 30000;
  private readonly MAX_RETRIES = 3;
  private readonly DEFAULT_TOPIC = '/file/transfer';
  private readonly DEFAULT_QOS = 1;

  /** MQTT 传输配置 */
  private mqttConfig: MQTTTransferConfig = {
    topic: this.DEFAULT_TOPIC,
    qos: this.DEFAULT_QOS,
    retain: false
  };

  constructor() {
    this.mqttClient = MQTTClient.getInstance();
  }

  /**
   * 获取协议名称
   */
  getProtocolName(): string {
    return 'MQTT';
  }

  /**
   * 获取协议能力信息
   */
  getCapabilities(): ProtocolCapabilities {
    const result: ProtocolCapabilities = {
      supportsLargeFiles: MQTT_CAPABILITIES.supportsLargeFiles,
      maxFileSize: MQTT_CAPABILITIES.maxFileSize,
      supportsChunking: MQTT_CAPABILITIES.supportsChunking,
      defaultChunkSize: MQTT_CAPABILITIES.defaultChunkSize,
      supportsResume: MQTT_CAPABILITIES.supportsResume,
      supportsProgress: MQTT_CAPABILITIES.supportsProgress,
      supportsCancellation: MQTT_CAPABILITIES.supportsCancellation,
      requiresActiveConnection: MQTT_CAPABILITIES.requiresActiveConnection
    };
    return result;
  }

  /**
   * 设置 MQTT 传输配置
   * @param config - MQTT 配置
   */
  setMQTTConfig(config: Partial<MQTTTransferConfig>): void {
    if (config.topic !== undefined) {
      this.mqttConfig.topic = config.topic;
    }
    if (config.qos !== undefined) {
      this.mqttConfig.qos = config.qos;
    }
    if (config.retain !== undefined) {
      this.mqttConfig.retain = config.retain;
    }
  }

  /**
   * 连接到 MQTT 服务器
   * MQTT 连接在初始化时已建立，这里只检查连接状态
   */
  async connect(host: string, port: number, config?: TransferConfig): Promise<TransferResult<boolean>> {
    try {
      const isConnected = await this.mqttClient.isCon();
      if (isConnected) {
        console.info('[MQTTTransferProtocol] MQTT 已连接');
        return createSuccessResult('connect', true);
      } else {
        console.warn('[MQTTTransferProtocol] MQTT 未连接');
        return createErrorResult(
          'connect',
          TransferErrorCode.MQTT_NOT_CONNECTED,
          'MQTT 客户端未连接'
        );
      }
    } catch (error) {
      console.error('[MQTTTransferProtocol] 检查连接失败:', error);
      return createErrorResult(
        'connect',
        TransferErrorCode.MQTT_NOT_CONNECTED,
        `检查 MQTT 连接失败: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  /**
   * 断开 MQTT 连接
   * 注意：通常不需要主动断开 MQTT 连接
   */
  async disconnect(): Promise<TransferResult<boolean>> {
    console.info('[MQTTTransferProtocol] MQTT 协议通常不需要主动断开连接');
    return createSuccessResult('disconnect', true);
  }

  /**
   * 检查 MQTT 连接状态
   */
  isConnected(): boolean {
    return this.mqttClient !== null;
  }

  /**
   * 发送文件数据
   * @param data - 文件数据（ArrayBuffer 或 Base64 编码的字符串）
   * @param taskId - 任务 ID
   * @param config - 传输配置
   * @returns 发送结果
   */
  async send(data: ArrayBuffer | string, taskId: string, config?: TransferConfig): Promise<TransferResult<boolean>> {
    const timeout = config?.timeout || this.DEFAULT_TIMEOUT;
    const maxRetries = config?.maxRetries || this.MAX_RETRIES;

    // 更新进度为传输中
    this.updateProgress(taskId, TransferState.TRANSFERRING, 0, 0, 0);

    try {
      // 检查文件大小限制
      let dataSize: number;
      if (data instanceof ArrayBuffer) {
        dataSize = data.byteLength;
        if (dataSize > MQTT_CAPABILITIES.maxFileSize) {
          return createErrorResult(
            taskId,
            TransferErrorCode.FILE_TOO_LARGE,
            `文件大小 ${dataSize} 字节超过 MQTT 协议限制 ${MQTT_CAPABILITIES.maxFileSize} 字节`
          );
        }
      } else {
        dataSize = data.length;
      }

      // 转换数据格式
      let payload: string;
      if (data instanceof ArrayBuffer) {
        payload = FileUtils.arrayBufferToBase64(data);
      } else {
        payload = data;
      }

      // 使用重试机制发送
      const sendOperation = async (): Promise<void> => {
        await this.mqttClient.pushMessage(payload, this.mqttConfig.topic);
      };

      await retry(sendOperation, maxRetries, 1000);

      // 更新进度为完成
      this.updateProgress(taskId, TransferState.COMPLETED, 100, dataSize, dataSize);
      console.info(`[MQTTTransferProtocol] 文件发送成功，taskId=${taskId}`);

      return createSuccessResult(taskId, true);
    } catch (error) {
      const transferError = errorFromException(error, TransferErrorCode.MQTT_PUBLISH_FAILED);
      console.error(`[MQTTTransferProtocol] 文件发送失败:`, transferError.message);
      this.updateProgress(taskId, TransferState.FAILED, 0, 0, 0, undefined, undefined, transferError.message);

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
   * MQTT 是推送模式，接收方通过事件监听获取数据
   * 这个方法主要用于协议接口的一致性
   */
  async receive(taskId: string): Promise<TransferResult<ArrayBuffer | string>> {
    console.info('[MQTTTransferProtocol] MQTT 接收通过事件监听实现，此方法返回空数据');
    return createSuccessResult(taskId, '');
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
    console.info(`[MQTTTransferProtocol] 取消传输任务：${taskId}`);
    this.updateProgress(taskId, TransferState.CANCELLED, 0, 0, 0);
    return createSuccessResult(taskId, true);
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

    // 清理已完成的进度记录
    if (state === TransferState.COMPLETED || state === TransferState.FAILED || state === TransferState.CANCELLED) {
      setTimeout(() => {
        this.progressMap.delete(taskId);
      }, 60000);
    }
  }
}
