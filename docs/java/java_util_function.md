# java.util.function 函数式接口速查

## 1. 先记 4 个核心

`java.util.function` 是 Java 8 提供的一组通用函数式接口，主要用于 Lambda、Stream、Optional、CompletableFuture 等场景。

记忆口诀：

```text
Function：有入参，有返回
Consumer：有入参，无返回
Supplier：无入参，有返回
Predicate：有入参，返回 boolean
```

| 接口 | 抽象方法 | 含义 | Lambda 例子 |
|---|---|---|---|
| `Function<T, R>` | `R apply(T t)` | T 转 R | `s -> s.length()` |
| `Consumer<T>` | `void accept(T t)` | 消费 T | `s -> System.out.println(s)` |
| `Supplier<T>` | `T get()` | 提供 T | `() -> new User()` |
| `Predicate<T>` | `boolean test(T t)` | 判断 T | `n -> n > 0` |

## 2. 核心接口示例

### Function：转换

```java
Function<String, Integer> length = s -> s.length();

Integer result = length.apply("java"); // 4
```

常见场景：

```java
List<Integer> lengths = names.stream()
        .map(String::length)
        .toList();
```

`map` 需要的就是：

```java
Function<T, R>
```

### Consumer：消费

```java
Consumer<String> print = s -> System.out.println(s);

print.accept("hello");
```

常见场景：

```java
names.forEach(System.out::println);
```

`forEach` 需要的就是：

```java
Consumer<T>
```

### Supplier：提供

```java
Supplier<User> userSupplier = () -> new User();

User user = userSupplier.get();
```

常见场景：

```java
User user = optional.orElseGet(() -> new User());
```

`orElseGet` 需要的就是：

```java
Supplier<T>
```

### Predicate：判断

```java
Predicate<Integer> positive = n -> n > 0;

boolean result = positive.test(10); // true
```

常见场景：

```java
List<Integer> positives = nums.stream()
        .filter(n -> n > 0)
        .toList();
```

`filter` 需要的就是：

```java
Predicate<T>
```

## 3. Bi 开头：两个入参

`Bi` 表示 two，也就是两个参数。

| 接口 | 抽象方法 | 含义 | Lambda 例子 |
|---|---|---|---|
| `BiFunction<T, U, R>` | `R apply(T t, U u)` | T 和 U 转 R | `(a, b) -> a + b` |
| `BiConsumer<T, U>` | `void accept(T t, U u)` | 消费 T 和 U | `(k, v) -> System.out.println(k + v)` |
| `BiPredicate<T, U>` | `boolean test(T t, U u)` | 判断 T 和 U | `(a, b) -> a.equals(b)` |

示例：

```java
BiFunction<Integer, Integer, Integer> add = (a, b) -> a + b;
Integer sum = add.apply(1, 2); // 3

BiPredicate<String, String> same = (a, b) -> a.equals(b);
boolean result = same.test("a", "a"); // true
```

## 4. Operator：参数和返回值类型相同

`Operator` 是 `Function` 的特殊情况：入参和返回值类型相同。

| 接口 | 等价理解 | 抽象方法 | Lambda 例子 |
|---|---|---|---|
| `UnaryOperator<T>` | `Function<T, T>` | `T apply(T t)` | `n -> n + 1` |
| `BinaryOperator<T>` | `BiFunction<T, T, T>` | `T apply(T t1, T t2)` | `(a, b) -> a + b` |

示例：

```java
UnaryOperator<Integer> plusOne = n -> n + 1;
Integer a = plusOne.apply(10); // 11

BinaryOperator<Integer> max = (x, y) -> x > y ? x : y;
Integer b = max.apply(3, 5); // 5
```

## 5. 常用默认方法

### Function 组合

```java
Function<String, String> trim = s -> s.trim();
Function<String, Integer> length = s -> s.length();

Integer a = trim.andThen(length).apply(" java "); // 4
Integer b = length.compose(trim).apply(" java "); // 4
```

区别：

