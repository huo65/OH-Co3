
import { MQTTClient, MQTTOptionsType, EVENTID } from '../../manager/broker/MQTTClient'
import emitter from '@ohos.events.emitter';

const MQTTOption: MQTTOptionsType = {
  url: 'mqtt://192.168.87.159:1883',
  clientId: 'mqtt123456@',
  userName: 'root',
  password: 'admin',
  topic: '/test/123',
  qos: 1
}

const MQTTInstance: MQTTClient = MQTTClient.getInstance(MQTTOption)
// 定义一个简单的MQTT客户端组件
@Component
@Preview
export struct  MqttClientScreen {
  brokerUrl: string = 'tcp://broker.emqx.io:1883';
  connectionStatus: string = 'Disconnected';
  @State title: string = 'MQTT客户端';
  @State sendMsg: string = ''
  @State receiveMsg: Array<string> = [];

  // @State receiveMsg: string = ''
  // @State sendMsg: string = ''
  //监听收到的消息
  aboutToAppear(): void {
    emitter.on({
      eventId: EVENTID
    }, (data) => {
      let message:string = JSON.stringify(data)
      this.receiveMsg.push(message)
    });
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
