# Learn

规则参考：[5W2H](5w2h.md) | [MECE](mece.md)

## Why

- **do**: log.md 中的 pending 条目是原始事件，需要消化为结构化、可检索的知识，才能被 Improve 和日常使用所利用。
- **don't**: 单次出现且不太可能复现的一次性事实，让它们在 log.md 中自然老化。

## What

- **do**: 消费 log.md 中所有 pending 条目，提炼写入 knowledge.md，标记 done。
- **don't**: 不记录事件（Capture 的事），不修改 skill（Improve 的事），不判断知识归属哪个 skill（Improve 的事）。

## Who

- **do**: Learn 模块。子步骤中 `grep` 负责 KB 去重，`knowledge update` 重建索引。
- **don't**: 不做 Capture 或 Improve 的事。

## When

- **do**: 新对话开始时（agentSpawn hook 加载 pending 条目后），消费所有 pending 条目。
- **don't**: session-summary 条目不立即写入 KB，走跨会话模式识别（同主题 ≥ 3 次才提升）。

## Where

- **do**:
  - 输入：`.data/log.md`（pending 条目）
  - 输出：`.data/knowledge.md`
- **don't**: 不写入项目特定 KB。

## How

- **do**:
  1. 读取所有 pending 条目
  2. 对每条：`grep -i "关键词"` 检查 user-profile KB
     - 已存在且一致 → 跳过写入，标记 done
     - 已存在但矛盾 → 用最新内容覆盖（用户纠正优先）
     - 不存在 → 追加到对应 section
  3. `knowledge update` 重建索引
  4. 标记条目 `Status: done`
  5. 跨会话模式识别：扫描 session-summary，同主题 ≥ 3 次 → 提炼为 KB 条目，标记 done
- **don't**: 不修改 skill 文件，不标注 skill 归属，不重复写入已存在且一致的内容。

## How much

- **do**: 每次消费所有 pending 条目，无遗留。矛盾时以最新用户纠正为准。
- **don't**: session-summary 未达 3 次阈值的不提升。模糊或未验证的知识不写入 KB。
