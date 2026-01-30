# 基于OpenHarmony的多终端推理任务调度框架

[TOC]



## 1. 项目概述

基于OpenHarmony的多终端推理任务调度框架是一个专为分布式AI推理场景设计的系统级解决方案，旨在实现多设备协同、智能任务分配和高效推理执行。该框架通过整合MQTT通信、系统监控、智能调度和任务执行等核心模块，构建了一个统一的多终端推理任务管理平台，为开发者提供了简洁易用的API接口，同时实现了资源的最优利用和任务的高效执行。

> 本项目在OpenHarony6.0、API20版本SDK、IDE版本6.0.0版本已验证通过

## 2. 核心功能

### 2.1 多终端协同调度
- **设备发现与状态同步**：自动发现网络中的其他设备并实时同步设备状态
- **分布式任务分配**：基于设备性能和网络状况智能分配推理任务
- **跨设备通信**：通过MQTT协议实现设备间的可靠通信

### 2.2 智能任务管理
- **任务队列管理**：实现任务的串行化执行和优先级调度
- **任务状态跟踪**：实时监控任务执行状态，支持任务结果查询
- **故障处理机制**：当任务执行失败时提供错误处理和重试机制

### 2.3 系统监控与优化
- **实时系统监控**：监控设备的CPU、内存、存储、电池等状态
- **网络延迟检测**：定期测试设备间网络延迟，为调度决策提供依据
- **性能参数优化**：根据系统状态动态调整任务执行参数

### 2.4 统一API接口
- **简洁易用的接口**：提供统一的API接口，简化开发流程
- **类型安全**：基于OpenHarmony Ark TS的强类型系统，确保代码安全性
- **异步操作支持**：支持异步任务执行和结果回调

## 3. 架构设计

### 3.1 整体架构

该框架采用分层设计架构，主要包含以下几个核心层次：

1. **API层**：提供统一的对外接口，包括任务提交、状态查询等功能
2. **调度层**：负责任务的智能分配和调度决策
3. **通信层**：处理设备间的通信和数据传输
4. **监控层**：实时监控设备状态和网络状况
5. **执行层**：负责实际的推理任务执行

### 3.2 模块组成

框架由四个核心模块组成：
- **Broker模块**：负责设备间的通信和消息传递
- **Monitor模块**：负责设备状态监控和信息收集
- **Scheduler模块**：负责任务的智能调度和分配
- **Worker模块**：负责推理任务的实际执行

### 3.3 数据流

1. **任务提交流程**：
   - 用户通过API提交推理任务
   - 调度器评估设备状态，选择最优执行设备
   - 若选择本地执行，直接提交到本地任务队列
   - 若选择远程执行，通过MQTT发送到目标设备

2. **结果返回流程**：
   - 执行设备完成推理任务
   - 将结果通过MQTT发送回源设备
   - 源设备接收结果并更新任务状态
   - 用户通过API获取任务结果

## 4. 技术特点

### 4.1 基于OpenHarmony Ark TS
- 利用OpenHarmony Ark TS的强类型系统确保代码安全性
- 支持鸿蒙原生API和组件，确保系统兼容性

### 4.2 分布式架构
- 采用去中心化设计，无单点故障
- 支持动态设备加入和退出
- 基于MQTT协议实现设备间的可靠通信

### 4.3 智能调度算法
- 基于多维度指标（CPU、内存、存储、电池、网络延迟）的设备性能评估
- 实时调整任务分配策略，适应系统状态变化
- 支持任务优先级和截止时间约束

### 4.4 可扩展性
- 模块化设计，支持功能模块的独立扩展
- 支持多种推理模型和输入类型
- 提供自定义Worker接口，支持第三方推理引擎集成

## 5. 模块组成与实现细节

### 5.1 HarmonyInferenceClient核心实现

`HarmonyInferenceClient`是框架的核心类，采用单例模式实现，负责整合各个功能模块并提供统一的API接口。

