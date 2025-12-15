defmodule TestServer do
  use GenServer, restart: :temporary
  use TwoFaced

  def start_link(args) do
    if info = Keyword.get(args, :info) do
      with {:ok, pid} <- GenServer.start_link(__MODULE__, args) do
        {:ok, pid, info}
      end
    else
      GenServer.start_link(__MODULE__, args)
    end
  end

  @impl TwoFaced
  def init(server, args) do
    GenServer.call(server, {:init, args})
  end

  @impl GenServer
  def init(args) do
    case Keyword.get(args, :phase1, :ok) do
      :ok ->
        {:ok, %{}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl GenServer
  def handle_call({:init, args}, _from, state) do
    case Keyword.get(args, :phase2, :ok) do
      :ok ->
        {:reply, :ok, Map.new(args)}

      {:error, reason} ->
        {:stop, reason, {:error, reason}, state}
    end
  end
end
