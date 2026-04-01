---
name: self-improving
description: "Three-module closed-loop system for continuous self-improvement"
triggers:
  - "command fails"
  - "user corrects"
  - "knowledge outdated"
  - "missing capability"
  - "better approach"
  - "convention"
  - "pending learnings"
---

# Self-Improving

设计基准：[analysis-method](../common/analysis-method/SKILL.md)，维度规则参考 [5w2h-reference.md](../common/analysis-method/5w2h-reference.md)。

## Why

- **includes**：在持续使用过程中，知识会过时、操作会出错、能力会有缺口。需要一个闭环机制，将这些事件自动捕获、沉淀为知识、反哺到 skill 中，使系统越用越好。
- **excludes**：不用于一次性任务或不需要积累经验的场景。

## What

- **includes**：三模块闭环——Capture（捕获事件）→ Learn（沉淀知识）→ Improve（改进 skill）。将对话中的错误、纠正、新发现等事件转化为持久化的知识和 skill 改进。
- **excludes**：不直接执行业务逻辑，不替代具体 skill 的职责。不修改自身文件。

## Who

- **includes**：本 skill 自身，包含三个子模块各司其职：
  - Capture：[capture.md](capture.md)——检测并记录事件
  - Learn：[learn.md](learn.md)——消化事件、沉淀知识
  - Improve：[improve.md](improve.md)——改进其他 skill
- **excludes**：不承担具体业务 skill 的角色。Capture 不处理知识，Learn 不修改 skill，Improve 不记录事件。

## When

- **includes**：以下时机触发：
  - 命令或工具执行失败时（→ Capture）
  - 用户纠正时（→ Capture）
  - 发现知识过时或缺失时（→ Capture）
  - 发现更好的方法时（→ Capture）
  - 用户建立约定或决策时（→ Capture）
  - 新对话开始且有 pending 条目时（→ Learn）
  - KB 中同一主题累积 ≥ 3 次时（→ Improve）
- **excludes**：Capture 前先去重：`grep -i "keyword" $KIRO_HOME/.learnings/LOG.md`，已存在则不重复记录。

## Where

- **includes**：
  - 事件缓冲：`$KIRO_HOME/.learnings/LOG.md`
  - 知识沉淀：`$KIRO_HOME/resources/knowledgeBase/user-profile/`
  - 归档：`$KIRO_HOME/.learnings/ARCHIVE.md`
- **excludes**：不操作具体业务 skill 的资源路径（Improve 只修改 skill 文件本身）。

## How

- **includes**：三模块顺序流水线，通过 LOG.md 通信：
  ```
  Capture (detect & record) → Learn (understand & distill) → Improve (act & enhance)
       ↑                                                              │
       └──────────────────────────────────────────────────────────────┘
  ```
  - Capture → Learn：Capture 写入 LOG.md，Learn 在下次对话开始时消费所有 pending 条目，沉淀到 KB，标记 done
  - Learn → Improve：Improve 不读 LOG.md，扫描 KB 中未标注归属的条目，判断归属并标注 `[skill: <name>]`，回流到对应 skill
  - Improve → Capture：改进后的 skill 投入使用，新问题由 Capture 继续捕获，循环往复
  - 三个 hook 驱动自动运行：agentSpawn（`scripts/activator.sh`）、postToolUse（`scripts/error-detector.sh`）、stop（`scripts/stop-review.sh`）
  - LOG.md 超过 30 条时运行 `scripts/cleanup.sh` 归档 done 条目
- **excludes**：不并行处理模块，严格顺序。不在一个模块中做另一个模块的事。读写命令分开调用，不链式执行。

## How much

- **includes**：
  - Capture：每个事件一条 LOG 条目，含 type 和 status
  - Learn：每次消费所有 pending 条目，无遗留
  - Improve：同一主题 KB 累积 ≥ 3 次才触发 skill 修改；小缺口可即时修复并通知用户
  - agentSpawn 最多加载 20 条 pending 条目到上下文
- **excludes**：不过度记录——去重后仍重复的不记。不过度改进——未达到阈值的模式不急于修改 skill。
