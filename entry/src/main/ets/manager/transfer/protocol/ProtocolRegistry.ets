/**
 * 协议注册中心
 * 管理所有可用的传输协议，支持动态注册和查找
 */
import { TransferProtocolInterface } from './TransferProtocolInterface';

export class ProtocolRegistry {
  private static instance: ProtocolRegistry;
  private protocols: Map<string, TransferProtocolInterface> = new Map();

  private constructor() {
    // 私有构造函数，防止外部实例化
  }

  /**
   * 获取单例实例
   */
  static getInstance(): ProtocolRegistry {
    if (!ProtocolRegistry.instance) {
      ProtocolRegistry.instance = new ProtocolRegistry();
    }
    return ProtocolRegistry.instance;
  }

  /**
   * 注册传输协议
   * @param protocolName - 协议名称
   * @param protocol - 协议实现实例
   * @returns 是否注册成功
   */
  registerProtocol(protocolName: string, protocol: TransferProtocolInterface): boolean {
    if (this.protocols.has(protocolName)) {
      console.warn(`[ProtocolRegistry] 协议 ${protocolName} 已存在，将被覆盖`);
    }
    this.protocols.set(protocolName, protocol);
    console.info(`[ProtocolRegistry] 协议 ${protocolName} 注册成功`);
    return true;
  }

  /**
   * 注销传输协议
   * @param protocolName - 协议名称
   * @returns 是否注销成功
   */
  unregisterProtocol(protocolName: string): boolean {
    const result = this.protocols.delete(protocolName);
    if (result) {
      console.info(`[ProtocolRegistry] 协议 ${protocolName} 注销成功`);
    } else {
      console.warn(`[ProtocolRegistry] 协议 ${protocolName} 不存在`);
    }
    return result;
  }

  /**
   * 获取传输协议实例
   * @param protocolName - 协议名称
   * @returns 协议实例，不存在则返回 null
   */
  getProtocol(protocolName: string): TransferProtocolInterface | null {
    const protocol = this.protocols.get(protocolName);
    if (!protocol) {
      console.warn(`[ProtocolRegistry] 未找到协议 ${protocolName}`);
    }
    return protocol || null;
  }

  /**
   * 列出所有已注册的协议
   * @returns 协议名称数组
   */
  listProtocols(): string[] {
    return Array.from(this.protocols.keys());
  }

  /**
   * 检查协议是否已注册
   * @param protocolName - 协议名称
   * @returns 是否已注册
   */
  hasProtocol(protocolName: string): boolean {
    return this.protocols.has(protocolName);
  }

  /**
   * 清空所有协议
   */
  clearAll(): void {
    this.protocols.clear();
    console.info('[ProtocolRegistry] 所有协议已清空');
  }
}
