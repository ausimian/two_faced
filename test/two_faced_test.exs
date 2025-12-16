defmodule TwoFacedTest do
  use ExUnit.Case
  doctest TwoFaced

  setup do
    [sup: start_supervised!({DynamicSupervisor, strategy: :one_for_one})]
  end

  test "start_child/2 starts and initializes a TwoFaced child", %{sup: sup} do
    child_spec = {TestServer, id: 123}

    assert {:ok, pid} = TwoFaced.start_child(sup, child_spec)
    assert Process.alive?(pid)
    assert %{id: 123} = :sys.get_state(pid)
  end

  test "start_child/2 handles phase1 failure", %{sup: sup} do
    child_spec = {TestServer, phase1: {:error, :failed_phase1}}

    assert {:error, :failed_phase1} = TwoFaced.start_child(sup, child_spec)
  end

  test "start_child/2 handles phase2 failure", %{sup: sup} do
    child_spec = {TestServer, phase2: {:error, :normal}}

    assert {:error, _} = TwoFaced.start_child(sup, child_spec)
  end

  test "start_child/2 works with empty args", %{sup: sup} do
    child_spec = TestServer

    assert {:ok, pid} = TwoFaced.start_child(sup, child_spec)
    assert Process.alive?(pid)
    assert map_size(:sys.get_state(pid)) == 0
  end

  test "start_child/2 works with info tuple", %{sup: sup} do
    child_spec = {TestServer, info: :extra_info}

    assert {:ok, pid, :extra_info} = TwoFaced.start_child(sup, child_spec)
    assert Process.alive?(pid)
    assert map_size(:sys.get_state(pid)) == 1
  end

  test "start_child/2 with raw child spec", %{sup: sup} do
    child_spec = %{
      id: TestServer,
      start: {TestServer, :start_link, [[phase1: :ok, phase2: :ok]]},
      restart: :temporary,
      type: :worker
    }

    assert {:ok, pid} = TwoFaced.start_child(sup, child_spec)
    assert Process.alive?(pid)
    assert %{phase1: :ok, phase2: :ok} = :sys.get_state(pid)
  end

  test "start_child/2 handles badmatch results from phase2", %{sup: sup} do
    child_spec = {TestServer, phase2: {:badmatch, :a, :b}}
    assert {:error, {:case_clause, {:badmatch, :a, :b}}} = TwoFaced.start_child(sup, child_spec)
  end

  test "start_child/2 handles exceptions from phase2", %{sup: sup} do
    child_spec = {TestServer, phase2: {:raise, ArgumentError.exception("invalid argument")}}

    assert {:error, %ArgumentError{message: "invalid argument"}} =
             TwoFaced.start_child(sup, child_spec)
  end

  test "start_child/3 with timeout handles slow initialization", %{sup: sup} do
    child_spec = {TestServer, phase2: :ok, init_delay: 1000}

    assert {:error, :timeout} = TwoFaced.start_child(sup, child_spec, 200)
  end
end
