import HashMap from '@ohos.util.HashMap';
import { ownName } from '../broker/monitor/NodeInfoSyn';
import { taskDispatch, TaskTransmitData } from '../broker/task/TaskDispatch';
import { DeviceInfo, systemProfiler } from '../monitor/SystemProfiler';
import { paramSyn } from '../broker/paramOpt/ParamSyn';
import { 
  InferenceTask, 
  InferenceResult, 
  InferenceInputType, 
  InferenceInputData,
  ImageInputData,
  TextInputData,
  AudioInputData,
  VideoInputData
} from '../worker/InferenceWorker';
import { systemDateTime } from '@kit.BasicServicesKit';

/**
 * 任务调度状态枚举
 * 定义任务在调度生命周期中的各个状态
 */
export enum TaskScheduleStatus {
  /** 任务已创建，等待调度决策 */
  PENDING = 'pending',
  /** 正在评估节点性能，进行调度决策 */
  SCHEDULING = 'scheduling',
  /** 任务已分发到远程节点 */
  DISPATCHED = 'dispatched',
  /** 任务正在本地执行 */
  RUNNING_LOCAL = 'running_local',
  /** 任务正在远程节点执行 */
  RUNNING_REMOTE = 'running_remote',
  /** 任务执行完成 */
  COMPLETED = 'completed',
  /** 任务执行失败 */
  FAILED = 'failed',
  /** 任务已取消 */
  CANCELLED = 'cancelled',
  /** 任务等待重试 */
  RETRYING = 'retrying'
}

/**
 * 重试配置接口
 * 定义任务重试的相关参数
 */
export interface SchedulerRetryConfig {
  /** 最大重试次数，默认3次 */
  maxRetries: number;
  /** 基础延迟时间（毫秒），默认1000ms */
  baseDelayMs: number;
  /** 最大延迟时间（毫秒），默认10000ms */
  maxDelayMs: number;
  /** 是否启用指数退避，默认true */
  exponentialBackoff: boolean;
}

/**
 * 重试队列项
 * 存储待重试的任务信息
 */
export interface SchedulerRetryQueueItem {
  /** 待重试的任务 */
  task: InferenceTask;
  /** 当前重试次数 */
  retryCount: number;
  /** 计划执行时间戳 */
  scheduledTime: number;
  /** 失败原因 */
  failureReason: string;
}

/**
 * 失败类型枚举
 * 用于区分不同类型的失败场景
 */
export enum SchedulerFailureType {
  /** 调度决策失败 */
  SCHEDULING_FAILED = 'scheduling_failed',
  /** 本地执行失败 */
  LOCAL_EXECUTION_FAILED = 'local_execution_failed',
  /** 远程执行失败 */
  REMOTE_EXECUTION_FAILED = 'remote_execution_failed',
  /** 任务传输失败 */
  TRANSMISSION_FAILED = 'transmission_failed',
  /** 结果接收超时 */
  RESULT_TIMEOUT = 'result_timeout',
  /** 未知错误 */
  UNKNOWN = 'unknown'
}

/**
 * 任务流转记录项
 * 记录任务状态变更的历史轨迹
 */
export interface TaskTransitionRecord {
  /** 状态变更时间戳 */
  timestamp: number;
  /** 变更后的状态 */
  status: TaskScheduleStatus;
  /** 执行节点名称（本地或远程） */
  node: string;
  /** 状态变更说明 */
  message?: string;
}

/**
 * 调度器任务状态信息
 * 扩展基础 TaskStatus，增加调度相关的状态信息
 */
export interface SchedulerTaskStatus {
  /** 任务唯一标识 */
  taskId: string;
  /** 当前调度状态 */
  status: TaskScheduleStatus;
  /** 任务创建时间 */
  createdAt: number;
  /** 最后更新时间 */
  updatedAt: number;
  /** 目标执行节点 */
  targetNode?: string;
  /** 任务执行结果（完成后填充） */
  result?: InferenceResult;
  /** 错误信息（失败后填充） */
  error?: string;
  /** 任务流转历史记录 */
  transitionHistory: TaskTransitionRecord[];
  /** 当前重试次数 */
  retryCount: number;
  /** 最大重试次数 */
  maxRetries: number;
  /** 最后一次失败原因 */
  lastFailureReason?: string;
  /** 最后一次失败类型 */
  lastFailureType?: SchedulerFailureType;
  /** 原始任务数据（用于重试） */
  originalTask?: InferenceTask;
}

/**
 * 任务调度器类
 * 负责收集设备节点信息，计算节点评分，并根据评分结果决策任务执行位置（本地执行或分发到其他节点）
 * 采用单例模式，全局唯一调度实例
 * 
 * 新增功能：任务状态监控
 * - 跟踪每个任务的调度状态（待处理、已分发、执行中、已完成、失败等）
 * - 记录任务在不同节点间的流转情况
 * - 提供任务状态查询接口供上层调用
 */
