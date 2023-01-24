defmodule SEV.TEST.LEGAL do
  require ERP

#  @from "34239034"
 # @to "34239035"
#  @to "77777777"

  def staging({_urn, _act}, _stage), do: []

  def testLegalRequest(_guid, _urn, _act, _stage), do: []

  def testLegalInformationTransfer(_guid, _urn, _act, _stage), do: []

  def testLegalApproval(_guid, _inAnswerTo, _urn, _act, _stage), do: []
end
