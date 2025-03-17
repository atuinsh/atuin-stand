defmodule AtuinStandTreeTest do
  use ExUnit.Case, async: true
  doctest AtuinStand.Tree, except: [:moduledoc]
  doctest AtuinStand.Node

  alias AtuinStand.Tree

  setup do
    tree = Tree.new()
    root = Tree.root(tree)
    node1 = Tree.create_child(root, "node1")
    node2 = Tree.create_child(root, "node2")
    node3 = Tree.create_child(root, "node3")

    node4 = Tree.create_child(node1, "node4")
    node5 = Tree.create_child(node1, "node5")

    node6 = Tree.create_child(node2, "node6")
    node7 = Tree.create_child(node2, "node7")
    node8 = Tree.create_child(node2, "node8")

    node9 = Tree.create_child(node6, "node9")
    node10 = Tree.create_child(node6, "node10")

    {:ok,
     tree: tree,
     root: root,
     node1: node1,
     node2: node2,
     node3: node3,
     node4: node4,
     node5: node5,
     node6: node6,
     node7: node7,
     node8: node8,
     node9: node9,
     node10: node10}
  end

  test "does not allow duplicate IDs", context do
    assert Tree.create_child(context.root, "node1") == {:error, :duplicate_id}
  end

  test "gets node IDs", context do
    assert context.root.id == :root
    assert context.node1.id == "node1"
    assert context.node10.id == "node10"
  end

  test "checks for node existence", context do
    assert Tree.has_node(context.tree, :root)
    assert Tree.has_node(context.tree, "node1")
    assert Tree.has_node(context.tree, "node10")
    assert Tree.has_node(context.tree, "node11") == false
  end

  test "fetches nodes", context do
    assert Tree.get_node(context.tree, :root) == context.root
    assert Tree.get_node(context.tree, "node1") == context.node1
    assert Tree.get_node(context.tree, "node10") == context.node10
    assert Tree.get_node(context.tree, "node11") == {:error, :not_found}
  end
end