class Scheduler{
  private static SchedulerInstance: Scheduler

  /**
   * 设备信息映射表
   * 存储当前网络中所有在线设备的名称及其详细性能信息
   */
  private deviceInfos:HashMap<string,DeviceInfo> = new HashMap();

  /**
   * 任务状态映射表
   * 存储所有被调度任务的状态信息，key为taskId
   */
  private taskStatusMap: Map<string, SchedulerTaskStatus> = new Map();

  /**
   * 任务状态监听器集合
   * 用于通知外部任务状态变更
   */
  private statusListeners: Array<(taskId: string, status: SchedulerTaskStatus) => void> = [];

  /**
   * 重试配置
   * 默认配置：最大重试3次，基础延迟1000ms，启用指数退避
   */
  private retryConfig: SchedulerRetryConfig = {
    maxRetries: 3,
    baseDelayMs: 1000,
    maxDelayMs: 10000,
    exponentialBackoff: true
  };

  /**
   * 重试队列
   * 存储待重试的任务
   */
  private retryQueue: SchedulerRetryQueueItem[] = [];

  /**
   * 重试处理器定时器ID
   */
  private retryTimerId: number | null = null;

  /**
   * 任务重试回调函数
   * 当任务需要重试时调用，由 HarmonyInferenceClient 设置
   */
  private retryCallback: ((task: InferenceTask) => void) | null = null;

  /**
   * 活跃重试任务计数
   * 记录当前正在执行的重试任务数量
   */
  private activeRetryCount: number = 0;

  /**
   * 任务调度决策入口
   * 收集节点信息，计算各节点评分，选择最优节点执行任务
   * 
   * 新增功能：集成任务状态跟踪机制
   * - 任务开始调度时记录 PENDING -> SCHEDULING 状态
   * - 本地执行时记录 SCHEDULING -> RUNNING_LOCAL 状态
   * - 远程分发时记录 SCHEDULING -> DISPATCHED 状态
   * 
   * @param task - 待调度的推理任务
   * @param logMessages - 日志消息数组（预留参数，用于记录调度日志）
   * @returns 是否在本地执行任务（true:本地执行；false:已分发到其他节点）
   */
  workScheduler(task: InferenceTask, logMessages: Array<string>): Boolean {
    const taskId = task.taskId;
    
    // 初始化任务状态记录（传入原始任务数据用于重试）
    this.initTaskStatus(taskId, task);
    
    // 更新状态为调度中
    this.updateTaskStatus(
      taskId,
      TaskScheduleStatus.SCHEDULING,
      ownName,
      '开始节点评分与调度决策'
    );

    this.deviceInfos = systemProfiler.getDeviceInfos();
    let highestScoreNode: [string, DeviceInfo] | undefined = undefined;
    
    try {
      for (let entry of this.deviceInfos.entries()) {
        const key = entry[0];
        const nodeInfo = entry[1];
        const score = this.calculate_score(nodeInfo);
        if (!highestScoreNode || score > this.calculate_score(highestScoreNode[1])) {
          highestScoreNode = entry;
        }
      }
    } catch (error) {
      console.error(`[HarmonyInference] [Scheduler] 获取设备信息失败: ${error}`);
      this.updateTaskStatus(
        taskId,
        TaskScheduleStatus.FAILED,
        ownName,
        `获取设备信息失败: ${error}`
      );
      return true; // 出错时默认本地执行
    }

    if (highestScoreNode) {
      const targetNode = highestScoreNode[0];
      const score = this.calculate_score(highestScoreNode[1]);
      console.info(`[HarmonyInference] [Scheduler] 最优节点: ${targetNode}, 评分: ${score.toFixed(2)}`);
      
      if (targetNode !== ownName) {
        // 分发到远程节点
        this.updateTaskStatus(
          taskId,
          TaskScheduleStatus.DISPATCHED,
          targetNode,
          `任务将分发到最优节点: ${targetNode}, 评分: ${score.toFixed(2)}`
        );
        
        this.dispatchTask(task, targetNode);
        console.info(`[HarmonyInference] [Scheduler] 任务已分发至节点: ${targetNode}`);
        return false;
      } else {
        // 本地执行
        this.updateTaskStatus(
          taskId,
          TaskScheduleStatus.RUNNING_LOCAL,
          ownName,
          `当前节点为最优节点，评分: ${score.toFixed(2)}，将在本地执行`
        );
      }
    } else {
      console.warn(`[HarmonyInference] [Scheduler] 未找到可用节点，将在本地执行任务`);
      this.updateTaskStatus(
        taskId,
        TaskScheduleStatus.RUNNING_LOCAL,
        ownName,
        '未找到其他可用节点，默认本地执行'
      );
    }
    return true;
  }

