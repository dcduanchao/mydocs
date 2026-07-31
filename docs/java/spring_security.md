# Spring Security、JWT 与 OAuth2

## 1. 安全体系解决什么问题

应用安全至少包括：

- **认证 Authentication**：确认调用者是谁。
- **授权 Authorization**：确认调用者能做什么。
- **会话管理**：保存、续期和撤销登录状态。
- **攻击防护**：CSRF、会话固定、暴力破解和凭据泄露。
- **审计**：记录谁在何时访问或修改了什么。

Spring Security 提供认证、授权和 Web 安全框架；JWT 是一种 Token 格式；OAuth2 是授权框架；OpenID Connect（OIDC）是在 OAuth2 之上的身份认证协议。四者不能混为一谈。

```text
Spring Security：应用安全框架
JWT：可签名的声明载体
OAuth2：委托授权协议
OIDC：基于 OAuth2 的登录认证协议
```

## 2. Spring Security 核心组件

| 组件 | 作用 |
|---|---|
| SecurityFilterChain | 定义请求匹配、认证方式和授权规则。 |
| SecurityContext | 保存当前请求的 Authentication。 |
| Authentication | 主体、凭据、权限和认证状态。 |
| AuthenticationManager | 接收认证请求并协调 Provider。 |
| AuthenticationProvider | 执行某类认证，例如用户名密码。 |
| UserDetailsService | 按用户名加载账号。 |
| PasswordEncoder | 密码哈希与校验。 |
| GrantedAuthority | 角色或权限标识。 |
| AccessDecision | 根据认证和规则决定是否允许访问。 |

Servlet 请求主要经过 `FilterChainProxy` 中匹配的 SecurityFilterChain：

```text
请求 -> 安全过滤器链 -> 提取凭据 -> AuthenticationManager
    -> AuthenticationProvider -> SecurityContext
    -> AuthorizationFilter -> Controller
```

过滤器顺序有安全含义。自定义认证过滤器应放在正确位置，并只处理明确的请求，不能无差别吞掉异常或覆盖已有 SecurityContext。

## 3. Spring Boot 3 基础配置

Spring Security 6 使用 Bean 和 Lambda DSL：

```java
@Configuration(proxyBeanMethods = false)
@EnableMethodSecurity
public class SecurityConfiguration {

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http)
            throws Exception {
        return http
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/actuator/health/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/articles/**")
                            .hasAuthority("article:read")
                        .requestMatchers("/api/admin/**").hasRole("ADMIN")
                        .anyRequest().authenticated())
                .formLogin(Customizer.withDefaults())
                .logout(logout -> logout.logoutSuccessUrl("/login"))
                .build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return PasswordEncoderFactories.createDelegatingPasswordEncoder();
    }
}
```

`hasRole("ADMIN")` 默认检查 `ROLE_ADMIN`，`hasAuthority("article:read")` 精确检查权限字符串。项目应统一角色和权限命名，避免一部分带 `ROLE_`、一部分不带。

多个 SecurityFilterChain 使用 `securityMatcher` 和 `@Order` 划分，例如管理后台使用 Session，开放 API 使用 Bearer Token。必须保证请求只落入预期链，并为兜底链配置默认拒绝或认证规则。

## 4. 密码认证

### 4.1 密码只能哈希保存

```java
String encoded = passwordEncoder.encode(rawPassword);
boolean matches = passwordEncoder.matches(rawPassword, encoded);
```

密码使用 BCrypt、Argon2、PBKDF2、SCrypt 等自适应单向哈希，不能明文保存，也不能使用 MD5、SHA-1 或普通 SHA-256 直接哈希。

DelegatingPasswordEncoder 保存类似 `{bcrypt}...` 的算法标识，便于逐步升级哈希算法。用户成功登录时可以判断 `upgradeEncoding` 并重新哈希。

### 4.2 登录防护

- 对账号、IP、设备和接口进行分层限流。
- 连续失败使用递增延迟、验证码或临时锁定。
- 错误响应不要区分“账号不存在”和“密码错误”。
- 管理员和高风险操作启用 MFA。
- 修改密码后撤销已有 Refresh Token 或会话。
- 密码重置链接一次性、短时有效并绑定用途。

