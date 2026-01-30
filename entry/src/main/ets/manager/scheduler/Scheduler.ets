import HashMap from '@ohos.util.HashMap';
import { ownName } from '../broker/monitor/NodeInfoSyn';
import { taskDispatch, TaskTransmitData } from '../broker/task/TaskDispatch';
import { DeviceInfo, systemProfiler } from '../monitor/SystemProfiler';
import { paramSyn } from '../broker/paramOpt/ParamSyn';
import { InferenceTask } from '../worker/InferenceWorker';
import { systemDateTime } from '@kit.BasicServicesKit';

class Scheduler{
  private static SchedulerInstance: Scheduler

  private deviceInfos:HashMap<string,DeviceInfo> = new HashMap();

  workScheduler(task: InferenceTask, logMessages: Array<string>):Boolean{
    this.deviceInfos =  systemProfiler.getDeviceInfos();
    let highestScoreNode: [string, DeviceInfo] | undefined = undefined;
    try {
      for (let entry of this.deviceInfos.entries()) {
        const key = entry[0];
        const nodeInfo = entry[1];
        const score = this.calculate_score(nodeInfo);
        if (!highestScoreNode || score > this.calculate_score(highestScoreNode[1])) {
          highestScoreNode = entry;
        }
      }
    } catch (error) {
      console.error("Failed to send task:", error);
    }

    if (highestScoreNode) {
      console.log(`Highest score node id: ${highestScoreNode[0]}, Score: ${this.calculate_score(highestScoreNode[1])}`);
      if (highestScoreNode[0] != ownName) {
        this.dispatchTask(task, highestScoreNode[0])
        console.log('任务发送到其他节点')
        return false
      }
    } else {
      console.log("No nodes found.");
    }
    return true
  }
  calculate_score(nodeInfo:DeviceInfo){
    let param = paramSyn.getNewParam()
    let score = param[0] * (1 - nodeInfo.cpuUsage) + param[1] *(1 - nodeInfo.memoryUsage)  + param[2] * nodeInfo.batteryLevel + param[3] *nodeInfo.storageFree + param[4]*(1 - nodeInfo.latency);
    return score;
  }
  public static getInstance(): Scheduler {
    if (!Scheduler.SchedulerInstance) {
      Scheduler.SchedulerInstance = new Scheduler()
    }
    return Scheduler.SchedulerInstance
  }



  /**
   * 发送任务
   * @param url
   * @param to
   */
  async dispatchTask(inferenceTask: InferenceTask, to: string) {
    let taskInfo: TaskTransmitData = new TaskTransmitData();

    try {
      const time = systemDateTime.getTime(false);
      taskInfo.taskId = inferenceTask.taskId;
      taskInfo.fromClient = ownName;
      taskInfo.toClient = to;
      taskInfo.timestamp = time;
      taskInfo.params = inferenceTask;
      taskDispatch.sendTask(taskInfo);
    } catch (error) {
      console.error("Failed to send task:", error);
    }
  }

}
export { Scheduler };