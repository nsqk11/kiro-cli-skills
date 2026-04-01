# Capture

## Why

- **do**：对话过程中会产生有价值的事件（错误、纠正、新发现等），如果不及时捕获就会丢失。Capture 作为闭环的第一步，确保这些事件被记录下来供后续模块消化。
- **don't**：不捕获没有具体触发事件的猜测性内容。no event = no log。

## What

- **do**：检测对话中的有价值事件，写入 `LOG.md` 作为 pending 条目。纯被动缓冲——只记录，不处理。
- **don't**：不提取知识，不修改 skill，不消费 LOG 条目。

## Who

- **do**：Capture 模块自身。子步骤中 `grep` 负责去重检查。
- **don't**：不做 Learn 或 Improve 的事。

## When

- **do**：检测到直接信号或间接信号时触发（完整信号列表见 [检测触发表](#检测触发表)）。会话结束时（stop hook）进行 session-end review。用户说 `/save`、"记一下" 时触发 Quick Save。
- **don't**：Capture 前先去重，已存在则更新 Hits 而非新建条目。

## Where

- **do**：写入 `$KIRO_HOME/.learnings/LOG.md`。
- **don't**：不写入 KB，不写入 skill 文件。

## How

- **do**：
  1. 检测事件（信号类型见 [检测触发表](#检测触发表)，含 [Self-Improving Detection](#self-improving-detection)）
  2. 去重检查：先 `grep -F "Pattern-Key"` 精确匹配，再 `grep -i "关键词"` 模糊匹配
  3. 有匹配 → Hits +1，追加日期；无匹配 → 新建条目
  4. 条目按标准格式写入（格式见 [条目格式](#条目格式)，含 [Pattern-Key](#pattern-key) 和 [Priority Guidelines](#priority-guidelines)）
  5. session-summary 跳过去重（每条唯一）
- **don't**：不链式执行命令，读写分开调用。

## How much

- **do**：每个事件一条条目。ID 格式 `LOG-YYYYMMDD-XXX`（XXX 为当日顺序号）。Hits ≥ 3 为高优先级（完整优先级定义见 [Priority Guidelines](#priority-guidelines)）。
- **don't**：不过度记录，去重后仍重复的不记。

---

## 检测触发表

### 事件类型

| Situation | Type |
|-----------|------|
| Command/tool fails | `error` |
| User corrects you | `correction` |
| Knowledge was wrong/outdated | `knowledge-gap` |
| Better approach found | `improvement` |
| Missing capability requested | `feature-request` |
| Design/architecture decision | `decision` |
| Naming/format/process convention | `convention` |
| Task processing pattern | `workflow` |
| User communication pattern | `user-pattern` |
| Non-obvious pitfall | `gotcha` |
| Environment config/limitation | `environment` |
| Deprecated functionality | `deprecation` |
| End-of-session summary | `session-summary` |
| Skill improvement suggestion | `skill-improvement` |

### 间接信号

| User Says | Likely Meaning |
|-----------|---------------|
| "这样做能对吗？"、"确定吗？" | Correction — verify before proceeding |
| "我记得不是这样的"、"之前你说的是..." | Correction or knowledge-gap |
| "有没有其他方式"、"能不能..." | Feature-request or improvement |
| "有必要吗？"、"为什么不..."、"不能直接...吗？" | Suggesting a better approach |
| "好的"/"可以" after you explain a limitation | Resigned acceptance (feature-request) |
| "重新改"、"改回去"、"不对重来" | Previous approach was wrong |

### Self-Improving Detection

如果对话中途意识到用户之前其实在纠正/请求/建议但当时没捕获到——记录用户原话为 `user-pattern`，使触发检测随时间自我改进。

---

## 条目格式

```markdown
## [LOG-YYYYMMDD-XXX] type

**Logged**: ISO-8601
**Status**: pending
**Hits**: 1 (YYYY-MM-DD)
**Pattern-Key**: domain.topic (optional)
**Tags**: tag1, tag2

### Summary
One-line description

### Details
Full context (error messages, user's exact words, trigger scenario, etc.)
```

### Pattern-Key

可选的稳定去重键，格式 `domain.topic`。同 Pattern-Key 条目自动关联用于模式检测。Hits ≥ 3 + Pattern-Key = 强 skill 候选信号。一次性事件不加。

### Priority Guidelines

| Priority | When |
|----------|------|
| critical | Blocks core functionality, data loss, security |
| high | Significant impact, common workflows, recurring, Hits ≥ 3 |
| medium | Moderate impact, workaround exists |
| low | Minor, edge case |
