---
trigger: model_decision
description: 需要写ArkTS（.ets文件）代码的时候，需要严格遵守语法规则
---
本项目为鸿蒙开发使用的语言为ETS（Enhanced TypeScript），作为鸿蒙专属的ArkTS语言核心实现，与标准TypeScript（TS）的语法差异主要体现在以下方面：

---

## 一、类型系统差异

### 1.1 静态类型强制
ETS完全禁用动态类型（如`any`/`unknown`），要求所有变量必须显式声明类型。

```typescript
// ❌ TS允许但ETS禁止
let data: any = fetchData(); 
let value: unknown = getValue();

// ✅ ETS必须明确类型
class FetchResult { value: string = "" }
let data: FetchResult = fetchData(); 

// ✅ 使用Object替代unknown
function processValue(value: Object): void {
  if (value instanceof String) {
    const str: string = value.toString();
  }
}
```

### 1.2 泛型限制
ETS在UI组件中使用泛型时更严格，部分复杂泛型场景需重构代码。

---

## 二、不支持的语法特性清单

### 2.1 对象展开运算符（Spread Operator）
**错误代码：**
```typescript
// ❌ 禁止：对象展开运算符
const copy = { ...original };
const merged = { ...obj1, ...obj2 };
const updated = { ...obj, newProp: value };
```

**替代方案：**
```typescript
// ✅ 使用显式属性赋值
const copy: MyInterface = {
  prop1: original.prop1,
  prop2: original.prop2
};

// ✅ 使用Object.assign的替代方案
const merged: MyInterface = {
  prop1: obj1.prop1,
  prop2: obj1.prop2,
  prop3: obj2.prop3
};
```

### 2.2 解构赋值（Destructuring Assignment）
**错误代码：**
```typescript
// ❌ 禁止：解构赋值
const { a, b } = obj;
const { x, y, ...rest } = obj;
const [first, second] = array;
```

**替代方案：**
```typescript
// ✅ 使用显式属性访问
const a: TypeA = obj.a;
const b: TypeB = obj.b;

// ✅ 手动提取剩余属性
const rest: RestType = {
  prop1: obj.prop1,
  prop2: obj.prop2
};
```

### 2.3 keyof操作符与索引访问
**错误代码：**
```typescript
// ❌ 禁止：keyof操作符用于索引访问
function getValue(obj: MyInterface, key: keyof MyInterface): ValueType {
  return obj[key]; // 错误：索引访问不支持
}
```

**替代方案：**
```typescript
// ✅ 使用字符串类型和条件判断
function getValue(obj: MyInterface, key: string): ValueType | undefined {
  if (key === 'prop1') {
    return obj.prop1 as ValueType;
  } else if (key === 'prop2') {
    return obj.prop2 as ValueType;
  }
  return undefined;
}
```

### 2.4 Object.assign方法
**错误代码：**
```typescript
// ❌ 禁止：Object.assign
const copy = Object.assign({}, original);
const merged = Object.assign({}, obj1, obj2);
```

**替代方案：**
```typescript
// ✅ 显式属性复制
const copy: MyInterface = {
  prop1: original.prop1,
  prop2: original.prop2
};

// ✅ 合并多个对象
const merged: MyInterface = {
  prop1: obj1.prop1,
  prop2: obj1.prop2,
  prop3: obj2.prop3,
  prop4: obj2.prop4
};
```

### 2.5 内联对象字面量作为类型
**错误代码：**
```typescript
// ❌ 禁止：内联对象字面量作为类型声明
interface MyInterface {
  data: {
    field1: string;
    field2: number;
  };
}
```

**替代方案：**
```typescript
// ✅ 提取为独立接口
interface DataType {
  field1: string;
  field2: number;
}

interface MyInterface {
  data: DataType;
}

// ✅ 使用时显式声明类型
const data: DataType = {
  field1: 'value',
  field2: 123
};
```

### 2.6 无类型对象字面量
**错误代码：**
```typescript
// ❌ 禁止：无显式类型的对象字面量
this.emit(eventId, { protocol: 'TCP' });
return { error: message, errorCode: code };
```

**替代方案：**
```typescript
// ✅ 显式声明接口类型
interface EventData {
  protocol: string;
}

const data: EventData = { protocol: 'TCP' };
this.emit(eventId, data);

// ✅ 错误数据接口
interface ErrorData {
  error: string;
  errorCode?: string;
}

const errorData: ErrorData = { 
  error: message, 
  errorCode: code 
};
return errorData;
```

---

## 三、动态特性限制

### 3.1 对象操作限制
ETS禁止动态修改对象属性，要求通过`interface`或`class`明确定义对象结构。