| 方法 | 执行顺序 |
|---|---|
| `f.andThen(g)` | 先执行 f，再执行 g |
| `f.compose(g)` | 先执行 g，再执行 f |

### Predicate 组合

```java
Predicate<Integer> positive = n -> n > 0;
Predicate<Integer> even = n -> n % 2 == 0;

boolean a = positive.and(even).test(10); // true
boolean b = positive.or(even).test(-2);  // true
boolean c = positive.negate().test(-1);  // true
```

| 方法 | 含义 |
|---|---|
| `and` | 并且 |
| `or` | 或者 |
| `negate` | 取反 |

### Consumer 组合

```java
Consumer<String> print = s -> System.out.println(s);
Consumer<String> log = s -> System.out.println("log: " + s); //java  log: java

print.andThen(log).accept("java");
```

`Consumer.andThen` 会按顺序执行多个消费动作。

## 6. 基本类型专用接口

为了减少自动装箱和拆箱，JDK 提供了 `int`、`long`、`double` 的专用版本。

| 普通接口 | int 专用 | long 专用 | double 专用 |
|---|---|---|---|
| `Function<T, R>` | `IntFunction<R>` | `LongFunction<R>` | `DoubleFunction<R>` |
| `Consumer<T>` | `IntConsumer` | `LongConsumer` | `DoubleConsumer` |
| `Supplier<T>` | `IntSupplier` | `LongSupplier` | `DoubleSupplier` |
| `Predicate<T>` | `IntPredicate` | `LongPredicate` | `DoublePredicate` |
| `UnaryOperator<T>` | `IntUnaryOperator` | `LongUnaryOperator` | `DoubleUnaryOperator` |
| `BinaryOperator<T>` | `IntBinaryOperator` | `LongBinaryOperator` | `DoubleBinaryOperator` |

示例：

```java
IntPredicate even = n -> n % 2 == 0;
IntUnaryOperator square = n -> n * n;

boolean a = even.test(10);      // true
int b = square.applyAsInt(5);   // 25
```

注意方法名会变：

| 接口 | 方法 |
|---|---|
| `IntSupplier` | `getAsInt()` |
| `IntFunction<R>` | `apply(int value)` |
| `IntUnaryOperator` | `applyAsInt(int operand)` |
| `IntPredicate` | `test(int value)` |
| `IntConsumer` | `accept(int value)` |

## 7. ToXxx 和 XxxToYyy

这类接口用来表达返回值或入参是基本类型。

| 接口 | 含义 | 例子 |
|---|---|---|
| `ToIntFunction<T>` | T 转 int | `String::length` |
| `ToLongFunction<T>` | T 转 long | `user -> user.getId()` |
| `ToDoubleFunction<T>` | T 转 double | `order -> order.getAmount()` |
| `IntToLongFunction` | int 转 long | `n -> (long) n` |
| `IntToDoubleFunction` | int 转 double | `n -> n * 1.0` |
| `LongToIntFunction` | long 转 int | `n -> (int) n` |
| `DoubleToIntFunction` | double 转 int | `n -> (int) n` |

示例：

```java
ToIntFunction<String> length = String::length;
int size = length.applyAsInt("java"); // 4

IntToDoubleFunction half = n -> n / 2.0;
double value = half.applyAsDouble(5); // 2.5
```

## 8. 最常见的使用位置

| API | 常见参数类型 | 例子 |
|---|---|---|
| `stream().map(...)` | `Function<T, R>` | `map(User::getName)` |
| `stream().filter(...)` | `Predicate<T>` | `filter(u -> u.isActive())` |
| `stream().forEach(...)` | `Consumer<T>` | `forEach(System.out::println)` |
| `Optional.orElseGet(...)` | `Supplier<T>` | `orElseGet(User::new)` |
| `Map.forEach(...)` | `BiConsumer<K, V>` | `forEach((k, v) -> ...)` |
| `Map.compute(...)` | `BiFunction<K, V, V>` | `compute(k, (key, old) -> ...)` |
| `Comparator.comparing(...)` | `Function<T, U>` | `comparing(User::getAge)` |

