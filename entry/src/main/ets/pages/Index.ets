import { Performance } from './tabs/Performance'
import {MindSpore} from './tabs/MindScope'
// import {MQTT} from './Tabs/MQTT'
// C:\Users\86132\AppData\Local\Huawei\Sdk\hmscore\emulator
// Emulator –hvd Huawei_Phone
@Entry
@Component
struct Index {
  // @Provide 装饰器和 @Consume装饰器：与后代组件双向同步
  @Provide currentIndex: number = 0
  @Provide isPageShow: boolean = false
  @StorageLink('bottomHeight') bottomHeight: number = 0

  onPageShow() {
    // themeManager.enableFullScreen()
    // 保存页面显示与隐藏状态
    this.isPageShow = true
  }

  onPageHide() {
    // themeManager.disableFullScreen()
    this.isPageShow = false
  }

  @Builder
  TabBuilder(title: string, targetIndex: number, selectedImg: Resource, normalImg: Resource) {
    Column() {
      Image(this.currentIndex === targetIndex ? selectedImg : normalImg)
        .width(20)
        .aspectRatio(1)
      Text(title)
        .fontSize(10)
        .fontColor(this.currentIndex === targetIndex ? $r('app.color.brand') : $r('app.color.font'))
        .margin({ top: 4 })
    }
    .width('100%')
    .height(56)
    .border({ width: { top: 1 }, color: '#eee' })
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = targetIndex;
    })
  }

  build() {
    Tabs({ index: this.currentIndex, barPosition: BarPosition.End }) {
      TabContent() {
        Performance()
      }
      .tabBar(this.TabBuilder('性能', 0, $r('app.media.xn'), $r('app.media.xn2')))

      TabContent() {
        MindSpore()
      }
      .tabBar(this.TabBuilder('推理', 1, $r('app.media.tl'), $r('app.media.tl2')))

      TabContent() {
        // MQTT()
      }
      .tabBar(this.TabBuilder('通信', 2, $r('app.media.app_icon'), $r('app.media.app_icon')))
    }
    .barMode(BarMode.Fixed) // 默认值 Fixed
    .scrollable(false) // 限制滑动
    .padding({ bottom: this.bottomHeight })
  }
}

function MindScope() {
  throw new Error('Function not implemented.');
}
