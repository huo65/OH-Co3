import { HarmonyInferenceClient, MQTTConfig, InferenceTask, SystemStatus } from '../manager/HarmonyInferenceClient';
import { DeviceInfo } from '../manager/monitor/SystemProfiler';
import { ImageInputData, InferenceInputType, InferenceWorker, InferenceResult } from '../manager/worker/InferenceWorker';
import { SelectTitleBar } from '@kit.ArkUI';
import { ModelManager } from '../TestImageTask/ImageIdModelManager';
import { SchedulerTaskStatus, TaskScheduleStatus, TaskTransitionRecord } from '../manager/scheduler/Scheduler';
import deviceInfo from '@ohos.deviceInfo';
import image from '@ohos.multimedia.image';
import { getDeviceId } from '../manager/config/DeviceIdentifier';

// 日志级别枚举
enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR'
}

// 日志条目接口
interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  details?: string;
}

// 任务监控信息接口
interface TaskMonitorInfo {
  taskId: string;
  status: TaskScheduleStatus;
  progress: number;
  node: string;
  retryCount: number;
  maxRetries: number;
  message: string;
  startTime: number;
  duration: number;
  result?: InferenceResult;
  error?: string;
}

// @Entry
@Component
export struct TestClientPage {
  private client = HarmonyInferenceClient.getInstance();
  @State private isInitialized: boolean = false;
  private ImageModelWorker: InferenceWorker = ModelManager.getInstance();
  
  // MQTT连接状态
  @State connectionStatus: string = 'Disconnected';
  @State mqttConnected: boolean = false;
  
  // MQTT连接配置输入
  @State mqttServerIp: string = '10.238.161.159';
  @State mqttServerPort: string = '1883';
  @State mqttUsername: string = 'root';
  @State mqttPassword: string = 'admin';
  
  // 系统状态
  @State systemStatus: SystemStatus | null = null;
  @State deviceCount: number = 0;
  
  // 任务监控状态
  @State taskMonitorMap: Map<string, TaskMonitorInfo> = new Map();
  @State selectedTaskId: string = '';
  @State taskTransitionHistory: TaskTransitionRecord[] = [];
  @State isTaskRunning: boolean = false;
  @State currentTaskId: string = '';
  
  // 测试结果
  @State testResult: string = '';
  @State testResultSuccess: boolean = false;
  
  // 增强日志系统
  @State logEntries: LogEntry[] = [];
  @State logFilterLevel: LogLevel = LogLevel.DEBUG;
  @State showLogDetails: boolean = true;
  @State autoScrollLog: boolean = true;
  
  // 重试配置
  @State retryConfigVisible: boolean = false;
  @State maxRetries: number = 3;
  @State baseDelayMs: number = 1000;
  
  // 资源
  private imageBuffer: ArrayBuffer | null = null;
  private testTask: InferenceTask | null = null;
  private statusCheckTimer: number | null = null;
  private logScroller: Scroller = new Scroller();
  aboutToAppear() {
    this.initializeResources();

    this.registerTaskStatusListener();
  }

  aboutToDisappear() {
    this.stopStatusCheckTimer();
  }

  // 初始化资源
  private initializeResources(): void {
    const resMgr = getContext(this).resourceManager;
    const resource = $r('app.media.dog');

    try {
      const uint8Array: Uint8Array = resMgr.getMediaContentSync(resource.id);
      this.imageBuffer = uint8Array.buffer as ArrayBuffer;
      this.testTask = {
        taskId: `task-${Date.now()}`,
        modelName: 'image-model.ms',
        type: InferenceInputType.IMAGE,
        data: {
          type: InferenceInputType.IMAGE,
          buffer: this.imageBuffer
        } as ImageInputData,
        params: { "maxResults": 5 }
      };
      this.log(LogLevel.INFO, '资源初始化成功', '图片资源加载完成，测试任务已创建');
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      this.log(LogLevel.ERROR, '资源初始化失败', `图片加载异常: ${errorMsg}`);
    }
  }

  // 启动状态检查定时器
  private startStatusCheckTimer(): void {
    this.statusCheckTimer = setInterval(() => {
      this.updateConnectionStatus();
      this.updateSystemStatus();
    }, 3000);
  }

  // 停止状态检查定时器
  private stopStatusCheckTimer(): void {
    if (this.statusCheckTimer !== null) {
      clearInterval(this.statusCheckTimer);
      this.statusCheckTimer = null;
    }
  }