## 9. 函数方法调用示例

### 直接调用函数对象

函数式接口本质上就是一个对象，调用它的抽象方法即可。

```java
Function<String, Integer> length = s -> s.length();
Integer a = length.apply("hello");

Consumer<String> print = s -> System.out.println(s);
print.accept("hello");

Supplier<String> supplier = () -> "hello";
String b = supplier.get();

Predicate<Integer> adult = age -> age >= 18;
boolean c = adult.test(20);
```

### 方法参数接收 Function

```java
public static <T, R> R convert(T value, Function<T, R> function) {
    return function.apply(value);
}

Integer length = convert("java", s -> s.length());
String upper = convert("java", s -> s.toUpperCase());
```

适合做“传入一个值，按外部规则转换成另一个值”。

### 方法参数接收 Consumer

```java
public static <T> void handle(T value, Consumer<T> consumer) {
    consumer.accept(value);
}

handle("java", s -> System.out.println(s));
handle("java", System.out::println);
```

适合做“传入一个值，然后执行某个动作”，比如打印、写日志、保存、发送消息。

### 方法参数接收 Supplier

```java
public static <T> T create(Supplier<T> supplier) {
    return supplier.get();
}

String value = create(() -> "default");
User user = create(User::new);
```

适合做“延迟创建”，需要时再执行。

### 方法参数接收 Predicate

```java
public static <T> List<T> filter(List<T> list, Predicate<T> predicate) {
    List<T> result = new ArrayList<>();

    for (T item : list) {
        if (predicate.test(item)) {
            result.add(item);
        }
    }

    return result;
}

List<Integer> nums = List.of(1, 2, 3, 4, 5);
List<Integer> evens = filter(nums, n -> n % 2 == 0);
```

适合做“把判断条件交给调用方”。

### 方法参数接收 BiFunction

```java
public static <T, U, R> R calculate(T a, U b, BiFunction<T, U, R> function) {
    return function.apply(a, b);
}

Integer sum = calculate(10, 20, (a, b) -> a + b);
String text = calculate("hello", 3, (s, n) -> s.repeat(n));
```

适合做“两个参数计算出一个结果”。

### 在 Optional 中调用

```java
String name = Optional.ofNullable(user)
        .map(User::getName)              // Function<User, String>
        .filter(s -> !s.isBlank())       // Predicate<String>
        .orElseGet(() -> "unknown");     // Supplier<String>
```

### 在 Stream 中调用

```java
List<String> names = users.stream()
        .filter(User::isActive)          // Predicate<User>
        .map(User::getName)              // Function<User, String>
        .peek(System.out::println)       // Consumer<String>
        .toList();
```

### 在 Map 中调用

```java
Map<String, Integer> countMap = new HashMap<>();

countMap.compute("java", (key, oldValue) -> oldValue == null ? 1 : oldValue + 1);
countMap.forEach((key, value) -> System.out.println(key + "=" + value));
```

这里：

| 方法 | 接收的函数式接口 |
|---|---|
| `compute` | `BiFunction<K, V, V>` |
| `forEach` | `BiConsumer<K, V>` |

### 使用方法引用调用

Lambda 能写成方法引用时，可以更简洁。

```java
Function<String, Integer> length1 = s -> s.length();
Function<String, Integer> length2 = String::length;

Consumer<String> print1 = s -> System.out.println(s);
Consumer<String> print2 = System.out::println;

Supplier<User> user1 = () -> new User();
Supplier<User> user2 = User::new;
```

常见方法引用格式：

| 写法 | 含义 | 例子 |
|---|---|---|
| `对象::实例方法` | 调用某个对象的方法 | `System.out::println` |
| `类::实例方法` | 调用参数对象的方法 | `String::length` |
| `类::静态方法` | 调用静态方法 | `Integer::parseInt` |
| `类::new` | 调用构造方法 | `User::new` |

## 10. `->` 和 `::` 怎么用

### 先记结论

