/**
 * 文件处理工具类
 * 提供文件分块、重组、哈希计算等功能
 */
import { ChunkData, FileInfo, generateFileId } from '../model/TransferDataModels';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

/**
 * 文件处理工具类
 */
export class FileUtils {
  /**
   * 将文件数据分块
   * @param data - 文件原始数据
   * @param chunkSize - 每块大小（字节），默认 128KB
   * @param taskId - 任务 ID
   * @returns 分块数据数组
   */
  static chunkFile(data: ArrayBuffer, chunkSize: number = 128 * 1024, taskId: string): ChunkData[] {
    const chunks: ChunkData[] = [];
    const totalChunks = Math.ceil(data.byteLength / chunkSize);

    for (let i = 0; i < totalChunks; i++) {
      const start = i * chunkSize;
      const end = Math.min(start + chunkSize, data.byteLength);
      const chunkData = data.slice(start, end);

      const chunk: ChunkData = {
        taskId,
        chunkIndex: i,
        totalChunks,
        data: chunkData,
        chunkSize: chunkData.byteLength,
        isLastChunk: i === totalChunks - 1
      };

      chunks.push(chunk);
    }

    console.info(`[FileUtils] 文件分块完成，总块数：${totalChunks}`);
    return chunks;
  }

  /**
   * 重组分块数据为完整文件
   * @param chunks - 分块数据数组（需按 chunkIndex 排序）
   * @returns 完整的 ArrayBuffer
   */
  static reassembleChunks(chunks: ChunkData[]): ArrayBuffer {
    if (chunks.length === 0) {
      throw new Error('[FileUtils] 分块数组为空');
    }

    // 按索引排序
    chunks.sort((a, b) => a.chunkIndex - b.chunkIndex);

    // 计算总大小
    const totalSize = chunks.reduce((sum, chunk) => sum + chunk.data.byteLength, 0);

    // 创建目标缓冲区
    const result = new Uint8Array(totalSize);
    let offset = 0;

    // 依次复制每个分块
    for (const chunk of chunks) {
      const chunkArray = new Uint8Array(chunk.data);
      result.set(chunkArray, offset);
      offset += chunk.data.byteLength;
    }

    console.info(`[FileUtils] 文件重组完成，总大小：${totalSize} 字节`);
    return result.buffer;
  }

  /**
   * 计算文件哈希值（SHA-256）
   * @param data - 文件数据
   * @returns 哈希值字符串（十六进制）
   */
  static async calculateHash(data: ArrayBuffer): Promise<string> {
    try {
      const md = cryptoFramework.createMd('SHA256');
      const uint8Array = new Uint8Array(data);
      const dataBlob: cryptoFramework.DataBlob = { data: uint8Array };
      await md.update(dataBlob);
      const mdResult: cryptoFramework.DataBlob = await md.digest();

      // 转换为十六进制字符串
      const hashBytes = mdResult.data;
      let hashHex = '';
      for (let i = 0; i < hashBytes.length; i++) {
        hashHex += hashBytes[i].toString(16).padStart(2, '0');
      }

      console.info(`[FileUtils] 哈希计算完成：${hashHex.substring(0, 16)}...`);
      return hashHex;
    } catch (error) {
      const errMsg: string = error instanceof Error ? error.message : String(error);
      console.error('[FileUtils] 哈希计算失败:', errMsg);
      throw new Error(errMsg);
    }
  }

  /**
   * 验证文件哈希
   * @param data - 文件数据
   * @param expectedHash - 期望的哈希值
   * @returns 是否匹配
   */
  static async verifyHash(data: ArrayBuffer, expectedHash: string): Promise<boolean> {
    try {
      const actualHash = await FileUtils.calculateHash(data);
      return actualHash.toLowerCase() === expectedHash.toLowerCase();
    } catch (error) {
      console.error('[FileUtils] 哈希验证失败:', error);
      return false;
    }
  }

  /**
   * ArrayBuffer 转 Base64
   * @param buffer - ArrayBuffer
   * @returns Base64 字符串
   */
  static arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    const helper = new util.Base64Helper();
    const base64Bytes = helper.encodeSync(bytes);
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(base64Bytes);
  }

  /**
   * Base64 转 ArrayBuffer
   * @param base64 - Base64 字符串
   * @returns ArrayBuffer
   */
  static base64ToArrayBuffer(base64: string): ArrayBuffer {
    const helper = new util.Base64Helper();
    const encoder = new util.TextEncoder();
    const base64Bytes = encoder.encodeInto(base64).buffer as ArrayBuffer;
    const decoded = helper.decodeSync(new Uint8Array(base64Bytes));
    return decoded.buffer as ArrayBuffer;
  }

  /**
   * ArrayBuffer 转字符串
   * @param buffer - ArrayBuffer
   * @returns 字符串
   */
  static arrayBufferToString(buffer: ArrayBuffer): string {
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(new Uint8Array(buffer));
  }

  /**
   * 字符串转 ArrayBuffer
   * @param str - 字符串
   * @returns ArrayBuffer
   */
  static stringToArrayBuffer(str: string): ArrayBuffer {
    const encoder = new util.TextEncoder();
    return encoder.encodeInto(str).buffer as ArrayBuffer;
  }

  /**
   * 从文件路径获取文件信息
   * @param filePath - 文件路径
   * @returns 文件信息对象
   */
  static async getFileInfo(filePath: string): Promise<FileInfo> {
    const pathParts: string[] = filePath.split('/');
    const fileName: string = pathParts.length > 0 ? pathParts[pathParts.length - 1] : 'unknown';

    const fileInfo: FileInfo = {
      fileId: generateFileId(),
      fileName: fileName,
      size: 0,
      filePath: filePath,
      createdAt: Date.now()
    };

    return fileInfo;
  }

  /**
   * 生成文件唯一标识
   * @returns 文件 ID
   * @deprecated 使用 generateFileId 从 TransferDataModels 导入
   */
  static generateFileId(): string {
    return generateFileId();
  }
}
