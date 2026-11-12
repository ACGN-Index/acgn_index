# 规则包规范 v1

> 本文件是规则 schema 的**唯一权威**。修改规则格式必须同步更新本文件、`RulePackValidator`、`assets/rules/demo_rule_pack.json` 与 `kSupportedSchemaVersion`。
>
> 当前仍是预发布阶段，字段可在不升版本号的前提下调整；正式发布后再按第 9 节执行版本演进。
> 一个规则包只服务一类内容，`meta.type` 必填；`content` 必须声明 `mode`。

规则包是一个 JSON 对象，扩展名约定为 `.acgn.json`，用于描述"如何从某个站点取到作品、目录与正文"。

## 1. 顶层结构

```json
{
  "schemaVersion": 1,
  "meta": { },
  "request": { },
  "capabilities": { }
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `schemaVersion` | int | ✅ | 必须等于当前支持的版本（当前 `1`） |
| `meta` | object | ✅ | 规则元信息 |
| `request` | object | ❌ | 请求默认值，缺省时使用内置默认 |
| `login` | object | ❌ | 登录方式声明，见 3.1 |
| `capabilities` | object | ✅ | 至少声明一种能力 |

未知字段不报错，只产生 warning（前向兼容）。

## 2. `meta`

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | ✅ | 全局唯一标识，建议 `owner.site` 形式，**发布后不可修改** |
| `name` | string | ✅ | 展示名 |
| `type` | string | ✅ | 内容类型：`anime` / `comic` / `novel`，一个包只服务一类 |
| `baseUrl` | string | ✅ | 绝对 `http(s)` 地址，相对链接据此解析 |
| `version` | string | ✅ | 规则自身版本，遵循 semver |
| `author` | string | ❌ | 作者 |
| `lang` | string | ❌ | 内容语言，默认 `zh` |
| `description` | string | ❌ | 备注 |
| `adult` | bool | ❌ | 是否成人内容，默认 `false`；发现页据此过滤 |
| `notice` | string | ❌ | 来源与合规说明，内置规则集使用 |
| `allowedHosts` | string[] | ❌ | 除 `baseUrl` 之外还允许请求的主机（索引、下载跨域时使用） |

## 3. `request`

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `headers` | object<string,string> | `{}` | 附加请求头，会与内置默认（含 User-Agent）合并 |
| `timeoutMs` | int | `15000` | 单请求超时 |
| `encoding` | string | `utf-8` | 响应解码字符集 |
| `retry` | int | `0` | 网络失败重试次数，0–2 |

### 3.1 `login`（可选）

需要登录的站点可以声明登录方式。规则包只描述「怎么登录」，真实 Cookie / 请求头由应用保存在本地，**不写入规则包、不参与导出**。

```json
"login": {
  "mode": "webview",
  "url": "{{baseUrl}}/login",
  "successUrlPattern": "/(profile|user)",
  "cookieNames": ["sessionid"],
  "headers": {
    "Authorization": "Bearer {{cookie.access_token}}"
  }
}
```

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `mode` | `"webview"` \| `"headers"` | `webview` | `webview`：应用内打开登录页并抓取 Cookie；`headers`：用户手动填写请求头 |
| `url` | string | — | 登录页地址，`webview` 必填；支持 `{{baseUrl}}` 与相对路径 |
| `successUrlPattern` | string | — | 登录成功 URL 正则，匹配时提示用户保存登录状态 |
| `cookieNames` | string[] | `[]` | WebView 抓取时只保留这些 Cookie；留空表示全部 |
| `headers` | object<string,string> | `{}` | 登录后附加到该规则所有请求的请求头；值支持 `{{cookie.name}}` |

登录凭据按 `meta.id` 保存在本地数据库。应用会把它合并进该规则的全部 HTTP 请求、封面 / 图片 / 视频 / 文件请求头；同名请求头以本地凭据为准。WebView 登录地址的主机必须属于 `meta.baseUrl` 或 `meta.allowedHosts`。

> `login.headers` 属于规则内容，值应尽量留空或使用 `cookie` 模板；用户真实 Token 请通过应用登录界面填写，不要写进规则包。

## 4. `capabilities`

键只能是 `search` / `detail` / `toc` / `content`，未知键产生 warning。

| 能力 | 动漫 | 漫画 | 小说 | 期望产出 |
| --- | --- | --- | --- | --- |
| `search` | 必需 | 必需 | 必需 | 作品列表（`id`、`title`、`cover`、`author`…） |
| `detail` | 必需 | 必需 | 必需 | 单作品字段（简介、状态、标签、分卷…） |
| `toc` | 必需 | 必需 | 必需 | 剧集/卷/章列表，可分组 |
| `content` | 可选（`video`） | 必需（`images`） | 必需（`text` / `file`） | 视频源 / 图片列表 / 段落 / 文件 |

> 仅提供资料、没有播放或正文的源可以省略 `content`；阅读器会提示「该源仅提供资料」。

### 4.1 公共字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `url` | string | ✅ | 请求地址模板（`search` 的 `index` 模式、`toc` 的分卷扇出、`video` 正文可省略） |
| `method` | `"GET"` \| `"POST"` | ❌ | 默认 `GET` |
| `body` | string | ❌ | POST 请求体模板 |
| `headers` | object<string,string> | ❌ | 该能力附带的请求头，与规则包级请求头合并 |
| `list` | FieldRule | ❌ | 列表条目选择器，每个条目作为后续字段的求值上下文 |
| `fields` | object<string, FieldRule> | ❌ | 字段提取规则 |

### 4.2 `search`

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `mode` | `"query"` \| `"index"` | `query` | 远程关键词，或拉索引后本地过滤 |
| `index` | object | — | `mode=index` 必填，见下 |
| `filter` | FieldRule | — | `mode=index` 必填；`value` 为条目，`ctx.keyword` / `ctx.keywordNormalized` 可用 |
| `pageSize` | int | `20` | 每页条数（本地分页或 `{{pageSize}}`） |
| `pagination` | object | — | 远程分页信息：`totalItems`（FieldRule）与 `pageSize` |

`index` 对象：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `url` | string | ✅ | 索引地址模板 |
| `method` | GET/POST | ❌ | 默认 `GET` |
| `body` | string | ❌ | POST 请求体 |
| `list` | FieldRule | ✅ | 索引条目选择器 |
| `ttlSeconds` | int | ❌ | 缓存时长，默认 `3600` |

### 4.3 `detail`

请求单作品详情。分卷/分组等数组字段使用对象数组规则：

```json
"volumes": {
  "items": { "jsonPath": "$.data.volumes[*]" },
  "fields": {
    "id": { "jsonPath": "$.vid" },
    "title": { "jsonPath": "$.title" }
  }
}
```

引擎会把 `volumes` 作为多值字段传给 `toc.fanOutFrom`。

### 4.4 `toc`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `fanOutFrom` | string | 可选，如 `detail.volumes` 或 `search.volumes`；按该字段每个条目发起一次目录请求 |
| `group` | object | 可选，`{"id": "vid", "title": "title"}`；把条目键映射为分组 id 与标题，必须与 `fanOutFrom` 一起使用 |

- 无 `fanOutFrom`：单次请求，`list` + `fields` 产出平铺目录。
- 有 `fanOutFrom` + `url` + `list`：逐组请求（例如按卷取章节）。
- 有 `fanOutFrom` 且无 `url`/`list`：每个条目本身就是一章（例如分卷 EPUB），章节字段直接来自该条目。

### 4.5 `content`

| `mode` | 必填字段 | 可选字段 |
| --- | --- | --- |
| `video` | `url` 或 `urls`（请求地址 `url` 可留空） | `type`（`hls`/`mp4`）、`headers`、`referer`、`quality`、`danmakuUrl` |
| `images` | `images`（数组） | `headers`、`referer` |
| `text` | `body`（HTML/文本）或 `paragraphs` | `images`、`title` |
| `file` | `url`、`format`（`epub`/`txt`） | `size`、`checksum` |

`video` 的 `url`（请求地址）可以留空：此时不发请求，`fields` 必须声明 `url` 或 `urls`，通常用 `{{chapter.url}}` 取目录条目自带的直链。留空时 `resolve` 不可用。

可选 `resolve` 二段请求：`{"url": "...", "method": "GET", "fields": { ... }}`，其字段以 `{{resolve.*}}` 注入 `content.fields` 与资产地址模板。

### 4.6 字段契约

| 能力 | 必填 | 可选 |
| --- | --- | --- |
| `search` | `id`、`title` | `cover`、`author`、`subtitle`、`url`、`status`、`tags` |
| `detail` | `title` | `cover`、`intro`、`author`、`status`、`tags`、`rating`、`year`、`episodeCount`、`volumes`、`aliases` |
| `toc` | `title` + （`id` 或 `url`） | `order`、`group`、`duration`、`airdate`、`extra` |

## 5. 模板变量

`url`、`body`、`template` 与 `const` 中的 `{{name}}` 会被替换：

| 变量 | 可用能力 | 含义 |
| --- | --- | --- |
| `{{baseUrl}}` | 全部 | `meta.baseUrl` |
| `{{key}}` | `search` | 经 URL 编码的关键词 |
| `{{keywordNormalized}}` | `search` | 归一化关键词（去空白/标点、全角转半角、小写） |
| `{{page}}` | `search` | 页码，从 1 开始 |
| `{{pageSize}}` | `search` | 每页条数 |
| `{{offset}}` | `search` | `(page - 1) * pageSize` |
| `{{id}}` | `detail`、`toc` | 作品 id |
| `{{url}}` | `detail`、`toc` | 作品详情页绝对地址 |
| `{{chapter.id}}` / `{{chapter.url}}` / `{{chapter.title}}` | `content` | 章节字段 |
| `{{chapter.<任意字段>}}` | `content` | 目录 `fields` 里声明的自定义字段（如 EPUB 的 `file`、`size`） |
| `{{group.id}}` / `{{group.title}}` | `toc` | 分卷/线路分组字段 |
| `{{resolve.*}}` | `content` | `resolve` 二段请求的字段 |
| `{{cookie.name}}` | `login.headers` | 本地保存的 Cookie 值；缺失时按空值处理 |

未声明的变量视为规则错误，请求不会发出。`login.headers` 中值为空的项不会发送。

## 6. FieldRule（字段规则）

### 6.1 取值来源（一个主来源，可附加 `js`；或用 `items` 声明对象数组）

| 键 | 说明 |
| --- | --- |
| `selector` | CSS 选择器（默认在列表条目上下文中查询） |
| `xpath` | XPath 表达式（用于 XML/XHTML） |
| `jsonPath` | JSONPath 表达式（用于 JSON 接口） |
| `js` | JS 表达式，在沙箱内执行；可单独作为来源，也可附加在一个主来源之后 |
| `const` | 常量字符串 |
| `items` | 对象数组的条目选择规则；与所有取值来源互斥（包括 `js`） |

主来源最多声明一个：`selector` / `xpath` / `jsonPath` / `const`。`js` 不占主来源名额：单独声明时是来源，与主来源同时声明时是后处理步骤。

### 6.2 后处理选项

| 键 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `attr` | string | — | 取元素属性；缺省取文本节点 |
| `html` | bool | `false` | 取 `innerHtml` 而非文本 |
| `regex` | string | — | 对结果做正则匹配 |
| `group` | int | `1` | 正则捕获组序号 |
| `multiple` | bool | `false` | 取全部匹配（多节点/数组），保持原顺序 |
| `template` | string | — | 结果模板，支持 `{{value}}` 与 `{{ctx.xxx}}` |
| `prefix` | string | `""` | 结果前缀 |
| `suffix` | string | `""` | 结果后缀 |
| `absolute` | bool | `false` | 把相对地址解析为绝对地址（基于 `baseUrl` 或当前页地址） |
| `htmlToText` | bool | `false` | 把 HTML 切成纯文本段落 |
| `fallback` | FieldRule | — | 前一步为空时改用的规则（`default` 只能给常量） |
| `default` | string | — | 取不到值时的常量兜底 |
| `fields` | object<string, FieldRule> | — | 仅与 `items` 一起使用，逐项求值 |

### 6.3 求值顺序

```
主来源（selector / xpath / jsonPath / const）或纯 JS
  → attr 或 html 或 text 或 htmlToText
  → regex(group)
  → js 后处理（value 为当前结果；纯 JS 时 value 为当前条目/页面）
  → template（{{value}} / {{ctx.xxx}}）
  → prefix + 结果 + suffix
  → absolute 解析
  → fallback → default
