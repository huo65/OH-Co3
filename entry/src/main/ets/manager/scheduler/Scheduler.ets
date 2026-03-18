import HashMap from '@ohos.util.HashMap';
import { ownName } from '../broker/monitor/NodeInfoSyn';
import { taskDispatch, TaskTransmitData } from '../broker/task/TaskDispatch';
import { DeviceInfo, systemProfiler } from '../monitor/SystemProfiler';
import { paramSyn } from '../broker/paramOpt/ParamSyn';
import { InferenceTask, InferenceResult } from '../worker/InferenceWorker';
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
  CANCELLED = 'cancelled'
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
    
    // 初始化任务状态记录
    this.initTaskStatus(taskId);
    
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
   * @param taskId - 任务唯一标识
   * @returns 创建的任务状态对象
   */
  private initTaskStatus(taskId: string): SchedulerTaskStatus {
    const now = systemDateTime.getTime(false);
    const status: SchedulerTaskStatus = {
      taskId: taskId,
      status: TaskScheduleStatus.PENDING,
      createdAt: now,
      updatedAt: now,
      targetNode: undefined,
      transitionHistory: [{
        timestamp: now,
        status: TaskScheduleStatus.PENDING,
        node: ownName,
        message: '任务已创建，等待调度'
      }]
    };
    this.taskStatusMap.set(taskId, status);
    this.notifyStatusChange(taskId, status);
    return status;
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
        // 分发成功，状态保持 DISPATCHED，等待远程执行结果
        this.updateTaskStatus(
          taskId,
          TaskScheduleStatus.DISPATCHED,
          to,
          `任务已成功分发到节点: ${to}，等待远程执行结果`
        );
      } else {
        // 分发失败
        this.updateTaskStatus(
          taskId,
          TaskScheduleStatus.FAILED,
          to,
          `任务分发到节点 ${to} 失败`
        );
      }
    } catch (error) {
      console.error(`[HarmonyInference] [Scheduler] 分发任务失败: ${error}`);
      this.updateTaskStatus(
        taskId,
        TaskScheduleStatus.FAILED,
        to,
        `分发任务异常: ${error}`
      );
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
}
export { Scheduler };