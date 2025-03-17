defmodule AtuinStand.Tree do
  @moduledoc """
  `AtuinStand.Tree` is a generic tree data structure for Elixir. Each node in the tree
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

  `AtuinStand.Tree.new` calls `Agent.start_link/3` to create a new process to manage the state.
  If creating the process fails, it returns an error tuple in the same form as is returned
  from `Agent.start_link/3`.

  If you have previously serialized a tree using `serialize/1`, you can use `deserialize/1`
  to restore the tree.

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
  `AtuinStand.Node.move_before/2` and `AtuinStand.Node.move_after/2`.

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

  ## Traversing the tree

  There are several functions for traversing the tree:

  * [`AtuinStand.Tree.nodes(tree, order)`](`AtuinStand.Tree.nodes/2`)
  * [`AtuinStand.Node.children(node)`](`AtuinStand.Node.children/1`)
  * [`AtuinStand.Node.parent(node)`](`AtuinStand.Node.parent/1`)
  * [`AtuinStand.Node.siblings(node)`](`AtuinStand.Node.siblings/1`)
  * [`AtuinStand.Node.descendants(node, order)`](`AtuinStand.Node.descendants/2`)
  * [`AtuinStand.Node.ancestors(node)`](`AtuinStand.Node.ancestors/1`)

  See the `AtuinStand.Node` module for more information on these functions.

  ## Associated data

  You can set and get user-defined data with `AtuinStand.Node.set_data/2` and
  `AtuinStand.Node.get_data/1`. To remain compatible with other `atuin-stand`
  implementations, the data must be a JSON-serializable map.

  It's recommended to use string keys for the data, as during deserialization
  all keys are converted to strings.

  ```elixir
  AtuinStand.Node.set_data(node, %{"name" => "Node 1"})
  AtuinStand.Node.get_data(node)
  # => %{"name" => "Node 1"}
  ```
  """

  alias AtuinStand.Node
  alias AtuinStand.Internals

  defstruct [:pid]

  @type t() :: %__MODULE__{pid: pid()}

  @doc """
  Creates a new tree. Starts a new process linked to the current process
  to manage the tree's state.

  Returns the tree, or an error tuple if `Agent.start_link/3` fails.
  """
  @spec new() :: t() | {:error, term()}
  def new do
    case Agent.start_link(&Internals.init/0) do
      {:ok, pid} ->
        %__MODULE__{pid: pid}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Serializes the tree to a JSON string map. See `deserialize/1` for more information.
  """
  @spec serialize(tree :: t()) :: String.t()
  def serialize(tree) do
    Agent.get(tree.pid, &Internals.export_data(&1))
    |> JSON.encode!()
  end

  @doc """
  Deserializes a JSON string generated with `serialize/1` to a tree.

  Calls `Agent.start_link/3` to create a new process to manage the tree's state,
  and returns the tree, or an error tuple if `Agent.start_link/3` fails,
  similar to `new/0`.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> child = AtuinStand.Node.create_child(root, "child")
      iex> AtuinStand.Node.set_data(child, %{name: "Child"})
      iex> tree_data = AtuinStand.Tree.serialize(tree)
      iex> AtuinStand.Tree.destroy(tree)
      iex> tree = AtuinStand.Tree.deserialize(tree_data)
      iex> child = AtuinStand.Tree.node(tree, "child")
      %AtuinStand.Node{id: "child", tree: tree}
      iex> AtuinStand.Node.get_data(child)
      %{"name" => "Child"}
  """
  @spec deserialize(data :: String.t()) :: t() | {:error, term()}
  def deserialize(data) do
    data = JSON.decode!(data)

    case Agent.start_link(fn -> Internals.from_data(data) end) do
      {:ok, pid} ->
        %__MODULE__{pid: pid}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Shuts down the tree and frees up its resources.

  Returns `:ok` if the tree was successfully stopped, or `{:error, reason}` if it was not.
  See `Agent.stop/1` for more information.

  Note that all nodes associated with the tree are invalid once the tree is destroyed.
  """
  def destroy(tree) do
    Agent.stop(tree.pid)
  end

  @doc """
  Returns the root node of the tree.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> root.id
      :root
  """
  @spec root(tree :: t()) :: Node.t()
  def root(tree) do
    %Node{id: :root, tree: tree}
  end

  @doc """
  Returns the node with the given ID.

  Returns `{:error, :not_found}` if the node does not exist.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Node.create_child(root, "node1")
      iex> node1 = AtuinStand.Tree.node(tree, "node1")
      iex> node1.id
      "node1"
  """
  @spec node(tree :: t(), id :: atom() | String.t()) :: Node.t() | {:error, atom()}
  def node(tree, id) do
    case {id, has_node(tree, id)} do
      {:root, _} ->
        %Node{id: :root, tree: tree}

      {id, true} ->
        %Node{id: id, tree: tree}

      {_, false} ->
        {:error, :not_found}
    end
  end

  @doc """
  Checks if a node with the given ID exists in the tree.

  The only atom for which this function returns `true` is `:root`.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> AtuinStand.Tree.has_node(tree, "node1")
      false
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Node.create_child(root, "node1")
      iex> AtuinStand.Tree.has_node(tree, "node1")
      true
  """
  @spec has_node(tree :: t(), id :: atom() | String.t()) :: boolean()
  def has_node(tree, id) do
    case id do
      :root ->
        true

      id ->
        Agent.get(tree.pid, &Internals.has_node(&1, id))
    end
  end

  @doc """
  Returns a list of all nodes in the tree.

  Provide `:dfs` or `:bfs` as an optional argument to return the results in
  depth-first or breadth-first order, respectively. Defaults to `:dfs`.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> node1 = AtuinStand.Node.create_child(root, "node1")
      iex> node2 = AtuinStand.Node.create_child(root, "node2")
      iex> node3 = AtuinStand.Node.create_child(root, "node3")
      iex> node4 = AtuinStand.Node.create_child(node2, "node4")
      iex> AtuinStand.Tree.nodes(tree, :dfs)
      [root, node1, node2, node4, node3]
      iex> AtuinStand.Tree.nodes(tree, :bfs)
      [root, node1, node2, node3, node4]
  """
  @spec nodes(tree :: t(), order :: :dfs | :bfs) :: [Node.t()]
  def nodes(tree, order \\ :dfs) do
    Agent.get(tree.pid, &Internals.get_nodes_in_order(&1, order, :root))
    |> Enum.map(fn node -> %Node{id: node, tree: tree} end)
  end

  @doc """
  Returns a list of all external nodes (nodes with no children) in the tree, including the
  root node (if applicable).

  Provide `:dfs` or `:bfs` as an optional argument to return the results in depth-first
  or breadth-first order, respectively. Defaults to `:dfs`.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Tree.external_nodes(tree)
      [root]
      iex> node1 = AtuinStand.Node.create_child(root, "node1")
      iex> node2 = AtuinStand.Node.create_child(root, "node2")
      iex> node3 = AtuinStand.Node.create_child(root, "node3")
      iex> node4 = AtuinStand.Node.create_child(node2, "node4")
      iex> AtuinStand.Tree.external_nodes(tree, :dfs)
      [node1, node4, node3]
      iex> AtuinStand.Tree.external_nodes(tree, :bfs)
      [node1, node3, node4]
  """
  @spec external_nodes(tree :: t(), order :: :dfs | :bfs) :: [Node.t()]
  def external_nodes(tree, order \\ :dfs) do
    Agent.get(tree.pid, &Internals.get_leaves(&1, order))
    |> Enum.map(fn node -> %Node{id: node, tree: tree} end)
  end

  @doc """
  Returns a list of all internal nodes (nodes with children) in the tree, including the
  root node (if applicable).

  Provide `:dfs` or `:bfs` as an optional argument to return the results in depth-first
  or breadth-first order, respectively. Defaults to `:dfs`.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> node1 = AtuinStand.Node.create_child(root, "node1")
      iex> node2 = AtuinStand.Node.create_child(root, "node2")
      iex> node3 = AtuinStand.Node.create_child(node1, "node3")
      iex> _ = AtuinStand.Node.create_child(node2, "node4")
      iex> _ = AtuinStand.Node.create_child(node3, "node5")
      iex> AtuinStand.Tree.internal_nodes(tree, :dfs)
      [root, node1, node3, node2]
      iex> AtuinStand.Tree.internal_nodes(tree, :bfs)
      [root, node1, node2, node3]
  """
  @spec internal_nodes(tree :: t(), order :: :dfs | :bfs) :: [Node.t()]
  def internal_nodes(tree, order \\ :dfs) do
    Agent.get(tree.pid, &Internals.get_branches(&1, order))
    |> Enum.map(fn node -> %Node{id: node, tree: tree} end)
  end

  @doc """
  An alias for `external_nodes/1`.
  """
  def leaves(tree), do: external_nodes(tree)

  @doc """
  An alias for `internal_nodes/1`.
  """
  def branches(tree), do: internal_nodes(tree)

  @doc """
  Returns the number of nodes in the tree, including the root node.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> AtuinStand.Tree.size(tree)
      1
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Node.create_child(root, "node1")
      iex> AtuinStand.Tree.size(tree)
      2
      iex> AtuinStand.Node.create_child(root, "node2")
      iex> AtuinStand.Tree.size(tree)
      3
  """
  @spec size(tree :: t()) :: non_neg_integer()
  def size(tree) do
    Agent.get(tree.pid, &Internals.size(&1))
  end
end
