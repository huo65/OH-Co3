/**
 * MQTT 文件传输协议实现
 * 基于现有 MQTT 客户端，处理小文件（≤2MB）的直接传输
 */
import { TransferProtocolInterface, TransferConfig, TransferState, TransferProgress } from '../protocol/TransferProtocolInterface';
import { MQTTClient } from '../../broker/MQTTClient';
import { FileInfo } from '../model/TransferDataModels';
import { FileUtils } from '../utils/FileUtils';
// TODO 使用类似TCP的思想，开一个单独的主题
export class MQTTTransferProtocol implements TransferProtocolInterface {
  private mqttClient: MQTTClient;
  private progressMap: Map<string, TransferProgress> = new Map();
  private readonly DEFAULT_TIMEOUT = 30000; // 30 秒超时
  private readonly MAX_RETRIES = 3; // 最多重试 3 次

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
   * 连接到 MQTT 服务器
   * MQTT 连接在初始化时已建立，这里只检查连接状态
   */
  async connect(host: string, port: number, config?: TransferConfig): Promise<boolean> {
    try {
      const isConnected = await this.mqttClient.isCon();
      if (isConnected) {
        console.info('[MQTTTransferProtocol] MQTT 已连接');
        return true;
      } else {
        console.warn('[MQTTTransferProtocol] MQTT 未连接，尝试重新初始化');
        // 注意：正常情况下 MQTT 应该在应用启动时就连接好了
        return false;
      }
    } catch (error) {
      console.error('[MQTTTransferProtocol] 检查连接失败:', error);
      return false;
    }
  }

  /**
   * 断开 MQTT 连接
   * 注意：通常不需要主动断开 MQTT 连接
   */
  async disconnect(): Promise<boolean> {
    console.info('[MQTTTransferProtocol] MQTT协议通常不需要主动断开连接');
    return true;
  }

  /**
   * 检查 MQTT 连接状态
   */
  isConnected(): boolean {
    // 同步检查可能不准确，最好使用异步方法
    return this.mqttClient !== null;
  }

  /**
   * 发送文件数据
   * @param data - 文件数据（ArrayBuffer 或 Base64 编码的字符串）
   * @param taskId - 任务 ID
   */
  async send(data: ArrayBuffer | string, taskId: string): Promise<boolean> {
    const timeout = this.DEFAULT_TIMEOUT;
    
    for (let attempt = 0; attempt < this.MAX_RETRIES; attempt++) {
      try {
        // 更新进度为传输中
        this.updateProgress(taskId, TransferState.TRANSFERRING, 0);
        
        let payload: string;
        if (data instanceof ArrayBuffer) {
          // 如果是 ArrayBuffer，转换为 Base64
          payload = FileUtils.arrayBufferToBase64(data);
        } else {
          // 如果已经是字符串，直接使用
          payload = data;
        }

        // 通过 MQTT 发送消息到文件传输主题
        await this.mqttClient.pushMessage(payload, '/file/transfer');
        
        // 更新进度为完成
        this.updateProgress(taskId, TransferState.COMPLETED, 100);
        console.info(`[MQTTTransferProtocol] 文件发送成功，taskId=${taskId}`);
        return true;
      } catch (error) {
        console.error(`[MQTTTransferProtocol] 文件发送失败 (尝试 ${attempt + 1}/${this.MAX_RETRIES}):`, error);
        
        if (attempt === this.MAX_RETRIES - 1) {
          // 最后一次尝试也失败了
          this.updateProgress(taskId, TransferState.FAILED, 0, '发送失败：' + JSON.stringify(error));
          return false;
        }
        
        // 等待一段时间后重试
        await this.sleep(1000 * (attempt + 1));
      }
    }
    
    return false;
  }

  /**
   * 接收文件数据
   * @param taskId - 任务 ID
   * @returns 接收到的数据
   */
  async receive(taskId: string): Promise<ArrayBuffer | string> {
    // MQTT 是推送模式，接收方通过事件监听获取数据
    // 这个方法主要用于协议接口的一致性
    console.info('[MQTTTransferProtocol] MQTT 接收通过事件监听实现');
    return '';
  }

  /**
   * 获取传输进度
   */
  getProgress(taskId: string): TransferProgress {
    const progress = this.progressMap.get(taskId);
    if (!progress) {
      // 返回默认进度信息
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
    console.info(`[MQTTTransferProtocol] 取消传输任务：${taskId}`);
    this.updateProgress(taskId, TransferState.CANCELLED, 0);
    return true;
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
    
    // 如果任务完成或失败，清理进度记录（保留一段时间供查询）
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
