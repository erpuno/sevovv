defmodule SEV do
  require ERP

  def inbox(org_id, count), do:
    (case :kvs.get("/crm/sev/org", org_id) do ERP."Organization"(login: l, password: p) -> inbox(l, p, count); _ -> [] end)
  def inbox(login, pass, count), do: SEV.BUS.messages(login, pass, count)

  def delete(login, pass, session, id), do: SEV.BUS.closeSession(login, pass, session, id)

  def process(msg, pid), do: SEV.BPE.process(msg, pid)

  def error(type, msg, pid), do: SEV.BPE.error(type, msg, pid)

  def download(login, pass, id, pid), do: SEV.DOWN.start(login, pass, id, pid)

  def upload(id, login, pass, msg, pid), do: SEV.UP.start(login, pass, id, msg, pid)

  def ack(ack, pid), do: SEV.BPE.handle(ack, pid)

  def ack(ack, regnumber, regdate, errortext, doc, pid), do: SEV.BPE.generate(doc, pid, ack, regnumber, regdate, errortext)

  def send(id, doc, bPid, pid), do: SEV.BPE.generate(id, doc, bPid, pid)

end