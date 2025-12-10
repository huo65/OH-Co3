# HarmonyInferenceClient接口优化最终方案

## 1. 核心设计思路

根据用户反馈和当前代码结构，我们将优化HarmonyInferenceClient接口，保留InferenceTask接口（用于模型选择、执行状态等扩展），同时简化参数传递逻辑，提高代码的可读性和可维护性。

核心原则：
- 保留InferenceTask接口，用于支持模型选择、执行状态等扩展
- 简化submitTask方法，消除类型检查和转换逻辑
- 保持参数的明确性和可读性
- 遵循ArkTS语法规范
- 提高代码的可维护性和扩展性

## 2. 接口设计优化

### 2.1 优化InferenceTask接口

调整InferenceTask接口，使其直接包含推理输入的核心字段，不再需要InferenceInput类型：

```typescript
// 推理任务参数类型（保留用于模型选择、执行状态等扩展）
export interface InferenceTask {
  // 任务相关字段
  taskId?: string;
  modelName?: string;
  
  // 推理输入字段
  type: InferenceInputType;
  data: ImageInputData | TextInputData | AudioInputData | ArrayBuffer;
  params?: Record<string, string | number | boolean | ArrayBuffer>;
  
  // 兼容现有接口
  imageUri?: string;
}
```

### 2.2 删除InferenceInput接口

由于InferenceTask已经包含了所有必要的推理输入字段，删除冗余的InferenceInput接口：

```typescript
// 删除冗余的InferenceInput接口
// export interface InferenceInput {
//   type: InferenceInputType;
//   data: ImageInputData | TextInputData | AudioInputData | ArrayBuffer;
//   params?: InferenceParams;
// }
```

### 2.3 调整InferenceWorker接口

修改InferenceWorker接口的infer方法参数，直接使用任务参数：

```typescript
// 调整InferenceWorker接口，直接使用任务参数
interface InferenceWorker {
  initModel(modelName: string): Promise<void>;
  infer(task: InferenceTask): Promise<InferenceResult>;
  isInitialized(): boolean;
  release?(): Promise<void>;
}
```

## 3. submitTask方法简化

简化submitTask方法，只接受InferenceTask类型，消除类型检查和转换逻辑：

```typescript
// 提交推理任务，只接受InferenceTask类型
public async submitTask(task: InferenceTask): Promise<InferenceResult> {
  if (!this.isInitialized) {
    throw new Error('HarmonyInferenceClient is not initialized');
  }

  try {
    // 处理兼容逻辑：如果提供了imageUri，转换为标准格式
    if (task.imageUri) {
      task.type = InferenceInputType.IMAGE;
      task.data = { uri: task.imageUri };
    }

    // 使用调度器处理任务
    const logMessages: string[] = [];
    const shouldExecuteLocally = this.scheduler.workScheduler(
      (task.type === InferenceInputType.IMAGE && typeof task.data === 'object' && 'uri' in task.data) ? task.data.uri : '', 
      logMessages
    );

    if (shouldExecuteLocally) {
      // 本地执行推理
      console.info('Executing inference locally');
      const result = await this.worker.infer(task);
      return result;
    } else {
      // 任务已发送到其他设备，需要等待结果
      return new Promise((resolve, reject) => {
        // 现有实现保持不变
      });
    }
  } catch (error) {
    console.error('Error submitting task:', error);
    throw error;
  }
}
```

## 4. 保留TaskStatus接口

保留TaskStatus接口，用于任务执行状态的扩展：

```typescript
// 任务执行状态类型（保留用于扩展）
export interface TaskStatus {
  taskId: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  result?: InferenceResult;
  error?: string;
}
```

## 5. 实现步骤

1. 修改HarmonyInferenceClient.ets文件：
   - 优化InferenceTask接口，直接包含推理输入字段
   - 删除InferenceInput和ExtendedInferenceResult接口
   - 简化submitTask方法，只接受InferenceTask类型
   - 保留TaskStatus接口
2. 修改InferenceWorker.ets文件：
   - 调整InferenceWorker接口，infer方法直接接受InferenceTask参数
3. 修改ModelManager.ets文件：
   - 调整infer方法，接受InferenceTask参数
4. 更新所有调用submitTask方法的地方
5. 更新相关的注释和文档
6. 测试验证优化后的功能

## 6. 预期效果

- 保留了InferenceTask接口，支持模型选择、执行状态等扩展
- 简化了submitTask方法，消除了类型检查和转换逻辑
- 提高了代码的可读性和可维护性
- 遵循了ArkTS语法规范
- 保持了向后兼容性
- 增强了扩展性

通过这次优化，我们将使HarmonyInferenceClient的接口设计更加简洁、通用和易于使用，同时保留了对模型选择、执行状态等扩展的支持。