账号锁定也可能被用于恶意拒绝服务，不能只用“失败 N 次永久锁定”。

## 5. Session 与 Cookie

传统服务端会话流程：

```text
登录成功 -> 服务端保存 Session -> 浏览器保存 Session Cookie
后续请求 -> Cookie -> 查找 Session -> 恢复认证状态
```

Cookie 建议：

```yaml
server:
  servlet:
    session:
      cookie:
        http-only: true
        secure: true
        same-site: lax
      timeout: 30m
```

- `HttpOnly` 降低 JavaScript 直接读取 Cookie 的风险。
- `Secure` 只通过 HTTPS 发送。
- `SameSite` 降低部分跨站请求风险，但不能替代完整 CSRF 防护。
- 登录后 Spring Security 默认会防护 Session Fixation。

集群会话可以使用负载均衡粘性、Spring Session + Redis，或让网关统一处理。Redis 会话仍要配置 TTL、高可用和序列化兼容。

## 6. CSRF 与 CORS

### 6.1 CSRF

CSRF 利用浏览器自动携带 Cookie 的行为，诱导已登录用户发送非本人意愿的请求。

使用 Cookie Session 的浏览器应用应保留 CSRF Token 防护。纯 Bearer Token API 如果 Token 只由客户端显式放入 Authorization Header，通常可以关闭 CSRF：

```java
http
    .csrf(csrf -> csrf.disable())
    .sessionManagement(session -> session
        .sessionCreationPolicy(SessionCreationPolicy.STATELESS));
```

如果 JWT 放在 Cookie 中，浏览器仍会自动携带，不能因为格式是 JWT 就直接关闭 CSRF。

### 6.2 CORS

CORS 是浏览器跨域读取响应的规则，不是服务端认证授权机制。

```java
@Bean
CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("https://app.example.com"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    config.setAllowCredentials(true);

    UrlBasedCorsConfigurationSource source =
            new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```

允许 Credentials 时不能使用通配符 Origin。生产环境使用明确域名，不把反射请求 Origin 当成允许策略。

## 7. JWT 原理

JWT 通常由三部分组成：

```text
Base64Url(Header).Base64Url(Payload).Signature
```

```json
{
  "alg": "RS256",
  "kid": "key-2026-01",
  "typ": "JWT"
}
```

```json
{
  "iss": "https://auth.example.com",
  "sub": "user-1001",
  "aud": ["order-api"],
  "scope": "order:read order:write",
  "iat": 1785376800,
  "exp": 1785377100,
  "jti": "unique-token-id"
}
```

JWT Payload 只是 Base64Url 编码，不是加密。任何拿到 Token 的人都能读取声明，不能保存密码、身份证、银行卡和内部敏感信息。

### 7.1 签名算法

- HMAC：签发和验证共享同一密钥，适合单体或严格受控服务。
- RSA/ECDSA：认证服务持有私钥签发，资源服务使用公钥验证，更适合微服务。

资源服务必须限制允许算法，不能信任 Header 任意指定算法。密钥需要足够强度、受控存储、定期轮换，并使用 `kid` 和 JWKS 支持多把公钥过渡。

### 7.2 必须验证的声明

- 签名和允许的算法。
- `iss` 签发者。
- `aud` 是否包含当前 API。
- `exp` 是否过期。
- `nbf` 是否已经生效。
- 必要时校验 `jti`、账号状态、Token Version。
- 只允许很小的时钟偏差，并保证服务器时间同步。

只验证签名和过期时间不够。错误的 Audience 校验可能让发给 A 系统的 Token 被 B 系统接受。

## 8. Spring Security JWT Resource Server

依赖：

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
</dependency>
```

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com
```

```java
@Bean
SecurityFilterChain apiSecurity(HttpSecurity http) throws Exception {
    return http
            .securityMatcher("/api/**")
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session
                    .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                    .requestMatchers("/api/public/**").permitAll()
                    .anyRequest().authenticated())
            .oauth2ResourceServer(resource -> resource
                    .jwt(Customizer.withDefaults()))
            .build();
}
```

