# 基于ArkTS的鸿蒙多终端协同推理框架Client接口优化方案（符合ArkTS语法）

## 1. 优化目标

- 重构Worker模块为接口定义优先架构，提升框架通用性
- 允许使用者独立实现具体推理逻辑，支持多种推理任务类型
- 规范Client使用流程
- 确保接口设计具备良好的扩展性、清晰的参数定义和完善的类型标注
- 严格遵循ArkTS语法规范，禁止使用any类型、动态修改对象属性等
- 提供详细的接口文档和使用示例

## 2. 核心设计思路

### 2.1 Worker模块接口化设计

将现有的ModelManager拆分为通用接口定义和默认实现，允许使用者自定义实现各种推理逻辑：

- 定义通用的`InferenceWorker`接口，不局限于图像识别任务
- 严格遵循ArkTS语法规范，所有类型必须明确声明
- 支持多种输入类型（图像、文本、音频等）
- 保留现有的ModelManager作为图像识别的默认实现
- 支持使用者自定义实现并注册到Client中

### 2.2 优化后的Client使用流程

1. 使用者基于`InferenceWorker`接口实现具体推理任务的Worker模块
2. 初始化Client实例，在建立MQTT Broker连接过程中完成自定义Worker模块的注册与关联
3. 保持Client后续使用流程与现有实现一致

## 3. 详细设计方案

### 3.1 接口定义（符合ArkTS语法）

#### 3.1.1 通用类型定义

```typescript
// 推理任务输入类型枚举
export enum InferenceInputType {
  IMAGE = 'image',
  TEXT = 'text',
  AUDIO = 'audio',
  VIDEO = 'video',
  OTHER = 'other'
}

// 推理任务参数类型
export interface InferenceParams {
  [key: string]: string | number | boolean | ArrayBuffer;
}

// 图像输入数据类型
export interface ImageInputData {
  uri: string; // 本地图像URI
}

// 文本输入数据类型
export interface TextInputData {
  text: string; // 文本内容
}

// 音频输入数据类型
export interface AudioInputData {
  buffer: ArrayBuffer; // 音频数据缓冲区
  sampleRate: number; // 采样率
  channels: number; // 声道数
}

// 通用推理输入类型
export interface InferenceInput {
  type: InferenceInputType;
  data: ImageInputData | TextInputData | AudioInputData | ArrayBuffer;
  params?: InferenceParams;
}

// 推理结果类型
export interface InferenceResult {
  // 通用结果字段
  success: boolean;
  message?: string;
  
  // 图像识别特定结果（可选）
  maxArray?: number[];
  maxIndexArray?: number[];
  
  // 文本识别特定结果（可选）
  textResult?: string;
  confidence?: number;
  
  // 自定义结果数据（可选）
  customData?: ArrayBuffer;
}
```

#### 3.1.2 通用InferenceWorker接口

```typescript
// 推理Worker接口
export interface InferenceWorker {
  // 初始化模型
  initModel(modelName: string): Promise<void>;
  
  // 执行推理（通用方法，支持不同类型的输入）
  infer(input: InferenceInput): Promise<InferenceResult>;
  
  // 检查是否已初始化
  isInitialized(): boolean;
  
  // 释放资源（可选）
  release?(): Promise<void>;
}
```

#### 3.1.3 Client接口扩展

- 在`HarmonyInferenceClient`中添加Worker注册机制
- 修改`init`方法，支持传入自定义Worker实例
- 支持在运行时切换Worker实例
- 扩展`submitTask`方法，支持通用的推理输入类型

### 3.2 代码结构调整

```
worker/
├── InferenceWorker.ets    // 通用推理Worker接口定义
├── ModelManager.ets       // 默认图像识别实现
├── Model.ets              // 模型推理核心逻辑（保持不变）
└── SerialTaskQueue.ets    // 任务队列管理（保持不变）
```

### 3.3 核心实现修改

#### 3.3.1 HarmonyInferenceClient修改

- 添加`worker`成员变量，支持自定义Worker
- 修改`init`方法，支持传入Worker实例
- 扩展`submitTask`方法，支持通用的推理输入
- 在内部调用中，将具体推理逻辑委托给Worker实例

#### 3.3.2 ModelManager适配

修改现有的ModelManager，使其实现通用的InferenceWorker接口：

```typescript
class ModelManager implements InferenceWorker {
  private static instance: ModelManager;
  private modelBuffer: ArrayBuffer = new ArrayBuffer(0);
  private modelInputHeight: number = 224;
  private modelInputWidth: number = 224;
  private isInit: boolean = false;
  
  // 实现通用接口方法
  async infer(input: InferenceInput): Promise<InferenceResult> {
    if (!this.isInit) {
      return {
        success: false,
        message: 'Model not initialized'
      };
    }
    
    let processedData: ArrayBuffer;
    
    // 处理不同类型的输入
    if (input.type === InferenceInputType.IMAGE) {
      let imageData = input.data as ImageInputData;
      processedData = await this.processImage(imageData.uri);
    } else {
      // 处理其他类型的输入
      return {
        success: false,
        message: `Unsupported input type: ${input.type}`
      };
    }
    
    let predictResult = await this.predictWithTopResults([processedData]);
    
    return {
      success: true,
      maxArray: predictResult.maxArray,
      maxIndexArray: predictResult.maxIndexArray
    };
  }
  
  // 其他方法保持不变...
}
```

