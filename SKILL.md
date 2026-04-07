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

规则参考：[5W2H](prompts/5w2h.md) | [MECE](prompts/mece.md)

## Why

- **do**: 知识会过时、操作会出错、能力会有缺口。闭环机制自动捕获这些事件，沉淀为知识，反哺到 skill。
- **don't**: 一次性任务或不需要积累经验的场景不使用。

## What

- **do**: 三模块闭环——Capture（捕获事件）→ Learn（沉淀知识）→ Improve（改进 skill）。将错误、纠正、新发现等事件转化为持久化知识和 skill 改进。
- **don't**: 不执行业务逻辑，不替代具体 skill，不修改自身文件。

## Who

- **do**: 三个子模块各司其职：
  - [Capture](prompts/capture.md)：检测并记录事件
  - [Learn](prompts/learn.md)：消化事件、沉淀知识
  - [Improve](prompts/improve.md)：改进其他 skill
- **don't**: Capture 不处理知识，Learn 不修改 skill，Improve 不记录事件。

## When

- **do**:
  - 命令/工具执行失败 → Capture
  - 用户纠正 → Capture
  - 知识过时或缺失 → Capture
  - 更好的方法被发现 → Capture
  - 用户建立约定/决策 → Capture
  - 新对话开始且有 pending 条目 → Learn
  - KB 同主题累积 ≥ 3 次 → Improve
- **don't**: Capture 前先去重：`grep -i "keyword" .data/log.md`，已存在则不重复记录。

## Where

- **do**:
  - 事件缓冲：`.data/log.md`
  - 知识沉淀：`.data/knowledge.md`
  - 归档：`.data/archive.md`
- **don't**: 不操作具体业务 skill 的资源路径（Improve 只修改 skill 文件本身）。

## How

- **do**: 三模块顺序流水线，通过 LOG.md 通信：
  ```
  Capture → Learn → Improve
     ↑                  │
     └──────────────────┘
  ```
  - Capture → Learn：写入 log.md，Learn 在下次对话开始时消费 pending 条目，沉淀到 KB，标记 done
  - Learn → Improve：扫描 KB 中未标注归属的条目，判断归属并标注 `[skill: <name>]`，回流到对应 skill
  - Improve → Capture：改进后的 skill 投入使用，新问题继续捕获
  - Hook 驱动：agentSpawn（`hooks/agent-spawn.sh`）、postToolUse（`hooks/post-tool-use.sh`）、stop（`hooks/stop.sh`）
  - log.md 超 30 条时 `scripts/cleanup.sh` 归档 done 条目（由 stop hook 自动触发）
- **don't**: 不并行处理模块，严格顺序。不在一个模块中做另一个模块的事。读写分开调用。不能跳过 Learn 步骤直接从 LOG 改 Skill，Improve 的输入是 KB 不是 LOG。

## How much

- **do**:
  - Capture：每个事件一条 LOG 条目
  - Learn：每次消费所有 pending 条目，无遗留
  - Improve：同主题 ≥ 3 次才触发 skill 修改；小缺口可即时修复
  - agentSpawn 最多加载 20 条 pending 条目
- **don't**: 去重后仍重复的不记。未达阈值的模式不急于修改 skill。
