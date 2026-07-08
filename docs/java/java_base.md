# java 基础
## java 类和对象

### 一句话秒答

类是对象的模板，用来描述一类事物的属性和行为；对象是类创建出来的具体实例。简单说，类是抽象的设计图，对象是根据设计图创建出来的真实个体。

### 3 句展开

类里通常包含成员变量、方法、构造方法，用来定义对象有什么数据、能做什么事情。对象通过 `new` 创建，每个对象都有自己的一份实例变量。面向对象编程就是把现实问题抽象成类，再通过对象之间的协作完成业务逻辑。

### 经典案例（代码）

```java
class User {
    String name;

    User(String name) {
        this.name = name;
    }
}

User u1 = new User("Alice");
User u2 = new User("Bob");
System.out.println(u1.name); // Alice
System.out.println(u2.name); // Bob
```

### 3 个高频坑

- 类本身不是对象，`new` 出来的实例才是对象。
- 成员变量属于对象，局部变量属于方法内部，生命周期和默认值都不一样。
- 构造方法不是普通方法，它没有返回值，主要用于创建对象时初始化状态。

### 2 个面试追问

- 类加载和对象创建是一回事吗？  
  不是，类加载是 JVM 把类信息加载进内存，对象创建是运行时根据类创建实例。
- 一个类可以创建多个对象吗？  
  可以，同一个类可以创建多个对象，每个对象的实例变量互不影响。

## 接口与抽象类的区别？

### 一句话秒答

抽象类主要用于抽取一类事物的共性，强调“是什么”；接口主要用于定义能力或规范，强调“能做什么”。Java 类只能继承一个抽象类，但可以实现多个接口，所以接口更适合做扩展能力，抽象类更适合做公共代码复用。

### 3 句展开

抽象类可以有成员变量、构造方法、普通方法和抽象方法，适合沉淀一组子类的公共状态和行为。接口默认更偏规范定义，Java 8 以后也可以有 `default` 方法和 `static` 方法，但核心目的仍然是定义能力。实际选择时，如果多个类有明显父子关系和公共代码，用抽象类；如果只是具备某种能力，用接口。

### 经典案例（代码）

```java
abstract class Animal {
    abstract void eat();

    void sleep() {
        System.out.println("sleep");
    }
}

interface Flyable {
    void fly();
}

class Bird extends Animal implements Flyable {
    public void eat() {
        System.out.println("eat");
    }

    public void fly() {
        System.out.println("fly");
    }
}
```

### 3 个高频坑

- 抽象类不能直接 `new`，必须通过子类实例化。
- 一个类只能 `extends` 一个类，但可以 `implements` 多个接口。
- 接口有默认方法不代表它等同于抽象类，接口仍然更偏能力约束，抽象类更偏模板和复用。
- 要点：接口强调外部契约和能力替换，通常不承载实例状态，适合多实现；抽象类强调共享骨架和默认实现，可以持有状态，但受单继承约束，适合稳定主线复用

### 2 个面试追问

- 接口可以有方法实现吗？  
  可以，Java 8 开始接口可以有 `default` 方法和 `static` 方法，但普通抽象方法仍然需要实现类去实现。
- 什么时候用抽象类，什么时候用接口？  
  有强父子关系和公共代码复用时用抽象类，只是定义能力或规范时用接口。

## Java 面向对象

Java 面向对象的四大特性是**封装、继承、多态和抽象**，它们共同构成了面向对象的设计基础。

**封装:**是把数据和方法封装在类中，对外隐藏内部实现细节，只提供安全的访问方式，从而提高安全性和可维护性。

**继承:**是子类复用父类的属性和方法，并可以在此基础上进行扩展，实现代码复用和层次化设计，但Java只支持单继承。

**多态:**是指同一父类引用指向不同子类对象时，调用相同方法会表现出不同的行为，本质是通过方法重写实现运行时动态绑定，从而提升系统的扩展性和灵活性。

**抽象:**是对共性行为的提取，通过抽象类或接口定义统一规范，隐藏实现细节，让使用者只关注“做什么”而不关心“怎么做”，从而降低系统复杂度。

一句话补充版：

这四者的核心思想分别是：封装提高安全性，继承提高复用性，多态提高扩展性，抽象降低复杂度


## 重载|重写

| 对比点  | 重载 Overload | 重写 Override |
| ---- | ----------- | ----------- |
| 关系   | 同一个类        | 子类与父类       |
| 方法名  | 必须相同        | 必须相同        |
| 参数   | 必须不同        | 必须相同        |
| 返回值  | 可不同         | 基本相同/协变     |
| 发生阶段 | 编译期         | 运行期         |
| 作用   | 提供多种调用方式    | 改变行为        |
| 多态性  | 编译多态        | 运行多态        |

## 里氏替换原则（LSP） 继承的本质
- 定义：凡是父类能出现的地方，子类都应该可以替换进去，且程序语义不被破坏
- 这不是语法规则，而是行为契约

## a = a + b 与 a += b 的区别

byte / short / char 参与运算时，会自动提升为 int

所以两个整型相加，结果至少是 int 类型

```java
byte a = 1;
byte b = 2;
byte c = a + b; // 编译错误 a + b 已经提升为 int
```

## Java 基本数据类型（8种）

### 四类八种
| 类型 | 关键字     | 占用  | 默认值      | 最大值                                 |
| -- | ------- | --- | -------- | ----------------------------------- |
| 整型 | byte    | 1字节 | 0        | 127（2^7 - 1）                        |
|    | short   | 2字节 | 0        | 32767（2^15 - 1）                     |
|    | int     | 4字节 | 0        | 2,147,483,647（2^31 - 1）             |
|    | long    | 8字节 | 0L       | 9,223,372,036,854,775,807（2^63 - 1） |
| 浮点 | float   | 4字节 | 0.0f     | ±3.4e38（约）                          |
|    | double  | 8字节 | 0.0d     | ±1.7e308（约）                         |
| 字符 | char    | 2字节 | '\u0000' | 65535（Unicode 0~65535）              |
| 布尔 | boolean | 1位  | false    | true / false（无严格数值范围）               |


### 类型提升
- 运算时自动向“更大类型”提升 byte / short / char → int → long → float → double
- 类型运算统一变 int
- 混合类型按“最大类型
```java
byte + byte → int
short + short → int
char + char → int

byte a = 1;
byte b = 2;
byte c = a + b; // 编译错误
byte c = (byte)(a + b);

int + long → long
int + float → float
long + double → double

```

> 为什么要提升 :防止溢出,统一 JVM 运算体系（默认 int 运算模型）

### 自动装箱 & 拆箱

| 名称 | 含义         |
| -- | ---------- |
| 装箱 | 基本类型 → 包装类 |
| 拆箱 | 包装类 → 基本类型 |

| 基本类型    | 包装类       |
| ------- | --------- |
| int     | Integer   |
| long    | Long      |
| double  | Double    |
| char    | Character |
| boolean | Boolean   |

### 高频坑
```java

Integer a = 100;
Integer b = 100;
System.out.println(a == b); // true（缓存）

Integer x = 200;
Integer y = 200;
System.out.println(x == y); // false

```
## Integer 缓存机制
-128 ~ 127

所以
- 小范围：复用对象
- 大范围：新对象

##  高频面试总结（秒答版）

Java 基本数据类型有 8 种，包括整型、浮点型、字符型和布尔型。

在表达式运算中，byte、short、char 会自动提升为 int，小于 int 的运算结果默认是 int。

如果参与混合运算，会向更高类型提升，遵循 long → float → double 的顺序。

Java 5 引入自动装箱和拆箱机制，实现基本类型与包装类之间的自动转换，本质是编译器自动调用 valueOf 和 xxxValue 方法。


## 基本类型 vs 包装类
| 对比点      | 基本类型      | 包装类     |
| -------- | --------- | ------- |
| 存储位置     | 栈         | 堆       |
| 是否对象     | ❌         | ✅       |
| 默认值      | 0 / false | null    |
| 是否可为null | ❌         | ✅       |
| 用途       | 计算        | 集合 / 泛型 |

```java
Integer a = 10;  // 装箱
int b = a;       // 拆箱

//空指针
Integer a = null;
int b = a; // NullPointerException
```
## == vs equals 区别

### 面试精简回答

`==` 比较的是值还是地址，要分类型来看。基本类型用 `==` 比较的是值，引用类型用 `==` 比较的是对象地址。