```typescript
// ❌ 禁止：动态添加属性
const obj: MyInterface = { prop1: 'value' };
(obj as any).newProp = 123; // 禁止

// ✅ 正确：预定义所有属性
interface MyInterface {
  prop1: string;
  newProp?: number; // 可选属性
}

const obj: MyInterface = { 
  prop1: 'value',
  newProp: 123
};
```

### 3.2 函数调用限制
禁用`call`/`apply`/`bind`等动态改变`this`指向的方法。

```typescript
// ❌ 禁止：动态this绑定
function.myCall(thisArg, arg1, arg2);
function.myApply(thisArg, [arg1, arg2]);
const boundFunc = func.bind(thisArg);

// ✅ 正确：使用箭头函数或显式参数传递
const result = func(arg1, arg2);
```

---

## 四、类型声明规范

### 4.1 接口定义规范
```typescript
// ✅ 完整的接口定义
export interface TransferConfig {
  /** 超时时间（毫秒） */
  timeout?: number;
  /** 重试次数 */
  maxRetries?: number;
  /** 分块大小（字节） */
  chunkSize?: number;
  /** 文件信息 */
  fileInfo?: FileInfo;
  /** 额外协议参数 */
  protocolParams?: Record<string, Object>;
}
```

### 4.2 类型别名规范
```typescript
// ✅ 使用类型别名定义联合类型
export type TransferTaskState = 'pending' | 'connecting' | 'transferring' | 'completed' | 'failed' | 'cancelled';

// ✅ 回调函数类型
export type TransferNotifyCallback = (notifyInfo: TransferNotifyInfo) => Promise<void>;
```

### 4.3 枚举定义规范
```typescript
// ✅ 使用枚举定义固定值集合
export enum TransferState {
  IDLE = 'idle',
  CONNECTING = 'connecting',
  TRANSFERRING = 'transferring',
  COMPLETED = 'completed',
  FAILED = 'failed',
  CANCELLED = 'cancelled'
}
```

---

## 五、常见错误示例与解决方案

### 5.1 类型转换错误
**错误：**
```typescript
const fileData = await receiveFile(...);
const base64 = FileUtils.arrayBufferToBase64(fileData as ArrayBuffer);
```

**解决：**
```typescript
const result = await receiveFile(...);
if (result.success && result.data instanceof ArrayBuffer) {
  const base64 = FileUtils.arrayBufferToBase64(result.data);
}
```

### 5.2 事件监听参数类型不匹配
**错误：**
```typescript
emitter.once(eventId, (eventData) => { ... });
```

**解决：**
```typescript
emitter.once(eventId.toString(), (eventData: emitter.EventData) => {
  callback(eventData as TransferEventData);
});
```

### 5.3 可选属性处理
**错误：**
```typescript
interface MyInterface {
  data?: {
    field: string;
  };
}
// 直接访问可能为undefined的属性
const value = obj.data.field;
```

**解决：**
```typescript
interface DataType {
  field: string;
}

interface MyInterface {
  data?: DataType;
}

// 安全访问
if (obj.data !== undefined) {
  const value: string = obj.data.field;
}
```

---

## 六、UI开发扩展

### 6.1 声明式UI语法
ETS通过装饰器（如`@Component`、`@State`）实现声明式UI开发：

```typescript
@Entry
@Component
struct MyPage {
  @State message: string = "Hello";
  build() {
    Column() {
      Text(this.message).onClick(() => { this.message = "Clicked!" })
    }
  }
}
```

### 6.2 内置状态管理
支持`@Prop`、`@Link`等状态装饰器实现数据驱动UI更新。

---

## 七、编译与运行时

### 7.1 编译目标差异
ETS编译为HarmonyOS字节码（ArkVM执行），TS编译为JavaScript。ETS的编译过程保留类型信息以优化性能。

### 7.2 运行时限制
ETS禁止访问浏览器/DOM API（如`document`），仅支持鸿蒙原生API（如`@kit.ArkUI`组件）。

---

## 八、互操作性规则

- **单向调用**：ETS可通过`import`调用TS导出的函数/类，但TS无法识别ETS的扩展语法（如装饰器UI）。
- **场景分工**：推荐ETS负责UI/系统能力调用，TS处理工具函数、网络请求等非UI逻辑。

---

## 九、最佳实践总结

1. **始终显式声明类型**：避免类型推断，所有变量、参数、返回值都要有明确类型
2. **提前定义接口**：不要内联对象类型，提前提取为独立接口
3. **避免动态特性**：不使用`any`/`unknown`，不进行动态属性操作
4. **使用显式复制**：替代展开运算符和Object.assign
5. **安全访问属性**：对可选属性进行非空检查
6. **类型安全转换**：使用`instanceof`或类型守卫进行类型收窄

---

**总结**：ETS通过增强静态类型、约束动态特性、扩展声明式UI能力，为鸿蒙应用提供高性能与安全保证，而TS更适用于通用业务逻辑开发。两者互补，共同构建完整的鸿蒙应用架构。