  // 更新连接状态
  private async updateConnectionStatus(): Promise<void> {
    try {
      const connected = await this.client.isConnected();
      this.mqttConnected = connected;
      this.connectionStatus = connected ? '已连接' : '未连接';
    } catch (error) {
      this.mqttConnected = false;
      this.connectionStatus = '连接异常';
    }
  }

  // 更新系统状态
  private updateSystemStatus(): void {
    try {
      this.systemStatus = this.client.getSystemStatus();
      if (this.systemStatus !== null) {
        this.deviceCount = this.systemStatus.allDevices.length;
      }
    } catch (error) {
      this.log(LogLevel.WARN, '系统状态更新失败');
    }
  }

  // 注册任务状态监听器
  private registerTaskStatusListener(): void {
    this.client.addTaskStatusListener((taskId: string, status: SchedulerTaskStatus) => {
      this.handleTaskStatusUpdate(taskId, status);
    });
  }

  // 处理任务状态更新
  private handleTaskStatusUpdate(taskId: string, status: SchedulerTaskStatus): void {
    const progress = this.calculateTaskProgress(status.status);
    const monitorInfo: TaskMonitorInfo = {
      taskId: taskId,
      status: status.status,
      progress: progress,
      node: status.targetNode || '本地',
      retryCount: status.retryCount,
      maxRetries: status.maxRetries,
      message: this.getStatusDescription(status.status),
      startTime: status.createdAt,
      duration: Date.now() - status.createdAt,
      result: status.result,
      error: status.error
    };

    this.taskMonitorMap.set(taskId, monitorInfo);
    this.taskMonitorMap = new Map(this.taskMonitorMap); // 触发UI更新

    // 记录状态变更日志
    this.log(LogLevel.INFO, `任务状态更新 [${taskId}]`, `状态: ${status.status}, 节点: ${monitorInfo.node}`);

    // 如果当前选中此任务，更新历史记录
    if (this.selectedTaskId === taskId) {
      const history = this.client.getTaskTransitionHistory(taskId);
      if (history !== undefined) {
        this.taskTransitionHistory = history;
      }
    }

    // 更新运行状态
    if (status.status === TaskScheduleStatus.COMPLETED || 
        status.status === TaskScheduleStatus.FAILED) {
      if (this.currentTaskId === taskId) {
        this.isTaskRunning = false;
        if (status.result !== undefined) {
          this.testResult = JSON.stringify(status.result, null, 2);
          this.testResultSuccess = status.result.success;
        }
        if (status.error !== undefined) {
          this.testResult = status.error;
          this.testResultSuccess = false;
        }
      }
    }
  }

  // 计算任务进度
  private calculateTaskProgress(status: TaskScheduleStatus): number {
    switch (status) {
      case TaskScheduleStatus.PENDING:
        return 10;
      case TaskScheduleStatus.SCHEDULING:
        return 25;
      case TaskScheduleStatus.DISPATCHED:
        return 40;
      case TaskScheduleStatus.RUNNING_LOCAL:
      case TaskScheduleStatus.RUNNING_REMOTE:
      case TaskScheduleStatus.RUNNING_RECEIVED:
        return 70;
      case TaskScheduleStatus.RETRYING:
        return 50;
      case TaskScheduleStatus.RECEIVED:
        return 30;
      case TaskScheduleStatus.COMPLETED:
        return 100;
      case TaskScheduleStatus.FAILED:
        return 100;
      case TaskScheduleStatus.CANCELLED:
        return 0;
      default:
        return 0;
    }
  }

  // 获取状态描述
  private getStatusDescription(status: TaskScheduleStatus): string {
    const descriptions: Map<TaskScheduleStatus, string> = new Map([
      [TaskScheduleStatus.PENDING, '等待调度'],
      [TaskScheduleStatus.SCHEDULING, '正在调度决策'],
      [TaskScheduleStatus.DISPATCHED, '已分发到远程节点'],
      [TaskScheduleStatus.RUNNING_LOCAL, '本地执行中'],
      [TaskScheduleStatus.RUNNING_REMOTE, '远程执行中'],
      [TaskScheduleStatus.RUNNING_RECEIVED, '执行接收任务中'],
      [TaskScheduleStatus.RECEIVED, '已接收任务'],
      [TaskScheduleStatus.COMPLETED, '执行完成'],
      [TaskScheduleStatus.FAILED, '执行失败'],
      [TaskScheduleStatus.CANCELLED, '已取消'],
      [TaskScheduleStatus.RETRYING, '等待重试']
    ]);
    const desc = descriptions.get(status);
    return desc !== undefined ? desc : status;
  }

