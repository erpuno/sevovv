defmodule SEV.Listener do
  require N2O
  require ERP
  require KVS
  import Record

  @delete_on_preload true
  @delay {0, 0, 10}

  defrecord(:sign, id: [], body: [], time: [])
  defrecord(:file, id: [], type: [], description: [], main: false, sign: [], body: [])
  defrecord(:acknowledgement, id: [], org: [], msg_type: [], corr: [], time: [], ack_to: [], ack_type: [], error: [], error_code: [], regnumber: [], regdate: [])
  defrecord(:document, id: [], annotation: [], document_type: [], files: [], corr: [], org: [], title: [], kind: [],
                       approvers: [], tasks: [], referred_tasks: [], comment: [], msg_acknow: [], msg_type: [], purpose: [],
                       regdate: [], regnumber: [], time: [], urgent: [], pid: [], referred: [], pages: [], attestation: [])
  defrecord(:task, id: [], guid: [], number: [], deadline: [], text: [], control: [], date: [], executor: [], subexecutors: [], notify: [])
  defrecord(:approver, id: [], guid: [], deadline: [], org: [])
  defrecord(:executor, type: [], org: [])
  defrecord(:reference, id: [], type: [])

  defrecordp(:state, id: [], timer: [], login: [], pass: [])
  defrecordp(:msg, id: [], status: [], session: [], document: [], pid: [], time: [])

  def metainfo(), do: KVS.schema(name: SEV.Listener, tables: tables())
  def tables(), do: [KVS.table(name: :msg, fields: Keyword.keys(msg(msg())), instance: msg()),
                     KVS.table(name: :document, fields: Keyword.keys(document(document())), instance: document()),
                     KVS.table(name: :acknowledgement, fields: Keyword.keys(acknowledgement(acknowledgement())), instance: acknowledgement())]

  defp spec(ERP."Organization"(code: i, login: l, password: p)), do:
    N2O.pi(module: __MODULE__, restart: :permanent, timeout: 10000, name: "inbox#{i}",
           sup: __MODULE__, state: state(id: i, login: l, pass: p), table: :sev)

  def start(), do:
    (Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__);
     :lists.foreach(&:n2o_pi.start(spec(&1)), :kvs.all("/crm/sev/org")))

  def stop(), do:
    :lists.foreach(&:n2o_pi.stop(:sev, "inbox" <> ERP."Organization"(&1, :code)), :kvs.all("/crm/sev/org"))

  def proc(:init, N2O.pi(state: state(login: l, pass: p))) when l in ["", []] or p in ["", []], do: {:stop, :invalid_config}
  def proc(:init, N2O.pi(state: state() = s) = pi), do: {:ok, N2O.pi(pi, state: state(s, timer: timer(@delay)))}

  def proc(:ping, N2O.pi(state: state(login: l, pass: p, timer: t) = s) = pi), do:
    (:erlang.cancel_timer(t); send(self(), {:inbox, SEV.inbox(l, p, 1000)});
     {:noreply, N2O.pi(pi, state: state(s, timer: timer(@delay)))})

  def proc({:inbox, messages}, N2O.pi(state: state(id: org, login: l, pass: p)) = pi) do
    :lists.foreach(fn {:MessageInfo, %{:MessageId => id}} ->
      case :kvs.get("/sev/messages/#{org}", id) do
        {:ok, msg(status: :init)} -> []
        {:ok, msg(status: :processed)} -> []
        {:ok, msg(status: :parsed)} -> []
        {:ok, msg(status: :downloading)} -> []
        {:ok, msg(status: :zombie)} -> []
        {:error, _} -> SEV.UTL.info('income new ~tp', [id]); SEV.download(l, p, id, self())
        x -> SEV.UTL.warning('unknown status ~tp: ~tp', [id, x])
      end
    end, messages)
    {:noreply, pi}
  end

  def proc({:download, :downloaded = s, id, session}, N2O.pi(state: state(id: org, login: l, pass: p)) = pi), do:
    (status(org, id, s, :session, session); @delete_on_preload == true and SEV.delete(l, p, session, id); {:noreply, pi})
  def proc({:download, :parsed = s, id, document() = res}, N2O.pi(state: state(id: org)) = pi), do:
    (status(org, id, s, :document, res); send(self(), {:ack, 1, id, [], [], []}); {:noreply, pi})
  def proc({:download, :parsed = s, id, acknowledgement() = res}, N2O.pi(state: state(id: org)) = pi), do:
    (status(org, id, s, :document, res); send(self(), {:ack, res}); {:noreply, pi})
  def proc({:download, s, id, session}, N2O.pi(state: state(id: org)) = pi), do: (status(org, id, s, :session, session); {:noreply, pi})

  def proc({:upload, :uploaded, id, _, msg}, N2O.pi(state: state(id: org)) = pi), do:
    (status(org, id, :uploaded, :document, msg); SEV.process(msg, self()); {:noreply, pi})
  def proc({:upload, :error, id, _, msg}, N2O.pi(state: state(id: org)) = pi), do:
    (status(org, id, :error, :document, msg); SEV.error(:upload, msg, self()); {:noreply, pi})
  def proc({:upload, s, id, session, _}, N2O.pi(state: state(id: org)) = pi), do: (status(org, id, s, :session, session); {:noreply, pi})

  def proc({:bpe, :generated, id, x}, N2O.pi(state: state(id: org, login: l, pass: p)) = pi), do:
    (status(org, id, :generated, :document, x); SEV.upload(id, l, p, x, self()); {:noreply, pi})
  def proc({:bpe, :processed, id, doc}, N2O.pi(state: state(id: org)) = pi), do:
    (status(org, id, :processed, :document, doc); {:noreply, pi})

  def proc({:send, id, doc, pid}, N2O.pi(state: state(id: org)) = pi), do:
    (status(org, id, :init, :pid, pid); SEV.send(id, doc, pid, self()); {:noreply, pi})

  def proc({:ack, acknowledgement() = ack}, N2O.pi() = pi), do: (SEV.ack(ack, self()); {:noreply, pi})

  def proc({:ack, ack, id, regnumber, regdate, errortext}, N2O.pi(state: state(id: org)) = pi), do:
    (case :kvs.get("/sev/messages/#{org}", id) do
       {:ok, msg(document: doc)} -> SEV.ack(ack, regnumber, regdate, errortext, doc, self());
       _ -> []
     end;
     {:noreply, pi})

  def proc(_, pi), do: {:noreply, pi}

  def ack_to(ERP."Organization"(code: org), id), do:
    (case :kvs.get("/sev/messages/#{org}", id) do {:ok, msg(document: x)} -> x; _ -> [] end)

  defp status(org, id, s, f, v), do:
    (x = case :kvs.get("/sev/messages/#{org}", id) do {:ok, msg() = x} -> x; _ -> msg() end;
     :kvs.append(:kvs.setfield(msg(x, id: id, status: s, time: :calendar.universal_time()), f, v), "/sev/messages/#{org}"))

  defp timer({h, m, s}), do: :erlang.send_after(1000 * (s + 60 * m + 60 * 60 * h), self(), :ping)

end