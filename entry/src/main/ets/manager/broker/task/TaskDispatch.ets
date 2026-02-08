import { InferenceTask } from '../../HarmonyInferenceClient';
import { GlobalTaskManager } from '../../worker/GlobalTaskManager';
import { InferenceResult, InferenceInputType } from '../../worker/InferenceWorker';
import { ownName } from '../monitor/NodeInfoSyn';
import { MQTTClient } from '../MQTTClient'
import { systemDateTime } from '@kit.BasicServicesKit';

/**
 * 任务传输数据类
 * 封装需要在设备间传输的推理任务信息，包含任务内容与路由信息
 */
class TaskTransmitData {
  taskId: string;
  /**
   * 发送方客户端标识
   */
  fromClient: string;
  /**
   * 接收方客户端标识
   */
  toClient: string;
  /**
   * 时间戳，用于后续计算任务总耗时
   */
  timestamp: number;
  /**
   * 推理任务参数详情
   */
  params: InferenceTask;

  constructor() {
    this.taskId = "";
    this.fromClient = "";
    this.toClient = "";
    this.timestamp = 0;
    this.params = {taskId:"", modelName:"", type: InferenceInputType.IMAGE, data: { imageData: "" } };
  }
}

/**
 * 任务结果传输数据类
 * 封装推理任务的结果信息，用于在设备间返回任务执行结果
 */
class TaskResTransmitData {
  /**
   * 任务唯一标识，与对应任务匹配
   */
  taskId: string;
  /**
   * 结果发送方客户端标识
   */
  fromClient: string;
  /**
   * 结果接收方客户端标识
   */
  toClient: string;
  /**
   * 时间戳
   */
  timestamp: number;
  /**
   * 结果
   */
  params: InferenceResult;

  constructor() {
    this.taskId = "";
    this.fromClient = "";
    this.toClient = "";
    this.timestamp = 0;
    this.params = { success: false };
  }
}

/**
 * 任务调度分发类
 * 负责推理任务在分布式设备间的发送、接收、解析与结果回传
 */
class TaskDispatch{

  /**
   * 发送被调度的任务到目标设备
   * @param taskInfo - 待发送的完整任务传输数据
   * @returns 发送是否成功
   */
  async sendTask(taskInfo: TaskTransmitData): Promise<boolean> {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    try {
      const taskInfoMessage = JSON.stringify(taskInfo);
      MQTTInstance.pushMessage(taskInfoMessage,"/task/assign");
      return true;
    } catch (e) {
      console.error(e);
      return false;
    }
  }

  /**
   * 解析接收到的任务消息并处理
   * @param message - 接收到的任务消息JSON字符串
   */
  async parseTaskMessage(message: string) {
    const taskInfo: TaskTransmitData = JSON.parse(message)
    console.info('收到任务消息', taskInfo.taskId);
    // 注意会有重复处理
    if (taskInfo.toClient == ownName) {
      // 本地执行推理，添加到全局任务队列
      console.info('收到分配任务');
      const taskQueue = GlobalTaskManager.getQueue()
      const result = await taskQueue.addTask(taskInfo.params);
      const taskResTransmitData: TaskResTransmitData = new TaskResTransmitData()
      taskResTransmitData.taskId = taskInfo.taskId;
      taskResTransmitData.fromClient = taskInfo.fromClient;
      taskResTransmitData.toClient = taskInfo.toClient;
      taskResTransmitData.params = result;
      taskResTransmitData.timestamp = systemDateTime.getTime(false);
      this.sendTaskResult(taskResTransmitData)
    }
  }

  /**
   * 发送任务执行结果到请求方
   * @param inferenceResult - 封装好的任务结果传输数据
   */
  sendTaskResult(inferenceResult: TaskResTransmitData) {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    try {
      const taskResMessage = JSON.stringify(inferenceResult);
      console.info('发送分配任务结果');
      MQTTInstance.pushMessage(taskResMessage,"/task/result");
    } catch (e) {
      console.error(e);
    }
  }

  /**
   * 解析任务结果消息，并筛选出本设备发出的任务结果
   * @param message - 接收到的任务结果消息JSON字符串
   * @returns 如果结果是本设备发出的任务则返回结果数据，否则返回null
   */
  parseResultMessage(message: string): TaskResTransmitData | null {
    const taskResult: TaskResTransmitData = JSON.parse(message);
    const fromClient = taskResult.fromClient;
    console.log("结果处理解析", fromClient)
    console.log("结果处理判断", ownName)
    if (fromClient == ownName) {
      console.log("结果处理返回", ownName)
      return taskResult;
    }
    return null;
  }
}

export const taskDispatch = new TaskDispatch();
export { TaskTransmitData, TaskResTransmitData }