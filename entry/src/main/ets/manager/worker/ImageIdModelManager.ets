import image from '@ohos.multimedia.image';
// import fileIo from '@ohos.file.fs';
import modelPredict from './Model';
import util from '@ohos.util';
import buffer from '@ohos.buffer';
import { fileIo } from '@kit.CoreFileKit';
import { InferenceWorker, InferenceInput, InferenceResult, InferenceInputType, ImageInputData,
  InferenceTask } from './InferenceWorker';


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
class ImageIdModelManager implements InferenceWorker {
  private static instance: ImageIdModelManager
  private modelBuffer: ArrayBuffer = new ArrayBuffer(0);
  private modelInputHeight: number = 224;
  private modelInputWidth: number = 224;
  private isInit: boolean = false;
  // 静态方法获取唯一实例
  public static getInstance(): ImageIdModelManager {
    if (!ImageIdModelManager.instance) {
      ImageIdModelManager.instance = new ImageIdModelManager()
    }
    return ImageIdModelManager.instance
  }

  async initModel(modelName: string): Promise<void> {
    if (this.isInit) {
      return
    }
    const resMgr = getContext().getApplicationContext().resourceManager;
    const rawFileContent: Uint8Array = await resMgr.getRawFileContent(modelName);
    this.modelBuffer = rawFileContent.buffer as ArrayBuffer;  // 添加类型断言
    this.isInit = true;
}

  async processImage(uri: string): Promise<ArrayBuffer> {
    try {
      const resourceManager = getContext().getApplicationContext().resourceManager;
      const fileData = await resourceManager.getMediaContent($r('app.media.dog'));
      const imageSource = image.createImageSource(fileData.buffer);
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
      return this.normalizeImageData(new Uint8Array(readBuffer));
    } catch (error) {
      console.error("Error details:",
        JSON.stringify({
          message: error.message,
          code: error.code,
          stack: error.stack
        }));
    } finally {
      // let file: fileIo.File | null = null;
      // file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      // if (file) {
      //   fileIo.closeSync(file); // 确保文件关闭
      // }
    }
    return this.normalizeImageData(new Uint8Array());
  }
  // 根据接受的参数处理图片
  async processImageWithParam(bitmap: string): Promise<ArrayBuffer> {
    const pixelMap = await this.base64ToPixelMap(bitmap);

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

  async processImageTOBase64(uri: string): Promise<string> {
    let file: fileIo.File | null = null;

    try {
      // 打开文件
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);

      // 创建图像源
      const imageSource = image.createImageSource(file.fd);
      const pixelMap = await imageSource.createPixelMap();

      // 获取原始图像信息
      const info = await pixelMap.getImageInfo();

      // 缩放至最大宽度 512
      const scale = Math.min(512 / info.size.width, 1);
      await pixelMap.scale(scale, scale);

      // 使用 ImagePacker 打包成 JPEG，设置压缩质量
      const imagePackerApi: image.ImagePacker = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/jpeg', quality: 70 };

      const data: ArrayBuffer = await imagePackerApi.packing(pixelMap, packOpts);

      // 转换为 Buffer 并生成 Base64
      const buf: buffer.Buffer = buffer.from(data);
      const base64 = buf.toString('base64', 0, buf.length);

      return base64;
    } catch (error) {
      console.error("Error processing image to base64:", error);
      return "";
    } finally {
      if (file) {
        fileIo.closeSync(file);
      }
    }
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

  // 实现InferenceWorker接口的infer方法，接受InferenceTask参数
  async infer(task: InferenceTask): Promise<InferenceResult> {
    if (!this.isInit) {
      return {
        success: false,
        message: 'Model not initialized'
      };
    }
    
    let processedData: ArrayBuffer;
    
    // 处理输入
    if (task.type === InferenceInputType.IMAGE) {
      let imageData = task.data as ImageInputData;
      processedData = await this.processImage(imageData.uri);
    } else {
      // 类型不匹配
      return {
        success: false,
        message: `Unsupported input type: ${task.type}`
      };
    }
    
    let predictResult = await this.predictWithTopResults([processedData]);
    
    return {
      success: true,
      maxArray: predictResult.maxArray,
      maxIndexArray: predictResult.maxIndexArray
    };
  }

  // 实现InferenceWorker接口的isInitialized方法
  isInitialized(): boolean {
    return this.isInit;
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
export {ImageIdModelManager as ModelManager}