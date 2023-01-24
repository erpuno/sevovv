defmodule SEV.TEST.REPLY do
  require ERP
#  @from "34239035"
 # @to "34239034"

  # replace these with ids sent from web interface in IAGE order
  def mem(), do: []

  def acks(), do: []
  def acks(_from, _to), do: []

  def acks(_from, _to, _mem), do: []

  def acks3(_from, _to, _mem), do: []

  def all(), do: []
  def all(_from, _to), do: []

  def all(_from, _to, {_i, _a, _g, _e}), do: []

  def testInformation(_guid, _inAnswerTo), do: []

  def testApproval(_guid, _inAnswerTo), do: []

  def testReject(_guid, _inAnswerTo), do: []

  def testGeneralization(_guid, _inAnswerTo), do: []

  def testExecutionTask(_guid, _inAnswerTo), do: []
end