使用 `issuer-uri` 时，资源服务会发现授权服务器元数据和 JWKS，并验证 Issuer。生产环境还要配置 Audience Validator，并明确如何把 `scope`、`roles` 等 Claims 转为 GrantedAuthority。

```java
@PreAuthorize("hasAuthority('SCOPE_order:write')")
public void createOrder(CreateOrderCommand command) {
}
```

Spring Resource Server 默认常把 Scope 映射为 `SCOPE_` 前缀权限。自定义 Claim 转换时不要让客户端可控 Claim 直接获得管理员权限。

## 9. Access Token 与 Refresh Token

| Token | 用途 | 建议特征 |
|---|---|---|
| Access Token | 调用资源 API | 短期有效、Audience 明确。 |
| Refresh Token | 换取新 Access Token | 更长有效、仅发送给授权服务器。 |

Refresh Token 不应发送到普通业务 API。推荐 Refresh Token Rotation：每次刷新发放新 Token 并作废旧 Token；旧 Token 再次使用时视为泄露，撤销整个 Token Family。

JWT Access Token 的即时撤销是权衡问题：

- 使用短 TTL，等待自然过期。
- 保存账号 Token Version，关键请求额外检查。
- 使用 `jti` 黑名单，但会引入状态与查询成本。
- 对高风险系统使用不透明 Token + Introspection。

“完全无状态”和“立即撤销”通常不能同时达到。退出登录至少要删除客户端凭据，并按业务风险决定是否服务端撤销 Refresh Token 和 Access Token。

## 10. 浏览器如何保存 Token

| 位置 | 主要风险 |
|---|---|
| localStorage | XSS 可以读取并带走 Token。 |
| HttpOnly Cookie | JavaScript 不可读取，但浏览器自动携带，需要 CSRF 防护。 |
| 内存 | 刷新页面丢失，仍可能被恶意脚本代发请求。 |

不存在脱离威胁模型的“绝对最佳位置”。浏览器应用优先评估 BFF：浏览器只持有安全 Session Cookie，BFF 在服务端保存或交换 Token，减少 Token 暴露给 JavaScript。

任何方案都必须部署 CSP、输出编码、依赖安全、HTTPS 和 XSS 防护。

## 11. OAuth2 角色与流程

| 角色 | 含义 |
|---|---|
| Resource Owner | 资源所有者，通常是用户。 |
| Client | 请求授权的应用。 |
| Authorization Server | 登录、授权并签发 Token。 |
| Resource Server | 验证 Token 并提供 API。 |

### 11.1 Authorization Code + PKCE

适合浏览器、移动端和服务端 Web 登录：

```text
客户端生成 code_verifier 和 code_challenge
  -> 浏览器跳转授权服务器登录并授权
  -> 回调获得一次性 authorization_code
  -> 客户端携带 code_verifier 换 Token
```

必须校验精确 Redirect URI 和 `state`。OIDC 还要校验 `nonce`、ID Token 的 Issuer、Audience、签名和时间声明。

Implicit Flow 与 Resource Owner Password Credentials 不适合新系统。不要让第三方客户端直接收集用户密码。

### 11.2 Client Credentials

适合没有用户参与的服务间调用：

```text
服务 A 使用自身 Client 凭据 -> Authorization Server
    -> 获取只代表服务 A 的 Access Token
    -> 调用服务 B
```

Client Credentials Token 不代表终端用户。如果调用链需要用户身份，应使用 Token Relay、Token Exchange 或业务授权上下文，并限制跨服务传播范围。

### 11.3 OIDC

OIDC 在 OAuth2 之上增加身份层：

- ID Token：向 Client 说明用户登录身份，不用于调用普通资源 API。
- UserInfo Endpoint：获取用户声明。
- Discovery：发布端点和能力元数据。
- Logout、Session 等扩展能力。

Access Token 发给 Resource Server，ID Token 发给 Client。把 ID Token 当 API Bearer Token 是常见错误。

