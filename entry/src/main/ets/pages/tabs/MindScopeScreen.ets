import { BusinessError } from '@ohos.base';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { ModelManager } from '../../manager/worker/ModelManager';
import { Scheduler} from '../../manager/scheduler/Scheduler';
import systemDateTime from '@ohos.systemDateTime';
import { taskDispatch, TaskInfo } from '../../manager/broker/task/TaskDispatch';
import emitter from '@ohos.events.emitter';
import { nodeInfoSyn } from '../../manager/broker/monitor/NodeInfoSyn';
import { RESULT } from '../../manager/broker/MQTTClient';
import { DataPass, RealDataPass } from './BrokerScreen';

interface PredictResult {
  maxArray: number[];
  maxIndexArray: number[];
}
const SchedulerInstance: Scheduler = Scheduler.getInstance();
// TODO 参照Android改进
@Component
export struct MindSpore {
  // @Provide 装饰器和 @Consume 装饰器：与后代组件双向同步
  @Consume @Watch('onTabsChange') currentIndex: number
  @Consume @Watch('onTabsChange') isPageShow: boolean
  @State title: string = 'MindSporeLite推理';
  @State modelName: string = 'mobilenetv2.ms';
  @State modelInputHeight: number = 224;
  @State modelInputWidth: number = 224;
  @State uris: Array<string> = [];
  @State max: number = 0;
  @State maxIndex: number = 0;
  @State maxArray: Array<number> = [];
  @State maxIndexArray: Array<number> = [];
  @State labelsNameMmap: string[] = [
    "Herd", "Safari", "Bangle", "Cushion", "Countertop",
    "Prom", "Branch", "Sports", "Sky", "Community",
    "Wheel", "Cola", "Tuxedo", "Flowerpot", "Team",
    "Computer", "Unicycle", "Brig", "Aerospace engineering", "Scuba diving",
    "Goggles", "Fruit", "Badminton", "Horse", "Sunglasses",
    "Fun", "Prairie", "Poster", "Flag", "Speedboat",
    "Eyelash", "Veil", "Mobile phone", "Wheelbarrow", "Saucer",
    "Leather", "Drawer", "Paper", "Pier", "Waterfowl",
    "Tights", "Rickshaw", "Vegetable", "Handrail", "Ice",
    "Metal", "Flower", "Wing", "Silverware", "Event",
    "Skyline", "Money", "Comics", "Handbag", "Porcelain",
    "Rodeo", "Curtain", "Tile", "Human mouth", "Army",
    "Menu", "Boat", "Snowboarding", "Cairn terrier", "Net",
    "Pasteles", "Cup", "Rugby", "Pho", "Cap",
    "Human hair", "Surfing", "Loveseat", "Museum", "Shipwreck",
    "Trunk (Tree)", "Plush", "Monochrome", "Volcano", "Rock",
    "Pillow", "Presentation", "Nebula", "Subwoofer", "Lake",
    "Sledding", "Bangs", "Tablecloth", "Necklace", "Swimwear",
    "Standing", "Jeans", "Carnival", "Softball", "Centrepiece",
    "Skateboarder", "Cake", "Dragon", "Aurora", "Skiing",
    "Bathroom", "Dog", "Needlework", "Umbrella", "Church",
    "Fire", "Piano", "Denim", "Bridle", "Cabinetry",
    "Lipstick", "Ring", "Television", "Roller", "Seal",
    "Concert", "Product", "News", "Fast food", "Horn (Animal)",
    "Tattoo", "Bird", "Bridegroom", "Love", "Helmet",
    "Dinosaur", "Icing", "Miniature", "Tire", "Toy",
    "Icicle", "Jacket", "Coffee", "Mosque", "Rowing",
    "Wetsuit", "Camping", "Underwater", "Christmas", "Gelato",
    "Whiteboard", "Field", "Ragdoll", "Construction", "Lampshade",
    "Palace", "Meal", "Factory", "Cage", "Clipper (Boat)",
    "Gymnastics", "Turtle", "Human foot", "Marriage", "Web page",
    "Human beard", "Fog", "Wool", "Cappuccino", "Lighthouse",
    "Lego", "Sparkler", "Sari", "Model", "Temple",
    "Beanie", "Building", "Waterfall", "Penguin", "Cave",
    "Stadium", "Smile", "Human hand", "Park", "Desk",
    "Shetland sheepdog", "Bar", "Eating", "Neon", "Dalmatian",
    "Crocodile", "Wakeboarding", "Longboard", "Road", "Race",
    "Kitchen", "Odometer", "Cliff", "Fiction", "School",
    "Interaction", "Bullfighting", "Boxer", "Gown", "Aquarium",
    "Superhero", "Pie", "Asphalt", "Surfboard", "Cheeseburger",
    "Screenshot", "Supper", "Laugh", "Lunch", "Party ",
    "Glacier", "Bench", "Grandparent", "Sink", "Pomacentridae",
    "Blazer", "Brick", "Space", "Backpacking", "Stuffed toy",
    "Sushi", "Glitter", "Bonfire", "Castle", "Marathon",
    "Pizza", "Beach", "Human ear", "Racing", "Sitting",
    "Iceberg", "Shelf", "Vehicle", "Pop music", "Playground",
    "Clown", "Car", "Rein", "Fur", "Musician",
    "Casino", "Baby", "Alcohol", "Strap", "Reef",
    "Balloon", "Outerwear", "Cathedral", "Competition", "Joker",
    "Blackboard", "Bunk bed", "Bear", "Moon", "Archery",
    "Polo", "River", "Fishing", "Ferris wheel", "Mortarboard",
    "Bracelet", "Flesh", "Statue", "Farm", "Desert",
    "Chain", "Aircraft", "Textile", "Hot dog", "Knitting",
    "Singer", "Juice", "Circus", "Chair", "Musical instrument",
    "Room", "Crochet", "Sailboat", "Newspaper", "Santa claus",
    "Swamp", "Skyscraper", "Skin", "Rocket", "Aviation",
    "Airliner", "Garden", "Ruins", "Storm", "Glasses",
    "Balance", "Nail (Body part)", "Rainbow", "Soil ", "Vacation ",
    "Moustache", "Doily", "Food", "Bride ", "Cattle",
    "Pocket", "Infrastructure", "Train", "Gerbil", "Fireworks",
    "Pet", "Dam", "Crew", "Couch", "Bathing",
    "Quilting", "Motorcycle", "Butterfly", "Sled", "Watercolor paint",
    "Rafting", "Monument", "Lightning", "Sunset", "Bumper",
    "Shoe", "Waterskiing", "Sneakers", "Tower", "Insect",
    "Pool", "Placemat", "Airplane", "Plant", "Jungle",
    "Armrest", "Duck", "Dress", "Tableware", "Petal",
    "Bus", "Hanukkah", "Forest", "Hat", "Barn",
    "Tubing", "Snorkeling", "Cool", "Cookware and bakeware", "Cycling",
    "Swing (Seat)", "Muscle", "Cat", "Skateboard", "Star",
    "Toe", "Junk", "Bicycle", "Bedroom", "Person",
    "Sand", "Canyon", "Tie", "Twig", "Sphynx",
    "Supervillain", "Nightclub", "Ranch", "Pattern", "Shorts",
    "Himalayan", "Wall", "Leggings", "Windsurfing", "Deejay",
    "Dance", "Van", "Bento", "Sleep", "Wine",
    "Picnic", "Leisure", "Dune", "Crowd", "Kayak",
    "Ballroom", "Selfie", "Graduation", "Frigate", "Mountain",
    "Dude", "Windshield", "Skiff", "Class", "Scarf",
    "Bull", "Soccer", "Bag", "Basset hound", "Tractor",
    "Swimming", "Running", "Track", "Helicopter", "Pitch",
    "Clock", "Song", "Jersey", "Stairs", "Flap",
    "Jewellery", "Bridge", "Cuisine", "Bread", "Caving",
    "Shell", "Wreath", "Roof", "Cookie", "Canoe"];
  @State logMessages: Array<string> = [];  // 新增日志状态

