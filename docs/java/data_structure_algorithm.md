# 数据结构与算法面试高频

## 时间复杂度和空间复杂度

### 一句话秒答

时间复杂度看算法运行次数随数据规模增长的趋势，空间复杂度看额外内存随数据规模增长的趋势。面试里重点会问 `O(1)`、`O(log n)`、`O(n)`、`O(n log n)`、`O(n^2)`。

### 经典案例（代码）

```java
for (int i = 0; i < n; i++) {
    System.out.println(i); // O(n)
}

for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
        System.out.println(i + j); // O(n^2)
    }
}
```

### 高频坑

- 只保留最高阶，`O(2n)` 记作 `O(n)`。
- 二分查找是 `O(log n)`，前提是数据有序。
- 递归要同时考虑调用次数和递归栈空间。

### 面试追问

- 为什么忽略常数项？  
  因为复杂度关注增长趋势，不关注固定倍数。
- `O(1)` 一定最快吗？  
  理论增长最稳定，但实际性能还受常数、IO、缓存等影响。

## 数组和链表区别

### 一句话秒答

数组内存连续，支持下标随机访问，查询快；链表内存不连续，插入删除节点方便，但查找需要遍历。大多数按下标读的场景优先数组或 `ArrayList`。

### 经典案例（代码）

```java
int[] nums = {1, 2, 3};
System.out.println(nums[1]); // O(1)
```

### 高频坑

- 链表不是所有插入删除都快，找到位置本身也要成本。
- 数组扩容通常要创建新数组并复制元素。
- 链表节点额外存指针，空间开销更高。

### 面试追问

- `ArrayList` 和数组有什么关系？  
  `ArrayList` 底层就是动态数组。
- `LinkedList` 为什么随机访问慢？  
  因为它要从头或尾逐个节点遍历。

## 栈和队列

### 一句话秒答

栈是先进后出，常用于括号匹配、递归、撤销；队列是先进先出，常用于 BFS、任务排队。Java 里栈和队列优先用 `Deque`，少用老的 `Stack`。

### 经典案例（代码）

```java
Deque<Integer> stack = new ArrayDeque<>();
stack.push(1);
stack.push(2);
System.out.println(stack.pop()); // 2

Queue<Integer> queue = new ArrayDeque<>();
queue.offer(1);
queue.offer(2);
System.out.println(queue.poll()); // 1
```

### 高频坑

- `Stack` 是老类，通常用 `ArrayDeque` 替代。
- 队列空时 `poll()` 返回 `null`，`remove()` 会抛异常。
- BFS 通常用队列，DFS 通常用栈或递归。

### 面试追问

- 栈为什么能做括号匹配？  
  因为最近打开的括号必须最先闭合，符合后进先出。
- 队列为什么适合 BFS？  
  因为 BFS 按层访问，先入队的节点先处理。

## 哈希表

### 一句话秒答

哈希表通过 key 的 hash 值快速定位存储位置，平均查询、插入、删除都是 `O(1)`。Java 里最常见实现是 `HashMap`。

### 经典案例（代码）

```java
Map<String, Integer> map = new HashMap<>();
map.put("Tom", 18);
System.out.println(map.get("Tom")); // O(1) 平均
```

### 高频坑

- 哈希冲突不可避免，冲突后要用链表或红黑树处理。
- `hashCode()` 相同不代表对象相等。
- 自定义 key 必须正确重写 `equals()` 和 `hashCode()`。

### 面试追问

- 为什么哈希表查询平均是 `O(1)`？  
  因为 hash 能直接定位桶，冲突少时不用遍历太多元素。
- 最坏情况为什么会退化？  
  因为大量 key 落到同一个桶，可能需要遍历链表或树。

## 二叉树和二叉搜索树

### 一句话秒答

二叉树是每个节点最多两个子节点；二叉搜索树要求左子树小于根节点，右子树大于根节点。二叉搜索树中序遍历可以得到有序结果。

### 经典案例（代码）

```java
void inorder(TreeNode root) {
    if (root == null) return;
    inorder(root.left);
    System.out.println(root.val);
    inorder(root.right);
}
```

### 高频坑

- 普通二叉树没有大小顺序。
- 二叉搜索树退化成链表时查询会变成 `O(n)`。
- 平衡二叉搜索树才能稳定保持较好查询效率。

### 面试追问

- 中序遍历二叉搜索树为什么有序？  
  因为访问顺序是左子树、根、右子树。
- 红黑树解决什么问题？  
  通过近似平衡避免搜索树退化成链表。

