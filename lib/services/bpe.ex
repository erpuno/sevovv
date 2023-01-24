defmodule SEV.BPE do
  require N2O
  require ERP
  require BPE
  require FORM
  import Record
  import SEV.Listener

  def sendAck(ack, ERP.receiveSevDoc(guid: id, corr: ERP."Organization"(code: c), project: ERP.project(comment: ERP.rejectComment(comment: comment)))), do:
    (case :n2o_pi.pid(:sev, "inbox#{c}") do x when is_pid(x) -> send(x, {:ack, ack, id, [], [], comment});
                                            _ -> SEV.Listener.start(); send(:n2o_pi.pid(:sev, "inbox#{c}"), {:ack, ack, id, [], [], comment}) end)
  def sendAck(ack, ERP.receiveSevDoc(guid: id, corr: ERP."Organization"(code: c), reg_date: rD, reg_number: rN)), do:
    (case :n2o_pi.pid(:sev, "inbox#{c}") do x when is_pid(x) -> send(x, {:ack, ack, id, rN, rD, []});
                                            _ -> SEV.Listener.start(); send(:n2o_pi.pid(:sev, "inbox#{c}"), {:ack, ack, id, rN, rD, []}) end)

  def sendDoc(ERP.sendSevDoc(guid: g, from: ERP."Organization"(code: c)) = doc, pid), do:
    (case :n2o_pi.pid(:sev, "inbox#{c}") do x when is_pid(x) -> send(x, {:send, g, doc, pid});
                                            _ -> SEV.Listener.start(); send(:n2o_pi.pid(:sev, "inbox#{c}"), {:send, g, doc, pid}) end)

  @download "priv/sev/download/"
  @upload "priv/sev/upload/"
  @storage "priv/storage/"

  defrecordp(:state, id: [], pid: [])

  defp spec(id, pid), do:
    N2O.pi(module: __MODULE__, table: :sev, sup: SEV.Listener, restart: :temporary,
           timeout: :brutal_kill, state: state(id: id, pid: pid), name: "bpe#{id}")

  def generate(id, msg, bPid, pid), do:
    (case :n2o_pi.start(spec(id, pid)) do {x, _} when is_pid(x) -> send(x, {:generate, id, msg, bPid}); _ -> [] end)
  def generate(msg, pid, ack, regnumber, regdate, errortext), do:
    (case :n2o_pi.start(spec(:kvs.field(msg, :id), pid)) do {x, _} when is_pid(x) -> send(x, {:generate, msg, ack, regnumber, regdate, errortext}); _ -> [] end)

  def error(type, msg, pid), do:
    (case :n2o_pi.start(spec(:kvs.field(msg, :id), pid)) do {x, _} when is_pid(x) -> send(x, {:error, type, msg}); _ -> [] end)

  def process(msg, pid), do:
    (case :n2o_pi.start(spec(:kvs.field(msg, :id), pid)) do {x, _} when is_pid(x) -> send(x, {:process, msg}); _ -> [] end)

  def handle(ack, pid), do:
    (case :n2o_pi.start(spec(:kvs.field(ack, :id), pid)) do {x, _} when is_pid(x) -> send(x, {:handle, ack}); _ -> [] end)

  def proc(:init, N2O.pi() = pi), do: (:erlang.process_flag(:trap_exit, true); {:ok, pi})

  def proc({:generate, id, msg, bPid}, N2O.pi(state: state(pid: pid)) = pi), do:
    (send(pid, {:bpe, :generated, id, create(id, msg, bPid)}); {:stop, :normal, pi})

  def proc({:generate, msg, ack, regnumber, regdate, errortext}, N2O.pi(state: state(pid: pid)) = pi), do:
    (acknowledgement(id: id) = x = create(msg, ack, regnumber, regdate, errortext); send(pid, {:bpe, :generated, id, x}); {:stop, :normal, pi})

  def proc({:process, acknowledgement(id: aId, ack_type: 1, ack_to: document(id: id) = d) = ack}, N2O.pi(state: state(pid: lPid)) = pi) do
    ERP.receiveSevDoc(guid: guid, tasks: tasks, out_reg_number: rN, out_reg_date: rD, from: ERP."Organization"(name: oN)) = doc = convert(ack)
    {:ok, FORM.formReg(proc: module)} = :kvs.get("/crm/docs", :receiveSevDoc)
    doc_id = SEVOVV.get_doc_id(doc)
    monitor = :kvs.seq(:monitor, 1)
    pid = SEVOVV.get_proc_id(:receiveSevDoc, doc_id)
    :bpe.start(BPE.process(module.def(), id: pid, monitor: monitor), [ERP.receiveSevDoc(doc, id: doc_id)], {BPE.monitor(id: monitor), BPE.procRec(name: doc_id)})
    :kvs.append(ERP.sevRef(id: guid, regnumber: rN, regdate: rD, org: oN, pid: pid), "/sev/ref/in/documents")
    :lists.map(fn ERP.sevTask(guid: g, number: n, date: d) -> :kvs.append(ERP.sevRef(id: g, regnumber: n, regdate: d, pid: pid), "/sev/ref/in/tasks/#{guid}") end, tasks)
    send(lPid, {:bpe, :processed, id, document(d, pid: pid)})
    send(lPid, {:bpe, :processed, aId, acknowledgement(ack, ack_to: document(d, pid: pid))})
    :bpe.next(pid)
    {:stop, :normal, pi}
  end
  def proc({:process, acknowledgement(id: id, ack_to: document(pid: pid)) = ack}, N2O.pi(state: state(pid: lPid)) = pi), do:
    (:bpe.messageEvent(pid, BPE.messageEvent(name: 'Acknowledgement')); send(lPid, {:bpe, :processed, id, ack}); {:stop, :normal, pi})
  def proc({:process, document(id: id, pid: pid, regnumber: rN, regdate: rD, tasks: t) = doc}, N2O.pi(state: state(pid: lPid)) = pi), do:
    (:kvs.append(ERP.sevRef(id: id, regnumber: rN, regdate: rD, pid: pid), "/sev/ref/out/documents");
     :lists.map(fn task(guid: g, number: n, date: d) -> :kvs.append(ERP.sevRef(id: g, regnumber: n, regdate: d, pid: pid), "/sev/ref/out/tasks/#{id}") end, t);
     :bpe.messageEvent(pid, BPE.messageEvent(name: 'Uploaded')); send(lPid, {:bpe, :processed, id, doc}); {:stop, :normal, pi})

  def proc({:handle, acknowledgement(id: id, regnumber: rN, regdate: rD, error: e, error_code: eC, ack_to: document(pid: pid)) = ack}, N2O.pi(state: state(pid: lPid)) = pi), do:
    (:bpe.messageEvent(pid, BPE.messageEvent(name: 'Acknowledgement', payload: {rN, rD, e, eC})); send(lPid, {:bpe, :processed, id, ack}); {:stop, :normal, pi})

  def proc({:error, :upload, document(pid: pid)}, N2O.pi() = pi), do:
    (:bpe.messageEvent(pid, BPE.messageEvent(name: 'UploadError')); {:stop, :normal, pi})

  def proc(_, pi), do: {:stop, :error, pi}

  def terminate(:normal, _), do: []
  def terminate(reason, N2O.pi(state: state(id: i))), do: SEV.UTL.warning('BPE ~ts TERMINATE REASON ~tp', [i, reason])

  defp create(id, ERP.sendSevDoc(reg_number: regnumber, reg_date: regdate, content: content, urgent: urgent, tasks: tasks,
                                 referred_tasks: ref_tasks, sending_time: time, from: from, corr: corr, kind: kind, purpose: purpose,
                                 referred: ref, main_sheets: pages, attachments: atts, document_type: type, msg_type: msg_type,
                                 title: title, approvers: approvers, approval_status: attestation, approval_comment: comment), bPid), do:
    document(id: id, pid: bPid, regnumber: regnumber, pages: pages, regdate: regdate, annotation: content,
             tasks: tasks(id, tasks), comment: comment, time: time, corr: corr, org: from, kind: kind, purpose: purpose,
             urgent: urgent, approvers: approvers(id, approvers), attestation: attestation, files: files(id, atts), msg_type: msg_type,
             title: title, document_type: type, referred: ref, referred_tasks: ref_tasks)
  defp create(document(corr: ERP."Organization"() = c, org: ERP."Organization"() = o) = doc, ack, regnumber, regdate, errortext), do:
    acknowledgement(id: SEVOVV.guid(), msg_type: type("0"), ack_to: doc, corr: c, org: o, ack_type: ack, regnumber: regnumber, regdate: regdate, error: errortext)

  defp convert(acknowledgement(ack_to: document(id: id, corr: ERP."Organization"() = from, org: ERP."Organization"() = to, kind: kind,
                                                purpose: ERP.dict() = purpose, msg_type: ERP.dict() = msg_type, urgent: urgent,
                                                annotation: annotation, time: time, title: title, files: f, approvers: approvers,
                                                pages: pages, referred: r, referred_tasks: rT, attestation: attestation, comment: comment,
                                                regdate: regdate, regnumber: regnumber, document_type: ERP.dict() = doc_type, tasks: tasks) = doc)), do:
    ERP.receiveSevDoc(from: from, corr: to, kind: kind, purpose: purpose, msg_type: msg_type, urgent: urgent, document_type: doc_type,
                      referred_tasks: refs(rT, doc), content: annotation, attachments: files(id, f), sending_time: time, title: title,
                      referred: refs(r, doc), main_sheets: pages, approval_status: attestation, approval_comment: comment, out_reg_date: regdate,
                      out_reg_number: regnumber, guid: id, date: :erlang.date(), approvers: approvers(id, approvers), tasks: tasks(id, tasks))

  defp refs(reference(id: id, type: ERP.dict(name: "Документ")), _), do:
    (case :kvs.get("/sev/ref/out/documents", id) do {:ok, ERP.sevRef() = x} -> x; _ -> [] end)
  defp refs([reference(type: ERP.dict(name: "Задача")) | _] = x, document(referred: reference(id: guid))), do:
    :lists.map(fn reference(id: id) -> case :kvs.get("/sev/ref/out/tasks/#{guid}", id) do {:ok, ERP.sevRef() = x} -> x; _ -> [] end end, x)
    |> :lists.flatten()
  defp refs(_, _), do: []

  defp signInfo(guid, msgId, id, [{[], {{_, _, _}, {_, _, _}} = t} | _]), do:
    (File.cp("#{@storage}#{guid}.p7s", "#{@upload}#{msgId}/#{id}.p7s"); sign(time: t))
  defp signInfo(guid, msgId, id, [{ERP."Employee"() = signer, {{_, _, _}, {_, _, _}} = t} | _]), do:
    (File.cp("#{@storage}#{guid}_#{SEVOVV.id(signer)}.p7s", "#{@upload}#{msgId}/#{id}.p7s"); sign(time: t))
  defp signInfo(_, _, _, _), do: []

  defp files(msgId, [ERP.fileDesc() | _] = x), do:
    (:filelib.ensure_dir("#{@upload}#{msgId}/#{msgId}.xml");
    res = :lists.map(fn ERP.fileDesc(id: guid, main: main, fileName: fN, signInfo: sI, mime: mime) ->
      id = :nitro.to_binary(:kvs.seq([], []))
      File.cp("#{@storage}#{guid}", "#{@upload}#{msgId}/#{id}")
      x = file(id: id, main: main, description: "#{fN}.#{mime}", type: ".#{mime}")
      file(x, sign: signInfo(guid, msgId, id, sI))
    end, x);
    case :lists.any(&file(&1, :main), res) do
      true -> res
      _ -> case :lists.partition(&(file(&1, :sign) != []), res) do
             {[], _} -> []
             {[file() = x | t1], t2} -> [file(x, main: true) | t1 ++ t2]
           end
    end)
  defp files(msgId, [file() | _] = x), do:
    (:filelib.ensure_dir(@storage);
     :lists.map(fn file(id: id, main: main, description: d, sign: s) ->
       mime = case :string.casefold(:filename.extension(d)) do <<".">> <> x -> x; x -> x end
       fN = :filename.rootname(:filename.basename(d))
       guid = SEVOVV.guid()
       File.cp("#{@download}#{msgId}/#{id}", "#{@storage}#{guid}")
       r = ERP.fileDesc(id: guid, seq_id: id, main: main, fileName: fN, mime: mime)
       case s do sign(time: x) -> File.cp("#{@download}#{msgId}/#{id}.p7s", "#{@storage}#{guid}.p7s"); ERP.fileDesc(r, needSign: true, signed: x, signInfo: [{[], x}]); _ -> r end
    end, x))

  defp approvers(_, [ERP.sevApprover() | _] = x), do:
    :lists.map(fn ERP.sevApprover(id: id, guid: g, org: o, dueDate: d) -> approver(id: id, guid: g, deadline: d, org: o) end, x)
  defp approvers(id, [approver() | _] = x), do:
    :lists.map(fn approver(guid: guid, deadline: dueDate, org: o) ->
      x = ERP.sevApprover(id: :kvs.seq([], []), guid: guid, dueDate: dueDate, org: o)
      :kvs.append(x, "/sev/approvers/in/#{id}"); x
    end, x)
  defp approvers(_, _), do: []

  defp tasks(_, [ERP.sevTask() | _] = x), do:
    :lists.map(fn ERP.sevTask(id: id, guid: g, number: n, title: t, date: date, control: c, dueDate: d, executor: e0, subexecutors: s0, notify: notify0) ->
      s = :lists.map(&executor(org: &1, type: executor_type("Співвиконавець")), s0)
      notify = :lists.map(&executor(org: &1, type: executor_type("До відома")), notify0)
      e = case e0 do ERP."Organization"() = x -> executor(org: x, type: executor_type("Виконавець")); _ -> [] end
      task(id: id, guid: g, number: n, deadline: d, text: t, date: date, control: c, executor: e, subexecutors: s, notify: notify)
    end, x)
  defp tasks(id, [task() | _] = x), do:
    :lists.map(fn task(guid: guid, number: n, deadline: dueDate, text: t, control: c, date: d, executor: e0, subexecutors: s0, notify: notify0) ->
      s = :lists.map(&executor(&1, :org), s0)
      e = case e0 do executor(org: x) -> x; _ -> [] end
      notify = :lists.map(&executor(&1, :org), notify0)
      x = ERP.sevTask(id: :kvs.seq([], []), guid: guid, date: d, number: n, title: t, dueDate: dueDate, control: c, executor: e, subexecutors: s, notify: notify)
      :kvs.append(x, "/sev/tasks/in/#{id}"); x
    end, x)
  defp tasks(_, _), do: []

  defp type(id), do: (case :kvs.get("/crm/sevdicts/msg_type", :nitro.to_list(id)) do {:ok, ERP.dict() = x} -> x; _ -> [] end)

  defp executor_type(name), do:
    (case :lists.keyfind(name, ERP.dict(:name) + 1, :kvs.all("/crm/sevdicts/executor_type")) do
      ERP.dict() = x -> x
      _ -> []
    end)
end