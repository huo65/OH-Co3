/**
 * 通用工具函数
 * 提供模块内共享的辅助函数
 */

/**
 * 延迟函数
 * @param ms - 延迟毫秒数
 * @returns Promise
 */
export function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 生成唯一 ID
 * @param prefix - ID 前缀
 * @returns 唯一 ID 字符串
 */
export function generateUniqueId(prefix: string = 'id'): string {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * 格式化字节大小为人类可读格式
 * @param bytes - 字节数
 * @returns 格式化后的字符串
 */
export function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * 格式化持续时间
 * @param ms - 毫秒数
 * @returns 格式化后的字符串
 */
export function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
  const minutes = Math.floor(ms / 60000);
  const seconds = ((ms % 60000) / 1000).toFixed(0);
  return `${minutes}m ${seconds}s`;
}

/**
 * 计算传输速度
 * @param bytes - 传输字节数
 * @param durationMs - 持续时间（毫秒）
 * @returns 速度（字节/秒）
 */
export function calculateSpeed(bytes: number, durationMs: number): number {
  if (durationMs <= 0) return 0;
  return Math.round((bytes / durationMs) * 1000);
}

/**
 * 计算预计剩余时间
 * @param transferredBytes - 已传输字节数
 * @param totalBytes - 总字节数
 * @param elapsedMs - 已用时间（毫秒）
 * @returns 预计剩余时间（秒）
 */
export function calculateEstimatedTime(
  transferredBytes: number,
  totalBytes: number,
  elapsedMs: number
): number {
  if (transferredBytes <= 0 || elapsedMs <= 0) return 0;
  const speed = transferredBytes / elapsedMs; // bytes per ms
  const remainingBytes = totalBytes - transferredBytes;
  return Math.ceil(remainingBytes / speed / 1000);
}

/**
 * 安全地执行异步操作并返回结果
 * @param operation - 异步操作函数
 * @param errorHandler - 错误处理函数
 * @returns 操作结果或 null
 */
export async function safeExecute<T>(
  operation: () => Promise<T>,
  errorHandler?: (error: Error) => void
): Promise<T | null> {
  try {
    return await operation();
  } catch (error) {
    if (errorHandler && error instanceof Error) {
      errorHandler(error);
    } else {
      console.error('[CommonUtils] 操作执行失败:', error);
    }
    return null;
  }
}

/**
 * 带超时的 Promise
 * @param promise - 原始 Promise
 * @param timeoutMs - 超时时间（毫秒）
 * @param errorMessage - 超时错误消息
 * @returns Promise
 */
export function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  errorMessage: string = '操作超时'
): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => {
      setTimeout(() => reject(new Error(errorMessage)), timeoutMs);
    })
  ]);
}

/**
 * 重试执行异步操作
 * @param operation - 异步操作函数
 * @param maxRetries - 最大重试次数
 * @param delayMs - 重试延迟（毫秒）
 * @returns 操作结果
 */
export async function retry<T>(
  operation: () => Promise<T>,
  maxRetries: number,
  delayMs: number = 1000
): Promise<T> {
  let lastError: Error | undefined;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      
      if (attempt < maxRetries) {
        const waitTime = delayMs * (attempt + 1);
        console.warn(`[CommonUtils] 操作失败，${waitTime}ms 后重试 (${attempt + 1}/${maxRetries})`);
        await sleep(waitTime);
      }
    }
  }
  
  throw lastError || new Error('操作失败，已达到最大重试次数');
}

/**
 * 清理 Map 中过期的条目
 * @param map - 要清理的 Map
 * @param isExpired - 判断条目是否过期的函数
 * @returns 清理的条目数量
 */
export function cleanupExpiredEntries<K, V>(
  map: Map<K, V>,
  isExpired: (value: V, key: K) => boolean
): number {
  let cleanedCount = 0;
  const keysToDelete: K[] = [];
  
  map.forEach((value, key) => {
    if (isExpired(value, key)) {
      keysToDelete.push(key);
    }
  });
  
  keysToDelete.forEach(key => {
    map.delete(key);
    cleanedCount++;
  });
  
  return cleanedCount;
}

/**
 * 验证非空字符串
 * @param value - 要验证的值
 * @param fieldName - 字段名称（用于错误消息）
 * @returns 验证后的字符串
 * @throws 如果验证失败
 */
export function validateNonEmptyString(value: Object, fieldName: string): string {
  if (!(value instanceof String) && typeof value !== 'string') {
    throw new Error(`${fieldName} 必须是非空字符串`);
  }
  const strValue = value.toString();
  if (strValue.trim().length === 0) {
    throw new Error(`${fieldName} 必须是非空字符串`);
  }
  return strValue.trim();
}

/**
 * 验证正整数
 * @param value - 要验证的值
 * @param fieldName - 字段名称（用于错误消息）
 * @returns 验证后的数字
 * @throws 如果验证失败
 */
export function validatePositiveInteger(value: Object, fieldName: string): number {
  const num = Number(value);
  if (!Number.isInteger(num) || num <= 0) {
    throw new Error(`${fieldName} 必须是正整数`);
  }
  return num;
}

/**
 * 验证端口范围
 * @param port - 端口号
 * @returns 验证后的端口号
 * @throws 如果验证失败
 */
export function validatePort(port: Object): number {
  const num = Number(port);
  const portNum = Number(port);
  if (!Number.isInteger(num) || num < 1 || portNum > 65535) {
    throw new Error(`端口号必须在 1-65535 范围内`);
  }
  return num;
}
