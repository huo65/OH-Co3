import { MQTTClient, MQTTOptionsType } from './broker/MQTTClient';
import { MqttQos } from '@ohos/mqtt';
import { Scheduler } from './scheduler/Scheduler';
import { ModelManager } from '../TestImageTask/ImageIdModelManager';
import { InferenceWorker, InferenceTask, InferenceResult } from './worker/InferenceWorker';
import { GlobalTaskManager } from './worker/GlobalTaskManager';
import { DeviceInfo, systemProfiler } from './monitor/SystemProfiler';
import HashMap from '@ohos.util.HashMap';
import emitter from '@ohos.events.emitter';

// 事件ID定义
const RESULT_EVENT_ID = 1002;

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
  ownDevice: HashMap<string, DeviceInfo>;       // 当前设备状态
  otherDevices: HashMap<string, DeviceInfo>;  // 其他设备状态（通过通信模块同步）
  allDevices: HashMap<string, DeviceInfo>;    // 所有设备状态（当前设备+其他设备）
}

// 任务执行状态类型
export interface TaskStatus {
  taskId: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  result?: InferenceResult;
  error?: string;
}

// 设备状态更新回调类型
export type DeviceStatusCallback = (status: SystemStatus) => void;

// 任务结果回调类型
export type TaskResultCallback = (result: InferenceResult) => void;

// 任务错误回调类型
export type TaskErrorCallback = (error: string) => void;

interface GeneratedTypeLiteralInterface_1 {
  resolve: (result: InferenceResult) => void;
  reject: (error: Error) => void;
}

class HarmonyInferenceClient {
  private static instance: HarmonyInferenceClient;
  private mqttClient: MQTTClient | null = null;
  private scheduler: Scheduler;
  private worker: InferenceWorker;
  // 默认图像识别模型
  private defaultWorker: ModelManager;
  private isInitialized: boolean = false;
  private modelName: string = '';
  //存疑
  private taskCallbacks: Map<string, GeneratedTypeLiteralInterface_1> = new Map();
  private deviceStatusCallbacks: Set<DeviceStatusCallback> = new Set();
  private taskStatusMap: Map<string, TaskStatus> = new Map();

  // 私有构造函数
  private constructor() {
    this.scheduler = Scheduler.getInstance();
    this.defaultWorker = ModelManager.getInstance();
    this.worker = this.defaultWorker;
    // this.initEventListeners();
  }

  // 获取单例实例
  public static getInstance(): HarmonyInferenceClient {
    if (!HarmonyInferenceClient.instance) {
      HarmonyInferenceClient.instance = new HarmonyInferenceClient();
    }
    return HarmonyInferenceClient.instance;
  }
  // TODO 监听任务处理封装
  // 初始化事件监听器
  private initEventListeners(): void {
    // 监听任务结果事件
    emitter.on({
      eventId: RESULT_EVENT_ID,
      priority: emitter.EventPriority.LOW
    }, (eventData) => {
      this.handleTaskResult(eventData.data?.content);
    });
  }



  // 注册设备状态更新回调
  public registerDeviceStatusCallback(callback: DeviceStatusCallback): void {
    this.deviceStatusCallbacks.add(callback);
    // 立即调用一次回调，提供当前状态
    callback(this.getSystemStatus());
  }

  // 注销设备状态更新回调
  public unregisterDeviceStatusCallback(callback: DeviceStatusCallback): void {
    this.deviceStatusCallbacks.delete(callback);
  }