`equals()` 主要用于引用类型比较“内容是否相等”，但前提是这个类重写了 `equals()`。

所以面试里可以直接答：基本类型 `==` 比值，引用类型 `==` 比地址，内容比较通常看 `equals()`。

### 核心区别

| 对比点 | `==` | `equals()` |
| --- | --- | --- |
| 基本类型 | 比较值 | 不适用 |
| 引用类型 | 比较对象地址 | 默认比较地址，重写后通常比较内容 |
| 是否可重写 | 不可 | 可以 |
| 常见用途 | 判空、同一对象判断、基本类型比较 | 字符串、包装类、自定义对象内容比较 |

### 经典案例

```java
int a = 10;
int b = 10;
System.out.println(a == b); // true

String s1 = "abc";
String s2 = "abc";
System.out.println(s1 == s2); // true，常量池
System.out.println(s1.equals(s2)); // true

String s3 = new String("abc");
String s4 = new String("abc");
System.out.println(s3 == s4); // false
System.out.println(s3.equals(s4)); // true
```

### 高频坑

- `Object` 默认的 `equals()` 本质也是比较地址，所以不重写时和 `==` 差别不大。
- `Integer`、`Long` 等包装类有缓存机制，小值范围内用 `==` 可能是 `true`，大值就不一定。
- 自定义类如果只重写 `equals()` 不重写 `hashCode()`，放进 `HashSet`、`HashMap` 会出问题。
- 调用 `str.equals("abc")` 时，如果 `str` 为 `null` 会抛空指针，更稳妥的是 `"abc".equals(str)`。

### 一句话秒答版

基本类型 `==` 比值，引用类型 `==` 比地址；`equals()` 一般比内容，但具体要看类有没有重写。

# static 关键字作用，this 可以使用吗

### 面试精简回答

`static` 表示成员属于类本身，而不是属于某个具体对象。静态变量、静态方法、静态代码块都随着类加载而存在，可以通过类名直接访问。`static` 方法里不能直接使用 `this`，因为 `this` 代表当前对象，而静态方法调用时可以没有对象。

### 核心区别

| 对比点 | static 成员 | 普通成员 |
| --- | --- | --- |
| 归属 | 类 | 对象 |
| 访问方式 | 类名直接访问 | 需要对象访问 |
| 生命周期 | 类加载时存在 | 对象创建后存在 |
| 是否能直接用 this | 不能 | 可以 |

### 经典案例

```java
class User {
    static int count = 0;
    String name;

    static void printCount() {
        System.out.println(count);
        // System.out.println(this.name); // 编译错误
    }

    void printName() {
        System.out.println(this.name);
    }
}
```

### 高频坑

- 静态方法不能直接访问普通成员变量，因为普通成员变量依赖对象存在。
- `static` 变量是类共享的一份数据，不是每个对象各自一份。
- 静态方法可以被子类定义同名方法，但这不是重写，而是隐藏，不体现运行时多态。
- `this` 只能用于实例方法或构造方法，不能用于静态方法或静态代码块。

### 一句话秒答版

`static` 属于类，`this` 属于对象；静态上下文没有当前对象，所以不能直接使用 `this`。

# final / finally / finalize 区别

### 一句话秒答

`final` 是修饰符，表示不可变、不可继承或不可重写；`finally` 是异常处理里的代码块，通常用于释放资源；`finalize()` 是对象被垃圾回收前可能调用的方法，已经不推荐使用。

### 3 句展开

`final` 修饰变量时表示只能赋值一次，修饰方法表示不能被重写，修饰类表示不能被继承。`finally` 一般和 `try-catch` 搭配，用来执行必须收尾的逻辑，比如关闭资源。`finalize()` 依赖 GC 触发，执行时机不确定，现代 Java 里不要用它做资源释放。

### 经典案例（代码）

```java
class Person {
    String name;

    Person(String name) {
        this.name = name;
    }
}

public class Test {
    public static void main(String[] args) {
        final Person p = new Person("Alice");

        // p = new Person("Bob"); // 编译错误，引用不能改变

        p.name = "Bob"; // 可以修改，对象内部状态改变

        System.out.println(p.name); // Bob
    }
}
```

### 3 个高频坑

- `final` 修饰引用类型时，引用地址不能变，但对象内部状态仍然可能被修改。
- `finally` 不一定绝对执行，比如 JVM 直接退出、线程被强制终止、机器断电。
- 不要依赖 `finalize()` 释放文件、连接等资源，优先用 `try-with-resources`。

### 2 个面试追问

- `final`、`finally`、`finalize()` 分别属于语法、异常处理还是 GC 机制？  
  `final` 是语法修饰符，`finally` 是异常处理机制，`finalize()` 和对象回收相关但已不推荐使用。
- `finally` 里写 `return` 会发生什么？  
  `finally` 的 `return` 会覆盖 `try` 或 `catch` 里的返回结果，所以实际开发中不建议这样写。

# String / StringBuilder / StringBuffer 区别

### 一句话秒答

`String` 是不可变字符串，每次修改都会产生新对象；`StringBuilder` 是可变字符串，性能高但线程不安全；`StringBuffer` 也是可变字符串，方法加了同步，线程安全但性能相对低。

### 3 句展开

少量字符串拼接可以直接用 `String`，代码最清晰。大量循环拼接优先用 `StringBuilder`，避免频繁创建对象。多线程共享同一个字符串缓冲区时才考虑 `StringBuffer`，但实际开发中这种场景不多。

### 经典案例（代码）

```java
String s = "a";
s += "b"; // 产生新字符串对象

StringBuilder builder = new StringBuilder();
builder.append("a");
builder.append("b");
System.out.println(builder.toString()); // ab
```

### 3 个高频坑

- 循环里使用 `str += value` 可能产生大量临时对象，性能差。
- `String` 不可变不是不能重新赋值，而是原对象内容不能变。
- `StringBuffer` 线程安全只保证单个方法同步，不代表一整段复合逻辑天然安全。

### 2 个面试追问

- 为什么 `String` 要设计成不可变？  
  主要是为了安全、线程安全、字符串常量池复用，以及让 `hashCode()` 缓存更稳定。
- `StringBuilder` 默认容量不够时会发生什么？  
  会自动扩容，底层创建更大的字符数组并复制旧内容，所以大量拼接时可以提前指定容量。

# List / Set / Map 区别

### 一句话秒答

`List` 存一组有序、可重复的元素；`Set` 存一组不重复的元素；`Map` 存键值对，通过 key 找 value，key 不能重复。

### 3 句展开

需要按插入顺序或下标访问时用 `List`，常见实现是 `ArrayList`、`LinkedList`。需要去重时用 `Set`，常见实现是 `HashSet`、`LinkedHashSet`、`TreeSet`。需要按 key 查询数据时用 `Map`，常见实现是 `HashMap`、`LinkedHashMap`、`TreeMap`。

### 经典案例（代码）

```java
List<String> list = new ArrayList<>();
list.add("a");
list.add("a"); // 允许重复

Set<String> set = new HashSet<>();
set.add("a");
set.add("a"); // 自动去重

Map<String, Integer> map = new HashMap<>();
map.put("age", 18);
map.put("age", 20); // 覆盖旧值
```

### 3 个高频坑

- `HashSet` 判断重复依赖 `hashCode()` 和 `equals()`，自定义对象必须正确重写。
- `HashMap` 的 key 不能重复，重复 put 同一个 key 会覆盖旧 value。
- `ArrayList` 查询快但中间插入删除成本高，`LinkedList` 不是所有场景都比 `ArrayList` 好。

### 2 个面试追问

- `ArrayList` 和 `LinkedList` 怎么选？  
  大多数场景优先用 `ArrayList`；只有频繁在链表中间插入删除且已持有节点位置时，才考虑 `LinkedList`。
- `HashMap`、`LinkedHashMap`、`TreeMap` 有什么区别？  
  `HashMap` 无序，`LinkedHashMap` 保持插入顺序，`TreeMap` 按 key 排序。

#  map 存储结构和扩容机制

### 一句话秒答

Java 面试里问 `Map` 存储结构，通常默认问的是 `HashMap`。`HashMap` 底层是数组 + 链表 + 红黑树，先根据 key 的 hash 定位数组下标，冲突时用链表或红黑树存储。扩容一般发生在元素数量超过 `容量 * 负载因子` 时，默认负载因子是 `0.75`，扩容后容量通常变为原来的 2 倍。

