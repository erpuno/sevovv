-ifndef(NITRO_CX).
-define(NITRO_CX, true).

-record(cx, { handlers=[], actions=[], req=[], module=[], lang=[], path=[],
              session=[], token=[], formatter=bert, params=[], node=[],
              client_pid=[], state=[], from=[], vsn = [] }).

-endif.
