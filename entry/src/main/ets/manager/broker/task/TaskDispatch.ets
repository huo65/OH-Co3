import { InferenceTask } from '../../HarmonyInferenceClient';
import { GlobalTaskManager } from '../../worker/GlobalTaskManager';
import { InferenceResult, InferenceInputType, ImageInputData } from '../../worker/InferenceWorker';
import { ownName } from '../monitor/NodeInfoSyn';
import { MQTTClient } from '../MQTTClient'
import { systemDateTime } from '@kit.BasicServicesKit';
import { NetworkUtils } from '../../transfer/utils/NetworkUtils';
import { FileUtils } from '../../transfer/utils/FileUtils';
import { TCPTransferProtocol } from '../../transfer/protocol/TCPTransferProtocol';


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
 */
class TaskDispatch{
  // 文件大小阈值，超过此值使用 TCP 传输（2MB）
  private readonly FILE_SIZE_THRESHOLD: number = 2 * 1024 * 1024;

  /**
   * 发送被调度的任务到目标设备
   * @param taskInfo - 待发送的完整任务传输数据
   * @returns 发送是否成功
   */
  async sendTask(taskInfo: TaskTransmitData): Promise<boolean> {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    try {
      // 判断是否需要使用 TCP 传输大文件
      const dataSize = this.estimateDataSize(taskInfo.params);
      console.info(`[TaskDispatch] 文件大小，dataSize=${dataSize}`);

      // TODO 测试完调整
      if (dataSize < this.FILE_SIZE_THRESHOLD) {
        // 大文件，使用 TCP 传输
        return await this.sendLargeFile(taskInfo);
      } else {
        // 小文件，使用 MQTT 直接传输
        const taskInfoMessage = JSON.stringify(taskInfo);
        MQTTInstance.pushMessage(taskInfoMessage,"/task/assign");
        return true;
      }
    } catch (e) {
      console.error(e);
      return false;
    }
  }

  /**
   * 发送大文件（通过 TCP 协议）TODO 应该由manger接管
   * @param taskInfo - 任务信息
   * @returns 发送是否成功
   */
  private async sendLargeFile(taskInfo: TaskTransmitData): Promise<boolean> {
    try {
      // 获取本机 IP 地址
      const sourceIp = NetworkUtils.getIpAddress();
      if (!sourceIp) {
        console.error('[TaskDispatch] 无法获取本机 IP 地址');
        return false;
      }
      
      // 设置 TCP 传输标识和源 IP
      taskInfo.transferType = 'tcp';
      taskInfo.sourceIp = sourceIp;
      
      console.info(`[TaskDispatch] 大文件传输，taskId=${taskInfo.taskId}, sourceIp=${sourceIp}`);
      
      // TODO: 启动 TCP 服务器监听
      const tcpProtocol = new TCPTransferProtocol();
      await tcpProtocol.startServer(8888);
      
      // 通过 MQTT 发送任务通知（包含 TCP 连接信息）
      const taskInfoMessage = JSON.stringify(taskInfo);
      const MQTTInstance: MQTTClient = MQTTClient.getInstance();
      await MQTTInstance.pushMessage(taskInfoMessage, "/task/assign");
      
      // TODO: 等待目标设备发起 TCP 连接并传输文件
      // 目标设备收到消息后会主动连接到 sourceIp:8888
      
      return true;
    } catch (error) {
      console.error('[TaskDispatch] 大文件传输失败:', error);
      return false;
    }
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
   * @param message - 接收到的任务消息 JSON 字符串
   */
  async parseTaskMessage(message: string) {
    const taskInfo: TaskTransmitData = JSON.parse(message)
    console.info('收到任务消息', taskInfo.taskId);

    if (taskInfo.toClient == ownName) {
      // 判断是否是 TCP 大文件传输
      if (taskInfo.transferType === 'tcp' && taskInfo.sourceIp) {
        console.info('收到 TCP 大文件传输任务，准备发起 TCP 连接');
        await this.receiveLargeFile(taskInfo);
        return;
      } else {
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
  }
  
  /**
   * 接收大文件（通过 TCP 协议）
   * @param taskInfo - 任务信息
   */
  private async receiveLargeFile(taskInfo: TaskTransmitData): Promise<void> {
    try {
      console.info(`[TaskDispatch] 开始接收大文件，taskId=${taskInfo.taskId}, sourceIp=${taskInfo.sourceIp}`);
        
      // TODO: 发起 TCP 连接到源设备
      const tcpProtocol = new TCPTransferProtocol();
      const connected = await tcpProtocol.connect(taskInfo.sourceIp!, 8888);
        
      if (connected) {
        // 接收文件数据
        const fileData  = await tcpProtocol.receive(taskInfo.taskId);

        // 验证文件哈希
        if (taskInfo.fileHash) {
          const isValid = await FileUtils.verifyHash(fileData as ArrayBuffer, taskInfo.fileHash);
          if (!isValid) {
            console.error('[TaskDispatch] 文件哈希校验失败');
            return;
          }
        }

        // 将文件数据设置到任务参数中
        // 注意：这里需要根据实际的 InferenceTask 结构调整
        if (taskInfo.params.type === InferenceInputType.IMAGE) {
          const imageDataObj: ImageInputData = {
            imageData: FileUtils.arrayBufferToBase64(fileData as ArrayBuffer)
          };
          taskInfo.params.data = imageDataObj;
        }

        // 执行本地推理
        const taskQueue = GlobalTaskManager.getQueue();
        const result = await taskQueue.addTask(taskInfo.params);

        // 返回结果
        const taskResTransmitData = new TaskResTransmitData();
        taskResTransmitData.taskId = taskInfo.taskId;
        taskResTransmitData.fromClient = taskInfo.fromClient;
        taskResTransmitData.toClient = taskInfo.toClient;
        taskResTransmitData.params = result;
        taskResTransmitData.timestamp = systemDateTime.getTime(false);
        this.sendTaskResult(taskResTransmitData);
      }
        
      console.info('[TaskDispatch] TCP 文件接收逻辑待实现');
    } catch (error) {
      console.error('[TaskDispatch] TCP 文件接收失败:', error);
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