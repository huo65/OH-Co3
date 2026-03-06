/**
 * 文件传输模块使用示例
 * 
 * 该文件展示了如何使用文件传输模块进行文件传输
 */

import { FileTransferManager, FileInfo, FileUtils } from '../index';

/**
 * 示例 1: 基本文件传输（自动选择协议）
 */
async function example1_BasicTransfer() {
  // 获取文件传输管理器实例
  const transferManager = FileTransferManager.getInstance();
  
  // 准备文件数据
  const fileData = new ArrayBuffer(1024); // 1KB 示例数据
  const fileInfo: FileInfo = {
    fileId: FileUtils.generateFileId(),
    fileName: 'test_image.jpg',
    size: fileData.byteLength,
    fileType: 'image/jpeg'
  };
  
  // 发起传输（小于 2MB 会自动使用 MQTT协议）
  const taskId = await transferManager.transferFile(fileData, fileInfo, 'target_device_1');
  console.info(`传输任务已创建，taskId=${taskId}`);
}

/**
 * 示例 2: 大文件传输（自动使用 TCP 协议）
 */
async function example2_LargeFileTransfer() {
  const transferManager = FileTransferManager.getInstance();
  
  // 准备一个大文件（大于 2MB）
  const largeFileData = new ArrayBuffer(3 * 1024 * 1024); // 3MB
  const fileInfo: FileInfo = {
    fileId: FileUtils.generateFileId(),
    fileName: 'large_model.ms',
    size: largeFileData.byteLength,
    fileType: 'application/octet-stream'
  };
  
  // 发起传输（大于 2MB 会自动使用 TCP 协议）
  const taskId = await transferManager.transferFile(largeFileData, fileInfo, 'target_device_2');
  console.info(`大文件传输任务已创建，taskId=${taskId}, 使用 TCP 协议`);
}

/**
 * 示例 3: 查询传输进度
 */
async function example3_CheckProgress(taskId: string) {
  const transferManager = FileTransferManager.getInstance();
  
  // 获取传输进度
  const progress = transferManager.getTransferProgress(taskId);
  if (progress) {
    console.info(`进度：${progress.progress}%, 状态：${progress.state}`);
  }
}

/**
 * 示例 4: 取消传输任务
 */
async function example4_CancelTransfer(taskId: string) {
  const transferManager = FileTransferManager.getInstance();
  
  // 取消传输
  const success = await transferManager.cancelTransfer(taskId);
  if (success) {
    console.info(`传输任务已取消，taskId=${taskId}`);
  }
}

/**
 * 示例 5: 自定义配置
 */
async function example5_CustomConfig() {
  const transferManager = FileTransferManager.getInstance();
  
  // 设置自定义配置
  transferManager.setDefaultOptions({
    sizeThreshold: 1 * 1024 * 1024, // 1MB 阈值
    tcpChunkSize: 64 * 1024,        // 64KB 分块
    maxRetries: 5,                  // 最多重试 5 次
    timeout: 60000,                 // 60 秒超时
    tcpPort: 9999                   // 使用 9999 端口
  });
  
  console.info('自定义配置已设置');
}

/**
 * 示例 6: 监听传输事件
 */
function example6_EventListening() {
  const transferManager = FileTransferManager.getInstance();
  
  // 监听传输开始事件
  // 注意：实际使用时需要通过 TransferEventManager 来监听
  
  console.info('事件监听器已注册');
}

/**
 * 示例 7: 查看活动任务
 */
function example7_ActiveTasks() {
  const transferManager = FileTransferManager.getInstance();
  
  // 获取所有活动任务
  const tasks = transferManager.getActiveTasks();
  console.info(`当前活动任务数：${tasks.length}`);
  
  tasks.forEach(task => {
    console.info(`任务 ${task.taskId}: ${task.state}, 协议：${task.protocol}`);
  });
}

/**
 * 示例 8: 文件哈希计算与校验
 */
async function example8_HashVerification() {
  const fileData = new ArrayBuffer(1024);
  
  // 计算哈希
  const hash = await FileUtils.calculateHash(fileData);
  console.info(`文件哈希：${hash}`);
  
  // 验证哈希
  const isValid = await FileUtils.verifyHash(fileData, hash);
  console.info(`哈希校验结果：${isValid ? '通过' : '失败'}`);
}

/**
 * 示例 9: 文件分块与重组
 */
function example9_Chunking() {
  const fileSize = 500 * 1024; // 500KB
  const fileData = new ArrayBuffer(fileSize);
  
  // 分块（每块 128KB）
  const chunks = FileUtils.chunkFile(fileData, 128 * 1024, 'test_task');
  console.info(`分块数量：${chunks.length}`);
  
  // 重组
  const reassembled = FileUtils.reassembleChunks(chunks);
  console.info(`重组后大小：${reassembled.byteLength}字节`);
}

/**
 * 示例 10: 完整的传输流程
 */
async function example10_CompleteFlow() {
  try {
    const transferManager = FileTransferManager.getInstance();
    
    // 1. 准备文件
    const fileData = new ArrayBuffer(2.5 * 1024 * 1024); // 2.5MB
    const fileInfo: FileInfo = {
      fileId: FileUtils.generateFileId(),
      fileName: 'model_file.ms',
      size: fileData.byteLength,
      fileType: 'application/octet-stream'
    };
    
    // 2. 发起传输
    const taskId = await transferManager.transferFile(fileData, fileInfo, 'device_A');
    console.info(`传输开始，taskId=${taskId}`);
    
    // 3. 等待并检查进度
    // await new Promise(resolve => setTimeout(resolve, 1000));
    const progress = transferManager.getTransferProgress(taskId);
    console.info(`当前进度：${progress?.progress}%`);
    
    // 4. 完成后清理
    setTimeout(() => {
      transferManager.cleanupCompletedTasks();
      console.info('已完成的任务已清理');
    }, 5000);
    
  } catch (error) {
    console.error('传输过程中发生错误:', error);
  }
}

// 导出所有示例函数
export {
  example1_BasicTransfer,
  example2_LargeFileTransfer,
  example3_CheckProgress,
  example4_CancelTransfer,
  example5_CustomConfig,
  example6_EventListening,
  example7_ActiveTasks,
  example8_HashVerification,
  example9_Chunking,
  example10_CompleteFlow
};
