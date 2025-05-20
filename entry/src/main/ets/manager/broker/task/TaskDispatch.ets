import { ownName } from '../monitor/NodeInfoSyn';
import { MQTTClient } from '../MQTTClient'
import {MQTTOption} from '../MQTTConfig'
const MQTTInstance: MQTTClient = MQTTClient.getFirstInstance(MQTTOption)
interface TaskParams {
  bitmap?: string;
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

class TaskInfo {
  taskId: string;
  fromClientId: string;
  toClientId: string;
  interTime: string;
  params: TaskParams;
  constructor() {
    this.taskId = "";
    this.fromClientId = "";
    this.toClientId = "";
    this.interTime = "";
    this.params = {};
  }
}
class TaskDispatch{
  ownName:String = "OpenHarmony 3.2";
  async sendTask(taskInfo: TaskInfo): Promise<boolean> {
    const bitmapParams:TaskParams =  taskInfo.params
  try {
    const message = JSON.stringify({
      taskId: taskInfo.taskId,
      fromClient: taskInfo.fromClientId,
      toClient: taskInfo.toClientId,
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
  parseTaskMessage(){

  }
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




}
export const taskDispatch = new TaskDispatch();
export {TaskInfo}