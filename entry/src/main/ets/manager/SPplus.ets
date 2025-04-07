// import hilog from '@ohos.hilog';
// import testStatisticsApi from 'libentry.so';
//
// //https://docs.openharmony.cn/pages/v4.0/zh-cn/application-dev/reference/apis/js-apis-battery-info.md/
// import batteryInfo from '@ohos.batteryInfo';
//
// //https://docs.openharmony.cn/pages/v4.0/zh-cn/application-dev/reference/apis/js-apis-device-info.md/
// import deviceinfo from '@ohos.deviceInfo';
//
// import vibrator from '@ohos.vibrator';
//
// import window from '@ohos.window';
// import common from '@ohos.app.ability.common';
//
// // @Entry
// @Component
// struct Index {
//   @State cpuCount: Number = 0;
//   @State totalMem: String = '';
//   @State freeMem: String = '';
//   @State cachedMem: String = '';
//   @State availableMem: String = '';
//   @State batterySOC: Number = 0;
//   @State voltage: Number = 0;
//   @State technology: String = '';
//   @State batteryTemperature: Number = 0;
//   @State chargingStatus: batteryInfo.BatteryChargeState = 0;
//   @State chargingStatus_info: String = '';
//   @State healthStatus: batteryInfo.BatteryHealthState	= 0;
//   @State healthStatus_info: String = '';
//   @State pluggedType: batteryInfo.BatteryPluggedType= 0;
//   @State pluggedType_info: String = '';
//   @State batteryCapacityLevel: batteryInfo.BatteryCapacityLevel= 0;
//   @State batteryCapacityLevel_info: String = '';
//   @State time: String = '';
//   @State soctemp: String = '';
//   @State CPU_CORE_big7_temp: String = '';
//   @State CPU_CORE_mid6_temp: String = '';
//   @State CPU_CORE_mid5_temp: String = '';
//   @State CPU_CORE_mid4_temp: String = '';
//   @State CPU_CORE_lit3_temp: String = '';
//   @State CPU_CORE_lit2_temp: String = '';
//   @State CPU_CORE_lit1_temp: String = '';
//   @State CPU_CORE_lit0_temp: String = '';
//   @State GPU_temp: String = '';
//   @State Board_temp: String = '';
//   @State Swaps: String = '';
//   @State RTC_Date_temp: String = '';
//   @State Kernel_version: String = '';
//   @State abiListInfo: String = '';
//   @State osFullNameInfo: String = '';
//   @State sdkApiVersionInfo: Number = 0;
//   @State linuxVersion: String = '';
//   @State clangVersion: String = '';
//   @State construction_time: String = '';
//   @State RTC_Time_temp: String = '';
//   @State Cpu_stat_cpu: String = '';
//   @State processes: String = '';
//   @State ctxt: String = '';
//   @State cpuinfo_hardware: String = '';
//
//
//   //沉浸式界面开发:https://gitee.com/openharmony/docs/blob/master/zh-cn/third-party-cases/immersion-mode.md#%E5%8F%82%E8%80%83
//   context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext
//   async setSystemBar() {
//
//     let windowClass = await window.getLastWindow(this.context)
//     //设置导航栏，状态栏不可见
//     /*
//      * let names: Array<'status' | 'navigation'> = ['navigation'];//设置顶部状态栏不可见
//      * let names: Array<'status' | 'navigation'> = ['status'];//设置底部导航栏不可见
//      * let names: Array<'status' | 'navigation'> = [];//设置底部导航栏、顶部状态栏都不可见
//     */
//     let names: Array<'status' | 'navigation'> = ["navigation"];
//     await windowClass.setWindowSystemBarEnable(names)
//   }
//
//
//   aboutToAppear() {
//
//     this.setSystemBar()
//     setInterval(() => {
//       testStatisticsApi.getMemoryInfo();
//       testStatisticsApi.getCpuInfo();
//       //getctxt
//       this.ctxt = testStatisticsApi.getctxt();
//       console.log("========Cpu_stat_cpu is ",this.ctxt)
//
//       //getprocesses
//       this.processes = testStatisticsApi.getprocesses();
//       console.log("========Cpu_stat_cpu is ",this.processes)
//
//       //getCpu_stat_cpu
//       this.Cpu_stat_cpu = testStatisticsApi.getCpu_stat_cpu();
//       console.log("========Cpu_stat_cpu is ",this.Cpu_stat_cpu)
//
//       this.freeMem = testStatisticsApi.getFreeMem();
//       console.log("========freeMem is ",this.freeMem)
//
//       this.cachedMem = testStatisticsApi.getCachedMem();
//       console.log("========cachedMem is ",this.cachedMem)
//
//       this.cpuCount = testStatisticsApi.getCpuCount();
//       console.log("========cpuCount is ",this.cpuCount)
//
//       this.totalMem = testStatisticsApi.getMemTotal();
//       console.log("========cpuCoreCount is ",this.totalMem)
//
//       this.availableMem = testStatisticsApi.getAvailableMem();
//       console.log("========availableMem is ",this.availableMem)
//       // TODO
//       this.time = testStatisticsApi.getUptime();
//       console.log("======== getUptime is",this.time.split(" ")[0])
//
//
//     }, 1000);
//
//   }
//
//   onPageShow(){
//   }
//
//
//   build() {
//     Column() {
//
//       Flex({ direction: FlexDirection.Column, alignItems: ItemAlign.Start, justifyContent: FlexAlign.SpaceBetween }) {
//
//         Text("CPU核心数:"+ this.cpuCount + "\t\t\t SOC型号:" + this.cpuinfo_hardware )
//           .textAlign(TextAlign.Start)
//           .fontSize(14)
//           .border({ width: 1 })
//           .padding(10)
//           .width('100%')
//
//
//         Text("手机系统运行时间:"+
//         Math.floor(Number(this.time.split(" ")[0]) / 3600) + ":" +
//         Math.floor((Number(this.time.split(" ")[0]) % 3600) / 60) + ":" +
//         Math.floor(Number(this.time.split(" ")[0]) % 60)
//         )
//           .textAlign(TextAlign.Start)
//           .fontSize(14)
//           .border({ width: 1 })
//           .padding(10)
//           .width('100%')
//
//         Text("RAM总内存:"+this.totalMem +
//           "\nRAM可用内存:"+this.availableMem +
//           "\nRAM空闲内存:"+this.freeMem +
//           "\n缓存使用内存:"+this.cachedMem +
//           "\nSwaps交换分区:"+this.Swaps + "kB" +
//           "\n系统启动以来创建的进程数量:" + this.processes.split(" ")[1] +
//           "\n上下文切换的总数:" +this.ctxt.split(" ")[1]
//         )
//           .textAlign(TextAlign.Start)
//           .fontSize(14)
//           .border({ width: 1 })
//           .padding(10)
//           .width('100%')
//
//         Text(
//           "\t\t\t  CPU利用率:" + (Number(this.Cpu_stat_cpu.split(" ")[0])).toFixed(3)
//         )
//           .textAlign(TextAlign.Start)
//           .fontSize(14)
//           .border({ width: 1 })
//           .padding(10)
//           .width('100%')
//       }.width('100%').height('100%').padding({ left: 35, right: 35, top: 35 ,bottom:35})
//
//     }
//     .width('100%')
//     .height('100%')
//     .backgroundColor(0xDCDCDC)
//     .padding({ top: 5 })
//   }
// }