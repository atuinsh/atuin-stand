defmodule AtuinStand do
  @moduledoc """
  `AtuinStand` is a generic tree data structure for Elixir. Each node in the tree
  can have user-defined data associated with it, and can have any number of children.

  AtuinStand is an implementation of the
  [`atuin-stand` project](https://github.com/atuinsh/atuin-stand).

  ## API overview

  The AtuinStand API is split into two main parts:

  * `AtuinStand.Tree` - functions that operate on the entire tree
  * `AtuinStand.Node` - functions that operate on a single node

  ## Creating a tree

  ```elixir
  tree = AtuinStand.Tree.new()
  ```

  `AtuinStand.Tree.new/0` calls `Agent.start_link/3` to create a new process to manage the state.
  If creating the process fails, it returns an error tuple in the same form as is returned
  from `Agent.start_link/3`.

  ### Importing and exporting a tree

  You can export the tree as a map with `AtuinStand.Tree.export/1`.

  ```elixir
  tree_data = AtuinStand.Tree.export(tree)
  ```

  To import existing data to a new tree instance, use `AtuinStand.Tree.import/1`.

  ```elixir
  tree = AtuinStand.Tree.import(tree_data)
  ```

  The data exported by `AtuinStand.Tree.export/1` can be safely serialized to JSON.
  Keep in mind that any keys in user-defined data will be serialized as strings,
  even if they were originally created as atoms.

  ## Getting the root node

  The root node is a special node that is always present in the tree. It is the ultimate
  ancestor of all other nodes. Note that it cannot have associated data, and cannot be
  moved in the tree or deleted.

  ```elixir
  root = AtuinStand.Tree.root(tree)
  ```

  ## Creating a new child node

  To create a new node, call `AtuinStand.Node.create_child/2` with the parent node and the ID of
  the new node. Note that all node IDs must be strings. The one exception is the root node,
  which has the ID `:root`.

  ```elixir
  child = AtuinStand.Node.create_child(root, "child")
  child.id
  # => "child"
  ```

  Nodes in the tree are ordered, and by default, a newly created child node is placed at the end
  of its parent's children. If you'd like to place the child at a specific index within its siblings,
  pass the index as the third argument to `AtuinStand.Node.create_child/2`.

  ```elixir
  child = AtuinStand.Node.create_child(root, "child1")
  child = AtuinStand.Node.create_child(root, "child2", 0)
  AtuinStand.Node.children(root)
  # => [child2, child1]
  ```

  ## Querying nodes

  You can check if a node exists with `AtuinStand.Tree.has_node/2`.

  ```elixir
  AtuinStand.Tree.has_node(tree, "child")
  # => true
  ```

  You can get a node by ID with `AtuinStand.Tree.node/2`.

  ```elixir
  node = AtuinStand.Tree.node(tree, "child")
  ```

  You can fetch all of the external nodes (leaves) or internal nodes (branches)
  with `AtuinStand.Tree.external_nodes/1` and `AtuinStand.Tree.internal_nodes/1`, respectively.
  These are aliased as `AtuinStand.Tree.leaves/1` and `AtuinStand.Tree.branches/1`.

  ```elixir
  leaves = AtuinStand.Tree.external_nodes(tree)
  branches = AtuinStand.Tree.internal_nodes(tree)
  ```

  Finally, you can fetch all the nodes in a tree with `AtuinStand.Tree.nodes/2`.

  ```elixir
  nodes = AtuinStand.Tree.nodes(tree, :dfs) # or :bfs
  ```

  ### Traversing the tree

  There are several functions for traversing the tree from a given node:

  * [`AtuinStand.Node.parent(node)`](`AtuinStand.Node.parent/1`)
  * [`AtuinStand.Node.children(node)`](`AtuinStand.Node.children/1`)
  * [`AtuinStand.Node.siblings(node)`](`AtuinStand.Node.siblings/1`)
  * [`AtuinStand.Node.ancestors(node)`](`AtuinStand.Node.ancestors/1`)
  * [`AtuinStand.Node.descendants(node, order)`](`AtuinStand.Node.descendants/2`)

  See the `AtuinStand.Node` module for more information on these functions.


  ## Manipulating nodes

  ### Moving nodes

  You can move a node to a new parent with `AtuinStand.Node.move_to/2`. By default,
  the node is moved to the end of the new parent's children. If you'd like to place the
  node at a specific index within its new siblings, pass the index as the second argument.

  ```elixir
  root = AtuinStand.Tree.root(tree)
  child1 = AtuinStand.Node.create_child(root, "child1")
  child2 = AtuinStand.Node.create_child(root, "child2")
  AtuinStand.Node.move_to(child2, child1)
  AtuinStand.Node.children(root)
  # => [child1]
  AtuinStand.Node.children(child1)
  # => [child2]
  ```

  You can also move a node to be directly before or after another node using
  `AtuinStand.Node.move_before/2` and `AtuinStand.Node.move_after/2`, and you can reposition
  a node within its siblings using `AtuinStand.Node.reposition/2`.

  ### Deleting nodes

  To delete a node, you must specifcy what to do with that node's children, if it has
  any. The options are:

  * `:refuse` - return an error if the node being deleted has children
  * `:cascade` - recursively delete the node and all of its children
  * `:reattach` - move the node's children to the node's parent before deleting it

  ```elixir
  tree = AtuinStand.Tree.new()
  root = AtuinStand.Tree.root(tree)
  child1 = AtuinStand.Node.create_child(root, "child1")
  child2 = AtuinStand.Node.create_child(child1, "child2")
  AtuinStand.Node.delete(child1, :decline)
  # => {:error, :has_children}
  AtuinStand.Node.delete(child1, :cascade)
  AtuinStand.Tree.nodes(tree)
  # => [root]
  ```

  ## Associated data

  You can set and get user-defined data with `AtuinStand.Node.set_data/2` and
  `AtuinStand.Node.get_data/1`. To remain compatible with other `atuin-stand`
  implementations, the data must be a JSON-serializable map.

  ```elixir
  AtuinStand.Node.set_data(node, %{"name" => "Node 1"})
  AtuinStand.Node.get_data(node)
  # => %{"name" => "Node 1"}
  ```

  ## Raising API

  Every function that can return an error has a raising version that raises an
  error instead of returning an error tuple, and returns the value directly instead
  of an ok tuple if successful.

  Each error tuple maps to a specific exception:

  * `{:error, :not_found}` -> `AtuinStand.Error.NodeNotFound`
  * `{:error, :duplicate_id}` -> `AtuinStand.Error.DuplicateNode`
  * `{:error, :invalid_operation}` -> `AtuinStand.Error.InvalidOperation`
  * `{:error, :invalid_data}` -> `AtuinStand.Error.InvalidData`
  * `{:error, :has_children}` -> `AtuinStand.Error.HasChildren`
  """
end
