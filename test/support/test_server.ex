defmodule TestServer do
  use GenServer, restart: :temporary

  def start_link(args) do
    if info = Keyword.get(args, :info) do
      with {:ok, pid} <- GenServer.start_link(__MODULE__, args) do
        {:ok, pid, info}
      end
    else
      GenServer.start_link(__MODULE__, args)
    end
  end

  @impl GenServer
  def init(args) do
    case Keyword.get(args, :phase1, :ok) do
      :ok ->
        {:ok, %{}, {:continue, {:init, args}}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl GenServer
  def handle_continue({:init, args}, state) do
    if delay = Keyword.get(args, :init_delay) do
      :timer.sleep(delay)
    end

    case Keyword.get(args, :phase2, :ok) do
      :ok ->
        {:noreply, Map.new(args)}

      {:error, reason} ->
        {:stop, reason, state}

      {:badmatch, v, v} ->
        {:noreply, state}

      {:raise, exception} ->
        raise exception
    end
  end

  @impl GenServer
  def handle_info({TwoFaced, :ack, ref}, state) do
    TwoFaced.acknowledge(ref)
    {:noreply, state}
  end
end
