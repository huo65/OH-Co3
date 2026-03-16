// 推理任务参数
export interface InferenceTask {
  taskId: string;
  modelName?: string;

  // 保持 type 字段，方便旧代码读取，也方便日志
  type: InferenceInputType;

  // 规范化之后的核心数据结构
  data: InferenceInputData;

  params?: Record<string, string | number | boolean | ArrayBuffer>;
}
// 推理任务输入类型枚举
export enum InferenceInputType {
  IMAGE = 'image',
  TEXT = 'text',
  AUDIO = 'audio',
  VIDEO = 'video',
  OTHER = 'other'
}
export interface BaseInputData {
  /** 与枚举一一对应，作为联合类型的判别字段 */
  type: InferenceInputType;
}

/** 图像输入：强制使用二进制数据 */
export interface ImageInputData extends BaseInputData {
  type: InferenceInputType.IMAGE;
  buffer: ArrayBuffer;
  /** 可选：原始格式、宽高等元信息 */
  format?: string;
  width?: number;
  height?: number;
}

/** 文本输入 */
export interface TextInputData extends BaseInputData {
  type: InferenceInputType.TEXT;
  text: string;
  /** 可选：编码信息，例如 'utf-8' */
  encoding?: string;
}

/** 音频输入 */
export interface AudioInputData extends BaseInputData {
  type: InferenceInputType.AUDIO;
  buffer: ArrayBuffer;
  sampleRate: number;
  channels: number;
}

/** 视频输入 */
export interface VideoInputData extends BaseInputData {
  type: InferenceInputType.VIDEO;
  buffer: ArrayBuffer;
  /** 可选：帧率、分辨率等 */
  fps?: number;
}

/** 其他自定义二进制输入 */
export interface OtherInputData extends BaseInputData {
  type: InferenceInputType.OTHER;
  buffer: ArrayBuffer;
  metadata?: string;
}

/** 统一的规范化输入数据联合类型 */
export type InferenceInputData =
  | ImageInputData
    | TextInputData
    | AudioInputData
    | VideoInputData
    | OtherInputData;


// 推理结果类型
export interface InferenceResult {
  // 执行状态
  success: boolean;
  // 附加信息（可选
  message?: string;
  // 结果数据
  result?: ImageResult | TextResult | AudioResult  | CustomResult
}
// 图像识别结果（IMAGE类型专用）
interface ImageResult {
  maxArray?: number[];      // 置信度数组
  maxIndexArray?: number[]; // 最大索引数组
}

// 文本处理结果（TEXT类型专用）
interface TextResult {
  recognizedText: string;   // 识别文本
  confidence?: number;      // 置信度
}

// 音频处理结果（AUDIO类型专用）
interface AudioResult {
  transcription: string;    // 语音转文字结果
  buffer?: ArrayBuffer;     // 处理后的音频数据
}

// 自定义类型结果（OTHER类型专用）
interface CustomResult {
  data: ArrayBuffer;        // 原始二进制数据
  metadata?: string;        // 元数据描述
}



// 推理Worker接口
export interface InferenceWorker {

  // 初始化模型
  initModel(modelName: string): Promise<void>;
  
  // 执行推理（直接使用InferenceTask参数）
  infer(task: InferenceTask): Promise<InferenceResult>;
  
  // 检查是否已初始化
  isInitialized(): boolean;
  
  // 释放资源（可选）
  release?(): Promise<void>;
}
