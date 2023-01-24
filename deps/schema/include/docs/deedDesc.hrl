-ifndef(DEED_DESC_HRL).
-define(DEED_DESC_HRL, true).

-record(deedDesc, { id= [] :: binary(),
                    guid= [] :: list(),
                    date = [] :: [] | calendar:datetime(),
                    xml = [] :: [] | binary(),
                    hash = [] :: binary() | list(),
                    signature = [] :: binary() | list(),
                    dueDate = [] :: [] | calendar:datetime(),
                    document_type = <<"Акт про вилучення"/utf8>> :: term(),
                    branch = [] :: term(),
                    category = [] :: term(),
                    parent = [] :: term(),
                    registered_by=[] :: [] | #'Person'{},
                    attachments = [] :: list(term()),
                    proc_id = [] :: list()
                }).

-endif.