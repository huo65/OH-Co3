/**
 * 文件传输模块使用示例
 * 
 * 该文件展示了如何使用文件传输模块进行文件传输
 */

import { FileTransferManager, FileInfo, generateFileId, TransferResult, TransferErrorCode, FileTransferCompleteResult } from '../index';

/**
 * 示例 1: 基本文件传输（显式指定 MQTT 协议）
 */
async function example1_BasicTransfer() {
  // 获取文件传输管理器实例
  const transferManager = FileTransferManager.getInstance();

  // 准备文件数据
  const fileData = new ArrayBuffer(1024); // 1KB 示例数据
  const fileInfo: FileInfo = {
    fileId: generateFileId(),
    fileName: 'test_image.jpg',
    size: fileData.byteLength,
    fileType: 'image/jpeg'
  };

  // 发起传输（显式指定使用 MQTT 协议）
  const result = await transferManager.transferFile(fileData, fileInfo, 'target_device_1', 'MQTT');
  
  if (result.success) {
    console.info(`传输成功，taskId=${result.taskId}`);
    const completeResult = result.data as FileTransferCompleteResult;
    console.info(`传输耗时: ${completeResult.duration}ms, 平均速度: ${completeResult.averageSpeed} B/s`);
  } else {
    console.error(`传输失败: ${result.error?.message}, 错误码: ${result.error?.code}`);
  }
}

/**
 * 示例 2: 大文件传输（显式指定 TCP 协议）
 */
async function example2_LargeFileTransfer() {
  const transferManager = FileTransferManager.getInstance();

  // 准备一个大文件（大于 2MB）
  const largeFileData = new ArrayBuffer(3 * 1024 * 1024); // 3MB
  const fileInfo: FileInfo = {
    fileId: generateFileId(),
    fileName: 'large_model.ms',
    size: largeFileData.byteLength,
    fileType: 'application/octet-stream'
  };

  // 发起传输（显式指定 TCP 协议）
  const result = await transferManager.transferFile(largeFileData, fileInfo, 'target_device_2', 'TCP');
  
  if (result.success) {
    console.info(`大文件传输成功，taskId=${result.taskId}`);
  } else {
    console.error(`大文件传输失败: ${result.error?.message}`);
  }
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
    console.info(`已传输：${progress.transferredBytes}/${progress.totalBytes} 字节`);
    if (progress.speed) {
      console.info(`传输速度：${progress.speed} 字节/秒`);
    }
    if (progress.estimatedTimeRemaining) {
      console.info(`预计剩余时间：${progress.estimatedTimeRemaining} 秒`);
    }
  }
}

/**
 * 示例 4: 取消传输任务
 */
async function example4_CancelTransfer(taskId: string) {
  const transferManager = FileTransferManager.getInstance();

  // 取消传输
  const result = await transferManager.cancelTransfer(taskId);
  if (result.success) {
    console.info(`传输任务已取消，taskId=${taskId}`);
  } else {
    console.error(`取消失败: ${result.error?.message}`);
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
  // 通过 TransferEventManager 来监听
  // 注意：需要单独导入 TransferEventManager 和 TransferEventId

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
 * 示例 8: 获取协议能力信息
 */
function example8_ProtocolCapabilities() {
  const transferManager = FileTransferManager.getInstance();

  // 获取 TCP 协议的能力信息
  const tcpCapabilities = transferManager.getProtocolCapabilities('TCP');
  if (tcpCapabilities) {
    console.info(`TCP 协议能力:`);
    console.info(`  - 支持大文件: ${tcpCapabilities.supportsLargeFiles}`);
    console.info(`  - 默认分块大小: ${tcpCapabilities.defaultChunkSize} 字节`);
    console.info(`  - 支持断点续传: ${tcpCapabilities.supportsResume}`);
  }

  // 检查协议是否支持特定功能
  const supportsChunking = transferManager.isCapabilitySupported('TCP', 'supportsChunking');
  console.info(`TCP 协议支持分块传输: ${supportsChunking}`);
}

/**
 * 示例 9: 错误处理
 */
async function example9_ErrorHandling() {
  const transferManager = FileTransferManager.getInstance();

  const fileData = new ArrayBuffer(1024);
  const fileInfo: FileInfo = {
    fileId: generateFileId(),
    fileName: 'test.txt',
    size: fileData.byteLength
  };

  const result = await transferManager.transferFile(fileData, fileInfo, 'target', 'UNKNOWN_PROTOCOL');

  if (!result.success && result.error) {
    // 根据错误码进行不同的处理
    switch (result.error.code) {
      case TransferErrorCode.PROTOCOL_NOT_FOUND:
        console.error('协议未找到，请检查协议名称');
        break;
      case TransferErrorCode.CONNECTION_FAILED:
        console.error('连接失败，请检查网络');
        break;
      case TransferErrorCode.TIMEOUT:
        console.error('传输超时，请稍后重试');
        break;
      default:
        console.error(`传输失败: ${result.error.message}`);
    }
  }
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
      fileId: generateFileId(),
      fileName: 'model_file.ms',
      size: fileData.byteLength,
      fileType: 'application/octet-stream'
    };

    // 2. 发起传输（显式指定 TCP 协议）
    const result = await transferManager.transferFile(fileData, fileInfo, 'device_A', 'TCP');
    console.info(`传输开始，taskId=${result.taskId}`);

    if (result.success) {
      // 3. 传输成功
      const completeResult = result.data as FileTransferCompleteResult;
      console.info(`传输完成，耗时: ${completeResult.duration}ms`);
      console.info(`平均速度: ${completeResult.averageSpeed} 字节/秒`);
    } else {
      // 4. 传输失败
      console.error(`传输失败: ${result.error?.message}`);
    }

    // 5. 完成后清理
    setTimeout(() => {
      const cleanedCount = transferManager.cleanupCompletedTasks();
      console.info(`已清理 ${cleanedCount} 个已完成任务`);
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
  example8_ProtocolCapabilities,
  example9_ErrorHandling,
  example10_CompleteFlow
};
