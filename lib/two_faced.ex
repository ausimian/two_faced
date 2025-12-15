defmodule TwoFaced do
  @moduledoc """
  Two-phase initialization for OTP-compliant processes.

  This module provides a mechanism to perform a second stage of initialization
  after a process has been started. It defines a behaviour with a callback `init/2`
  that must be implemented by modules using this functionality.

  The purpose of this design is to allow processes to complete their initial setup
  in two distinct phases, which can be useful in scenarios where long-running
  initialization risks blocking dynamic supervisors.

  ## Example

      defmodule MyWorker do
        use GenServer
        @behaviour TwoFaced

        def start_link(args) do
          GenServer.start_link(__MODULE__, args)
        end

        @impl TwoFaced
        def init(server, args) do
          # Second stage initialization
          GenServer.call(server, {:init, args})
        end

        @impl GenServer
        def init(args) do
          # First stage initialization
          {:ok, %{}}
        end

        @impl GenServer
        def handle_call({:init, args}, _from, state) do
          # Perform additional setup
          new_state = perform_additional_setup(state, args)
          {:reply, :ok, new_state}
        end
      end

      # Starting the worker under a DynamicSupervisor
      DynamicSupervisor.start_child(supervisor, {MyWorker, initial_args})

  ## Handling Errors

  If the second stage initialization fails, the process should ensure that it
  replies _and then terminates_.

      defmodule MyFailingWorker do
        use GenServer
        @behaviour TwoFaced

        @impl TwoFaced
        def init(server, args) do
          # Second stage initialization
          GenServer.call(server, {:init, args})
        end

        @impl GenServer
        def handle_call({:init, args}, _from, state) do
          case maybe_failing_setup() do
            {:ok, new_state} ->
              {:reply, :ok, new_state}

            {:error, reason} ->
              # Reply and then terminate
              {:stop, reason, {:error, :failed}, state}
          end
        end
      end
  """

  @type server :: GenServer.server()
  @type return :: :ok | {:error, any()}

  @doc """
  Second stage initialization callback.
  """
  @callback init(server(), any()) :: return()

  defmacro __using__(_opts) do
    quote do
      @behaviour TwoFaced
    end
  end

  def start_child(supervisor, child_spec) do
    case DynamicSupervisor.start_child(supervisor, child_spec) do
      {:ok, pid} ->
        with :ok <- two_faced_init(pid, child_spec) do
          {:ok, pid}
        end

      {:ok, pid, info} ->
        with :ok <- two_faced_init(pid, child_spec) do
          {:ok, pid, info}
        end

      other ->
        other
    end
  end

  defp two_faced_init(pid, child_spec) do
    {mod, _fun, _args} = :proc_lib.initial_call(pid)
    mod.init(pid, get_args(child_spec))
  end

  defp get_args({_mod, args}), do: args
  defp get_args(mod) when is_atom(mod), do: []
end
