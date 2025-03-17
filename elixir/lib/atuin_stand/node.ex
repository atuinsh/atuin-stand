defmodule AtuinStand.Node do
  @moduledoc """
  A node in an `AtuinStand.Tree`.

  You can access the node's ID via the `id` property, and the tree it belongs to
  via the `tree` property.

  For a more detailed overview of the API, see `AtuinStand.Tree`.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      %AtuinStand.Node{id: :root, tree: tree}
      iex> AtuinStand.Node.create_child(root, "node1")
      %AtuinStand.Node{id: "node1", tree: tree}
  """

  alias __MODULE__, as: Node
  alias AtuinStand.Tree
  alias AtuinStand.Internals

  defstruct [:id, :tree]

  @type t() :: %__MODULE__{id: atom() | String.t(), tree: Tree.t()}

  @doc """
  Creates a new child node with the given ID.

  User-created nodes must have unique, string IDs. Returns `{:error, :duplicate_id}`
  if a node with the given ID already exists in the tree. Returns `{:error, :not_found}`
  if the parent node is not found in the tree.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Node.create_child(root, "node1")
      %AtuinStand.Node{id: "node1", tree: tree}
      iex> AtuinStand.Node.create_child(root, "node1")
      {:error, :duplicate_id}
  """
  @spec create_child(node :: Node.t(), id :: String.t()) :: Node.t() | {:error, atom()}
  def create_child(%Node{tree: tree} = parent_node, id) when is_binary(id) do
    func = fn state ->
      Internals.create_child(state, parent_node.id, id)
    end

    case Agent.get_and_update(tree.pid, func) do
      :ok ->
        %Node{id: id, tree: tree}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Returns the parent of the given node.

  Returns `{:error, :not_found}` if the node is not found in the tree.
  Returns `{:error, :invalid_node}` if the node is the root node.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Node.parent(root)
      {:error, :invalid_node}
      iex> node1 = AtuinStand.Node.create_child(root, "node1")
      iex> AtuinStand.Node.parent(node1)
      %AtuinStand.Node{id: :root, tree: tree}
      iex> fake_node = %AtuinStand.Node{id: "fake", tree: tree}
      iex> AtuinStand.Node.parent(fake_node)
      {:error, :not_found}
  """
  @spec parent(node :: Node.t()) :: Node.t() | {:error, atom()}
  def parent(%Node{id: :root}), do: {:error, :invalid_node}

  def parent(%Node{id: id, tree: tree}) do
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
      iex> node1 = AtuinStand.Node.create_child(root, "node1")
      iex> node2 = AtuinStand.Node.create_child(root, "node2")
      iex> AtuinStand.Node.children(root)
      [node1, node2]
      iex> AtuinStand.Node.children(node1)
      []
  """
  def children(%Node{id: id, tree: tree}) do
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
      iex> node1 = AtuinStand.Node.create_child(root, "node1")
      iex> node2 = AtuinStand.Node.create_child(root, "node2")
      iex> node3 = AtuinStand.Node.create_child(root, "node3")
      iex> AtuinStand.Node.siblings(node1)
      [node2, node3]
  """
  @spec siblings(node :: Node.t()) :: [Node.t()] | {:error, atom()}
  def siblings(%Node{id: id, tree: tree}) do
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
      iex> node1 = AtuinStand.Node.create_child(root, "node1")
      iex> node2 = AtuinStand.Node.create_child(node1, "node2")
      iex> node3 = AtuinStand.Node.create_child(node2, "node3")
      iex> node4 = AtuinStand.Node.create_child(root, "node4")
      iex> AtuinStand.Node.descendants(node1, :dfs)
      [node2, node3]
      iex> AtuinStand.Node.descendants(root, :bfs)
      [node1, node4, node2, node3]
  """
  @spec descendants(node :: Node.t(), order :: :dfs | :bfs) :: [Node.t()] | {:error, atom()}
  def descendants(%Node{id: id, tree: tree}, order \\ :dfs) do
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
      iex> node1 = AtuinStand.Node.create_child(root, "node1")
      iex> node2 = AtuinStand.Node.create_child(node1, "node2")
      iex> node3 = AtuinStand.Node.create_child(node2, "node3")
      iex> AtuinStand.Node.ancestors(node3)
      [node2, node1, root]
  """
  @spec ancestors(node :: Node.t()) :: [Node.t()] | {:error, atom()}
  def ancestors(%Node{id: id, tree: tree}) do
    Agent.get(tree.pid, &Internals.get_ancestors(&1, id))
    |> Enum.map(fn node -> %Node{id: node, tree: tree} end)
  end

  @doc """
  Returns the depth of the given node.

  For any node, the depth is the number of edges on the path to the root node.
  The root node has a depth of 0, and every other node has a depth of 1 + its parent's depth.

  Equivalent to `length(AtuinStand.Node.ancestors(node))`.

  Returns `{:error, :not_found}` if the node is not found in the tree.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Node.depth(root)
      0
      iex> node1 = AtuinStand.Node.create_child(root, "node1")
      iex> AtuinStand.Node.depth(node1)
      1
      iex> node2 = AtuinStand.Node.create_child(node1, "node2")
      iex> AtuinStand.Node.depth(node2)
      2
  """
  @spec depth(node :: Node.t()) :: non_neg_integer() | {:error, atom()}
  def depth(%Node{id: id, tree: tree}) do
    Agent.get(tree.pid, &Internals.get_node_depth(&1, id))
  end

  @doc """
  Returns the user-defined data associated with the node.

  If the node is not found, returns `{:error, :not_found}`.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      iex> AtuinStand.Node.create_child(root, "node1")
      iex> AtuinStand.Tree.node(tree, "node1")
      ...> |> AtuinStand.Node.set_data(%{"name" => "Node 1"})
      ...> |> AtuinStand.Node.get_data()
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
      iex> AtuinStand.Node.create_child(root, "node1")
      iex> AtuinStand.Tree.node(tree, "node1")
      ...> |> AtuinStand.Node.set_data(%{"name" => "Node 1"})
      ...> |> AtuinStand.Node.get_data()
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
