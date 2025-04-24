import { BusinessError } from '@ohos.base';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { ModelManager } from '../../manager/ModelManager';
interface PredictResult {
  maxArray: number[];
  maxIndexArray: number[];
}
// TODO 参照Android改进
@Component
export struct MindSpore {
  // @Provide 装饰器和 @Consume 装饰器：与后代组件双向同步
  @Consume @Watch('onTabsChange') currentIndex: number
  @Consume @Watch('onTabsChange') isPageShow: boolean
  @State modelPredict: string = 'MindSporeLite推理';
  @State modelName: string = 'mobilenetv2.ms';
  // Andoid，正常运行但无法得到正确答案
  // @State modelName: string = 'mobilenetv2Android.ms';
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

  // 当 Tabs 发生变化 && 页面显示 时（监听父组件的 currentIndex 和 isPageShow）
  onTabsChange() {
    if (this.currentIndex === 2 && this.isPageShow === true) {
      // this.getDebugInfo()
      // this.getStatfsInfo()
      // this.getBatteryInfo()
    }
  }

  private modelManager: ModelManager = new ModelManager();
  @State isLoading: boolean = false;

  build() {
    Row() {
      Column() {
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
            .overlay('rgba(0,0,0,0.04)')
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
          .width('90%')
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
      }
    }
  }

  private async handleImageSelection(): Promise<PredictResult> {
    return new Promise((resolve, reject) => {
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

        try {
          this.uris = photoSelectResult.photoUris;
          const processedImage = await this.modelManager.processImage(this.uris[0]);
          const predictResult = await this.modelManager.predictWithTopResults([processedImage]);
          console.info('=========MS_LITE_LOG END=========');
          resolve(predictResult);
        } catch (e) {
          reject(e);
        }
      });
    });
  }
}