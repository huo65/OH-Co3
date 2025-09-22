
import { BusinessError } from '@ohos.base';
import { taskDispatch, TaskInfo } from '../broker/task/TaskDispatch';
import { ModelManager } from './ModelManager';

const ModelManagerInstance: ModelManager = ModelManager.getInstance()

export class SerialTaskQueue {
//   class TaskInfo {
//   taskId: string;
//   fromClientId: string;
//   toClientId: string;
//   interTime: string;
//   params: TaskParams;
//   constructor() {
//     this.taskId = "";
//     this.fromClientId = "";
//     this.toClientId = "";
//     this.interTime = "";
//     this.params = {};
//   }
// }
//   interface TaskParams {
//   bitmap?: string;
// }
  private taskQueue: TaskInfo[] = []; // 使用数组模拟队列
  private isProcessing: boolean = false;


  // 添加任务（非阻塞）
  addTask(taskInfo: TaskInfo): void {
    this.taskQueue.push(taskInfo);
    console.log(`[SerialTaskQueue] 任务已加入队列，当前队列长度: ${this.taskQueue.length}`);
    this.processNextTask(); // 尝试启动处理
  }

  // 内部：处理下一个任务（串行）
  private async processNextTask(): Promise<void> {
    if (this.isProcessing || this.taskQueue.length === 0) {
      return;
    }

    this.isProcessing = true;
    const task = this.taskQueue.shift(); // 取出队首任务

    if (!task) {
      this.isProcessing = false;
      return;
    }

    try {
      // 处理图片
      const processedImage = await ModelManagerInstance.processImageWithParam(task.params.bitmap);

      //  执行图像识别（异步）
      const result = await ModelManagerInstance.predictWithTopResults([processedImage]);

      //  发送结果
      taskDispatch.sendTaskResult();
      console.log('[SerialTaskQueue] 任务处理完成并发送结果');

    } catch (err) {
      let error = err as BusinessError;
      console.error(`[SerialTaskQueue] 任务处理失败: ${error.message}`);
    } finally {
      this.isProcessing = false;
      // 处理下一个任务（递归调用，确保串行）
      this.processNextTask();
    }
  }

  // 停止队列（清空任务）
  shutdown(): void {
    this.taskQueue = [];
    this.isProcessing = false;
    console.log('[SerialTaskQueue] 队列已关闭');
  }

  // 获取当前队列长度（可选）
  getQueueLength(): number {
    return this.taskQueue.length;
  }
}