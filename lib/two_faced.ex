defmodule TwoFaced do
  @moduledoc """
  Two-phase child process initialization for OTP-compliant processes.

  This module provides functionality to start child processes that require
  two-phase initialization. It is particularly useful when using dynamic
  supervisors where the child process needs to perform lengthy initialization
  without blocking the supervisor.

  Applications that wish to utilize this functionality should:

  1. Define their child processes to support a two-phase initialization pattern, typically
     using `c:GenServer.handle_continue/2` callbacks and handling the acknowledgment message
     via `c:GenServer.handle_info/2`.
  2. Parent their child processes under a DynamicSupervisor.
  3. Use `start_child/2` or `start_child/3` to start and initialize the child processes.

  Handling two-pase initialization means deferring long-running setup tasks via
  `c:GenServer.handle_continue/2` callbacks in GenServer or similar OTP behaviours, and handling
  an acknowledgment message (of type `t:ack_request/0`) to signal completion.

  ## Example
      defmodule MyServer do
        use GenServer

        @impl GenServer
        def init(args) do
          {:ok, %{}, {:continue, {:init, args}}}
        end

        @impl GenServer
        def handle_continue({:init, args}, state) do
          # Perform lengthy initialization here
          :timer.sleep(2000)
          {:noreply, state}
        end

        @impl GenServer
        # Acknowledge initialization completion
        def handle_info({TwoFaced, :ack, ref}, state) do
          TwoFaced.acknowledge(ref)
          {:noreply, state}
        end
      end

      {:ok, sup} = DynamicSupervisor.start_link(strategy: :one_for_one)
      child_spec = {MyServer, some_arg: :value}
      {:ok, pid} = TwoFaced.start_child(sup, child_spec)
      true = Process.alive?(pid)
  """

  @type ack_request() :: {TwoFaced, :ack, reference()}
  @type ack_response() :: {:ack, reference()}

  @type child_spec ::
          Supervisor.child_spec()
          | {module, term}
          | module
          | :supervisor.child_spec()

  @doc """
  Sends an acknowledgment message to the given reference.

  This function is typically called from within the child process on receipt of the
  acknowledgment request message sent by `TwoFaced.start_child/2,3`.

  ## Example
      def handle_info({TwoFaced, :ack, ref}, state) do
        TwoFaced.acknowledge(ref)
        {:noreply, state}
      end
  """
  @spec acknowledge(reference()) :: :ok
  def acknowledge(ref) when is_reference(ref) do
    send(ref, {:ack, ref})
    :ok
  end

  @doc """
  Same as `start_child/3` with a default timeout of 5000 milliseconds.
  """
  @spec start_child(Supervisor.supervisor(), child_spec()) :: DynamicSupervisor.on_start_child()
  def start_child(sup, child_spec) do
    start_child(sup, child_spec, 5_000)
  end

  @doc """
  Starts a child process under the given supervisor and waits for its
  two-phase initialization to complete.

  After starting the child process, this function sends an acknowledgment
  request message to the child and waits for an acknowledgment response
  within the specified timeout period. If the acknowledgment is received within
  the timeout, it returns `{:ok, pid}` or `{:ok, pid, info}`.

  If the timeout is exceeded, the child process is terminated and
  `{:error, :timeout}` is returned. If the child process terminates before
  sending the acknowledgment, the termination reason is returned as an error.
  """
  @spec start_child(Supervisor.supervisor(), child_spec(), non_neg_integer()) ::
          DynamicSupervisor.on_start_child()
  def start_child(sup, child_spec, timeout) when is_integer(timeout) and timeout >= 0 do
    case DynamicSupervisor.start_child(sup, child_spec) do
      {:ok, pid} ->
        with :ok <- wait_for_initialization(pid, timeout) do
          {:ok, pid}
        end

      {:ok, pid, info} ->
        with :ok <- wait_for_initialization(pid, timeout) do
          {:ok, pid, info}
        end

      other ->
        other
    end
  end

  defp wait_for_initialization(pid, timeout) do
    ref = Process.monitor(pid, alias: :reply_demonitor)

    send(pid, {TwoFaced, :ack, ref})

    receive do
      {:ack, ^ref} ->
        :ok

      {:DOWN, ^ref, :process, ^pid, reason} ->
        to_error(reason)
    after
      timeout ->
        Process.demonitor(ref, [:flush])
        Process.exit(pid, :kill)
        {:error, :timeout}
    end
  end

  defp to_error(reason) do
    case reason do
      {{_kind, _} = error, _stacktrace} ->
        # Extract structured errors from GenServer.call failures
        {:error, error}

      {%_{} = exception, _stacktrace} ->
        # Extract exception structs
        {:error, exception}

      {reason, _stacktrace} when is_atom(reason) ->
        # Simple atom reasons like :noproc, :timeout
        {:error, reason}

      reason ->
        # Fallback for any other exit
        {:error, reason}
    end
  end
end