#### 5.1.1 核心功能
- **初始化与销毁**：管理框架的生命周期
- **任务提交与管理**：处理推理任务的提交、执行和结果获取
- **系统状态监控**：获取设备状态和网络状况
- **连接管理**：处理MQTT连接的建立和维护

#### 5.1.2 关键代码实现

```typescript
// 推理任务参数
export interface InferenceTask {
  // 任务相关字段
  taskId: string;
  modelName?: string;

  // 推理输入字段
  type: InferenceInputType;
  data: ImageInputData | TextInputData | AudioInputData | ArrayBuffer;
  params?: Record<string, string | number | boolean | ArrayBuffer>;

}

// 推理任务输入类型枚举
export enum InferenceInputType {
  IMAGE = 'image',
  TEXT = 'text',
  AUDIO = 'audio',
  VIDEO = 'video',
  OTHER = 'other'
}

// 图像输入数据类型
export interface ImageInputData {
  imageData: string; // 图像数据
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


// 推理Worker接口
export interface InferenceWorker {

  // 初始化模型
  initModel(modelName: string): Promise<void>;
  
  // 执行推理（直接使用InferenceTask参数）
  infer(task: InferenceTask): Promise<InferenceResult>;
  
  // 检查是否已初始化
  isInitialized(): boolean;
  
  // 释放资源（可选）
  release?(): Promise<void>;
}

class HarmonyInferenceClient {
  
  // 初始化方法
  public async init(config: MQTTConfig, modelName: string, customWorker?: InferenceWorker): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }

    try {
      MQTTOption.clientId = config.clientId;
      await this.initMQTTClient(config)
      this.initEventListeners()

      // 使用自定义Worker或默认Worker
      if (customWorker) {
        this.worker = customWorker;
      } else {
        this.worker = this.defaultWorker;
      }

      // 初始化模型
      await this.worker.initModel(modelName);
      this.modelName = modelName;

      // 初始化全局任务队列
      GlobalTaskManager.init(this.worker);

      // 启动设备状态同步
      this.startDeviceStatusSync();

      this.isInitialized = true;
      return true;
    } catch (error) {
      console.error('HarmonyInferenceClient initialization failed:', error);
      return false;
    }
  }

  }
}
```

### 5.2 Broker模块

Broker模块负责设备间的通信和消息传递，基于MQTT协议实现，主要包含以下组件：

#### 5.2.1 MQTTClient
- **连接管理**：处理MQTT连接的建立、维护和断开
- **消息发布与订阅**：支持发布消息到指定主题和订阅感兴趣的主题
- **消息处理**：接收和处理来自其他设备的消息

#### 5.2.2 TaskDispatch
- **任务分发**：负责将任务发送到目标设备
- **结果回传**：处理任务执行结果的回传
- **消息解析**：解析接收到的任务和结果消息

#### 5.2.3 NodeInfoSyn
- **节点信息同步**：同步网络中其他设备的状态信息
- **延迟测试**：测试设备间的网络延迟
- **信息维护**：维护其他节点的状态信息

### 5.3 Monitor模块

Monitor模块负责设备状态的监控和信息收集，主要包含以下组件：

#### 5.3.1 SystemProfiler
- **系统信息采集**：收集设备的CPU、内存、存储、电池等状态信息
- **设备信息管理**：管理本设备和其他设备的状态信息
- **信息合并**：将本设备和其他设备的信息合并为统一的设备列表

### 5.4 Scheduler模块

Scheduler模块负责任务的智能调度和分配，是框架的核心决策组件：

#### 5.4.1 调度算法
- **设备性能评估**：基于设备的CPU、内存、存储、电池和网络延迟等指标评估设备性能
- **任务分配决策**：根据设备性能和任务需求，选择最优的执行设备
- **负载均衡**：确保任务分配的均衡性，避免单个设备过载

### 5.5 Worker模块