  // 获取状态颜色
  private getStatusColor(status: TaskScheduleStatus): ResourceColor {
    switch (status) {
      case TaskScheduleStatus.COMPLETED:
        return '#52c41a';
      case TaskScheduleStatus.FAILED:
        return '#ff4d4f';
      case TaskScheduleStatus.RUNNING_LOCAL:
      case TaskScheduleStatus.RUNNING_REMOTE:
      case TaskScheduleStatus.RUNNING_RECEIVED:
        return '#1890ff';
      case TaskScheduleStatus.RETRYING:
        return '#faad14';
      case TaskScheduleStatus.PENDING:
      case TaskScheduleStatus.SCHEDULING:
      case TaskScheduleStatus.RECEIVED:
        return '#bfbfbf';
      default:
        return '#8c8c8c';
    }
  }

  // 判断是否可以提交任务
  private canSubmitTask(): boolean {
    return this.isInitialized && !this.isTaskRunning;
  }

  // 获取提交按钮颜色
  private getSubmitButtonColor(): string {
    if (!this.isInitialized) {
      return '#bfbfbf'; // 未初始化 - 灰色
    }
    if (this.isTaskRunning) {
      return '#faad14'; // 运行中 - 黄色
    }
    return '#1890ff'; // 可提交 - 蓝色
  }
  // 构建MQTT配置
  private buildMQTTConfig(): MQTTConfig {
    return {
      url: `mqtt://${this.mqttServerIp}:${this.mqttServerPort}`,
      clientId: getDeviceId(),
      userName: this.mqttUsername,
      password: this.mqttPassword,
      topic: '/test/123',
      qos: 1
    };
  }

  // 生成新任务
  private generateNewTask(): InferenceTask {
    return {
      taskId: `task-${Date.now()}`,
      modelName: 'image-model.ms',
      type: InferenceInputType.IMAGE,
      data: {
        type: InferenceInputType.IMAGE,
        buffer: this.imageBuffer as ArrayBuffer
      } as ImageInputData,
      params: { "maxResults": 5 }
    };
  }

  build() {
    Scroll(this.logScroller) {
      Column({ space: 16 }) {
        // 标题
        this.buildHeader()

        // MQTT连接状态卡片
        this.buildConnectionCard()

        // 系统状态卡片
        this.buildSystemStatusCard()

        // 任务监控面板
        this.buildTaskMonitorPanel()

        // 控制面板
        this.buildControlPanel()

        // 日志面板
        this.buildLogPanel()
      }
      .padding(16)
      .constraintSize({ minHeight: '100%' })
      .width('100%')
    }
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  // 构建头部
  @Builder
  buildHeader() {
    Column({ space: 8 }) {
      Text('Harmony Inference Client')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1890ff')
      
      Text('分布式推理任务调度测试平台')
        .fontSize(14)
        .fontColor('#8c8c8c')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 8 })
  }

