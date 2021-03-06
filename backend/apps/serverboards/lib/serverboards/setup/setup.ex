require Logger

defmodule Serverboards.Setup do
  @moduledoc ~S"""
  Performs setup tasks, as initial database setup or permission updates
  """
  alias Serverboards.Repo
  alias Serverboards.Auth.Model
  alias Serverboards.Auth

  def start do
    {:ok, _} = Application.ensure_all_started(:ecto)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:logger)
    if Process.whereis(Serverboards.Repo) != nil do
      {:ok, nil} # already running
    else
      {:ok, pid} = Serverboards.Repo.start_link
    end
  end

  def exit(nil), do: :ok
  def exit(pid), do: Process.exit(pid, :normal)

  @doc ~S"""
  Setups the database for initial state, with given username and password
  """
  def initial(options \\ []) do
    start
    import_user(%{
      email: Keyword.get(options, :email, "admin@serverboards.io"),
      name: "Admin",
      is_active: true,
      groups: ["user", "admin"],
      password: Keyword.get(options, :password, UUID.uuid4)
    })
    :init.stop()
  end

  @doc ~S"""
  Ensures some data is up to date, as default groups and permissions
  """
  def update do
    Logger.debug("Updating database")
    # update database
    path = Application.app_dir(:serverboards, "share/serverboards/backend/migrations")
    Ecto.Migrator.run(Serverboards.Repo, path, :up, all: true)

    import_group( %{ name: "user", perms: []} )
    import_group( %{ name: "admin", perms: all_perms} )
    Logger.debug("Done")
  end

  @doc ~S"""
  Imports an user into the system or updates it
  """
  def import_user(user) do
    u = Repo.get_or_create_and_update(Model.User, [email: user.email], user)

    Enum.map user.groups, fn gn ->
      group = Repo.get_or_create_and_update(Model.Group, [name: gn], %{name: gn})
      _ = Repo.get_or_create_and_update(Model.UserGroup, [group_id: group.id, user_id: u.id], %{group_id: group.id, user_id: u.id})
    end

    :ok = Auth.User.Password.password_set(u, user.password, u)
  end

  @doc ~S"""
  Ensures this group with thouse permissions exist.
  """
  def import_group(group) do
    groupm = Repo.get_or_create_and_update(Model.Group, [name: group.name], %{name: group.name})
    perms = group.perms
    Enum.map perms, fn p ->
      perm = Repo.get_or_create_and_update(Model.Permission, [code: p], %{ code: p })
      Repo.get_or_create_and_update(Model.GroupPerms, [ group_id: groupm.id, perm_id: perm.id ], %{ group_id: groupm.id, perm_id: perm.id })
    end
  end

  defp system_user do
    %{
      email: "system",
      id: -1,
      perms: all_perms
    }
  end

  defp all_perms do
    [
    "auth.modify_self", "auth.modify_any",
    "auth.create_user", "auth.create_token",
    "auth.info_any_user",
    "auth.modify_groups", "auth.manage_groups",
    "plugin",
    "serverboard.add", "serverboard.update",
    "serverboard.delete", "serverboard.info",
    "serverboard.widget.add", "serverboard.widget.update",
    "service.add", "service.update",
    "service.delete", "service.info",
    "service.attach",
    "settings.user.view", "settings.user.view_all",
    "settings.user.update", "settings.user.update_all",
    "settings.view", "settings.update",
    "debug",
    "notifications.notify", "notifications.notify_all",
    "notifications.list",
    "action.trigger", "action.watch",
    "rules.update", "rules.view",
    "logs.view"
    ]
  end

end
