import { HarmonyInferenceClient, MQTTConfig, InferenceTask, SystemStatus } from '../manager/HarmonyInferenceClient';
import { DeviceInfo } from '../manager/monitor/SystemProfiler';

@Entry
@Component
struct TestClientPage {
  private client = HarmonyInferenceClient.getInstance();
  private isInitialized: boolean = false;
  private connectionStatus: string = 'Disconnected';
  private systemStatus: SystemStatus | null = null;
  private testResult: string = '';
  private logMessages: string[] = [];

  // MQTT配置
  private mqttConfig: MQTTConfig = {
    url: 'tcp://localhost:1883',
    clientId: 'test-client',
    userName: '',
    password: '',
    topic: 'task/request',
    qos: 1
  };

  // 测试任务
  private testTask: InferenceTask = {
    imageUri: '', // 需要替换为实际的图片URI
    modelName: 'model.ms'
  };
  // 在组件外定义计算属性
  get deviceList(): Array<[string, DeviceInfo]> {
    return Array.from(this.systemStatus?.allDevices.entries());
  }

  build() {
    Column() {
      Text('Harmony Inference Client Test').fontSize(24).fontWeight(FontWeight.Bold)
      
      // 连接状态
      Text(`Connection Status: ${this.connectionStatus}`).fontSize(18)
      
      // 初始化按钮
      Button('Initialize Client')
        .onClick(async () => {
          this.log('Initializing client...');
          const result = await this.client.init(this.mqttConfig, 'model.ms');
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
          this.log('System status retrieved');
        })
      
      // 显示系统状态
      if (this.systemStatus) {
        Text('System Status:').fontSize(18).fontWeight(FontWeight.Bold)
        // Text(`Own Device: ${this.systemStatus.ownDevice.deviceName}`)
        // Text(`Other Devices: ${this.systemStatus.otherDevices.size}`)
        // Text(`All Devices: ${this.systemStatus.allDevices.size}`)
        
        // 显示所有设备信息
        Scroll() {
          Column() {
            ForEach(
              this.deviceList, // 确保是 Array<[string, DeviceInfo]> 类型
              // (item: [string, DeviceInfo]) => item, // 使用数组第一个元素（name）作为键
              (item: [string, DeviceInfo]) =>
              Text(`${item}`)
            )
          }
        }.height(200).width('100%').backgroundColor('#f0f0f0')
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
            const result = await this.client.submitTask(this.testTask);
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
    .width('100%')
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
}