Worker模块负责推理任务的实际执行，主要包含以下组件：

#### 5.5.1 InferenceWorker接口
- **模型初始化**：初始化推理模型
- **推理执行**：执行推理任务
- **资源释放**：释放模型和相关资源

#### 5.5.2 SerialTaskQueue
- **任务队列管理**：管理待执行的推理任务队列
- **串行执行**：确保任务的串行化执行，避免资源冲突
- **任务状态管理**：跟踪任务的执行状态和结果

#### 5.5.3 GlobalTaskManager
- **全局队列管理**：管理全局任务队列的生命周期
- **队列获取**：提供获取任务队列的接口

## 6. 使用指南

### 6.1 环境配置

1. **MQTT服务器配置**：
   - 搭建MQTT服务器，确保设备网络可达（有对应的Java项目可以提供）
2. **设备准备**：
   - 确保设备运行OpenHarmony系统
   - 安装必要的依赖包和模块
   - 配置设备网络连接，确保设备间网络互通

### 6.2 初始化流程

1. **导入必要的模块**：
   ```typescript
   import { HarmonyInferenceClient, MQTTConfig, InferenceTask, SystemStatus } from '../manager/HarmonyInferenceClient';
   import { InferenceInputType, InferenceWorker } from '../manager/worker/InferenceWorker';
   import { ModelManager } from '../TestImageTask/ImageIdModelManager';
   import deviceInfo from '@ohos.deviceInfo';
   ```

2. **创建并初始化客户端**：
   
   ```typescript
   // 创建客户端实例
   private client = HarmonyInferenceClient.getInstance();
   // 自定义推理执行逻辑，实现Worker模块定义的接口
   private ImageModelWorker: InferenceWorker = ImageModelManager.getInstance();
   
   // MQTT配置
   private mqttConfig: MQTTConfig = {
     url: 'mqtt://10.218.227.159:1883',
     clientId: deviceName,
     userName: 'root',
     password: 'admin',
     topic: '/test/123',
     qos: 1
   };
   
   // 初始化客户端
   const result = await this.client.init(this.mqttConfig, 'mobilenetv2.ms', this.ImageModelWorker);
   this.isInitialized = result;
   this.connectionStatus = result ? 'Connected' : 'Failed';
   ```
   
   ```typescript
   // 自定义推理执行逻辑示例
   class ImageIdModelManager implements InferenceWorker {
     // 实现InferenceWorker接口的infer方法，接受InferenceTask参数
     async infer(task: InferenceTask): Promise<InferenceResult> {
       if (!this.isInit) {
         return {
           success: false,
           message: 'Model not initialized',
         };
       }
       let processedData: ArrayBuffer;
       
       // 处理输入
       if (task.type === InferenceInputType.IMAGE) {
         let imageData = task.data as ImageInputData;
         processedData = await this.processImage(imageData.imageData);
       } else {
         // 类型不匹配
         return {
           success: false,
           message: `Unsupported input type: ${task.type}`
         };
       }
       let predictResult = await this.predictWithTopResults([processedData]);
       return {
         success: true,
         message:"识别成功",
         result:{
           maxArray: predictResult.maxArray,
           maxIndexArray: predictResult.maxIndexArray
         }
       };
     }
   }
   ```

### 6.3 API调用方法

1. **检查连接状态**：
   ```typescript
   const connected = await this.client.isConnected();
   this.connectionStatus = connected ? 'Connected' : 'Disconnected';
   ```

2. **获取系统状态**：
   ```typescript
   this.systemStatus = this.client.getSystemStatus();
   ```

3. **获取所有设备信息**：
   ```typescript
   const allDevices = this.client.getAllDevices();
   ```

4. **获取指定设备信息**：
   ```typescript
   const deviceInfo = this.client.getDeviceInfo(deviceName);
   ```

5. **获取任务状态**：
   ```typescript
   const taskStatus = this.client.getTaskStatus(taskId);
   ```

