import { MQTTClient, MQTTOptionsType, EVENTID } from '../../manager/broker/MQTTClient'
import emitter from '@ohos.events.emitter';

const MQTTOption: MQTTOptionsType = {
  url: 'mqtt://broker.emqx.io:1883',
  clientId: 'mqtt123456@',
  userName: 'root',
  password: 'admin',
  topic: 'topic1',
  qos: 1
}

const MQTTInstance: MQTTClient = MQTTClient.getInstance(MQTTOption)

@Component
export struct MQTT {
  @State receiveMsg: string = ''
  @State sendMsg: string = ''

  onPageShow(): void {
    emitter.on({
      eventId: EVENTID
    }, (data) => {
      this.receiveMsg = JSON.stringify(data)
    });
  }

  build() {
    Column({ space: 24 }) {

      Text('MQTT客户端')
        .fontSize(32)
        .fontWeight(500)
        .margin({ bottom: 20 })


      Row() {
        Text('接收到的消息：')
        TextInput({ text: $$this.receiveMsg, placeholder: '接收到的消息' })
          .layoutWeight(1)
      }

      Row({ space: 16 }) {
        Button('发送消息')
          .onClick(() => {
            if (this.sendMsg) {
              MQTTInstance.pushMessage(this.sendMsg)
              this.sendMsg = ''
            }
          })
        TextInput({ text: $$this.sendMsg, placeholder: '请填写需要发送的消息' })
          .layoutWeight(1)

      }
      .width('100%')

      Button('销毁客户端')
        .width('100%')
        .onClick(() => {
          MQTTInstance.destroy()
        })

    }
    .padding(20)
    .width('100%')
  }
}
