# TwoFaced

Two-phase initialization for OTP-compliant processes.

TwoFaced provides a mechanism to perform initialization in two distinct phases when starting processes under a `DynamicSupervisor`. This design helps prevent blocking the supervisor during long-running initialization tasks while maintaining proper error handling and process lifecycle management.

## Usage

```elixir
defmodule MyWorker do
  use GenServer
  use TwoFaced

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl TwoFaced
  def init(server, args) do
    # Phase 2: Additional initialization after the process is started
    GenServer.call(server, {:init, args})
  end

  @impl GenServer
  def init(_args) do
    # Phase 1: Fast initialization that won't block the supervisor
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:init, args}, _from, state) do
    # Perform long-running setup here
    {:reply, :ok, Map.new(args)}
  end
end

# Start the worker using TwoFaced.start_child/2
{:ok, sup} = DynamicSupervisor.start_link(strategy: :one_for_one)
{:ok, pid} = TwoFaced.start_child(sup, {MyWorker, [key: :value]})
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `two_faced` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:two_faced, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/two_faced>.

