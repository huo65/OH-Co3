import { HarmonyInferenceClient, MQTTConfig, InferenceTask, SystemStatus } from '../manager/HarmonyInferenceClient';
import { DeviceInfo } from '../manager/monitor/SystemProfiler';
import { ImageInputData, InferenceInputType, InferenceWorker } from '../manager/worker/InferenceWorker';
import { SelectTitleBar } from '@kit.ArkUI';
import { ModelManager } from '../TestImageTask/ImageIdModelManager';
import deviceInfo from '@ohos.deviceInfo';
import image from '@ohos.multimedia.image';

// @Entry
@Component
export struct TestClientPage {
  private client = HarmonyInferenceClient.getInstance();
  private isInitialized: boolean = false;
  private ImageModelWorker:InferenceWorker = ModelManager.getInstance()
  @State connectionStatus: string = 'Disconnected';
  @State testResult: string = '';
  @State logMessages: string[] = [];
  @State systemStatus: SystemStatus | null = null;
  private imageBuffer:ArrayBuffer | null = null;
  private testTask: InferenceTask | null = null; // 延迟初始化
  aboutToAppear() {
    // 获取资源管理器
    const resMgr = getContext(this).resourceManager;

    // 获取图片资源对象
    const resource = $r('app.media.dog'); // 注意：省略文件扩展名

    try {
      // 同步读取资源内容为 Uint8Array
      const uint8Array: Uint8Array = resMgr.getMediaContentSync(resource.id);

      // 转换为 ArrayBuffer
      this.imageBuffer = uint8Array.buffer as ArrayBuffer;
      // 资源加载完成后初始化任务
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

      console.log('Task initialized successfully');
    } catch (error) {
      console.error(`Failed to load image: ${error.message}`);
    }
  }
  // TODO 改进测试页面
  // MQTT配置
  private mqttConfig: MQTTConfig = {
    url: 'mqtt://10.238.161.159:1883',
    //测试防止重复 clientId: deviceInfo.marketName + "_" + Math.floor(Math.random() * 10000),
    clientId: deviceInfo.marketName,
    userName: 'root',
    password: 'admin',
    topic: '/test/123',
    qos: 1
  };


  // // 测试任务
  // private testTask: InferenceTask = {
  //   taskId: `task-${Date.now()}`,
  //   modelName: 'image-model.ms',
  //   type: InferenceInputType.IMAGE,
  //   data: {
  //     // 默认使用entry/src/main/resources/base/media/dog.jpg
  //     // imageData: ""
  //     type: InferenceInputType.IMAGE,
  //     buffer: this.imageBuffer as ArrayBuffer,
  //   } as ImageInputData,
  //   params: {
  //     "maxResults": 5
  //   }
  // };

  build() {
    Scroll() {
    Column() {
      Text('Harmony Inference Client Test').fontSize(24).fontWeight(FontWeight.Bold)
      
      // 连接状态
      Text(`Connection Status: ${this.connectionStatus}`).fontSize(18)

      // 初始化按钮
      Button('Initialize Client')
        .onClick(async () => {
          this.log('Initializing client...');
          const result = await this.client.init(this.mqttConfig, 'mobilenetv2.ms', this.ImageModelWorker);
          this.isInitialized = result;
          this.connectionStatus = result ? 'Connected' : 'Failed';
          this.log(`Initialization ${result ? 'success' : 'failed'}`);
        })
      
      // 检查连接状态按钮
      Button('Check Connection')
        .onClick(async () => {
          const connected = await this.client.isConnected();
          this.connectionStatus = connected ? 'Connected' : 'Disconnected';
          this.log(`Connection status: ${connected ? 'Connected' : 'Disconnected'}`);
        })
      
      // 获取系统状态按钮
      Button('Get System Status')
        .onClick(() => {
          this.systemStatus = this.client.getSystemStatus();
          this.log('System status update');
        })
      
      // 显示系统状态
      if (this.systemStatus) {
        Text('System Status:').fontSize(18).fontWeight(FontWeight.Bold)
        // 所有设备展示
        Text('All Devices:').margin({ top: 8 }).fontColor(0x333333)
        ForEach(Array.from(this.systemStatus.allDevices.values()), (device: DeviceInfo) => {
          Column() {
            Text(`设备名称：${device.deviceName}`).fontSize(14)
            Text(`电池：${device.batteryLevel.toFixed(2)}%`).fontColor(0x666666)
            Text(`内存占用：${device.memoryUsage.toFixed(2)}%`).fontColor(0x666666)
            Text(`CPU占用：${device.cpuUsage.toFixed(2)}%`).fontColor(0x666666)
            Text(`存储剩余：${device.storageFree.toFixed(2)}%`).fontColor(0x666666)
          }.padding({ left: 16 })
        })
      }
      
      // 提交任务按钮
      Button('Submit Test Task')
        .onClick(async () => {
          if (!this.isInitialized) {
            this.log('Client not initialized');
            return;
          }
          
          try {
            this.log('Submitting test task...');
            const result = await this.client.submitTask(this.testTask as InferenceTask);
            this.testResult = JSON.stringify(result);
            this.log('Task completed successfully');
          } catch (error) {
            this.log(`Task failed: ${error}`);
          }
        })
      
      // 显示测试结果
      if (this.testResult) {
        Text('Test Result:').fontSize(18).fontWeight(FontWeight.Bold)
        Text(this.testResult).width('100%').backgroundColor('#f0f0f0').padding(10)
      }
      
      // 销毁客户端按钮
      Button('Destroy Client')
        .onClick(async () => {
          await this.client.destroy();
          this.isInitialized = false;
          this.connectionStatus = 'Disconnected';
          this.log('Client destroyed');
        })
      
      // 日志显示
      Text('Log:').fontSize(18).fontWeight(FontWeight.Bold)
      Scroll() {
        Column() {
          ForEach(this.logMessages, (msg:string) => {
            Text(msg).fontSize(14).textAlign(TextAlign.Start)
          })
        }
      }.height(200).width('100%').backgroundColor('#f0f0f0')
    }
    .padding(20)
    .constraintSize({ minHeight: '100%' })
    }
    .height('100%')
  }

  private log(message: string): void {
    const timestamp = new Date().toLocaleTimeString();
    this.logMessages.push(`[${timestamp}] ${message}`);
    // 限制日志数量
    if (this.logMessages.length > 20) {
      this.logMessages.shift();
    }
  }
  private async getBigFile(): Promise<Uint8Array>{
    const resMgr = getContext().getApplicationContext().resourceManager;
    try {
      const rawFileContent: Uint8Array = await resMgr.getRawFileContent("mobilenetv2.ms");
      return rawFileContent;
    } catch (error) {
      console.info(`[TestPage] 测试页面 error=${error}`);
    }
    return new Uint8Array;
  }
}