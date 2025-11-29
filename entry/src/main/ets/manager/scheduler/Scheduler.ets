import HashMap from '@ohos.util.HashMap';
import { ownName } from '../broker/monitor/NodeInfoSyn';
import { taskDispatch, TaskInfo } from '../broker/task/TaskDispatch';
import { DeviceInfo, systemProfiler } from '../monitor/SystemProfiler';
import systemDateTime from '@ohos.systemDateTime';
import { paramSyn } from '../broker/paramOpt/ParamSyn';
import { ModelManager } from '../../manager/worker/ModelManager';
const ModelManagerInstance: ModelManager = ModelManager.getInstance()
class Scheduler{
  private static SchedulerInstance: Scheduler
  // private modelManager: ModelManager = new ModelManager();


  private deviceInfos:HashMap<string,DeviceInfo> = new HashMap();
  workScheduler(uri:string, logMessages: Array<string>):Boolean{
    logMessages.push('[3/6] 调度处理')
    this.deviceInfos =  systemProfiler.getDeviceInfos();

    let highestScoreNode: [string, DeviceInfo] | undefined = undefined;

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
  calculate_score(nodeInfo:DeviceInfo){
    let param = paramSyn.getNewParam()
    let score = param[0] * (100 - nodeInfo.cpuUsage) + param[1] *(100 - nodeInfo.memoryUsage)  + param[3] * nodeInfo.storageFree + param[2] *nodeInfo.batteryLevel;
    return score;
  }
  public static getInstance(): Scheduler {
    if (!Scheduler.SchedulerInstance) {
      Scheduler.SchedulerInstance = new Scheduler()
    }
    return Scheduler.SchedulerInstance
  }



  async dispatchTask(url: string, to: string) {
    let taskInfo: TaskInfo = new TaskInfo();

    try {
      // 使用封装的 Promise 方法获取当前时间
      const time = await this.getCurrentTimeAsync();
      console.info(`Succeeded in getting currentTime : ${time}`);
      taskInfo.taskId = time.toString();

      // 初始化其他字段
      taskInfo.fromClient = ownName;
      taskInfo.toClient = to;
      taskInfo.interTime = "now";
      taskInfo.params.bitmap = await ModelManagerInstance.processImageTOBase64(url);

      // 所有数据准备完毕后再发送任务
      taskDispatch.sendTask(taskInfo);
    } catch (error) {
      console.error("Failed to get current time:", error);
      // 可选：处理错误或提示用户
    }
  }

  // 将原来的回调方式封装为 Promise
  private getCurrentTimeAsync(): Promise<number> {
    return new Promise((resolve, reject) => {
      systemDateTime.getCurrentTime(false, (error, time) => {
        if (error) {
          reject(error);
        } else {
          resolve(time);
        }
      });
    });
  }
}
export { Scheduler };