defmodule AtuinStand.Error do
  @moduledoc false

  defmodule NodeNotFound do
    @moduledoc """
    Raised when a node is not found in the tree.
    """

    defexception [:id]

    def message(exception) do
      "Node with id \"#{exception.id}\" not found"
    end
  end

  defmodule DuplicateNode do
    @moduledoc """
    Raised when a node with the same ID already exists in the tree.
    """

    defexception [:id]

    def message(exception) do
      "Node with id \"#{exception.id}\" already exists"
    end
  end

  defmodule InvalidData do
    @moduledoc """
    Raised when invalid data is set on a node.
    """

    defexception [:id]

    def message(exception) do
      "Invalid data for node with id \"#{exception.id}\""
    end
  end

  defmodule HasChildren do
    @moduledoc """
    Raised when a node has children and is deleted with `:refuse`.
    """

    defexception [:id]

    def message(exception) do
      "Node with id \"#{exception.id}\" has children"
    end
  end

  defmodule InvalidOperation do
    @moduledoc """
    Raised when an invalid operation is performed on a node.
    """

    defexception [:id, :operation]

    def message(exception) do
      "Invalid operation: \"#{exception.operation}\" on node with id \"#{exception.id}\""
    end
  end
end
