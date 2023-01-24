defmodule SEVOVV do
  use Application
  require KVS
  require ERP
  require FORM

  def id(ERP."Employee"(person: ERP."Person"(id: id))), do: id
  def id(el) when is_tuple(el), do: :erlang.element(2, el)
  def id(el) when is_list(el), do: :lists.map(fn x when is_tuple(x) -> :erlang.element(2, x); x1 -> x1 end, el)
  def id(el) when is_binary(el) or is_atom(el), do: el
  def id(_), do: ""

  def v4() do
    v4(:rand.uniform(:erlang.round(:math.pow(2, 48))) - 1,
       :rand.uniform(:erlang.round(:math.pow(2, 12))) - 1,
       :rand.uniform(:erlang.round(:math.pow(2, 32))) - 1,
       :rand.uniform(:erlang.round(:math.pow(2, 30))) - 1)
  end
  def v4(r1, r2, r3, r4), do: <<r1::48, 4::4, r2::12, 2::2, r3::32, r4::30>>
  def guid(), do: :nitro.to_binary(:string.uppercase(to_str(v4())))
  def to_str(u), do: :lists.flatten(:io_lib.format('~8.16.0b-~4.16.0b-~4.16.0b-~2.16.0b~2.16.0b-~12.16.0b', get_parts(u)))
  def get_parts(<<tL::32, tM::16, tHV::16, cSR::8, cSL::8, n::48>>), do: [tL, tM, tHV, cSR, cSL, n]

  def get_doc_id(doc), do: apply(rules(), :get_doc_id, [id_rules(:erlang.element(1, doc)), :erlang.element(1, doc), doc])
  def get_doc_id(doc, input_id), do: apply(rules(), :get_doc_id, [id_rules(:erlang.element(1, doc)), :erlang.element(1, doc), doc, input_id])

  def get_proc_id(doc_type, doc_id), do: apply(rules(), :get_proc_id, [id_rules(doc_type), doc_id])

  def rules(), do: :application.get_env(:crm, :rules_module, SEVOVV)
  def id_rules(doc_type), do: (case :kvs.get("/crm/docs", doc_type) do {:ok, FORM.formReg(id_rules: x)} -> x; _ -> [] end)

  def start(_, _) do
    :logger.add_handlers(:sevovv)
    :kvs.join([], KVS.kvs(mod: :kvs_rocks, db: 'rocksdb'))
    :kvs.join([], KVS.kvs(mod: :kvs_mnesia))
    :erp.boot()

    sev_ovv = Supervisor.start_link([], strategy: :one_for_one, name: SEVOVV)

    SEV.Listener.start()

    sev_ovv
  end
end
