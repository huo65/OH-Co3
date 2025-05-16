
import { MQTTClient, EVENTID} from '../../manager/broker/MQTTClient'
import emitter from '@ohos.events.emitter';
import { MQTTOption } from '../../manager/broker/MQTTConfig';
import { nodeInfoSyn } from '../../manager/broker/monitor/NodeInfoSyn';
interface DataPass {
  data:string;
}
interface RealDataPass {
  topic: string,
  content: string;
}


const MQTTInstance: MQTTClient = MQTTClient.getFirstInstance(MQTTOption)
// 定义一个简单的MQTT客户端组件
@Component
@Preview
export struct  MqttClientScreen {
  brokerUrl: string = 'tcp://broker.emqx.io:1883';
  @State connectionStatus: string = 'Disconnected';
  @State title: string = 'MQTT客户端';
  @State sendMsg: string = ''
  @State receiveMsg: Array<string> = [];

  // @State receiveMsg: string = ''
  // @State sendMsg: string = ''
  //监听收到的消息
  aboutToAppear(): void {
    setInterval(() => {
      this.checkConnectionStatus()
      this.receiveMsg.shift()
    }, 5000);
    MQTTInstance.subscribeTopic(["/device/list","/device/status"])
    emitter.on({
      eventId: EVENTID
    }, (data) => {
      let message:string = JSON.stringify(data)
      let dataMessage:DataPass = JSON.parse(message)
      let realData:string = JSON.stringify(dataMessage.data)
      let realMessage:RealDataPass = JSON.parse(realData)
      if (realMessage.topic == "/device/status") {
        nodeInfoSyn.parseNodeInfoMessage(realMessage.content);
      }
      this.receiveMsg.push(message)
    });
    // emitter.on({
    //   eventId: STATUS
    // }, (data) => {
    //   let message:string = JSON.stringify(data)
    //   nodeInfoSyn.parseNodeInfoMessage(message);
    // });
  }
  public async checkConnectionStatus() {
    try {
      const isConnected = await MQTTInstance.isCon();
      if (isConnected) {
        this.connectionStatus = 'Connected';
      } else {
        this.connectionStatus = 'Disconnected';
      }
    } catch (error) {
      console.error("Failed to check connection status:", error);
      this.connectionStatus = 'Error';
    }
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Text(this.title)
          .focusable(true)
          .fontSize(45)
          .fontWeight(FontWeight.Bold)


        Row() {
          Text('Broker URL：')
          TextInput({ text: $$this.brokerUrl, placeholder: 'Broker 服务器地址' })
            .layoutWeight(1)
        }

        Button() {
          if (this.connectionStatus == "Disconnected") {
            Text("Connect").fontSize(20)
              .fontColor(Color.White)
              .onClick(()=>{
                MQTTInstance.init()
              })

          } else {
            Text("Disconnect").fontSize(20)
              .fontColor(Color.White)
              .onClick(()=>{
                MQTTInstance.destroy()
              })
          }
        }
        .type(ButtonType.Capsule)
        .width(200)
        .height(50)
        .margin(20)
        .backgroundColor('#0D9FFB')
        // .onClick(() => {
        //
        // })


        Text('status: ' + this.connectionStatus)
          .fontColor(
            this.connectionStatus === 'Connected' ? '#00FF00' :
              this.connectionStatus === 'Disconnected' ? '#FF0000' :
                  '#ffee044e'
          );


        Row({ space: 16 }) {
          TextInput({ text: $$this.sendMsg, placeholder: '请填写需要发送的消息' })
            .layoutWeight(1)
          Button('发送消息')
            .onClick(() => {
              if (this.sendMsg) {
                MQTTInstance.pushMessage(this.sendMsg)
                this.sendMsg = ''
              }
            })
        }
        .width('70%')

        // 新增日志展示区域
        Column() {
          Text('接收消息')
            .fontSize(18)
            .margin({ bottom: 10 })
          Text(this.receiveMsg.join('\n'))
            .fontSize(14)
            .textAlign(TextAlign.Start)
            .width('100%')
            .padding(10)
            .backgroundColor('#F5F5F5')
            .maxLines(10)
            .borderRadius(8)
        }
        .width('90%')
        .margin({ top: 20 })

      }
      .padding(20)
      .width('100%')
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
    .scrollBarColor(Color.Gray)
    .scrollBarWidth(10)
    .edgeEffect(EdgeEffect.Spring)
  }

}