`->` 是 Lambda 表达式，表示“我要自己写一段函数逻辑”。

`::` 是方法引用，表示“这段逻辑已经有现成方法了，直接引用它”。

```text
能用 :: 的地方，基本都能改回 ->
但能用 -> 的地方，不一定都能改成 ::
```

### `->` 的基本写法

```java
参数 -> 方法体
```

一个参数：

```java
Function<String, Integer> length = s -> s.length();
Predicate<Integer> even = n -> n % 2 == 0;
Consumer<String> print = s -> System.out.println(s);
```

多个参数：

```java
BiFunction<Integer, Integer, Integer> add = (a, b) -> a + b;
BiPredicate<String, String> same = (a, b) -> a.equals(b);
```

没有参数：

```java
Supplier<String> supplier = () -> "hello";
```

多行逻辑：

```java
Function<String, String> clean = s -> {
    String value = s.trim();
    return value.toUpperCase();
};
```

注意：

```java
s -> s.length()
```

等价于：

```java
s -> {
    return s.length();
}
```

### `::` 的基本写法

`::` 左边是类名或对象名，右边是方法名。

```java
类名::方法名
对象名::方法名
类名::new
```

它不能写参数，也不能写括号：

```java
String::length        // 对
String::length()      // 错
System.out::println   // 对
System.out.println    // 错
```

### `->` 改成 `::`

如果 Lambda 只是简单调用一个已有方法，通常可以改成方法引用。

| Lambda | 方法引用 |
|---|---|
| `s -> s.length()` | `String::length` |
| `s -> s.toUpperCase()` | `String::toUpperCase` |
| `s -> System.out.println(s)` | `System.out::println` |
| `s -> Integer.parseInt(s)` | `Integer::parseInt` |
| `() -> new User()` | `User::new` |
| `user -> user.getName()` | `User::getName` |

示例：

```java
List<String> names = users.stream()
        .map(user -> user.getName())
        .toList();

List<String> names2 = users.stream()
        .map(User::getName)
        .toList();
```

两段代码效果一样。

### 什么时候不能用 `::`

如果 Lambda 里面有额外逻辑，不能直接改成 `::`。

```java
// 可以用 ::
Function<String, Integer> f1 = s -> s.length();
Function<String, Integer> f2 = String::length;

// 不适合用 ::
Function<String, Integer> f3 = s -> s.trim().length();
Function<String, String> f4 = s -> "hello " + s;
Predicate<Integer> f5 = n -> n > 18 && n < 60;
```

因为 `trim().length()`、字符串拼接、多个条件判断都不是“单纯调用一个已有方法”。

### 四种常见方法引用

#### 1. 对象::实例方法

已有一个对象，直接引用它的方法。

```java
Consumer<String> print = System.out::println;
print.accept("java");
```

等价于：

```java
Consumer<String> print = s -> System.out.println(s);
```

这里 `System.out` 是对象，`println` 是这个对象的方法。

#### 2. 类::静态方法

引用静态方法。

```java
Function<String, Integer> parse = Integer::parseInt;
Integer value = parse.apply("123");
```

等价于：

```java
Function<String, Integer> parse = s -> Integer.parseInt(s);
```

#### 3. 类::实例方法

这个最容易混。

```java
Function<String, Integer> length = String::length;
Integer size = length.apply("java");
```

等价于：

```java
Function<String, Integer> length = s -> s.length();
```

理解方式：

```text
String::length
```

表示“传进来一个 String 对象，然后调用这个对象的 length 方法”。

再看一个两个参数的例子：

```java
BiPredicate<String, String> startsWith = String::startsWith;
boolean result = startsWith.test("java", "ja");
```

等价于：

```java
BiPredicate<String, String> startsWith = (s, prefix) -> s.startsWith(prefix);
```

第一个参数会变成方法调用者，后面的参数会变成方法参数。

### 4. 类::new

引用构造方法。

```java
Supplier<User> supplier = User::new;
User user = supplier.get();
```

等价于：

```java
Supplier<User> supplier = () -> new User();
```

