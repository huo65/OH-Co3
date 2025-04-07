import router from '@ohos.router';
import { NodeInfo, systemProfiler } from '../../manager/SystemProfiler';
import List from '@ohos.util.List';
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
  @State deviceName: string = ''
  @State batteryState: number = 0
  @State memorySize: number = 0
  @State cpuUsage: number = 0
  @State statfsFreeSize: number = 0
  @State deviceInfos:HashMap<string,NodeInfo> = new HashMap();
  @State deviceNames:Array<SelectOption> = new Array();
  nameList:List<SelectOption> = new List();

  aboutToAppear() {
    this.updateInfo()
    setInterval(() => {
      this.updateInfo()
    }, 5000);
  }

  // 当 Tabs 发生变化 && 页面显示 时（监听父组件的 currentIndex 和 isPageShow）
  onTabsChange() {
    if (this.currentIndex === 2 && this.isPageShow === true) {
      // this.getDebugInfo()
      // this.getStatfsInfo()
      // this.getBatteryInfo()
    }
  }
  updateInfo(){
    this.deviceInfos = systemProfiler.getInfo()
    this.nameList.clear()
    for (const key of this.deviceInfos.keys()) {
      let nodeName:SelectOption = {value:key}
      this.nameList.add(nodeName)
    }
    this.deviceNames =  this.nameList.convertToArray()
  }
  showInfo(index:number){
    this.deviceName =  this.deviceNames[index].value.toString()
    let info:NodeInfo = this.deviceInfos.get(this.deviceName)
    this.batteryState = info.batteryState
    this.memorySize = info.memorySize
    this.cpuUsage = info.cpuUsage
    this.statfsFreeSize = info.statfsFreeSize
  }

  // 标题行
  @Builder
  TitleRow(title = '', target = '') {
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
          options:this.deviceNames,
          selected: 0,
          // onSelected: (index) => promptAction.showToast({ message: 'page index ' + index }),
          onSelected: (index): number => setInterval(() => {
            this.showInfo(index)
          }, 5000),
          hidesBackButton: true
        })

        // 硬件信息
        Column() {
          // 标题
          this.TitleRow(this.deviceName, 'pages/Hardware/HardwareIndexPage')
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
          this.TitleRow('电池管家', 'pages/Battery/BatteryIndexPage')
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