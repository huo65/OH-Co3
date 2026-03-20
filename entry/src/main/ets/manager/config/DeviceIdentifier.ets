/**
 * 设备标识管理模块
 * 统一管理设备唯一标识符的生成与访问
 *
 * 设计原则：
 * 1. 全局唯一性：结合设备型号、随机UUID、时间戳确保唯一性
 * 2. 可读性：包含设备型号前缀，便于识别
 * 3. 稳定性：应用生命周期内保持不变
 */
import deviceInfo from '@ohos.deviceInfo';
import util from '@ohos.util';

/**
 * 设备标识配置接口
 */
export interface DeviceIdentifierConfig {
  /** 设备唯一标识符 */
  deviceId: string;
  /** 设备型号 */
  productModel: string;
  /** 设备类型 */
  deviceType: string;
}

/**
 * 设备标识管理类
 * 负责生成和管理设备唯一标识符
 */
class DeviceIdentifierManager {
  /** 设备唯一标识符（应用生命周期内保持不变） */
  private _deviceId: string = '';

  /** 设备型号 */
  private _productModel: string = '';

  /** 设备类型 */
  private _deviceType: string = '';

  /** 标识是否已初始化 */
  private _initialized: boolean = false;

  /**
   * 获取设备唯一标识符
   * 如果未初始化则自动初始化
   */
  get deviceId(): string {
    if (!this._initialized) {
      this.initialize();
    }
    return this._deviceId;
  }

  /**
   * 获取设备型号
   */
  get productModel(): string {
    if (!this._initialized) {
      this.initialize();
    }
    return this._productModel;
  }

  /**
   * 获取设备类型
   */
  get deviceType(): string {
    if (!this._initialized) {
      this.initialize();
    }
    return this._deviceType;
  }

  /**
   * 获取完整配置
   * @returns 设备标识配置对象
   */
  getConfig(): DeviceIdentifierConfig {
    if (!this._initialized) {
      this.initialize();
    }
    const config: DeviceIdentifierConfig = {
      deviceId: this._deviceId,
      productModel: this._productModel,
      deviceType: this._deviceType
    };
    return config;
  }

  /**
   * 初始化设备标识
   * 生成格式: OH-{productModel}-{shortUUID}
   * 示例: OH-MatePadPro-1a2b3c4d
   */
  private initialize(): void {
    if (this._initialized) {
      return;
    }

    // 获取设备型号（如 MatePadPro、Phone 等）
    this._productModel = this.sanitizeProductModel(deviceInfo.productModel);

    // 获取设备类型
    this._deviceType = this.getDeviceTypeName();

    // 生成唯一标识符
    this._deviceId = this.generateUniqueId();

    this._initialized = true;

    console.info(`[HarmonyInference] [DeviceIdentifier] 设备标识初始化完成: ${this._deviceId}`);
  }

  /**
   * 生成唯一设备标识符
   * 格式: OH-{productModel}-{shortUUID}
   * @returns 唯一标识符字符串
   */
  private generateUniqueId(): string {
    // 生成随机UUID
    const fullUUID: string = util.generateRandomUUID(false);

    // 取前8位作为短UUID，保证可读性的同时减少长度
    const shortUUID: string = fullUUID.substring(0, 8).toLowerCase();

    // 组合生成唯一标识符
    const deviceId: string = `OH-${this._productModel}-${shortUUID}`;

    return deviceId;
  }

  /**
   * 清理设备型号字符串
   * 移除空格和特殊字符，保留字母数字和连字符
   * @param model 原始设备型号
   * @returns 清理后的设备型号
   */
  private sanitizeProductModel(model: string): string {
    // 移除空格和特殊字符，只保留字母数字
    let sanitized: string = '';
    for (let i: number = 0; i < model.length; i++) {
      const char: string = model.charAt(i);
      const code: number = char.charCodeAt(0);
      // 保留字母(a-z, A-Z)和数字(0-9)
      if ((code >= 97 && code <= 122) || (code >= 65 && code <= 90) || (code >= 48 && code <= 57)) {
        sanitized = sanitized + char;
      }
    }

    // 如果清理后为空，使用默认值
    if (sanitized.length === 0) {
      sanitized = 'Device';
    }

    return sanitized;
  }

  /**
   * 获取设备类型名称
   * @returns 设备类型名称字符串
   */
  private getDeviceTypeName(): string {
    // deviceInfo.deviceType 返回设备类型，如 "phone", "tablet" 等
    const typeMap: Record<string, string> = {
      'phone': 'Phone',
      'tablet': 'Tablet',
      'tv': 'TV',
      'wearable': 'Wearable',
      'car': 'Car',
      'default': 'Unknown'
    };

    const deviceType: string = deviceInfo.deviceType;
    const typeName: string | undefined = typeMap[deviceType];

    if (typeName !== undefined) {
      return typeName;
    }
    return 'Unknown';
  }

  /**
   * 重置设备标识（仅用于测试）
   * 注意：生产环境不应调用此方法
   */
  reset(): void {
    this._deviceId = '';
    this._productModel = '';
    this._deviceType = '';
    this._initialized = false;
    console.warn('[HarmonyInference] [DeviceIdentifier] 设备标识已重置');
  }
}

/**
 * 设备标识管理器单例实例
 * 全局统一访问点
 */
export const deviceIdentifier = new DeviceIdentifierManager();

/**
 * 便捷函数：获取设备唯一标识符
 * @returns 设备唯一标识符
 */
export function getDeviceId(): string {
  return deviceIdentifier.deviceId;
}

/**
 * 便捷函数：获取设备型号
 * @returns 设备型号
 */
export function getProductModel(): string {
  return deviceIdentifier.productModel;
}

/**
 * 便捷函数：获取设备类型
 * @returns 设备类型
 */
export function getDeviceType(): string {
  return deviceIdentifier.deviceType;
}