如果构造方法有参数：

```java
Function<String, User> createUser = User::new;
User user = createUser.apply("张三");
```

等价于：

```java
Function<String, User> createUser = name -> new User(name);
```

### 快速判断能不能用 `::`

看到 Lambda 时按这个规则判断：

```text
如果 Lambda 只是把参数原封不动传给一个已有方法，就可以考虑 ::
如果 Lambda 里有计算、判断、拼接、多个方法连续调用，就继续用 ->
```

例子：

| Lambda | 能否改成 `::` | 原因 |
|---|---|---|
| `s -> s.length()` | 能，`String::length` | 只调用一个现成方法 |
| `s -> s.trim().length()` | 不能 | 连续调用了两个方法 |
| `s -> Integer.parseInt(s)` | 能，`Integer::parseInt` | 只调用静态方法 |
| `n -> n > 0` | 不能 | 自己写了判断逻辑 |
| `u -> u.getName()` | 能，`User::getName` | 只调用 getter |
| `u -> u.getName().trim()` | 不能 | 多了一步 `trim()` |
| `() -> new User()` | 能，`User::new` | 只创建对象 |

### 最常用记忆模板

```java
// 对象方法
s -> s.length()
String::length

// 静态方法
s -> Integer.parseInt(s)
Integer::parseInt

// 打印
s -> System.out.println(s)
System.out::println

// getter
user -> user.getName()
User::getName

// 构造方法
() -> new User()
User::new
```

## 11. Stream 的数据传递过程

### 先记结论

Stream 不是先把所有数据执行完 `filter`，再把所有数据执行完 `map`。

更准确的理解是：

```text
一个元素从源头进入管道，依次经过 filter、map、peek 等操作；
能走到终点的元素，才会进入 collect、forEach、count 等终止操作。
```

示例：

```java
List<String> result = List.of("java", "go", "python", "js").stream()
        .filter(s -> s.length() > 2)
        .map(s -> s.toUpperCase())
        .toList();
```

执行过程可以理解为：

```text
"java"   -> filter 通过 -> map 变成 "JAVA"   -> 收集
"go"     -> filter 不通过 -> 后面的 map 不执行
"python" -> filter 通过 -> map 变成 "PYTHON" -> 收集
"js"     -> filter 不通过 -> 后面的 map 不执行
```

最终结果：

```java
[JAVA, PYTHON]
```

### Stream 操作分两类

| 类型 | 含义 | 常见方法 |
|---|---|---|
| 中间操作 | 返回新的 Stream，不会立刻执行 | `filter`、`map`、`peek`、`sorted`、`limit`、`distinct` |
| 终止操作 | 触发整个 Stream 执行 | `collect`、`toList`、`forEach`、`count`、`findFirst`、`anyMatch` |

只有中间操作，没有终止操作时，代码不会真正执行。

```java
List<String> names = List.of("java", "python");

names.stream()
        .filter(s -> {
            System.out.println("filter: " + s);
            return s.length() > 2;
        });
```

这段代码不会打印任何内容，因为没有终止操作。

加上 `toList()` 后才会执行：

```java
List<String> result = names.stream()
        .filter(s -> {
            System.out.println("filter: " + s);
            return s.length() > 2;
        })
        .toList();
```

### 用 peek 看数据怎么流动

`peek` 常用于调试 Stream 中间过程。

```java
List<String> result = List.of("java", "go", "python").stream()
        .peek(s -> System.out.println("source: " + s))
        .filter(s -> s.length() > 2)
        .peek(s -> System.out.println("after filter: " + s))
        .map(s -> s.toUpperCase())
        .peek(s -> System.out.println("after map: " + s))
        .toList();
```

输出顺序类似：

```text
source: java
after filter: java
after map: JAVA
source: go
source: python
after filter: python
after map: PYTHON
```

注意 `go` 只打印了 `source`，因为它没有通过 `filter`，后面的 `peek` 和 `map` 都不会执行。

### filter 传递 Predicate

