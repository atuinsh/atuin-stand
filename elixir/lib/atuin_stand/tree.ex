defmodule AtuinStand.Tree do
  @moduledoc """
  `AtuinStand.Tree` is a generic tree data structure for Elixir. Each node in the tree
  can have user-defined data associated with it, and can have any number of children.

  AtuinStand is an implementation of the
  [`atuin-stand` project](https://github.com/atuinsh/atuin-stand).

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

  To create a new node, call `AtuinStand.Tree.create_child/2` with the parent node and the ID of
  the new node. Note that all node IDs must be strings. The one exception is the root node,
  which has the ID `:root`.

  ```elixir
  child = AtuinStand.Tree.create_child(root, "child")
  child.id
  # => "child"
  ```

  ## Querying nodes

  You can check if a node exists with `AtuinStand.Tree.has_node/2`.

  ```elixir
  AtuinStand.Tree.has_node(tree, "child")
  # => true
  ```

  You can get a node by ID with `AtuinStand.Tree.get_node/2`.

  ```elixir
  node = AtuinStand.Tree.get_node(tree, "child")
  ```

  You can fetch all of the external nodes (leaves) or internal nodes (branches)
  with `AtuinStand.Tree.get_external/1` and `AtuinStand.Tree.get_internal/1`, respectively.
  These are aliased as `AtuinStand.Tree.get_leaves/1` and `AtuinStand.Tree.get_branches/1`.

  ```elixir
  leaves = AtuinStand.Tree.get_external(tree)
  branches = AtuinStand.Tree.get_internal(tree)
  ```

  ## Traversing the tree

  There are several functions for traversing the tree:

  * [AtuinStand.Tree.get_nodes(tree, order)](`AtuinStand.Tree.get_nodes/2`)
  * [AtuinStand.Tree.get_children(node)](`AtuinStand.Tree.get_children/1`)
  * [AtuinStand.Tree.get_parent(node)](`AtuinStand.Tree.get_parent/1`)
  * [AtuinStand.Tree.get_siblings(node)](`AtuinStand.Tree.get_siblings/1`)
  * [AtuinStand.Tree.get_descendants(node)](`AtuinStand.Tree.get_descendants/2`)
  * [AtuinStand.Tree.get_ancestors(node)](`AtuinStand.Tree.get_ancestors/1`)

  ## Associated data

  You can set and get user-defined data with `AtuinStand.Tree.set_data/2` and
  `AtuinStand.Tree.get_data/1`. To remain compatible with other `atuin-stand`
  implementations, the data must be a JSON-serializable map.

  It's recommended to use string keys for the data, as during deserialization
  all keys are converted to strings.

  ```elixir
  AtuinStand.Tree.set_data(node, %{"name" => "Node 1"})
  AtuinStand.Tree.get_data(node)
  # => %{"name" => "Node 1"}
  ```
  """

  alias AtuinStand.Internals
  alias AtuinStand.Node

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
      iex> child = AtuinStand.Tree.create_child(root, "child")
      iex> AtuinStand.Tree.set_data(child, %{name: "Child"})
      iex> tree_data = AtuinStand.Tree.serialize(tree)
      iex> AtuinStand.Tree.destroy(tree)
      iex> tree = AtuinStand.Tree.deserialize(tree_data)
      iex> child = AtuinStand.Tree.get_node(tree, "child")
      %AtuinStand.Node{id: "child", tree: tree}
      iex> AtuinStand.Tree.get_data(child)
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
  Creates a new child node with the given ID.

  User-created nodes must have unique, string IDs. Returns `{:error, :duplicate_id}`
  if a node with the given ID already exists in the tree. Returns `{:error, :not_found}`
  if the parent node is not found in the tree.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Tree.create_child(root, "node1")
      %AtuinStand.Node{id: "node1", tree: tree}
      iex> AtuinStand.Tree.create_child(root, "node1")
      {:error, :duplicate_id}
  """
  @spec create_child(node :: Node.t(), id :: String.t()) :: Node.t() | {:error, atom()}
  def create_child(%Node{tree: tree} = parent, id) when is_binary(id) do
    func = fn state ->
      Internals.create_child(state, parent.id, id)
    end

    case Agent.get_and_update(tree.pid, func) do
      :ok ->
        %Node{id: id, tree: tree}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Returns the node with the given ID.

  Returns `{:error, :not_found}` if the node does not exist.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Tree.create_child(root, "node1")
      iex> node1 = AtuinStand.Tree.get_node(tree, "node1")
      iex> node1.id
      "node1"
  """
  @spec get_node(tree :: t(), id :: atom() | String.t()) :: Node.t() | {:error, atom()}
  def get_node(tree, id) do
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
      iex> AtuinStand.Tree.create_child(root, "node1")
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
      iex> node1 = AtuinStand.Tree.create_child(root, "node1")
      iex> node2 = AtuinStand.Tree.create_child(root, "node2")
      iex> node3 = AtuinStand.Tree.create_child(root, "node3")
      iex> node4 = AtuinStand.Tree.create_child(node2, "node4")
      iex> AtuinStand.Tree.get_nodes(tree, :dfs)
      [root, node1, node2, node4, node3]
      iex> AtuinStand.Tree.get_nodes(tree, :bfs)
      [root, node1, node2, node3, node4]
  """
  @spec get_nodes(tree :: t(), order :: :dfs | :bfs) :: [Node.t()]
  def get_nodes(tree, order \\ :dfs) do
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
      iex> AtuinStand.Tree.get_external(tree)
      [root]
      iex> node1 = AtuinStand.Tree.create_child(root, "node1")
      iex> node2 = AtuinStand.Tree.create_child(root, "node2")
      iex> node3 = AtuinStand.Tree.create_child(root, "node3")
      iex> node4 = AtuinStand.Tree.create_child(node2, "node4")
      iex> AtuinStand.Tree.get_external(tree, :dfs)
      [node1, node4, node3]
      iex> AtuinStand.Tree.get_external(tree, :bfs)
      [node1, node3, node4]
  """
  @spec get_external(tree :: t(), order :: :dfs | :bfs) :: [Node.t()]
  def get_external(tree, order \\ :dfs) do
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
      iex> node1 = AtuinStand.Tree.create_child(root, "node1")
      iex> node2 = AtuinStand.Tree.create_child(root, "node2")
      iex> node3 = AtuinStand.Tree.create_child(node1, "node3")
      iex> _ = AtuinStand.Tree.create_child(node2, "node4")
      iex> _ = AtuinStand.Tree.create_child(node3, "node5")
      iex> AtuinStand.Tree.get_internal(tree, :dfs)
      [root, node1, node3, node2]
      iex> AtuinStand.Tree.get_internal(tree, :bfs)
      [root, node1, node2, node3]
  """
  @spec get_internal(tree :: t(), order :: :dfs | :bfs) :: [Node.t()]
  def get_internal(tree, order \\ :dfs) do
    Agent.get(tree.pid, &Internals.get_branches(&1, order))
    |> Enum.map(fn node -> %Node{id: node, tree: tree} end)
  end

  @doc """
  An alias for `get_external/1`.
  """
  def get_leaves(tree), do: get_external(tree)

  @doc """
  An alias for `get_internal/1`.
  """
  def get_branches(tree), do: get_internal(tree)

  @doc """
  Returns the parent of the given node.

  Returns `{:error, :not_found}` if the node is not found in the tree.
  Returns `{:error, :invalid_node}` if the node is the root node.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Tree.get_parent(root)
      {:error, :invalid_node}
      iex> node1 = AtuinStand.Tree.create_child(root, "node1")
      iex> AtuinStand.Tree.get_parent(node1)
      %AtuinStand.Node{id: :root, tree: tree}
      iex> fake_node = %AtuinStand.Node{id: "fake", tree: tree}
      iex> AtuinStand.Tree.get_parent(fake_node)
      {:error, :not_found}
  """
  @spec get_parent(node :: Node.t()) :: Node.t() | {:error, atom()}
  def get_parent(%Node{id: :root}), do: {:error, :invalid_node}

  def get_parent(%Node{id: id, tree: tree}) do
    case Agent.get(tree.pid, &Internals.get_parent(&1, id)) do
      {:ok, parent} -> %Node{id: parent, tree: tree}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns a list of all children of the given node.

  Returns `{:error, :not_found}` if the node is not found in the tree.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> node1 = AtuinStand.Tree.create_child(root, "node1")
      iex> node2 = AtuinStand.Tree.create_child(root, "node2")
      iex> AtuinStand.Tree.get_children(root)
      [node1, node2]
      iex> AtuinStand.Tree.get_children(node1)
      []
  """
  def get_children(%Node{id: id, tree: tree}) do
    case Agent.get(tree.pid, &Internals.get_children(&1, id)) do
      {:error, reason} -> {:error, reason}
      children -> Enum.map(children, fn child -> %Node{id: child, tree: tree} end)
    end
  end

  @doc """
  Returns a list of all siblings (other nodes with the same parent) of the given node.

  Returns `{:error, :not_found}` if the node is not found in the tree.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> node1 = AtuinStand.Tree.create_child(root, "node1")
      iex> node2 = AtuinStand.Tree.create_child(root, "node2")
      iex> node3 = AtuinStand.Tree.create_child(root, "node3")
      iex> AtuinStand.Tree.get_siblings(node1)
      [node2, node3]
  """
  @spec get_siblings(node :: Node.t()) :: [Node.t()] | {:error, atom()}
  def get_siblings(%Node{id: id, tree: tree}) do
    case Agent.get(tree.pid, &Internals.get_siblings(&1, id)) do
      {:error, reason} -> {:error, reason}
      siblings -> Enum.map(siblings, fn sibling -> %Node{id: sibling, tree: tree} end)
    end
  end

  @doc """
  Returns a list of all descendants of the given node.

  Provide `:dfs` or `:bfs` as an optional argument to return the results in
  depth-first or breadth-first order, respectively. Defaults to `:dfs`.

  Returns `{:error, :not_found}` if the node is not found in the tree.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> node1 = AtuinStand.Tree.create_child(root, "node1")
      iex> node2 = AtuinStand.Tree.create_child(node1, "node2")
      iex> node3 = AtuinStand.Tree.create_child(node2, "node3")
      iex> node4 = AtuinStand.Tree.create_child(root, "node4")
      iex> AtuinStand.Tree.get_descendants(node1, :dfs)
      [node2, node3]
      iex> AtuinStand.Tree.get_descendants(root, :bfs)
      [node1, node4, node2, node3]
  """
  @spec get_descendants(node :: Node.t(), order :: :dfs | :bfs) :: [Node.t()] | {:error, atom()}
  def get_descendants(%Node{id: id, tree: tree}, order \\ :dfs) do
    case Agent.get(tree.pid, &Internals.get_descendants(&1, id, order)) do
      {:error, reason} -> {:error, reason}
      descendants -> Enum.map(descendants, fn child -> %Node{id: child, tree: tree} end)
    end
  end

  @doc """
  Returns a list of all ancestors of the given node, starting at the node's parent and
  ending at the root node (inclusive).

  Returns `{:error, :not_found}` if the node is not found in the tree.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> node1 = AtuinStand.Tree.create_child(root, "node1")
      iex> node2 = AtuinStand.Tree.create_child(node1, "node2")
      iex> node3 = AtuinStand.Tree.create_child(node2, "node3")
      iex> AtuinStand.Tree.get_ancestors(node3)
      [node2, node1, root]
  """
  @spec get_ancestors(node :: Node.t()) :: [Node.t()] | {:error, atom()}
  def get_ancestors(%Node{id: id, tree: tree}) do
    Agent.get(tree.pid, &Internals.get_ancestors(&1, id))
    |> Enum.map(fn node -> %Node{id: node, tree: tree} end)
  end

  @doc """
  Returns the depth of the given node.

  For any node, the depth is the number of edges on the path to the root node.
  The root node has a depth of 0, and every other node has a depth of 1 + its parent's depth.

  Equivalent to `length(AtuinStand.Tree.get_ancestors(node))`.

  Returns `{:error, :not_found}` if the node is not found in the tree.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Tree.node_depth(root)
      0
      iex> node1 = AtuinStand.Tree.create_child(root, "node1")
      iex> AtuinStand.Tree.node_depth(node1)
      1
      iex> node2 = AtuinStand.Tree.create_child(node1, "node2")
      iex> AtuinStand.Tree.node_depth(node2)
      2
  """
  @spec node_depth(node :: Node.t()) :: non_neg_integer() | {:error, atom()}
  def node_depth(%Node{id: id, tree: tree}) do
    Agent.get(tree.pid, &Internals.get_node_depth(&1, id))
  end

  @doc """
  Returns the number of nodes in the tree, including the root node.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> AtuinStand.Tree.size(tree)
      1
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Tree.create_child(root, "node1")
      iex> AtuinStand.Tree.size(tree)
      2
      iex> AtuinStand.Tree.create_child(root, "node2")
      iex> AtuinStand.Tree.size(tree)
      3
  """
  @spec size(tree :: t()) :: non_neg_integer()
  def size(tree) do
    Agent.get(tree.pid, &Internals.size(&1))
  end

  @doc """
  Returns the user-defined data associated with the node.

  If the node is not found, returns `{:error, :not_found}`.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Tree.create_child(root, "node1")
      iex> AtuinStand.Tree.get_node(tree, "node1")
      ...> |> AtuinStand.Tree.set_data(%{"name" => "Node 1"})
      ...> |> AtuinStand.Tree.get_data()
      %{"name" => "Node 1"}
  """
  @spec get_data(node :: Node.t()) :: map() | {:error, atom()}
  def get_data(%Node{} = node) do
    case Agent.get(node.tree.pid, &Internals.get_node_data(&1, node.id)) do
      {:ok, data} -> data
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Sets the user-defined data associated with the node. Returns the node.

  The data must be a map, otherwise returns `{:error, :invalid_data}`. When the
  tree is serialized to JSON, the data is serialized as well, so any atom keys
  will be converted to strings.

  If the node is not found, returns `{:error, :not_found}`.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Tree.create_child(root, "node1")
      iex> AtuinStand.Tree.get_node(tree, "node1")
      ...> |> AtuinStand.Tree.set_data(%{"name" => "Node 1"})
      ...> |> AtuinStand.Tree.get_data()
      %{"name" => "Node 1"}
  """
  @spec set_data(node :: Node.t(), data :: map()) :: Node.t() | {:error, atom()}
  def set_data(%Node{} = node, data) when is_map(data) do
    Agent.get_and_update(node.tree.pid, fn state ->
      case Internals.set_node_data(state, node.id, data) do
        {:ok, state} -> {node, state}
        {{:error, reason}, state} -> {{:error, reason}, state}
      end
    end)
  end

  def set_data(_node, _data) do
    {:error, :invalid_data}
  end
end
