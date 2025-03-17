defmodule AtuinStand.Node do
  @moduledoc """
  A node in an `AtuinStand.Tree`.

  You can access the node's ID via the `id` property, and the tree it belongs to
  via the `tree` property.

  ## Examples

      iex> tree = AtuinStand.Tree.new()
      iex> root = AtuinStand.Tree.root(tree)
      %AtuinStand.Node{id: :root, tree: tree}
      iex> AtuinStand.Tree.create_child(root, "node1")
      %AtuinStand.Node{id: "node1", tree: tree}
  """
  defstruct [:id, :tree]

  @type t() :: %__MODULE__{id: atom() | String.t(), tree: AtuinStand.Tree.t()}
end