  // ####----------------------------------@初始化与注销（连接）@----------------------------------####
  // 初始化方法
  public async init(config: MQTTConfig, modelName: string, customWorker?: InferenceWorker): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }

    try {
      // 初始化MQTT连接
      const mqttOptions: MQTTOptionsType = {
        url: config.url,
        clientId: config.clientId,
        userName: config.userName,
        password: config.password,
        topic: config.topic || 'task/request',
        qos: config.qos || 1
      };

      this.mqttClient = MQTTClient.getNewInstance(mqttOptions);
      await this.mqttClient.init();

      // 使用自定义Worker或默认Worker
      if (customWorker) {
        this.worker = customWorker;
      } else {
        this.worker = this.defaultWorker;
      }

      // 初始化模型
      await this.worker.initModel(modelName);
      this.modelName = modelName;

      // 初始化全局任务队列
      GlobalTaskManager.init(this.worker);

      // 启动设备状态同步
      this.startDeviceStatusSync();

      this.isInitialized = true;
      return true;
    } catch (error) {
      console.error('HarmonyInferenceClient initialization failed:', error);
      return false;
    }
  }
  // 释放资源
  public async destroy(): Promise<void> {
    if (!this.isInitialized) {
      return;
    }

    try {
      // 关闭MQTT连接
      if (this.mqttClient) {
        await this.mqttClient.destroy();
        this.mqttClient = null;
      }

      // 释放Worker资源
      if (this.worker.release) {
        await this.worker.release();
      }

      // 清空任务回调和状态
      this.taskCallbacks.clear();
      this.taskStatusMap.clear();
      this.deviceStatusCallbacks.clear();

      // 移除事件监听器
      emitter.off(RESULT_EVENT_ID);

      this.isInitialized = false;
      console.info('HarmonyInferenceClient destroyed successfully');
    } catch (error) {
      console.error('HarmonyInferenceClient destruction failed:', error);
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

  // ####----------------------------------@状态信息获取与同步@----------------------------------####
  // 启动设备状态同步
  private startDeviceStatusSync(): void {
    // 设备状态同步由SystemProfiler和NodeInfoSyn模块自动处理
    // 这里不需要额外的代码，只需要确保这些模块正常工作
    console.info('Device status sync started');

    // 定期更新设备状态
    setInterval(() => {
      this.updateDeviceStatus();
    }, 5000); // 每5秒更新一次
  }

  // 更新设备状态并通知回调
  private updateDeviceStatus(): void {
    const status = this.getSystemStatus();
    this.deviceStatusCallbacks.forEach(callback => {
      try {
        callback(status);
      } catch (error) {
        console.error('Error in device status callback:', error);
      }
    });
  }
  // 获取全局系统状态视图
  public getSystemStatus(): SystemStatus {

    const allDevicesMap = systemProfiler.getDeviceInfos();
    const ownInfo = systemProfiler.getOwnInfo();
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
  // 获取任务状态
  public getTaskStatus(taskId: string): TaskStatus | undefined {
    return this.taskStatusMap.get(taskId);
  }

  // 获取所有任务状态
  public getAllTaskStatus(): Map<string, TaskStatus> {
    return new Map(this.taskStatusMap);
  }
  // 处理任务结果
  private handleTaskResult(resultData: string): void {
    try {
      // // 解析任务结果
      // const result = JSON.parse(resultData);
      // // 查找对应的任务回调
      // // 这里需要根据实际的任务ID解析逻辑进行调整
      // // 暂时使用模拟的任务ID
      // const taskId = 'test-task-id';
      // const callback = this.taskCallbacks.get(taskId);
      // if (callback) {
      //   callback.resolve(result);
      //   this.taskCallbacks.delete(taskId);
      //   // 更新任务状态
      //   this.taskStatusMap.set(taskId, {
      //     taskId,
      //     status: 'completed',
      //     result
      //   });
      // }
    } catch (error) {
      console.error('Error handling task result:', error);
    }
  }

  // 提交推理任务，只接受InferenceTask类型
  public async submitTask(task: InferenceTask): Promise<InferenceResult> {
    if (!this.isInitialized) {
      throw new Error('HarmonyInferenceClient is not initialized');
    }

    try {
      // 使用调度器处理任务
      const logMessages: string[] = [];
      const shouldExecuteLocally = this.scheduler.workScheduler(
        task, 
        logMessages
      );

      if (shouldExecuteLocally) {
        // 本地执行推理，添加到全局任务队列
        console.info('Adding inference task to local queue');
        const result = await GlobalTaskManager.getQueue().addTask(task);
        return result;
      } else {
        // 任务已发送到其他设备，需要等待结果
        return new Promise((resolve, reject) => {
          console.info('Task sent to remote device, waiting for result');
          // 生成唯一任务ID
          const taskId = `task-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
          // 保存任务回调
          this.taskCallbacks.set(taskId, { resolve, reject });
          // 更新任务状态
          this.taskStatusMap.set(taskId, {
            taskId,
            status: 'pending'
          });

          // 设置超时处理
          setTimeout(() => {
            if (this.taskCallbacks.has(taskId)) {
              const error = 'Task timeout';
              reject(new Error(error));
              this.taskCallbacks.delete(taskId);
              // 更新任务状态
              this.taskStatusMap.set(taskId, {
                taskId,
                status: 'failed',
                error
              });
            }
          }, 30000); // 30秒超时
        });
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      console.error(`Error: ${errorMsg}`);
      throw new Error(errorMsg);
    }
  }

  // 取消任务
  public cancelTask(taskId: string): boolean {
    const callback = this.taskCallbacks.get(taskId);
    if (callback) {
      callback.reject(new Error('Task cancelled'));
      this.taskCallbacks.delete(taskId);
      // 更新任务状态
      this.taskStatusMap.set(taskId, {
        taskId,
        status: 'failed',
        error: 'Task cancelled'
      });
      return true;
    }
    return false;
  }

}

export { HarmonyInferenceClient, InferenceTask };