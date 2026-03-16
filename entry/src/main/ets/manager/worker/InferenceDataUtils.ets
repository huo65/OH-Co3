import { InferenceInputData, InferenceInputType } from "./InferenceWorker";

export class InferenceDataUtils {
  /**
   * 估算统一数据结构的大小
   */
  static estimateInputDataSize(input: InferenceInputData): number {
    if (input.type === InferenceInputType.TEXT) {
      // 文本：根据字符数估算（这里用 UTF-8 简单估算）
      const text: string = input.text;
      return InferenceDataUtils.estimateStringSize(text);
    }else {
      // TODO 待测试
      return input.buffer.byteLength;
    }

    // 其他类型都用二进制 buffer 长度
    // if (InferenceDataUtils.isBufferInput(input)) {
    //   return input.buffer.byteLength;
    // }

    // 理论上不会走到这里
    return 0;
  }

  private static isBufferInput(input: InferenceInputData): boolean {

    return input instanceof ArrayBuffer;
  }

  private static estimateStringSize(text: string): number {
    // 简单估算：按 UTF-8 平均 1~3 字节，这里取 2 作折中
    const length: number = text.length;
    return length * 2;
  }
}