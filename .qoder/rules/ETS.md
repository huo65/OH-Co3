---
trigger: always_on
---
本项目为鸿蒙开发使用的语言为ETS（Enhanced TypeScript），作为鸿蒙专属的ArkTS语言核心实现，与标准TypeScript（TS）的语法差异主要体现在以下方面：

---

### 一、类型系统差异

1. **静态类型强制**  
   ETS完全禁用动态类型（如`any`/`unknown`），要求所有变量必须显式声明类型。例如：

   ```typescript
   // TS允许
   let data: any = fetchData(); 
   
   // ETS必须明确类型
   class FetchResult { value: string = "" }
   let data: FetchResult = fetchData(); 
   ```

2. **泛型限制**  
   ETS在UI组件中使用泛型时更严格，部分复杂泛型场景需重构代码。

---

**二、动态特性限制**

1. **对象操作限制**  
   ETS禁止动态修改对象属性（如`obj.newProp = 1`），要求通过`interface`或`class`明确定义对象结构。
2. **禁用解构赋值**  
   ETS不支持类似`const { a, b } = obj;`的语法，需通过传统属性访问实现。
3. **函数调用限制**  
   禁用`call`/`apply`/`bind`等动态改变`this`指向的方法，确保并发安全（如`@Sendable`对象不可变）。

---

**三、UI开发扩展**

1. **声明式UI语法**  
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

2. **内置状态管理**  
   支持`@Prop`、`@Link`等状态装饰器实现数据驱动UI更新，TS需依赖第三方库。

---

**四、编译与运行时**

1. **编译目标差异**  
   ETS编译为HarmonyOS字节码（ArkVM执行），TS编译为JavaScript。ETS的编译过程保留类型信息以优化性能。
2. **运行时限制**  
   ETS禁止访问浏览器/DOM API（如`document`），仅支持鸿蒙原生API（如`@kit.ArkUI`组件）。

---

**五、互操作性规则**

- **单向调用**：ETS可通过`import`调用TS导出的函数/类，但TS无法识别ETS的扩展语法（如装饰器UI）。
- **场景分工**：推荐ETS负责UI/系统能力调用，TS处理工具函数、网络请求等非UI逻辑。

---

**总结**：ETS通过增强静态类型、约束动态特性、扩展声明式UI能力，为鸿蒙应用提供高性能与安全保证，而TS更适用于通用业务逻辑开发。两者互补，共同构建完整的鸿蒙应用架构。