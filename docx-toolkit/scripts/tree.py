#!/usr/bin/env python3
"""JSON tree operations for docx-toolkit."""
import argparse
import json
import sys
import uuid


def gen_id():
    return "nd-" + uuid.uuid4().hex[:8]


def load(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def save(data, path):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def find_parent(data, node_id):
    """Find parent node id for a given node. Returns None if in root."""
    for nid, node in data["nodes"].items():
        if node_id in node.get("children", []):
            return nid
    if node_id in data["root"]:
        return None
    return None


def cmd_show(data, node_id=None):
    """Print tree structure."""
    def show(nid, indent=0):
        n = data["nodes"][nid]
        h = n.get("heading", "") or "(preamble)"
        lv = n.get("level", 0)
        cc = len(n.get("content", []))
        ch = len(n.get("children", []))
        print("{}[H{}] {} ({} blocks, {} children) {}".format(
            "  " * indent, lv, h, cc, ch, nid))
        for c in n.get("children", []):
            show(c, indent + 1)

    if node_id:
        if node_id not in data["nodes"]:
            print("Node not found: " + node_id, file=sys.stderr)
            sys.exit(1)
        show(node_id)
    else:
        for r in data["root"]:
            show(r)


def cmd_get(data, node_id):
    """Print a single node's full content."""
    if node_id not in data["nodes"]:
        print("Node not found: " + node_id, file=sys.stderr)
        sys.exit(1)
    print(json.dumps(data["nodes"][node_id], ensure_ascii=False, indent=2))


def op_update(data, instr):
    nid = instr["id"]
    if nid not in data["nodes"]:
        raise ValueError("Node not found: " + nid)
    data["nodes"][nid]["content"] = instr["content"]


def op_rename(data, instr):
    nid = instr["id"]
    if nid not in data["nodes"]:
        raise ValueError("Node not found: " + nid)
    data["nodes"][nid]["heading"] = instr["heading"]


def op_delete(data, instr):
    nid = instr["id"]
    recursive = instr.get("recursive", True)
    if nid not in data["nodes"]:
        raise ValueError("Node not found: " + nid)

    node = data["nodes"][nid]
    children = node.get("children", [])

    # Remove from parent's children or root
    parent_id = find_parent(data, nid)
    if parent_id:
        siblings = data["nodes"][parent_id]["children"]
    else:
        siblings = data["root"]

    idx = siblings.index(nid)

    if recursive:
        # Delete entire subtree
        def collect(n):
            ids = [n]
            for c in data["nodes"][n].get("children", []):
                ids.extend(collect(c))
            return ids
        for dead in collect(nid):
            del data["nodes"][dead]
        siblings.pop(idx)
    else:
        # Promote children to parent at same position
        siblings.pop(idx)
        for i, c in enumerate(children):
            siblings.insert(idx + i, c)
        del data["nodes"][nid]


def op_add(data, instr):
    parent = instr.get("parent")
    after = instr.get("after")
    heading = instr["heading"]
    level = instr["level"]
    content = instr.get("content", [])

    nid = gen_id()
    data["nodes"][nid] = {
        "type": "section",
        "heading": heading,
        "level": level,
        "children": [],
        "content": content
    }

    if parent:
        if parent not in data["nodes"]:
            raise ValueError("Parent not found: " + parent)
        siblings = data["nodes"][parent]["children"]
    else:
        siblings = data["root"]

    if after is None:
        siblings.insert(0, nid)
    elif after == "$end":
        siblings.append(nid)
    else:
        if after not in siblings:
            raise ValueError("After node not found in siblings: " + after)
        idx = siblings.index(after) + 1
        siblings.insert(idx, nid)

    return nid


def op_move(data, instr):
    nid = instr["id"]
    new_parent = instr.get("parent")
    after = instr.get("after")

    if nid not in data["nodes"]:
        raise ValueError("Node not found: " + nid)

    # Remove from current location
    old_parent = find_parent(data, nid)
    if old_parent:
        data["nodes"][old_parent]["children"].remove(nid)
    else:
        data["root"].remove(nid)

    # Insert at new location
    if new_parent:
        if new_parent not in data["nodes"]:
            raise ValueError("New parent not found: " + new_parent)
        siblings = data["nodes"][new_parent]["children"]
    else:
        siblings = data["root"]

    if after is None:
        siblings.insert(0, nid)
    elif after == "$end":
        siblings.append(nid)
    else:
        if after not in siblings:
            raise ValueError("After node not found in siblings: " + after)
        idx = siblings.index(after) + 1
        siblings.insert(idx, nid)


OPS = {
    "update": op_update,
    "rename": op_rename,
    "delete": op_delete,
    "add": op_add,
    "move": op_move,
}


def cmd_apply(data, instructions):
    """Apply change instructions to the tree."""
    for i, instr in enumerate(instructions):
        op = instr.get("op")
        if op not in OPS:
            raise ValueError("Unknown op '{}' at index {}".format(op, i))
        result = OPS[op](data, instr)
        if op == "add" and result:
            print("Added: {} -> {}".format(instr["heading"], result))
    return data


def main():
    parser = argparse.ArgumentParser(description="docx-toolkit JSON tree operations")
    sub = parser.add_subparsers(dest="cmd")

    p_show = sub.add_parser("show", help="Print tree structure")
    p_show.add_argument("json_file")
    p_show.add_argument("node_id", nargs="?")

    p_get = sub.add_parser("get", help="Get a single node")
    p_get.add_argument("json_file")
    p_get.add_argument("node_id")

    p_apply = sub.add_parser("apply", help="Apply change instructions")
    p_apply.add_argument("json_file")
    p_apply.add_argument("instructions", help="Instructions JSON file or inline JSON string")
    p_apply.add_argument("-o", "--output", help="Output JSON file (default: overwrite input)")

    args = parser.parse_args()
    if not args.cmd:
        parser.print_help()
        sys.exit(1)

    data = load(args.json_file)

    if args.cmd == "show":
        cmd_show(data, getattr(args, 'node_id', None))
    elif args.cmd == "get":
        cmd_get(data, args.node_id)
    elif args.cmd == "apply":
        instr_arg = args.instructions
        if instr_arg.startswith("["):
            instructions = json.loads(instr_arg)
        else:
            with open(instr_arg, 'r', encoding='utf-8') as f:
                instructions = json.load(f)
        data = cmd_apply(data, instructions)
        out_path = args.output or args.json_file
        save(data, out_path)
        print("Applied {} instructions, saved to {}".format(len(instructions), out_path))


if __name__ == "__main__":
    main()