#### 3.3.3 任务调度适配

修改Scheduler和SerialTaskQueue，使其支持通用的推理输入类型：

- 更新任务信息结构，支持多种输入类型
- 确保任务在设备间传输时能够正确序列化和反序列化
- 严格遵循ArkTS语法规范，禁止使用动态特性

### 3.4 使用示例

#### 3.4.1 自定义文本推理Worker示例

```typescript
// 1. 实现自定义文本推理Worker
class TextInferenceWorker implements InferenceWorker {
  private model: any; // 注意：实际实现中需替换为具体类型
  private isInit: boolean = false;
  
  // 初始化模型
  async initModel(modelName: string): Promise<void> {
    // 初始化文本模型逻辑
    this.isInit = true;
  }
  
  // 执行文本推理
  async infer(input: InferenceInput): Promise<InferenceResult> {
    if (!this.isInit) {
      return {
        success: false,
        message: 'Model not initialized'
      };
    }
    
    if (input.type !== InferenceInputType.TEXT) {
      return {
        success: false,
        message: `Unsupported input type: ${input.type}`
      };
    }
    
    let textData = input.data as TextInputData;
    // 执行文本推理逻辑
    let result = await this.model.predict(textData.text);
    
    return {
      success: true,
      textResult: result.text,
      confidence: result.confidence
    };
  }
  
  // 检查是否已初始化
  isInitialized(): boolean {
    return this.isInit;
  }
}
```

#### 3.4.2 Client使用示例

```typescript
// 2. 初始化Client并注册自定义Worker
const textWorker = new TextInferenceWorker();
const client = HarmonyInferenceClient.getInstance();

// 初始化Client，传入自定义Worker
let initSuccess = await client.init({
  url: 'mqtt://example.com',
  clientId: 'device-123'
}, 'text-model.ms', textWorker);

if (initSuccess) {
  // 3. 使用Client进行文本推理
  let textInput: InferenceInput = {
    type: InferenceInputType.TEXT,
    data: {
      text: '这是一段测试文本'
    },
    params: {
      maxLength: 100
    }
  };
  
  let result = await client.submitTask(textInput);
  
  if (result.success) {
    console.log('推理结果:', result.textResult);
  } else {
    console.error('推理失败:', result.message);
  }
}
```

#### 3.4.3 兼容现有代码示例

```typescript
// 保持向后兼容，使用默认图像识别Worker
const client = HarmonyInferenceClient.getInstance();

// 初始化Client，使用默认Worker
let initSuccess = await client.init({
  url: 'mqtt://example.com',
  clientId: 'device-123'
}, 'image-model.ms');

if (initSuccess) {
  // 使用现有方式提交图像任务
  let result = await client.submitTask({
    imageUri: 'image://example.jpg'
  });
  
  console.log('推理结果:', result);
}
```

## 4. 实现步骤

1. 创建`InferenceWorker.ets`文件，定义通用推理Worker接口和相关类型
2. 修改`ModelManager.ets`，使其实现通用的InferenceWorker接口
3. 修改`HarmonyInferenceClient.ets`，添加Worker注册机制和通用任务支持
4. 更新Scheduler和SerialTaskQueue，支持通用推理输入
5. 编写详细的接口文档和使用示例
6. 测试验证优化后的功能，确保向后兼容

## 5. 预期效果

- 框架通用性显著提升，支持多种推理任务类型
- 使用者可以灵活实现自定义推理逻辑
- 接口设计清晰、通用，易于理解和使用
- 严格遵循ArkTS语法规范，确保编译通过和运行稳定
- 保持与现有代码的良好兼容性
- 提供良好的扩展性，便于未来功能扩展
- 支持不同推理引擎和模型格式

## 6. 注意事项

- 严格遵循ArkTS语法规范，禁止使用any类型、动态修改对象属性等
- 确保接口设计的向后兼容性，不破坏现有代码
- 提供完整的类型定义和文档
- 考虑并发安全问题，确保多线程环境下的稳定性
- 保持代码的可读性和可维护性
- 提供丰富的示例代码，便于使用者快速上手
- 支持不同类型的模型加载和推理引擎集成

通过以上优化设计，我们将构建一个更加灵活、通用的鸿蒙多终端协同推理框架，允许使用者根据自己的需求实现各种类型的推理逻辑，同时严格遵循ArkTS语法规范，确保框架的稳定性和兼容性。