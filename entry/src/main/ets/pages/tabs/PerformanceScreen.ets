import router from '@ohos.router';
import { DeviceInfo, systemProfiler } from '../../manager/monitor/SystemProfiler';
import { SelectTitleBar } from "@ohos.arkui.advanced.SelectTitleBar"
import HashMap from '@ohos.util.HashMap';


interface UsageItem {
  icon: Resource
  name: string
  value: string
  unit: string
}

@Component
@Preview
export struct Performance {
  // @Provide 装饰器和 @Consume 装饰器：与后代组件双向同步
  @Consume @Watch('onTabsChange') currentIndex: number
  @Consume @Watch('onTabsChange') isPageShow: boolean
  @State batteryState: number = 0
  @State memorySize: number = 0
  @State cpuUsage: number = 0
  @State statfsFreeSize: number = 0
  @State deviceInfos:HashMap<string,DeviceInfo> = new HashMap();
  // https://docs.openharmony.cn/pages/v4.1/zh-cn/application-dev/quick-start/arkts-state.md {value:"Lenovo TB-J607F"},{value:"OpenHarmony 3.2"}
  @State deviceNames:SelectOption[] = [{value:"Lenovo TB-J607F"},{value:"OpenHarmony 3.2"}];
  @State isRefreshing: boolean = false

  aboutToAppear() {
    this.updateInfo()
    setInterval(() => {
      this.updateInfo()
    }, 10000);
  }

  // 当 Tabs 发生变化 && 页面显示 时（监听父组件的 currentIndex 和 isPageShow）
  onTabsChange() {
    if (this.currentIndex === 2 && this.isPageShow === true) {

    }
  }
  updateInfo(){
    this.deviceInfos = systemProfiler.getDeviceInfos()
    this.deviceNames = []
    for (const key of this.deviceInfos.keys()) {
      let nodeNameOption:SelectOption = {value:key}
      this.deviceNames.push(nodeNameOption)
      console.log("updateHuoADD:" + nodeNameOption.value);
    }
    console.log("updateHuoADD:");
  }
  showInfo(nameChoose:string){
    let info:DeviceInfo = this.deviceInfos.get(nameChoose)
    if (info) {
      this.batteryState = info.batteryLevel
      this.memorySize = info.memoryUsage
      this.cpuUsage = info.cpuUsage
      this.statfsFreeSize = info.storageFree
    }
  }

  // 标题行
  @Builder
  TitleRow(title = '') {
    Row() {
      Text(title)
        .fontSize(18)
        .fontWeight(500)
        .fontColor($r('app.color.font'))
    }
    .width('100%')
    .padding({ top: 20, bottom: 20 })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  // 占用率
  @Builder
  UsageColumn(item: UsageItem) {
    Column({ space: 10 }) {
      Image(item.icon)
        .height(28)
        .aspectRatio(1)
      Text(item.name)
        .fontSize(14)
        .fontColor($r('app.color.font2'))
      Text() {
        Span(item.value)
          .fontSize(26)
          .fontWeight(500)
        Span(' ')
        Span(item.unit)
      }
      .fontSize(14)
      .fontColor($r('app.color.font'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .height(120)
    .borderRadius(5)
    .padding(10)
    .backgroundColor($r('app.color.background'))
  }

  build() {
    Scroll() {
      Column() {
          SelectTitleBar({
            options: this.deviceNames,
            selected: 0,
            onSelected: (index: number): void => {
              this.showInfo(this.deviceNames[index].value.toString());
            },
            hidesBackButton: true
          })
        // test
        // Divider().height(2).color(0xCCCCCC)
        // SelectTitleBar({
        //   options: [
        //     { value: '所有照片' },
        //     { value: '本地（设备）' },
        //     { value: '本地本地本地本地本地（储存卡）' }
        //   ],
        //   selected: 0,
        //   onSelected: (index) => promptAction.showToast({ message: 'page index ' + index }),
        //   hidesBackButton: true
        // })


        // 硬件信息
        Column() {
          // 标题
          // this.TitleRow(this.chooseDeviceName)
          // GridRow 布局 可以看作是 Grid 布局
          GridRow({ columns: 3, gutter: 10 }) {
            GridCol() {
              this.UsageColumn({
                icon: $r('app.media.ic_my_cpu'),
                name: 'CPU占用',
                value: this.cpuUsage.toFixed(0),
                unit: '%'
              })
            }

            GridCol() {
              this.UsageColumn({
                icon: $r('app.media.ic_my_ram'),
                name: '内存占用',
                value: this.memorySize.toFixed(0),
                unit: '%'
              })
            }

            GridCol() {
              this.UsageColumn({
                icon: $r('app.media.ic_my_storage'),
                name: '剩余存储',
                value: this.statfsFreeSize.toFixed(1),
                unit: 'GB'
              })
            }
          }
        }
        .padding({ left: 20, right: 20 })

        // 电池管家
        Column() {
          this.TitleRow('电池管家')
          Column() {
            Row() {
              Text(`电池剩余${this.batteryState}%`)
                .fontSize(14)
                .fontColor($r('app.color.font2'))
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            // 环形图表
            Gauge({ value: this.batteryState, min: 0, max: 100 }) {
              Column() {
                Text(this.batteryState + '%')
                  .fontSize(30)
                  .fontWeight(500)
                  .margin({ top: 60 })
              }
              .width('100%')
              .height('100%')
            }
            .startAngle(270)
            .endAngle(90)
            .description(null)
            .colors(new LinearGradient([
              { color: $r('app.color.danger'), offset: 0 },
              { color: $r('app.color.warning'), offset: 0.2 },
              { color: $r('app.color.success'), offset: 1 },
            ]))
            .strokeWidth(12)
            .width(200)
            .height(200)
            .margin({ top: 20 })
          }
          .width('100%')
          .height(180)
          .borderRadius(6)
          .padding(15)
          .backgroundColor($r('app.color.background'))
          .onClick(() => {
            router.pushUrl({ url: 'pages/Battery/BatteryIndexPage' })
          })
        }
        .padding({ left: 20, right: 20 })
      }
      .constraintSize({ minHeight: '100%' })
    }
    .backgroundImage('/common/images/MyPage_bg.png')
    .backgroundImageSize({ width: '100%' })
    .height('100%')
  }
}