  /**
   * 计算节点评分
   * 根据节点性能指标和权重参数，计算节点的综合得分
   * 评分越高表示节点越适合执行任务
   * @param nodeInfo - 节点的设备性能信息
   * @returns 节点的综合评分
   */
  calculate_score(nodeInfo:DeviceInfo){
    let param = paramSyn.getNewParam()
    let score = param[0] * (1 - nodeInfo.cpuUsage) + param[1] *(1 - nodeInfo.memoryUsage)  + param[2] * nodeInfo.batteryLevel + param[3] *nodeInfo.storageFree + param[4]*(1 - nodeInfo.latency);
    return score;
  }

  /**
   * 获取调度器单例实例
   * @returns Scheduler单例对象
   */
  public static getInstance(): Scheduler {
    if (!Scheduler.SchedulerInstance) {
      Scheduler.SchedulerInstance = new Scheduler()
    }
    return Scheduler.SchedulerInstance
  }

  // ####----------------------------------@任务状态管理方法@----------------------------------####

  /**
   * 初始化任务状态记录
   * 在任务开始调度前调用，创建初始状态记录
   * 如果是重试任务（taskId已存在），保留原有的重试计数
   * @param taskId - 任务唯一标识
   * @param task - 原始任务数据（可选，用于重试）
   * @returns 创建的任务状态对象
   */
  private initTaskStatus(taskId: string, task?: InferenceTask): SchedulerTaskStatus {
    const now = systemDateTime.getTime(false);
    
    // 检查是否已存在任务状态（重试场景）
    const existingStatus = this.taskStatusMap.get(taskId);
    
    // 深拷贝任务数据，防止后续传输过程中被修改
    const taskCopy: InferenceTask | undefined = task ? this.deepCopyTask(task) : undefined;
    
    const status: SchedulerTaskStatus = {
      taskId: taskId,
      status: TaskScheduleStatus.PENDING,
      createdAt: existingStatus ? existingStatus.createdAt : now,  // 保留原始创建时间
      updatedAt: now,
      targetNode: undefined,
      transitionHistory: existingStatus ? existingStatus.transitionHistory : [{  // 保留历史记录
        timestamp: now,
        status: TaskScheduleStatus.PENDING,
        node: ownName,
        message: '任务已创建，等待调度'
      }],
      retryCount: existingStatus ? existingStatus.retryCount : 0,  // 保留重试计数！
      maxRetries: this.retryConfig.maxRetries,
      lastFailureReason: existingStatus ? existingStatus.lastFailureReason : undefined,
      lastFailureType: existingStatus ? existingStatus.lastFailureType : undefined,
      originalTask: taskCopy || existingStatus?.originalTask  // 优先使用新传入的任务
    };
    
    // 添加状态流转记录
    status.transitionHistory.push({
      timestamp: now,
      status: TaskScheduleStatus.PENDING,
      node: ownName,
      message: existingStatus ? '任务重新调度（重试）' : '任务已创建，等待调度'
    });
    
    this.taskStatusMap.set(taskId, status);
    this.notifyStatusChange(taskId, status);
    return status;
  }

  /**
   * 深拷贝推理任务
   * 防止任务数据在传输过程中被修改影响重试
   * @param task - 原始任务
   * @returns 深拷贝后的任务
   */
  private deepCopyTask(task: InferenceTask): InferenceTask {
    // 基础字段拷贝
    const copy: InferenceTask = {
      taskId: task.taskId,
      type: task.type,
      data: undefined as InferenceInputData | undefined,
      modelName: task.modelName,
      params: task.params
    };
    
    // 深拷贝 data 字段（可能包含 ArrayBuffer）
    if (task.data) {
      const inputType = task.type;
      if (inputType === InferenceInputType.IMAGE) {
        const imageData = task.data as ImageInputData;
        if (imageData.buffer) {
          // 创建新的 ArrayBuffer 副本
          const originalBuffer = imageData.buffer;
          const newBuffer = new ArrayBuffer(originalBuffer.byteLength);
          const originalView = new Uint8Array(originalBuffer);
          const newView = new Uint8Array(newBuffer);
          newView.set(originalView);
          
          const newImageData: ImageInputData = {
            type: InferenceInputType.IMAGE,
            buffer: newBuffer,
            format: imageData.format,
            width: imageData.width,
            height: imageData.height
          };
          copy.data = newImageData;
        }
      } else if (inputType === InferenceInputType.TEXT) {
        const textData = task.data as TextInputData;
        const newTextData: TextInputData = {
          type: InferenceInputType.TEXT,
          text: textData.text,
          encoding: textData.encoding
        };
        copy.data = newTextData;
      } else if (inputType === InferenceInputType.AUDIO) {
        const audioData = task.data as AudioInputData;
        if (audioData.buffer) {
          const originalBuffer = audioData.buffer;
          const newBuffer = new ArrayBuffer(originalBuffer.byteLength);
          const originalView = new Uint8Array(originalBuffer);
          const newView = new Uint8Array(newBuffer);
          newView.set(originalView);
          
          const newAudioData: AudioInputData = {
            type: InferenceInputType.AUDIO,
            buffer: newBuffer,
            sampleRate: audioData.sampleRate,
            channels: audioData.channels
          };
          copy.data = newAudioData;
        }
      } else if (inputType === InferenceInputType.VIDEO) {
        const videoData = task.data as VideoInputData;
        if (videoData.buffer) {
          const originalBuffer = videoData.buffer;
          const newBuffer = new ArrayBuffer(originalBuffer.byteLength);
          const originalView = new Uint8Array(originalBuffer);
          const newView = new Uint8Array(newBuffer);
          newView.set(originalView);
          
          const newVideoData: VideoInputData = {
            type: InferenceInputType.VIDEO,
            buffer: newBuffer,
            fps: videoData.fps
          };
          copy.data = newVideoData;
        }
      } else {
        // 其他类型直接赋值
        copy.data = task.data;
      }
    }
    
    return copy;
  }

