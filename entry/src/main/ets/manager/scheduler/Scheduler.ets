import HashMap from '@ohos.util.HashMap';
import { ownName } from '../broker/monitor/NodeInfoSyn';
import { taskDispatch, TaskTransmitData } from '../broker/task/TaskDispatch';
import { DeviceInfo, systemProfiler } from '../monitor/SystemProfiler';
import { paramSyn } from '../broker/paramOpt/ParamSyn';
import { InferenceTask } from '../worker/InferenceWorker';
import { systemDateTime } from '@kit.BasicServicesKit';

/**
 * 任务调度器类
 * 负责收集设备节点信息，计算节点评分，并根据评分结果决策任务执行位置（本地执行或分发到其他节点）
 * 采用单例模式，全局唯一调度实例
 */
class Scheduler{
  private static SchedulerInstance: Scheduler

  /**
   * 设备信息映射表
   * 存储当前网络中所有在线设备的名称及其详细性能信息
   */
  private deviceInfos:HashMap<string,DeviceInfo> = new HashMap();

  /**
   * 任务调度决策入口
   * 收集节点信息，计算各节点评分，选择最优节点执行任务
   * @param task - 待调度的推理任务
   * @param logMessages - 日志消息数组（预留参数，用于记录调度日志）
   * @returns 是否在本地执行任务（true:本地执行；false:已分发到其他节点）
   */
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
      console.error(`[HarmonyInference] [Scheduler] 获取设备信息失败: ${error}`);
    }

    if (highestScoreNode) {
      console.info(`[HarmonyInference] [Scheduler] 最优节点: ${highestScoreNode[0]}, 评分: ${this.calculate_score(highestScoreNode[1]).toFixed(2)}`);
      if (highestScoreNode[0] != ownName) {
        this.dispatchTask(task, highestScoreNode[0])
        console.info(`[HarmonyInference] [Scheduler] 任务已分发至节点: ${highestScoreNode[0]}`);
        return false
      }
    } else {
      console.warn(`[HarmonyInference] [Scheduler] 未找到可用节点，将在本地执行任务`);
    }
    return true
  }

  /**
   * 计算节点评分
   * 根据节点性能指标和权重参数，计算节点的综合得分
   * 评分越高表示节点越适合执行任务
   * @param nodeInfo - 节点的设备性能信息
   * @returns 节点的综合评分
   */
  calculate_score(nodeInfo:DeviceInfo){
    let param = paramSyn.getNewParam()
    let score = param[0] * (1 - nodeInfo.cpuUsage) + param[1] *(1 - nodeInfo.memoryUsage)  + param[2] * nodeInfo.batteryLevel + param[3] *nodeInfo.storageFree + param[4]*(1 - nodeInfo.latency);
    return score;
  }

  /**
   * 获取调度器单例实例
   * @returns Scheduler单例对象
   */
  public static getInstance(): Scheduler {
    if (!Scheduler.SchedulerInstance) {
      Scheduler.SchedulerInstance = new Scheduler()
    }
    return Scheduler.SchedulerInstance
  }

  /**
   * 分发任务到指定节点
   * 将推理任务封装为传输格式，通过任务调度模块发送给目标设备
   * @param inferenceTask - 待分发的推理任务
   * @param to - 目标节点设备名称
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
      console.error(`[HarmonyInference] [Scheduler] 分发任务失败: ${error}`);
    }
  }
}
export { Scheduler };