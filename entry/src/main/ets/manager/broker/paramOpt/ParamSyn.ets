/**
 * 参数消息接口
 * 用于定义从消息中解析出的参数数据结构
 */
interface ParamMessage {
  param: number[];
}

/**
 * 参数同步类
 * 负责接收、解析和提供参数更新，维护当前生效的参数数组
 */
class ParamSyn{
  /**
   * 当前生效的参数数组
   * 默认初始值为 [1,1,1,1,1]
   */
  public param:number[] = [1,1,1,1,1];

  /**
   * 解析参数更新消息
   * 从JSON格式消息中提取参数数组并更新内部状态
   * @param message - 包含参数数组的JSON字符串
   */
  parseParamMessage(message:string){
    const parsedMessage = JSON.parse(message) as ParamMessage;
    console.info(`[HarmonyInference] [ParamSyn] 参数优化更新: [${parsedMessage.param.join(', ')}]`);
    this.param = parsedMessage.param;
  }

  /**
   * 获取最新参数
   * @returns 当前生效的参数数组副本
   */
  public getNewParam():number[]{
    return this.param;
  }

}
export const paramSyn = new ParamSyn();