  /**
   * 更新任务状态
   * 记录状态变更并更新历史记录
   * @param taskId - 任务唯一标识
   * @param newStatus - 新状态
   * @param targetNode - 目标节点（可选）
   * @param message - 状态变更说明（可选）
   * @param result - 执行结果（完成时填充）
   * @param error - 错误信息（失败时填充）
   */
  private updateTaskStatus(
    taskId: string,
    newStatus: TaskScheduleStatus,
    targetNode?: string,
    message?: string,
    result?: InferenceResult,
    error?: string
  ): void {
    const status = this.taskStatusMap.get(taskId);
    if (!status) {
      console.warn(`[HarmonyInference] [Scheduler] 更新状态失败，未找到任务: ${taskId}`);
      return;
    }

    const now = systemDateTime.getTime(false);
    status.status = newStatus;
    status.updatedAt = now;
    
    if (targetNode !== undefined) {
      status.targetNode = targetNode;
    }
    if (result !== undefined) {
      status.result = result;
    }
    if (error !== undefined) {
      status.error = error;
    }

    // 记录流转历史
    status.transitionHistory.push({
      timestamp: now,
      status: newStatus,
      node: targetNode || ownName,
      message: message || `状态变更为: ${newStatus}`
    });

    this.notifyStatusChange(taskId, status);
    console.info(`[HarmonyInference] [Scheduler] 任务状态更新: ${taskId} -> ${newStatus}`);
  }

  /**
   * 通知所有监听器任务状态变更
   * @param taskId - 任务唯一标识
   * @param status - 当前任务状态
   */
  private notifyStatusChange(taskId: string, status: SchedulerTaskStatus): void {
    this.statusListeners.forEach(listener => {
      try {
        listener(taskId, status);
      } catch (error) {
        console.error(`[HarmonyInference] [Scheduler] 状态监听器执行失败: ${error}`);
      }
    });
  }

  /**
   * 注册任务状态变更监听器
   * @param listener - 状态变更回调函数
   */
  public addStatusListener(listener: (taskId: string, status: SchedulerTaskStatus) => void): void {
    this.statusListeners.push(listener);
    console.info(`[HarmonyInference] [Scheduler] 已注册任务状态监听器，当前监听器数量: ${this.statusListeners.length}`);
  }

  /**
   * 移除任务状态变更监听器
   * @param listener - 要移除的回调函数
   */
  public removeStatusListener(listener: (taskId: string, status: SchedulerTaskStatus) => void): void {
    const index = this.statusListeners.indexOf(listener);
    if (index > -1) {
      this.statusListeners.splice(index, 1);
      console.info(`[HarmonyInference] [Scheduler] 已移除任务状态监听器，当前监听器数量: ${this.statusListeners.length}`);
    }
  }

  /**
   * 获取指定任务的状态信息
   * @param taskId - 任务唯一标识
   * @returns 任务状态信息，不存在则返回undefined
   */
  public getTaskStatus(taskId: string): SchedulerTaskStatus | undefined {
    return this.taskStatusMap.get(taskId);
  }

  /**
   * 获取所有任务的状态信息
   * @returns 所有任务状态的Map副本
   */
  public getAllTaskStatus(): Map<string, SchedulerTaskStatus> {
    return new Map(this.taskStatusMap);
  }

  /**
   * 获取指定状态的任务列表
   * @param status - 要筛选的状态
   * @returns 符合条件的任务状态数组
   */
  public getTasksByStatus(status: TaskScheduleStatus): SchedulerTaskStatus[] {
    const result: SchedulerTaskStatus[] = [];
    this.taskStatusMap.forEach((taskStatus) => {
      if (taskStatus.status === status) {
        result.push(taskStatus);
      }
    });
    return result;
  }

