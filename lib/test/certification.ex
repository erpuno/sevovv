defmodule SEV.TEST.CERT do
  require ERP

#  @from "34239034"
 # @to "34239035"
#  @to "77777777"

  def testFinalApprovalKMU({_urn,_act}), do: []

  def testTransferFinal({_urn,_act}), do: []

  def testTransfer(), do: []

  def legalAct(), do: []

  def legalAct0(), do: []

  # child org prolog

  def npa_STAGE_0(),           do: []
  def npa_STAGE_1({_urn, _act}), do: []

  # parent org prolog

  def npa_STAGE(),             do: []

  # common coda

  def npa_STAGE_2({_urn, _act}), do: []
  def npa_STAGE_3({_urn, _act}), do: []

  def dir_ALL(), do: []

end
