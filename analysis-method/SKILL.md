---
name: analysis-method
description: "七何分析法——结构化思维与 Skill 设计的元规范"
triggers:
  - "skill 规范"
  - "skill 设计"
  - "5W2H"
  - "七何"
  - "新建 skill"
  - "结构化思维"
  - "分析问题"
---

# 七何分析法（5W2H Extended Method of Analysis）

维度规则详见 [5w2h-reference.md](./5w2h-reference.md)，以下按 7 个维度定义本 skill 自身。

## Why

- **includes**：提供一套结构化的思维方式，用于分析、拆解和定义任何行为或问题。同时作为 skill 设计的元规范，使每个 skill 的结构统一、严谨，执行可预测、可控、稳定。
- **excludes**：当行为足够简单（单步操作、零歧义）时，不需要使用本框架。

## What

- **includes**：定义分析任何行为或问题时必须回答的 7 个 MECE 维度，每个维度包含 includes/excludes 两面，形成围栏。既是思维工具，也是 skill 设计规范。
- **excludes**：不定义任何具体行为的业务内容，不定义运行时逻辑，不替代具体行为的分析。

## Who

- **includes**：本规范自身，作为结构化思维工具和 skill 设计的元规范，自身严格遵循本框架。
- **excludes**：不执行任何具体业务逻辑，不承担具体行为的角色。

## When

- **includes**：在需要结构化分析一个行为或问题、设计新 skill 或重构现有 skill 时使用。前置条件：对目标行为的场景有充分理解。
- **excludes**：对目标行为的场景理解不充分时，先补齐认知再使用本框架。

## Where

- **includes**：存放于 skill 目录中，被引用作为分析和设计的基准。
- **excludes**：不涉及具体业务资源路径。

## How

- **includes**：按核心层（Why → What）→ 约束层（Who、When、Where）→ 执行层（How → How much）的顺序，逐一回答 7 个维度。每个维度先写 includes，再写 excludes。维度规则全部参考 5w2h-reference.md。
- **excludes**：不跳过任何维度，不合并维度，不打破 MECE。

## How much

- **includes**：每个维度至少一条 includes 和一条 excludes。关键维度（Why、What、How）应详细展开。合格标准：每个维度已回答、无跨维度重复、includes/excludes 均存在。
- **excludes**：不写长篇论文。维度内容与其他维度重复说明 MECE 被破坏。不过度规范到规范比行为本身更难维护。