  /**
   * 获取任务的流转历史记录
   * @param taskId - 任务唯一标识
   * @returns 流转历史记录数组，任务不存在则返回undefined
   */
  public getTaskTransitionHistory(taskId: string): TaskTransitionRecord[] | undefined {
    const status = this.taskStatusMap.get(taskId);
    return status ? [...status.transitionHistory] : undefined;
  }

  /**
   * 清理已完成的任务记录
   * @param maxAge - 最大保留时间（毫秒），超过此时间的已完成/失败任务将被清理
   * @returns 清理的任务数量
   */
  public cleanupCompletedTasks(maxAge: number = 3600000): number {
    const now = systemDateTime.getTime(false);
    let cleanedCount = 0;
    
    this.taskStatusMap.forEach((status, taskId) => {
      const isTerminalStatus = status.status === TaskScheduleStatus.COMPLETED ||
                               status.status === TaskScheduleStatus.FAILED ||
                               status.status === TaskScheduleStatus.CANCELLED;
      
      if (isTerminalStatus && (now - status.updatedAt) > maxAge) {
        this.taskStatusMap.delete(taskId);
        cleanedCount++;
      }
    });

    if (cleanedCount > 0) {
      console.info(`[HarmonyInference] [Scheduler] 已清理 ${cleanedCount} 个过期任务记录`);
    }
    return cleanedCount;
  }

