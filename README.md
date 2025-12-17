# TwoFaced

  Two-phase child process initialization for OTP-compliant processes.

  This module provides functionality to start child processes that require
  two-phase initialization. It is particularly useful when using dynamic
  supervisors where the child process needs to perform lengthy initialization
  without blocking the supervisor.

  Applications that wish to utilize this functionality should:

  1. Define their child processes to support a two-phase initialization pattern.
  2. Parent their child processes under a DynamicSupervisor.
  3. Use `TwoFaced.start_child/2,3` to start and initialize the child processes.

  Handling two-phase initialization means deferring long-running setup tasks via
  handle_continue/2 callbacks in GenServer or similar OTP behaviours, and handling
  an acknowledgment message (of type `ack_request()`) to signal completion.

## Usage

  ```elixir
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
  ```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `two_faced` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:two_faced, "~> 0.2.2"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/two_faced>.

