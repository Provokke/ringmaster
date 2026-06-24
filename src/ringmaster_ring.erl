-module(ringmaster_ring).

-export([new/0, new/1, add/2, remove/2, nodes/1, lookup/2, replicas/3, size/1, hash/1]).

-define(DEFAULT_VNODES, 128).

-record(ring, {vnodes = ?DEFAULT_VNODES :: pos_integer(),
               members = [] :: [term()],
               points = [] :: [{non_neg_integer(), term()}]}).

-opaque ring() :: #ring{}.
-export_type([ring/0]).

-spec new() -> ring().
new() -> new(?DEFAULT_VNODES).

-spec new(pos_integer()) -> ring().
new(VNodes) when is_integer(VNodes), VNodes > 0 ->
    #ring{vnodes = VNodes}.

-spec add(term(), ring()) -> ring().
add(Node, #ring{members = Members} = Ring) ->
    case lists:member(Node, Members) of
        true -> Ring;
        false -> rebuild(Ring#ring{members = [Node | Members]})
    end.

-spec remove(term(), ring()) -> ring().
remove(Node, #ring{members = Members} = Ring) ->
    rebuild(Ring#ring{members = lists:delete(Node, Members)}).

-spec nodes(ring()) -> [term()].
nodes(#ring{members = Members}) -> lists:sort(Members).

-spec size(ring()) -> non_neg_integer().
size(#ring{members = Members}) -> length(Members).

-spec lookup(term(), ring()) -> {ok, term()} | {error, empty}.
lookup(Key, Ring) ->
    case replicas(Key, 1, Ring) of
        [Node] -> {ok, Node};
        [] -> {error, empty}
    end.

-spec replicas(term(), non_neg_integer(), ring()) -> [term()].
replicas(_Key, _N, #ring{points = []}) ->
    [];
replicas(Key, N, #ring{points = Points, members = Members}) ->
    Wanted = min(N, length(Members)),
    Start = hash(Key),
    {Before, From} = lists:splitwith(fun({P, _}) -> P < Start end, Points),
    collect(From ++ Before, Wanted, []).

-spec hash(term()) -> non_neg_integer().
hash(Term) ->
    <<Value:32, _/binary>> = crypto:hash(md5, term_to_binary(Term)),
    Value.

collect(_Points, 0, Acc) ->
    lists:reverse(Acc);
collect([], _Wanted, Acc) ->
    lists:reverse(Acc);
collect([{_, Node} | Rest], Wanted, Acc) ->
    case lists:member(Node, Acc) of
        true -> collect(Rest, Wanted, Acc);
        false -> collect(Rest, Wanted - 1, [Node | Acc])
    end.

rebuild(#ring{vnodes = VNodes, members = Members} = Ring) ->
    Points = [{hash({Node, I}), Node} || Node <- Members, I <- lists:seq(1, VNodes)],
    Ring#ring{points = lists:sort(Points)}.