## 二叉树遍历

### 一句话秒答

二叉树常见遍历有前序、中序、后序和层序。前中后序通常用递归或栈，层序通常用队列。

### 经典案例（代码）

```java
void preorder(TreeNode root) {
    if (root == null) return;
    System.out.println(root.val);
    preorder(root.left);
    preorder(root.right);
}
```

### 高频坑

- 前序是根左右，中序是左根右，后序是左右根。
- 二叉搜索树中序遍历才有序，普通二叉树不保证。
- 层序遍历用队列，不是栈。

### 面试追问

- 层序遍历为什么用队列？  
  因为要按进入顺序逐层处理节点，符合先进先出。
- 递归遍历的空间复杂度是多少？  
  取决于树高，平衡树约 `O(log n)`，最坏退化为 `O(n)`。

## 平衡二叉树

### 一句话秒答

平衡二叉树是左右子树高度差受限制的二叉搜索树，常见说法是任意节点左右子树高度差不超过 1。它的目的就是避免普通二叉搜索树退化成链表。

### 经典案例（代码）

```java
int height(TreeNode root) {
    if (root == null) return 0;
    return Math.max(height(root.left), height(root.right)) + 1;
}
```

### 高频坑

- 平衡二叉树首先通常是二叉搜索树，再强调高度平衡。
- 平衡不是左右节点数量完全一样，而是高度差受限制。
- 插入删除后可能需要旋转来恢复平衡。

### 面试追问

- 平衡二叉树解决什么问题？  
  避免搜索树退化成链表，让查询保持接近 `O(log n)`。
- 为什么维护平衡有成本？  
  因为插入删除后可能要计算高度并做旋转调整。

## 红黑树

### 一句话秒答

红黑树是一种近似平衡的二叉搜索树，通过红黑颜色规则控制树高，让查询、插入、删除都保持 `O(log n)`。Java 里的 `TreeMap`、`TreeSet`、JDK8 后 `HashMap` 桶树化都用到红黑树。

### 经典案例（代码）

```java
TreeMap<Integer, String> map = new TreeMap<>();
map.put(2, "b");
map.put(1, "a");
map.put(3, "c");
System.out.println(map.keySet()); // [1, 2, 3]
```

### 高频坑

- 红黑树不是严格平衡树，而是近似平衡。
- 红黑树查询不一定比链表在小数据量下快，因为维护和节点结构更复杂。
- `HashMap` 不是默认全用红黑树，只有桶冲突严重且满足条件才树化。

### 面试追问

- 红黑树为什么不追求绝对平衡？  
  绝对平衡维护成本高，红黑树用近似平衡换取更好的综合性能。
- 为什么 HashMap 不直接全部用红黑树？  
  链表节点少时更简单、维护成本更低，大多数 hash 分布均匀时不需要红黑树。

## AVL 树和红黑树区别

### 一句话秒答

AVL 树更严格平衡，查询更稳定；红黑树是近似平衡，插入删除调整成本通常更低。读多写少偏 AVL，读写都多常见红黑树。

### 经典案例（场景）

```text
数据库或语言库里的通用有序集合，通常更偏向红黑树。
需要极致查询稳定性的场景，可以考虑 AVL 树。
```

### 高频坑

- AVL 树不是红黑树，它比红黑树更严格平衡。
- 红黑树不保证左右高度差不超过 1。
- 面试一般不要求手写红黑树旋转细节，重点说清取舍。

### 面试追问

- 为什么 Java TreeMap 用红黑树？  
  因为红黑树在查询、插入、删除之间综合表现更均衡。
- AVL 查询为什么可能更快？  
  因为树更矮、更严格平衡，查找路径更稳定。

## B 树和 B+ 树

### 一句话秒答

B 树和 B+ 树都是多路平衡搜索树，常用于磁盘索引。B+ 树的数据主要在叶子节点，叶子节点之间有链表，更适合范围查询，所以数据库索引常用 B+ 树。

### 经典案例（场景）

```text
MySQL InnoDB 索引常说 B+ 树：
按主键查询可以走树高很低的索引路径；
范围查询可以在叶子节点链表上顺序扫描。
```

### 高频坑

- B+ 树不是二叉树，是多路搜索树。
- B+ 树非叶子节点主要存索引，叶子节点存数据或数据指针。
- B+ 树适合磁盘 IO 场景，因为树高低、范围查询友好。

### 面试追问

