-ifndef(INTERNAL_DOC_HRL).
-define(INTERNAL_DOC_HRL, true).

-include("dict/project.hrl").
-include("dict/person.hrl").

-record(internalDoc, { id= [] :: binary(),
                       guid= [] :: list(),
                       urgent=[] :: [] | boolean(),
                       date=[] :: [] | calendar:datetime(),
                       xml = [] :: [] | binary(),
                       hash = [] :: binary() | list(),
                       signature = [] :: binary() | list(),
                       document_type = [] :: tuple(),
                       nomenclature=[] :: term(),
                       executor=[] :: [] | #'Person'{},
                       approvers = [] :: list(#'Person'{}),
                       branch=[] :: [] | list(),
                       head=[] :: [] | #'Person'{},
                       content=[] :: term(),
                       signatory=[] :: [] | list(#'Person'{}),
                       target=[] :: [] | #'Person'{},
                       note=[] :: list(),
                       attachments = [] :: list(term()),
                       registered_by=[] :: [] | #'Person'{},
                       project = [] :: [] | #project{},
                       seq_id = [] :: list(),
                       created_by = [] :: term(),
                       created = [] :: term(),
                       modified_by = [] :: term(),
                       modified = [] :: term(),
                       template = [] :: term(),
                       bizTask_initiator = [] :: term(),
                       toAttention = []
                      }).

-endif.
