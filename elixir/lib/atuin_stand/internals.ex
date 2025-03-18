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

    child_map =
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
            index < 0 -> 0
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

  def update_node(_state, _id, _parent_id, _index \\ nil)

  def update_node(state, :root, _parent_id, _index) do
    {{:error, :invalid_operation}, state}
  end

  def update_node(state, id, parent_id, index) do
    current_parent = get_parent(state, id)

    if current_parent == parent_id do
      update_node_same_parent(state, id, index)
    else
      update_node_new_parent(state, id, parent_id, index)
    end
  end

  def update_node_same_parent(state, id, index \\ nil) do
    if has_node(state, id) do
      old_index = state.data[id].index
      siblings = get_siblings(state, id)

      index =
        cond do
          index == nil -> length(siblings)
          index > length(siblings) -> length(siblings)
          index < 0 -> 0
          true -> index
        end

      nodes_to_decrement =
        siblings
        |> Enum.filter(fn sibling ->
          node = Map.get(state.data, sibling)
          node.index > old_index
        end)

      new_data =
        nodes_to_decrement
        |> Enum.reduce(state.data, fn sibling, acc ->
          Map.update!(acc, sibling, fn node -> %{node | index: node.index - 1} end)
        end)

      nodes_to_increment =
        siblings
        |> Enum.filter(fn sibling ->
          node = Map.get(new_data, sibling)
          node.index >= index
        end)

      new_data =
        nodes_to_increment
        |> Enum.reduce(new_data, fn sibling, acc ->
          Map.update!(acc, sibling, fn node -> %{node | index: node.index + 1} end)
        end)

      new_data =
        Map.update!(new_data, id, fn node -> %{node | index: index} end)

      {:ok,
       %{
         state
         | data: new_data
       }}
    else
      {{:error, :not_found}, state}
    end
  end

  def update_node_new_parent(state, id, parent_id, index \\ nil) do
    case {has_node(state, id), has_node(state, parent_id)} do
      {true, true} ->
        ancestors = get_ancestors(state, parent_id)

        if Enum.any?(ancestors, fn ancestor -> ancestor == id end) do
          {{:error, :invalid_operation}, state}
        else
          old_parent = get_parent(state, id)
          old_siblings = get_siblings(state, id)
          old_index = state.data[id].index

          new_data =
            state.data
            |> (fn data ->
                  nodes_to_update =
                    old_siblings
                    |> Enum.filter(fn id ->
                      node = Map.get(state.data, id)
                      node.index > old_index
                    end)

                  Enum.reduce(nodes_to_update, data, fn id, acc ->
                    Map.update!(acc, id, fn node -> %{node | index: node.index - 1} end)
                  end)
                end).()

          new_siblings = get_children(state, parent_id)

          index =
            cond do
              index == nil -> length(new_siblings)
              index > length(new_siblings) -> length(new_siblings)
              index < 0 -> 0
              true -> index
            end

          new_data =
            new_data
            |> (fn data ->
                  nodes_to_update =
                    new_siblings
                    |> Enum.filter(fn id ->
                      node = Map.get(state.data, id)
                      node.index >= index
                    end)

                  Enum.reduce(nodes_to_update, data, fn id, acc ->
                    Map.update!(acc, id, fn node -> %{node | index: node.index + 1} end)
                  end)
                end).()

          new_child_map =
            state.child_map
            |> Map.update(parent_id, MapSet.new([id]), fn set ->
              MapSet.put(set, id)
            end)
            |> Map.update(old_parent, MapSet.new(), fn set ->
              MapSet.delete(set, id)
            end)

          new_parent_val =
            case parent_id do
              :root -> nil
              id -> id
            end

          new_data =
            new_data
            |> Map.update!(id, fn node ->
              %{node | parent: new_parent_val, index: index}
            end)

          {:ok,
           %{
             state
             | data: new_data,
               child_map: new_child_map
           }}
        end

      _ ->
        {{:error, :not_found}, state}
    end
  end

  def move_relative(state, id, other_id, offset) do
    if has_node(state, id) && has_node(state, other_id) do
      parent = get_parent(state, id)
      other_parent = get_parent(state, other_id)
      other_index = state.data[other_id].index

      if parent == other_parent do
        update_node_same_parent(state, id, other_index + offset)
      else
        update_node_new_parent(state, id, other_parent, other_index + offset)
      end
    else
      {{:error, :not_found}, state}
    end
  end

  def delete_node(state, :root, _strategy) do
    {{:error, :invalid_operation}, state}
  end

  def delete_node(state, id, strategy) do
    case has_node(state, id) do
      false ->
        {{:error, :not_found}, state}

      true ->
        case strategy do
          :refuse -> delete_node_refuse(state, id)
          :cascade -> delete_node_cascade(state, id)
          :reattach -> delete_node_reattach(state, id)
        end
    end
  end

  def delete_node_refuse(state, id) do
    children = get_children(state, id)

    if length(children) > 0 do
      {{:error, :has_children}, state}
    else
      state = delete_single_node(state, id, true)

      {:ok, state}
    end
  end

  def delete_node_cascade(state, id) do
    descendants = get_descendants(state, id)

    state =
      descendants
      |> Enum.reduce(state, fn descendant, acc ->
        delete_single_node(acc, descendant, false)
      end)

    state = delete_single_node(state, id, true)

    {:ok, state}
  end

  def delete_node_reattach(state, id) do
    parent = get_parent(state, id)
    children = get_children(state, id)

    state =
      children
      |> Enum.reduce(state, fn child, acc ->
        {:ok, state} = update_node_new_parent(acc, child, parent)
        state
      end)

    state = delete_single_node(state, id, true)

    {:ok, state}
  end

  def delete_single_node(state, id, reorder_siblings) do
    parent = get_parent(state, id)

    data =
      if reorder_siblings do
        siblings = get_siblings(state, id)
        index = state.data[id].index

        siblings
        |> Enum.filter(fn sibling ->
          node = Map.get(state.data, sibling)
          node.index > index
        end)
        |> Enum.reduce(state.data, fn sibling, acc ->
          Map.update!(acc, sibling, fn node -> %{node | index: node.index - 1} end)
        end)
      else
        state.data
      end

    data = Map.delete(data, id)

    child_map =
      Map.update(state.child_map, parent, MapSet.new(), fn set ->
        MapSet.delete(set, id)
      end)

    %{state | data: data, child_map: child_map}
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
      node -> node.parent || :root
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
