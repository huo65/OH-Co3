import HashMap from '@ohos.util.HashMap';
import { ownName } from '../broker/monitor/NodeInfoSyn';
import { taskDispatch, TaskTransmitData } from '../broker/task/TaskDispatch';
import { DeviceInfo, systemProfiler } from '../monitor/SystemProfiler';
import { paramSyn } from '../broker/paramOpt/ParamSyn';
import { ModelManager } from '../worker/ImageIdModelManager';
import { InferenceTask, InferenceInputType } from '../worker/InferenceWorker';
import { systemDateTime } from '@kit.BasicServicesKit';

class Scheduler{
  private static SchedulerInstance: Scheduler

  private deviceInfos:HashMap<string,DeviceInfo> = new HashMap();
  // 与原项目解耦合
  workScheduler(task: InferenceTask, logMessages: Array<string>):Boolean{
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
        this.dispatchTask(task, highestScoreNode[0])
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
    // TODO 更新计算公式，加入网络因素;在系统监控模块加入计算逻辑
    let score = param[0] * (100 - nodeInfo.cpuUsage) + param[1] *(100 - nodeInfo.memoryUsage)  + param[3] * nodeInfo.storageFree + param[2] *nodeInfo.batteryLevel;
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
      const time = await this.getCurrentTimeAsync();
      // TODO 测试后删除
      console.info(`Succeeded in getting currentTime : ${time}`);
      taskInfo.taskId = time.toString();
      taskInfo.fromClient = ownName;
      taskInfo.toClient = to;
      taskInfo.interTime = await this.getCurrentTimeAsync();
      // TODO 针对特殊任务类型，Worker中添加发送数据处理？（还是传输的问题）
      // taskInfo.params.bitmap = await ModelManagerInstance.processImageTOBase64(url);
      taskInfo.params = inferenceTask;
      taskDispatch.sendTask(taskInfo);
    } catch (error) {
      console.error("Failed to send task:", error);
    }
  }

  // 使用封装的 Promise 方法获取当前时间
  private getCurrentTimeAsync(): Promise<number> {
    return new Promise((resolve, reject) => {
      systemDateTime.getTime(true)
    });
  }
}
export { Scheduler };