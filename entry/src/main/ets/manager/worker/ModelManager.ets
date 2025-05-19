import image from '@ohos.multimedia.image';
import fileIo from '@ohos.file.fs';
import modelPredict from './Model';
import util from '@ohos.util';


// 在文件顶部添加类型定义
interface ImageSize {
  height: number;
  width: number;
}

interface CropOptions {
  x: number;
  y: number;
  size: ImageSize;
}

interface PredictResult {
  maxArray: number[];
  maxIndexArray: number[];
}
  interface ValueIndexPair {
    val: number;
    idx: number;
  }
export class ModelManager {
  private modelBuffer: ArrayBuffer = new ArrayBuffer(0);
  private modelInputHeight: number = 224;
  private modelInputWidth: number = 224;

  async initModel(modelName: string): Promise<void> {
    const resMgr = getContext().getApplicationContext().resourceManager;
    const rawFileContent: Uint8Array = await resMgr.getRawFileContent(modelName);
    this.modelBuffer = rawFileContent.buffer as ArrayBuffer;  // 添加类型断言
}

  async processImage(uri: string): Promise<ArrayBuffer> {
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    const imageSource = image.createImageSource(file.fd);
    const pixelMap = await imageSource.createPixelMap();
    
    // 图片预处理
    const info = await pixelMap.getImageInfo();
    await pixelMap.scale(256.0 / info.size.width, 256.0 / info.size.height);
    // 修改crop参数类型
    const cropOptions: CropOptions = {
      x: 16,
      y: 16,
      size: {
        height: this.modelInputHeight,
        width: this.modelInputWidth
      }
    };
    await pixelMap.crop(cropOptions);
    // 获取像素数据
    const readBuffer = new ArrayBuffer(this.modelInputHeight * this.modelInputWidth * 4);
    await pixelMap.readPixelsToBuffer(readBuffer);
    fileIo.closeSync(file);

    return this.normalizeImageData(new Uint8Array(readBuffer));
  }

  private normalizeImageData(imageArr: Uint8Array): ArrayBuffer {
    const means = [0.485, 0.456, 0.406];
    const stds = [0.229, 0.224, 0.225];
    const float32View = new Float32Array(this.modelInputHeight * this.modelInputWidth * 3);
    
    let index = 0;
    for (let i = 0; i < imageArr.length; i += 4) { // 修改循环方式
      float32View[index] = (imageArr[i] / 255.0 - means[0]) / stds[0]; // R
      float32View[index+1] = (imageArr[i+1] / 255.0 - means[1]) / stds[1]; // G
      float32View[index+2] = (imageArr[i+2] / 255.0 - means[2]) / stds[2]; // B
      index += 3;
    }
    return float32View.buffer;
  }


  async predictWithTopResults(inputs: ArrayBuffer[]): Promise<PredictResult> {
    const outputs = await modelPredict(this.modelBuffer.slice(0), inputs)
    const result = new Float32Array(outputs[0].getData())
    console.info('=========MS_LITE_LOG: MS_LITE predict success=====');

    console.info('MS_LITE_LOG: max:' + this.getTopValues(result, 5));
    console.info('MS_LITE_LOG: maxIndex:' + this.getTopIndices(result, 5));
    
    return {
      maxArray: this.getTopValues(result, 5),
      maxIndexArray: this.getTopIndices(result, 5)
    } as PredictResult;
  }

  private getTopValues(arr: Float32Array, count: number): number[] {
    return [...arr]
      .map((val, idx) => ({ val, idx } as ValueIndexPair))
      .sort((a, b) => b.val - a.val)
      .slice(0, count)
      .map(item => Math.round(item.val * 10000))
  }

  private getTopIndices(arr: Float32Array, count: number): number[] {
    return [...arr]
      .map((val, idx) => ({ val, idx } as ValueIndexPair))
      .sort((a, b) => b.val - a.val)
      .slice(0, count)
      .map(item => item.idx)
  }



  base64ToPixelMap(base64: string): Promise<image.PixelMap> {
    //将原始图片base64字符串转变为通过base64字符串
    const reg = new RegExp('data:image/\\w+;base64,');
    const base64Str = base64.replace(reg, '');
    //将通用base64字符串转变为arrayBuffer
    let base64Helper = new util.Base64Helper();
    let arrayBuffer = base64Helper.decodeSync(base64Str).buffer as ArrayBuffer;
    //将arrayBuffer转变为pixelMap
    let imageSource = image.createImageSource(arrayBuffer);
    let opts: image.DecodingOptions = { editable: false }
    //注意：这里return的是Promise，因此使用时需要在业务侧拿到最终的PixelMap
    return imageSource.createPixelMap(opts);
  }
}