`filter` 接收的是 `Predicate<T>`。

```java
List<String> result = names.stream()
        .filter(s -> s.length() > 3)
        .toList();
```

等价理解：

```java
Predicate<String> predicate = s -> s.length() > 3;

for (String s : names) {
    if (predicate.test(s)) {
        // 通过的数据继续往后传
    }
}
```

`filter` 的作用是：

```text
true  -> 数据继续往后走
false -> 数据在这里被拦下
```

### map 传递 Function

`map` 接收的是 `Function<T, R>`。

```java
List<Integer> result = names.stream()
        .map(s -> s.length())
        .toList();
```

等价理解：

```java
Function<String, Integer> function = s -> s.length();

for (String s : names) {
    Integer value = function.apply(s);
    // 把转换后的 value 继续往后传
}
```

`map` 的作用是：

```text
把一个元素转换成另一个元素
```

例如：

```text
"java" -> 4
"go" -> 2
"python" -> 6
```

### forEach 传递 Consumer

`forEach` 接收的是 `Consumer<T>`，它是终止操作。

```java
names.stream()
        .filter(s -> s.length() > 2)
        .forEach(s -> System.out.println(s));
```

等价理解：

```java
Consumer<String> consumer = s -> System.out.println(s);

for (String s : names) {
    if (s.length() > 2) {
        consumer.accept(s);
    }
}
```

`forEach` 的作用是：

```text
消费最终流出来的数据，不再返回 Stream
```

### 一个完整的数据传递例子

```java
List<User> users = List.of(
        new User("张三", 20, true),
        new User("李四", 17, true),
        new User("王五", 30, false)
);

List<String> names = users.stream()
        .filter(user -> user.isActive())
        .filter(user -> user.getAge() >= 18)
        .map(user -> user.getName())
        .toList();
```

数据传递过程：

```text
张三 -> isActive 为 true  -> age >= 18 为 true  -> map 得到 "张三" -> 收集
李四 -> isActive 为 true  -> age >= 18 为 false -> 停止往后走
王五 -> isActive 为 false -> 停止往后走
```

最终结果：

```java
["张三"]
```

### limit 和短路

有些终止操作或中间操作会短路，也就是拿到足够结果后就不继续处理后面的数据。

```java
List<String> result = List.of("java", "go", "python", "js").stream()
        .filter(s -> s.length() > 2)
        .limit(1)
        .toList();
```

执行过程：

```text
"java" -> filter 通过 -> limit 收到第 1 个元素 -> 结束
```

后面的 `"go"`、`"python"`、`"js"` 不一定会继续执行。

常见短路操作：

| 方法 | 含义 |
|---|---|
| `limit(n)` | 只要前 n 个 |
| `findFirst()` | 找到第一个就结束 |
| `findAny()` | 找到任意一个就结束 |
| `anyMatch(...)` | 有一个满足就结束 |
| `allMatch(...)` | 有一个不满足就结束 |
| `noneMatch(...)` | 有一个满足就结束 |

### sorted 比较特殊

`sorted` 需要先拿到足够的数据才能排序，所以它不像 `filter`、`map` 那样简单地一个个直接往后传。

```java
List<String> result = List.of("java", "go", "python").stream()
        .filter(s -> s.length() > 2)
        .sorted()
        .toList();
```

大致过程：

```text
"java"   -> filter 通过 -> 进入 sorted 缓存
"go"     -> filter 不通过
"python" -> filter 通过 -> 进入 sorted 缓存
sorted 对 ["java", "python"] 排序
最后收集结果
```

类似需要先缓存再处理的操作：

| 方法 | 原因 |
|---|---|
| `sorted` | 需要拿到多个元素才能排序 |
| `distinct` | 需要记录已经出现过的元素 |

### Stream 不会修改原集合

```java
List<String> names = new ArrayList<>(List.of("java", "go"));

List<String> result = names.stream()
        .map(String::toUpperCase)
        .toList();

System.out.println(names);  // [java, go]
System.out.println(result); // [JAVA, GO]
```

