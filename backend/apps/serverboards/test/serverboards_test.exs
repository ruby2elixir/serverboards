require Logger

defmodule ServerboardsTest do
  use ExUnit.Case
  @moduletag :capture_log

  doctest Serverboards
  doctest Serverboards.Utils, import: true
  doctest Serverboards.Utils.Decorators, import: true

  def email_type, do: "serverboards.test.auth/email"

  def check_if_event_on_client(client, event, shortname) do
    Test.Client.expect(client, [{:method, event}, {~w(params serverboard shortname), shortname}], 500 )
  end
  def check_if_event_on_serverboard(agent, event, shortname) do
    check_if_event_on_serverboard(agent, event, shortname, 10)
  end
  def check_if_event_on_serverboard(_agent, _event, _shortname, 0), do: false
  def check_if_event_on_serverboard(agent, event, shortname, count) do
    ok = Agent.get agent, fn status ->
      events =Map.get(status, event, [])
      Logger.debug("Check if #{shortname} in #{inspect events} / #{inspect count}")
      Enum.any? events, fn event ->
        if Map.get(event.data, :serverboard) do
          event.data.serverboard.shortname == shortname
        else
          event.data.shortname == shortname
        end
      end
    end
    if ok do
      ok
    else # tries several times. polling, bad, but necessary.
      :timer.sleep 100
      check_if_event_on_serverboard(agent, event, shortname, count - 1)
    end
  end

  setup_all do
    {:ok, agent } = Agent.start_link fn -> %{} end
    MOM.Channel.subscribe( :client_events, fn %{ payload: msg } ->
      Agent.update agent, fn status ->
        Logger.info("New message to client #{inspect msg}. #{inspect agent} ")
        Map.put( status, msg.type, Map.get(status, msg.type, []) ++ [msg] )
      end
    end )
    system=%{ email: "system", perms: ["auth.info_any_user"] }

    {:ok, %{ agent: agent, system: system} }
  end

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Serverboards.Repo)
    # Setting the shared mode must be done only after checkout
    Ecto.Adapters.SQL.Sandbox.mode(Serverboards.Repo, {:shared, self()})
  end

  test "Serverboard lifecycle", %{ agent: agent, system: system } do
    import Serverboards.Serverboard

    user = Serverboards.Auth.User.user_info("dmoreno@serverboards.io", system)
    {:ok, "SBDS-TST3"} = serverboard_add "SBDS-TST3", %{ "name" => "serverboards" }, user
    assert check_if_event_on_serverboard(agent, "serverboard.added", "SBDS-TST3")

    :ok = serverboard_update "SBDS-TST3", %{ "name" => "Serverboards" }, user
    assert check_if_event_on_serverboard(agent, "serverboard.updated", "SBDS-TST3")

    {:ok, info} = serverboard_info "SBDS-TST3", user
    assert info.name == "Serverboards"

    :ok = serverboard_delete "SBDS-TST3", user
    assert check_if_event_on_serverboard(agent, "serverboard.deleted", "SBDS-TST3")

    assert {:error, :not_found} == serverboard_info "SBDS-TST3", user
  end


  test "Create serverboard and widgets, no ES" do
    import Serverboards.Serverboard
    import Serverboards.Serverboard.Widget

    user = Test.User.system

    serverboard_add "SBDS-TST12", %{ "name" => "Test 12" }, user
    {:ok, widget} = widget_add("SBDS-TST12", %{ config: %{}, widget: "test/widget"}, user)
    #Logger.debug(inspect list)

    {:ok, list} = widget_list("SBDS-TST12")

    Logger.debug(inspect widget)
    Logger.info("List of widgets at SBDS-TST12#{Serverboards.Utils.table_layout(list)}")

    assert Enum.any?(list, &(&1.uuid == widget))
    assert Enum.any?(list, &(&1.widget == "test/widget"))
    assert Enum.any?(list, &(&1.config == %{}))

    :ok = widget_update(widget, %{config: %{ "test" => true }}, user)
    {:ok, list} = widget_list("SBDS-TST12")
    Logger.info("List of widgets at SBDS-TST12#{Serverboards.Utils.table_layout(list)}")
    assert Enum.any?(list, &(&1.config == %{ "test" => true }))
  end

  test "Serverboard and widgets via RPC" do
    {:ok, client} = Test.Client.start_link as: "dmoreno@serverboards.io"
    Test.Client.call(client, "event.subscribe", ["serverboard.widget.added", "serverboard.widget.updated"])
    {:ok, sbds} = Test.Client.call(client, "serverboard.add", ["SBDS-TST13", %{}] )
    {:ok, uuid} = Test.Client.call(client, "serverboard.widget.add", %{ serverboard: "SBDS-TST13", widget: "test"})
    :timer.sleep(300)
    assert Test.Client.expect(client, method: "serverboard.widget.added")

    {:ok, _ } = Test.Client.call(client, "serverboard.widget.list", [sbds])

    {:ok, _uuid} = Test.Client.call(client, "serverboard.widget.update", %{ uuid: uuid, widget: "test2"})
    :timer.sleep(300)

    assert Test.Client.expect(client, method: "serverboard.widget.updated")
    {:ok, [%{"uuid" => uuid}]} = Test.Client.call(client, "serverboard.widget.list", [sbds])

    # just dont fail
    {:ok, _catalog} = Test.Client.call(client, "serverboard.widget.catalog", ["SBDS-TST13"])

    {:ok, _} = Test.Client.call(client, "serverboard.widget.remove", [uuid])
    {:ok, []} = Test.Client.call(client, "serverboard.widget.list", [sbds])
  end

  test "Update serverboards tags", %{ system: system } do
    import Serverboards.Serverboard

    user = Serverboards.Auth.User.user_info("dmoreno@serverboards.io", system)
    {:error, :not_found } = serverboard_info "SBDS-TST5", user

    {:ok, "SBDS-TST5"} = serverboard_add "SBDS-TST5", %{ "name" => "serverboards" }, user
    {:ok, info } = serverboard_info "SBDS-TST5", user
    assert info.tags == []

    :ok = serverboard_update "SBDS-TST5", %{ "tags" => ~w(tag1 tag2 tag3)}, user
    {:ok, info } = serverboard_info "SBDS-TST5", user
    Logger.debug("Current serverboard info: #{inspect info}")
    assert Enum.member? info.tags, "tag1"
    assert Enum.member? info.tags, "tag2"
    assert Enum.member? info.tags, "tag3"
    assert not (Enum.member? info.tags, "tag4")

    serverboard_update "SBDS-TST5", %{ "tags" => ~w(tag1 tag2 tag4) }, user
    {:ok, info } = serverboard_info "SBDS-TST5", user
    assert Enum.member? info.tags, "tag1"
    assert Enum.member? info.tags, "tag2"
    assert not (Enum.member? info.tags, "tag3")
    assert Enum.member? info.tags, "tag4"

    # should not remove tags
    :ok = serverboard_update "SBDS-TST5", %{ "description" => "A simple description"}, user
    {:ok, info } = serverboard_info "SBDS-TST5", user
    assert Enum.member? info.tags, "tag1"
    assert Enum.member? info.tags, "tag2"
    assert Enum.member? info.tags, "tag4"

    :ok = serverboard_delete "SBDS-TST5", user
  end

  test "Serverboards as a client", %{ agent: agent } do
    {:ok, client} = Test.Client.start_link as: "dmoreno@serverboards.io"

    {:ok, dir} = Test.Client.call client, "dir", []
    Logger.debug("Known methods: #{inspect dir}")
    assert Enum.member? dir, "serverboard.list"
    assert Enum.member? dir, "serverboard.add"
    assert Enum.member? dir, "serverboard.delete"
    assert Enum.member? dir, "serverboard.info"

    #{:ok, json} = JSON.encode(Test.Client.debug client)
    #Logger.info("Debug information: #{json}")

    Test.Client.call(client, "event.subscribe", [
      "serverboard.added","serverboard.deleted","serverboard.updated"
      ])
    {:ok, l} = Test.Client.call client, "serverboard.list", []
    Logger.info("Got serverboards: #{inspect l}")
    assert (Enum.count l) >= 0

    {:ok, "SBDS-TST8"} = Test.Client.call client, "serverboard.add", [
      "SBDS-TST8",
      %{
        "name" => "Serverboards test",
        "tags" => ["tag1", "tag2"],
        "services" => [
          %{ "type" => "test", "name" => "main web", "config" => %{ "url" => "http://serverboards.io" } },
          %{ "type" => "test", "name" => "blog", "config" => %{ "url" => "http://serverboards.io/blog" } },
        ]
      }
    ]
    assert check_if_event_on_client(client, "serverboard.added", "SBDS-TST8")
    deleted=check_if_event_on_client(client, "serverboard.deleted", "SBDS-TST8")
    Logger.info("At serverboard deleted? #{deleted}")
    assert not deleted

    {:ok, cl} = Test.Client.call client, "serverboard.info", ["SBDS-TST8"]
    Logger.info("Info from serverboard #{inspect cl}")
    {:ok, json} = JSON.encode(cl)
    assert not String.contains? json, "__"
    assert (hd cl["services"])["name"] == "main web"
    assert (hd (tl cl["services"]))["name"] == "blog"

    {:ok, cls} = Test.Client.call client, "serverboard.list", []
    Logger.info("Info from serverboard #{inspect cls}")
    {:ok, json} = JSON.encode(cls)
    assert not String.contains? json, "__"
    assert Enum.any?(cls, &(&1["shortname"] == "SBDS-TST8"))


    {:ok, service} = Test.Client.call client, "service.add", %{ "tags" => ["email","test"], "type" => email_type, "name" => "Email" }
    Test.Client.call client, "service.attach", ["SBDS-TST8", service]
    Test.Client.call client, "service.info", [service]
    Test.Client.call client, "service.list", []
    Test.Client.call client, "service.list", [["type","email"]]

    Test.Client.call client, "serverboard.update", [
      "SBDS-TST8",
      %{
        "services" => [
          %{ "uuid" => service, "name" => "new name" }
        ]
      }
    ]
    {:ok, info} = Test.Client.call client, "service.info", [service]
    assert info["name"] == "new name"

    Test.Client.call client, "service.delete", [service]
    {:ok, services} = Test.Client.call client, "service.list", [["type","email"]]
    assert not (Enum.any? services, &(&1["uuid"] == service))


    Test.Client.call client, "serverboard.delete", ["SBDS-TST8"]

    assert check_if_event_on_client(client, "serverboard.updated", "SBDS-TST8")
    assert Test.Client.expect(client, [{:method, "serverboard.deleted"}, {[:params, :shortname], "SBDS-TST8"}])


    Test.Client.stop(client)
  end

end
