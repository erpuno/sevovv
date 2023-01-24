defmodule NPA do
  require ERP

# sev20 test environment credentials
#  @from "34239034"
#    @to "34239035"

# 34239034:a96bde74-09de-4823-8de1-d6c2cc503fab:90207e60-3c9f-46fd-a366-96aab3042d42
 # @user "a96bde74-09de-4823-8de1-d6c2cc503fab"
  #@pass "90207e60-3c9f-46fd-a366-96aab3042d42"

# 34239035:574ec453-b3fe-44ac-a5e5-508ae223620c:da94a8a7-ef54-4f39-bd78-68324e894c25
#  @user "574ec453-b3fe-44ac-a5e5-508ae223620c"
#  @pass "da94a8a7-ef54-4f39-bd78-68324e894c25"

# 34239036:2f80d518-6147-4219-adfc-1cd2b5ba8979:f897ac6e-e1c1-4b84-a445-26e5a999ed7f

  # NPA API: Retrive all Legal Acts from NPA inbox

  def today(), do: []
  def today(_stage), do: []

  def recent(), do: []
  def recent(_stage), do: []

  def yester(), do: []
  def yester(_stage), do: []

  def count(), do: []

  def list(), do: []

  # NPA API: Create Legal Act

  def create(), do: []

  def create(_stage), do: []
    # Generate URN/LegalActGUID

  def createDoc(_codeFrom, _codeTo, _createDoc), do: []

  def closeDoc(_codeFrom, _closeDoc), do: []

  # NPA API: Close Legal Act at a given Stage

  def close(_closeGuid, _stage), do: []
  def close(_codeFrom, _closeGuid, _stage), do: []

  # NPA API: Revoke Legal Act

  def revoke(_closeGuid, _stage), do: []

  def skip(_closeGuid, _stage), do: []

  def transfer(_closeGuid, _stage), do: []

  # NPA API: Extend Legal Act due date

  def extend(_closeGuid, _stage, _prolongation_date), do: []

  def newURN(), do: []

  def newURN(_type), do: []

  def routingInfo(_x), do: []

  def regDate(_x), do: []
  def unpack(_t), do: []

  # parse LegalAct stanzas

  def parse(_, _acc, _), do: []

  def groupByActThenByStage, do: []

  def dumpAct(_actGuid), do: []

  def dumpActNotify(_actGuid), do: []

  def trimTime(_time), do: []

  def generateCSV({_actGuid, _act}), do: []

  def all, do: []

  def groupByAct(_docs), do: []

  def groupByStage(_input), do: []

  def parseAct(_guid, _folder), do: []

end
