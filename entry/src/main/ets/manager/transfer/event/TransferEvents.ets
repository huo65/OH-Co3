/**
 * 文件传输事件定义
 * 定义传输过程中的各类事件和数据结构
 */
import emitter from '@ohos.events.emitter';
import { TransferProgress, TransferState } from '../protocol/TransferProtocolInterface';
import { TransferError } from '../model/TransferResult';

/**
 * 传输事件 ID 枚举
 */
export enum TransferEventId {
  /** 传输开始事件 */
  TRANSFER_START = 2001,
  /** 传输进度更新事件 */
  TRANSFER_PROGRESS = 2002,
  /** 传输完成事件 */
  TRANSFER_COMPLETE = 2003,
  /** 传输失败事件 */
  TRANSFER_FAILED = 2004,
  /** 传输取消事件 */
  TRANSFER_CANCELLED = 2005,
  /** TCP 连接建立事件 */
  TCP_CONNECTED = 2006,
  /** TCP 连接断开事件 */
  TCP_DISCONNECTED = 2007,
  /** 文件分块接收事件 */
  CHUNK_RECEIVED = 2008,
  /** 文件重组完成事件 */
  FILE_REASSEMBLED = 2009,
  /** 协议注册事件 */
  PROTOCOL_REGISTERED = 2010,
  /** 协议注销事件 */
  PROTOCOL_UNREGISTERED = 2011
}

/**
 * 传输事件数据接口
 */
export interface TransferEventData extends emitter.EventData {
  /** 任务 ID */
  taskId: string;
  /** 事件类型 */
  eventType: TransferEventId;
  /** 事件数据 */
  data?: Object;
  /** 时间戳 */
  timestamp?: number;
}

/**
 * 传输开始事件数据
 */
export interface TransferStartEventData extends TransferEventData {
  data: TransferStartData;
}

/**
 * 传输开始数据
 */
export interface TransferStartData {
  protocol: string;
}

/**
 * 传输进度事件数据
 */
export interface TransferProgressEventData extends TransferEventData {
  data: TransferProgress;
}

/**
 * 传输完成事件数据
 */
export interface TransferCompleteEventData extends TransferEventData {
  data: TransferCompleteData;
}

/**
 * 传输完成数据
 */
export interface TransferCompleteData {
  fileInfo: Object;
  duration: number;
  transferredBytes: number;
  averageSpeed: number;
  protocol: string;
}

/**
 * 传输失败事件数据
 */
export interface TransferFailedEventData extends TransferEventData {
  data: TransferFailedData;
}

/**
 * 传输失败数据
 */
export interface TransferFailedData {
  error: string;
  errorCode?: string;
}

/**
 * 协议事件数据
 */
export interface ProtocolEventData {
  protocolName: string;
}

/**
 * 传输事件监听器配置
 */
export interface TransferEventListener {
  /** 事件 ID */
  eventId: TransferEventId;
  /** 优先级 */
  priority?: emitter.EventPriority;
  /** 回调函数 */
  callback: (eventData: TransferEventData) => void;
}

/**
 * 文件传输事件管理类
 * 提供事件的发送和监听功能
 */
