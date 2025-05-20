import HashMap from '@ohos.util.HashMap';
import { ownName } from '../broker/monitor/NodeInfoSyn';
import { taskDispatch, TaskInfo } from '../broker/task/TaskDispatch';
import { NodeInfo, systemProfiler } from '../monitor/SystemProfiler';
import { ModelManager } from '../worker/ModelManager';
import systemDateTime from '@ohos.systemDateTime';

class Scheduler{
  private static SchedulerInstance: Scheduler
  private modelManager: ModelManager = new ModelManager();


  private deviceInfos:HashMap<string,NodeInfo> = new HashMap();
  workScheduler(uri:string, logMessages: Array<string>):Boolean{
    logMessages.push('[3/6] 调度处理')
    this.deviceInfos =  systemProfiler.getDeviceInfos();

    let highestScoreNode: [string, NodeInfo] | undefined = undefined;

    for (let entry of this.deviceInfos.entries()) {
      const key = entry[0];
      const nodeInfo = entry[1];

      const score = this.calculate_score(nodeInfo);

      if (!highestScoreNode || score > this.calculate_score(highestScoreNode[1])) {
        highestScoreNode = entry;
      }
    }

    if (highestScoreNode) {
      console.log(`Highest score node id: ${highestScoreNode[0]}, Score: ${this.calculate_score(highestScoreNode[1])}`);
      if (highestScoreNode[0] != ownName) {
        logMessages.push('[4/6] 任务发送到其他节点')
        this.dispatchTask(uri, highestScoreNode[0])
        logMessages.push('[5/6] 任务发送成功')
        return false
      }
    } else {
      console.log("No nodes found.");
    }
    return true
  }
  calculate_score(nodeInfo:NodeInfo){
    let  score = 0.2 * (100 - nodeInfo.cpuUsage) + 0.5 *(100 - nodeInfo.memoryUsage)  + 0.1 * nodeInfo.storageFree +0.1 *nodeInfo.batteryLevel;
    return score;
  }
  public static getInstance(): Scheduler {
    if (!Scheduler.SchedulerInstance) {
      Scheduler.SchedulerInstance = new Scheduler()
    }
    return Scheduler.SchedulerInstance
  }



  async dispatchTask(url:string, to:string){
    let taskInfo: TaskInfo = new TaskInfo()
    systemDateTime.getCurrentTime(false, (error, time) => {
      console.info(`Succeeded in getting currentTime : ${time}`);
      taskInfo.taskId = time.toString()
    });
    taskInfo.fromClientId = ownName
    taskInfo.toClientId = to
    taskInfo.interTime = "now"
    taskInfo.params.bitmap = await this.modelManager.processImageTOBase64(url)
    taskDispatch.sendTask(taskInfo)
  }
}
export { Scheduler };