`map` 产生的是新结果，不会把原集合里的 `"java"` 改成 `"JAVA"`。

### 常见误区

| 误区 | 正确理解 |
|---|---|
| `filter` 会立刻执行 | 不会，遇到终止操作才执行 |
| `map` 会修改原集合 | 不会，它产生转换后的新数据 |
| `peek` 适合写业务逻辑 | 不建议，主要用于调试 |
| Stream 一定比 for 循环快 | 不一定，Stream 更主要是表达数据处理流程 |
| 每一步都会处理完整集合 | 不一定，通常是元素逐个穿过管道，短路时会提前结束 |

### 记忆图

```text
数据源
  |
  v
stream()
  |
  v
filter(Predicate)  true 继续，false 丢弃
  |
  v
map(Function)      转换成新元素
  |
  v
peek(Consumer)     查看或调试
  |
  v
终止操作            toList / collect / forEach / count
```

## 12. 泛型接口继承

### 先记结论

泛型接口继承时，子接口有两种常见写法：

```text
1. 子接口继续保留泛型
2. 子接口继承时直接把泛型类型固定死
```

示例：

```java
interface Repository<T> {
    T findById(Long id);
}

// 继续保留泛型
interface BaseRepository<T> extends Repository<T> {
}

// 直接固定泛型类型
interface UserRepository extends Repository<User> {
}
```

### 1. 子接口继续保留泛型

```java
interface Converter<T, R> {
    R convert(T value);
}

interface StringConverter<R> extends Converter<String, R> {
}
```

这里 `StringConverter<R>` 固定了入参类型是 `String`，但返回值 `R` 继续交给子接口使用者决定。

使用：

```java
StringConverter<Integer> lengthConverter = s -> s.length();
Integer length = lengthConverter.convert("java"); // 4

StringConverter<Boolean> blankChecker = s -> s.isBlank();
Boolean blank = blankChecker.convert("");
```

等价理解：

```java
StringConverter<Integer>
```

相当于：

```java
Converter<String, Integer>
```

### 2. 子接口固定全部泛型

```java
interface Converter<T, R> {
    R convert(T value);
}

interface StringToIntegerConverter extends Converter<String, Integer> {
}
```

使用：

```java
StringToIntegerConverter converter = s -> Integer.parseInt(s);
Integer value = converter.convert("123");
```

此时抽象方法可以理解为：

```java
Integer convert(String value);
```

所以 Lambda 的参数是 `String`，返回值必须是 `Integer`。

### 3. 子接口增加自己的泛型

子接口可以继承父接口的泛型，也可以增加自己的泛型。

```java
interface Mapper<T, R> {
    R map(T value);
}

interface EntityMapper<ID, T, R> extends Mapper<T, R> {
    ID getId(T value);
}
```

使用：

```java
class User {
    private Long id;
    private String name;

    public Long getId() {
        return id;
    }

    public String getName() {
        return name;
    }
}

class UserNameMapper implements EntityMapper<Long, User, String> {
    @Override
    public String map(User user) {
        return user.getName();
    }

    @Override
    public Long getId(User user) {
        return user.getId();
    }
}
```

这里类型对应关系是：

```text
ID -> Long
T  -> User
R  -> String
```

### 4. 泛型接口实现类

实现泛型接口时，也有两种写法。

保留泛型：

```java
interface Repository<T> {
    T findById(Long id);
}

class MemoryRepository<T> implements Repository<T> {
    @Override
    public T findById(Long id) {
        return null;
    }
}
```

固定泛型：

```java
class UserRepository implements Repository<User> {
    @Override
    public User findById(Long id) {
        return new User();
    }
}
```

区别：

| 写法 | 含义 |
|---|---|
| `class MemoryRepository<T> implements Repository<T>` | 实现类继续是泛型类 |
| `class UserRepository implements Repository<User>` | 实现类只服务于 `User` |

### 5. 泛型函数式接口继承

函数式接口也可以使用泛型继承。

