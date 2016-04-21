require Logger
defmodule Serverboards.RPC.ClientTest do
  use ExUnit.Case
  @moduletag :capture_log
  doctest Serverboards.MOM.RPC.Client, import: true

  alias Serverboards.MOM.RPC.Client

  test "Create and stop a client" do
    {:ok, client} = Client.start_link writef: :context

    Client.stop client

    assert (Process.alive? client) == false
  end

  test "Bad protocol" do
    {:ok, client} = Client.start_link writef: :context

    {:error, :bad_protocol} = Client.parse_line client, "bad protocol"

    # Now a good call
    {:ok, mc} = JSON.encode(%{method: "dir", params: [], id: 1})
    :ok = Client.parse_line client, mc

    Client.stop(client)
  end

  test "Good protocol" do
    {:ok, client} = Client.start_link writef: :context

    {:ok, mc} = JSON.encode(%{method: "dir", params: [], id: 1})
    Client.parse_line client, mc

    :timer.sleep(200)

    {:ok, json} = JSON.decode( Client.get client, :last_line )
    assert Map.get(json,"result") == ~w(dir ping version)

    Client.stop(client)
  end

  test "Call to client" do
    {:ok, client} = Client.start_link writef: :context

    to_client = Client.get client, :to_client

    Serverboards.MOM.RPC.cast to_client, "dir", [], 1, fn {:ok, []} ->
      Client.set client, :called, true
    end
    :timer.sleep(20)

    # manual reply
    assert (Client.get client, :called, false) == false
    {:ok, js} = JSON.decode(Client.get client, :last_line)
    assert Map.get(js,"method") == "dir"
    {:ok, res} = JSON.encode(%{ id: 1, result: []})
    Logger.debug("Writting result #{res}")
    assert (Client.parse_line client, res) == :ok

    :timer.sleep(20)

    assert (Client.get client, :called) == true

    Client.stop(client)
  end
end
