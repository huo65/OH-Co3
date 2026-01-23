import { InferenceTask } from '../../HarmonyInferenceClient';
import { ImageInputData, InferenceInputType } from '../../worker/InferenceWorker';
import { ownName } from '../monitor/NodeInfoSyn';
import { MQTTClient } from '../MQTTClient'

interface TaskParams {
  bitmap: string;
}
interface TaskResultObj{
  taskId: string,
  fromClient:string,
  toClient:string,
  params:ResultInfo
}
interface ResultInfo{
  result:string
}

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
    MQTTInstance.pushMessage(taskInfoMessage,"task/assign");
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
      //   做一个任务队列，避免阻塞，同时可以扩展任务流转
      //   GlobalTaskManager.getQueue().addTask(taskInfo);

    }

  }
  // TODO 发送任务执行的结果
  sendTaskResult(){

  }
  // TODO 解析发回来的任务执行结果
  parseResultMessage(message:string):string{
    const taskResult:TaskResultObj = JSON.parse(message)
    const fromClient = taskResult.fromClient;
    if (fromClient == ownName) {
      return taskResult.params.result;
    }
    return ""
  }





}
export const taskDispatch = new TaskDispatch();
export {TaskTransmitData}