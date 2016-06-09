require Logger

defmodule Test.Client do
  @moduledoc ~S"""
  Fake client to ease test construction.

  Allows to send calls, expect messages/events.

  It creates all the necesary stuff to start as a non connected client
  """
  use GenServer

  alias MOM.RPC
  alias Test.Client

  @doc ~S"""
  Starts a fake client for tests.

  Options:

  * as: email -- Starts as that email user
  """
  def start_link(options \\ []) do
    {:ok, pid} = GenServer.start_link __MODULE__, :ok, []
    client=GenServer.call(pid, {:get_client})

    maybe_user=Keyword.get(options, :as, false)
    ok = if maybe_user do
      Serverboards.Auth.authenticate(client)

      Client.expect( client, method: "auth.required" )
      user = Serverboards.Auth.User.user_info maybe_user, %{ email: "system", perms: ["auth.info_any_user"] }
      if user do
        token = Serverboards.Auth.User.Token.create(user)
        user = Client.call( client, "auth.auth", %{ "type" => "token", "token" => token })
        :ok
      else
        Logger.warn("Test client cant log as user #{inspect maybe_user}")
        :cant_log_in
      end
    else
      :ok
    end

    if ok == :ok do
      {:ok, client}
    else
      GenServer.stop(pid, :normal)
      {:error, ok}
    end
  end

  def stop(client, reason \\ :normal) do
    GenServer.stop(RPC.Client.get(client, :pid), reason)
  end

  def debug(client) do
    GenServer.call(RPC.Client.get(client, :pid), {:debug})
  end

  @doc ~S"""
  Ignore events until this appears or timeout. What is a keyword/value list.

  It is asynchronous and stores all messages since last expect, so that there
  are no race conditions.

  ## Example

    iex> cl = Test.Client.start_link
    iex> Test.Client.ready(cl)
    iex> Test.Client.expect(cl, method: "auth.auth")
    %{ method: "auth.auth" }

  """
  def expect(client, what, timeout \\ 5000) do
    try do
      GenServer.call(RPC.Client.get(client, :pid), {:expect, what}, timeout)
    rescue
      _e ->
        false
    end
  end

  @doc ~S"""
  Calls into the client
  """
  def call(client, method, params) do
    GenServer.call(RPC.Client.get(client, :pid), {:call_from_json, method, params})
  end

  ## server impl
  def init(:ok) do
    pid = self()
    {:ok, client} = RPC.Client.start_link [
      writef: fn line ->
        Logger.debug("Write to test client: #{line}")
        {:ok, rpc_call} = JSON.decode( line )
        GenServer.cast(pid, {:call, rpc_call } )
        end,
      name: "TestClient"
      ]

    RPC.Client.set client, :pid, pid

    {:ok, %{
        client: client,
        messages: [],
        expecting: nil,
        waiting: %{},
        maxid: 1
    } }
  end

  defp expect_rec(_what, []) do
    {false, []}
  end
  defp expect_rec(what, [msg | rest ]) do
    if expect_match?(what, msg) do
      #Logger.debug("True!")
      {true, rest}
    else
      {ok, rmsgs} = expect_rec(what, rest)
      {ok, [msg | rmsgs ]}
    end
  end

  def handle_call({:expect, what}, from, status) do
    Logger.debug("Look for #{inspect what} at #{inspect status.messages}")
    {isin, messages} = expect_rec(what, status.messages)
    if isin do
      #Logger.debug("Already here")
      {:reply, true, %{status | messages: messages, expecting: nil }}
    else
      status=%{ status | expecting: %{ what: what, from: from } }
      {:noreply, status, 200}
    end
  end

  def handle_call({:call_from_json, method, params}, from, status) do
    {:ok, json} = JSON.encode( %{ method: method, params: params, id: status.maxid })
    RPC.Client.parse_line(status.client, json)
    {:noreply, %{ status |
      waiting: Map.put(status.waiting, status.maxid, from),
      maxid: status.maxid + 1,
    } }
  end

  def handle_call({:get_client}, _from, status) do
    {:reply, status.client, status}
  end

  def handle_call({:debug}, _from, status) do
    {:reply, %{ "debug test client" => RPC.Client.debug(status.client) }, status}
  end

  def handle_cast({:call, msg}, status) do
    Logger.debug("Add msg #{inspect msg} && #{inspect status.expecting}")

    waiting_from = status.waiting[msg["id"]]
    Logger.debug("Waiting for #{inspect status.waiting}, #{inspect msg["id"]}, #{inspect waiting_from}")
    if waiting_from do
      if msg["error"] == nil do
        res = case msg["result"] do
          "ok" -> :ok
          other -> other
        end
        GenServer.reply(waiting_from, {:ok, res})
      else
        err = case msg["error"] do
          "unknown_method" -> :unknown_method
          other -> other
        end
        GenServer.reply(waiting_from, {:error, err})
      end
    end

    messages = status.messages ++ [msg]
    messages = if status.expecting do
      {isin, messages} = expect_rec(status.expecting.what, messages)
      if isin do
        #Logger.debug("Got #{inspect status.expecting.what} now")
        GenServer.reply(status.expecting.from, true)
        {:noreply, %{ status | messages: messages, expecting: nil }}
      else
        {:noreply, %{ status | messages: messages }}
      end
    else
      {:noreply, %{ status | messages: messages }}
    end
    messages
  end

  defp expect_match?(_w, nil) do
    false
  end
  defp expect_match?([], _) do
    #Logger.debug("Match done!")
    true
  end
  defp expect_match?([w | rest], msg) do
    Logger.debug("Match? #{inspect w} #{inspect msg}")
    cont = case w do
      {:method, v} ->
        Map.get(msg, "method", nil) == v
      {[k], v} ->
        Map.get(msg, to_string(k), nil) == v
      {[k | kr], v} ->
        expect_match?([{kr, v}], Map.get( msg, to_string(k)))
      {k, v} ->
        Map.get(msg, to_string(k), nil) == v
    end

    if cont do
      expect_match?(rest, msg)
    else
      false
    end
  end

  def handle_info(:timeout, state) do
    GenServer.reply(state.expecting.from, false)
    {:noreply, %{ state | expecting: nil }}
  end
end
