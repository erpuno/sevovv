defmodule NPA.CRON do
  require BPE
  require N2O
  require ERP
  require Logger

  def start() do
    Supervisor.start_link([], strategy: :one_for_one, name: NPA.CRON)

    N2O.pi(
      module: NPA.CRON,
      table: :cron,
      sup: NPA.CRON,
      state: {[], []},
      timeout: 60000,
      name: "npacron"
    )
    |> :n2o_pi.start()
  end

 # def generateReportNPA(act) do
#      :erlang.send(:n2o_pi.pid(:cron, "cron"), {:generateNPA, act})
#  end

 # def find(atom,dump) do
#    case :lists.flatten(:lists.foldl(fn {_,[]},acc -> acc
#       {_,list},acc ->
#       :lists.foldl(fn y,acc2 -> [case :proplists.get_value(atom,y,[]) do [] -> [] ; v -> {:urn,v} end |acc2] end,[],list) ++ acc
#    end, [], dump)) do
#       [] -> []
#       [{_,x}|_] -> x
#    end
 # end

#  def sampleReportNPA(_act, _dump, _dumpNotify), do: []
#      {approved,_approved1} = case :proplists.get_value(3, dump, []) do
#         [] -> {[],[]}
#          [dump1] -> {[],dump1}
#          [dump1,dump2|_] -> {dump2,dump1}
#
#      end
#      {concluded,concluded1,skip2} = case :proplists.get_value(2, dump, []) do
#        [] -> {[],[],true}
#         [dump2] -> {[],dump2,false}
#         [dump1,dump2|_] -> {dump2,dump1,false}
#      end
#      create = hd(:proplists.get_value(1, dumpNotify, []))
#      {_download,download1} = case :proplists.get_value(1, dump, []) do
#         [] -> {[],[]}
#         [dump2] -> {[],dump2}
#         [dump1,dump2|_] -> {dump2,dump1}
#      end
#      stage0 = :proplists.get_value(0, dump, [])
#      {register,agree} = case stage0 do
#         [] -> {:proplists.get_value(:from, download1, []),"Без батьківської СЕД"}
#          _ -> {:proplists.get_value(:to, hd(:lists.reverse(stage0))),:proplists.get_value(:from, hd(:lists.reverse(stage0)))}
#      end
#      ERP.npaReport(
#         name: :proplists.get_value(:name, create, []),
#         register: register,
#         begin_date: :proplists.get_value(:time, create, []),
#         agree: agree,
#         agree_date: :proplists.get_value(:regDate, approved, []),
#         num: find(:urn,dump),
#         guid: act,
#         skip2: skip2,
#         content: find(:content,dump),
#         exp_date: NPA.trimTime(:nitro.to_binary(:proplists.get_value(:time, concluded, []))),
#         exp_term_date: :proplists.get_value(:deadline, concluded1, []),
#         exp_conclusion_date: :proplists.get_value(:regDate, concluded, []),
#         register_num: :proplists.get_value(:regNumber, approved, []),
#         register_date: :proplists.get_value(:regDate, approved, [])
#     )
 # end

 # def docxDSL({:npaReport, name, register, date, agree, agree_date, num, guid, skip2, content, exp_date,
#                           exp_term_date, exp_conclusion_date, register_num, register_date}) do
#      [
#        {"Table",:vector, "priv/sev/npa-reports/" <> guid <> ".csv"},
#        {"name",:base64,:base64.encode(name)},
#        {"register",:base64,:base64.encode(register)},
#        {"begin_date",:base64,:base64.encode(date)},
#        {"agree",:base64, :base64.encode(agree)},
#        {"agree_date",:base64,:base64.encode(agree_date)},
#        {"num",:scalar, num},
#        {"guid",:scalar, guid},
#        {"content",:base64,:base64.encode(content)}]
#     ++ case skip2 do true -> [] ; _ ->
#       [{"exp_date",:base64,:base64.encode(exp_date)},
#        {"exp_term_date",:base64,:base64.encode(exp_term_date)},
#        {"exp_conclusion_date",:base64,:base64.encode(exp_conclusion_date)}]
#        end ++
#       [{"register_num",:scalar,register_num},
#        {"register_date",:base64,:base64.encode(register_date)}
#      ]
#  end

  #def compileDSL(dsl), do: :lists.map(fn {name,type,value} -> :io_lib.format ' ~p "~ts" "~ts" , ', [type,name,value] end, dsl)

  def proc(:init, pi) do
    :filelib.ensure_dir('priv/sev/npa-reports/')
    {:ok, N2O.pi(pi, state: {[], ping(100)})}
  end

#  def proc({:generateNPA, act}, N2O.pi(state: {_, timer}) = pi) do
#      {act, dump} = NPA.dumpAct act
#      {act, dumpNotify} = NPA.dumpActNotify act
#      NPA.generateCSV {act, dump}
#      CRM.debug 'Генерація аркушу погодження: ~ts', [act]
#      npaReport = sampleReportNPA(act, dump, dumpNotify)
#      compile = npaReport |> docxDSL |> compileDSL
#      guid = :nitro.to_list act
#      template = case ERP.npaReport(npaReport, :skip2) do
#         true -> 'npaSkip2.docx'
#         false -> 'npa.docx'
#      end
#      exe = :lists.concat(['priv/docx/docx -vars ',compile,' -in "priv/docx/',template,'" -out "priv/sev/npa-reports/',guid,'.docx"'])
#      CRM.QR.execute(exe, false)
#      {:noreply, N2O.pi(pi, state: {[], timer})}
 # end

  def proc({:check}, N2O.pi(state: {_, timer}) = pi) do
    :erlang.cancel_timer(timer)
    new_timer = ping(30000)
    {:noreply, N2O.pi(pi, state: {[], new_timer})}
  end

  def proc(_, N2O.pi(state: {_, timer}) = pi) do
      {:reply, :ok, N2O.pi(pi, state: {[], timer})}
  end

  def ping(milliseconds), do: :erlang.send_after(milliseconds, :n2o_pi.pid(:cron, "cron"), {:check})

end
