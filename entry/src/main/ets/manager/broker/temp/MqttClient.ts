// @ts-ignore
import { MqttAsync } from '@ohos/native_mqtt'
import {
  Client,
  MqttClientOptions,
  MqttConnectOptions,
  MqttPublishOptions,
  MqttSubscribeOptions,
  MqttResponse,
  MqttMessage,
  QoS
// @ts-ignore
} from '@ohos/native_mqtt/src/main/ets/components/MainPage/MqttOption'
import { ThreadWorkerGlobalScope } from '@ohos.worker'
// import { platformTopics } from '../configs/mqttConfig'

const TAG: string = '@MqttClient@';

class MqttClient {
  private mqClient: Client;
  private baseTopic: string;
  public workerPort: ThreadWorkerGlobalScope;

  static getInstance() {
    if (!globalThis.mqttClient) {
      console.info(TAG, 'new MqttClient');
      globalThis.mqttClient = new MqttClient();
    }
    return globalThis.mqttClient;
  }

  init(productId: string, deviceId: string, workerPort: ThreadWorkerGlobalScope) {
    this.workerPort = workerPort;
    this.baseTopic = `/v1/${ productId }/${ deviceId }/`
    console.info(TAG, 'baseTopic: ' + this.baseTopic);
  }

  async createAndConnect(clientOptions: MqttClientOptions, connectOptions: MqttConnectOptions): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        console.info(TAG, 'mqtt create!');
        // 创建mqtt客户端
        this.mqClient = MqttAsync.createMqtt(clientOptions);
        console.info(TAG, 'mqtt start connecting...');
        // 连接mqtt服务
        while(true) {
          const connectState = await this.connect(connectOptions);
          if (connectState) {
            break;
          }
          console.info(TAG, 'connectState: ' + connectState);
          // await sleep(20 * 1000);
          console.info(TAG, 'reconnection');
        }

        this.messageArrived();
        // 订阅平台下发的所有topic
        // await Promise.all(platformTopics.map(v => this.subscribe(`${ this.baseTopic }${ v }`)));
        resolve();
        this.connectLost();
      } catch (err) {
        console.error(TAG, 'createAndConnect err: ' + JSON.stringify(err));
      }
    });
  }

  // 连接mqtt
  async connect(connectOptions) {
    return new Promise(async (resolve, reject) => {
      try {
        const data: MqttResponse = await this.mqClient.connect(connectOptions);
        console.info(TAG, 'mqtt connect data: ' + JSON.stringify(data));
        if (data.code !== 0) {
          resolve(false);
          return console.error(TAG, 'mqtt connect fail: err: ' + JSON.stringify(data));
        }
        console.info(TAG, 'mqtt connect success!');
        resolve(true);
      } catch (err) {
        console.error(TAG, 'connect err: ' + JSON.stringify(err));
        resolve(false);
      }
    });
  }

  // 订阅消息
  public subscribe(topic: string, qos: QoS = 1): Promise<void> {
    console.info(TAG, 'mqtt subscribe topic: ' + topic);
    const subscribeOption: MqttSubscribeOptions = { topic, qos };
    return new Promise((resolve, reject) => {
      this.mqClient.subscribe(subscribeOption, (err: Error, data: MqttResponse) => {
        console.info(TAG, 'mqtt subscribe data: ' + JSON.stringify(data));
        if (err || data.code !== 0) {
          reject(err || data);
          return console.info(TAG, 'mqtt subscribe error: ' + err);
        }
        resolve();
      });
    });
  }

  // 取消订阅
  public unsubscribe<T>(topic: string, qos: QoS = 1): void {
    const subscribeOption: MqttSubscribeOptions = { topic, qos };

    this.mqClient.unsubscribe(subscribeOption, (err, data: MqttResponse) => {
      if (err) return console.error(TAG, 'mqtt unsubscribe error: ' + err);
      console.info(TAG, 'mqtt unsubscribe data: ' + JSON.stringify(data));
    });
  }

  // 接收消息
  public messageArrived(): void {
    this.mqClient.messageArrived((err: Error, data: MqttMessage) => {
      if (err) return console.error(TAG, 'mqtt messageArrived error: ' + err);
      // 接收消息, 有时候会出现乱码问题, 解决字符串乱码
      const index = data.payload.lastIndexOf('}');
      data.payload = data.payload.substring(0, index + 1);
      console.info(TAG, 'mqtt messageArrived data: ' + JSON.stringify(data));
      this.workerPort.postMessage({
        key: 'MqttMessageArrived',
        params: [data]
      });
    });
  }

  // 发布消息
  async publish<T>(topic: string, payload: string | Record<string, any>,  qos: QoS = 0): Promise<MqttResponse>  {
    if (typeof payload !== 'string') {
      payload = JSON.stringify(payload);
    }
    topic = `${this.baseTopic}${topic}`;
    const publishOption: MqttPublishOptions = { topic, payload, qos, retained: false };
    const connectState = await this.mqClient.isConnected();
    console.info(TAG, 'mqtt connectState: ' + connectState);
    if (!connectState) {
      this.reconnect();
      return
    }

    console.info(TAG, 'publishOption: ' + JSON.stringify(publishOption));
    return this.mqClient.publish(publishOption)
  }

  // 断开连接
  public disconnect(): void {
    this.mqClient.disconnect((err: Error, data: MqttResponse) => {
      if (err) return console.error(TAG, 'mqtt disconnect error: ' + JSON.stringify(err));
      console.info(TAG, 'mqtt disconnect data: ' + JSON.stringify(data));
    });
  }

  // 连接丢失监听
  public connectLost(): void {
    this.mqClient.connectLost((err: Error, data: MqttResponse) => {
      if (err) return console.error(TAG, 'mqtt connectLost error: ' + JSON.stringify(err));
      console.info(TAG, 'mqtt connectLost data: ' + JSON.stringify(data));
      this.reconnect();
    })
  }

  // 重连
  async reconnect(): Promise<boolean> {
    let isReConnected: boolean = await this.mqClient.reconnect();
    console.info(TAG, 'isReConnected state: ' + isReConnected);
    // 注意: 重链订阅平台下发的所有topic
    // await Promise.all(platformTopics.map(v => this.subscribe(`${ this.baseTopic }${ v }`)));
    return isReConnected;
  }

  // 销毁mqtt客户端
  public destroy(): void {
    console.info(TAG, 'mqtt destroy');
    this.mqClient && this.mqClient.destroy();
  }
}

const mqttClient = MqttClient.getInstance();
export default mqttClient;