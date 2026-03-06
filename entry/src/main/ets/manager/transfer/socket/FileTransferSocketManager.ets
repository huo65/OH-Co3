/**
 * TCP Socket 管理器
 * 统一管理 TCP 文件传输的 Socket 连接
 */
import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { NetworkUtils } from '../utils/NetworkUtils';

/**
 * TCP 连接信息
 */
export interface TCPConnectionInfo {
  /** 连接 ID */
  connectionId: string;
  /** 远程 IP 地址 */
  remoteIp: string;
  /** 远程端口 */
  remotePort: number;
  /** Socket 连接对象 */
  socket: socket.TCPSocket | socket.TCPSocketConnection;
  /** 创建时间 */
  createdAt: number;
  /** 最后活跃时间 */
  lastActiveAt: number;
}

/**
 * TCP Socket 管理类
 * 负责管理所有 TCP 连接的生命周期
 */
export class FileTransferSocketManager {
  private static instance: FileTransferSocketManager;
  
  /** 服务端 Socket */
  private serverSocket: socket.TCPSocketServer | null = null;
  
  /** 客户端连接池 */
  private connections: Map<string, TCPConnectionInfo> = new Map();
  
  /** 是否正在监听 */
  private isListening: boolean = false;
  
  /** 监听端口 */
  private listenPort: number = 8888;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): FileTransferSocketManager {
    if (!FileTransferSocketManager.instance) {
      FileTransferSocketManager.instance = new FileTransferSocketManager();
    }
    return FileTransferSocketManager.instance;
  }

  /**
   * 启动 TCP 服务器监听
   * @param port - 监听端口，默认 8888
   * @returns 是否启动成功
   */
  async startServer(port: number = 8888): Promise<boolean> {
    if (this.isListening) {
      console.warn('[FileTransferSocketManager] 服务器已在监听中');
      return true;
    }

    try {
      this.listenPort = port;
      const ipAddress = NetworkUtils.getIpAddress();
      
      if (!ipAddress) {
        console.error('[FileTransferSocketManager] 无法获取本机 IP 地址');
        return false;
      }

      // 创建 TCP Socket Server
      this.serverSocket = socket.constructTCPSocketServerInstance();
      
      const netAddress: socket.NetAddress = {
        address: ipAddress,
        port: port
      };

      // 绑定并监听
      await this.serverSocket.listen(netAddress);
      this.isListening = true;
      
      console.info(`[FileTransferSocketManager] TCP 服务器启动成功，${ipAddress}:${port}`);

      // 监听客户端连接
      this.setupConnectionListener();
      
      return true;
    } catch (error) {
      console.error('[FileTransferSocketManager] TCP 服务器启动失败:', error);
      this.isListening = false;
      return false;
    }
  }

  /**
   * 设置连接监听器
   */
  private setupConnectionListener(): void {
    if (!this.serverSocket) return;

    this.serverSocket.on('connect', (client: socket.TCPSocketConnection) => {
      console.info('[FileTransferSocketManager] 新的客户端连接');
      
      // 生成连接 ID
      const connectionId = `conn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      
      // 保存连接信息
      const connectionInfo: TCPConnectionInfo = {
        connectionId,
        remoteIp: '', // 可以从 client 获取
        remotePort: 0,
        socket: client,
        createdAt: Date.now(),
        lastActiveAt: Date.now()
      };
      
      this.connections.set(connectionId, connectionInfo);
      
      // 设置消息接收处理
      this.setupMessageHandler(connectionId, client);
      
      // 设置关闭处理
      client.on('close', () => {
        console.info(`[FileTransferSocketManager] 连接关闭：${connectionId}`);
        this.removeConnection(connectionId);
      });
    });
  }

  /**
   * 设置消息处理器
   */
  private setupMessageHandler(
    connectionId: string,
    client: socket.TCPSocketConnection
  ): void {
    interface MessageValue {
      message?: ArrayBuffer;
    }
    client.on('message', (value: MessageValue) => {
      // 更新最后活跃时间
      const conn = this.connections.get(connectionId);
      if (conn) {
        conn.lastActiveAt = Date.now();
      }
      
      // 这里可以添加消息处理逻辑
      console.info(`[FileTransferSocketManager] 收到消息，connectionId=${connectionId}`);
    });
  }

  /**
   * 连接到远程 TCP 服务器
   * @param host - 远程主机 IP
   * @param port - 远程端口
   * @param timeout - 超时时间（毫秒）
   * @returns 连接 ID，失败返回 null
   */
  async connectToServer(host: string, port: number, timeout: number = 30000): Promise<string | null> {
    try {
      // 创建 TCP Socket
      const tcpClient = socket.constructTCPSocketInstance();
      
      // 获取本机 IP 和端口
      const localIp = NetworkUtils.getIpAddress();
      const localPort = port + 1000; // 使用不同的本地端口
      
      // 绑定本地地址
      const localAddress: socket.NetAddress = {
        address: localIp,
        port: localPort
      };
      
      await new Promise<void>((resolve, reject) => {
        tcpClient.bind(localAddress, (err: BusinessError) => {
          if (err) {
            console.error('[FileTransferSocketManager] bind 失败:', err);
            reject(err);
          } else {
            console.info('[FileTransferSocketManager] bind 成功');
            resolve();
          }
        });
      });
      
      // 连接远程服务器
      const remoteAddress: socket.NetAddress = {
        address: host,
        port: port
      };
      
      const connectOptions: socket.TCPConnectOptions = {
        address: remoteAddress,
        timeout: timeout
      };
      
      await tcpClient.connect(connectOptions);
      console.info(`[FileTransferSocketManager] 连接到 ${host}:${port} 成功`);
      
      // 生成连接 ID
      const connectionId = `conn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      
      // 保存连接信息
      const connectionInfo: TCPConnectionInfo = {
        connectionId,
        remoteIp: host,
        remotePort: port,
        socket: tcpClient,
        createdAt: Date.now(),
        lastActiveAt: Date.now()
      };
      
      this.connections.set(connectionId, connectionInfo);
      
      return connectionId;
    } catch (error) {
      console.error('[FileTransferSocketManager] 连接失败:', error);
      return null;
    }
  }

  /**
   * 发送数据
   * @param connectionId - 连接 ID
   * @param data - 要发送的数据
   * @returns 是否发送成功
   */
  async sendData(connectionId: string, data: ArrayBuffer): Promise<boolean> {
    const connection = this.connections.get(connectionId);
    if (!connection) {
      console.error(`[FileTransferSocketManager] 连接不存在：${connectionId}`);
      return false;
    }

    try {
      const sendOptions: socket.TCPSendOptions = {
        data: data
      };
      if (connection.socket ) {
        await connection.socket.send(sendOptions);
      } else {
        console.error('[FileTransferSocketManager] 不是有效的连接类型');
        return false;
      }
      
      // 更新最后活跃时间
      connection.lastActiveAt = Date.now();
      
      console.info(`[FileTransferSocketManager] 数据发送成功，connectionId=${connectionId}`);
      return true;
    } catch (error) {
      console.error('[FileTransferSocketManager] 数据发送失败:', error);
      return false;
    }
  }

  /**
   * 移除连接
   */
  private removeConnection(connectionId: string): void {
    this.connections.delete(connectionId);
    console.info(`[FileTransferSocketManager] 连接已移除：${connectionId}`);
  }

  /**
   * 关闭指定连接
   * @param connectionId - 连接 ID
   * @returns 是否关闭成功
   */
  async closeConnection(connectionId: string): Promise<boolean> {
    const connection = this.connections.get(connectionId);
    if (!connection) {
      console.warn(`[FileTransferSocketManager] 连接不存在：${connectionId}`);
      return false;
    }

    try {
      await connection.socket.close();
      this.removeConnection(connectionId);
      console.info(`[FileTransferSocketManager] 连接已关闭：${connectionId}`);
      return true;
    } catch (error) {
      console.error('[FileTransferSocketManager] 关闭连接失败:', error);
      return false;
    }
  }

  /**
   * 停止服务器
   * @returns 是否停止成功
   */
  async stopServer(): Promise<boolean> {
    if (!this.isListening || !this.serverSocket) {
      console.warn('[FileTransferSocketManager] 服务器未运行');
      return false;
    }

    try {
      // 关闭所有客户端连接
      const closePromises = Array.from(this.connections.keys()).map(id => 
        this.closeConnection(id)
      );
      await Promise.all(closePromises);
      
      // 关闭服务器
      await this.serverSocket.close();
      this.serverSocket = null;
      this.isListening = false;
      
      console.info('[FileTransferSocketManager] TCP 服务器已停止');
      return true;
    } catch (error) {
      console.error('[FileTransferSocketManager] 停止服务器失败:', error);
      return false;
    }
  }

  /**
   * 获取活动连接数
   */
  getActiveConnections(): number {
    return this.connections.size;
  }

  /**
   * 检查是否在监听
   */
  isServerListening(): boolean {
    return this.isListening;
  }

  /**
   * 获取监听端口
   */
  getListenPort(): number {
    return this.listenPort;
  }

  /**
   * 获取所有连接 ID 列表
   */
  getConnectionIds(): string[] {
    return Array.from(this.connections.keys());
  }
}