export class TransferEventManager {
  private static instance: TransferEventManager;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): TransferEventManager {
    if (!TransferEventManager.instance) {
      TransferEventManager.instance = new TransferEventManager();
    }
    return TransferEventManager.instance;
  }

  /**
   * 发送传输事件
   * @param eventId - 事件 ID
   * @param taskId - 任务 ID
   * @param data - 事件数据
   * @param priority - 事件优先级
   */
  emit(
    eventId: TransferEventId,
    taskId: string,
    data?: Object,
    priority: emitter.EventPriority = emitter.EventPriority.HIGH
  ): void {
    const eventData: TransferEventData = {
      taskId,
      eventType: eventId,
      data,
      timestamp: Date.now()
    };

    try {
      emitter.emit({
        eventId,
        priority
      }, eventData);

      console.info(`[HarmonyInference] [TransferEventManager] 事件发送成功: ${TransferEventId[eventId]}, 任务ID: ${taskId}`);
    } catch (error) {
      console.error(`[HarmonyInference] [TransferEventManager] 事件发送失败: ${error}`);
    }
  }

  /**
   * 监听传输事件
   * @param eventId - 事件 ID
   * @param callback - 回调函数
   * @param priority - 事件优先级
   */
  on(
    eventId: TransferEventId,
    callback: (eventData: TransferEventData) => void,
    priority: emitter.EventPriority = emitter.EventPriority.HIGH
  ): void {
    try {
      emitter.on(eventId.toString(), (eventData: emitter.EventData) => {
        callback(eventData as TransferEventData);
      });

      console.info(`[HarmonyInference] [TransferEventManager] 事件监听已注册: ${TransferEventId[eventId]}`);
    } catch (error) {
      console.error(`[HarmonyInference] [TransferEventManager] 注册事件监听失败: ${error}`);
    }
  }

  /**
   * 监听传输事件（一次性）
   * @param eventId - 事件 ID
   * @param callback - 回调函数
   * @param priority - 事件优先级
   */
  once(
    eventId: TransferEventId,
    callback: (eventData: TransferEventData) => void,
    priority: emitter.EventPriority = emitter.EventPriority.HIGH
  ): void {
    try {
      emitter.once(eventId.toString(), (eventData: emitter.EventData) => {
        callback(eventData as TransferEventData);
      });

      console.info(`[HarmonyInference] [TransferEventManager] 一次性事件监听已注册: ${TransferEventId[eventId]}`);
    } catch (error) {
      console.error(`[HarmonyInference] [TransferEventManager] 注册一次性事件监听失败: ${error}`);
    }
  }

  /**
   * 移除传输事件监听
   * @param eventId - 事件 ID
   */
  off(eventId: TransferEventId): void {
    try {
      emitter.off(eventId);
      console.info(`[HarmonyInference] [TransferEventManager] 事件监听已移除: ${TransferEventId[eventId]}`);
    } catch (error) {
      console.error(`[HarmonyInference] [TransferEventManager] 移除事件监听失败: ${error}`);
    }
  }

  /**
   * 移除所有传输事件监听
   */
  offAll(): void {
    Object.values(TransferEventId).forEach(eventId => {
      if (typeof eventId === 'number') {
        this.off(eventId as TransferEventId);
      }
    });
  }

  /**
   * 触发传输开始事件
   * @param taskId - 任务 ID
   * @param protocol - 使用的协议
   */
  emitTransferStart(taskId: string, protocol: string): void {
    const data: TransferStartData = { protocol: protocol };
    this.emit(TransferEventId.TRANSFER_START, taskId, data);
  }

  /**
   * 触发传输进度更新事件
   * @param taskId - 任务 ID
   * @param progress - 进度信息
   */
  emitTransferProgress(taskId: string, progress: TransferProgress): void {
    this.emit(TransferEventId.TRANSFER_PROGRESS, taskId, progress);
  }

  /**
   * 触发传输完成事件
   * @param taskId - 任务 ID
   * @param result - 完成结果
   */
  emitTransferComplete(taskId: string, result: Object): void {
    this.emit(TransferEventId.TRANSFER_COMPLETE, taskId, result);
  }

  /**
   * 触发传输失败事件
   * @param taskId - 任务 ID
   * @param error - 错误信息
   * @param errorCode - 错误码（可选）
   */
  emitTransferFailed(taskId: string, error: string, errorCode?: string): void {
    const data: TransferFailedData = { error: error, errorCode: errorCode };
    this.emit(TransferEventId.TRANSFER_FAILED, taskId, data);
  }

  /**
   * 触发传输取消事件
   * @param taskId - 任务 ID
   */
  emitTransferCancelled(taskId: string): void {
    this.emit(TransferEventId.TRANSFER_CANCELLED, taskId);
  }

  /**
   * 触发协议注册事件
   * @param protocolName - 协议名称
   */
  emitProtocolRegistered(protocolName: string): void {
    const data: ProtocolEventData = { protocolName: protocolName };
    this.emit(TransferEventId.PROTOCOL_REGISTERED, 'register', data);
  }

  /**
   * 触发协议注销事件
   * @param protocolName - 协议名称
   */
  emitProtocolUnregistered(protocolName: string): void {
    const data: ProtocolEventData = { protocolName: protocolName };
    this.emit(TransferEventId.PROTOCOL_UNREGISTERED, 'unregister', data);
  }
}
