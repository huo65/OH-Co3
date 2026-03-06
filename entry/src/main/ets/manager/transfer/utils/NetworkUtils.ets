/**
 * 网络工具类
 * 提供网络状态检测、IP 地址获取等功能
 */
import wifiManager from '@ohos.wifiManager';

export class NetworkUtils {
  /**
   * 获取设备 IP 地址
   * @returns IPv4 地址字符串，失败返回空字符串
   */
  static getIpAddress(): string {
    try {
      const ipInfo = wifiManager.getIpInfo();
      const ipNum = ipInfo.ipAddress;
      
      // 将整数 IP 转换为点分十进制格式
      const ip = (ipNum >>> 24) + '.' + 
                 (ipNum >> 16 & 0xFF) + '.' + 
                 (ipNum >> 8 & 0xFF) + '.' + 
                 (ipNum & 0xFF);
      
      console.info(`[NetworkUtils] 获取 IP 地址：${ip}`);
      return ip;
    } catch (error) {
      console.error('[NetworkUtils] 获取 IP 地址失败:', error);
      return '';
    }
  }

  /**
   * 检查网络连接状态
   * @returns 是否已连接
   */
  static isNetworkConnected(): boolean {
    try {
      const wifiState = wifiManager.isWifiActive();
      console.info(`[NetworkUtils] WiFi 连接状态：${wifiState}`);
      return wifiState;
    } catch (error) {
      console.error('[NetworkUtils] 检查网络状态失败:', error);
      return false;
    }
  }


  /**
   * 获取子网掩码
   * @returns 子网掩码地址
   */
  static getSubnetMask(): string {
    try {
      const ipInfo = wifiManager.getIpInfo();
      const netmask = ipInfo.netmask;
      
      const mask = (netmask >>> 24) + '.' + 
                   (netmask >> 16 & 0xFF) + '.' + 
                   (netmask >> 8 & 0xFF) + '.' + 
                   (netmask & 0xFF);
      
      return mask;
    } catch (error) {
      console.error('[NetworkUtils] 获取子网掩码失败:', error);
      return '255.255.255.0';
    }
  }

  /**
   * 获取网关地址
   * @returns 网关地址
   */
  static getGateway(): string {
    try {
      const ipInfo = wifiManager.getIpInfo();
      const gateway = ipInfo.gateway;
      
      const gw = (gateway >>> 24) + '.' + 
                 (gateway >> 16 & 0xFF) + '.' + 
                 (gateway >> 8 & 0xFF) + '.' + 
                 (gateway & 0xFF);
      
      return gw;
    } catch (error) {
      console.error('[NetworkUtils] 获取网关地址失败:', error);
      return '';
    }
  }

  /**
   * 验证 IP 地址格式
   * @param ip - IP 地址字符串
   * @returns 是否是有效的 IPv4 地址
   */
  static isValidIpAddress(ip: string): boolean {
    const ipv4Pattern = /^(\d{1,3}\.){3}\d{1,3}$/;
    
    if (!ipv4Pattern.test(ip)) {
      return false;
    }
    
    const parts = ip.split('.');
    for (const part of parts) {
      const num = parseInt(part, 10);
      if (num < 0 || num > 255) {
        return false;
      }
    }
    
    return true;
  }

  /**
   * 将端口号转换为有效数字
   * @param port - 端口号
   * @param defaultPort - 默认端口号
   * @returns 有效的端口号
   */
  static validatePort(port: number | undefined, defaultPort: number = 8888): number {
    if (port === undefined || isNaN(port)) {
      return defaultPort;
    }
    
    if (port < 1 || port > 65535) {
      console.warn(`[NetworkUtils] 端口号 ${port} 无效，使用默认端口 ${defaultPort}`);
      return defaultPort;
    }
    
    return port;
  }
}
