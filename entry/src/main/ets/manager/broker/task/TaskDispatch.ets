import { InferenceTask } from '../../HarmonyInferenceClient';
import { GlobalTaskManager } from '../../worker/GlobalTaskManager';
import { InferenceResult, InferenceInputType, ImageInputData } from '../../worker/InferenceWorker';
import { ownName } from '../monitor/NodeInfoSyn';
import { MQTTClient } from '../MQTTClient'
import { systemDateTime } from '@kit.BasicServicesKit';
import { FileTransferManager, TCPNotifyCallback } from '../../transfer/FileTransferManager';
import { FileUtils } from '../../transfer/utils/FileUtils';
import { FileInfo, TCPNotifyInfo } from '../../transfer/model/TransferDataModels';


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
  /**
   * 源设备 IP 地址（TCP 传输时使用）
   */
  sourceIp?: string;
  /**
   * 传输类型：'direct' - 直接传输，'tcp' - TCP 大文件传输
   */
  transferType?: 'direct' | 'tcp';
  /**
   * 文件哈希值（用于校验）
   */
  fileHash?: string;

  constructor() {
    this.taskId = "";
    this.fromClient = "";
    this.toClient = "";
    this.timestamp = 0;
    this.params = {taskId:"", modelName:"", type: InferenceInputType.IMAGE, data: { imageData: "" } };
    this.sourceIp = undefined;
    this.transferType = 'direct';
    this.fileHash = undefined;
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
 * 具体的文件传输协议选择与 TCP 连接建立均委托给 FileTransferManager
 */
class TaskDispatch{
  // 文件大小阈値，从 FileTransferManager 默认配置读取
  private get fileSizeThreshold(): number {
    // 与 FileTransferManager 内部配置保持一致：2MB
    return 2 * 1024 * 1024;
  }

  /**
   * 发送被调度的任务到目标设备
   * - 小文件（≤ fileSizeThreshold）：直接通过 MQTT 发送任务信息
   * - 大文件（> fileSizeThreshold）：将文件数据委托给 FileTransferManager，
   *   FileTransferManager 启动 TCP 服务器后通过 notifyCallback 通知目标设备发起连接
   * @param taskInfo - 待发送的完整任务传输数据
   * @returns 发送是否成功
   */
  async sendTask(taskInfo: TaskTransmitData): Promise<boolean> {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance();
    try {
      const dataSize = this.estimateDataSize(taskInfo.params);
      console.info(`[TaskDispatch] 估算数据大小：dataSize=${dataSize}`);

      if (dataSize > this.fileSizeThreshold) {
        // 大文件：委托 FileTransferManager 选择 TCP 协议并传输
        console.info(`[TaskDispatch] 大文件传输，委托给 FileTransferManager，taskId=${taskInfo.taskId}`);

        // 将任务数据转换为传输用的 ArrayBuffer
        const fileData = this.extractFileData(taskInfo.params);
        if (!fileData) {
          console.error('[TaskDispatch] 无法提取文件数据');
          return false;
        }

        // 构建文件元数据
        const fileInfo: FileInfo = {
          fileId: taskInfo.taskId,
          fileName: taskInfo.taskId,
          size: dataSize
        };

        // 调用 FileTransferManager，并传入 notifyCallback
        // 当 TCP 服务器就绪后，FileTransferManager 会调用此回调，
        // TaskDispatch 将通过 MQTT 通知目标设备发起 TCP 连接
        const notifyCallback: TCPNotifyCallback = async (notifyInfo: TCPNotifyInfo): Promise<void> => {
          taskInfo.transferType = 'tcp';
          taskInfo.sourceIp = notifyInfo.sourceIp;
          if (notifyInfo.fileHash !== undefined) {
            taskInfo.fileHash = notifyInfo.fileHash;
          }
          const taskInfoMessage = JSON.stringify(taskInfo);
          await MQTTInstance.pushMessage(taskInfoMessage, '/task/assign');
          console.info(`[TaskDispatch] 已通过 MQTT 通知目标设备发起 TCP 连接，sourceIp=${notifyInfo.sourceIp}`);
        };

        await FileTransferManager.getInstance().transferFile(
          fileData,
          fileInfo,
          taskInfo.toClient,
          notifyCallback
        );
        return true;
      } else {
        // 小文件：直接通过 MQTT 发送任务消息
        taskInfo.transferType = 'direct';
        const taskInfoMessage = JSON.stringify(taskInfo);
        MQTTInstance.pushMessage(taskInfoMessage, '/task/assign');
        return true;
      }
    } catch (e) {
      console.error('[TaskDispatch] sendTask 异常:', e);
      return false;
    }
  }

  /**
   * 从推理任务中提取文件数据
   * @param task - 推理任务
   * @returns 文件的 ArrayBuffer 表示，如果无法提取则返回 null
   */
  private extractFileData(task: InferenceTask): ArrayBuffer | null {
    if (task.type === InferenceInputType.IMAGE) {
      const imageDataObj: ImageInputData = task.data as ImageInputData;
      const base64: string = imageDataObj.imageData || '';
      if (!base64) {
        return null;
      }
      return FileUtils.base64ToArrayBuffer(base64);
    }
    return null;
  }

  /**
   * 估算数据大小
   * @param task - 推理任务
   * @returns 数据大小（字节）
   */
  private estimateDataSize(task: InferenceTask): number {
    // 简单估算：根据 imageData 或其他数据字段的大小 TODO 优化估算
    console.info(`[TaskDispatch] 文件类型 type=${task.type}`);
    if (task.type === InferenceInputType.IMAGE) {
      const imageDataObj: ImageInputData = task.data as ImageInputData;
      const imageData: string = imageDataObj.imageData || '';
      return imageData.length;
    }
    // 其他类型可以进一步扩展
    return 0;
  }

  /**
   * 解析接收到的任务消息并处理
   * - 直接传输（direct）：直接执行本地推理
   * - TCP 大文件传输（tcp）：委托 FileTransferManager 建立连接并接收文件，再执行推理
   * @param message - 接收到的任务消息 JSON 字符串
   */
  async parseTaskMessage(message: string) {
    const taskInfo: TaskTransmitData = JSON.parse(message);
    console.info('收到任务消息', taskInfo.taskId);

    if (taskInfo.toClient !== ownName) {
      return;
    }

    if (taskInfo.transferType === 'tcp' && taskInfo.sourceIp) {
      // 大文件 TCP 传输：委托 FileTransferManager 接收文件
      console.info('收到 TCP 大文件传输任务，委托 FileTransferManager 建立连接并接收');
      try {
        const fileInfo: FileInfo= {
          fileId: taskInfo.taskId,
          fileName: taskInfo.taskId,
          size: 0,
          hash: taskInfo.fileHash
        };
        const fileData = await FileTransferManager.getInstance().receiveFile(
          taskInfo.taskId,
          taskInfo.sourceIp,
          fileInfo
        );

        // 将接收到的文件数据还原到任务参数
        if (taskInfo.params.type === InferenceInputType.IMAGE) {
          const imageDataObj: ImageInputData = {
            imageData: FileUtils.arrayBufferToBase64(fileData as ArrayBuffer)
          };
          taskInfo.params.data = imageDataObj;
        }

        // 执行推理并返回结果
        await this.executeAndReturn(taskInfo);
      } catch (error) {
        console.error('[TaskDispatch] TCP 文件接收失败:', error);
      }
    } else {
      // 直接传输：执行本地推理并返回结果
      console.info('收到分配任务');
      await this.executeAndReturn(taskInfo);
    }
  }

  /**
   * 执行本地推理并返回结果
   * @param taskInfo - 包含推理参数的任务信息
   */
  private async executeAndReturn(taskInfo: TaskTransmitData): Promise<void> {
    const taskQueue = GlobalTaskManager.getQueue();
    const result = await taskQueue.addTask(taskInfo.params);
    const taskResTransmitData: TaskResTransmitData = new TaskResTransmitData();
    taskResTransmitData.taskId = taskInfo.taskId;
    taskResTransmitData.fromClient = taskInfo.fromClient;
    taskResTransmitData.toClient = taskInfo.toClient;
    taskResTransmitData.params = result;
    taskResTransmitData.timestamp = systemDateTime.getTime(false);
    this.sendTaskResult(taskResTransmitData);
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