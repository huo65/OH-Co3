import HashMap from '@ohos.util.HashMap';
import { NodeInfo, systemProfiler } from '../monitor/SystemProfiler';

class Scheduler{

  private deviceInfos:HashMap<string,NodeInfo> = new HashMap();
  workScheduler(){
    this.deviceInfos = systemProfiler.getOwnInfo()

  }

  calculate_score(batteryState: number,memorySize: number,cpuUsage: number,statfsFreeSize: number){
    let  score = 0.5 * batteryState + 0.2 *(1 - cpuUsage)  + 0.2 *(1 - memorySize);
    return score;
  }
}
export const scheduler = new Scheduler()