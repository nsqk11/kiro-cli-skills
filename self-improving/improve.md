# Improve

## Why

- **do**：知识沉淀到 KB 后，需要反哺到 skill 中才能真正改变行为。Improve 是闭环的最后一步，将积累的知识转化为 skill 的实际改进。
- **don't**：单次出现的问题不急于改 skill，等待复现确认模式。

## What

- **do**：基于 user-profile KB 中的知识和周期性 review 信号，判断知识的 skill 归属、改进现有 skill、创建新 skill、管理 skill 路由（按需加载）。
- **don't**：不记录事件（Capture 的事），不管理 KB（Learn 的事），不直接读 LOG.md，不修改 self-improving 自身文件。

## Who

- **do**：Improve 模块自身。子步骤中 `fs_read` 加载 skill，`str_replace` 修改 skill，`scripts/extract-skill.sh` 生成新 skill 脚手架。
- **don't**：不做 Capture 或 Learn 的事。

## When

- **do**：
  - 对话开始时（Learn 完成后）：扫描 KB 中 `[skill: <name>]` 条目，回流到对应 skill
  - 用户话题匹配 skill triggers 时：按需加载 skill（路由规则见 How 中 [Skill 路由](#skill-路由)）
  - 使用 skill 过程中发现小缺口时：即时修复
  - 周期性 review（每 20 次对话或 7 天，检查项见 How 中 [周期性 Review](#周期性-review)）
  - 用户明确说"做成 skill"时：立即创建
- **don't**：KB 中同主题未达 3 次阈值时不主动改 skill。用户不同意的方案不自动执行。

## Where

- **do**：
  - 输入：`$KIRO_HOME/resources/knowledgeBase/user-profile/knowledgeBase.md`（带 skill 标签的条目）
  - 输出：`$KIRO_HOME/skills/<category>/<name>/SKILL.md`（修改或新建）
- **don't**：不写入 LOG.md，不写入 KB。

## How

- **do**：
  ### Skill 路由
  1. agentSpawn 时 `scripts/skill-router.sh` 自动扫描所有 SKILL.md frontmatter，生成 `<skill-router>` 路由表注入上下文
  2. 用户请求 → 匹配路由表中各 skill 的 `triggers`
  3. 匹配到 → 立即 `fs_read` 加载对应 path，不询问
  4. 一个请求可触发多个 skill；加载后 session 内保持活跃
  5. 不确定 → 不加载，等更明确的信号

  ### KB → Skill 回流
  1. 扫描 KB 中未标注 skill 归属的条目
  2. 判断归属，标注 `[skill: <name>]` 或 `[skill: none]`
  3. 将 `[skill: <name>]` 条目合并到对应 skill 的相关 section
  4. 标记 KB 条目为 `[merged to skill: <name>]`
  5. 通知用户

  ### 变更控制
  | 类型 | 示例 | 动作 |
  |------|------|------|
  | Minor | 加 tip、修措辞、加示例 | 自动修改，通知用户 |
  | Major | 新建 skill、删除 skill、改 When/triggers、重构 | 先提议，等用户确认 |

  ### Skill 发现与创建
  - 同类任务重复 3+ 次 / 用户明确要求 → 生成 Skill Candidate
  - 创建前检查：与现有 skill 重叠 > 50% → 建议改进现有 skill
  - 新建和修改 skill 必须遵循 [analysis-method](../common/analysis-method/SKILL.md) 的 5W2H 结构（fs_read 加载后参照）
  - 新 skill 必须通过质量门：triggers 覆盖常见表述、description 脱离上下文可理解、无硬编码路径、有 do/don't
  - 创建后确保新 skill 的 SKILL.md 包含正确的 frontmatter（name/description/triggers），`skill-router.sh` 会自动将其纳入路由表

  ### 周期性 Review
  每 20 次对话或 7 天自动提醒，检查：重复 tag 3+ → Skill Candidate？30 天未用 skill → 归档？3+ 待改进 → 批量更新？scope 重叠 → 合并？

- **don't**：不为一次性任务创建 skill。不为已有 skill 覆盖的主题重复创建。cosmetic 改动无功能影响的跳过。

## How much

- **do**：
  - 回流：每条 `[skill: <name>]` 条目都处理，无遗留
  - 发现阈值：同主题 3+ 次才提议新 skill
  - 用户纠正同一行为 2+ 次 → 更新 skill
  - 即时修复限于 minor 变更
- **don't**：未达阈值的模式不改 skill。major 变更未经用户确认不执行。