### 3 句展开

`HashMap` 的数组叫桶数组，每个桶里可能是单个节点、链表，或者红黑树。JDK 8 之后，当同一个桶里的链表长度达到 8，并且数组容量至少 64 时，链表会转成红黑树，降低极端 hash 冲突下的查询成本。扩容时会创建更大的数组，并把旧数据重新分布到新数组中，所以频繁扩容会影响性能。

### 经典案例（代码）

```java
Map<String, Integer> map = new HashMap<>(16, 0.75f);
map.put("a", 1);
map.put("b", 2);

Integer value = map.get("a"); // 根据 key 的 hash 定位桶
System.out.println(value); // 1
```

### 3 个高频坑

- `HashMap` 不是线程安全的，多线程并发写可能出现数据覆盖或结构异常。
- 负载因子不是越小越好，太小会浪费空间，太大又会增加 hash 冲突。
- 链表转红黑树不是只看链表长度，还要求数组容量至少达到 64。

### 2 个面试追问

- 为什么 `HashMap` 容量通常是 2 的幂？  
  因为可以用 `(n - 1) & hash` 快速计算下标，比取模更高效，也更利于扩容时重新分布。
- `HashMap` 扩容为什么性能开销大？  
  因为要创建新数组，并把旧数组里的节点迁移或重新分布到新位置。

# this() 和 super() 在构造方法中的区别

### 一句话秒答

`this()` 用来调用本类的其他构造方法，`super()` 用来调用父类的构造方法。它们都只能写在构造方法的第一行，所以同一个构造方法里不能同时直接写 `this()` 和 `super()`。

### 3 句展开

`this()` 常用于构造方法重载时复用初始化逻辑，避免重复代码。`super()` 用于先完成父类部分的初始化，如果子类构造方法没有显式写，编译器会默认插入无参 `super()`。如果父类没有无参构造方法，子类就必须手动调用父类已有的有参构造方法。

### 经典案例（代码）

```java
class Parent {
    Parent(String name) {
        System.out.println("parent: " + name);
    }
}

class Child extends Parent {
    Child() {
        this("Tom"); // 调用本类另一个构造方法
    }

    Child(String name) {
        super(name); // 调用父类构造方法，必须放第一行
        System.out.println("child: " + name);
    }
}
```

### 3 个高频坑

- `this()` 和 `super()` 都必须是构造方法里的第一条语句。
- 同一个构造方法里不能同时直接调用 `this()` 和 `super()`。
- 父类没有无参构造方法时，子类构造方法必须显式调用 `super(参数)`。

### 2 个面试追问

- 为什么 `this()` 和 `super()` 必须放第一行？  
  因为对象初始化必须先确定构造链，父类初始化和构造委托都要在当前构造逻辑执行前完成。
- 子类构造方法默认一定会调用父类构造方法吗？  
  会，如果没有显式写 `super()` 或 `this()`，编译器默认插入无参 `super()`。

# Java 基础高频补充

## String 为什么不可变

### 一句话秒答

`String` 不可变是为了安全、线程安全、常量池复用和哈希缓存稳定。不可变后，同一个字符串对象可以被多个地方共享，不用担心内容被改掉。

### 3 句展开

字符串经常作为参数、文件路径、网络地址、Map 的 key 使用，如果可变会有安全风险。不可变对象天然更容易做到线程安全，也方便字符串常量池复用。`String` 的 `hashCode()` 可以缓存，作为 `HashMap` 的 key 时更稳定。

### 经典案例（代码）

```java
String s = "abc";
s.toUpperCase();
System.out.println(s); // abc，原对象没变

String upper = s.toUpperCase();
System.out.println(upper); // ABC，新对象
```

### 高频坑

- `String` 不可变不是变量不能重新赋值，而是字符串对象内容不能变。
- `s += "x"` 看起来是修改，实际是创建新字符串再让变量指向它。
- `StringBuilder` 可变，不能和 `String` 的不可变性混为一谈。

### 面试追问

- `String` 适合作为 `HashMap` 的 key 吗？  
  适合，因为不可变且 `hashCode()` 稳定。
- 字符串拼接一定会创建很多对象吗？  
  不一定，编译期常量会被优化，循环运行期拼接更容易产生临时对象。

## new String("abc") 创建几个对象

### 一句话秒答

通常说最多创建两个对象：一个是字符串常量池里的 `"abc"`，一个是堆里的 `new String` 对象。如果常量池里已经有 `"abc"`，那就只创建堆里的那个对象。

### 3 句展开

字面量 `"abc"` 会进入字符串常量池。`new String("abc")` 会在堆上创建一个新的 `String` 对象。变量最终引用的是堆里的新对象，不是常量池对象。

### 经典案例（代码）

```java
String a = "abc";
String b = new String("abc");

System.out.println(a == b); // false
System.out.println(a.equals(b)); // true
```

### 高频坑

- 不能死背“一定两个”，因为常量池里可能已经存在字面量。
- `==` 比较引用地址，`equals()` 比较内容。
- `intern()` 会尝试返回常量池中的字符串引用。

### 面试追问

- `intern()` 是什么？  
  它会返回字符串在常量池中的引用。
- `new String("abc").intern() == "abc"` 结果是什么？  
  通常是 `true`，因为两边都指向常量池里的字符串。

## equals() 和 hashCode() 为什么要一起重写

### 一句话秒答

因为哈希集合和哈希表会先用 `hashCode()` 定位桶，再用 `equals()` 判断是否相等。只重写 `equals()` 不重写 `hashCode()`，可能导致逻辑相等的对象放进不同桶里，查找和去重都会出问题。

### 3 句展开

`equals()` 判断两个对象是否相等，`hashCode()` 用于哈希定位。Java 约定：两个对象 `equals()` 为 `true`，它们的 `hashCode()` 必须相同。`HashMap`、`HashSet` 都依赖这个约定。

### 经典案例（代码）

```java
class User {
    String name;

    User(String name) {
        this.name = name;
    }

    public boolean equals(Object obj) {
        return obj instanceof User && name.equals(((User) obj).name);
    }
}

Set<User> set = new HashSet<>();
set.add(new User("Tom"));
set.add(new User("Tom"));
System.out.println(set.size()); // 可能是 2，因为 hashCode 没重写
```

### 高频坑

- `equals()` 相等，`hashCode()` 必须相等。
- `hashCode()` 相等，`equals()` 不一定相等，可能只是哈希冲突。
- 自定义对象作为 `HashMap` key 时尤其要重写两者。

### 面试追问

- 只重写 `hashCode()` 不重写 `equals()` 行吗？  
  不行，最终相等判断还是依赖 `equals()`。
- 为什么哈希冲突后还要用 `equals()`？  
  因为不同对象可能有相同哈希值，需要进一步判断真实相等。

## HashMap 为什么线程不安全

### 一句话秒答

`HashMap` 没有同步控制，多线程同时 `put`、扩容或修改同一个桶时，可能出现数据覆盖、丢失更新或结构异常。并发场景应该用 `ConcurrentHashMap`。

### 3 句展开

`HashMap` 的数组、链表、红黑树结构都不是为并发写设计的。多个线程同时修改同一个位置时，没有锁或 CAS 保证一致性。读多写少也不能简单认为安全，因为写入期间读到的结构可能不稳定。

### 经典案例（代码）

```java
Map<Integer, Integer> map = new HashMap<>();

new Thread(() -> map.put(1, 1)).start();
new Thread(() -> map.put(1, 2)).start();

// 最终结果不可控，不能依赖 HashMap 做并发写
```

### 高频坑

- `HashMap` 可以读，不代表并发读写安全。
- `Collections.synchronizedMap()` 是粗粒度同步，不等同于 `ConcurrentHashMap`。
- 并发场景优先用 `ConcurrentHashMap`，不要自己给所有操作随手加锁。

### 面试追问

- `ConcurrentHashMap` 为什么更适合并发？  
  它内部做了并发控制，能在保证线程安全的同时减少锁竞争。
- `Hashtable` 线程安全吗？  
  是线程安全的，但方法级同步太重，现代并发场景一般不用它。

## HashMap / Hashtable / ConcurrentHashMap 区别

### 一句话秒答

`HashMap` 线程不安全，允许一个 `null` key 和多个 `null` value；`Hashtable` 线程安全但效率低，不允许 `null`；`ConcurrentHashMap` 线程安全且并发性能更好，是并发场景首选。