- 为什么数据库不用普通二叉搜索树做索引？  
  二叉树高度更高，磁盘 IO 次数更多，不适合大规模磁盘索引。
- B+ 树为什么适合范围查询？  
  因为叶子节点有序并通过链表连接，可以顺序扫描。

## 判断一棵树是否平衡

### 一句话秒答

判断一棵树是否平衡，核心是看每个节点左右子树高度差是否超过 1。最优写法是递归计算高度时顺便判断，一旦不平衡就提前返回。

### 经典案例（代码）

```java
int check(TreeNode root) {
    if (root == null) return 0;
    int left = check(root.left);
    if (left == -1) return -1;
    int right = check(root.right);
    if (right == -1) return -1;
    if (Math.abs(left - right) > 1) return -1;
    return Math.max(left, right) + 1;
}

boolean isBalanced(TreeNode root) {
    return check(root) != -1;
}
```

### 高频坑

- 不要每个节点都重复计算高度，否则可能退化到 `O(n^2)`。
- 平衡判断要对每个节点成立，不只是根节点成立。
- 空树通常认为是平衡树。

### 面试追问

- 这个优化写法为什么是 `O(n)`？  
  因为每个节点只被访问一次。
- 为什么用 `-1`？  
  作为哨兵值表示子树已经不平衡，后续可以提前结束。

## 堆和优先队列

### 一句话秒答

堆是一种完全二叉树结构，常用于快速取最大值或最小值。Java 的 `PriorityQueue` 默认是小顶堆。

### 经典案例（代码）

```java
PriorityQueue<Integer> heap = new PriorityQueue<>();
heap.offer(3);
heap.offer(1);
heap.offer(2);
System.out.println(heap.poll()); // 1
```

### 高频坑

- `PriorityQueue` 不是普通 FIFO 队列，而是按优先级出队。
- 默认小顶堆，要大顶堆需要自定义比较器。
- 堆只能快速拿到堆顶，不适合直接查找任意元素。

### 面试追问

- Top K 问题为什么常用堆？  
  因为可以用大小为 K 的堆维护当前最优 K 个元素。
- `PriorityQueue` 是线程安全的吗？  
  不是，线程安全优先队列可看 `PriorityBlockingQueue`。

## 排序算法

### 一句话秒答

面试常问冒泡、选择、插入、归并、快速排序。重点记住：快排平均 `O(n log n)`，最坏 `O(n^2)`；归并稳定但需要额外空间。

### 经典案例（代码）

```java
Arrays.sort(nums); // 面试写业务代码时优先用标准库
```

### 高频坑

- 稳定排序表示相等元素排序前后相对顺序不变。
- 快排不是稳定排序。
- 归并排序稳定，但通常需要 `O(n)` 额外空间。

### 面试追问

- Java 里为什么业务代码优先用 `Arrays.sort()`？  
  标准库成熟、边界处理好，不要手写重复轮子。
- 快排最坏情况什么时候出现？  
  pivot 选择很差，导致划分极度不均衡。

## 二分查找

### 一句话秒答

二分查找用于有序数组，每次排除一半数据，时间复杂度是 `O(log n)`。核心是处理好左右边界和循环条件。

### 经典案例（代码）

```java
int binarySearch(int[] nums, int target) {
    int left = 0, right = nums.length - 1;
    while (left <= right) {
        int mid = left + (right - left) / 2;
        if (nums[mid] == target) return mid;
        if (nums[mid] < target) left = mid + 1;
        else right = mid - 1;
    }
    return -1;
}
```

### 高频坑

- 数据必须有序。
- `mid = (left + right) / 2` 可能整数溢出，推荐 `left + (right - left) / 2`。
- 查找第一个或最后一个位置时，边界处理不同。

### 面试追问

- 二分为什么是 `O(log n)`？  
  因为每次都把搜索范围缩小一半。
- 二分只能用于数组吗？  
  不一定，但需要能高效访问中间元素，链表不适合。

## 双指针和滑动窗口

### 一句话秒答

双指针常用于有序数组、链表、区间问题；滑动窗口常用于连续子数组或字符串窗口问题。它们的核心都是减少重复遍历，把很多 `O(n^2)` 问题优化到 `O(n)`。

### 经典案例（代码）

```java
int left = 0, sum = 0;
for (int right = 0; right < nums.length; right++) {
    sum += nums[right];
    while (sum > target) {
        sum -= nums[left++];
    }
}
```

### 高频坑

- 滑动窗口通常要求窗口连续。
- 左右指针移动条件要明确，否则容易死循环。
- 有负数时，很多基于和的滑动窗口不再适用。

