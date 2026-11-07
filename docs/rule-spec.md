# 规则包规范 v1

> 本文件是规则 schema 的**唯一权威**。修改规则格式必须同步更新本文件、`RulePackValidator`、`assets/rules/demo_rule_pack.json` 与 `kSupportedSchemaVersion`。

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
| `capabilities` | object | ✅ | 至少声明一种能力 |

未知字段不报错，只产生 warning（前向兼容）。

## 2. `meta`

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | ✅ | 全局唯一标识，建议 `owner.site` 形式，**发布后不可修改** |
| `name` | string | ✅ | 展示名 |
| `baseUrl` | string | ✅ | 绝对 `http(s)` 地址，相对链接据此解析 |
| `version` | string | ✅ | 规则自身版本，遵循 semver |
| `author` | string | ❌ | 作者 |
| `lang` | string | ❌ | 内容语言，默认 `zh` |
| `description` | string | ❌ | 备注 |
| `types` | string[] | ⚠️ | 支持的内容类型：`anime` / `comic` / `novel`；缺省时规则不出现在任何分类 |

## 3. `request`

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `headers` | object<string,string> | `{}` | 附加请求头，会与内置默认（含 User-Agent）合并 |
| `timeoutMs` | int | `15000` | 单请求超时 |
| `encoding` | string | `utf-8` | 响应解码字符集 |

## 4. `capabilities`

键只能是 `search` / `detail` / `toc` / `content`，未知键产生 warning。

| 能力 | 语义 | 输入变量 | 期望产出 |
| --- | --- | --- | --- |
| `search` | 关键词搜索 | `key`、`page` | 作品列表（`id`、`title`、`cover`、`author`…） |
| `detail` | 作品详情 | `id`、`url` | 单作品字段（简介、状态、标签…） |
| `toc` | 目录/章节列表 | `id`、`url` | 章节列表（`title`、`url`） |
| `content` | 章节正文 | `chapterUrl` | 小说文本或漫画图片列表 |

### 4.1 能力对象

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `url` | string | ✅ | 请求地址模板 |
| `method` | `"GET"` \| `"POST"` | ❌ | 默认 `GET` |
| `body` | string | ❌ | POST 请求体模板 |
| `list` | FieldRule | ❌ | 列表条目选择器，每个条目作为后续字段的求值上下文 |
| `fields` | object<string, FieldRule> | ❌ | 字段提取规则 |

## 5. 模板变量

`url`、`body` 中的 `{{name}}` 会被替换：

| 变量 | 可用能力 | 含义 |
| --- | --- | --- |
| `{{baseUrl}}` | 全部 | `meta.baseUrl` |
| `{{key}}` | `search` | 经 URL 编码的关键词 |
| `{{page}}` | `search` | 页码，从 1 开始 |
| `{{id}}` | `detail`、`toc` | 作品 id |
| `{{url}}` | `detail`、`toc` | 作品详情页绝对地址 |
| `{{chapterUrl}}` | `content` | 章节绝对地址 |

未声明的变量视为规则错误，请求不会发出。

## 6. FieldRule（字段规则）

### 6.1 取值来源（必须且只能声明一个）

| 键 | 说明 |
| --- | --- |
| `selector` | CSS 选择器（默认在列表条目上下文中查询） |
| `xpath` | XPath 表达式（用于 XML/XHTML） |
| `jsonPath` | JSONPath 表达式（用于 JSON 接口） |
| `js` | JS 表达式，在沙箱内执行 |
| `const` | 常量字符串 |

### 6.2 后处理选项

| 键 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `attr` | string | — | 取元素属性；缺省取文本节点 |
| `html` | bool | `false` | 取 `innerHtml` 而非文本 |
| `regex` | string | — | 对结果做正则匹配 |
| `group` | int | `1` | 正则捕获组序号 |
| `prefix` | string | `""` | 结果前缀 |
| `suffix` | string | `""` | 结果后缀 |
| `absolute` | bool | `false` | 把相对地址解析为绝对地址（基于 `baseUrl` 或当前页地址） |
| `default` | string | — | 取不到值时的兜底 |

### 6.3 求值顺序

```
选择器/JS/常量
  → attr 或 html 或 text
  → regex(group)
  → js 表达式（value 变量为当前结果）
  → prefix + 结果 + suffix
  → absolute 解析
  → default 兜底
```

### 6.4 JS 表达式约定

- 沙箱内**只能**访问：`value`（前一步结果）、`ctx`（当前条目/页面的只读上下文）、`http`（受限 GET）。
- 不提供 `dart:io`、`dart:ffi`、文件系统、任意网络；`http` 仅允许访问规则声明的 host。
- 表达式建议是纯函数形式：`"value => value.trim()"`，也可写语句块（M1 实现时确定）。
- 单次执行上限 3 秒（`AppConstants.scriptTimeout`），超时即判规则失败。

## 7. 校验规则

`RulePackValidator` 在解析前执行，一次性返回全部问题：

**error（阻止安装）**

- 缺少 `schemaVersion` / 非整数 / 不受支持
- 缺少 `meta`，或 `id` / `name` / `baseUrl` / `version` 为空
- `baseUrl` 不是绝对 http(s)
- `types` 含未知值
- 缺少 `capabilities` 或为空
- 能力缺少 `url`；`method` 不是 GET/POST
- 字段规则没有取值来源，或声明了多个来源
- `regex` 无法编译；`group` 非非负整数；`html` / `absolute` 非布尔

**warning（不阻止安装）**

- 未知字段（顶层、meta、request、能力、字段）
- 未声明 `types`
- `fields` 为空
- 未知能力键

## 8. 安全边界

| 风险 | 约束 |
| --- | --- |
| 任意代码执行 | 规则不能导入库、不能访问宿主对象；仅 `value`/`ctx`/`http` |
| 任意网络访问 | 请求目标 host 必须属于规则声明的 `baseUrl` 或显式允许列表 |
| 拒绝服务 | JS 执行超时 + 请求超时 + 分页上限 |
| 凭据泄漏 | 导出规则时剔除 cookie/token；日志脱敏 |
| 恶意规则分发 | 导入前必须通过校验；导入展示作者、来源与请求 host 供用户确认 |

## 9. 版本演进

| schemaVersion | 变更 | 迁移 |
| --- | --- | --- |
| `1` | 初版：四种能力 + CSS/XPath/JSONPath/JS/常量取值 | — |

规则演进策略：

- **向后兼容的新增**（新可选字段）：不升版本，校验器对该字段给出 warning 前先支持。
- **破坏性变更**（删改语义、必填变更）：`schemaVersion` +1，并在本表登记"旧包如何迁移"；引擎需保留上一版本的迁移函数。

## 10. 完整示例

见 [`assets/rules/demo_rule_pack.json`](../assets/rules/demo_rule_pack.json)，指向 `example.invalid`，仅用于本地开发与测试。
