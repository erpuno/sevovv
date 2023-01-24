defmodule SEV.Body do
  @behaviour Sax.Handler
  @prefix "priv/sev/download/"
  require ERP
  import SEV.Listener

  def handle_event(:start_document, _, state), do: {:ok, {[], state}}
  def handle_event(:end_document, _, {_, state}), do: {:ok, state}

  def handle_event(:start_element, {"Header", attributes}, {t, _}), do:
    {:ok, {t, case  msg_type(:proplists.get_value("msg_type", attributes, "1")) do
                ERP.dict(name: "Сповіщення") = x ->
                  acknowledgement(id: :proplists.get_value("msg_id", attributes, ""),
                                  msg_type: x,
                                  time: time_to_erl(:proplists.get_value("time", attributes, "")),
                                  corr: org(:proplists.get_value("from_org_id", attributes, []), :proplists.get_value("from_organization", attributes, "")),
                                  org: org(:proplists.get_value("to_org_id", attributes, []), :proplists.get_value("to_organization", attributes, "")))
                x ->
                  document(id: :proplists.get_value("msg_id", attributes, ""),
                           time: time_to_erl(:proplists.get_value("time", attributes, "")),
                           msg_type: x,
                           corr: org(:proplists.get_value("from_org_id", attributes, []), :proplists.get_value("from_organization", attributes, "")),
                           org: org(:proplists.get_value("to_org_id", attributes, []), :proplists.get_value("to_organization", attributes, ""))) end}}
  def handle_event(:start_element, {"Acknowledgement", attributes}, {t, acknowledgement(org: c) = state}), do:
    {:ok, {[{:Acknowledgment, []} | t], acknowledgement(state, ack_type: :proplists.get_value("ack_type", attributes, "0"),
                                                               ack_to: ack_to(c, :proplists.get_value("msg_id", attributes, "")))}}
  def handle_event(:start_element, {"AckResult", attributes}, {[{:Acknowledgment, _} | _] = t, acknowledgement(ack_type: "4") = state}), do:
    {:ok, {t, acknowledgement(state, error: :proplists.get_value("errortext", attributes, ""),
                                     error_code: :proplists.get_value("errorcode", attributes, "0"))}}
  def handle_event(:start_element, {"Document", attributes}, {t, state}), do:
    {:ok, {[{:Document, []} | t], document(state, document_type: document_type(:proplists.get_value("type", attributes, "0")),
                                                  kind: :proplists.get_value("kind", attributes, ""),
                                                  title: :proplists.get_value("title", attributes, ""),
                                                  annotation: :proplists.get_value("annotation", attributes, ""),
                                                  pages: :proplists.get_value("pages", attributes, "0"),
                                                  purpose: purpose(:proplists.get_value("purpose_type", attributes, "0")),
                                                  urgent: bool(:proplists.get_value("urgent", attributes, "0")))}}
  def handle_event(:start_element, {"Approver", attributes}, {t, state}), do:
    {:ok, {[{:Approver, approver(deadline: date_to_erl(:proplists.get_value("deadline", attributes, [])))} | t], state}}
  def handle_event(:start_element, {"ApprovalResponse", attributes}, {t, state}), do:
    {:ok, {t, document(state, attestation: :proplists.get_value("attestation", attributes, []),
                              comment: :proplists.get_value("comment", attributes, []))}}
  def handle_event(:start_element, {"Referred", attributes}, {t, state}), do:
    {:ok, {[{:Referred, reference(id: :proplists.get_value("idnumber", attributes, []),
                                  type: ref_type(:proplists.get_value("retype", attributes, [])))} | t], state}}
  def handle_event(:start_element, {"RegNumber", attributes}, {[{:Document, _} | _] = t, state}), do:
    {:ok, {[{:RegNumber, []} | t], document(state, regdate: date_to_erl(:proplists.get_value("regdate", attributes, [])))}}
  def handle_event(:start_element, {"RegNumber", attributes}, {[{:Acknowledgment, _} | _] = t, state}), do:
    {:ok, {[{:RegNumber, []} | t], acknowledgement(state, regdate: date_to_erl(:proplists.get_value("regdate", attributes, [])))}}
  def handle_event(:start_element, {"AddDocuments", _}, {t, state}), do: {:ok, {[{:AddDocuments, []} | t], state}}
  def handle_event(:start_element, {"DocTransfer", attributes}, {[{x, _} | _] = t, state}), do:
    {:ok, {[{:DocTransfer, file(type: :proplists.get_value("type", attributes, ""),
                                main: x == :Document,
                                description: :proplists.get_value("description", attributes, ""),
                                id: :proplists.get_value("idnumber", attributes, ""))} | t], state}}
  def handle_event(:start_element, {"SignInfo", attributes}, {t, state}), do:
    {:ok, {[{:SignInfo, sign(id: :proplists.get_value("docTransfer_idnumber", attributes, ""))} | t], state}}
  def handle_event(:start_element, {"SigningTime", _}, {[{:SignInfo, _} | _] = t, state}), do: {:ok, {[{:SigningTime, []} | t], state}}
  def handle_event(:start_element, {"SignData", _}, {[{:SignInfo, _} | _] = t, state}), do: {:ok, {[{:SignData, []} | t], state}}
  def handle_event(:start_element, {"TaskList", _}, {t, state}), do: {:ok, {[{:TaskList, []} | t], state}}
  def handle_event(:start_element, {"Task", attributes}, {[{:TaskList, _} | _] = t, state}), do:
    {:ok, {[{:Task, task(guid: :proplists.get_value("idnumber", attributes, []),
                         text: :proplists.get_value("task_text", attributes, ""),
                         deadline: date_to_erl(:proplists.get_value("deadline", attributes, [])),
                         control: bool(:proplists.get_value("referred-control", attributes, "0")))} | t], state}}
  def handle_event(:start_element, {"TaskNumber", attributes}, {[{:Task, x} | t], state}), do:
    {:ok, {[{:TaskNumber, []}, {:Task, task(x, date: date_to_erl(:proplists.get_value("taskDate", attributes, [])))} | t], state}}
  def handle_event(:start_element, {"Executor", attributes}, {[{:Task, _} = x | t], state}), do:
    {:ok, {[{:Executor, executor(type: executor_type(:proplists.get_value("responsible", attributes, "0")))}, x | t], state}}
  def handle_event(:start_element, {"Organization", attributes}, {[{:Approver, app} | t], state}), do:
    {:ok, {[{:Approver, approver(app, org: org(:proplists.get_value("ogrn", attributes, ""), :proplists.get_value("fullname", attributes, "")))} | t], state}}
  def handle_event(:start_element, {"Organization", attributes}, {[{:Executor, exec} | t], state}), do:
    {:ok, {[{:Executor, executor(exec, org: org(:proplists.get_value("ogrn", attributes, ""), :proplists.get_value("fullname", attributes, "")))} | t], state}}
  def handle_event(:start_element, _, state), do: {:ok, state}

  def handle_event(:characters, c, {[{:SignData, _}, {:SignInfo, _} = s | t], state}), do: {:ok, {[{:SignData, c}, s | t], state}}
  def handle_event(:characters, c, {[{:SigningTime, _}, {:SignInfo, _} = s | t], state}), do: {:ok, {[{:SigningTime, time_to_erl(c)}, s | t], state}}
  def handle_event(:characters, c, {[{:DocTransfer, x} | t], state}), do: {:ok, {[{:DocTransfer, file(x, body: c)} | t], state}}
  def handle_event(:characters, c, {[{:RegNumber, _}, {:Document, _} = d | t], state}), do: {:ok, {[{:RegNumber, c}, d | t], state}}
  def handle_event(:characters, c, {[{:RegNumber, _}, {:Acknowledgment, _} = d | t], state}), do: {:ok, {[{:RegNumber, c}, d | t], state}}
  def handle_event(:characters, c, {[{:TaskNumber, _}, {:Task, _} = x | t], state}), do: {:ok, {[{:TaskNumber, c}, x | t], state}}
  def handle_event(:characters, _, state), do: {:ok, state}

  def handle_event(:end_element, "SigningTime", {[{:SigningTime, x}, {:SignInfo, s} | t], state}), do: {:ok, {[{:SignInfo, sign(s, time: x)} | t], state}}
  def handle_event(:end_element, "SignData", {[{:SignData, x}, {:SignInfo, s} | t], state}), do: {:ok, {[{:SignInfo, sign(s, body: x)} | t], state}}
  def handle_event(:end_element, "RegNumber", {[{:RegNumber, x} | t], acknowledgement() = state}), do: {:ok, {t, acknowledgement(state, regnumber: x)}}
  def handle_event(:end_element, "RegNumber", {[{:RegNumber, x} | t], state}), do: {:ok, {t, document(state, regnumber: x)}}
  def handle_event(:end_element, "SignInfo", {[{:SignInfo, x} | t], document(files: f) = state}), do: (save(x, state); {:ok, {t, document(state, files: file_sign(x, f))}})
  def handle_event(:end_element, "DocTransfer", {[{:DocTransfer, x} | t], document(files: f) = state}), do: (save(x, state); {:ok, {t, document(state, files: [file(x, body: []) | f])}})
  def handle_event(:end_element, "AddDocuments", {[{:AddDocuments, _} | t], state}), do: {:ok, {t, state}}
  def handle_event(:end_element, "Referred", {[{:Referred, reference(type: ERP.dict(name: "Документ")) = x} | t], state}), do: {:ok, {t, document(state, referred: x)}}
  def handle_event(:end_element, "Referred", {[{:Referred, reference(type: ERP.dict(name: "Задача")) = x} | t], document(referred_tasks: tasks) = state}), do:
    {:ok, {t, document(state, referred_tasks: [x | tasks])}}
  def handle_event(:end_element, "Referred", {[{:Referred, _} | t], state}), do: {:ok, {t, state}}
  def handle_event(:end_element, "TaskList", {[{:TaskList, _} | t], state}), do: {:ok, {t, state}}
  def handle_event(:end_element, "TaskNumber", {[{:TaskNumber, n}, {:Task, x} | t], state}), do: {:ok, {[{:Task, task(x, number: n)} | t], state}}
  def handle_event(:end_element, "Executor", {[{:Executor, executor(type: ERP.dict(name: "Співвиконавець")) = e}, {:Task, task(subexecutors: s) = x} | t], state}), do:
    {:ok, {[{:Task, task(x, subexecutors: [e | s])} | t], state}}
  def handle_event(:end_element, "Executor", {[{:Executor, executor(type: ERP.dict(name: "Виконавець")) = e}, {:Task, x} | t], state}), do:
    {:ok, {[{:Task, task(x, executor: e)} | t], state}}
  def handle_event(:end_element, "Executor", {[{:Executor, executor(type: ERP.dict(name: "До відома")) = e}, {:Task, task(notify: n) = x} | t], state}), do:
    {:ok, {[{:Task, task(x, notify: [e | n])} | t], state}}
  def handle_event(:end_element, "Executor", {[{:Executor, _} | t], state}), do: {:ok, {t, state}}
  def handle_event(:end_element, "Approver", {[{:Approver, x} | t], document(approvers: a) = state}), do: {:ok, {t, document(state, approvers: [x | a])}}
  def handle_event(:end_element, "Task", {[{:Task, x} | t], document(tasks: tasks) = state}), do: {:ok, {t, document(state, tasks: [x | tasks])}}
  def handle_event(:end_element, _, state), do: {:ok, state}

  def parse(xml), do: ({:ok, x} = Sax.parse_string(xml, SEV.Body, []); x)

  def gen(login, document(id: id, org: ERP."Organization"(code: from), corr: ERP."Organization"(code: to), files: f) = doc), do:
    {from, to, time(), [:xml_decl, {:Header, header(login, doc),
                                     [{:Document, documentHeader(doc), documentBody(doc)}, tasks(doc) ++ files(id, :add, f) ++ expansion(doc)]}] |> XmlGen.generate(format: :none)}
  def gen(login, acknowledgement(ack_to: document(id: id), ack_type: ackT, org: ERP."Organization"(code: from), corr: ERP."Organization"(code: to)) = ack), do:
    {from, to, time(), [:xml_decl, {:Header, header(login, ack),
                                     [{:Acknowledgement, [msg_id: id, ack_type: ackT], ackBody(ack)}]}] |> XmlGen.generate(format: :none)}

  defp header(document(msg_type: ERP.dict(id: t), org: ERP."Organization"(code: fId, name: fName), corr: ERP."Organization"(code: tId, name: tName))), do:
    [msg_type: :nitro.to_binary(t), from_org_id: fId, from_organization: fName, to_org_id: tId, to_organization: tName, msg_acknow: "2"]
  defp header(acknowledgement(org: ERP."Organization"(code: fId, name: fName), corr: ERP."Organization"(code: tId, name: tName))), do:
    [msg_type: "0", from_org_id: fId, from_organization: fName, to_org_id: tId, to_organization: tName]
  defp header(_), do: []
  defp header(login, doc), do:
    [standart: "1207",
     version: "1.5",
     charset: "UTF-8",
     msg_id: :kvs.field(doc, :id),
     time: time(),
     from_system_details: "",
     from_system: "СЕВ",
     from_sys_id: login,
     to_system: "СЕВ",
     to_system_details: "",
     to_sys_id: "99999999"] ++ header(doc)

  defp documentHeader(document(id: id, annotation: annotation, urgent: urgent, pages: pages, kind: kind, purpose: ERP.dict(id: p), document_type: ERP.dict(id: t))), do:
    [idnumber: id, annotation: annotation, urgent: bool(urgent), collection: 0, pages: pages, type: :nitro.to_binary(t), kind: kind, purpose_type: :nitro.to_binary(p)]

  defp documentBody(document(id: id, org: ERP."Organization"() = from, corr: ERP."Organization"() = to, regnumber: rN, regdate: rD, files: f) = doc), do:
    regNumber(rN, rD) ++ [{:Confident, [flag: 0], ""}] ++ files(id, :main, f) ++
      [{:Author, nil, [organization(from), {:OutNumber, nil, regNumber(rN, rD)}]},
       {:Addressee, [type: 0], [organization(to)] ++ referred(doc)},
       {:Writer, nil, [organization(to)]}] ++ approval(doc)

  defp approval(document(purpose: ERP.dict(id: '1'), approvers: a)), do:
    [{:Approval, nil, [{:ApprovalRequest, nil, :lists.map(fn approver(deadline: deadline, org: ERP."Organization"(code: id) = c) ->
                         {:Approver, [idnumber: :nitro.to_binary(id), deadline: date(deadline)], [organization(c)]} end, a)}]}]
  defp approval(document(purpose: ERP.dict(id: '4'), attestation: ERP.dict(name: a), comment: c)), do:
    [{:Approval, nil, [{:ApprovalResponse, [attestation: a, comment: c], []}]}]
  defp approval(_), do: []

  defp referred(document(purpose: ERP.dict(id: '4'), referred: ERP.sevRef(id: id, regnumber: rN, regdate: rD), referred_tasks: [ERP.sevRef() | _] = x)), do:
    [{:Referred, [idnumber: id, retype: "д"], [{:RegNumber, [regdate: date(rD)], rN}]} |
      :lists.map(fn ERP.sevRef(id: guid, regdate: date, regnumber: num) ->
        {:Referred, [idnumber: guid, retype: "з"], [{:TaskNumber, [taskDate: date(date)], num}]}
      end, x)]
  defp referred(_), do: []

  defp tasks(document(id: guid, purpose: ERP.dict(id: '3'), regnumber: rN, regdate: rD, org: ERP."Organization"() = org, tasks: [task() | _] = x)), do:
    [{:TaskList, nil, :lists.map(fn task(guid: i, number: n, date: date, text: t, deadline: d, control: c, executor: e, subexecutors: s, notify: notify) ->
      {:Task, [idnumber: i, task_reg: 0, task_copy: 0, kind: 3, task_text: t, deadline: date(d)] ++ [{:"referred-control", bool(c)}],
        [{:TaskNumber, [taskDate: date(date)], n}, {:Confident, [flag: 0], nil}, {:Referred, [idnumber: guid, retype: "д"], regNumber(rN, rD)}, {:Author, nil, [organization(org)]}] ++
          :lists.flatten(:lists.map(&exec(date, &1), [e | s ++ notify]))}
    end, x)}]
  defp tasks(_), do: []

  defp exec(date, executor(org: ERP."Organization"() = x, type: ERP.dict(id: t))), do: {:Executor, [responsible: t, deadline: date(date)], [organization(x)]}
  defp exec(_, _), do: []

  defp organization(ERP."Organization"(name: name, code: c, position: post, director: person)), do:
    {:Organization, [fullname: name, shortname: name, ogrn: :nitro.to_binary(c), inn: 0],
                      [{:Address, [country: "Україна"], ""}, {:OfficialPerson, nil,
                        [{:Name, nil, person}, {:Official, [post: post, separator: ""], ""}]}]}

  defp regNumber(regnum, date), do: [{:RegNumber, [regdate: date(date)], regnum}]

  defp ackBody(acknowledgement(ack_type: 3, regnumber: regnum, regdate: regdate)), do: [regNumber(regnum, regdate), {:AckResult, [errorcode: 0, errortext: "OK"], nil}]
  defp ackBody(acknowledgement(ack_type: 4, error: error)), do: [{:AckResult, [errorcode: 0, errortext: error], nil}]
  defp ackBody(_), do: [{:AckResult, [errorcode: 0, errortext: "OK"], nil}]

  defp expansion(document(id: id, org: ERP."Organization"(phones: phone, url: url), files: f)), do:
    [{:Expansion,
       [organization: "INFOTECH SE", exp_ver: "1.0-[2.7.20]"],
       [{:Econtact, [type: "р"], :nitro.to_binary(phone)}, {:Econtact, [type: "і"], :nitro.to_binary(url)}, {:StaticExpansion, nil, signatures(id, f)}]
    }]

  defp files(guid, [file() | _] = x), do:
    :lists.map(fn file(id: id, description: d, type: t) ->
      {:DocTransfer, [type: t, char_set: "UTF-8", description: d, idnumber: id],
        case :filelib.is_regular("priv/sev/upload/#{guid}/#{id}") do
          true -> :base64.encode(:erlang.element(2, :file.read_file("priv/sev/upload/#{guid}/#{id}")))
          false -> ""
        end}
    end, x)
  defp files(_, _), do: []
  defp files(id, :main, [file() | _] = x), do: files(id, :lists.filter(&file(&1, :main), x))
  defp files(id, :add, [file() | _] = x), do: [{:AddDocuments, nil, [{:Folder, [add_type: "0"], files(id, :lists.filter(&(file(&1, :main) != true), x))}]}]

  defp signatures(guid, [file() | _] = x), do:
    :lists.map(fn file(id: id, sign: sign(time: t)) ->
      {:SignInfo, [docTransfer_idnumber: id], [{:SigningTime, nil, time(t)}, {:SignData, nil,
        case :filelib.is_regular("priv/sev/upload/#{guid}/#{id}.p7s") do
          true -> :base64.encode(:erlang.element(2, :file.read_file("priv/sev/upload/#{guid}/#{id}.p7s")))
          false -> ""
        end}]}
                _ -> [] end, x) |> :lists.flatten

  defp save(file(id: i, body: b), document(id: g)), do: :ok = :file.write_file("#{@prefix}#{g}/#{i}", :base64.decode(b), [:raw, :binary])
  defp save(sign(id: i, body: b), document(id: g)), do: :ok = :file.write_file("#{@prefix}#{g}/#{i}.p7s", :base64.decode(b), [:raw, :binary])

  defp file_sign(sign(id: i) = s, x), do:
    (case :lists.keytake(i, 2, x) do {:value, file() = f, t} -> [file(f, sign: sign(s, body: [])) | t]; _ -> x end)

  defp time(), do:
    ({{y, m, d}, {h, min, s}} = :calendar.local_time();
     :erlang.list_to_binary(:io_lib.format('~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ', [y, m, d, h, min, s])))
  defp time({{y, m, d}, {h, min, s}}), do:
    :erlang.list_to_binary(:io_lib.format('~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ', [y, m, d, h, min, s]))

  defp time_to_erl(x) when is_binary(x), do: ({_, t} = NaiveDateTime.from_iso8601(x); NaiveDateTime.to_erl(t))
  defp time_to_erl(_), do: []

  defp date({y, m, d}), do: :erlang.list_to_binary(:io_lib.format('~4..0w-~2..0w-~2..0w', [y, m, d]))
  defp date(_), do: []

  defp date_to_erl(x) when is_binary(x), do:
    {String.to_integer(String.slice(x, 0, 4)), String.to_integer(String.slice(x, 5, 2)),
     String.to_integer(String.slice(x, 8, 2))}
  defp date_to_erl(_), do: []

  defp org(edrpou, name), do:
    (case :kvs.get("/crm/sev/validstakeholders", :nitro.to_list(edrpou)) do
      {:ok, ERP."Organization"() = x} -> x;
      _ ->
        x = ERP."Organization"(id: :nitro.to_list(edrpou), code: edrpou, name: name, orgname: name, type: :juridical);
        :kvs.append(x, "/crm/sev/stakeholders");
        :kvs.append(x, "/crm/sev/stakeholders/orgs");
        :kvs.append(x, "/crm/sev/validstakeholders"); x
    end)

  defp msg_type(id), do: (case :kvs.get("/crm/sevdicts/msg_type", :nitro.to_list(id)) do {:ok, ERP.dict() = x} -> x; _ -> [] end)

  defp purpose(id), do: (case :kvs.get("/crm/sevdicts/purpose/in", :nitro.to_list(id)) do {:ok, ERP.dict() = x} -> x; _ -> [] end)

  defp document_type(id), do: (case :kvs.get("/crm/sevdicts/document_type", :nitro.to_list(id)) do {:ok, ERP.dict() = x} -> x; _ -> [] end)

  defp executor_type(id), do: (case :kvs.get("/crm/sevdicts/executor_type", :nitro.to_list(id)) do {:ok, ERP.dict() = x} -> x; _ -> [] end)

  defp ref_type(id), do: (case :kvs.get("/crm/sevdicts/referred_type", :nitro.to_list(id)) do {:ok, ERP.dict() = x} -> x; _ -> [] end)

  defp bool(true), do: "1"
  defp bool(false), do: "0"
  defp bool("1"), do: true
  defp bool("0"), do: false

end