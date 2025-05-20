import { MQTTClient } from '../MQTTClient'
import {MQTTOption} from '../MQTTConfig'
const MQTTInstance: MQTTClient = MQTTClient.getFirstInstance(MQTTOption)
interface TaskParams {
  bitmap?: string;
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
  parseResultMessage(){

  }



}
export const taskDispatch = new TaskDispatch();
export {TaskInfo}