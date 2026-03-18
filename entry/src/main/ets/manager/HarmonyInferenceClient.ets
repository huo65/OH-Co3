import { EVENTID, MQTTClient, MQTTOptionsType, RESULT_EVENT_ID } from './broker/MQTTClient';
import { MqttQos } from '@ohos/mqtt';
import { Scheduler, SchedulerTaskStatus, TaskScheduleStatus, TaskTransitionRecord } from './scheduler/Scheduler';
import { ModelManager } from '../TestImageTask/ImageIdModelManager';
import { InferenceWorker, InferenceTask, InferenceResult } from './worker/InferenceWorker';
import { GlobalTaskManager } from './worker/GlobalTaskManager';
import { DeviceInfo, systemProfiler } from './monitor/SystemProfiler';
import HashMap from '@ohos.util.HashMap';
import emitter from '@ohos.events.emitter';
import { nodeInfoSyn } from './broker/monitor/NodeInfoSyn';
import { paramSyn } from './broker/paramOpt/ParamSyn';
import { taskDispatch,TaskResTransmitData} from './broker/task/TaskDispatch';
import { MQTTOption } from './broker/MQTTConfig';

// 事件ID定义
// const RESULT_EVENT_ID = 1002;
export interface DataPass {
  data:string;
}
export  interface RealDataPass {
  topic: string,
  content: string;
}

// MQTT连接配置类型
export interface MQTTConfig {
  url: string;
  clientId: string;
  userName?: string;
  password?: string;
  topic?: string;
  qos?: MqttQos;
}

// 系统状态类型
export interface SystemStatus {
  ownDevice:  DeviceInfo;       // 当前设备状态
  otherDevices: HashMap<string, DeviceInfo>;  // 其他设备状态（通过通信模块同步）
  allDevices: HashMap<string, DeviceInfo>;    // 所有设备状态（当前设备+其他设备）
}




class HarmonyInferenceClient {
  private static instance: HarmonyInferenceClient;
  private mqttClient: MQTTClient | null = null;
  private scheduler: Scheduler;
  private worker: InferenceWorker;
  private connectionStatus: string = 'Disconnected';
  // 默认图像识别模型
  private defaultWorker: ModelManager;
  private isInitialized: boolean = false;
  // 在类中添加定时器ID的成员变量
  private syncIntervalId: number | null = null;
  private taskResultMap: Map<string, InferenceResult> = new Map();

  // 私有构造函数
  private constructor() {
    this.scheduler = Scheduler.getInstance();
    this.defaultWorker = ModelManager.getInstance();
    this.worker = this.defaultWorker;
  }

  // 获取单例实例
  public static getInstance(): HarmonyInferenceClient {
    if (!HarmonyInferenceClient.instance) {
      HarmonyInferenceClient.instance = new HarmonyInferenceClient();
    }
    return HarmonyInferenceClient.instance;
  }


  private async initMQTTClient(config: MQTTConfig): Promise<void>{
    try {
      // 初始化MQTT连接
      const mqttOptions: MQTTOptionsType = {
        url: config.url,
        clientId: config.clientId,
        userName: config.userName,
        password: config.password,
        topic: config.topic,
        qos: config.qos || 1
      };

      this.mqttClient = MQTTClient.getNewInstance(mqttOptions);
      // await this.mqttClient.init();
      // 监控连接状态
      setInterval(async () => {
        if (this.mqttClient) {
          const isConnected = await this.mqttClient.isCon();
          if (isConnected) {
            this.connectionStatus = 'Connected';
            nodeInfoSyn.testLatencySend()
          } else {
            this.connectionStatus = 'Disconnected';
          }
        }
      }, 10000);
    }catch (error) {
      console.error(`[HarmonyInference] [Client] 检查连接状态失败: ${error}`);
      this.connectionStatus = 'Error';
    }

  }
  // 初始化事件监听器
  private initEventListeners(): void {
    if (this.mqttClient) {

      emitter.on({
        eventId: EVENTID
      }, (data) => {
        let message:string = JSON.stringify(data)
        let dataMessage:DataPass = JSON.parse(message)
        let realData:string = JSON.stringify(dataMessage.data)
        let realMessage:RealDataPass = JSON.parse(realData)
        if (realMessage.topic == "/device/status") {
          nodeInfoSyn.parseNodeInfoMessage(realMessage.content);
        }
        if (realMessage.topic == "/test/latency") {
          nodeInfoSyn.testLatencyRec(realMessage.content);
        }
        if (realMessage.topic == "/optimization/param") {
          paramSyn.parseParamMessage(realMessage.content);
        }
        // 接收任务，参数
        if (realMessage.topic == "/task/assign") {
          taskDispatch.parseTaskMessage(realMessage.content);
        }
      });
      // 监听任务结果事件
      emitter.on({
        eventId: RESULT_EVENT_ID,
        priority: emitter.EventPriority.LOW
      }, (eventData) => {
        console.info(`[HarmonyInference] [Client] 接收到任务结果事件`);
        let message:string = JSON.stringify(eventData)
        let dataMessage:DataPass = JSON.parse(message)
        let realData:string = JSON.stringify(dataMessage.data)
        let realMessage:RealDataPass = JSON.parse(realData)
        this.handleTaskResult(realMessage.content);
      });
    }

  }