### 3 句展开

`HashMap` 适合单线程或外部已保证同步的场景。`Hashtable` 是早期集合类，很多方法直接加 `synchronized`。`ConcurrentHashMap` 针对并发访问设计，读写并发能力更好。

### 经典案例（代码）

```java
Map<String, Integer> map = new HashMap<>();
map.put(null, 1); // 可以

Map<String, Integer> concurrentMap = new ConcurrentHashMap<>();
// concurrentMap.put(null, 1); // 抛 NullPointerException
```

### 高频坑

- `ConcurrentHashMap` 不允许 `null` key 和 `null` value。
- `Hashtable` 虽然线程安全，但不是现代并发首选。
- `HashMap` 单线程性能好，但并发写不安全。

### 面试追问

- 为什么 `ConcurrentHashMap` 不允许 `null`？  
  为了避免并发场景下无法区分 key 不存在还是 value 本身为 `null`。
- 多线程下可以用 `HashMap` 加锁吗？  
  可以，但容易锁粒度粗或漏锁，通常不如直接用并发容器。

## ArrayList 和 LinkedList 区别

### 一句话秒答

`ArrayList` 底层是数组，随机访问快；`LinkedList` 底层是双向链表，理论上插入删除节点快。实际开发大多数场景优先用 `ArrayList`。

### 3 句展开

`ArrayList` 通过下标访问是 O(1)，但中间插入删除需要移动元素。`LinkedList` 查找指定位置要遍历，随机访问慢。除非频繁在已知节点附近插入删除，否则 `LinkedList` 不一定更快。

### 经典案例（代码）

```java
List<String> list = new ArrayList<>();
list.add("a");
list.add("b");
System.out.println(list.get(1)); // b，下标访问方便
```

### 高频坑

- 不要简单说 `LinkedList` 增删一定快。
- `ArrayList` 扩容会复制数组，有成本。
- 只按下标访问或遍历时，通常 `ArrayList` 更合适。

### 面试追问

- `ArrayList` 默认容量是多少？  
  JDK 8 以后默认空数组，第一次添加元素时通常扩到 10。
- `LinkedList` 还能当队列用吗？  
  可以，但队列场景通常优先考虑 `ArrayDeque`。

## ArrayList 扩容机制

### 一句话秒答

`ArrayList` 底层是数组，容量不够时会扩容，通常扩为原来的 1.5 倍左右。扩容会创建新数组并复制旧元素，所以频繁扩容有性能成本。

### 3 句展开

`ArrayList` 添加元素时会检查容量。容量不足就创建更大的数组，再把旧数组元素复制过去。如果能预估元素数量，可以用构造方法指定初始容量。

### 经典案例（代码）

```java
List<Integer> list = new ArrayList<>(1000);
for (int i = 0; i < 1000; i++) {
    list.add(i);
}
```

### 高频坑

- `size` 是元素个数，`capacity` 是底层数组容量，不是一回事。
- 扩容不是每次 `add` 都发生，只有容量不够才发生。
- 大量添加元素时，提前指定容量可以减少扩容次数。

### 面试追问

- 扩容为什么耗时？  
  因为要创建新数组并复制旧元素。
- `ArrayList` 删除元素会自动缩容吗？  
  通常不会自动缩容，需要手动调用 `trimToSize()`。

## fail-fast 和 fail-safe 区别

### 一句话秒答

`fail-fast` 是遍历时发现集合被并发修改就快速失败，常见于 `ArrayList`、`HashMap` 的迭代器；`fail-safe` 通常遍历副本，不会直接抛并发修改异常，常见于 `CopyOnWriteArrayList`。

### 3 句展开

`fail-fast` 依赖修改次数检查，发现结构性修改就抛 `ConcurrentModificationException`。`fail-safe` 遍历时不直接操作原集合结构，安全但可能读到旧数据。二者不是绝对线程安全的同义词，只是迭代策略不同。

### 经典案例（代码）

```java
List<String> list = new ArrayList<>(List.of("a", "b"));
for (String item : list) {
    list.remove(item); // 可能抛 ConcurrentModificationException
}
```

### 高频坑

- `fail-fast` 不保证一定抛异常，只是尽力检测。
- `ConcurrentModificationException` 不只在多线程出现，单线程错误删除也会出现。
- `fail-safe` 可能读到旧数据，不代表没有代价。

### 面试追问

- 怎么安全删除遍历中的元素？  
  用 `Iterator.remove()`。
- `CopyOnWriteArrayList` 适合什么场景？  
  适合读多写少场景，写入会复制数组。

## Iterator 遍历时为什么不能直接 list.remove()

### 一句话秒答

因为增强 for 底层用的是迭代器，直接调用 `list.remove()` 会绕过迭代器的修改记录，导致迭代器发现集合结构被外部改了，从而抛 `ConcurrentModificationException`。

### 3 句展开

迭代器内部维护预期修改次数。集合直接删除会改变实际修改次数，但迭代器不知道这次删除是安全的。用 `Iterator.remove()` 可以同步迭代器状态。

### 经典案例（代码）

```java
Iterator<String> it = list.iterator();
while (it.hasNext()) {
    if ("a".equals(it.next())) {
        it.remove(); // 正确
    }
}
```

### 高频坑

- 增强 for 里直接 `remove` 容易出错。
- 普通 for 正序删除也可能漏删元素。
- 删除多个元素时可以优先用 `removeIf()`。

### 面试追问

- `removeIf()` 底层也是遍历吗？  
  是，但由集合实现负责处理删除逻辑。
- 为什么普通 for 删除会漏元素？  
  删除后后续元素前移，索引继续递增会跳过一个位置。

## Comparable 和 Comparator 区别

### 一句话秒答

`Comparable` 是类自己定义自然排序，重写 `compareTo()`；`Comparator` 是外部比较器，重写 `compare()`。一个类只能有一种自然排序，但可以配多个比较器。

### 3 句展开

如果排序规则是对象天然规则，比如年龄升序，可以实现 `Comparable`。如果不同场景需要不同排序，比如按年龄、按姓名，就用 `Comparator`。`TreeSet`、`TreeMap`、`Collections.sort()` 都常用它们。

### 经典案例（代码）

```java
List<User> users = new ArrayList<>();
users.sort(Comparator.comparingInt(user -> user.age));
```

### 高频坑

- `compare()` 返回 0 会被有些集合认为是重复元素。
- 比较逻辑要满足自反性、传递性和一致性。
- `TreeSet` 去重依据比较结果，不只看 `equals()`。

### 面试追问

- `TreeSet` 如何判断重复？  
  主要看比较器结果是否为 0。
- 多字段排序怎么写？  
  可以用 `thenComparing()` 链式组合。

## 面向对象四大特性怎么理解

### 一句话秒答

封装隐藏细节，继承复用能力，多态提升扩展，抽象提取共性。它们一起让代码更安全、更复用、更易扩展。

### 3 句展开

封装通过访问控制保护内部状态。继承让子类复用父类能力，但要遵守里氏替换原则。多态让同一接口在不同实现上表现出不同行为，抽象让使用者关注规范而不是细节。

### 经典案例（代码）

```java
Animal animal = new Dog();
animal.eat(); // 调用 Dog 重写后的 eat()
```

### 高频坑

- 继承不是越多越好，滥用会导致强耦合。
- 多态针对方法，不针对成员变量。
- 抽象类和接口都能表达抽象，但侧重点不同。

### 面试追问

- 多态的前提是什么？  
  继承或实现、方法重写、父类引用指向子类对象。
- 封装只是 private 吗？  
  不只是，核心是隐藏内部实现并提供受控访问。

## 多态的实现原理

### 一句话秒答

Java 多态的核心是动态绑定，运行时根据对象的实际类型决定调用哪个重写方法。父类引用指向子类对象时，方法调用看实际对象。

### 3 句展开

编译期只检查引用类型里有没有这个方法。运行期通过实际对象的方法表找到真正执行的方法。静态方法、私有方法、构造方法不参与这种运行时多态。

### 经典案例（代码）

```java
Animal a = new Dog();
a.eat(); // 执行 Dog 的 eat()
```

### 高频坑

- 成员变量不参与多态，变量看引用类型。
- 静态方法不是真正重写，是隐藏。
- private 方法不能被重写。

### 面试追问

- 重载是多态吗？  
  是编译期多态，重写是运行期多态。
- 构造方法能多态吗？  
  不能，构造方法不能被重写。