```

`multiple: true` 时对每个匹配项执行上述链，产出数组；纯 JS 返回数组时逐项产出。

### 6.4 对象数组

```json
"volumes": {
  "items": { "jsonPath": "$.data.volumes[*]" },
  "fields": {
    "id": { "jsonPath": "$.vid" },
    "title": { "jsonPath": "$.title" }
  }
}
```

求值结果为 `List<Map<String, String>>`，供 `toc.fanOutFrom` 与详情页分卷展示使用。

### 6.5 JS 表达式约定

- M1 沙箱注入：`value`（前一步结果 / 当前条目）与 `ctx`（当前条目、页面与模板变量的只读副本）。
- `ctx` 同时提供模板变量、`ctx.baseUrl`、`ctx.pageUri` 与 `ctx.json`；索引搜索额外提供 `ctx.keyword` 与 `ctx.keywordNormalized`（归一化关键词）。
- 不提供 `dart:io`、`dart:ffi`、文件系统或宿主对象。`http` 绑定预留给后续版本，当前引用会判规则错误。
- M1 支持表达式与函数形式：`"value => value.trim()"`、`"function (value, ctx) { return value.trim(); }"`；不支持裸语句块。
- 单次执行上限 3 秒（`AppConstants.scriptTimeout`），超时即判规则失败。

## 7. 校验规则

`RulePackValidator` 在解析前执行，一次性返回全部问题：

**error（阻止安装）**

- 缺少 `schemaVersion` / 非整数 / 不受支持
- 缺少 `meta`，或 `id` / `name` / `type` / `baseUrl` / `version` 为空
- `baseUrl` 不是绝对 http(s)；`type` 不是 `anime` / `comic` / `novel`
- 缺少 `capabilities` 或为空
- `search`：`mode` 非法；`query` 缺 `url`；`index` 缺 `index.url` / `index.list` / `filter`；`pageSize` 非正整数
- `toc`：无 `fanOutFrom` 时缺 `url`；声明 `group` 但缺 `fanOutFrom`；声明 `list` 但没有 `url`
- `content`：缺 `mode` 或 `mode` 非法；缺 `url`（`video` 且 `fields` 声明了 `url` / `urls` 时可留空）；`url` 留空却声明 `resolve`
- `detail` / `search`（query）缺 `url`
- `resolve` 缺 `url`
- `login` 不是对象；`login.mode` 不是 `webview` / `headers`；`webview` 模式缺 `login.url`；`login.url` 不是 http(s) 或相对路径
- `login.successUrlPattern` 不是合法正则
- `login.cookieNames` 不是字符串数组或包含空字符串
- `login.headers` 值不是字符串
- 能力 `method` 不是 GET/POST；`headers` 值不是字符串
- 字段规则没有取值来源且没有 `items`，或声明了多个主来源，或 `items` 与来源同时声明（`js` 可与一个主来源组合）
- `regex` 无法编译；`group` 非非负整数；`multiple` / `html` / `absolute` / `htmlToText` 非布尔
- `fallback` / `items` 不是对象；`fields` 与取值来源同时出现

**warning（不阻止安装）**

- 未知字段（顶层、meta、request、login、能力、能力子对象、字段）
- `fields` 为空
- 未知能力键
- `query` 模式下声明了只在 `index` 使用的配置

## 8. 安全边界

| 风险 | 约束 |
| --- | --- |
| 任意代码执行 | 规则不能导入库、不能访问宿主对象；仅 `value`/`ctx`/`http` |
| 任意网络访问 | 请求目标 host 必须属于规则声明的 `baseUrl` 或显式允许列表 |
| 拒绝服务 | JS 执行超时 + 请求超时 + 分页上限 |
| 凭据泄漏 | 登录凭据单独保存在本地数据库，不写入规则 JSON；导出规则时天然不含 cookie/token；日志脱敏 |
| 钓鱼登录页 | WebView 登录地址的主机必须属于 `baseUrl` / `allowedHosts`，规则不能把用户带到任意站点 |
| 恶意规则分发 | 导入前必须通过校验；导入展示作者、来源与请求 host 供用户确认 |

## 9. 版本演进

| schemaVersion | 变更 | 迁移 |
| --- | --- | --- |
| `1` | 初版（预发布）：四种能力 + CSS/XPath/JSONPath/JS/常量取值；单 `meta.type`；`content.mode`；`search.mode=index` + `filter`；`toc.fanOutFrom`/`group`；`FieldRule` 的 `multiple`/`template`/`fallback`/`items`/`fields`/`htmlToText`；`request.retry`；可选的 `login` 登录声明（WebView / 手动请求头） | —（预发布阶段不升版本，字段可调整） |

规则演进策略：

- **向后兼容的新增**（新可选字段）：不升版本，校验器对该字段给出 warning 前先支持。
- **破坏性变更**（删改语义、必填变更）：`schemaVersion` +1，并在本表登记"旧包如何迁移"；引擎需保留上一版本的迁移函数。

## 10. 完整示例

见 [`assets/rules/demo_rule_pack.json`](../assets/rules/demo_rule_pack.json)，指向 `example.invalid`，仅用于本地开发与测试。
