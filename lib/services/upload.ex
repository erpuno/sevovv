defmodule SEV.UP do
  require N2O
  import Record

  @prefix "priv/sev/upload/"

  defrecordp(:state, id: [], login: [], pass: [], pid: [], msg: [])

  defp spec(i, l, p, msg, pid), do:
    N2O.pi(module: __MODULE__, table: :sev, sup: SEV.Listener, restart: :temporary,
           timeout: :brutal_kill, state: state(id: i, msg: msg, login: l, pass: p, pid: pid), name: "upload#{i}")

  def start(login, pass, id, msg, pid), do:
    (case :n2o_pi.start(spec(id, login, pass, msg, pid)) do {x, _} when is_pid(x) -> send(x, :generate); _ -> [] end)

  def proc(:init, N2O.pi(state: state(id: id, msg: msg, pid: pid)) = pi), do:
    (send(pid, {:upload, :init, id, [], msg}); :erlang.process_flag(:trap_exit, true); :filelib.ensure_dir("#{@prefix}#{id}.uploading"); {:ok, pi})

  def proc(:generate, N2O.pi(state: state(id: i, login: login, pass: pass, msg: msg)) = pi) do
    {from, to, time, body} = SEV.Body.gen(login, msg)
    :ok = :file.write_file("#{@prefix}#{i}.uploading", body, [:raw, :binary])
    SEV.UTL.info('UPLOAD START ~s ~p ~p ~p ~tp', [i, from, to, time, :erlang.element(1, msg)])
    type = :kvs.field(:kvs.field(msg, :msg_type), :type)
    send(self(), {:start, SEV.BUS.startUpload(i, from, to, login, pass, :erlang.size(body), SEV.UTL.sha256(body), type, time), :erlang.size(body)})
    {:noreply, pi}
  end

  def proc({:start, %{:partSize => partSize, :bytesCount => pos, :session => sId}, size}, N2O.pi(state: state(id: id, msg: msg, pid: pid)) = pi), do:
    (send(pid, {:upload, :uploading, id, sId, msg}); send(self(), {:upload, size, pos, partSize, sId, size - pos}); {:noreply, pi})

  def proc({:upload, size, pos, _, sId, _}, N2O.pi(state: state(login: login, pass: pass)) = pi) when pos >= size, do:
    (send(self(), {:final, SEV.BUS.endUploading(login, pass, sId)}); {:noreply, pi})

  def proc({:upload, size, pos, count, sId, rest}, N2O.pi(state: state(id: id, login: login, pass: pass)) = pi) do
    count = :erlang.min(count, rest)
    {:ok, fd} = :file.open("#{@prefix}#{id}.uploading", [:read, :raw, :binary])
    {:ok, data} = :file.pread(fd, pos, count)
    :ok = :file.close(fd)
    SEV.UTL.info('UP ~p', [{:partial, id, size, pos, count, rest}])
    send(self(), {:chunk, SEV.BUS.uploadChunk(login, pass, sId, :base64.encode(data)), size, pos, count, :erlang.size(data)})
    {:noreply, pi}
  end

  def proc({:chunk, %{:session => sId}, size, pos, count, chunkSize}, N2O.pi() = pi) do
    rest = size - (pos + chunkSize)
    send(self(), {:upload, size, pos + chunkSize, :erlang.min(rest, count), sId, rest})
    {:noreply, pi}
  end

  def proc({:final, %{:session => s}}, N2O.pi(state: state(id: id, msg: msg, pid: pid)) = pi) do
    send(pid, {:upload, :uploaded, id, s, msg})
    SEV.UTL.info('UPLOAD FINISH ~s ~tp', [id, s])
    :filelib.ensure_dir("#{@prefix}#{id}/#{id}.xml")
    File.rename("#{@prefix}#{id}.uploading", "#{@prefix}#{id}/#{id}.xml")
    {:stop, :normal, pi}
  end

  def proc(_, pi), do: {:stop, :error, pi}

  def terminate(:normal, _), do: []
  def terminate(reason, N2O.pi(state: state(id: i, pid: pid, msg: msg))), do:
    (send(pid, {:upload, :error, i, [], msg}); SEV.UTL.warning('UPLOAD ~ts TERMINATE REASON ~tp', [i, reason]))

end