## 父类引用指向子类对象时变量和方法看谁

### 一句话秒答

成员方法看实际对象，成员变量看引用类型。也就是方法动态绑定，变量静态绑定。

### 3 句展开

父类引用能调用的方法范围由父类类型决定。真正执行哪个重写方法由子类对象决定。字段没有重写概念，同名字段只是隐藏。

### 经典案例（代码）

```java
class Parent {
    String name = "parent";
    void print() { System.out.println("parent"); }
}

class Child extends Parent {
    String name = "child";
    void print() { System.out.println("child"); }
}

Parent p = new Child();
System.out.println(p.name); // parent
p.print(); // child
```

### 高频坑

- 字段没有多态。
- 方法能否调用先看引用类型。
- 强转只能在真实对象类型兼容时使用。

### 面试追问

- 为什么 `p.name` 是父类的？  
  因为成员变量在编译期按引用类型绑定。
- 如果子类新增方法父类没有，能直接调用吗？  
  不能，需要向下转型且类型真实兼容。

## 构造方法能不能被重写

### 一句话秒答

构造方法不能被重写，因为构造方法不被继承。子类只能通过 `super()` 调用父类构造方法。

### 3 句展开

重写的前提是子类继承到父类方法。构造方法名称必须和类名一致，天然不能被子类继承。子类创建对象时会先完成父类构造逻辑。

### 经典案例（代码）

```java
class Parent {
    Parent() {}
}

class Child extends Parent {
    Child() {
        super();
    }
}
```

### 高频坑

- 构造方法可以重载，不能重写。
- 构造方法没有返回值，写了 `void` 就变普通方法。
- 子类构造方法默认会调用父类无参构造。

### 面试追问

- 父类没有无参构造怎么办？  
  子类必须显式调用父类有参构造。
- 构造方法可以是 private 吗？  
  可以，常用于单例或禁止外部创建对象。

## 抽象类能不能有构造方法

### 一句话秒答

抽象类可以有构造方法，但不能直接 `new`。它的构造方法会在子类创建对象时被调用，用于初始化父类部分。

### 3 句展开

抽象类虽然不能实例化，但它仍然可以有成员变量和初始化逻辑。子类构造时必须先构造父类部分。抽象类构造方法常用于初始化公共状态。

### 经典案例（代码）

```java
abstract class Base {
    Base() {
        System.out.println("base init");
    }
}

class Sub extends Base {
    Sub() {
        System.out.println("sub init");
    }
}
```

### 高频坑

- 有构造方法不代表能直接实例化。
- 抽象类构造方法不能是抽象的。
- 子类初始化一定会先走父类构造链。

### 面试追问

- 接口有构造方法吗？  
  没有，接口不能保存实例构造状态。
- 抽象类适合放什么？  
  公共状态、公共方法、模板逻辑。

## 接口里能不能有变量

### 一句话秒答

接口里可以定义变量，但默认都是 `public static final` 常量。接口不能定义普通实例变量。

### 3 句展开

接口主要定义规范，不保存对象状态。接口中的字段默认是公共静态常量，即使不写修饰符也是这样。如果需要实例状态，通常用抽象类。

### 经典案例（代码）

```java
interface Config {
    int TIMEOUT = 3; // public static final
}
```

### 高频坑

- 接口变量必须初始化。
- 接口变量不是实例变量。
- 实现类不能修改接口常量。

### 面试追问

- 接口方法默认是什么修饰？  
  普通抽象方法默认是 `public abstract`。
- 接口能有私有方法吗？  
  Java 9 开始接口可以有 private 方法辅助默认方法复用。

## 接口默认方法冲突怎么办

### 一句话秒答

如果一个类实现多个接口，而多个接口有相同的默认方法，实现类必须重写该方法，明确选择自己的实现。

### 3 句展开

Java 不允许默认方法冲突时自动猜测调用谁。实现类可以自己重写，也可以通过 `接口名.super.方法名()` 调用某个接口默认实现。类中的方法优先级高于接口默认方法。

### 经典案例（代码）

```java
interface A {
    default void run() { System.out.println("A"); }
}

interface B {
    default void run() { System.out.println("B"); }
}

class C implements A, B {
    public void run() {
        A.super.run();
    }
}
```

### 高频坑

- 多接口默认方法冲突必须重写。
- 类方法优先于接口默认方法。
- 默认方法不是为了保存状态，而是为了接口演进。

### 面试追问

- 为什么 Java 8 加默认方法？  
  为了接口新增方法时不破坏已有实现类。
- 默认方法能被实现类重写吗？  
  可以，而且冲突时必须重写。

## static 初始化顺序

### 一句话秒答

静态成员按代码顺序在类加载时初始化，先父类静态，再子类静态；创建对象时再执行实例初始化和构造方法。

### 3 句展开

类第一次主动使用时会触发类初始化。静态变量和静态代码块按出现顺序执行。对象创建时，顺序通常是父类静态、子类静态、父类实例、父类构造、子类实例、子类构造。

### 经典案例（代码）

```java
class Demo {
    static int a = 1;
    static {
        a = 2;
    }
}

System.out.println(Demo.a); // 2
```

### 高频坑

- 静态初始化只执行一次。
- 静态代码块按书写顺序执行。
- 父类静态初始化早于子类静态初始化。

### 面试追问

- 什么时候触发类初始化？  
  创建对象、访问静态变量、调用静态方法等主动使用场景。
- 静态代码块能访问实例变量吗？  
  不能直接访问，因为此时没有具体对象。

## 静态代码块、构造代码块、构造方法执行顺序

### 一句话秒答

执行顺序是静态代码块先执行，且只执行一次；每次创建对象时，先执行构造代码块，再执行构造方法。

### 3 句展开

静态代码块属于类，类初始化时执行。构造代码块属于对象，每次 new 都会执行。构造方法最后执行，用来完成对象初始化。

### 经典案例（代码）

```java
class Demo {
    static { System.out.println("static"); }
    { System.out.println("block"); }
    Demo() { System.out.println("constructor"); }
}

new Demo();
new Demo();
// static 只打印一次，block 和 constructor 各打印两次
```

### 高频坑

- 静态代码块不是每次 new 都执行。
- 构造代码块先于构造方法执行。
- 继承场景还要先执行父类初始化。

### 面试追问

- 构造代码块有什么用？  
  可抽取多个构造方法共同的初始化逻辑，但实际开发不常用。
- 静态代码块能抛异常吗？  
  可以抛运行时异常，但会导致类初始化失败。

## transient 有什么用

### 一句话秒答

`transient` 用来修饰成员变量，表示该字段不参与 Java 默认序列化。常用于密码、临时缓存、可重新计算的数据。

### 3 句展开

对象序列化时，普通字段会被写入流中。被 `transient` 修饰的字段会被跳过，反序列化后恢复默认值。它只影响 Java 原生序列化机制。

### 经典案例（代码）

```java
class User implements Serializable {
    String name;
    transient String password;
}
```

### 高频坑

- `transient` 只能修饰变量，不能修饰类或方法。
- `static` 字段本来就不属于对象序列化内容。
- JSON 框架不一定遵守 `transient`，要看具体框架规则。

### 面试追问

- 反序列化后 transient 字段是什么值？  
  是类型默认值，比如引用类型是 `null`。
- 密码字段只加 transient 就安全吗？  
  不够，还要看日志、JSON、数据库等链路。

## volatile 作用是什么

### 一句话秒答

`volatile` 保证变量的可见性和一定的有序性，但不保证复合操作的原子性。它适合状态标记，不适合计数自增。

### 3 句展开

一个线程修改 `volatile` 变量后，其他线程能更快看到新值。它还能禁止部分指令重排序。`count++` 这种读改写操作仍然不是原子的。

### 经典案例（代码）

```java
volatile boolean running = true;

while (running) {
    // work
}
```

### 高频坑

- `volatile` 不能替代锁。
- `volatile int count; count++` 线程不安全。
- 它适合开关、状态标记、双重检查锁中的引用可见性。

### 面试追问

- `volatile` 保证原子性吗？  
  不保证复合操作原子性。
- 什么是可见性？  
  一个线程修改共享变量后，其他线程能看到最新值。

## synchronized 和 volatile 区别

### 一句话秒答

`volatile` 主要保证可见性，不保证复合操作原子性；`synchronized` 既保证可见性，也保证互斥和原子性。需要保护临界区时用 `synchronized`。

### 3 句展开

