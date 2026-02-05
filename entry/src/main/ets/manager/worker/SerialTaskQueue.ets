import { InferenceTask, InferenceResult, InferenceWorker } from './InferenceWorker';
import { Deque, LinkedList } from '@kit.ArkTS';

// 任务信息接口
export interface TaskInfo {
  taskId: string;
  task: InferenceTask;
  resolve: (result: InferenceResult) => void;
  reject: (error: Error) => void;
  createdAt: number;
}

export class SerialTaskQueue {
  private taskQueue: LinkedList<TaskInfo> = new LinkedList();
  private isProcessing: boolean = false;
  private worker: InferenceWorker;

  // 构造函数，接收推理Worker实例
  constructor(worker: InferenceWorker) {
    this.worker = worker;
  }

  // 添加任务（非阻塞）
  addTask(task: InferenceTask): Promise<InferenceResult> {
    const taskId: string = `task-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    
    return new Promise<InferenceResult>((resolve, reject) => {
      const taskInfo: TaskInfo = {
        taskId: taskId,
        task: task,
        resolve: resolve,
        reject: reject,
        createdAt: Date.now()
      };

      try {
        this.taskQueue.add(taskInfo);
      } catch (error) {
        console.error(`[SerialTaskQueue] Task add failed: ${error}`);
      }
      console.info(`[SerialTaskQueue] Task added to queue: ${taskId}, queue length: ${this.taskQueue.length}`);
      
      // 如果当前没有在处理任务，立即开始处理
      if (!this.isProcessing) {
        this.processTask();
      }
    });
  }

  // 处理任务
  private async processTask(): Promise<void> {
    if (this.isProcessing || this.taskQueue.length === 0) {
      return;
    }
    
    this.isProcessing = true;
    
    try {
      // 取出队列中的第一个任务
      const taskInfo: TaskInfo = this.taskQueue.getFirst()!;
      console.info(`[SerialTaskQueue] Processing task: ${taskInfo.taskId}`);
      
      // 执行推理
      const result: InferenceResult = await this.worker.infer(taskInfo.task);
      
      // 任务执行成功
      taskInfo.resolve(result);
      console.info(`[SerialTaskQueue] Task completed: ${taskInfo.taskId}`);
    } catch (error) {
      console.error(`[SerialTaskQueue] Task execution failed: ${error}`);
    } finally {
      this.isProcessing = false;
      
      // 如果队列中还有任务，继续处理
      if (this.taskQueue.length > 0) {
        this.processTask();
      }
    }
  }

  // 清空任务
  shutdown(): void {
    try {
      this.taskQueue.forEach(task => {
        task.reject(new Error('Queue shutdown'));
      });
      this.taskQueue.clear();
    } catch (error) {
      console.error(`[SerialTaskQueue] Task clear failed: ${error}`);
    }
    this.isProcessing = false;
    console.log('[SerialTaskQueue] 队列已关闭');
  }

  // 获取当前队列长度
  getQueueLength(): number {
    return this.taskQueue.length;
  }

}