## 12. 方法级授权与数据权限

```java
@PreAuthorize("hasAuthority('order:read') and #userId == authentication.name")
public OrderDetail getOrder(String userId, long orderId) {
}
```

复杂数据权限不要全部塞进 SpEL。可以调用专门授权 Bean：

```java
@PreAuthorize("@orderAuthorization.canRead(authentication, #orderId)")
public OrderDetail getOrder(long orderId) {
}
```

接口权限和数据权限不同：拥有 `order:read` 不代表可以读取所有租户订单。数据库查询本身应带租户或所有者条件，避免先查出敏感数据再在内存判断。

前端按钮隐藏只改善体验，不构成授权。所有敏感操作必须服务端校验。

## 13. 异常响应

未认证应返回 401，已认证但权限不足返回 403：

```java
http.exceptionHandling(ex -> ex
        .authenticationEntryPoint((request, response, exception) -> {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        })
        .accessDeniedHandler((request, response, exception) -> {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        }));
```

统一响应可以包含稳定错误码和 Trace ID，但不能返回 Token 解析细节、账号是否存在、内部异常类或密钥信息。

## 14. 服务间安全

- 每个服务使用独立 Client Identity，不共享一个万能账号。
- Token Audience 绑定目标 API，Scope 使用最小权限。
- 全链路 TLS；高安全场景使用 mTLS 认证服务身份。
- 网关认证不能替代服务自身授权，内部网络不等于可信网络。
- 传递用户身份时保留原始主体和调用服务主体，便于审计。
- 禁止客户端自行伪造 `X-User-Id` 等身份 Header；网关应清理外部同名 Header。

## 15. 密钥管理与轮换

- 私钥和 Client Secret 放入 KMS、Vault 或平台 Secret。
- 不写入 Git、镜像、日志和普通配置中心明文。
- 使用 `kid` 标识签名密钥，JWKS 同时发布新旧公钥。
- 先发布新公钥，再使用新私钥签发；旧 Token 过期后删除旧公钥。
- 缓存 JWKS 时处理轮换和未知 `kid`，但限制刷新频率防止攻击。
- 对密钥读取、签发和管理操作进行审计。

## 16. 测试与审计

```java
@WebMvcTest(OrderController.class)
class OrderSecurityTest {

    @Test
    @WithMockUser(authorities = "order:read")
    void shouldAllowReader() throws Exception {
    }
}
```

Resource Server 测试可以使用 `jwt()` RequestPostProcessor 构造 Claims。至少覆盖：

- 无 Token、无效签名、过期、错误 Issuer/Audience。
- 权限不足和跨租户访问。
- 管理员与普通用户边界。
- CORS 预检、CSRF、登出和 Refresh Rotation。
- 密钥轮换期间新旧 Token。

审计记录主体、动作、资源、结果、时间、来源和 Trace ID，不记录密码、完整 Token、Authorization Header 或敏感响应体。

## 17. 常见问题

### 17.1 401 与 403 混乱

401 表示缺少或无法验证认证信息；403 表示身份有效但没有权限。检查过滤器是否先正确建立 Authentication，以及异常是否被全局异常处理错误改写成 500 或 200。

### 17.2 配置 permitAll 仍进入自定义过滤器

`permitAll` 是授权规则，不会让请求跳过前面的自定义认证过滤器。过滤器应通过 RequestMatcher 判断是否需要处理，并在无凭据时按协议决定继续链路或返回错误。

### 17.3 JWT 签名正确却被拒绝

检查 Issuer、Audience、过期时间、服务器时间、JWKS 缓存、`kid` 和算法。不要为“修复”问题关闭这些验证。

### 17.4 登录成功但后续请求未认证

Session 模式检查 Cookie 域、SameSite、Secure、反向代理 HTTPS Header 和 Session 存储；Bearer 模式检查 Authorization Header 是否被网关转发，以及资源服务是否配置正确 Issuer。

## 18. 面试高频问题

### 18.1 认证和授权有什么区别