  // ####----------------------------------@初始化与注销（连接）@----------------------------------####
  // 初始化方法
  public async init(config: MQTTConfig, modelName: string, customWorker?: InferenceWorker): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }

    try {
      MQTTOption.clientId = config.clientId;
      await this.initMQTTClient(config)
      this.initEventListeners()

      // 使用自定义Worker或默认Worker
      if (customWorker) {
        this.worker = customWorker;
      } else {
        this.worker = this.defaultWorker;
      }

      // 初始化模型
      await this.worker.initModel(modelName);

      // 初始化全局任务队列
      GlobalTaskManager.init(this.worker);

      // 启动设备状态同步
      this.startDeviceStatusSync();

      this.isInitialized = true;
      return true;
    } catch (error) {
      console.error(`[HarmonyInference] [Client] 初始化失败: ${error}`);
      return false;
    }
  }
  // 释放资源
  public async destroy(): Promise<void> {
    if (!this.isInitialized) {
      return;
    }

    try {
      this.stopDeviceStatusSync();

      // 关闭MQTT连接
      if (this.mqttClient) {
        await this.mqttClient.destroy();
        this.mqttClient = null;
      }

      // 释放Worker资源
      if (this.worker.release) {
        await this.worker.release();
      }

      // 移除事件监听器
      emitter.off(RESULT_EVENT_ID);


      this.isInitialized = false;
      console.info(`[HarmonyInference] [Client] 实例销毁成功，资源已释放`);
    } catch (error) {
      console.error(`[HarmonyInference] [Client] 实例销毁失败: ${error}`);
      const errorMsg = error instanceof Error ? error.message : String(error);
      throw new Error(errorMsg);
    }
  }

  // 检查连接状态
  public async isConnected(): Promise<boolean> {
    if (!this.mqttClient) {
      return false;
    }
    return await this.mqttClient.isCon();
  }
  public getConnectionStatus():string{
    return this.connectionStatus
  }

  // ####----------------------------------@状态信息获取与同步@----------------------------------####
  // 启动设备状态同步
  private startDeviceStatusSync(): void {
    // 设备状态同步由SystemProfiler和NodeInfoSyn模块自动处理
    // 这里不需要额外的代码，只需要确保这些模块正常工作
    console.info(`[HarmonyInference] [Client] 设备状态同步已启动`);
    // 检查是否已存在定时器
    if (this.syncIntervalId !== null) {
      console.warn(`[HarmonyInference] [Client] 设备状态同步已在运行中`);
      return;
    }
    // 启动定时器并保存ID
    this.syncIntervalId = setInterval(() => {
      this.updateDeviceStatus();
    }, 10000);
  }
  // 新增：关闭设备状态同步方法
  private stopDeviceStatusSync(): void {
    if (this.syncIntervalId !== null) {
      clearInterval(this.syncIntervalId); // 清除定时任务
      this.syncIntervalId = null;         // 重置ID
      console.info(`[HarmonyInference] [Client] 设备状态同步已停止`);
    } else {
      console.warn(`[HarmonyInference] [Client] 未找到活跃的设备状态同步任务`);
    }
  }

  // 更新设备状态并通知回调
  private updateDeviceStatus(): void {
     this.getSystemStatus();
  }
  // 获取全局系统状态视图
  public getSystemStatus(): SystemStatus {

    const allDevicesMap = systemProfiler.getDeviceInfos();
    const ownInfo = systemProfiler.ownInfo
    const otherDevicesMap =systemProfiler.getOtherInfo();

    return {
      ownDevice: ownInfo,
      otherDevices: otherDevicesMap,
      allDevices: allDevicesMap
    };
  }

  // 获取所有设备信息
  public getAllDevices(): HashMap<string, DeviceInfo> {
    const deviceInfos = systemProfiler.getDeviceInfos();
    return deviceInfos;
  }
  // 获取指定设备信息
  public getDeviceInfo(deviceName: string): DeviceInfo | undefined {
    const deviceInfos = systemProfiler.getDeviceInfos();
    const nodeInfo = deviceInfos.get(deviceName);
    if (nodeInfo) {
      return nodeInfo;
    }
    return undefined;
  }

  // ####----------------------------------@任务处理@----------------------------------####
  
  /**
   * 获取任务状态
   * 优先从 Scheduler 获取详细的调度状态，如果不存在则返回本地缓存状态
   * @param taskId - 任务唯一标识
   * @returns 任务状态信息
   */
  public getTaskStatus(taskId: string): SchedulerTaskStatus | undefined {
    // 优先从 Scheduler 获取详细状态
    const schedulerStatus = this.scheduler.getTaskStatus(taskId);
    if (schedulerStatus) {
      return schedulerStatus;
    }
    return undefined;
  }

  /**
   * 获取所有任务状态
   * 合并 Scheduler 中的调度状态和本地缓存状态
   * @returns 所有任务状态的Map
   */
  public getAllTaskStatus(): Map<string, SchedulerTaskStatus> {
    const result = new Map<string, SchedulerTaskStatus>();
    
    // 从 Scheduler 获取所有调度状态
    const schedulerStatuses = this.scheduler.getAllTaskStatus();
    schedulerStatuses.forEach((status, taskId) => {
      result.set(taskId, status);
    });
    
    return result;
  }

  /**
   * 获取任务的流转历史记录
   * @param taskId - 任务唯一标识
   * @returns 流转历史记录数组
   */
  public getTaskTransitionHistory(taskId: string): Array<TaskTransitionRecord> | undefined {
    return this.scheduler.getTaskTransitionHistory(taskId);
  }


  /**
   * 注册任务状态变更监听器
   * @param listener - 状态变更回调函数
   */
  public addTaskStatusListener(listener: (taskId: string, status: SchedulerTaskStatus) => void): void {
    // 包装监听器以转换状态格式
    const wrappedListener = (taskId: string, schedulerStatus: SchedulerTaskStatus) => {
      listener(taskId, schedulerStatus);
    };
    this.scheduler.addStatusListener(wrappedListener);
  }

  /**
   * 清理已完成的任务记录
   * @param maxAge - 最大保留时间（毫秒），默认1小时
   * @returns 清理的任务数量
   */
  public cleanupCompletedTasks(maxAge: number = 3600000): number {
    return this.scheduler.cleanupCompletedTasks(maxAge);
  }

  private handleTaskResult(resultData: string): void {
    try {
      console.info(`[HarmonyInference] [Client] 开始处理任务结果`);
      const taskResult:TaskResTransmitData | null = taskDispatch.parseResultMessage(resultData);
      if (taskResult != null) {
        console.info(`[HarmonyInference] [Client] 任务结果已存入结果映射表，任务ID: ${taskResult.taskId}`);
        
        // 更新 Scheduler 中的任务状态为已完成
        this.scheduler.updateRemoteTaskStatus(
          taskResult.taskId,
          taskResult.params.success,
          taskResult.params,
          taskResult.params.success ? undefined : taskResult.params.message
        );
      }

    } catch (error) {
      console.error(`[HarmonyInference] [Client] 处理任务结果失败: ${error}`);
    }
  }

  // 提交推理任务，只接受InferenceTask类型
  public async submitTask(task: InferenceTask): Promise<InferenceResult> {
    if (!this.isInitialized) {
      throw new Error('HarmonyInferenceClient is not initialized');
    }

    const taskId: string = task.taskId as string;

    try {
      // 使用调度器处理任务
      const logMessages: string[] = [];
      const shouldExecuteLocally = this.scheduler.workScheduler(
        task, 
        logMessages
      );

      if (shouldExecuteLocally) {
        // 本地执行推理，添加到全局任务队列
        console.info(`[HarmonyInference] [Client] 任务将在本地执行，添加到任务队列`);
        try {
          const result = await GlobalTaskManager.getQueue().addTask(task);
          
          // 更新本地任务执行状态为完成
          this.scheduler.updateLocalTaskStatus(
            taskId,
            result.success,
            result,
            result.success ? undefined : result.message
          );
          
          return result;
        } catch (error) {
          // 更新本地任务执行状态为失败
          const errorMsg = error instanceof Error ? error.message : String(error);
          this.scheduler.updateLocalTaskStatus(
            taskId,
            false,
            undefined,
            errorMsg
          );
          throw new Error(errorMsg);
        }
      } else {
        console.info(`[HarmonyInference] [Client] 任务已分发，等待远程结果，任务ID: ${taskId}`);
        // 任务已发送到其他设备，需要等待结果
        return new Promise((resolve, reject) => {
          const checkInterval = setInterval(() => {
            const result = this.taskResultMap.get(taskId);
            if (result !== undefined && result !== null) {
              clearInterval(checkInterval);
              this.taskResultMap.delete(taskId);
              console.info(`[HarmonyInference] [Client] 收到远程任务结果，任务ID: ${taskId}，执行状态: ${result.success}`);
              
              // 远程任务状态已在 handleTaskResult 中更新
              resolve(result);
            }
          }, 100); // 每100ms检查一次结果

          setTimeout(() => {
            clearInterval(checkInterval);
            // 超时更新任务状态为失败
            this.scheduler.updateRemoteTaskStatus(
              taskId,
              false,
              undefined,
              '任务执行超时（30秒）'
            );
            reject(new Error('Task timeout after 30 seconds'));
          }, 30000);
        });
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      console.error(`[HarmonyInference] [Client] 提交任务失败: ${errorMsg}`);
      throw new Error(errorMsg);
    }
  }

}

export { HarmonyInferenceClient, InferenceTask };