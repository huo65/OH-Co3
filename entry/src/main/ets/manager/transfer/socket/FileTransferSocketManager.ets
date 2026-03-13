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
  /** 接收缓冲区 - 用于处理TCP粘包/拆包 */
  receiveBuffer: ArrayBuffer;
}

/**
 * 消息回调函数类型
 * 用于接收 TCP 消息通知
 */
export type MessageCallback = (connectionId: string, data: ArrayBuffer) => void;

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

  /** 消息回调映射（按任务 ID 注册） */
  private messageCallbacks: Map<string, MessageCallback> = new Map();

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
        lastActiveAt: Date.now(),
        receiveBuffer: new ArrayBuffer(0)
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
   * 设置消息处理器（服务器端连接）
   */
  private setupMessageHandler(
    connectionId: string,
    client: socket.TCPSocketConnection
  ): void {
    this.setupMessageListener(connectionId, client);
  }

  /**
   * 设置消息处理器（客户端连接）
   */
  private setupClientMessageHandler(
    connectionId: string,
    client: socket.TCPSocket
  ): void {
    this.setupMessageListener(connectionId, client);
  }

  /**
   * 通用的消息监听设置
   * 实现消息缓冲机制处理TCP粘包/拆包问题
   */
  private setupMessageListener(
    connectionId: string,
    client: socket.TCPSocket | socket.TCPSocketConnection
  ): void {
    interface MessageValue {
      message?: ArrayBuffer;
    }
    client.on('message', (value: MessageValue) => {
      // 更新最后活跃时间
      const conn = this.connections.get(connectionId);
      if (!conn) {
        console.warn(`[FileTransferSocketManager] 连接已不存在，connectionId=${connectionId}`);
        return;
      }
      conn.lastActiveAt = Date.now();

      // 获取消息数据
      const messageData = value.message;
      if (!messageData) {
        console.warn(`[FileTransferSocketManager] 收到空消息，connectionId=${connectionId}`);
        return;
      }

      // 将新数据追加到缓冲区
      const oldBuffer = conn.receiveBuffer;
      const newBuffer = new ArrayBuffer(oldBuffer.byteLength + messageData.byteLength);
      new Uint8Array(newBuffer).set(new Uint8Array(oldBuffer), 0);
      new Uint8Array(newBuffer).set(new Uint8Array(messageData), oldBuffer.byteLength);
      conn.receiveBuffer = newBuffer;

      console.info(`[FileTransferSocketManager] 收到数据，connectionId=${connectionId}, ` +
        `本次=${messageData.byteLength}字节, 缓冲区=${newBuffer.byteLength}字节`);

      // 尝试从缓冲区解析完整消息
      this.tryParseMessages(connectionId);
    });
  }

  /**
   * 尝试从缓冲区解析完整消息
   * 消息格式: [4字节长度(大端)][JSON头部数据]
   */
  private tryParseMessages(connectionId: string): void {
    const conn = this.connections.get(connectionId);
    if (!conn || conn.receiveBuffer.byteLength < 4) {
      return;
    }

    const buffer = conn.receiveBuffer;
    const bufferView = new DataView(buffer);

    // 读取消息头长度（大端序）
    const headerLength = bufferView.getInt32(0, false);

    // 验证消息头长度的合理性
    if (headerLength <= 0 || headerLength > 10 * 1024 * 1024) { // 最大10MB的JSON头
      console.error(`[FileTransferSocketManager] 无效的消息头长度: ${headerLength}，清空缓冲区`);
      conn.receiveBuffer = new ArrayBuffer(0);
      return;
    }

    // 检查是否已收到完整的消息
    const totalMessageLength = 4 + headerLength;
    if (buffer.byteLength < totalMessageLength) {
      console.info(`[FileTransferSocketManager] 消息不完整，等待更多数据。` +
        `需要=${totalMessageLength}字节, 当前=${buffer.byteLength}字节`);
      return;
    }

    // 提取一条完整消息
    const messageData = buffer.slice(0, totalMessageLength);

    // 更新缓冲区，移除已处理的消息
    const remainingLength = buffer.byteLength - totalMessageLength;
    if (remainingLength > 0) {
      conn.receiveBuffer = buffer.slice(totalMessageLength);
    } else {
      conn.receiveBuffer = new ArrayBuffer(0);
    }

    console.info(`[FileTransferSocketManager] 解析出完整消息，长度=${totalMessageLength}字节, ` +
      `剩余缓冲=${conn.receiveBuffer.byteLength}字节`);

    // 通知所有注册的回调
    this.messageCallbacks.forEach((callback, taskId) => {
      try {
        callback(connectionId, messageData);
      } catch (error) {
        console.error(`[FileTransferSocketManager] 消息回调执行失败，taskId=${taskId}:`, error);
      }
    });

    // 递归处理缓冲区中可能存在的更多消息
    if (conn.receiveBuffer.byteLength >= 4) {
      this.tryParseMessages(connectionId);
    }
  }

  /**
   * 注册消息回调
   * @param taskId - 任务 ID
   * @param callback - 消息回调函数
   */
  registerMessageCallback(taskId: string, callback: MessageCallback): void {
    this.messageCallbacks.set(taskId, callback);
    console.info(`[FileTransferSocketManager] 消息回调已注册，taskId=${taskId}`);
  }

  /**
   * 注销消息回调
   * @param taskId - 任务 ID
   */
  unregisterMessageCallback(taskId: string): void {
    this.messageCallbacks.delete(taskId);
    console.info(`[FileTransferSocketManager] 消息回调已注销，taskId=${taskId}`);
  }

  /**
   * 获取指定连接的 Socket 对象
   * @param connectionId - 连接 ID
   * @returns Socket 对象，不存在返回 null
   */
  getSocket(connectionId: string): socket.TCPSocket | socket.TCPSocketConnection | null {
    const connection = this.connections.get(connectionId);
    return connection ? connection.socket : null;
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
        lastActiveAt: Date.now(),
        receiveBuffer: new ArrayBuffer(0)
      };

      this.connections.set(connectionId, connectionInfo);

      // 设置消息接收处理（客户端也需要接收消息）
      this.setupClientMessageHandler(connectionId, tcpClient);

      // 设置关闭处理
      tcpClient.on('close', () => {
        console.info(`[FileTransferSocketManager] 客户端连接关闭：${connectionId}`);
        this.removeConnection(connectionId);
      });

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
