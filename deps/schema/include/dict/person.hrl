-ifndef(PERSON_HRL).
-define(PERSON_HRL, true).

-include("dict/location.hrl").
-include("dict/organization.hrl").

% LDAP inetOrgPerson OID=2.16.840.1.113730.3.2.2

-record('Person',      { id          = kvs:seq([],[]) :: [] | term(),
                         cn          = [] :: [] | binary(),
                         name        = [] :: [] | binary(),
                         displayName = [] :: [] | binary(),
                         location    = [] :: #'Loc'{},
                         hours       = 00 :: integer(),
                         type        = [] :: term() }).

-record('PersonCN',    { cn          = [] :: [] | term(),
                         id          = [] :: [] | term() }).

-endif.
