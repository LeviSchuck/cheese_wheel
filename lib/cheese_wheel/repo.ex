defmodule CheeseWheel.Repo do
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  def get(repo, key) when is_pid(repo) do
    GenServer.call(repo, {:get, key})
  end
  def get(name, key) when is_atom(name) do
    case :ets.lookup(name, key) do
      [] -> nil
      [{_, document}] -> document
    end
  end
  def get(repo, name, key) when is_pid(repo) and is_atom(name) do
    case :ets.lookup(name, key) do
      [] -> get(repo, key)
      [{_, document}] -> document
    end
  end
  def set(repo, key, document) when is_pid(repo) do
    GenServer.call(repo, {:set, key, document})
  end

  ## Callbacks

  def init(params) do
    path = Keyword.get(params, :path, ".")
    limit = Keyword.get(params, :limit, :infinite)
    name = Keyword.get(params, :name, nil)
    table = case name do
      nil -> :ets.new(:data, [])
      name when is_atom(name) -> :ets.new(name, [:named_table])
      _ -> :ets.new(:data, [])
    end
    {:ok, {path, limit, name, table}}
  end

  def handle_call({:get, key}, _from, state) do
    {path, limit, _, table} = state
    case :ets.lookup(table, key) do
      [] ->
        # Time to do the dirty work
        case File.read(file_path(path, key)) do
          {:ok, content} ->
            document = CheeseWheel.Serial.safe_decode(content)
            :ok = cache_doc(limit, table, key, document)
            {:reply, document, state}
          _ ->
            :ok = cache_doc(limit, table, key, nil)
            {:reply, nil, state}
        end
      [result] -> {:reply, result, state}
    end
  end

  def handle_call({:set, key, document}, _from, state) do
    {path, limit, _, table} = state
    :ok = save_doc(document, file_path(path, key))
    :ok = cache_doc(limit, table, key, document)
    {:reply, :ok, state}
  end

  defp file_path(path, key) do
    bin_key = CheeseWheel.Serial.encode(key)
    hash_key = XXHash.xxh32(bin_key)
    Path.join(path, "#{hash_key}.brt")
  end
  defp save_doc(document, file) do
    # TODO save file
    temp_file = file <> ".temp"
    :ok = File.write(temp_file, CheeseWheel.Serial.encode(document))
    :ok = File.rename(temp_file, file)
    :ok
  end
  defp cache_doc(limit, table, key, document) do
    # TODO evict ets
    case limit do
      :infinite -> nil
      num -> if :ets.info(table, :size) + 1 > limit do
        # Evict 10% of the entries
        case :ets.match(table, :"$1", div(num, 10)) do
          {evicts, _} -> Enum.each(evicts, fn evicts ->
            Enum.each(evicts, fn {key, _} ->
              :ets.delete(table, key)
            end)
          end)
          _ -> nil
        end
      end
    end
    # Insert or replace document with key
    true = :ets.insert(table, {key, document})
    :ok
  end

end
