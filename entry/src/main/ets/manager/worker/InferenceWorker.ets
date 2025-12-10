// 推理任务输入类型枚举
export enum InferenceInputType {
  IMAGE = 'image',
  TEXT = 'text',
  AUDIO = 'audio',
  VIDEO = 'video',
  OTHER = 'other'
}

// 推理任务参数类型
// export interface InferenceParams {
//   [key: string]: string | number | boolean | ArrayBuffer;
// }
export interface InferenceParams extends Record<string, string | number | boolean | ArrayBuffer> {}

// 图像输入数据类型
export interface ImageInputData {
  uri: string; // 本地图像URI
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

// 通用推理输入类型
export interface InferenceInput {
  type: InferenceInputType;
  data: ImageInputData | TextInputData | AudioInputData | ArrayBuffer;
  params?: InferenceParams;
}

// 推理结果类型
export interface InferenceResult {
  // 通用结果字段
  success: boolean;
  message?: string;
  
  // 图像识别特定结果（可选）
  maxArray?: number[];
  maxIndexArray?: number[];
  
  // 文本识别特定结果（可选）
  textResult?: string;
  confidence?: number;
  
  // 自定义结果数据（可选）
  customData?: ArrayBuffer;
}

// 推理任务参数类型（用于导入）
export interface InferenceTask {
  // 任务相关字段
  taskId?: string;
  modelName?: string;
  
  // 推理输入字段
  type: InferenceInputType;
  data: ImageInputData | TextInputData | AudioInputData | ArrayBuffer;
  params?: Record<string, string | number | boolean | ArrayBuffer>;

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