> 认证确认调用者身份，授权判断该身份是否有权执行某项操作。应先认证再授权，但公开接口可以允许匿名主体访问。

### 18.2 Spring Security 原理是什么

> Servlet 请求先经过 FilterChainProxy 中匹配的 SecurityFilterChain。认证过滤器提取凭据并交给 AuthenticationManager 和 Provider，成功后把 Authentication 保存到 SecurityContext，AuthorizationFilter 再根据请求规则决定是否放行。

### 18.3 JWT 是否加密

> 普通 JWT/JWS 只是 Base64Url 编码并签名，能保证篡改可检测，但 Payload 可以被任何持有者读取。敏感数据不能放入 Token；需要机密性时使用专门加密机制并评估是否真的需要自包含 Token。

### 18.4 JWT 如何注销

> 短期 Access Token 通常等待过期，同时撤销 Refresh Token；要求即时撤销时可以使用 JTI 黑名单、Token Version 或不透明 Token Introspection，但都会引入服务端状态。完全无状态与立即撤销存在权衡。

### 18.5 OAuth2 和 JWT 有什么区别

> OAuth2 是授权协议，定义角色和授权流程；JWT 是 Token 格式。OAuth2 Access Token 可以是 JWT，也可以是不透明随机字符串；JWT 也可以在非 OAuth2 场景使用。

### 18.6 Access Token 和 ID Token 有什么区别

> Access Token 发给 Resource Server 用于 API 授权；OIDC ID Token 发给 Client 证明用户完成认证。ID Token 的 Audience 是 Client，不能直接当作普通 API Access Token。

### 18.7 CSRF 和 CORS 有什么区别

> CSRF 利用浏览器自动携带 Cookie发起非本人意愿请求；CORS 控制浏览器是否允许一个 Origin 读取另一个 Origin 的响应。CORS 不是认证授权，也不能替代 CSRF 防护。

### 18.8 为什么密码不能使用 MD5

> MD5 计算太快且已不适合密码保存，攻击者可高速暴力破解。密码应使用带随机 Salt、成本可调的 BCrypt、Argon2 等专用算法，并逐步提高成本参数。

### 18.9 Authorization Code 为什么需要 PKCE

> PKCE 将授权请求中的 Challenge 与换 Token 时的 Verifier 绑定。即使一次性授权码被截获，没有 Verifier 也不能兑换 Token，特别适合无法安全保存 Client Secret 的浏览器和移动端。

### 18.10 RBAC 和数据权限有什么区别

> RBAC 决定角色能否执行某类操作；数据权限限制该操作可以作用于哪些租户、组织或资源。拥有订单读取角色不代表可以读取所有用户订单，查询层仍需加入所有者条件。

## 19. 生产环境检查清单

- [ ] 密码使用自适应哈希，登录具有限流和 MFA 策略。
- [ ] 全站 HTTPS，Cookie 配置 Secure、HttpOnly、SameSite。
- [ ] Session/Token、CSRF 和 CORS 策略与客户端类型匹配。
- [ ] JWT 验证签名、算法、Issuer、Audience 和时间声明。
- [ ] Access Token 短时有效，Refresh Token Rotation 可检测重放。
- [ ] OAuth2 使用 Authorization Code + PKCE 或 Client Credentials。
- [ ] ID Token 不作为普通 API Access Token。
- [ ] API、方法和数据权限均有服务端校验。
- [ ] 密钥支持 KMS 存储、`kid` 轮换和审计。
- [ ] 管理端点、异常和日志不泄露 Token 与内部信息。
- [ ] 跨租户、越权、失效 Token 和密钥轮换有自动化测试。

## 20. 学习路线

1. 理解认证、授权、SecurityContext 和过滤器链。
2. 掌握密码认证、Session、Cookie、CSRF 和 CORS。
3. 理解 JWT 签名、Claims、验证和密钥轮换。
4. 使用 Spring Resource Server 保护 API。
5. 掌握 OAuth2 Code + PKCE、Client Credentials 和 OIDC。
6. 设计 Refresh、撤销、服务间身份和数据权限。
7. 完成安全测试、审计和生产密钥管理。
