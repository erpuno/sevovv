defmodule SEV.BUS do

  @wsdl "priv/sevovv/wsdl/bus.esb.IntegrationService.cls.xml"

  def messages(login, password, count), do:
    [identity: %{SystemId: login, Password: password}, сount: count]
    |> request("GetInputMessages") |> parse()

  def startUpload(id, from, to, login, password, size, hash, type, time), do:
    [
      identity: %{SystemId: login, Password: password},
      messageInfo:
        %{CreationDate: time,
          Creator: "Sed",
          Format: "Plain",
          FromOrgId: from,
          FromSysId: login,
          Size: size,
          SessionId: "0",
          MessageId: id,
          ToOrgId: to,
          ToSysId: "СЕВ",
          Type: type},
      hash: hash,
      signature: ""
    ] |> request("OpenUploadingSession") |> parse()

  def startDownloading(login, password, id), do:
    [identity: %{SystemId: login, Password: password}, messageId: id]
    |> request("OpenDownloadingSession") |> parse()

  def uploadChunk(login, password, sessionId, data), do:
    [identity: %{SystemId: login, Password: password}, sessionId: sessionId, messageChunk: data]
    |> request("UploadMessageChunk") |> parse()

  def downloadChunk(login, password, sessionId, pos, count), do:
    [identity: %{SystemId: login, Password: password}, sessionId: sessionId, fromPosition: pos, count: count]
    |> request("DownloadMessageChunk") |> parse()

  def endUploading(login, password, sessionId), do:
    (x = [identity: %{SystemId: login, Password: password}, sessionId: sessionId];
     x |> request("GetMessageValidationInfo") |> parse() |> :maps.merge(x |> request("GetSessionInfo") |> parse()) |> check())

  def endDownloading(login, password, sessionId), do:
    [identity: %{SystemId: login, Password: password}, sessionId: sessionId]
    |> request("GetMessageValidationInfo") |> parse()

  def closeSession(login, password, %{:session => sId, :type => t}, id), do:
    [identity: %{SystemId: login, Password: password},
     sessionInfo: %{MessageId: id, SessionId: sId, Status: "Delivered", Type: t}]
    |> request("EndProcessingDownloadedMessage")

  defp request(body, f), do:
    ({:ok, x} = Soap.init_model(@wsdl); response(f, Soap.call(x, f, {nil, body}, [], [])))

  defp response(_, {:ok, response = %Soap.Response{status_code: 200}}), do:
    Soap.Response.parse(response)
  defp response(f, {:ok, %Soap.Response{body: body, status_code: 500}}), do:
    (%{:faultcode => c, :faultstring => s} = Soap.Response.Parser.parse(body, :fault);
    SEV.UTL.error('~ts 500: ~ts ~ts', [f, c, s]); [])
  defp response(_, {:ok, %Soap.Response{status_code: 503}}), do:
    (SEV.UTL.error('Service Unavailable ~tp', [503]); [])
  defp response(_, {:ok, %Soap.Response{status_code: 504}}), do:
    (SEV.UTL.error('Gateway Timeout ~tp', [504]); [])
  defp response(f, {:ok, %Soap.Response{body: body, status_code: code}}), do:
    (SEV.UTL.error('~ts ~ts: ~tp', [f, code, body]); [])
  defp response(f, response), do:
    (SEV.UTL.error('Action: ~tp ~n Response: ~tp~n', [f, response]); [])

  defp parse(%{:GetInputMessagesResponse => %{:"s01:GetInputMessagesResult" => x}}), do: check(x) |> inputMessages()
  defp parse(%{:GetInputMessagesResponse => _}), do: []
  defp parse(%{:OpenDownloadingSessionResponse => %{:"s01:OpenDownloadingSessionResult" => x}}), do: check(x) |> openDownSession()
  defp parse(%{:DownloadMessageChunkResponse => %{:"s01:DownloadMessageChunkResult" => x}}), do: check(x) |> downloadChunk()
  defp parse(%{:GetMessageValidationInfoResponse => %{:"s01:GetMessageValidationInfoResult" => x}}), do: check(x) |> endSession()
  defp parse(%{:GetSessionInfoResponse => %{:"s01:GetSessionInfoResult" => x}}), do: check(x)
  defp parse(%{:OpenUploadingSessionResponse => %{:"s01:OpenUploadingSessionResult" => x}}), do: check(x) |> openUploadSession()
  defp parse(%{:UploadMessageChunkResponse => %{:"s01:UploadMessageChunkResult" => x}}), do: check(x) |> uploadChunk()
  defp parse(_), do: :erlang.exit(self(), :error)

  defp check(%{:error => c}), do: %{:error => c}
  defp check(%{:Error => %{:Code => c, :Text => t}}), do: (SEV.UTL.error('~ts : ~ts', [c, t]); %{:error => c})
  defp check(x), do: x

  defp uploadChunk(%{:SessionId => sId}), do: %{:session => sId}
  defp uploadChunk(x), do: x

  defp downloadChunk(%{:Session => %{:MaxPartSize => mS}, :MessageChunk => c}), do:
    %{:partSize => mS |> :nitro.to_binary() |> String.to_integer(), :message => c}
  defp downloadChunk(x), do: x

  defp endSession(%{:Hash => x, :Session => %{:SessionId => s, :Type => t}}), do: %{:hash => x, :type => t, :session => s}
  defp endSession(x), do: x

  defp openUploadSession(%{:MaxPartSize => mS, :TransferredBytesCount => bC, :SessionId => sId}), do:
    %{:session => sId, :partSize => mS |> :nitro.to_binary() |> String.to_integer(), :bytesCount => bC |> :nitro.to_binary() |> String.to_integer()}
  defp openUploadSession(x), do: x

  defp openDownSession(%{:SessionId => sId, :MaxPartSize => mS, :MessageSize => s}), do:
    %{:partSize => mS |> :nitro.to_binary() |> String.to_integer(),
      :session => sId,
      :size => s |> :nitro.to_binary() |> String.to_integer()}
  defp openDownSession(x), do: x

  defp inputMessages(%{:MessageInfo => %{:MessageId => _} = x}), do: [MessageInfo: x]
  defp inputMessages([{:MessageInfo, %{:MessageId => _}} | _] = x), do: x
  defp inputMessages(x), do: x

end