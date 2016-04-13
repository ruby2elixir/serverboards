defmodule Serverboards.RPCTest do
  use ExUnit.Case
  @moduletag :capture_log
  doctest Serverboards.MOM.RPC
  doctest Serverboards.MOM.RPC.MethodCaller

	alias Serverboards.MOM.RPC

	test "Simple RPC use" do
		{:ok, rpc} = RPC.start_link
		RPC.tap( rpc )

		RPC.add_method rpc, "echo", &(&1), async: true

		# simple direct call
		assert RPC.call(rpc, "echo", "hello", 0) == "hello"

		# simple call through chain
		{:ok, worker} = RPC.start_link
		RPC.tap( worker )

		RPC.add_method worker, "ping", fn _ ->
			"pong"
		end
		RPC.chain rpc, worker
		assert RPC.call(rpc, "ping", [], 0) == "pong"

		# call unknown
		assert_raise Serverboards.MOM.RPC.UnknownMethod, fn ->
			RPC.call(rpc, "pong", nil, 0)
		end

		# chain a second worker
		{:ok, worker2} = RPC.start_link
		RPC.tap( worker2 )
		RPC.add_method worker2, "pong", fn _ ->
			"pong"
		end

		# still not chained, excpt
		assert_raise Serverboards.MOM.RPC.UnknownMethod, fn ->
			RPC.call(rpc, "pong", nil, 0)
		end

		# now works
		RPC.chain rpc, worker2
		assert RPC.call(rpc, "pong", nil, 0) == "pong"
	end


  test "RPC method with pattern matching" do
    {:ok, rpc} = RPC.start_link
    RPC.tap( rpc )

    RPC.add_method rpc, "echo", fn
      [_] -> "one item"
      [] -> "empty"
      %{ type: _ } -> "map with type"
    end, async: true

    assert RPC.call(rpc, "echo", [], 1) == "empty"
    assert RPC.call(rpc, "echo", [1], 1) == "one item"
    assert_raise Serverboards.MOM.RPC.UnknownMethod, fn ->
      RPC.call(rpc, "echo", %{}, 1)
    end
    assert RPC.call(rpc, "echo", %{ type: :test}, 1) == "map with type"
  end


  test "dir aggregates from all method callers and even calls remotes" do
    {:ok, rpc} = RPC.start_link
    RPC.tap( rpc )

    RPC.add_method rpc, "echo", fn
      [_] -> "one item"
      [] -> "empty"
      %{ type: _ } -> "map with type"
    end, async: true

    {:ok, mc1} = RPC.MethodCaller.start_link
    RPC.MethodCaller.add_method mc1, "echo1", &(&1)

    {:ok, mc2} = RPC.MethodCaller.start_link
    RPC.MethodCaller.add_method mc2, "echo2", &(&1)

    {:ok, mc3} = RPC.MethodCaller.start_link
    RPC.MethodCaller.add_method mc2, "echo3", &(&1)

    RPC.add_method_caller rpc, mc1
    RPC.add_method_caller rpc, mc2
    RPC.MethodCaller.add_method_caller mc2, mc3

    assert RPC.call(rpc, "dir", [], 1) == ~w(dir echo echo1 echo2 echo3)
  end
end
