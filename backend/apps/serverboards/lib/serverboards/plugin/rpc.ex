require Logger

defmodule Serverboards.Plugin.RPC do
  alias MOM.RPC
  alias Serverboards.Plugin

  def start_link(runner) do
    {:ok, method_caller} = RPC.MethodCaller.start_link name: Serverboards.Plugin.RPC
    Serverboards.Utils.Decorators.permission_method_caller method_caller

    RPC.MethodCaller.add_method method_caller, "plugin.start", fn [plugin_component_id] ->
      Plugin.Runner.start runner, plugin_component_id
    end, [required_perm: "plugin"]

    RPC.MethodCaller.add_method method_caller, "plugin.stop", fn [plugin_component_id] ->
      Plugin.Runner.stop runner, plugin_component_id
    end, [required_perm: "plugin"]

    RPC.MethodCaller.add_method method_caller, "plugin.call", fn
      [id, method, params] ->
        Plugin.Runner.call runner, id, method, params
      [id, method] ->
        Plugin.Runner.call runner, id, method, []
    end, [required_perm: "plugin"]

    RPC.MethodCaller.add_method method_caller, "plugin.alias", fn
      [id, newalias], context ->
        cmd = GenServer.call(runner, {:get, id})
        RPC.Context.update context, :plugin_aliases, [{ newalias, cmd.pid }]

        true
    end, [required_perm: "plugin", context: true]

    RPC.MethodCaller.add_method method_caller, "plugin.list", fn
      [] ->
        Serverboards.Plugin.Registry.list
      %{} ->
        Serverboards.Plugin.Registry.list
    end, [required_perm: "plugin"]


    RPC.MethodCaller.add_method method_caller, "plugin.data_set",
        fn [ plugin, key, value ], context ->
      user = RPC.Context.get context, :user
      perms = user.perms
      can_data = (
        ("plugin.data" in perms) or
        ("plugin.data[#{plugin}]" in perms)
        )
      if can_data do
        Plugin.Data.data_set(plugin, key, value, user)
      else
        Logger.debug("Perms #{inspect perms}, not plugin.data, nor plugin.data[#{plugin}]")
        {:error, :not_allowed}
      end
    end, context: true

    RPC.MethodCaller.add_method method_caller, "plugin.data_get",
        fn [ plugin, key ], context ->
      perms = (RPC.Context.get context, :user).perms
      can_data = (
        ("plugin.data" in perms) or
        ("plugin.data[#{plugin}]" in perms)
        )
      if can_data do
        {:ok, Plugin.Data.data_get(plugin, key)}
      else
        Logger.debug("Perms #{inspect perms}, not plugin.data, nor plugin.data[#{plugin}]")
        {:error, :not_allowed}
      end
    end, context: true


    # Catches all [UUID].method calls and do it. This is what makes call plugin by uuid work.
    RPC.MethodCaller.add_method_caller method_caller, &call_with_uuid(&1, runner),
      [required_perm: "plugin", name: :call_with_uuid]

    # Catches all [alias].method calls and do it. Alias are stores into the context
    RPC.MethodCaller.add_method_caller method_caller, &call_with_alias(&1, runner),
      [required_perm: "plugin", name: :call_with_alias]


    {:ok, method_caller}
  end


  # Method caller function UUID.method.
  def call_with_uuid(%MOM.RPC.Message{ method: method, params: params, context: _context}, runner) do
    #Logger.debug("Try to call #{inspect msg}")
    if method == "dir" do
      {:ok, []} # Do not return it as it can lead to show of opaque pointers. Use alias.
    else
      case Regex.run(~r/(^[-0-9a-f]{36})\.(.*)$/, method) do
        [_, id, method] ->
          res = Plugin.Runner.call runner, id, method, params
          #Logger.debug("UUID result #{inspect res}")
          res
        _ -> :nok
      end
    end
  end

  def call_with_alias(%MOM.RPC.Message{ method: method, params: params, context: context}, _runner) do
    if method == "dir" do
      {:ok, alias_dir(context)}
    else
      case Regex.run(~r/(^[^.]+)\.(.*)$/, method) do
        [_, alias_, method] ->
          aliases = RPC.Context.get context, :plugin_aliases, %{}
          cmd = Map.get aliases, alias_
          #Logger.debug("Call with alias #{inspect alias_}")
          cond do
            cmd == nil ->
              #Logger.debug("Not alias")
              :nok
            Process.alive? cmd ->
              ret=Serverboards.IO.Cmd.call cmd, method, params
              Logger.debug("Alias result #{inspect ret}")
              ret
            true ->
              # not running anymore, remove it
              Logger.debug("Plugin not running anymore")
              RPC.Context.update context, :plugin_aliases, [{ alias_, nil }]
              :nok
          end
        _ -> :nok
      end
    end
  end

  # returns a list of all known methods that use alias
  defp alias_dir(context) do
    aliases = RPC.Context.get context, :plugin_aliases, %{}
    ret = aliases
      |> Enum.flat_map(fn {alias_, cmd} ->
        try do
          if Process.alive? cmd do
            {:ok, res} = Serverboards.IO.Cmd.call cmd, "dir", []
            res |> Enum.map(fn d ->
                #Logger.debug("Got function #{alias_} . #{d}")
                "#{alias_}.#{d}"
              end)
          else
            # remove from aliases
            RPC.Context.update context, :plugin_aliases, [{alias_, nil}]
            []
          end
        rescue
          e ->
            Logger.error("Plugin with alias #{alias_} #{inspect cmd} does not implement dir. Fix it.\n#{inspect e}\n#{Exception.format_stacktrace}")
            []
        end
      end)
    #Logger.debug("Alias methods are: #{inspect ret}")
    ret
  end

end
