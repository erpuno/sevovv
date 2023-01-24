defmodule SEV.DOWN do
  require N2O
  import Record

  @prefix "priv/sev/download/"

  defrecordp(:state, id: [], login: [], pass: [], pid: [])

  defp spec(l, p, i, pid), do:
    N2O.pi(module: __MODULE__, table: :sev, sup: SEV.Listener, restart: :temporary,
           timeout: :brutal_kill, state: state(id: i, login: l, pass: p, pid: pid), name: "down#{i}")

  def start(login, pass, id, pid), do: :n2o_pi.start(spec(login, pass, id, pid))

  def proc(:init, N2O.pi(state: state(id: msg, login: login, pass: pass, pid: pid)) = pi) do
    send(pid, {:download, :init, msg, []})
    :erlang.process_flag(:trap_exit, true)
    :filelib.ensure_dir("#{@prefix}")
    send(self(), {:start, SEV.BUS.startDownloading(login, pass, msg)})
    {:ok, pi}
  end

  def proc({:start, %{:partSize => partSize, :session => sessionId, :size => messageSize}}, N2O.pi(state: state(id: id, pid: pid)) = pi) do
    send(pid, {:download, :downloading, id, sessionId})
    {count, x} = case :file.read_file_info("#{@prefix}#{id}.downloading") do {:error,_} -> {0, 0}; {:ok, x} -> {:erlang.element(2, x), 1} end
    send(self(), {:download, messageSize, count + x, :erlang.min(messageSize - count, partSize), sessionId, messageSize - count, x})
    SEV.UTL.info('~s download started as ~s', [id, sessionId])
    {:noreply, pi}
  end

  def proc({:start, %{:error => "14"}}, pi), do: {:stop, :zombie, pi}

  def proc({:download, 0, _, _, sId, _, _}, N2O.pi(state: state(id: id, pid: pid)) = pi), do:
    (SEV.UTL.error('attempt to download empty file ~ts', [id]); send(pid, {:download, :empty, id, sId}); {:stop, :empty, pi})

  def proc({:download, messageSize, pos, count, sessionId, rest, _}, N2O.pi(state: state(login: login, pass: pass)) = pi) when pos >= messageSize do
    send(self(), {:final, SEV.BUS.endDownloading(login, pass, sessionId), messageSize, pos, count, rest})
    {:noreply, pi}
  end

  def proc({:download, messageSize, pos, count, sessionId, rest, x}, N2O.pi(state: state(login: login, pass: pass)) = pi) do
    count = :erlang.min(rest, count)
    send(self(), {:chunk, SEV.BUS.downloadChunk(login, pass, sessionId, pos, count), messageSize, pos, count, sessionId, rest, x})
    {:noreply, pi}
  end

  def proc({:final, %{:hash => hash, :session => s, :type => t}, messageSize, pos, count, rest}, N2O.pi(state: state(id: id, pid: pid)) = pi) do
    SEV.UTL.info('DOWN ~s : ~p', [id, {:final, messageSize, pos, count, rest, s}])
    :filelib.ensure_dir("#{@prefix}#{id}/#{id}.xml")
    File.rename("#{@prefix}#{id}.downloading", "#{@prefix}#{id}/#{id}.xml")
    send(pid, {:download, :downloaded, id, %{:session => s, :type => t}})
    file = case :file.read_file("#{@prefix}#{id}/#{id}.xml") do {:ok, x} -> x; _ -> "" end
    case SEV.UTL.sha256(file) do
      ^hash ->
        xml = case file do <<"\uFEFF", t :: binary>> -> t; x -> x end
        send(pid, {:download, :parsed, id, SEV.Body.parse(xml)})
        {:stop, :normal, pi}
      _ -> {:stop, :hashError, pi}
    end
  end

  def proc({:chunk, %{:partSize => partSize, :message => chunk}, messageSize, pos, count, sessionId, rest, x}, N2O.pi(state: state(id: id)) = pi) do
    SEV.UTL.info('DOWN ~s : ~p', [id, {:download, messageSize, pos, count, rest}])
    :ok = :file.write_file("#{@prefix}#{id}.downloading", :base64.decode(chunk), [:raw, :binary, :append])
    rest = messageSize - (pos + count) + x
    send(self(), {:download, messageSize, pos + count, :erlang.min(rest, partSize), sessionId, rest, x})
    {:noreply, pi}
  end

  def proc(_, pi), do: {:stop, :error, pi}

  def terminate(:zombie, N2O.pi(state: state(id: i, pid: pid))), do: (SEV.UTL.error('ZOMBIE: ~ts', [i]); send(pid, {:download, :zombie, i, []}))
  def terminate(:normal, _), do: []
  def terminate(reason, N2O.pi(state: state(id: i))), do: SEV.UTL.warning('DOWNLOAD ~ts TERMINATE REASON ~tp', [i, reason])

end