  // 当 Tabs 发生变化 && 页面显示 时（监听父组件的 currentIndex 和 isPageShow）
  onTabsChange() {
    if (this.currentIndex === 2 && this.isPageShow === true) {
    }
  }
  aboutToAppear(): void {
    emitter.on({
      eventId: RESULT
    }, (data) => {
      let message:string = JSON.stringify(data)
      let dataMessage:DataPass = JSON.parse(message)
      let realData:string = JSON.stringify(dataMessage.data)
      let realMessage:RealDataPass = JSON.parse(realData)
      let res =  taskDispatch.parseResultMessage(realMessage.content);
      if (res != "") {
        this.logMessages.push("[6/6] 结果接收成功"+res)
      }

    });
  }

  private modelManager: ModelManager = new ModelManager();
  @State isLoading: boolean = false;

  build() {
    Row() {
      Scroll() {
        Column() {
          Text(this.title)
            .focusable(true)
            .fontSize(45)
            .fontWeight(FontWeight.Bold)
          if (this.isLoading) {
            LoadingProgress()
              .width(50)
              .height(50)
              .margin(20)
          }

          // 优化后的图片预览区域
          if (this.uris[0]) {
            Image(this.uris[0])
              .width(300)
              .height(300)
              .margin(15)
              .borderRadius(16)
          }

          // 优化后的结果展示卡片
          if (this.maxArray && this.maxArray.length > 0) {
            Column() {
              ForEach(this.maxIndexArray, (item: number, index: number) => {
                Row() {
                  Text(this.labelsNameMmap[item])
                    .fontSize(18)
                    .layoutWeight(1)
                  Progress({
                    value: this.maxArray[index] / 100,
                    total: 100,
                    type: ProgressType.Linear
                  })
                    .width(150)
                    .margin({ left: 10 })
                  Text(`${(this.maxArray[index] / 100).toFixed(2)}%`)
                    .fontSize(16)
                }.margin({ bottom: 8 })
              })
            }
            .width('60%')
            .padding(20)
            .backgroundColor(Color.White)
            .margin({ top: 20 })
            .borderRadius(12)
            .shadow({ radius: 8, color: 'rgba(0,0,0,0.1)', offsetX: 2, offsetY: 2 })
          }

          // 优化后的按钮样式
          Button() {
            Text('选择图片')
              .fontSize(20)
              .fontColor(Color.White)
          }
          .type(ButtonType.Capsule)
          .width(200)
          .height(50)
          .margin(20)
          .backgroundColor('#0D9FFB')
          .onClick(async () => {
            this.isLoading = true
            try {
              await this.modelManager.initModel(this.modelName)
              const result = await this.handleImageSelection()
              this.maxArray = result.maxArray
              this.maxIndexArray = result.maxIndexArray
            } catch (err) {
              console.error('处理失败:', err)
            }
            this.isLoading = false
          })
          // 新增日志展示区域
          Column() {
            Text('推理日志')
              .fontSize(18)
              .margin({ bottom: 10 })
            Text(this.logMessages.join('\n'))
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
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .scrollBarColor(Color.Gray)
      .scrollBarWidth(10)
      .edgeEffect(EdgeEffect.Spring)
    }
    .height('100%')
    .width('100%')
  }

  private async handleImageSelection(): Promise<PredictResult> {
    return new Promise((resolve, reject) => {
      this.logMessages = []
      this.logMessages.push('[1/6] 开始选择图片...');
      let photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      let photoPicker = new photoAccessHelper.PhotoViewPicker();

      photoPicker.select(photoSelectOptions, async (err: BusinessError, photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
        if (err) {
          console.error('MS_LITE_ERR: PhotoViewPicker.select failed with err: ' + JSON.stringify(err));
          reject(err);
          return;
        }
        this.logMessages.push('[2/6] 已选择图片: ' + photoSelectResult.photoUris[0]);
        if (SchedulerInstance.workScheduler(this.uris[0], this.logMessages)){
          try {
            this.uris = photoSelectResult.photoUris;
            this.logMessages.push('[4/6] 本地执行开始图片预处理...');
            const processedImage = await this.modelManager.processImage(this.uris[0]);
            this.logMessages.push('[5/6] 开始模型推理...');

            const predictResult = await this.modelManager.predictWithTopResults([processedImage]);
            this.logMessages.push('[6/6] 推理完成');
            console.info('=========MS_LITE_LOG END=========');
            resolve(predictResult);
          } catch (e) {
            this.logMessages.push('[ERROR] 流程异常: ' + e.message);
            reject(e);
          }
        }
      });
    });
  }
}