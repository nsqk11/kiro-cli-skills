# Contributing

Thanks for your interest in improving this skill!

## How to Contribute

1. Fork the repo and create a feature branch
2. Make your changes
3. Submit a pull request with a clear description

## Skill Design Standard

All skills must follow the [5W2H](prompts/5w2h.md) framework:

- 7 dimensions: Why, What, Who, When, Where, How, How much
- Each dimension has `do` and `don't`
- Dimensions must be [MECE](prompts/mece.md) (mutually exclusive, collectively exhaustive)
- Written in instruction-style for AI execution, not human documentation

## Guidelines

- Keep shell scripts POSIX-compatible where possible
- Use `set -euo pipefail` in all bash scripts
- No hardcoded paths — scripts resolve paths relative to their own location
- Test on both Linux and macOS before submitting

## Reporting Issues

Open an issue with:
- What you expected
- What happened
- Steps to reproduce
- OS and Kiro CLI version
