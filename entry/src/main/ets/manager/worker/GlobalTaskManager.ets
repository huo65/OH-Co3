import { SerialTaskQueue } from './SerialTaskQueue';
import { InferenceWorker } from './InferenceWorker';

export class GlobalTaskManager {
  private static instance: SerialTaskQueue | null = null;

  // 初始化全局任务队列，接收推理Worker实例
  static init(worker: InferenceWorker): void {
    if (!GlobalTaskManager.instance) {
      GlobalTaskManager.instance = new SerialTaskQueue(worker);
      console.info('[GlobalTaskManager] Task queue initialized');
    }
  }

  // 获取全局任务队列实例
  static getQueue(): SerialTaskQueue {
    if (!GlobalTaskManager.instance) {
      throw new Error('GlobalTaskManager has not been initialized');
    }
    return GlobalTaskManager.instance;
  }

  // 检查是否已初始化
  static isInitialized(): boolean {
    return GlobalTaskManager.instance !== null;
  }
}