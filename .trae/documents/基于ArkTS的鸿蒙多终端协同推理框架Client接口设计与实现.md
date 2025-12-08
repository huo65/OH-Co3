# 基于ArkTS的鸿蒙多终端协同推理框架Client接口设计与实现

## 1. 设计目标

设计一个统一的Client接口，整合现有模块，提供简洁易用的API，用于管理框架的完整生命周期流程，包括：

* 创建和管理MQTT连接

* 自动同步多终端设备状态

* 接收和解析任务指令

* 调度任务执行流程

* 监控系统运行状态

## 2. 核心模块整合

### 2.1 现有模块分析

| 模块名称     | 核心功能                | 关键文件                                   |
| -------- | ------------------- | -------------------------------------- |
| MQTT连接模块 | 与MQTT broker建立和管理连接 | `MQTTClient.ets`                       |
| 信息监控模块   | 收集和同步设备状态信息         | `SystemProfiler.ets`、`NodeInfoSyn.ets` |
| 调度处理模块   | 根据设备性能评分选择最优设备执行任务  | `Scheduler.ets`                        |
| 推理执行模块   | 管理模型加载和推理执行         | `ModelManager.ets`                     |
| 任务分发模块   | 负责任务的发送和接收          | `TaskDispatch.ets`                     |

### 2.2 模块关系设计

```
┌─────────────────┐
│   Client接口    │
└─────────────────┘
        │
        ├─────────────────┐
        │  MQTT连接模块   │
        └─────────────────┘
        │
        ├─────────────────┐
        │  信息监控模块   │
        └─────────────────┘
        │
        ├─────────────────┐
        │  调度处理模块   │
        └─────────────────┘
        │
        ├─────────────────┐
        │  推理执行模块   │
        └─────────────────┘
        │
        └─────────────────┐
                          │  任务分发模块   │
                          └─────────────────┘
```

## 3. Client接口设计

### 3.1 类型定义

```typescript
// MQTT连接配置类型
export interface MQTTConfig {
  url: string;
  clientId: string;
  userName?: string;
  password?: string;
  topic?: string;
  qos?: MqttQos;
}

// 设备信息类型
export interface DeviceInfo {
  deviceName: string;
  batteryLevel: number;
  memoryUsage: number;
  cpuUsage: number;
  storageFree: number;
  score: number;
}

// 推理任务参数类型
export interface InferenceTask {
  imageUri: string;
  modelName: string;
}

// 推理结果类型
export interface InferenceResult {
  maxArray: number[];
  maxIndexArray: number[];
}

// 系统状态类型
export interface SystemStatus {
  ownDevice: DeviceInfo;       // 当前设备状态
  otherDevices: Map<string, DeviceInfo>;  // 其他设备状态（通过通信模块同步）
  allDevices: Map<string, DeviceInfo>;    // 所有设备状态（当前设备+其他设备）
}

// 任务执行状态类型
export interface TaskStatus {
  taskId: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  result?: InferenceResult;
  error?: string;
}
```

### 3.2 核心方法设计

| 方法名                 | 功能描述                    | 参数                                      | 返回值                        | <br />      |
| ------------------- | ----------------------- | --------------------------------------- | -------------------------- | :---------- |
| `init()`            | 初始化Client，包括MQTT连接和模型加载 | `config: MQTTConfig, modelName: string` | `Promise<boolean>`         | <br />      |
| `submitTask()`      | 提交推理任务，自动处理调度和执行        | `task: InferenceTask`                   | `Promise<InferenceResult>` | <br />      |
| `getSystemStatus()` | 获取系统状态信息                | 无                                       | `SystemStatus`             | <br />      |
| `destroy()`         | 释放所有资源，关闭MQTT连接         | 无                                       | `Promise<void>`            | <br />      |
| `isConnected()`     | 检查MQTT连接状态              | 无                                       | `Promise<boolean>`         | <br />      |
| `getDeviceInfo()`   | 获取指定设备的状态信息             | `deviceName: string`                    | \`DeviceInfo               | undefined\` |
| `getAllDevices()`   | 获取所有设备的状态信息             | 无                                       | `Map<string, DeviceInfo>`  | <br />      |

## 4. 实现方案

### 4.1 Client类实现

1. 采用单例模式，确保全局只有一个实例
2. 封装各个模块的实例，实现模块间的低耦合
3. 提供统一的初始化方法，简化用户使用
4. 实现任务提交和执行的统一流程
5. 提供系统状态监控的统一接口，包括当前设备和其他设备
6. 实现资源释放的统一接口

### 4.2 关键代码实现

```typescript
class HarmonyInferenceClient {
  private static instance: HarmonyInferenceClient;
  private mqttClient: MQTTClient;
  private scheduler: Scheduler;
  private modelManager: ModelManager;
  private isInitialized: boolean = false;
  
  // 私有构造函数
  private constructor() {
    // 初始化各个模块实例
  }
  
  // 获取单例实例
  public static getInstance(): HarmonyInferenceClient {
    if (!HarmonyInferenceClient.instance) {
      HarmonyInferenceClient.instance = new HarmonyInferenceClient();
    }
    return HarmonyInferenceClient.instance;
  }
  
  // 初始化方法
  public async init(config: MQTTConfig, modelName: string): Promise<boolean> {
    // 初始化MQTT连接
    // 初始化模型
    // 启动设备状态同步
    // 返回初始化结果
  }
  
  // 提交推理任务
  public async submitTask(task: InferenceTask): Promise<InferenceResult> {
    // 处理图像
    // 调度任务执行
    // 执行推理
    // 返回结果
  }
  
  // 获取系统状态
  public getSystemStatus(): SystemStatus {
    // 获取当前设备信息
    // 构造系统状态
    // 返回系统状态
  }
  
  // 获取指定设备信息
  public getDeviceInfo(deviceName: string): DeviceInfo | undefined {
    // 获取所有设备信息
    // 查找指定设备
    // 返回设备信息
  }
  
  // 获取所有设备信息
  public getAllDevices(): Map<string, DeviceInfo> {
    // 获取所有设备信息
    // 返回所有设备信息
  }
  
  // 释放资源
  public async destroy(): Promise<void> {
    // 关闭MQTT连接
    // 释放模型资源
  }
  
  // 检查连接状态
  public async isConnected(): Promise<boolean> {
    // 检查MQTT连接状态
    // 返回连接状态
  }
}
```

## 5. 实现步骤

1. 创建`HarmonyInferenceClient.ets`文件
2. 定义Client接口的类型
3. 实现Client类的核心方法
4. 整合各个模块的功能
5. 编写测试代码验证Client接口的功能
6. 优化和完善Client接口

## 6. 预期效果

1. 提供简洁易用的API，简化框架的使用
2. 实现模块间的低耦合，提高系统的可维护性和可扩展性
3. 支持完整的生命周期管理，包括初始化、任务执行和资源释放
4. 提供统一的系统状态监控接口，包括当前设备和其他设备
5. 支持多终端协同推理，根据设备性能自动调度任务

## 7. 注意事项

1. 严格遵循ArkTS语法规范，特别注意类型校验
2. 确保各模块间的低耦合性，便于后续扩展和维护
3. 提供清晰的错误处理机制
4. 确保线程安全，避免并发问题
5. 优化性能，减少不必要的资源消耗
6. 确保设备状态同步的实时性和准确性

通过以上设计和实现，我们将创建一个统一的Client接口，整合现有模块，提供简洁易用的API来管理基于ArkTS的鸿蒙多终端协同推理框架的完整生命周期流程，同时支持获取当前设备和其他设备的状态信息。
