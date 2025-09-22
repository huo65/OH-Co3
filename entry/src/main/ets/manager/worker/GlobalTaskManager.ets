import { SerialTaskQueue } from './SerialTaskQueue';

// 如果你需要全局唯一队列，再在外面包一层单例
export class GlobalTaskManager {
  private static instance: SerialTaskQueue;

  static getQueue(): SerialTaskQueue {
    if (!GlobalTaskManager.instance) {
      GlobalTaskManager.instance = new SerialTaskQueue();
    }
    return GlobalTaskManager.instance;
  }
}