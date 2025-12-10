# 基于ArkTS的鸿蒙多终端协同推理框架Client接口优化文档

## 1. 优化背景

为了提升鸿蒙多终端协同推理框架的通用性和扩展性，我们对Client接口进行了优化，将Worker模块重构为接口定义优先的架构，使具体推理逻辑能够由使用者独立实现。

## 2. 核心优化内容

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

## 3. 接口定义

### 3.1 通用类型定义

#### 3.1.1 InferenceInputType枚举

```typescript
// 推理任务输入类型枚举
export enum InferenceInputType {
  IMAGE = 'image',
  TEXT = 'text',
  AUDIO = 'audio',
  VIDEO = 'video',
  OTHER = 'other'
}
```

#### 3.1.2 输入数据类型

```typescript
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
```

#### 3.1.3 推理结果类型

```typescript
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

### 3.2 InferenceWorker接口

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

## 4. 自定义Worker实现示例

### 4.1 文本推理Worker示例

```typescript
import { InferenceWorker, InferenceInput, InferenceResult, InferenceInputType, TextInputData } from '../worker/InferenceWorker';

// 自定义文本推理Worker实现
class TextInferenceWorker implements InferenceWorker {
  private model: any = null;
  private isInit: boolean = false;
  
  // 初始化模型
  async initModel(modelName: string): Promise<void> {
    // 初始化文本模型逻辑
    console.info(`Initializing text model: ${modelName}`);
    // 这里可以添加实际的模型加载逻辑
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
    console.info(`Processing text: ${textData.text}`);
    
    // 执行文本推理逻辑（模拟）
    let result = {
      text: `Processed: ${textData.text}`,
      confidence: 0.95
    };
    
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
  
  // 释放资源
  async release(): Promise<void> {
    console.info('Releasing text model resources');
    this.isInit = false;
    this.model = null;
  }
}

export { TextInferenceWorker };
```

## 5. Client使用示例

### 5.1 初始化Client并注册自定义Worker

```typescript
import { HarmonyInferenceClient, MQTTConfig } from '../manager/HarmonyInferenceClient';
import { TextInferenceWorker } from './TextInferenceWorker';

// 初始化Client并注册自定义Worker
async function initClient() {
  // 创建自定义Worker实例
  const textWorker = new TextInferenceWorker();
  
  // 获取Client单例
  const client = HarmonyInferenceClient.getInstance();
  
  // MQTT连接配置
  const mqttConfig: MQTTConfig = {
    url: 'mqtt://example.com',
    clientId: 'device-123',
    userName: 'username',
    password: 'password'
  };
  
  // 初始化Client，传入自定义Worker
  let initSuccess = await client.init(
    mqttConfig,
    'text-model.ms',
    textWorker
  );
  
  if (initSuccess) {
    console.info('Client initialized successfully with custom text worker');
  } else {
    console.error('Failed to initialize client');
  }
  
  return client;
}
```

### 5.2 使用Client进行文本推理

```typescript
import { InferenceInput, InferenceInputType } from '../manager/worker/InferenceWorker';
import { HarmonyInferenceClient } from '../manager/HarmonyInferenceClient';

// 使用Client进行文本推理
async function performTextInference(client: HarmonyInferenceClient) {
  // 创建文本推理输入
  let textInput: InferenceInput = {
    type: InferenceInputType.TEXT,
    data: {
      text: '这是一段测试文本'
    },
    params: {
      maxLength: 100
    }
  };
  
  try {
    // 提交推理任务
    let result = await client.submitTask(textInput);
    
    if (result.success) {
      console.log('推理结果:', result.textResult);
      console.log('置信度:', result.confidence);
    } else {
      console.error('推理失败:', result.message);
    }
  } catch (error) {
    console.error('推理过程中发生错误:', error);
  }
}
```

### 5.3 使用默认图像识别Worker

```typescript
import { HarmonyInferenceClient, MQTTConfig, InferenceTask } from '../manager/HarmonyInferenceClient';

// 使用默认图像识别Worker
async function initClientWithDefaultWorker() {
  // 获取Client单例
  const client = HarmonyInferenceClient.getInstance();
  
  // MQTT连接配置
  const mqttConfig: MQTTConfig = {
    url: 'mqtt://example.com',
    clientId: 'device-123'
  };
  
  // 初始化Client，使用默认Worker
  let initSuccess = await client.init(
    mqttConfig,
    'image-model.ms'
  );
  
  if (initSuccess) {
    console.info('Client initialized successfully with default image worker');
    
    // 使用现有方式提交图像任务（向后兼容）
    let imageTask: InferenceTask = {
      imageUri: 'image://example.jpg'
    };
    
    let result = await client.submitTask(imageTask);
    console.log('图像推理结果:', result);
  } else {
    console.error('Failed to initialize client');
  }
}
```

## 6. 向后兼容性说明

### 6.1 现有代码兼容

优化后的Client接口保持了与现有代码的良好兼容性：

- 现有使用`init(config, modelName)`方法初始化Client的代码可以继续使用
- 现有使用`submitTask({ imageUri: 'xxx' })`方式提交任务的代码可以继续使用
- 现有使用`InferenceResult`类型的代码可以继续使用

### 6.2 类型兼容性

- `InferenceResult`类型扩展了现有类型，添加了通用结果字段
- `submitTask`方法支持两种输入类型：`InferenceTask`（向后兼容）和`InferenceInput`（新接口）
- 所有现有方法的返回值类型保持不变

## 7. 最佳实践

### 7.1 实现自定义Worker的建议

1. 严格遵循`InferenceWorker`接口定义
2. 确保所有类型明确声明，符合ArkTS语法规范
3. 实现完整的错误处理逻辑
4. 提供资源释放方法，确保资源正确释放
5. 考虑并发安全问题

### 7.2 使用Client的建议

1. 只创建一个Client实例，使用单例模式获取
2. 在应用启动时初始化Client，在应用退出时销毁Client
3. 根据需要注册设备状态更新回调
4. 合理处理推理任务的返回结果和错误
5. 对于长时间运行的应用，定期检查Client连接状态

## 8. 常见问题解答

### 8.1 如何切换不同类型的Worker？

可以通过重新调用`init`方法并传入不同的Worker实例来切换Worker类型。

### 8.2 如何处理不同类型的推理输入？

使用`InferenceInput`类型创建推理输入，根据输入类型设置不同的`type`和`data`字段。

### 8.3 如何扩展支持新的推理任务类型？

1. 在`InferenceInputType`枚举中添加新的类型
2. 定义新的输入数据类型接口
3. 在自定义Worker的`infer`方法中添加对新类型的处理逻辑

## 9. 总结

通过本次优化，我们构建了一个更加灵活、通用的鸿蒙多终端协同推理框架，允许使用者根据自己的需求实现各种类型的推理逻辑，同时严格遵循ArkTS语法规范，确保框架的稳定性和兼容性。

优化后的框架具有以下优点：

- 更高的通用性：支持多种推理任务类型
- 更好的扩展性：允许使用者自定义实现推理逻辑
- 清晰的接口设计：易于理解和使用
- 良好的向后兼容性：不破坏现有代码
- 严格遵循ArkTS语法规范：确保编译通过和运行稳定

通过遵循本文档中的使用示例和最佳实践，使用者可以快速上手并充分利用优化后的框架功能。