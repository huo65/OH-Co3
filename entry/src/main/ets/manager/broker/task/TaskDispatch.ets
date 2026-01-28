import { InferenceTask } from '../../HarmonyInferenceClient';
import { GlobalTaskManager } from '../../worker/GlobalTaskManager';
import { InferenceResult, InferenceInputType } from '../../worker/InferenceWorker';
import { ownName } from '../monitor/NodeInfoSyn';
import { MQTTClient } from '../MQTTClient'
import { systemDateTime } from '@kit.BasicServicesKit';


class TaskTransmitData {
  taskId: string;
  fromClient: string;
  toClient: string;
  timestamp: number;//记录时间，之后计算总耗时
  params: InferenceTask;
  constructor() {
    this.taskId = "";
    this.fromClient = "";
    this.toClient = "";
    this.timestamp = 0;
    this.params = {taskId:"" , modelName:"", type: InferenceInputType.IMAGE, data : { imageData :""} };
  }
}
class TaskResTransmitData {
  taskId: string;
  fromClient: string;
  toClient: string;
  timestamp: number;//记录时间，之后计算总耗时
  params: InferenceResult;
  constructor() {
    this.taskId = "";
    this.fromClient = "";
    this.toClient = "";
    this.timestamp = 0;
    this.params = {success:false};
  }
}
class TaskDispatch{

  /**
   * 发送被调度的任务
   * @param taskInfo
   * @returns
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
   * 解析收到的任务
   * @param message
   */
  async parseTaskMessage(message:string){
    const taskInfo:TaskTransmitData = JSON.parse(message)
    console.info('收到任务消息',taskInfo.taskId);
    // 注意会有重复处理
    if (taskInfo.toClient == ownName) {
      // 本地执行推理，添加到全局任务队列
      console.info('收到分配任务');
      const taskQueue = GlobalTaskManager.getQueue()
      const result = await taskQueue.addTask(taskInfo.params);
      const  taskResTransmitData:TaskResTransmitData = new TaskResTransmitData()
      taskResTransmitData.taskId = taskInfo.taskId;
      taskResTransmitData.fromClient = taskInfo.fromClient;
      taskResTransmitData.toClient = taskInfo.toClient;
      taskResTransmitData.params = result;
      taskResTransmitData.timestamp = systemDateTime.getTime(true);
      this.sendTaskResult(taskResTransmitData)

    }

  }
  sendTaskResult(inferenceResult:TaskResTransmitData){
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    try {
      const taskResMessage = JSON.stringify(
        inferenceResult
      );
      console.info('发送分配任务结果');
      MQTTInstance.pushMessage(taskResMessage,"/task/result");
    } catch (e) {
      console.error(e);
    }

  }

  parseResultMessage(message:string):TaskResTransmitData | null{
    const taskResult:TaskResTransmitData = JSON.parse(message);
    const fromClient = taskResult.fromClient;
    console.log("结果处理解析",fromClient)
    console.log("结果处理判断",ownName)
    if (fromClient == ownName) {
      console.log("结果处理返回",ownName)
      return taskResult;
    }
    return null;
  }


}
export const taskDispatch = new TaskDispatch();
export {TaskTransmitData,TaskResTransmitData}