`volatile` 更轻量，只适合单变量状态同步。`synchronized` 会加锁，同一时间只有一个线程进入同步代码块。涉及多个变量或复合操作时，应该用锁或并发工具。

### 经典案例（代码）

```java
class Counter {
    private int count;

    synchronized void increment() {
        count++;
    }
}
```

### 高频坑

- `volatile` 不能保证 `i++` 安全。
- `synchronized` 不是只保证原子性，也保证可见性。
- 锁对象选择错误会导致锁不住共享资源。

### 面试追问

- `synchronized` 锁的是什么？  
  普通同步方法锁当前对象，静态同步方法锁 Class 对象。
- `volatile` 为什么不能保护多个变量一致性？  
  因为它没有互斥能力。

## private 方法能不能被重写

### 一句话秒答

`private` 方法不能被重写，因为它对子类不可见。子类写同名方法只是新定义了一个方法，不是重写。

### 3 句展开

重写要求子类能继承到父类方法。`private` 方法只在本类内部可见，子类无法继承。运行时多态也不会作用在私有方法上。

### 经典案例（代码）

```java
class Parent {
    private void run() {}
}

class Child extends Parent {
    public void run() {} // 不是重写
}
```

### 高频坑

- `private` 方法不能加 `@Override`。
- 私有方法不参与多态。
- 静态方法也不是真正重写。

### 面试追问

- 子类能定义同名 private 方法吗？  
  可以，但没有重写关系。
- final private 方法有意义吗？  
  意义不大，因为 private 本身就不能被重写。

## static 方法能不能被重写

### 一句话秒答

`static` 方法不能被真正重写，只能被子类同名隐藏。静态方法属于类，调用时看引用类型，不看实际对象。

### 3 句展开

重写是运行时多态，静态方法在编译期就按类型确定。子类可以定义同名静态方法，但这叫隐藏。不要用对象调用静态方法，容易误导。

### 经典案例（代码）

```java
class Parent {
    static void run() { System.out.println("parent"); }
}

class Child extends Parent {
    static void run() { System.out.println("child"); }
}

Parent p = new Child();
p.run(); // parent
```

### 高频坑

- 静态方法没有运行时多态。
- 子类同名静态方法是隐藏，不是重写。
- 用类名调用静态方法更清晰。

### 面试追问

- 静态方法能用 `@Override` 吗？  
  不能。
- 为什么静态方法不多态？  
  因为它属于类，调用在编译期按引用类型确定。

## Exception 和 Error 区别

### 一句话秒答

`Exception` 是程序可以处理的异常，`Error` 是 JVM 或系统级严重错误，通常不建议捕获处理。业务代码主要处理 `Exception`。

### 3 句展开

`Exception` 包括受检异常和运行时异常。`Error` 比如 `OutOfMemoryError`、`StackOverflowError`，通常说明程序或环境已处于严重状态。捕获 `Throwable` 容易误吞系统错误。

### 经典案例（代码）

```java
try {
    int n = Integer.parseInt("abc");
} catch (NumberFormatException e) {
    System.out.println("参数不是数字");
}
```

### 高频坑

- 不要随便 `catch (Throwable)`。
- `RuntimeException` 也是 `Exception`。
- `Error` 通常不作为业务恢复手段。

### 面试追问

- `OutOfMemoryError` 能 catch 吗？  
  语法上可以，但通常不建议依赖 catch 恢复。
- 异常处理的目的是什么？  
  让可预期错误有明确恢复、提示或降级逻辑。

## 受检异常和非受检异常区别

### 一句话秒答

受检异常编译器强制处理，必须 `try-catch` 或 `throws`；非受检异常通常是 `RuntimeException` 及其子类，编译器不强制处理。

### 3 句展开

受检异常常表示外部环境导致的问题，比如 IO 失败。非受检异常多表示程序逻辑问题，比如空指针、数组越界。业务中不要滥用受检异常，否则调用链会很重。

### 经典案例（代码）

```java
void readFile() throws IOException {
    Files.readString(Path.of("a.txt"));
}
```

### 高频坑

- `RuntimeException` 不需要强制 catch。
- 受检异常不是更高级，只是编译器强制处理。
- 不要把所有异常都包装成 `RuntimeException` 后丢失上下文。

### 面试追问

- `NullPointerException` 是受检异常吗？  
  不是，它是运行时异常。
- `IOException` 是受检异常吗？  
  是，编译器要求处理或声明抛出。

## throw 和 throws 区别

### 一句话秒答

`throw` 是在方法体里真正抛出一个异常对象，`throws` 是写在方法声明上，表示这个方法可能抛出异常。

### 3 句展开

`throw` 后面跟具体异常实例。`throws` 后面跟异常类型，可以有多个。简单说，`throw` 是动作，`throws` 是声明。

### 经典案例（代码）

```java
void check(int age) throws IllegalArgumentException {
    if (age < 0) {
        throw new IllegalArgumentException("age invalid");
    }
}
```

### 高频坑

- `throw` 只能抛一个异常对象。
- `throws` 可以声明多个异常类型。
- 声明 `throws` 不代表一定会抛。

### 面试追问

- `throw` 后面的代码还能执行吗？  
  同一分支下不会继续执行。
- 子类重写方法能抛更大的异常吗？  
  受检异常不能比父类方法声明得更宽。

## try-catch-finally 执行顺序

### 一句话秒答

先执行 `try`，有异常且匹配时执行 `catch`，最后执行 `finally`。通常无论是否异常，`finally` 都会执行。

### 3 句展开

`try` 中没有异常时跳过 `catch`。有异常时按匹配类型进入对应 `catch`。`finally` 常用于释放资源，但现代代码更推荐 `try-with-resources`。

### 经典案例（代码）

```java
try {
    System.out.println("try");
} catch (Exception e) {
    System.out.println("catch");
} finally {
    System.out.println("finally");
}
```

### 高频坑

- `finally` 不是绝对执行，例如 `System.exit()`。
- `finally` 里不要写 `return`。
- 多个 `catch` 要先写子类异常，再写父类异常。

### 面试追问

- `try` 里 return 了，finally 还执行吗？  
  通常会先执行 `finally`，再返回。
- catch 顺序为什么子类在前？  
  父类在前会把子类异常先捕获，后面的子类 catch 不可达。

## finally 一定会执行吗

### 一句话秒答

不一定。正常异常流程下通常会执行，但 JVM 退出、线程被强制停止、机器断电等情况下不会执行。

### 3 句展开

`finally` 的设计目的是收尾，不是绝对保证。`System.exit()` 会直接退出 JVM，后续 finally 不执行。资源释放更推荐 `try-with-resources`。

### 经典案例（代码）

```java
try {
    System.exit(0);
} finally {
    System.out.println("不会执行");
}
```

### 高频坑

- 不要把 finally 当成绝对可靠的持久化保证。
- finally 里 return 会覆盖前面的返回值。
- finally 里抛异常会掩盖 try/catch 中的异常。

### 面试追问

- finally 常用来做什么？  
  释放资源、关闭连接、清理临时状态。
- 为什么推荐 try-with-resources？  
  它更简洁，并且能正确处理资源关闭异常。

## try 和 finally 同时 return 返回谁

### 一句话秒答

如果 `finally` 里也写了 `return`，最终返回 `finally` 的结果，并覆盖 `try` 里的返回。实际开发中不要在 `finally` 里写 `return`。

### 3 句展开

`try` 的返回值会先被保存。执行真正返回前会进入 `finally`。如果 `finally` 重新 return，就会覆盖之前保存的结果。

### 经典案例（代码）

```java
int test() {
    try {
        return 1;
    } finally {
        return 2;
    }
}
// 返回 2
```

### 高频坑

- finally return 会吞掉异常。
- finally return 会覆盖 try/catch return。
- 代码规范通常禁止 finally 里 return。

### 面试追问

- finally 修改返回对象内容会影响结果吗？  
  如果返回的是引用对象，修改对象内部状态可能影响。
- finally 里抛异常会怎样？  
  会覆盖原异常或原返回路径。

## try-with-resources 原理

### 一句话秒答

`try-with-resources` 会自动关闭实现了 `AutoCloseable` 的资源，本质是编译器帮我们生成关闭资源的 `finally` 逻辑。

### 3 句展开

资源写在 `try(...)` 里，代码块结束后自动调用 `close()`。多个资源会按声明的反向顺序关闭。它还能处理关闭异常和业务异常同时出现的情况。

