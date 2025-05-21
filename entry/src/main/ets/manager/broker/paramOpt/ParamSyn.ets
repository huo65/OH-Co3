interface ParamMessage {
  param: number[];
}
class ParamSyn{
  public param:number[] = [1,1,1,1];
  parseParamMessage(message:string){
    const parsedMessage = JSON.parse(message) as ParamMessage;
    console.log("参数更新"+parsedMessage.param.toString())
    this.param = parsedMessage.param;
  }
  public getNewParam():number[]{
    return this.param;
  }

}
export const paramSyn = new ParamSyn();