# MECE

For any classification, decomposition, or dimension split, run these checks:

## Mutual Exclusivity

Each sub-item covers one non-overlapping scope. If a piece of content could belong to multiple sub-items, the classification has overlap — re-partition.

## Collective Exhaustiveness

All sub-items together cover the whole. If you can find a counterexample that fits none of the sub-items, the classification has a gap — add the missing item.

## Partitioning Constraints

- Each decomposition must split along a single dimension
- Root-cause analysis and solution design are two separate steps — do not mix them
- After decomposition, parts are independent; when solving, consider dependencies and interactions between parts

> Reference: [MECE Principle](https://en.wikipedia.org/wiki/MECE_principle)