### 经典案例（代码）

```java
try (BufferedReader reader = Files.newBufferedReader(Path.of("a.txt"))) {
    System.out.println(reader.readLine());
}
```

### 高频坑

- 资源必须实现 `AutoCloseable` 或 `Closeable`。
- 关闭顺序和声明顺序相反。
- 比手写 finally 关闭资源更稳。

### 面试追问

- close 异常会丢吗？  
  不会，可能作为 suppressed exception 记录。
- 为什么比 finally 更推荐？  
  更短、更不容易漏关资源。

## HashSet 如何保证元素不重复

### 一句话秒答

`HashSet` 底层主要依赖 `HashMap`，元素作为 key 存储。判断重复时先看 `hashCode()` 定位，再用 `equals()` 判断是否相等。

### 3 句展开

添加元素时，先计算哈希值找到桶。桶里没有相同元素就加入。有相同哈希时继续用 `equals()` 判断是否已经存在。

### 经典案例（代码）

```java
Set<String> set = new HashSet<>();
set.add("a");
set.add("a");
System.out.println(set.size()); // 1
```

### 高频坑

- 自定义对象必须正确重写 `equals()` 和 `hashCode()`。
- `HashSet` 不保证顺序。
- `hashCode()` 相同不代表对象相等。

### 面试追问

- `HashSet` 的 value 是什么？  
  底层 `HashMap` 用一个固定的占位对象作为 value。
- 想保持插入顺序用什么？  
  用 `LinkedHashSet`。

## HashMap 的 key 为什么建议不可变

### 一句话秒答

因为 key 的哈希值参与定位桶，如果 key 放入后内容变了，`hashCode()` 可能变化，后续就可能找不到这个 key。

### 3 句展开

`HashMap` put 时会按 key 的 hash 定位位置。get 时也按当前 key 的 hash 去找。如果 key 状态变化导致 hash 不一致，就会定位到错误位置。

### 经典案例（代码）

```java
Map<List<String>, String> map = new HashMap<>();
List<String> key = new ArrayList<>();
key.add("a");
map.put(key, "value");

key.add("b");
System.out.println(map.get(key)); // 可能拿不到
```

### 高频坑

- 可变对象做 key 风险很高。
- `String` 适合做 key，因为不可变。
- 自定义 key 字段参与 hash 后不要再修改。

### 面试追问

- key 变化为什么会找不到？  
  因为哈希定位位置可能变了。
- 可以用对象当 key 吗？  
  可以，但要保证相等逻辑稳定。

## HashMap 允许 null 吗

### 一句话秒答

`HashMap` 允许一个 `null` key 和多个 `null` value。`ConcurrentHashMap` 不允许 `null` key 和 `null` value。

### 3 句展开

`HashMap` 对 `null` key 做特殊处理，通常放在第 0 个桶。多个 value 可以是 `null`。并发 Map 不允许 `null`，主要是避免并发下语义不清。

### 经典案例（代码）

```java
Map<String, Integer> map = new HashMap<>();
map.put(null, 1);
map.put("a", null);
```

### 高频坑

- `HashMap` 只能有一个 null key。
- `Hashtable` 不允许 null。
- `ConcurrentHashMap` 不允许 null。

### 面试追问

- 为什么只能一个 null key？  
  因为 key 不能重复，后 put 会覆盖旧值。
- `get()` 返回 null 表示什么？  
  可能是 key 不存在，也可能是 value 本身为 null。

## TreeMap 和 HashMap 区别

### 一句话秒答

`HashMap` 基于哈希表，查询通常更快但无序；`TreeMap` 基于红黑树，按 key 排序，查询、插入、删除是 O(log n)。

### 3 句展开

如果只需要按 key 快速查找，优先 `HashMap`。如果需要 key 有序，选择 `TreeMap`。`TreeMap` 的 key 要能比较，或者传入比较器。

### 经典案例（代码）

```java
Map<Integer, String> map = new TreeMap<>();
map.put(2, "b");
map.put(1, "a");
System.out.println(map.keySet()); // [1, 2]
```

### 高频坑

- `TreeMap` 不是按插入顺序，而是按 key 排序。
- key 必须可比较，否则可能运行时报错。
- 比较结果为 0 会被认为是同一个 key。

### 面试追问

- 想保持插入顺序用什么 Map？  
  用 `LinkedHashMap`。
- `TreeMap` 可以传 Comparator 吗？  
  可以，用来自定义排序规则。

## LinkedHashMap 有什么用

### 一句话秒答

`LinkedHashMap` 在 `HashMap` 基础上维护双向链表，可以保持插入顺序，也可以支持访问顺序，常用于实现简单 LRU 缓存。

### 3 句展开

普通 `HashMap` 不保证遍历顺序。`LinkedHashMap` 通过链表记录顺序，遍历结果更可控。开启访问顺序后，最近访问的元素会移动到尾部。

### 经典案例（代码）

```java
Map<String, Integer> map = new LinkedHashMap<>();
map.put("b", 2);
map.put("a", 1);
System.out.println(map.keySet()); // [b, a]
```

### 高频坑

- `LinkedHashMap` 保持顺序但不是线程安全。
- 默认是插入顺序，不是访问顺序。
- 做 LRU 要重写 `removeEldestEntry()`。

### 面试追问

- `LinkedHashMap` 比 `HashMap` 多了什么？  
  多维护了一条双向链表。
- LRU 是什么？  
  最近最少使用，淘汰最久未访问的数据。

## Collections.synchronizedList 和 CopyOnWriteArrayList 区别

### 一句话秒答

`Collections.synchronizedList` 是给普通 List 包一层同步锁；`CopyOnWriteArrayList` 是写时复制，读不用加锁，适合读多写少。

### 3 句展开

同步 List 每次访问通常要竞争同一把锁。`CopyOnWriteArrayList` 写入时复制新数组，读操作读旧数组快且安全。写多场景不要用写时复制，成本太高。

### 经典案例（代码）

```java
List<String> list = new CopyOnWriteArrayList<>();
list.add("a");
for (String item : list) {
    list.add("b"); // 不会抛 ConcurrentModificationException
}
```

### 高频坑

- `CopyOnWriteArrayList` 写入成本高。
- 同步 List 迭代时仍要手动同步。
- 读多写少才适合 CopyOnWrite。

### 面试追问

- CopyOnWrite 读到的是最新数据吗？  
  不一定，遍历时可能读的是快照。
- synchronizedList 线程安全吗？  
  单个方法同步，但复合操作仍要自己保证同步。

## Java 泛型有什么用

### 一句话秒答

泛型就是把类型参数化，让代码在编译期检查类型，减少强制类型转换和运行时类型错误。最常见的例子就是 `List<String>`，它限制集合里只能放字符串。

### 3 句展开

泛型提高了代码复用性，同一套类或方法可以处理不同类型。泛型主要在编译期起作用，编译器会帮我们做类型检查。运行期由于类型擦除，很多泛型类型信息会被擦掉。

### 经典案例（代码）

```java
List<String> names = new ArrayList<>();
names.add("Tom");
// names.add(123); // 编译错误

String name = names.get(0); // 不需要强转
```

### 高频坑

- 泛型主要保证编译期类型安全，不是运行期完整保留类型。
- 原始类型 `List` 会绕过泛型检查，容易埋坑。
- `List<Object>` 不是 `List<String>` 的父类。

### 面试追问

- 泛型解决了什么问题？  
  解决类型安全和重复强转问题。
- 泛型是在编译期还是运行期生效？  
  主要在编译期生效，运行期会发生类型擦除。

## Java 泛型类型擦除

### 一句话秒答

Java 泛型是“伪泛型”，因为它主要在编译期做类型检查，运行期会通过类型擦除把大部分泛型信息擦掉，变成原始类型或上界类型。比如 `List<String>` 和 `List<Integer>` 运行期都是 `List`。

### 3 句展开

类型擦除是为了兼容早期没有泛型的 Java 代码。编译器会在编译期做类型检查，并在需要时插入强制类型转换。因为运行期泛型信息不完整，所以说 Java 泛型不是真正运行期保留完整类型信息的“真泛型”。

### 经典案例（代码）

```java
List<String> a = new ArrayList<>();
List<Integer> b = new ArrayList<>();

System.out.println(a.getClass() == b.getClass()); // true

// if (a instanceof List<String>) {} // 编译错误
```

### 高频坑