6. **获取所有任务状态**：
   ```typescript
   const allTaskStatus = this.client.getAllTaskStatus();
   ```

### 6.4 任务提交与管理

1. **创建推理任务**：
   ```typescript
   private testTask: InferenceTask = {
     taskId: `task-${Date.now()}`,
     modelName: 'image-model.ms',
     type: InferenceInputType.IMAGE,
     data: {
       imageData: ''
     },
     params: {
       "maxResults": 5
     }
   };
   ```

2. **提交任务**：
   ```typescript
   try {
     this.log('Submitting test task...');
     const result = await this.client.submitTask(this.testTask);
     this.testResult = JSON.stringify(result);
     this.log('Task completed successfully');
   } catch (error) {
     this.log(`Task failed: ${error}`);
   }
   ```

### 6.5 结果获取

1. **同步获取结果**：
   - 对于本地执行的任务，`submitTask`方法会直接返回任务结果
   - 对于远程执行的任务，`submitTask`方法会等待结果返回后再返回

2. **异步获取结果**：
   - 可以通过`getTaskStatus`方法查询任务状态
   - 可以通过事件监听获取任务结果通知

### 6.6 销毁客户端

```typescript
await this.client.destroy();
this.isInitialized = false;
this.connectionStatus = 'Disconnected';
```

### 6.7约束与限制

1. 本项目目前仅支持标准系统上运行。
2. 本项目建议使用API20版本SDK。
3. 本项目在IDE版本6.0.0及以上版本已验证通过。

## 7. 应用场景

### 7.1 智能家居
- **智能设备协同**：多个智能设备协同处理家庭场景中的AI推理任务
- **边缘计算**：将推理任务分配到合适的边缘设备，减少云端依赖
- **实时响应**：基于设备状态和网络状况，确保推理任务的实时响应

### 7.2 智能医疗
- **分布式医疗影像分析**：将医疗影像分析任务分配到多个设备并行处理
- **实时监测**：实时监测患者生理数据，及时发现异常情况
- **资源优化**：根据医院设备的使用情况，智能分配计算资源

### 7.3 智能交通
- **交通流量分析**：多个交通监控设备协同分析交通流量
- **车辆识别**：分布式处理车辆识别任务，提高识别效率
- **路况预测**：基于多设备数据，预测路况变化

### 7.4 工业物联网
- **设备状态监测**：实时监测工业设备的运行状态
- **故障预测**：基于多设备数据，预测设备故障
- **生产优化**：智能分配计算任务，优化生产流程

## 8. 总结与展望

基于OpenHarmony的多终端推理任务调度框架通过整合MQTT通信、系统监控、智能调度和任务执行等核心模块，构建了一个统一的多终端推理任务管理平台，为开发者提供了简洁易用的API接口，同时实现了资源的最优利用和任务的高效执行。

该框架具有以下优势：
- **多终端协同**：实现了多个设备的协同工作，提高了系统的整体性能
- **智能调度**：基于设备状态和网络状况，智能分配推理任务
- **实时监控**：实时监控设备状态和任务执行情况
- **简洁易用**：提供了统一的API接口，简化了开发流程
- **可扩展性**：模块化设计，支持功能模块的独立扩展

未来，我们计划在以下方面进一步完善和扩展该框架：

- **优化调度算法**：进一步优化任务调度算法，提高任务分配的准确性和效率
- **增强安全性**：加强设备间通信的安全性，保护数据隐私
- **支持更多通信协议**：除MQTT外，支持更多通信协议，如CoAP、HTTP等
- **云边协同**：支持与云端服务的协同，实现更复杂的推理任务处理

基于OpenHarmony的多终端推理任务调度框架为分布式AI推理场景提供了一个完整的解决方案，有望在智能家居、智能医疗、智能交通等领域得到广泛应用，为OpenHarmony生态系统的发展做出贡献。