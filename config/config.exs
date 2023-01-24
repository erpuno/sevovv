use Mix.Config

config :bpe,
  ttl: :infinity,
  ping_discipline: :undefined,
  shutdown_timeout: 20000,
  timeout: 30000,
  procmodules: [
    :bpe_account,
  ],
  logger_level: :error,
  logger: [
    {:handler, :synrc, :logger_std_h,
     %{
       level: :debug,
       id: :synrc,
       max_size: 2000,
       module: :logger_std_h,
       config: %{type: :file, file: 'sev.log'},
       formatter:
         {:logger_formatter,
          %{
            template: [:time, ' ', :pid, ' ', :module, ' ', :msg, '\n'],
            single_line: true
          }}
     }}
  ]

config :kvs,
  dba: :kvs_rocks,
  dba_st: :kvs_st,
  dba_seq: :kvs_mnesia,
  seq_pad: [:doclink, :process, :monitor],
  schema: [:kvs, :kvs_stream, :bpe_metainfo, :erp, :"Elixir.SEV.Listener"]

config :soa, :globals, version: "1.1"

