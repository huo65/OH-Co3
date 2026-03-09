// 推理任务参数
export interface InferenceTask {
  // 任务相关字段
  taskId: string;
  modelName?: string;

  // 推理输入字段
  type: InferenceInputType;
  data: ImageInputData | TextInputData | AudioInputData | ArrayBuffer | '';
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

// 图像输入数据类型
export interface ImageInputData {
  imageData: string; // 图像数据
}

// 文本输入数据类型
export interface TextInputData {
  text: string; // 文本内容
}

// 音频输入数据类型
export interface AudioInputData {
  buffer: ArrayBuffer; // 音频数据缓冲区
  sampleRate: number; // 采样率
  channels: number; // 声道数
}

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