  /**
   * 分发任务到指定节点
   * 将推理任务封装为传输格式，通过任务调度模块发送给目标设备
   * 
   * 状态跟踪：
   * - 分发成功：保持 DISPATCHED 状态
   * - 分发失败：更新为 FAILED 状态
   * 
   * @param inferenceTask - 待分发的推理任务
   * @param to - 目标节点设备名称
   */
  async dispatchTask(inferenceTask: InferenceTask, to: string) {
    let taskInfo: TaskTransmitData = new TaskTransmitData();
    const taskId = inferenceTask.taskId;

    try {
      const time = systemDateTime.getTime(false);
      taskInfo.taskId = taskId;
      taskInfo.fromClient = ownName;
      taskInfo.toClient = to;
      taskInfo.timestamp = time;
      taskInfo.params = inferenceTask;
      
      const sendResult = await taskDispatch.sendTask(taskInfo);
      
      if (sendResult) {
        // 分发成功，记录日志但不重复更新状态
        // 状态已在 workScheduler 中设置为 DISPATCHED
        console.info(`[HarmonyInference] [Scheduler] 任务已成功分发到节点: ${to}，任务ID: ${taskId}`);
      } else {
        // 分发失败，更新状态并触发重试
        console.warn(`[HarmonyInference] [Scheduler] 任务分发到节点 ${to} 失败，任务ID: ${taskId}`);
        this.updateTaskStatus(
          taskId,
          TaskScheduleStatus.FAILED,
          to,
          `任务分发到节点 ${to} 失败`
        );
        // 触发传输失败重试
        this.handleTransmissionFailure(taskId, `任务分发到节点 ${to} 失败`);
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error(`[HarmonyInference] [Scheduler] 分发任务异常: ${errorMsg}，任务ID: ${taskId}`);
      this.updateTaskStatus(
        taskId,
        TaskScheduleStatus.FAILED,
        to,
        `分发任务异常: ${errorMsg}`
      );
      // 触发传输失败重试
      this.handleTransmissionFailure(taskId, `分发任务异常: ${errorMsg}`);
    }
  }

  /**
   * 更新远程任务执行状态
   * 当收到远程任务执行结果时调用，更新任务状态为完成或失败
   * @param taskId - 任务唯一标识
   * @param success - 是否执行成功
   * @param result - 执行结果（成功时）
   * @param error - 错误信息（失败时）
   */
  public updateRemoteTaskStatus(
    taskId: string,
    success: boolean,
    result?: InferenceResult,
    error?: string
  ): void {
    const currentStatus = this.taskStatusMap.get(taskId);
    if (!currentStatus) {
      console.warn(`[HarmonyInference] [Scheduler] 更新远程任务状态失败，未找到任务: ${taskId}`);
      return;
    }

    if (success) {
      this.updateTaskStatus(
        taskId,
        TaskScheduleStatus.COMPLETED,
        currentStatus.targetNode,
        '远程任务执行完成',
        result,
        undefined
      );
    } else {
      this.updateTaskStatus(
        taskId,
        TaskScheduleStatus.FAILED,
        currentStatus.targetNode,
        `远程任务执行失败: ${error || '未知错误'}`,
        undefined,
        error
      );
    }
  }

  /**
   * 更新本地任务执行状态
   * 当本地任务执行完成或失败时调用
   * @param taskId - 任务唯一标识
   * @param success - 是否执行成功
   * @param result - 执行结果（成功时）
   * @param error - 错误信息（失败时）
   */
  public updateLocalTaskStatus(
    taskId: string,
    success: boolean,
    result?: InferenceResult,
    error?: string
  ): void {
    const currentStatus = this.taskStatusMap.get(taskId);
    if (!currentStatus) {
      console.warn(`[HarmonyInference] [Scheduler] 更新本地任务状态失败，未找到任务: ${taskId}`);
      return;
    }

    if (success) {
      this.updateTaskStatus(
        taskId,
        TaskScheduleStatus.COMPLETED,
        ownName,
        '本地任务执行完成',
        result,
        undefined
      );
    } else {
      this.updateTaskStatus(
        taskId,
        TaskScheduleStatus.FAILED,
        ownName,
        `本地任务执行失败: ${error || '未知错误'}`,
        undefined,
        error
      );
    }
  }

  // ####----------------------------------@重试机制方法@----------------------------------####

  /**
   * 设置重试配置
   * @param config - 重试配置对象
   */
  public setRetryConfig(config: Partial<SchedulerRetryConfig>): void {
    if (config.maxRetries !== undefined) {
      this.retryConfig.maxRetries = config.maxRetries;
    }
    if (config.baseDelayMs !== undefined) {
      this.retryConfig.baseDelayMs = config.baseDelayMs;
    }
    if (config.maxDelayMs !== undefined) {
      this.retryConfig.maxDelayMs = config.maxDelayMs;
    }
    if (config.exponentialBackoff !== undefined) {
      this.retryConfig.exponentialBackoff = config.exponentialBackoff;
    }
    console.info(`[HarmonyInference] [Scheduler] 重试配置已更新: 最大重试次数=${this.retryConfig.maxRetries}, 基础延迟=${this.retryConfig.baseDelayMs}ms`);
  }

  /**
   * 获取当前重试配置
   * @returns 当前重试配置
   */
  public getRetryConfig(): SchedulerRetryConfig {
    const config: SchedulerRetryConfig = {
      maxRetries: this.retryConfig.maxRetries,
      baseDelayMs: this.retryConfig.baseDelayMs,
      maxDelayMs: this.retryConfig.maxDelayMs,
      exponentialBackoff: this.retryConfig.exponentialBackoff
    };
    return config;
  }

  /**
   * 设置重试回调函数
   * @param callback - 重试回调函数
   */
  public setRetryCallback(callback: (task: InferenceTask) => void): void {
    this.retryCallback = callback;
    console.info(`[HarmonyInference] [Scheduler] 重试回调函数已设置`);
  }

  /**
   * 判断任务是否可以重试
   * @param taskId - 任务唯一标识
   * @returns 是否可以重试
   */
  public canRetry(taskId: string): boolean {
    const status = this.taskStatusMap.get(taskId);
    if (!status) {
      return false;
    }
    return status.retryCount < status.maxRetries;
  }

  /**
   * 获取任务当前重试次数
   * @param taskId - 任务唯一标识
   * @returns 当前重试次数，任务不存在返回-1
   */
  public getTaskRetryCount(taskId: string): number {
    const status = this.taskStatusMap.get(taskId);
    return status ? status.retryCount : -1;
  }

  /**
   * 计算重试延迟时间
   * 使用指数退避策略
   * @param retryCount - 当前重试次数
   * @returns 延迟时间（毫秒）
   */
  private calculateRetryDelay(retryCount: number): number {
    const baseDelayMs = this.retryConfig.baseDelayMs;
    const maxDelayMs = this.retryConfig.maxDelayMs;
    const exponentialBackoff = this.retryConfig.exponentialBackoff;
    
    if (exponentialBackoff) {
      // 指数退避：delay = baseDelay * 1.5^retryCount
      const delay = baseDelayMs * Math.pow(1.5, retryCount);
      // 添加随机抖动（0.8-1.2倍）
      const jitter = 0.8 + Math.random() * 0.4;
      return Math.min(delay * jitter, maxDelayMs);
    } else {
      // 固定延迟 + 随机抖动
      const jitter = 0.8 + Math.random() * 0.4;
      return baseDelayMs * jitter;
    }
  }

  /**
   * 调度任务重试
   * 将失败的任务加入重试队列，等待延迟后重新执行
   * @param taskId - 任务唯一标识
   * @param failureType - 失败类型
   * @param failureReason - 失败原因
   */
  public scheduleRetry(taskId: string, failureType: SchedulerFailureType, failureReason: string): void {
    const status = this.taskStatusMap.get(taskId);
    if (!status) {
      console.warn(`[HarmonyInference] [Scheduler] 调度重试失败，未找到任务: ${taskId}`);
      return;
    }

    // 检查是否可以重试
    if (!this.canRetry(taskId)) {
      console.warn(`[HarmonyInference] [Scheduler] 任务已达到最大重试次数: ${taskId}, 重试次数: ${status.retryCount}/${status.maxRetries}`);
      // 最终标记为失败
      this.markTaskFinallyFailed(taskId, failureReason);
      return;
    }

    // 获取原始任务数据
    const originalTask = status.originalTask;
    if (!originalTask) {
      console.error(`[HarmonyInference] [Scheduler] 无法重试，缺少原始任务数据: ${taskId}`);
      this.markTaskFinallyFailed(taskId, '缺少原始任务数据，无法重试');
      return;
    }

    // 计算重试延迟
    const delay = this.calculateRetryDelay(status.retryCount);
    const scheduledTime = systemDateTime.getTime(false) + delay;

    // 更新任务状态为重试中
    status.retryCount++;
    status.lastFailureReason = failureReason;
    status.lastFailureType = failureType;
    status.status = TaskScheduleStatus.RETRYING;
    status.updatedAt = systemDateTime.getTime(false);
    
    // 记录流转历史
    status.transitionHistory.push({
      timestamp: status.updatedAt,
      status: TaskScheduleStatus.RETRYING,
      node: ownName,
      message: `任务失败，准备第${status.retryCount}次重试，原因: ${failureReason}`
    });

    this.notifyStatusChange(taskId, status);
    console.info(`[HarmonyInference] [Scheduler] 任务已加入重试队列: ${taskId}, 第${status.retryCount}次重试, 延迟${delay.toFixed(0)}ms`);

    // 加入重试队列
    this.retryQueue.push({
      task: originalTask,
      retryCount: status.retryCount,
      scheduledTime: scheduledTime,
      failureReason: failureReason
    });

    console.info(`[HarmonyInference] [Scheduler] 任务已加入重试队列: ${taskId}, 第${status.retryCount}次重试, 延迟${delay.toFixed(0)}ms, 队列长度: ${this.retryQueue.length}, 活跃重试: ${this.activeRetryCount}`);

    // 启动重试处理器（如果未运行）
    this.startRetryProcessor();
  }

  /**
   * 启动重试处理器
   * 使用简单的轮询机制，每200ms检查一次队列
   * 关键点：处理器只有在队列为空且没有活跃重试任务时才停止
   */
  private startRetryProcessor(): void {
    // 如果定时器已存在，说明处理器正在运行，直接返回
    if (this.retryTimerId !== null) {
      return;
    }

    console.info(`[HarmonyInference] [Scheduler] 重试处理器已启动`);

    const processRetryQueue = () => {
      const now = systemDateTime.getTime(false);
      
      // 找出到期的重试任务
      const readyItems = this.retryQueue.filter(item => item.scheduledTime <= now);
      
      if (readyItems.length > 0) {
        // 从队列中移除已处理的项（保留未到期的）
        this.retryQueue = this.retryQueue.filter(item => item.scheduledTime > now);
        
        // 执行重试
        readyItems.forEach(item => {
          const taskId = item.task.taskId;
          
          // 增加活跃重试计数
          this.activeRetryCount++;
          
          console.info(`[HarmonyInference] [Scheduler] 开始执行第${item.retryCount}次重试: ${taskId}, 活跃重试: ${this.activeRetryCount}`);
          
          // 更新任务状态为 PENDING
          const taskStatus = this.taskStatusMap.get(taskId);
          if (taskStatus) {
            taskStatus.status = TaskScheduleStatus.PENDING;
            taskStatus.updatedAt = now;
            taskStatus.transitionHistory.push({
              timestamp: now,
              status: TaskScheduleStatus.PENDING,
              node: ownName,
              message: `开始第${item.retryCount}次重试`
            });
            this.notifyStatusChange(taskId, taskStatus);
          }

          // 调用重试回调（异步执行，不阻塞轮询）
          if (this.retryCallback) {
            // 使用 setTimeout 确保异步执行，给处理器时间继续轮询
            setTimeout(() => {
              try {
                this.retryCallback!(item.task);
              } catch (error) {
                console.error(`[HarmonyInference] [Scheduler] 重试回调执行失败: ${error}`);
              }
            }, 0);
          }
        });
      }

      // 检查是否需要继续轮询
      // 条件：队列不为空 或 有活跃的重试任务
      if (this.retryQueue.length > 0 || this.activeRetryCount > 0) {
        // 继续轮询
        this.retryTimerId = setTimeout(processRetryQueue, 200);
      } else {
        // 队列为空且没有活跃任务，停止处理器
        this.retryTimerId = null;
        console.info(`[HarmonyInference] [Scheduler] 重试处理器已停止`);
      }
    };

    // 立即开始第一次检查
    processRetryQueue();
  }

  /**
   * 通知重试任务完成
   * 当重试任务执行完成（成功或失败）时调用，用于减少活跃计数
   * @param taskId - 任务唯一标识
   */
  public notifyRetryComplete(taskId: string): void {
    if (this.activeRetryCount > 0) {
      this.activeRetryCount--;
      console.info(`[HarmonyInference] [Scheduler] 重试任务完成: ${taskId}, 剩余活跃重试: ${this.activeRetryCount}`);
    }
  }

  /**
   * 停止重试处理器
   */
  private stopRetryProcessor(): void {
    if (this.retryTimerId !== null) {
      clearTimeout(this.retryTimerId);
      this.retryTimerId = null;
    }
    this.activeRetryCount = 0;
    console.info(`[HarmonyInference] [Scheduler] 重试处理器已停止`);
  }

  /**
   * 标记任务最终失败
   * 当达到最大重试次数后调用
   * @param taskId - 任务唯一标识
   * @param reason - 最终失败原因
   */
  private markTaskFinallyFailed(taskId: string, reason: string): void {
    const status = this.taskStatusMap.get(taskId);
    if (!status) {
      return;
    }

    const now = systemDateTime.getTime(false);
    status.status = TaskScheduleStatus.FAILED;
    status.updatedAt = now;
    status.error = `最终失败（已重试${status.retryCount}次）: ${reason}`;
    
    status.transitionHistory.push({
      timestamp: now,
      status: TaskScheduleStatus.FAILED,
      node: ownName,
      message: `任务最终失败，已重试${status.retryCount}次，原因: ${reason}`
    });

    this.notifyStatusChange(taskId, status);
    console.warn(`[HarmonyInference] [Scheduler] 任务最终失败: ${taskId}, 重试次数: ${status.retryCount}, 原因: ${reason}`);
  }

  /**
   * 手动触发任务重试
   * 提供外部API供手动重试失败的任务
   * @param taskId - 任务唯一标识
   * @returns 是否成功触发重试
   */
  public retryTask(taskId: string): boolean {
    const status = this.taskStatusMap.get(taskId);
    if (!status) {
      console.warn(`[HarmonyInference] [Scheduler] 手动重试失败，未找到任务: ${taskId}`);
      return false;
    }

    if (status.status !== TaskScheduleStatus.FAILED) {
      console.warn(`[HarmonyInference] [Scheduler] 只有失败状态的任务才能手动重试: ${taskId}, 当前状态: ${status.status}`);
      return false;
    }

    // 重置重试计数（手动重试允许额外重试机会）
    status.retryCount = 0;
    
    this.scheduleRetry(taskId, status.lastFailureType || SchedulerFailureType.UNKNOWN, status.lastFailureReason || '手动触发重试');
    return true;
  }

  /**
   * 清理重试队列
   * 销毁时调用，清理所有待重试的任务
   */
  public clearRetryQueue(): void {
    this.stopRetryProcessor();
    this.retryQueue = [];
    console.info(`[HarmonyInference] [Scheduler] 重试队列已清理`);
  }

  /**
   * 获取当前重试队列长度
   * @returns 重试队列中的任务数量
   */
  public getRetryQueueLength(): number {
    return this.retryQueue.length;
  }

  /**
   * 处理调度失败
   * 当调度决策过程中发生错误时调用
   * @param taskId - 任务唯一标识
   * @param error - 错误信息
   */
  public handleSchedulingFailure(taskId: string, error: string): void {
    this.scheduleRetry(taskId, SchedulerFailureType.SCHEDULING_FAILED, error);
  }

  /**
   * 处理本地执行失败
   * @param taskId - 任务唯一标识
   * @param error - 错误信息
   */
  public handleLocalExecutionFailure(taskId: string, error: string): void {
    this.scheduleRetry(taskId, SchedulerFailureType.LOCAL_EXECUTION_FAILED, error);
  }

  /**
   * 处理远程执行失败
   * @param taskId - 任务唯一标识
   * @param error - 错误信息
   */
  public handleRemoteExecutionFailure(taskId: string, error: string): void {
    this.scheduleRetry(taskId, SchedulerFailureType.REMOTE_EXECUTION_FAILED, error);
  }

  /**
   * 处理传输失败
   * @param taskId - 任务唯一标识
   * @param error - 错误信息
   */
  public handleTransmissionFailure(taskId: string, error: string): void {
    this.scheduleRetry(taskId, SchedulerFailureType.TRANSMISSION_FAILED, error);
  }

  /**
   * 处理结果接收超时
   * @param taskId - 任务唯一标识
   */
  public handleResultTimeout(taskId: string): void {
    this.scheduleRetry(taskId, SchedulerFailureType.RESULT_TIMEOUT, '任务结果接收超时');
  }
}

export { Scheduler };