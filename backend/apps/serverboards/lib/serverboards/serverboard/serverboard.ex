require Logger

defmodule Serverboards.Serverboard do
  import Ecto.Query

  alias Serverboards.Repo
  alias Serverboards.Serverboard.Model.Serverboard, as: ServerboardModel
  alias Serverboards.Serverboard.Model.ServerboardTag, as: ServerboardTagModel
  alias Serverboards.Service.Model.Service, as: ServiceModel

  def start_link(_options) do
    {:ok, es} = EventSourcing.start_link name: :serverboard
    {:ok, _rpc} = Serverboards.Serverboard.RPC.start_link

    EventSourcing.Model.subscribe :serverboard, :serverboard, Serverboards.Repo
    #EventSourcing.subscribe :serverboard, :debug_full

    setup_eventsourcing(es)
    Serverboards.Serverboard.Widget.setup_eventsourcing(es)

    {:ok, es}
  end

  def setup_eventsourcing(es) do
    EventSourcing.subscribe es, :add_serverboard, fn attributes, me ->
      {:ok, serverboard} = Repo.insert( ServerboardModel.changeset(%ServerboardModel{}, attributes) )

      Enum.map(Map.get(attributes, :tags, []), fn name ->
        Repo.insert( %ServerboardTagModel{name: name, serverboard_id: serverboard.id} )
      end)

      Serverboards.Service.service_update_serverboard_real( serverboard.shortname, attributes, me )

      Serverboards.Event.emit("serverboard.added", %{ serverboard: serverboard}, ["serverboard.info"])
      serverboard.shortname
    end, name: :serverboard

    EventSourcing.subscribe es, :update_serverboard, fn [shortname, operations], _me ->
      import Ecto.Query
      # update tags
      serverboard = Repo.get_by!(ServerboardModel, shortname: shortname)

      tags = Map.get(operations, :tags, nil)
      if tags != nil do
        update_serverboards_tags_real(serverboard, tags)
      end

      {:ok, upd} = Repo.update( ServerboardModel.changeset(
        serverboard, operations
      ) )

      {:ok, serverboard} = serverboard_info upd

      Serverboards.Event.emit(
        "serverboard.updated",
        %{ shortname: shortname, serverboard: serverboard},
        ["serverboard.info"]
        )

      :ok
    end

    EventSourcing.subscribe es, :delete_serverboard, fn shortname, _me ->
      Repo.delete_all( from s in ServerboardModel, where: s.shortname == ^shortname )

      Serverboards.Event.emit("serverboard.deleted", %{ shortname: shortname}, ["serverboard.info"])
    end
  end

  defp update_serverboards_tags_real(serverboard, tags) do
    import Ecto.Query
    tags = MapSet.new(
      tags
        |> Enum.filter(&(&1 != ""))
      )

    current_tags = Repo.all(from st in ServerboardTagModel, where: st.serverboard_id == ^serverboard.id, select: st.name )
    current_tags = MapSet.new current_tags

    new_tags = MapSet.difference(tags, current_tags)
    expired_tags = MapSet.difference(current_tags, tags)

    Logger.debug("Update serverboard tags. Current #{inspect current_tags}, add #{inspect new_tags}, remove #{inspect expired_tags}")

    if (Enum.count expired_tags) > 0 do
      expired_tags = MapSet.to_list expired_tags
      Repo.delete_all( from t in ServerboardTagModel, where: t.serverboard_id == ^serverboard.id and t.name in ^expired_tags )
    end
    Enum.map(new_tags, fn name ->
      Repo.insert( %ServerboardTagModel{name: name, serverboard_id: serverboard.id} )
    end)
  end

  @doc ~S"""
  Creates a new serverboard given the shortname, attributes and creator_id

  Attributes is a Map with the serverboard attributes (strings, not atoms) All are optional.

  Attributes:
  * name -- Serverboard name
  * description -- Long description
  * priority -- Used for sorting, increasing.
  * tags -- List of tags to apply.

  ## Example

    iex> user = Test.User.system
    iex> {:ok, "SBDS-TST1"} = serverboard_add "SBDS-TST1", %{ "name" => "serverboards" }, user
    iex> {:ok, info} = serverboard_info "SBDS-TST1", user
    iex> info.name
    "serverboards"
    iex> serverboard_delete "SBDS-TST1", user
    :ok

  """
  def serverboard_add(shortname, attributes, me) do
    EventSourcing.dispatch :serverboard, :add_serverboard, %{
      shortname: shortname,
      creator_id: me.id,
      name: Map.get(attributes,"name", shortname),
      description: Map.get(attributes, "description", ""),
      priority: Map.get(attributes, "priority", 50),
      tags: Map.get(attributes, "tags", []),
      services: Map.get(attributes, "services", [])
    }, me.email
    {:ok, shortname}
  end



  @doc ~S"""
  Updates a serverboard by id or shortname

  ## Example:

    iex> user = Test.User.system
    iex> {:ok, "SBDS-TST2"} = serverboard_add "SBDS-TST2", %{ "name" => "serverboards" }, user
    iex> :ok = serverboard_update "SBDS-TST2", %{ "name" => "Serverboards" }, user
    iex> {:ok, info} = serverboard_info "SBDS-TST2", user
    iex> info.name
    "Serverboards"
    iex> serverboard_delete "SBDS-TST2", user
    :ok

  """
  def serverboard_update(serverboard, operations, me) when is_map(serverboard) do
    #Logger.debug("serverboard_update #{inspect {serverboard.shortname, operations, me}}, serverboard id #{serverboard.id}")

    # Calculate changes on serverboard itself.
    changes = Enum.reduce(operations, %{}, fn op, acc ->
      Logger.debug("#{inspect op}")
      {opname, newval} = op
      opatom = case opname do
        "name" -> :name
        "description" -> :description
        "priority" -> :priority
        "tags" -> :tags
        "shortname" -> :shortname
        "services" -> :services
        e ->
          Logger.error("Unknown operation #{inspect e}. Failing.")
          raise RuntimeError, "Unknown operation updating serverboard #{serverboard.shortname}: #{inspect e}. Failing."
      end
      if opatom do
        Map.put acc, opatom, newval
      else
        acc
      end
    end)

    EventSourcing.dispatch(:serverboard, :update_serverboard, [serverboard.shortname, changes], me.email)

    :ok
  end
  def serverboard_update(serverboard_id, operations, me) when is_number(serverboard_id) do
    serverboard_update(Repo.get_by(ServerboardModel, [id: serverboard_id]), operations, me)
  end
  def serverboard_update(serverboardname, operations, me) when is_binary(serverboardname) do
    serverboard_update(Repo.get_by(ServerboardModel, [shortname: serverboardname]), operations, me)
  end

  @doc ~S"""
  Deletes a serverboard by id or name
  """
  def serverboard_delete(%ServerboardModel{ shortname: shortname }, me) do
    EventSourcing.dispatch(:serverboard, :delete_serverboard, shortname, me.email)
    :ok
  end
  def serverboard_delete(serverboard_id, me) when is_number(serverboard_id) do
    serverboard_delete( Repo.get_by(ServerboardModel, [id: serverboard_id]), me )
  end
  def serverboard_delete(serverboard_shortname, me) when is_binary(serverboard_shortname) do
    serverboard_delete( Repo.get_by(ServerboardModel, [shortname: serverboard_shortname]), me )
  end

  @doc ~S"""
  Returns the information of a serverboard by id or name
  """
  def serverboard_info(%ServerboardModel{} = serverboard) do
    alias Serverboards.Serverboard.Model.ServerboardService, as: ServerboardServiceModel

    serverboard = Repo.preload(serverboard, :tags)

    serverboard = %{
      serverboard |
      tags: Enum.map(serverboard.tags, fn t -> t.name end)
    }

    services = Repo.all(from c in ServiceModel,
        join: sc in ServerboardServiceModel,
          on: sc.service_id==c.id,
       where: sc.serverboard_id == ^serverboard.id,
      select: c)
    serverboard = Map.put(serverboard, :services, services)

    #Logger.info("Got serverboard #{inspect serverboard}")
    {:ok, serverboard}
  end

  def serverboard_info(serverboard_id, _me) when is_number(serverboard_id) do
    case Repo.one( from( s in ServerboardModel, where: s.id == ^serverboard_id, preload: :tags ) ) do
      nil -> {:error, :not_found}
      serverboard ->
        serverboard_info(serverboard)
    end
  end
  def serverboard_info(serverboard_shortname, _me) when is_binary(serverboard_shortname) do
    case Repo.one( from(s in ServerboardModel, where: s.shortname == ^serverboard_shortname, preload: :tags ) ) do
      nil -> {:error, :not_found}
      serverboard ->
        serverboard_info(serverboard)
    end
  end

  @doc ~S"""
  Returns a list with all serverboards and its information

  ## Example

    iex> require Logger
    iex> user = Test.User.system
    iex> {:ok, l} = serverboard_list user.id
    iex> is_list(l) # may be empty or has something from before, but lists
    true
    iex> {:ok, "SBDS-TST4"} = serverboard_add "SBDS-TST4", %{ "name" => "serverboards" }, user
    iex> {:ok, l} = serverboard_list user
    iex> Logger.debug(inspect l)
    iex> Enum.any? l, &(&1.shortname=="SBDS-TST4") # exists in the list?
    true
    iex> serverboard_delete "SBDS-TST4", user
    :ok

  """
  def serverboard_list(_me) do
    serverboards = Serverboards.Repo.all(from s in ServerboardModel, preload: :tags )
     |> Enum.map( fn serverboard ->
       %{ serverboard | tags: Enum.map(serverboard.tags, &(&1.name)) }
     end)
    {:ok, serverboards }
  end
end