  // 构建MQTT连接状态卡片
  @Builder
  buildConnectionCard() {
    Column({ space: 12 }) {
      // 卡片标题
      Row() {
        Text('MQTT连接状态')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        // 状态指示器
        Row({ space: 6 }) {
          Circle()
            .width(10)
            .height(10)
            .fill(this.mqttConnected ? '#52c41a' : '#ff4d4f')
          
          Text(this.connectionStatus)
            .fontSize(14)
            .fontColor(this.mqttConnected ? '#52c41a' : '#ff4d4f')
        }
      }
      .width('100%')

      // MQTT配置输入表单
      Column({ space: 8 }) {
        this.buildInputRow('服务器IP', this.mqttServerIp, (value: string) => {
          this.mqttServerIp = value;
        })
        this.buildInputRow('端口', this.mqttServerPort, (value: string) => {
          this.mqttServerPort = value;
        })
        this.buildInputRow('用户名', this.mqttUsername, (value: string) => {
          this.mqttUsername = value;
        })
        this.buildPasswordRow('密码', this.mqttPassword, (value: string) => {
          this.mqttPassword = value;
        })
      }
      .width('100%')
      .padding({ top: 8 })

      // 连接详情
      if (this.mqttConnected) {
        Column({ space: 4 }) {
          this.buildInfoRow('服务器', `mqtt://${this.mqttServerIp}:${this.mqttServerPort}`)
          this.buildInfoRow('客户端ID', getDeviceId())
        }
        .width('100%')
        .padding({ top: 8 })
      }

      // 连接控制按钮
      Row({ space: 12 }) {
        Button(this.isInitialized ? '重新连接' : '初始化客户端')
          .fontSize(14)
          .height(36)
          .backgroundColor('#1890ff')
          .onClick(async () => {
            this.log(LogLevel.INFO, '正在初始化客户端...');
            try {
              const mqttConfig = this.buildMQTTConfig();
              const result = await this.client.init(
                mqttConfig, 
                'mobilenetv2.ms', 
                this.ImageModelWorker
              );
              this.isInitialized = result;
              this.mqttConnected = result;
              this.connectionStatus = result ? '已连接' : '连接失败';
              this.log(LogLevel.INFO, result ? '客户端初始化成功' : '客户端初始化失败');
              this.startStatusCheckTimer();
            } catch (error) {
              const errorMsg = error instanceof Error ? error.message : String(error);
              this.log(LogLevel.ERROR, '初始化失败', errorMsg);
              this.connectionStatus = '连接失败';
            }
          })

        if (this.isInitialized) {
          Button('断开连接')
            .fontSize(14)
            .height(36)
            .backgroundColor('#ff4d4f')
            .onClick(async () => {
              await this.client.destroy();
              this.isInitialized = false;
              this.mqttConnected = false;
              this.connectionStatus = '已断开';
              this.log(LogLevel.INFO, '客户端已断开连接');
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.1)', offsetY: 2 })
  }

  // 构建系统状态卡片
  @Builder
  buildSystemStatusCard() {
    Column({ space: 12 }) {
      Row() {
        Text('系统状态')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        Text(`${this.deviceCount} 个设备在线`)
          .fontSize(14)
          .fontColor('#1890ff')
      }
      .width('100%')

      // 设备网格列表
      if (this.systemStatus !== null) {
        this.buildDeviceGrid()
      } else {
        Text('暂无设备信息')
          .fontSize(14)
          .fontColor('#bfbfbf')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 16, bottom: 16 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.1)', offsetY: 2 })
  }

  // 获取设备列表（用于网格布局）
  private getDeviceList(): DeviceInfo[] {
    if (this.systemStatus !== null) {
      return Array.from(this.systemStatus.allDevices.values());
    }
    return [];
  }

  // // 构建设备网格布局
  @Builder
  buildDeviceGrid() {
    Column({ space: 12 }) {
      // 使用条件渲染和ForEach实现网格效果
      if (this.systemStatus !== null) {
        // 设备0和1
        if (this.systemStatus.allDevices.length >= 1) {
          Row({ space: 12 }) {
            this.buildCompactDeviceCard(Array.from(this.systemStatus.allDevices.values())[0])
            if (this.systemStatus.allDevices.length >= 2) {
              this.buildCompactDeviceCard(Array.from(this.systemStatus.allDevices.values())[1])
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
        // 设备2和3
        if (this.systemStatus.allDevices.length >= 3) {
          Row({ space: 12 }) {
            this.buildCompactDeviceCard(Array.from(this.systemStatus.allDevices.values())[2])
            if (this.systemStatus.allDevices.length >= 4) {
              this.buildCompactDeviceCard(Array.from(this.systemStatus.allDevices.values())[3])
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
        // 设备4和5
        if (this.systemStatus.allDevices.length >= 5) {
          Row({ space: 12 }) {
            this.buildCompactDeviceCard(Array.from(this.systemStatus.allDevices.values())[4])
            if (this.systemStatus.allDevices.length >= 6) {
              this.buildCompactDeviceCard(Array.from(this.systemStatus.allDevices.values())[5])
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
      }
    }
    .width('100%')
    .margin({ top: 8 })
  }


  // 构建紧凑型设备卡片（用于网格）
  @Builder
  buildCompactDeviceCard(device: DeviceInfo) {
    Column({ space: 6 }) {
      // 设备名称和本机标识
      Row() {
        Text(device.deviceName)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        
        if (this.systemStatus !== null && device.deviceName === this.systemStatus.ownDevice.deviceName) {
          Text('本机')
            .fontSize(10)
            .fontColor('#1890ff')
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .backgroundColor('#e6f7ff')
            .borderRadius(3)
            .margin({ left: 6 })
        }
      }
      .width('100%')

      // 性能指标网格
      Row({ space: 8 }) {
        this.buildCompactMetric('电池', device.batteryLevel, '%')
        this.buildCompactMetric('内存', 100 - device.memoryUsage, '%')
      }
      .width('100%')
      
      Row({ space: 8 }) {
        this.buildCompactMetric('CPU', 100 - device.cpuUsage, '%')
        this.buildCompactMetric('存储', device.storageFree, '%')
      }
      .width('100%')
    }
    .layoutWeight(1)
    .padding(10)
    .backgroundColor('#f6ffed')
    .borderRadius(8)
    .border({ width: 1, color: '#b7eb8f' })
  }

  // 构建紧凑型指标
  @Builder
  buildCompactMetric(label: string, value: number, unit: string) {
    Column({ space: 2 }) {
      Text(`${value.toFixed(0)}${unit}`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(value > 50 ? '#52c41a' : value > 20 ? '#faad14' : '#ff4d4f')
      
      Text(label)
        .fontSize(10)
        .fontColor('#8c8c8c')
    }
    .layoutWeight(1)
    .padding({ top: 4, bottom: 4 })
    .backgroundColor(Color.White)
    .borderRadius(4)
  }

  // 构建设备卡片
  @Builder
  buildDeviceCard(device: DeviceInfo) {
    Column({ space: 8 }) {
      Row() {
        Text(device.deviceName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        if (this.systemStatus !== null && device.deviceName === this.systemStatus.ownDevice.deviceName) {
          Text('本机')
            .fontSize(12)
            .fontColor('#1890ff')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor('#e6f7ff')
            .borderRadius(4)
        }
      }
      .width('100%')

      // 性能指标
      Column({ space: 4 }) {
        this.buildMetricRow('电池', `${device.batteryLevel.toFixed(1)}%`, device.batteryLevel)
        this.buildMetricRow('内存', `${device.memoryUsage.toFixed(1)}%`, 100 - device.memoryUsage)
        this.buildMetricRow('CPU', `${device.cpuUsage.toFixed(1)}%`, 100 - device.cpuUsage)
        this.buildMetricRow('存储', `${device.storageFree.toFixed(1)}%`, device.storageFree)
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#f6ffed')
    .borderRadius(8)
    .border({ width: 1, color: '#b7eb8f' })
  }

  // 构建指标行
  @Builder
  buildMetricRow(label: string, value: string, percent: number) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(12)
        .fontColor('#8c8c8c')
        .width(40)
      
      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(6)
          .backgroundColor('#f0f0f0')
          .borderRadius(3)
        
        Row()
          .width(`${Math.max(0, Math.min(100, percent))}%`)
          .height(6)
          .backgroundColor(percent > 50 ? '#52c41a' : percent > 20 ? '#faad14' : '#ff4d4f')
          .borderRadius(3)
      }
      .width(80)
      .height(6)
      
      Text(value)
        .fontSize(12)
        .fontColor('#595959')
        .width(60)
    }
    .width('100%')
  }

  // 构建任务监控面板
  @Builder
  buildTaskMonitorPanel() {
    Column({ space: 12 }) {
      Row() {
        Text('任务监控')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        Row({ space: 8 }) {
          // 清空任务记录按钮
          if (this.taskMonitorMap.size > 0) {
            Button('清空记录')
              .fontSize(12)
              .height(28)
              .backgroundColor('#ff4d4f')
              .onClick(() => {
                this.taskMonitorMap.clear();
                this.taskMonitorMap = new Map(); // 触发UI更新
                this.selectedTaskId = '';
                this.taskTransitionHistory = [];
                this.log(LogLevel.INFO, '任务监控记录已清空');
              })
          }
          
          if (this.isTaskRunning) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color('#1890ff')
            
            Text('任务执行中...')
              .fontSize(14)
              .fontColor('#1890ff')
              .margin({ left: 8 })
          }
        }
      }
      .width('100%')

      // 任务列表
      if (this.taskMonitorMap.size > 0) {
        Column({ space: 8 }) {
          ForEach(Array.from(this.taskMonitorMap.entries()), 
            (entry: [string, TaskMonitorInfo]) => {
              this.buildTaskCard(entry[1])
            }
          )
        }
        .width('100%')
        .margin({ top: 8 })
      } else {
        Text('暂无任务')
          .fontSize(14)
          .fontColor('#bfbfbf')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 })
      }

      // 任务流转历史
      if (this.selectedTaskId !== '' && this.taskTransitionHistory.length > 0) {
        this.buildTaskHistoryPanel()
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.1)', offsetY: 2 })
  }

  // 构建任务卡片
  @Builder
  buildTaskCard(taskInfo: TaskMonitorInfo) {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 4 }) {
          Text(`任务ID: ${taskInfo.taskId.substring(0, 20)}...`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
          
          Text(taskInfo.message)
            .fontSize(12)
            .fontColor(this.getStatusColor(taskInfo.status))
        }
        .alignItems(HorizontalAlign.Start)
        
        Blank()
        
        // 状态标签
        Text(taskInfo.status)
          .fontSize(12)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.getStatusColor(taskInfo.status))
          .borderRadius(4)
      }
      .width('100%')

      // 进度条
      Row({ space: 8 }) {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(8)
            .backgroundColor('#f0f0f0')
            .borderRadius(4)
          
          Row()
            .width(`${taskInfo.progress}%`)
            .height(8)
            .backgroundColor(this.getStatusColor(taskInfo.status))
            .borderRadius(4)
        }
        .width('70%')
        .height(8)
        
        Text(`${taskInfo.progress}%`)
          .fontSize(12)
          .fontColor('#595959')
          .width(40)
      }
      .width('100%')

      // 任务详情
      Row({ space: 16 }) {
        this.buildInfoTag('节点', taskInfo.node)
        this.buildInfoTag('重试', `${taskInfo.retryCount}/${taskInfo.maxRetries}`)
        this.buildInfoTag('耗时', `${(taskInfo.duration / 1000).toFixed(1)}s`)
      }
      .width('100%')
      .margin({ top: 4 })

      // 操作按钮
      Row({ space: 8 }) {
        Button('查看历史')
          .fontSize(12)
          .height(28)
          .onClick(() => {
            this.selectedTaskId = taskInfo.taskId;
            const history = this.client.getTaskTransitionHistory(taskInfo.taskId);
            if (history !== undefined) {
              this.taskTransitionHistory = history;
            }
          })

        if (taskInfo.status === TaskScheduleStatus.FAILED && taskInfo.retryCount < taskInfo.maxRetries) {
          Button('手动重试')
            .fontSize(12)
            .height(28)
            .backgroundColor('#faad14')
            .onClick(() => {
              const success = this.client.retryTask(taskInfo.taskId);
              this.log(LogLevel.INFO, `手动重试任务 ${taskInfo.taskId}`, success ? '触发成功' : '触发失败');
            })
        }

        if (taskInfo.result !== undefined) {
          Button('查看结果')
            .fontSize(12)
            .height(28)
            .backgroundColor('#52c41a')
            .onClick(() => {
              this.testResult = JSON.stringify(taskInfo.result, null, 2);
              this.testResultSuccess = taskInfo.result !== undefined ? taskInfo.result.success : false;
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#fafafa')
    .borderRadius(8)
    .border({ width: 1, color: '#e8e8e8' })
    .onClick(() => {
      this.selectedTaskId = taskInfo.taskId;
    })
  }

  // 构建信息标签
  @Builder
  buildInfoTag(label: string, value: string) {
    Row({ space: 4 }) {
      Text(label + ':')
        .fontSize(11)
        .fontColor('#8c8c8c')
      
      Text(value)
        .fontSize(11)
        .fontColor('#595959')
    }
  }

  // 构建任务历史面板
  @Builder
  buildTaskHistoryPanel() {
    Column({ space: 8 }) {
      Row() {
        Text(`任务流转历史 (${this.selectedTaskId.substring(0, 16)}...)`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        Button('关闭')
          .fontSize(12)
          .height(28)
          .backgroundColor('#bfbfbf')
          .onClick(() => {
            this.selectedTaskId = '';
            this.taskTransitionHistory = [];
          })
      }
      .width('100%')

      Column({ space: 4 }) {
        ForEach(this.taskTransitionHistory, (record: TaskTransitionRecord, index: number) => {
          Row({ space: 8 }) {
            Text(`${index + 1}.`)
              .fontSize(11)
              .fontColor('#8c8c8c')
              .width(24)
            
            Text(new Date(record.timestamp).toLocaleTimeString())
              .fontSize(11)
              .fontColor('#8c8c8c')
              .width(70)
            
            Text(record.status)
              .fontSize(11)
              .fontColor(this.getStatusColor(record.status))
              .width(100)
            
            Text(record.node)
              .fontSize(11)
              .fontColor('#595959')
              .width(60)
            
            if (record.message !== undefined) {
              Text(record.message)
                .fontSize(11)
                .fontColor('#8c8c8c')
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
        })
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#f6ffed')
      .borderRadius(8)
    }
    .width('100%')
    .margin({ top: 12 })
    .padding(12)
    .backgroundColor('#f0f5ff')
    .borderRadius(8)
    .border({ width: 1, color: '#adc6ff' })
  }

  // 构建控制面板
  @Builder
  buildControlPanel() {
    Column({ space: 12 }) {
      Row() {
        Text('控制面板')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')

      // 任务提交按钮
      Button('提交测试任务')
        .width('100%')
        .height(44)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.getSubmitButtonColor())
        .enabled(this.canSubmitTask())
        .onClick(async () => {
          if (this.imageBuffer === null) {
            this.log(LogLevel.ERROR, '图片资源未加载');
            return;
          }

          const task = this.generateNewTask();
          this.currentTaskId = task.taskId;
          this.isTaskRunning = true;
          this.testResult = '';
          
          this.log(LogLevel.INFO, `开始提交任务 ${task.taskId}`);

          try {
            const result = await this.client.submitTask(task);
            this.testResult = JSON.stringify(result, null, 2);
            this.testResultSuccess = result.success;
            this.log(LogLevel.INFO, `任务 ${task.taskId} 完成`, result.success ? '执行成功' : '执行失败');
          } catch (error) {
            const errorMsg = error instanceof Error ? error.message : String(error);
            this.testResult = errorMsg;
            this.testResultSuccess = false;
            this.log(LogLevel.ERROR, `任务 ${task.taskId} 异常`, errorMsg);
          } finally {
            this.isTaskRunning = false;
          }
        })

      // 重试配置
      Row() {
        Text('重试配置')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        Toggle({ type: ToggleType.Switch, isOn: this.retryConfigVisible })
          .selectedColor('#1890ff')
          .onChange((isOn: boolean) => {
            this.retryConfigVisible = isOn;
          })
      }
      .width('100%')
      .margin({ top: 8 })

      if (this.retryConfigVisible) {
        Column({ space: 12 }) {
          this.buildConfigSlider('最大重试次数', this.maxRetries, 1, 5, (value: number) => {
            this.maxRetries = value;
            this.client.setRetryConfig({ maxRetries: value });
          })
          
          this.buildConfigSlider('基础延迟(ms)', this.baseDelayMs, 500, 5000, (value: number) => {
            this.baseDelayMs = value;
            this.client.setRetryConfig({ baseDelayMs: value });
          })
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#f5f5f5')
        .borderRadius(8)
      }

      // 结果显示
      if (this.testResult !== '') {
        Column({ space: 8 }) {
          Row() {
            Text('执行结果')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            
            Blank()
            
            Text(this.testResultSuccess ? '成功' : '失败')
              .fontSize(12)
              .fontColor(this.testResultSuccess ? '#52c41a' : '#ff4d4f')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .backgroundColor(this.testResultSuccess ? '#f6ffed' : '#fff1f0')
              .borderRadius(4)
          }
          .width('100%')

          Text(this.testResult)
            .width('100%')
            .padding(12)
            .backgroundColor('#f6ffed')
            .borderRadius(8)
            .fontSize(12)
            .fontColor('#595959')
            .maxLines(10)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Color.White)
        .borderRadius(8)
        .border({ width: 1, color: this.testResultSuccess ? '#b7eb8f' : '#ffa39e' })
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.1)', offsetY: 2 })
  }

  // 构建配置滑块
  @Builder
  buildConfigSlider(label: string, value: number, min: number, max: number, onChange: (value: number) => void) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(13)
        .width(100)
      
      Slider({ value: value, min: min, max: max, step: label.includes('延迟') ? 500 : 1 })
        .layoutWeight(1)
        .selectedColor('#1890ff')
        .onChange((val: number) => {
          onChange(val);
        })
      
      Text(`${value}`)
        .fontSize(13)
        .width(50)
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  // 构建日志面板
  @Builder
  buildLogPanel() {
    Column({ space: 12 }) {
      // 日志标题栏
      Row() {
        Text('系统日志')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        // 日志级别筛选
        Row({ space: 8 }) {
          ForEach([LogLevel.DEBUG, LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR], (level: LogLevel) => {
            Text(level)
              .fontSize(11)
              .fontColor(this.logFilterLevel === level ? Color.White : '#595959')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(this.logFilterLevel === level ? '#1890ff' : '#f0f0f0')
              .borderRadius(4)
              .onClick(() => {
                this.logFilterLevel = level;
              })
          })
        }
      }
      .width('100%')

      // 日志控制栏
      Row({ space: 12 }) {
        Row({ space: 4 }) {
          Checkbox()
            .select(this.showLogDetails)
            .selectedColor('#1890ff')
            .onChange((value: boolean) => {
              this.showLogDetails = value;
            })
          
          Text('显示详情')
            .fontSize(12)
            .fontColor('#595959')
        }

        Row({ space: 4 }) {
          Checkbox()
            .select(this.autoScrollLog)
            .selectedColor('#1890ff')
            .onChange((value: boolean) => {
              this.autoScrollLog = value;
            })
          
          Text('自动滚动')
            .fontSize(12)
            .fontColor('#595959')
        }

        Blank()

        Button('清空')
          .fontSize(12)
          .height(28)
          .backgroundColor('#ff4d4f')
          .onClick(() => {
            this.logEntries = [];
          })
      }
      .width('100%')

      // 日志列表
      List({ scroller: this.logScroller }) {
        ForEach(this.getFilteredLogs(), (entry: LogEntry, index: number) => {
          ListItem() {
            Column({ space: 4 }) {
              Row({ space: 8 }) {
                Text(entry.timestamp)
                  .fontSize(11)
                  .fontColor('#8c8c8c')
                  .width(70)
                
                Text(entry.level)
                  .fontSize(11)
                  .fontColor(this.getLogLevelColor(entry.level))
                  .fontWeight(FontWeight.Medium)
                  .width(50)
                
                Text(entry.message)
                  .fontSize(12)
                  .fontColor('#262626')
                  .layoutWeight(1)
              }
              .width('100%')

              if (this.showLogDetails && entry.details !== undefined && entry.details !== '') {
                Text(entry.details)
                  .fontSize(11)
                  .fontColor('#8c8c8c')
                  .width('100%')
                  .padding({ left: 78 })
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })
            .backgroundColor(index % 2 === 0 ? Color.White : '#fafafa')
          }
        })
      }
      .width('100%')
      .height(250)
      .backgroundColor(Color.White)
      .borderRadius(8)
      .border({ width: 1, color: '#e8e8e8' })
      .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.1)', offsetY: 2 })
  }

  // 构建信息行
  @Builder
  buildInfoRow(label: string, value: string) {
    Row({ space: 8 }) {
      Text(label + ':')
        .fontSize(12)
        .fontColor('#8c8c8c')
        .width(70)
      
      Text(value)
        .fontSize(12)
        .fontColor('#595959')
        .layoutWeight(1)
    }
    .width('100%')
  }

  // 构建输入行
  @Builder
  buildInputRow(label: string, value: string, onChange: (value: string) => void) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor('#595959')
        .width(70)
      
      TextInput({ placeholder: `请输入${label}`, text: value })
        .layoutWeight(1)
        .height(36)
        .fontSize(13)
        .backgroundColor('#f5f5f5')
        .onChange((text: string) => {
          onChange(text);
        })
    }
    .width('100%')
  }

  // 构建密码输入行
  @Builder
  buildPasswordRow(label: string, value: string, onChange: (value: string) => void) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor('#595959')
        .width(70)
      
      TextInput({ placeholder: `请输入${label}`, text: value })
        .layoutWeight(1)
        .height(36)
        .fontSize(13)
        .backgroundColor('#f5f5f5')
        .type(InputType.Password)
        .onChange((text: string) => {
          onChange(text);
        })
    }
    .width('100%')
  }

  // 添加日志
  private log(level: LogLevel, message: string, details?: string): void {
    const entry: LogEntry = {
      timestamp: new Date().toLocaleTimeString(),
      level: level,
      message: message,
      details: details
    };
    
    this.logEntries.push(entry);
    
    // 限制日志数量
    if (this.logEntries.length > 100) {
      this.logEntries.shift();
    }

    // 自动滚动
    if (this.autoScrollLog) {
      setTimeout(() => {
        this.logScroller.scrollEdge(Edge.Bottom);
      }, 100);
    }
  }

  // 获取过滤后的日志
  private getFilteredLogs(): LogEntry[] {
    const levelPriority: Map<LogLevel, number> = new Map([
      [LogLevel.DEBUG, 0],
      [LogLevel.INFO, 1],
      [LogLevel.WARN, 2],
      [LogLevel.ERROR, 3]
    ]);
    
    const filterPriority = levelPriority.get(this.logFilterLevel) || 0;
    
    return this.logEntries.filter((entry: LogEntry) => {
      const entryPriority = levelPriority.get(entry.level) || 0;
      return entryPriority >= filterPriority;
    });
  }

  // 获取日志级别颜色
  private getLogLevelColor(level: LogLevel): ResourceColor {
    switch (level) {
      case LogLevel.DEBUG:
        return '#8c8c8c';
      case LogLevel.INFO:
        return '#1890ff';
      case LogLevel.WARN:
        return '#faad14';
      case LogLevel.ERROR:
        return '#ff4d4f';
      default:
        return '#595959';
    }
  }

  private async getBigFile(): Promise<Uint8Array> {
    const resMgr = getContext().getApplicationContext().resourceManager;
    try {
      const rawFileContent: Uint8Array = await resMgr.getRawFileContent("mobilenetv2.ms");
      return rawFileContent;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      this.log(LogLevel.ERROR, '获取模型文件失败', errorMsg);
    }
    return new Uint8Array(0);
  }
}