require Logger

defmodule Serverboards.NotificationTest do
  use ExUnit.Case
  @moduletag :capture_log

  doctest Serverboards.Notifications

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Serverboards.Repo)
    # Setting the shared mode must be done only after checkout
    Ecto.Adapters.SQL.Sandbox.mode(Serverboards.Repo, {:shared, self()})
  end

  test "List notifications" do
    cat = Serverboards.Notifications.catalog
    assert is_list(cat)
    catk = Map.keys(hd cat)
    assert :call in catk
    assert :command in catk
    assert :name in catk
    assert :channel in catk
    assert not :id in catk
    assert not :type in catk
    assert not :extra in catk
  end

  test "Simple notification" do
    chan = hd Serverboards.Notifications.catalog
    user = Test.User.system
    config = %{}
    {:ok, true} = Serverboards.Notifications.notify_real(user, chan, config, "Test message", "This is the body", [])

    {:ok, fd} = File.open("/tmp/lastmail.json")
    data = IO.read(fd, :all)
    File.close(fd)

    {:ok, data} = JSON.decode(data)

    assert data["user"]["email"] == user.email
  end

  test "Simple notification to group" do
    {:ok, true} = Serverboards.Notifications.notify_real("@admin", "Test message", "This is the body", %{})

    {:ok, fd} = File.open("/tmp/lastmail.json")
    data = IO.read(fd, :all)
    File.close(fd)

    {:ok, data} = JSON.decode(data)
  end

  test "Configure for user" do
    chan = hd Serverboards.Notifications.catalog
    user = Test.User.system
    config = %{ "email" => "test+notifications@serverboards.io" }

    # no config
    nil = Serverboards.Notifications.config_get(user.email, chan.channel <> "--bis")

    # insert
    :ok = Serverboards.Notifications.config_update(user.email, chan.channel, config, true, user)

    # get one
    conf = Serverboards.Notifications.config_get(user.email, chan.channel)
    assert conf.config == config

    # get all
    %{ "serverboards.test.auth/channel.json.tmp.file" => _conf } = Serverboards.Notifications.config_get(user.email)

    config = %{ "email" => nil }
    # update
    :ok = Serverboards.Notifications.config_update(user.email, chan.channel, config, true, user)

    # updated ok
    conf = Serverboards.Notifications.config_get(user.email, chan.channel)
    assert conf.config == config
  end

  test "Send notification" do
    chan = hd Serverboards.Notifications.catalog
    user = Test.User.system
    config = %{ "email" => "test+notifications2@serverboards.io" }

    :ok = Serverboards.Notifications.config_update(user.email, chan.channel, config, true, user)
    :ok = Serverboards.Notifications.notify(user.email, "Notify test", "To all configured channels", [], user)
    :timer.sleep(300)

    {:ok, fd} = File.open("/tmp/lastmail.json")
    data = IO.read(fd, :all)
    File.close(fd)

    {:ok, data} = JSON.decode(data)

    Logger.debug("Got #{inspect data}")
    assert data["config"]["email"] == config["email"]
  end

  test "RPC notifications" do
    alias Test.Client
    {:ok, client} = Client.start_link as: "dmoreno@serverboards.io"

    {:ok, [ch]} = Client.call client, "notifications.catalog", []

    {:ok, :ok} = Client.call client, "notifications.config_update",
      %{ email: "dmoreno@serverboards.io", channel: ch["channel"],
        config: %{ email: "test@serverboards.io"}, is_active: true}

    {:ok, :ok} = Client.call client, "notifications.notify",
      %{ email: "dmoreno@serverboards.io", subject: "Subject", body: "Body", extra: [] }

    {:ok, config} = Client.call client, "notifications.config", ["dmoreno@serverboards.io"]
    config = config["serverboards.test.auth/channel.json.tmp.file"]

    Logger.info(inspect config)
    assert config["__struct__"] == nil
    assert config["__meta__"] == nil
    assert config["config"]
    assert config["is_active"]


    {:ok, ^config} = Client.call client, "notifications.config", ["dmoreno@serverboards.io", "serverboards.test.auth/channel.json.tmp.file"]
  end

  test "In app communications" do
    alias Test.Client
    {:ok, client} = Client.start_link as: "dmoreno@serverboards.io"
    user = Test.User.system

    :ok = Serverboards.Notifications.notify("dmoreno@serverboards.io", "Notification for list", "This is a test that should be stored in app", [medatadata: "test"], user)
    Client.expect(client, method: "notifications.new")

    {:ok, coms} = Client.call client, "notifications.list", %{}
    mymsg = Enum.find(coms, nil, &(&1["subject"]=="Notification for list"))
    assert mymsg != nil
    assert "new" in mymsg["tags"]

    {:ok, coms} = Client.call client, "notifications.list", %{tags: ["unread"]}
    mymsg = Enum.find(coms, nil, &(&1["subject"]=="Notification for list"))
    assert mymsg != nil
    assert "new" in mymsg["tags"]
    assert "unread" in mymsg["tags"]

    {:ok, fullmsg} = Client.call client, "notifications.details", [mymsg["id"]]
    assert fullmsg["id"] == mymsg["id"]


    {:ok, :ok} = Client.call client, "notifications.update", %{ id: mymsg["id"], tags: ["other"]}
    Client.expect(client, method: "notifications.update")
    {:ok, fullmsg} = Client.call client, "notifications.details", [mymsg["id"]]
    Logger.info(inspect fullmsg)
    assert fullmsg["id"] == mymsg["id"]
    assert fullmsg["tags"] == ["other"]
    assert not "new" in fullmsg["tags"]
    assert not "unread" in fullmsg["tags"]
  end
end
