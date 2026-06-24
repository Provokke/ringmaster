-module(ringmaster_server).
-behaviour(gen_server).

-export([start_link/0, start_link/1, stop/1, add/2, remove/2, nodes/1, lookup/2, replicas/3]).
-export([init/1, handle_call/3, handle_cast/2]).

start_link() -> start_link(128).

start_link(VNodes) -> gen_server:start_link(?MODULE, VNodes, []).

stop(Server) -> gen_server:stop(Server).

add(Server, Node) -> gen_server:call(Server, {add, Node}).

remove(Server, Node) -> gen_server:call(Server, {remove, Node}).

nodes(Server) -> gen_server:call(Server, nodes).

lookup(Server, Key) -> gen_server:call(Server, {lookup, Key}).

replicas(Server, Key, N) -> gen_server:call(Server, {replicas, Key, N}).

init(VNodes) -> {ok, ringmaster_ring:new(VNodes)}.

handle_call({add, Node}, _From, Ring) ->
    {reply, ok, ringmaster_ring:add(Node, Ring)};
handle_call({remove, Node}, _From, Ring) ->
    {reply, ok, ringmaster_ring:remove(Node, Ring)};
handle_call(nodes, _From, Ring) ->
    {reply, ringmaster_ring:nodes(Ring), Ring};
handle_call({lookup, Key}, _From, Ring) ->
    {reply, ringmaster_ring:lookup(Key, Ring), Ring};
handle_call({replicas, Key, N}, _From, Ring) ->
    {reply, ringmaster_ring:replicas(Key, N, Ring), Ring}.

handle_cast(_Msg, Ring) -> {noreply, Ring}.
