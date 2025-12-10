import { GlobalTaskManager } from '../../worker/GlobalTaskManager';
import { SerialTaskQueue } from '../../worker/SerialTaskQueue';
import { ownName } from '../monitor/NodeInfoSyn';
import { MQTTClient } from '../MQTTClient'
import {MQTTOption} from '../MQTTConfig'

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
// TODO 需要改造
class TaskInfo {
  taskId: string;
  fromClient: string;
  toClient: string;
  interTime: string;
  params: TaskParams;
  constructor() {
    this.taskId = "";
    this.fromClient = "";
    this.toClient = "";
    this.interTime = "";
    this.params = {bitmap:""};
  }
}
class TaskDispatch{
  // ownName:String = "OpenHarmony 3.2";
  async sendTask(taskInfo: TaskInfo): Promise<boolean> {
    const MQTTInstance: MQTTClient = MQTTClient.getInstance()
    const bitmapParams:TaskParams =  taskInfo.params
  try {
    const message = JSON.stringify({
      taskId: taskInfo.taskId,
      fromClient: taskInfo.fromClient,
      toClient: taskInfo.toClient,
      timestamp: taskInfo.interTime,
      params:bitmapParams
    });
    MQTTInstance.pushMessage(message,"task/assign");
    return true;
  } catch (e) {
    console.error(e);
    return false;
  }
}
  // TODO 发送接收任务的结果
  sendTaskResult(){

  }
  /**
   *             {
   "taskId": "idhuo",
   "fromClient": "oh",
   "toClient": "Lenovo TB-J607F",
   "params": {
   "result": "识别成功 (45ms)
   Plant: 66%
   Pattern: 50%
   Vacation : 50%"
   }
   }
   * @param message
   */
  parseResultMessage(message:string):string{
    const taskResult:TaskResultObj = JSON.parse(message)
    const fromClient = taskResult.fromClient;
    if (fromClient == ownName) {
      return taskResult.params.result;
    }
    return ""
  }
  parseTaskMessage(message:string){
    const taskInfo:TaskInfo = JSON.parse(message)
    // TODO 注意重复处理
    if (taskInfo.toClient == ownName) {
    //   做一个任务队列，避免阻塞，同时可以扩展任务流转
    //   GlobalTaskManager.getQueue().addTask(taskInfo);

    }

  }




}
export const taskDispatch = new TaskDispatch();
export {TaskInfo}