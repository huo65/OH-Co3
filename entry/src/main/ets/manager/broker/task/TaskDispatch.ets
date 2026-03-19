import { InferenceTask } from '../../HarmonyInferenceClient';
import { GlobalTaskManager } from '../../worker/GlobalTaskManager';
import { InferenceResult, InferenceInputType, ImageInputData } from '../../worker/InferenceWorker';
import { FileTransferManager, TransferNotifyCallback } from '../../transfer/FileTransferManager';
import { MQTTClient } from '../MQTTClient'
import { systemDateTime } from '@kit.BasicServicesKit';
import { FileUtils } from '../../transfer/utils/FileUtils';
import { FileInfo } from '../../transfer/model/TransferDataModels';
import { TCPNotifyInfo } from '../../transfer/model/TCPModels';
import { InferenceDataUtils } from '../../worker/InferenceDataUtils';
import { getDeviceId } from '../../config/DeviceIdentifier';


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
   * 源设备标识（如 IP 地址或设备 ID，具体含义由传输协议决定）
   * @deprecated 使用 sourceDevice 替代
   */
  sourceIp?: string;
  /**
   * 源设备标识（如 IP 地址或设备 ID，具体含义由传输协议决定）
   */
  sourceDevice?: string;
  /**
   * 传输类型：'direct' - 直接传输，其他值表示使用对应协议（如 'TCP', 'UDP', 'HTTP' 等）
   */
  transferType:  string;
  /**
   * 文件哈希值（用于校验）
   */
  fileHash?: string;

  constructor() {
    this.taskId = "";
    this.fromClient = "";
    this.toClient = "";
    this.timestamp = 0;
    const emptyBuffer = new ArrayBuffer(0);
    const imageData: ImageInputData = {
      type: InferenceInputType.IMAGE,
      buffer: emptyBuffer
    };
    this.params = {taskId:"", modelName:"", type: InferenceInputType.IMAGE, data: imageData };
    this.sourceDevice = undefined;
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
 */
class TaskDispatch{
  // 文件大小阈値，从 FileTransferManager 默认配置读取
  private get fileSizeThreshold(): number {
    // 与 FileTransferManager 内部配置保持一致：2kb
    return 2 * 1024;
  }

  /**
   * 发送被调度的任务到目标设备
   * - 小文件（≤ fileSizeThreshold）：直接通过 MQTT 发送任务信息
   * - 大文件（> fileSizeThreshold）：显式指定 TCP 协议，委托给 FileTransferManager，
   *   FileTransferManager 启动 TCP 服务器后通过 notifyCallback 通知目标设备发起连接
   * @param taskInfo - 待发送的完整任务传输数据
   * @returns 发送是否成功
   */
  async sendTask(taskInfo: TaskTransmitData): Promise<boolean> {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance();
    try {
      const dataSize = this.estimateDataSize(taskInfo.params);
      console.info(`[HarmonyInference] [TaskDispatch] 估算任务数据大小: ${dataSize} 字节，任务ID: ${taskInfo.taskId}`);

      if (dataSize > this.fileSizeThreshold) {
        console.info(`[HarmonyInference] [TaskDispatch] 大文件传输模式，启用TCP协议，任务ID: ${taskInfo.taskId}`);
        // 将任务数据转换为传输用的 ArrayBuffer
        const fileData = this.extractFileData(taskInfo.params);
        if (!fileData) {
          console.error(`[HarmonyInference] [TaskDispatch] 无法提取文件数据，任务ID: ${taskInfo.taskId}`);
          return false;
        }

        // 构建文件元数据
        const fileInfo: FileInfo = {
          fileId: taskInfo.taskId,
          fileName: taskInfo.taskId,
          size: dataSize
        };

        // 调用 FileTransferManager 并传入 notifyCallback
        // 当 TCP 服务器就绪后，FileTransferManager 会调用此回调，
        // TaskDispatch 将通过 MQTT 通知目标设备发起连接
        const notifyCallback: TransferNotifyCallback = async (notifyInfo): Promise<void> => {
          // 将通用通知信息转换为 TCP 特有类型
          const tcpNotifyInfo: TCPNotifyInfo = notifyInfo as TCPNotifyInfo;
          taskInfo.transferType = 'TCP';
          // 清空数据，使用空的 ImageInputData
          const emptyImageData: ImageInputData = {
            type: InferenceInputType.IMAGE,
            buffer: new ArrayBuffer(0)
          };
          taskInfo.params.data = emptyImageData;
          taskInfo.sourceDevice = tcpNotifyInfo.sourceIp;
          const taskInfoMessage = JSON.stringify(taskInfo);
          await MQTTInstance.pushMessage(taskInfoMessage, '/task/assign');
          console.info(`[HarmonyInference] [TaskDispatch] 已通过MQTT通知目标设备发起TCP连接，源IP: ${tcpNotifyInfo.sourceIp}, 端口: ${tcpNotifyInfo.port}`);
        };

        await FileTransferManager.getInstance().transferFile(
          fileData,
          fileInfo,
          taskInfo.toClient,
          'TCP',
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
      console.error(`[HarmonyInference] [TaskDispatch] 发送任务异常: ${e}`);
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
      const buffer: ArrayBuffer = imageDataObj.buffer;
      if (!buffer || buffer.byteLength === 0) {
        return null;
      }
      return buffer;
    }
    return null;
  }

  /**
   * 估算数据大小
   * @param task - 推理任务
   * @returns 数据大小（字节）
   */
  private estimateDataSize(task: InferenceTask): number {
    console.info(`[HarmonyInference] [TaskDispatch] 估算文件大小，文件类型: ${task.type}`);
    return InferenceDataUtils.estimateInputDataSize(task.data);
  }

  /**
   * 解析接收到的任务消息并处理
   * - 直接传输（direct）：直接执行本地推理
   * - 大文件传输（tcp 或其他协议）：委托 FileTransferManager 建立连接并接收文件，再执行推理
   * @param message - 接收到的任务消息 JSON 字符串
   */
  async parseTaskMessage(message: string) {
    const taskInfo: TaskTransmitData = JSON.parse(message);
    console.info(`[HarmonyInference] [TaskDispatch] 收到任务消息，任务ID: ${taskInfo.taskId}`);

    const ownDeviceId: string = getDeviceId();
    if (taskInfo.toClient !== ownDeviceId) {
      return;
    }

    // 判断是否需要文件传输（transferType 不为 'direct' 且有源设备地址）
    if (taskInfo.transferType !== 'direct') {
      // 大文件传输：委托 FileTransferManager 接收文件
      // transferType 的值即为协议名称（如 'TCP', 'UDP' 等）
      const protocolName = taskInfo.transferType;
      console.info(`[HarmonyInference] [TaskDispatch] 收到${protocolName}大文件传输任务，委托FileTransferManager接收文件`);
      try {
        const fileInfo: FileInfo = {
          fileId: taskInfo.taskId,
          fileName: taskInfo.taskId,
          size: 0,
          hash: taskInfo.fileHash
        };
        const fileResult = await FileTransferManager.getInstance().receiveFile(
          taskInfo.taskId,
          taskInfo.sourceDevice as string,
          fileInfo,
          protocolName
        );

        // 将接收到的文件数据还原到任务参数
        if (fileResult.success && fileResult.data instanceof ArrayBuffer) {
          if (taskInfo.params.type === InferenceInputType.IMAGE) {
            const imageDataObj: ImageInputData = {
              type: InferenceInputType.IMAGE,
              buffer: fileResult.data
            };
            taskInfo.params.data = imageDataObj;
          }
        } else {
          console.error(`[HarmonyInference] [TaskDispatch] 文件接收失败: ${fileResult.error?.message}`);
          return;
        }

        // 执行推理并返回结果
        await this.executeAndReturn(taskInfo);
      } catch (error) {
        console.error(`[HarmonyInference] [TaskDispatch] ${protocolName}文件接收失败: ${error}`);
      }
    } else {
      // 直接传输：执行本地推理并返回结果
      console.info(`[HarmonyInference] [TaskDispatch] 收到直接传输任务，开始本地推理`);
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
      console.info(`[HarmonyInference] [TaskDispatch] 发送任务执行结果，任务ID: ${inferenceResult.taskId}`);
      MQTTInstance.pushMessage(taskResMessage,"/task/result");
    } catch (e) {
      console.error(`[HarmonyInference] [TaskDispatch] 发送任务结果异常: ${e}`);
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
    const ownDeviceId: string = getDeviceId();
    console.info(`[HarmonyInference] [TaskDispatch] 解析任务结果消息，来源设备: ${fromClient}`);
    console.info(`[HarmonyInference] [TaskDispatch] 当前设备标识: ${ownDeviceId}`);
    if (fromClient == ownDeviceId) {
      console.info(`[HarmonyInference] [TaskDispatch] 匹配成功，返回本设备发出的任务结果`);
      return taskResult;
    }
    return null;
  }
}

export const taskDispatch = new TaskDispatch();
export { TaskTransmitData, TaskResTransmitData }