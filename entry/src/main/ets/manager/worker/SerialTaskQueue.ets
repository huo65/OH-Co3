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
    // 优先复用 InferenceTask 自身携带的 taskId，保证全链路追踪一致性
    const taskId: string = task.taskId && task.taskId.length > 0
      ? task.taskId
      : `task-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    
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
        console.error(`[HarmonyInference] [SerialTaskQueue] 添加任务到队列失败: ${error}`);
      }
      console.info(`[HarmonyInference] [SerialTaskQueue] 任务已加入队列，任务ID: ${taskId}，当前队列长度: ${this.taskQueue.length}`);
      
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
    let taskInfo: TaskInfo|null = null
    try {
      // 取出队列中的第一个任务
      // taskInfo = this.taskQueue.getFirst()!;
      taskInfo = this.taskQueue.removeFirst();
      console.info(`[HarmonyInference] [SerialTaskQueue] 开始处理任务，任务ID: ${taskInfo.taskId}`);
      
      // 执行推理
      const result: InferenceResult = await this.worker.infer(taskInfo.task);
      
      // 任务执行成功
      taskInfo.resolve(result);
      console.info(`[HarmonyInference] [SerialTaskQueue] 任务执行完成，任务ID: ${taskInfo.taskId}`);
    } catch (error) {
      console.error(`[HarmonyInference] [SerialTaskQueue] 任务执行失败: ${error}`);
      if (taskInfo) {
        taskInfo.reject(error as Error);
      }
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
      console.error(`[HarmonyInference] [SerialTaskQueue] 清空任务队列失败: ${error}`);
    }
    this.isProcessing = false;
    console.info(`[HarmonyInference] [SerialTaskQueue] 任务队列已关闭`);
  }

  // 获取当前队列长度
  getQueueLength(): number {
    return this.taskQueue.length;
  }

}