defmodule SEV.UTL do
  require ERP
  require BPE

  def sha256(string), do:
    (<<x::unsigned-big-integer-size(256)>> = :crypto.hash(:sha256, string);
     :erlang.list_to_binary(:string.uppercase(:lists.flatten(:io_lib.format('~64.16.0b', [x])))))

  def date([]), do: []
  def date({y, m, d}), do: :erlang.list_to_binary(:io_lib.format('~4..0w-~2..0w-~2..0w', [y, m, d]))
  def date(d), do: d

  def time(), do: iso8601(:calendar.local_time())

  def iso8601(:none), do: :none
  def iso8601({{y, m, d}, {h, min, s}}), do:
    :erlang.list_to_binary(:io_lib.format('~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ', [y, m, d, h, min, s]))
  def iso8601(_), do: ""

  def error(f, x), do: :logger.error(:io_lib.format('SEV ' ++ f, x))
  def warning(f, x), do: :logger.warning(:io_lib.format('SEV ' ++ f, x))
  def info(f, x), do: :logger.info(:io_lib.format('SEV ' ++ f, x))

  def ref_tasks([ERP.sevRef() | _] = x, tasks), do:
    (res = :lists.flatten(:lists.map(fn BPE.process(docs: [ERP.receiveSevDoc(tasks: x) | _]) -> x; _ -> [] end, :lists.map(fn ERP.sevRef(pid: x) -> :bpe.load(x) end, x)));
     :lists.filter(fn ERP.sevTask() = t -> !:lists.member(t, tasks) end, res))
  def ref_tasks(_, _), do: []

end