### 面试追问

- 双指针为什么能降复杂度？  
  因为每个指针通常最多移动 n 次。
- 滑动窗口适合什么题？  
  连续子数组、最长/最短子串、固定窗口统计。

## 递归和动态规划

### 一句话秒答

递归是函数自己调用自己，适合树、回溯、分治问题；动态规划是把大问题拆成重叠子问题，用状态转移避免重复计算。

### 经典案例（代码）

```java
int fib(int n) {
    if (n <= 1) return n;
    int[] dp = new int[n + 1];
    dp[1] = 1;
    for (int i = 2; i <= n; i++) {
        dp[i] = dp[i - 1] + dp[i - 2];
    }
    return dp[n];
}
```

### 高频坑

- 递归必须有结束条件。
- 递归层数太深会栈溢出。
- 动态规划重点是状态定义和状态转移，不是死背模板。

### 面试追问

- 递归和迭代怎么选？  
  递归表达更自然时可用，但要注意栈深度；性能敏感时常改迭代。
- 动态规划和贪心区别？  
  动态规划考虑全局最优子结构，贪心每一步选择当前最优。

## DFS 和 BFS

### 一句话秒答

DFS 是深度优先，沿一条路径走到底再回溯；BFS 是广度优先，一层一层向外扩展。DFS 常用递归或栈，BFS 常用队列。

### 经典案例（代码）

```java
void dfs(TreeNode root) {
    if (root == null) return;
    dfs(root.left);
    dfs(root.right);
}

void bfs(TreeNode root) {
    Queue<TreeNode> queue = new ArrayDeque<>();
    if (root != null) queue.offer(root);
    while (!queue.isEmpty()) {
        TreeNode node = queue.poll();
        if (node.left != null) queue.offer(node.left);
        if (node.right != null) queue.offer(node.right);
    }
}
```

### 高频坑

- DFS 递归要注意栈溢出。
- BFS 要防止重复访问，图题通常需要 `visited`。
- 最短路径如果每条边权重相同，BFS 更适合。

### 面试追问

- BFS 为什么能求无权图最短路径？  
  因为它按层扩展，第一次到达目标就是最短步数。
- DFS 适合什么题？  
  树遍历、连通性、回溯搜索、路径枚举。

## 回溯算法

### 一句话秒答

回溯就是试探 + 撤销选择，适合排列、组合、子集、棋盘搜索这类需要枚举所有可能的题。核心模板是选择、递归、撤销选择。

### 经典案例（代码）

```java
void backtrack(List<Integer> path, boolean[] used, int[] nums) {
    if (path.size() == nums.length) {
        System.out.println(path);
        return;
    }
    for (int i = 0; i < nums.length; i++) {
        if (used[i]) continue;
        used[i] = true;
        path.add(nums[i]);
        backtrack(path, used, nums);
        path.remove(path.size() - 1);
        used[i] = false;
    }
}
```

### 高频坑

- 递归后必须撤销选择，否则状态会污染其他分支。
- 组合题通常用 `start` 控制不重复选择。
- 有重复元素时要排序并剪枝。

### 面试追问

- 回溯和 DFS 什么关系？  
  回溯通常是 DFS 的一种应用，重点在撤销状态。
- 剪枝有什么用？  
  提前排除不可能的分支，减少搜索量。

## 贪心算法

### 一句话秒答

贪心算法每一步都选择当前最优，希望最终得到全局最优。它适合有明确局部最优策略且能证明不会影响全局最优的题。

### 经典案例（代码）

```java
Arrays.sort(intervals, Comparator.comparingInt(a -> a[1]));
int count = 0;
int end = Integer.MIN_VALUE;
for (int[] interval : intervals) {
    if (interval[0] >= end) {
        count++;
        end = interval[1];
    }
}
```

### 高频坑

- 贪心不是凭感觉选最大或最小，必须能说明策略正确。
- 贪心不一定得到全局最优，很多题要用动态规划。
- 区间题常见贪心策略是按结束时间排序。

### 面试追问

- 贪心和动态规划怎么区分？  
  贪心只做当前最优选择，动态规划会保存子问题状态。
- 贪心为什么常要排序？  
  排序后才能稳定执行某个局部最优策略。

## 前缀和

### 一句话秒答

前缀和用一个数组提前保存从开头到当前位置的累计和，让区间求和从 `O(n)` 变成 `O(1)`。常用于数组区间和、子数组和问题。

### 经典案例（代码）