- 不能用 `instanceof List<String>` 判断泛型类型。
- 不能直接创建泛型数组。
- 方法重载不能只靠泛型参数不同区分，因为擦除后签名可能一样。

### 面试追问

- 为什么 Java 要类型擦除？  
  主要是为了兼容旧版本 Java 和原始类型代码。
- 如何理解 Java 泛型是伪泛型？  
  泛型类型主要存在于编译期，运行期大部分类型参数会被擦除。
- 类型擦除后还安全吗？  
  编译期已经做了类型检查，正常使用是安全的。

## 泛型上限和下限：? extends T 和 ? super T

### 一句话秒答

泛型上限用 `extends`，表示类型最多到某个父类型；泛型下限用 `super`，表示类型最少是某个子类型。`? extends T` 适合读取，`? super T` 适合写入，记一句话：`extends` 主要读，`super` 主要写。

### 3 句展开

`<T extends Number>` 表示类型参数 `T` 的上限是 `Number`，只能接收 `Number` 或其子类。`List<? extends Number>` 表示元素类型是 `Number` 或其子类，但具体是哪种不确定，所以不能随便添加元素。`List<? super Integer>` 表示元素类型是 `Integer` 或其父类，可以安全写入 `Integer`，这就是 PECS 原则：Producer Extends，Consumer Super。

### 经典案例（代码）

```java
class Box<T extends Number> {
    private T value;
}

List<? extends Number> nums = List.of(1, 2, 3);
Number n = nums.get(0); // 适合读
// nums.add(4); // 编译错误

List<? super Integer> values = new ArrayList<Number>();
values.add(1); // 适合写
```

### 高频坑

- `extends` 不是不能读，而是不能安全写入具体子类。
- `super` 可以写入下界类型，但读取时通常只能当 `Object`。
- PECS 是面试高频：生产者用 extends，消费者用 super。

### 面试追问

- 为什么 `List<? extends Number>` 不能 add Integer？  
  因为真实类型可能是 `List<Double>`，添加 `Integer` 不安全。
- `List<? super Integer>` 读取出来是什么类型？  
  通常只能安全当成 `Object`。

## List<Object> 和 List<?> 区别

### 一句话秒答

`List<Object>` 表示集合元素类型就是 `Object`，可以添加任何对象；`List<?>` 表示未知类型集合，主要用于安全读取，不能随便添加元素。

### 3 句展开

`List<Object>` 可以接收 `Object` 元素，但不能接收 `List<String>` 赋值。`List<?>` 可以引用 `List<String>`、`List<Integer>` 等各种泛型集合。因为 `?` 的真实类型未知，所以除了 `null` 外不能安全添加元素。

### 经典案例（代码）

```java
List<String> strings = new ArrayList<>();

List<?> unknown = strings; // 可以
// List<Object> objects = strings; // 编译错误
```

### 高频坑

- `List<Object>` 不是所有 `List<T>` 的父类型。
- `List<?>` 可以接很多类型，但写入能力受限。
- 泛型不支持协变，数组支持协变，这也是常考点。

### 面试追问

- 为什么 `List<Object>` 不能接 `List<String>`？  
  如果允许，就能往里面放非字符串对象，破坏类型安全。
- `List<?>` 能 add 什么？  
  通常只能 add `null`，不能添加具体类型对象。

## 泛型方法和泛型类区别

### 一句话秒答

泛型类是在类上定义类型参数，整个类都能使用；泛型方法是在方法上定义类型参数，只对这个方法生效。

### 3 句展开

泛型类适合类内部多个字段或方法都依赖同一种类型。泛型方法适合单个方法临时需要类型参数。泛型方法的类型参数写在返回值前面。

### 经典案例（代码）

```java
class Box<T> {
    private T value;
}

class Utils {
    public static <T> T first(List<T> list) {
        return list.get(0);
    }
}
```

### 高频坑

- 泛型方法的 `<T>` 要写在返回值类型前。
- 泛型类的 `T` 和泛型方法的 `T` 可以不是同一个。
- 静态方法不能直接使用泛型类上的类型参数，除非自己声明泛型。

### 面试追问

- 静态方法为什么不能直接用类上的 `T`？  
  因为类的泛型参数依赖对象实例，静态方法属于类本身。
- 泛型方法类型参数由谁决定？  
  通常由编译器根据调用参数推断。

## 泛型接口如何定义和使用

### 一句话秒答

泛型接口就是在接口名后面声明类型参数，比如 `interface Repository<T>`。实现时可以指定具体类型，也可以让实现类继续保留泛型。

### 3 句展开

泛型接口适合定义一套通用能力，比如保存、查询、转换。实现类如果确定类型，就写成 `class UserRepository implements Repository<User>`。如果实现类也想通用，就写成 `class MemoryRepository<T> implements Repository<T>`。

### 经典案例（代码）

```java
interface Repository<T> {
    void save(T data);
    T findById(long id);
}

class UserRepository implements Repository<User> {
    public void save(User data) {
        System.out.println(data);
    }

    public User findById(long id) {
        return new User();
    }
}

class MemoryRepository<T> implements Repository<T> {
    public void save(T data) {}

    public T findById(long id) {
        return null;
    }
}
```

### 高频坑

- 实现泛型接口时，要么指定具体类型，要么实现类继续声明泛型。
- 不要使用原始接口类型 `Repository`，会丢失类型检查。
- 泛型接口的类型参数在运行期也会被擦除。

### 面试追问

- 泛型接口和泛型类有什么区别？  
  泛型接口定义能力规范，泛型类定义具体数据结构或实现逻辑。
- 实现类能不能换一个类型参数名？  
  可以，名字不重要，类型参数位置和含义才重要。

## 泛型方法如何定义和使用

### 一句话秒答

泛型方法是在返回值类型前声明类型参数，比如 `public static <T> T first(List<T> list)`。它的泛型只在当前方法内生效，调用时通常由编译器自动推断类型。

### 3 句展开

泛型方法适合写工具方法，让同一个方法处理多种类型。`<T>` 必须写在修饰符之后、返回值之前。泛型方法可以定义在普通类、泛型类，甚至非泛型类里。

### 经典案例（代码）

```java
class Utils {
    public static <T> T first(List<T> list) {
        return list.isEmpty() ? null : list.get(0);
    }
}

String name = Utils.first(List.of("Tom", "Jerry"));
Integer num = Utils.first(List.of(1, 2, 3));
```

### 高频坑

- `<T>` 要写在返回值前面，不是只在参数里写 `T`。
- 泛型方法的类型参数和泛型类的类型参数可以相互独立。
- 静态泛型方法必须自己声明 `<T>`，不能直接使用泛型类上的 `T`。

### 面试追问

- 泛型方法一定要在泛型类里吗？  
  不需要，普通类里也可以定义泛型方法。
- 调用泛型方法时必须手动写类型吗？  
  通常不需要，编译器会根据参数和返回值上下文推断。

## 多个泛型类型参数：T / R / K / V

### 一句话秒答

泛型可以一次声明多个类型参数，比如 `<T, R>`、`<K, V>`。`T` 常表示普通类型，`R` 常表示返回结果，`K` 表示 key，`V` 表示 value，本质上都是类型占位符。

### 3 句展开

当入参类型和返回类型不一样时，可以写成 `<T, R>`，表示传入 `T`，返回 `R`。当处理键值对时，通常写成 `<K, V>`，比如 `Map<K, V>`。这些字母只是命名约定，换成 `<A, B>` 也能编译，但可读性会差。

### 经典案例（代码）

```java
public static <T, R> R convert(T value, Function<T, R> mapper) {
    return mapper.apply(value);
}

String text = convert(123, n -> String.valueOf(n));

public static <K, V> V getValue(Map<K, V> map, K key) {
    return map.get(key);
}

Map<String, Integer> ages = new HashMap<>();
ages.put("Tom", 18);
Integer age = getValue(ages, "Tom");
```

### 高频坑

- `<T, R>` 里的类型参数要先声明，后面返回值和参数里才能使用。
- `K`、`V` 不是关键字，只是约定俗成的名字。
- 类型参数越多越难读，不要为了炫技滥用泛型。

### 面试追问

- `<T, R>` 和 `<K, V>` 有本质区别吗？  
  没有，本质都是类型参数，只是命名语义不同。
- 编译器怎么知道 `T`、`R` 是什么类型？  
  通常根据传入参数、Lambda 和返回值上下文自动推断。
