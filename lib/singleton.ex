defmodule Singleton do
  @moduledoc """
  Singleton application.

  The top supervisor of singleton is a `:simple_one_for_one`
  supervisor. Singleton can manage many singleton processes at the
  same time. Each singleton is identified by its unique `name` term.

  """

  use Application

  require Logger

  def start(_, _) do
    DynamicSupervisor.start_link(strategy: :one_for_one, name: Singleton.Supervisor)
  end

  @doc """
  Start a new singleton process.

  This function needs to be executed on all nodes where the singleton
  process is allowed to live. The actual process will be started only
  once; a manager process is started on each node for each singleton
  to ensure that the process continues on (possibly) another node in
  case of node disconnects or crashes.

  """
  def start_child(module, args, name) do
    child_name = name(module, args)
    spec = {Singleton.Manager, [mod: module, args: args, name: name, child_name: child_name]}

    case DynamicSupervisor.start_child(Singleton.Supervisor, spec) do
      {:ok, _} = ok_result ->
        ok_result

      other ->
        raise "Could not start singleton #{inspect(child_name)}: #{inspect(other, pretty: true)}"
    end
  end

  def stop_child(module, args) do
    child_name = name(module, args)

    case Process.whereis(child_name) do
      nil -> {:error, :not_found}
      pid -> DynamicSupervisor.terminate_child(Singleton.Supervisor, pid)
    end
  end

  defp name(module, args) do
    bin = :crypto.hash(:sha, :erlang.term_to_binary({module, args}))
    String.to_atom("singleton_" <> Base.encode64(bin, padding: false))
  end
end