```java
int[] prefix = new int[nums.length + 1];
for (int i = 0; i < nums.length; i++) {
    prefix[i + 1] = prefix[i] + nums[i];
}

int sum = prefix[right + 1] - prefix[left];
```

### 高频坑

- 前缀和数组通常多开一位，减少边界判断。
- 求 `[left, right]` 区间和时是 `prefix[right + 1] - prefix[left]`。
- 有负数的连续子数组问题，滑动窗口不一定适用，前缀和更常用。

### 面试追问

- 为什么前缀和能 O(1) 求区间和？  
  因为区间和可以由两个累计和相减得到。
- 二维矩阵能用前缀和吗？  
  可以，二维前缀和用于快速求子矩阵和。

## 差分数组

### 一句话秒答

差分数组适合频繁做区间加减，最后一次性还原结果。它把区间更新从逐个修改 `O(n)` 优化成只改两个边界 `O(1)`。

### 经典案例（代码）

```java
int[] diff = new int[n + 1];

// 区间 [l, r] 加 val
diff[l] += val;
diff[r + 1] -= val;

int cur = 0;
for (int i = 0; i < n; i++) {
    cur += diff[i];
    nums[i] += cur;
}
```

### 高频坑

- 差分适合多次区间更新，不适合频繁实时查询。
- 右边界 `r + 1` 要防止越界。
- 最后要做一次前缀累加还原。

### 面试追问

- 差分和前缀和是什么关系？  
  差分是前缀和的逆操作。
- 什么场景用差分？  
  多次区间加减、航班预订、区间覆盖统计。

## 并查集

### 一句话秒答

并查集用来处理集合合并和连通性查询，核心操作是 `find` 和 `union`。常用于朋友圈、岛屿数量、冗余连接、最小生成树。

### 经典案例（代码）

```java
int find(int[] parent, int x) {
    if (parent[x] != x) {
        parent[x] = find(parent, parent[x]);
    }
    return parent[x];
}

void union(int[] parent, int a, int b) {
    int rootA = find(parent, a);
    int rootB = find(parent, b);
    if (rootA != rootB) {
        parent[rootA] = rootB;
    }
}
```

### 高频坑

- `find` 要做路径压缩，否则链太长会变慢。
- 初始化时每个节点的父节点是自己。
- 并查集适合动态合并，不适合枚举具体路径。

### 面试追问

- 路径压缩有什么用？  
  把节点直接挂到根节点下，后续查询更快。
- 并查集能判断两个点是否连通吗？  
  能，只要看它们的根节点是否相同。

## LRU 缓存

### 一句话秒答

LRU 是最近最少使用缓存，淘汰最长时间没被访问的数据。Java 里最简单实现可以用 `LinkedHashMap` 的访问顺序模式。

### 经典案例（代码）

```java
class LruCache<K, V> extends LinkedHashMap<K, V> {
    private final int capacity;

    LruCache(int capacity) {
        super(capacity, 0.75f, true);
        this.capacity = capacity;
    }

    protected boolean removeEldestEntry(Map.Entry<K, V> eldest) {
        return size() > capacity;
    }
}
```

### 高频坑

- `LinkedHashMap` 默认是插入顺序，不是访问顺序。
- LRU 要在构造方法里把 `accessOrder` 设置为 `true`。
- `LinkedHashMap` 本身不是线程安全的。

### 面试追问

- LRU 为什么要用哈希表 + 双向链表？  
  哈希表负责 O(1) 查找，双向链表负责 O(1) 调整访问顺序。
- `removeEldestEntry` 什么时候触发？  
  插入新元素后由 `LinkedHashMap` 自动判断是否删除最老元素。

## Top K 问题

### 一句话秒答

Top K 常用堆解决。求最大的 K 个数，用大小为 K 的小顶堆；堆顶保存当前 Top K 里最小的数。

### 经典案例（代码）

```java
PriorityQueue<Integer> heap = new PriorityQueue<>();
for (int num : nums) {
    heap.offer(num);
    if (heap.size() > k) {
        heap.poll();
    }
}
```

### 高频坑

- 求最大 K 个用小顶堆，求最小 K 个用大顶堆。
- 堆大小保持 K，复杂度是 `O(n log k)`。
- 如果只求第 K 大，也可以用快速选择。

### 面试追问

- 为什么不用排序？  
  排序是 `O(n log n)`，堆可以做到 `O(n log k)`。
- K 很接近 n 时堆还有优势吗？  
  优势会变小，直接排序可能更简单。
