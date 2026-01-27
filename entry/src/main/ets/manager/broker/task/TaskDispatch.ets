import { InferenceTask } from '../../HarmonyInferenceClient';
import { GlobalTaskManager } from '../../worker/GlobalTaskManager';
import { InferenceResult, InferenceInputType } from '../../worker/InferenceWorker';
import { ownName } from '../monitor/NodeInfoSyn';
import { MQTTClient } from '../MQTTClient'


class TaskTransmitData {
  taskId: string;
  fromClient: string;
  toClient: string;
  interTime: number;//记录接收时间，之后计算总耗时
  params: InferenceTask;
  constructor() {
    this.taskId = "";
    this.fromClient = "";
    this.toClient = "";
    this.interTime = 0;
    this.params = {taskId:"" , modelName:"", type: InferenceInputType.IMAGE, data : { imageData :""} };
  }
}
class TaskResTransmitData {
  taskId: string;
  fromClient: string;
  toClient: string;
  params: InferenceResult;
  constructor() {
    this.taskId = "";
    this.fromClient = "";
    this.toClient = "";
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
    const taskInfoMessage = JSON.stringify({
      taskInfo
    });
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
  // TODO 解析收到任务
  parseTaskMessage(message:string){
    const taskInfo:TaskTransmitData = JSON.parse(message)
    // 注意会有重复处理
    if (taskInfo.toClient == ownName) {
      // 本地执行推理，添加到全局任务队列
      console.info('Adding inference task to local queue');
      const result = GlobalTaskManager.getQueue().addTask(taskInfo.params);
    }

  }
  // TODO 发送任务执行的结果
  sendTaskResult(inferenceResult:TaskResTransmitData){
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    try {
      const taskResMessage = JSON.stringify({
        TaskResTransmitData
      });
      MQTTInstance.pushMessage(taskResMessage,"/task/result");
    } catch (e) {
      console.error(e);
    }

  }
  // TODO 解析发回来的任务执行结果
  parseResultMessage(message:string):string{
    const taskResult:TaskResTransmitData = JSON.parse(message);
    const fromClient = taskResult.fromClient;
    if (fromClient == ownName) {
      return "taskResult.message";
    }
    return ""
  }


}
export const taskDispatch = new TaskDispatch();
export {TaskTransmitData}