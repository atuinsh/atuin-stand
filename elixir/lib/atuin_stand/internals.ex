defmodule AtuinStand.Internals do
  @moduledoc false

  def init() do
    %{
      data: %{},
      child_map: %{root: MapSet.new()}
    }
  end

  def export_data(state) do
    state.data
  end

  def from_data(data) do
    data =
      Enum.map(data, fn {key, value} ->
        {key, atomize_keys(value, ["id", "parent", "index", "data"])}
      end)
      |> Enum.into(%{})

    child_map = %{root: MapSet.new()}

    Map.keys(data)
    |> Enum.reduce(child_map, fn id, acc ->
      Map.update(
        acc,
        data[id].parent || :root,
        MapSet.put(Map.get(acc, data[id].parent || :root, MapSet.new()), id),
        fn set ->
          MapSet.put(set, id)
        end
      )
    end)

    %{
      data: data,
      child_map: child_map
    }
  end

  def create_child(state, parent_id, child_id, index \\ nil) do
    case {has_node(state, child_id), has_node(state, parent_id)} do
      {true, _} ->
        {{:error, :duplicate_id}, state}

      {_, false} ->
        {{:error, :not_found}, state}

      {false, true} ->
        children = get_children(state, parent_id)

        index =
          cond do
            index == nil -> length(children)
            index > length(children) -> length(children)
            true -> index
          end

        parent_id =
          case parent_id do
            :root -> nil
            id -> id
          end

        child_map =
          Map.update(state.child_map, parent_id || :root, MapSet.new([child_id]), fn set ->
            MapSet.put(set, child_id)
          end)
          |> Map.put(child_id, MapSet.new())

        data =
          state.data
          |> (fn data ->
                nodes_to_update =
                  children
                  |> Enum.filter(fn id ->
                    node = Map.get(state.data, id)
                    node.index >= index
                  end)

                Enum.reduce(nodes_to_update, data, fn id, acc ->
                  Map.update!(acc, id, fn node -> %{node | index: node.index + 1} end)
                end)
              end).()
          |> Map.put(child_id, %{
            id: child_id,
            data: %{},
            parent: parent_id,
            index: index
          })

        {:ok,
         %{
           state
           | data: data,
             child_map: child_map
         }}
    end
  end

  def has_node(state, id) do
    case id do
      :root -> true
      id -> Map.has_key?(state.data, id)
    end
  end

  def get_leaves(state, order) do
    nodes = get_nodes_in_order(state, order, :root)

    nodes
    |> Enum.filter(fn key ->
      set = Map.get(state.child_map, key)
      set == nil || MapSet.size(set) == 0
    end)
  end

  def get_branches(state, order) do
    nodes = get_nodes_in_order(state, order, :root)

    nodes
    |> Enum.filter(fn key ->
      set = Map.get(state.child_map, key)
      set != nil && MapSet.size(set) > 0
    end)
  end

  def size(state) do
    Map.keys(state.child_map)
    |> length()
  end

  def get_node_data(state, id) do
    case Map.get(state.data, id) do
      nil -> {:error, :not_found}
      node -> {:ok, node.data}
    end
  end

  def set_node_data(state, id, user_data) do
    case Map.get(state.data, id) do
      nil ->
        {{:error, :not_found}, state}

      node ->
        data = Map.put(state.data, id, %{node | data: user_data})
        {:ok, %{state | data: data}}
    end
  end

  def get_parent(state, id) do
    case Map.get(state.data, id) do
      nil -> {:error, :not_found}
      node -> {:ok, node.parent || :root}
    end
  end

  def get_ancestors(state, id, acc \\ [])

  def get_ancestors(_state, :root, _acc) do
    []
  end

  def get_ancestors(state, id, acc) do
    case Map.get(state.data, id) do
      nil ->
        {:error, :not_found}

      node ->
        parent = node.parent || :root

        case parent do
          :root -> Enum.reverse(acc) ++ [:root]
          parent -> get_ancestors(state, parent, [parent | acc])
        end
    end
  end

  def get_descendants(state, id, order \\ :dfs) do
    get_nodes_in_order(state, order, id)
    |> Enum.drop(1)
  end

  def get_children(state, id) do
    case Map.get(state.child_map, id) do
      nil ->
        []

      set ->
        MapSet.to_list(set)
        |> Enum.sort(fn a, b -> state.data[a].index < state.data[b].index end)
    end
  end

  def get_siblings(state, id) do
    case Map.get(state.data, id) do
      nil ->
        {:error, :not_found}

      node ->
        parent = node.parent || :root

        get_children(state, parent)
        |> Enum.filter(fn child -> child != id end)
    end
  end

  def get_nodes_in_order(state, order, current, acc \\ []) do
    case order do
      :dfs -> do_get_nodes_in_order(state, order, current, acc) |> Enum.reverse()
      :bfs -> [current | do_get_nodes_in_order(state, order, current, acc)]
    end
  end

  def do_get_nodes_in_order(state, order, current, acc) do
    case order do
      :dfs ->
        acc = [current | acc]
        children = get_children(state, current)

        Enum.reduce(children, acc, fn child, acc ->
          child_children = do_get_nodes_in_order(state, order, child, [])
          child_children ++ acc
        end)

      :bfs ->
        children = get_children(state, current)
        acc = acc ++ children

        Enum.reduce(children, acc, fn child, acc ->
          do_get_nodes_in_order(state, order, child, acc)
        end)
    end
  end

  def get_node_depth(state, id) do
    case get_ancestors(state, id) do
      {:error, :not_found} -> {:error, :not_found}
      ancestors -> length(ancestors)
    end
  end

  defp atomize_keys(map, allowed_keys) when is_map(map) do
    Enum.map(map, fn {key, value} ->
      if key in allowed_keys do
        {String.to_atom(key), value}
      else
        {key, value}
      end
    end)
    |> Enum.into(%{})
  end
end
