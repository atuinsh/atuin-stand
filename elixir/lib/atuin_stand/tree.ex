defmodule AtuinStand.Tree do
  @moduledoc """
  A generic, ordered tree.

  For a more detailed overview of the API, see `AtuinStand`.

  ## Raising API

  Every function that can return an error has a raising version that raises an
  error instead of returning an error tuple, and returns the node instead of an
  ok tuple if successful.

  Each error tuple maps to a specific exception:

  * `{:error, :not_found}` -> `AtuinStand.Error.NodeNotFound`
  * `{:error, :duplicate_id}` -> `AtuinStand.Error.DuplicateNode`
  * `{:error, :invalid_operation}` -> `AtuinStand.Error.InvalidOperation`
  * `{:error, :invalid_data}` -> `AtuinStand.Error.InvalidData`
  * `{:error, :has_children}` -> `AtuinStand.Error.HasChildren`
  """

  alias __MODULE__, as: Tree
  alias AtuinStand.Node
  alias AtuinStand.Internals
  alias AtuinStand.Error

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
  Exports the tree as an Elixir map.

  To be compatible with other `atuin-stand` implementations, any user-defined data stored
  in the tree should use string keys.
  """
  @spec export(tree :: t()) :: map()
  def export(%Tree{} = tree) do
    Agent.get(tree.pid, &Internals.export_data(&1))
  end

  @doc """
  Imports a tree from an Elixir map generated with `export/1`, or exported from
  another `atuin-stand` implementation.

  Calls `Agent.start_link/3` to create a new process to manage the tree's state,
  and returns the tree, or an error tuple if `Agent.start_link/3` fails,
  similar to `new/0`.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> {:ok, child} = AtuinStand.Node.create_child(root, "child")
      iex> AtuinStand.Node.set_data(child, %{"name" => "Child"})
      iex> tree_data = AtuinStand.Tree.export(tree)
      iex> AtuinStand.Tree.destroy(tree)
      iex> tree = AtuinStand.Tree.import(tree_data)
      iex> {:ok, child} = AtuinStand.Tree.node(tree, "child")
      {:ok, %AtuinStand.Node{id: "child", tree: tree}}
      iex> AtuinStand.Node.get_data(child)
      {:ok, %{"name" => "Child"}}
  """
  @spec import(data :: map()) :: t() | {:error, term()}
  def import(data) do
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
  def destroy(%Tree{} = tree) do
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
  def root(%Tree{} = tree) do
    %Node{id: :root, tree: tree}
  end

  @doc """
  Returns the node with the given ID.

  Returns `{:error, :not_found}` if the node does not exist.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Node.create_child(root, "node1")
      iex> {:ok, node1} = AtuinStand.Tree.node(tree, "node1")
      iex> node1.id
      "node1"
  """
  @spec node(tree :: t(), id :: atom() | String.t()) :: {:ok, Node.t()} | {:error, atom()}
  def node(%Tree{} = tree, id) do
    case {id, has_node(tree, id)} do
      {:root, _} ->
        {:ok, %Node{id: :root, tree: tree}}

      {id, true} ->
        {:ok, %Node{id: id, tree: tree}}

      {_, false} ->
        {:error, :not_found}
    end
  end

  @doc """
  A raising version of `node/2`.
  """
  @spec node!(tree :: t(), id :: atom() | String.t()) :: Node.t()
  def node!(%Tree{} = tree, id) do
    case node(tree, id) do
      {:ok, node} ->
        node

      {:error, :not_found} ->
        raise Error.NodeNotFound, id: id
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
  def has_node(%Tree{} = tree, id) do
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
      iex> {:ok, node1} = AtuinStand.Node.create_child(root, "node1")
      iex> {:ok, node2} = AtuinStand.Node.create_child(root, "node2")
      iex> {:ok, node3} = AtuinStand.Node.create_child(root, "node3")
      iex> {:ok, node4} = AtuinStand.Node.create_child(node2, "node4")
      iex> AtuinStand.Tree.nodes(tree, :dfs)
      [root, node1, node2, node4, node3]
      iex> AtuinStand.Tree.nodes(tree, :bfs)
      [root, node1, node2, node3, node4]
  """
  @spec nodes(tree :: t(), order :: :dfs | :bfs) :: [Node.t()]
  def nodes(%Tree{} = tree, order \\ :dfs) do
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
      iex> {:ok, node1} = AtuinStand.Node.create_child(root, "node1")
      iex> {:ok, node2} = AtuinStand.Node.create_child(root, "node2")
      iex> {:ok, node3} = AtuinStand.Node.create_child(root, "node3")
      iex> {:ok, node4} = AtuinStand.Node.create_child(node2, "node4")
      iex> AtuinStand.Tree.external_nodes(tree, :dfs)
      [node1, node4, node3]
      iex> AtuinStand.Tree.external_nodes(tree, :bfs)
      [node1, node3, node4]
  """
  @spec external_nodes(tree :: t(), order :: :dfs | :bfs) :: [Node.t()]
  def external_nodes(%Tree{} = tree, order \\ :dfs) do
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
      iex> {:ok, node1} = AtuinStand.Node.create_child(root, "node1")
      iex> {:ok, node2} = AtuinStand.Node.create_child(root, "node2")
      iex> {:ok, node3} = AtuinStand.Node.create_child(node1, "node3")
      iex> _ = AtuinStand.Node.create_child(node2, "node4")
      iex> _ = AtuinStand.Node.create_child(node3, "node5")
      iex> AtuinStand.Tree.internal_nodes(tree, :dfs)
      [root, node1, node3, node2]
      iex> AtuinStand.Tree.internal_nodes(tree, :bfs)
      [root, node1, node2, node3]
  """
  @spec internal_nodes(tree :: t(), order :: :dfs | :bfs) :: [Node.t()]
  def internal_nodes(%Tree{} = tree, order \\ :dfs) do
    Agent.get(tree.pid, &Internals.get_branches(&1, order))
    |> Enum.map(fn node -> %Node{id: node, tree: tree} end)
  end

  @doc """
  An alias for `external_nodes/1`.
  """
  def leaves(%Tree{} = tree), do: external_nodes(tree)

  @doc """
  An alias for `internal_nodes/1`.
  """
  def branches(%Tree{} = tree), do: internal_nodes(tree)

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
  def size(%Tree{} = tree) do
    Agent.get(tree.pid, &Internals.size(&1))
  end
end