```java
@FunctionalInterface
interface Handler<T> {
    void handle(T value);
}

@FunctionalInterface
interface UserHandler extends Handler<User> {
}
```

使用：

```java
UserHandler handler = user -> System.out.println(user.getName());
handler.handle(new User());
```

`UserHandler` 固定了 `T` 是 `User`，所以它的方法可以理解为：

```java
void handle(User value);
```

### 6. 继承 Function

自定义函数式接口可以继承 JDK 的 `Function`。

```java
@FunctionalInterface
interface UserNameFunction extends Function<User, String> {
}
```

使用：

```java
UserNameFunction getName = user -> user.getName();
String name = getName.apply(user);
```

也可以写成方法引用：

```java
UserNameFunction getName = User::getName;
```

此时 `UserNameFunction` 本质上就是：

```java
Function<User, String>
```

只是名字更贴近业务。

### 7. 继承 Predicate

```java
@FunctionalInterface
interface UserPredicate extends Predicate<User> {
}
```

使用：

```java
UserPredicate adult = user -> user.getAge() >= 18;
boolean result = adult.test(user);
```

等价理解：

```java
Predicate<User> adult = user -> user.getAge() >= 18;
```

### 8. 继承时不要增加新的抽象方法

函数式接口只能有一个抽象方法。

```java
@FunctionalInterface
interface UserHandler extends Consumer<User> {
    // 可以添加 default 方法
    default void handleWithLog(User user) {
        System.out.println("handle user");
        accept(user);
    }
}
```

这样可以，因为 `handleWithLog` 是 `default` 方法，不算新的抽象方法。

下面这样不行：

```java
@FunctionalInterface
interface BadUserHandler extends Consumer<User> {
    void anotherHandle(User user); // 错：新增了第二个抽象方法
}
```

原因是 `Consumer<User>` 已经有一个抽象方法：

```java
void accept(User user);
```

再加一个 `anotherHandle`，就不再是函数式接口了。

### 9. 泛型继承常见场景

| 场景 | 写法 |
|---|---|
| 通用仓储接口 | `interface Repository<T>` |
| 用户仓储接口 | `interface UserRepository extends Repository<User>` |
| 通用转换接口 | `interface Converter<T, R>` |
| 字符串转换接口 | `interface StringConverter<R> extends Converter<String, R>` |
| 用户判断接口 | `interface UserPredicate extends Predicate<User>` |
| 用户名提取接口 | `interface UserNameFunction extends Function<User, String>` |

### 10. 快速判断

```text
父接口泛型还不确定 -> 子接口继续写 <T>
父接口泛型已经明确 -> extends 时直接写具体类型
想让接口语义更清楚 -> 可以继承 Function / Predicate / Consumer 起业务名字
函数式接口继承 -> 不能新增第二个抽象方法
```

## 13. 快速判断方法

看到一个 Lambda，按下面顺序判断：

```text
1. 有没有参数？
2. 有没有返回值？
3. 返回值是不是 boolean？
4. 参数和返回值类型是不是一样？
5. 是一个参数还是两个参数？
```

对应关系：

```text
无参数 + 有返回值      => Supplier
有参数 + 无返回值      => Consumer
有参数 + 返回 boolean  => Predicate
有参数 + 有返回值      => Function
同类型转换             => UnaryOperator
两个同类型合成一个同类型 => BinaryOperator
两个参数               => BiXxx
```

## 14. 一张总表

| 场景 | 优先想到 |
|---|---|
| 对象转换 | `Function<T, R>` |
| 打印、保存、发送消息 | `Consumer<T>` |
| 延迟创建对象 | `Supplier<T>` |
| 条件过滤、校验 | `Predicate<T>` |
| 一个值变成同类型另一个值 | `UnaryOperator<T>` |
| 两个同类型值合并成一个 | `BinaryOperator<T>` |
| 两个参数转一个结果 | `BiFunction<T, U, R>` |
| 两个参数只处理不返回 | `BiConsumer<T, U>` |
| 两个参数做判断 | `BiPredicate<T, U>` |
