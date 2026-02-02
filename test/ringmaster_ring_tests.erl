-module(ringmaster_ring_tests).
-include_lib("eunit/include/eunit.hrl").

ring_of(Nodes) ->
    lists:foldl(fun ringmaster_ring:add/2, ringmaster_ring:new(), Nodes).

empty_ring_test() ->
    ?assertEqual({error, empty}, ringmaster_ring:lookup(<<"k">>, ringmaster_ring:new())),
    ?assertEqual([], ringmaster_ring:replicas(<<"k">>, 3, ringmaster_ring:new())).

lookup_is_stable_test() ->
    Ring = ring_of([a, b, c]),
    {ok, First} = ringmaster_ring:lookup(<<"user:7">>, Ring),
    ?assertEqual({ok, First}, ringmaster_ring:lookup(<<"user:7">>, Ring)).

add_is_idempotent_test() ->
    Ring = ring_of([a, b]),
    ?assertEqual(Ring, ringmaster_ring:add(a, Ring)).

remove_test() ->
    Ring = ringmaster_ring:remove(b, ring_of([a, b, c])),
    ?assertEqual([a, c], ringmaster_ring:nodes(Ring)),
    Owners = [element(2, ringmaster_ring:lookup(K, Ring)) || K <- lists:seq(1, 200)],
    ?assertNot(lists:member(b, Owners)).

replicas_are_distinct_test() ->
    Ring = ring_of([a, b, c, d]),
    Reps = ringmaster_ring:replicas(<<"key">>, 3, Ring),
    ?assertEqual(3, length(Reps)),
    ?assertEqual(3, length(lists:usort(Reps))),
    ?assertEqual({ok, hd(Reps)}, ringmaster_ring:lookup(<<"key">>, Ring)).

replicas_capped_by_members_test() ->
    Ring = ring_of([a, b]),
    ?assertEqual(2, length(ringmaster_ring:replicas(<<"key">>, 5, Ring))).

removal_moves_only_removed_keys_test() ->
    Before = ring_of([a, b, c, d]),
    After = ringmaster_ring:remove(d, Before),
    Moved = [K || K <- lists:seq(1, 2000),
                  begin
                      {ok, O1} = ringmaster_ring:lookup(K, Before),
                      {ok, O2} = ringmaster_ring:lookup(K, After),
                      O1 =/= O2 andalso O1 =/= d
                  end],
    ?assertEqual([], Moved).

distribution_balance_test() ->
    Nodes = [n1, n2, n3, n4, n5],
    Ring = ring_of(Nodes),
    Keys = 20000,
    Counts = lists:foldl(
        fun(K, Acc) ->
            {ok, N} = ringmaster_ring:lookup({key, K}, Ring),
            maps:update_with(N, fun(C) -> C + 1 end, 1, Acc)
        end, #{}, lists:seq(1, Keys)),
    Ideal = Keys / length(Nodes),
    lists:foreach(
        fun(N) ->
            Count = maps:get(N, Counts, 0),
            ?assert(Count > Ideal * 0.7),
            ?assert(Count < Ideal * 1.3)
        end, Nodes).
