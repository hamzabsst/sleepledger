#!/usr/bin/env python3
"""Optional tree-sitter check. Install tree-sitter + tree-sitter-swift in an isolated environment.
This parses Swift grammar; it cannot type-check Apple APIs or execute tests.
"""
from pathlib import Path
from tree_sitter import Language, Parser
import tree_sitter_swift
parser=Parser(Language(tree_sitter_swift.language()))
errors=[]
files=sorted(Path(__file__).resolve().parents[1].rglob('*.swift'))
for file in files:
    tree=parser.parse(file.read_bytes())
    def walk(node):
        if node.type=='ERROR' or node.is_missing: errors.append((file,node.start_point,node.type,node.text[:120]))
        for child in node.children: walk(child)
    walk(tree.root_node)
for error in errors: print(error)
if errors: raise SystemExit(1)
print(f'PASS: {len(files)} Swift files parsed without syntax errors (not type-checked).')
