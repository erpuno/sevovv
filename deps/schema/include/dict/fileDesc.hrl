-ifndef(FILE_DESC_HRL).
-define(FILE_DESC_HRL, true).

-include_lib("crm/include/erp/catalogs/employee.hrl").

-record('fileDesc', { id = [] :: [] | binary() | list(),
                      seq_id = [] :: list() | binary(),
                      parent_id = [] :: [] | binary() | list(),
                      desc = [] :: list(),
                      fileName = [] :: list(),
                      created = [] :: [] | tuple(),
                      loaded = [] :: [] | tuple(),
                      signed = none :: none | tuple(),
                      creator = [] :: [] | #'Employee'{},
                      lastModified = [] :: [] | tuple(),
                      lastModifier = [] :: [] | #'Employee'{},
                      hash = [] :: binary() | list(),
                      signature = [] :: binary() | list(),
                      size = [] :: [] | integer(),
                      mime = [] :: [] | binary() | list(),
                      type = [] :: [] | binary(),
                      needSign = false :: atom(),
                      template = [] :: [] | binary(),
                      signInfo = [] :: [] | list(),
                      needCertification = false :: false | atom(),
                      certificate = [] :: [] | tuple(),
                      main = false :: false | atom()
                      }).

-endif.
