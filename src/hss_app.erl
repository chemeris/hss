%%% $Id: hss_app.erl,v 1.5 2008/02/18 05:34:31 vances Exp $
%%%---------------------------------------------------------------------
%%% @copyright 2008 Motivity Telecom Inc.
%%% @author Vance Shipley <vances@motivity.ca> [http://www.motivity.ca]
%%% @end
%%%
%%% Copyright (c) 2008, Motivity Telecom Inc.
%%% 
%%% All rights reserved.
%%% 
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions
%%% are met:
%%% 
%%%    - Redistributions of source code must retain the above copyright
%%%      notice, this list of conditions and the following disclaimer.
%%%    - Redistributions in binary form must reproduce the above copyright
%%%      notice, this list of conditions and the following disclaimer in
%%%      the documentation and/or other materials provided with the 
%%%      distribution.
%%%    - Neither the name of Motivity Telecom  nor the names of its
%%%      contributors may be used to endorse or promote products derived
%%%      from this software without specific prior written permission.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
%%% A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
%%% OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%%% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
%%% LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
%%% DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
%%% THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
%%% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
%%% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%%%
%%%---------------------------------------------------------------------
%%% @doc This {@link //stdlib/application. <tt>application</tt>} 
%%% 		behaviour callback module implements the start functions for
%%% 		the <tt>hss</tt> application.
%%%
-module(hss_app).
-copyright('Copyright (c) 2008 Motivity Telecom Inc.').
-author('vances@motivity.ca').
-vsn('$Revision: 1.5 $').

-behaviour(application).

%% call backs needed for application behaviour
-export([start/2, prep_stop/1, stop/1, config_change/3]).

-include("subscriber_data.hrl").

-define(WAITFORSCHEMA, 10000).
-define(WAITFORTABLES,  10000).

-record(state, {}).

%%----------------------------------------------------------------------
%%  The hss_app aplication call backs
%%----------------------------------------------------------------------

%% @spec (StartType, StartArgs) -> {ok, Pid, state()}
%% 	StartType = normal | {takeover, Node} | {failover, Node}
%% 	StartArgs = []
%% 	Node = node()
%% 	Pid = pid()
%%
%% @doc Starts the application.
%% @private
%%
start(_StartType = normal, _StartArgs) ->
	try
		case mnesia:wait_for_tables([schema], ?WAITFORSCHEMA) of
			ok ->
				ok;
			SchemaResult->
				throw(SchemaResult)
		end,
		Tables = [subscriber, user, address, profile, filter, trigger],
		case mnesia:wait_for_tables(Tables, ?WAITFORTABLES) of
			ok ->
				supervisor:start_link({local, hss_sup}, hss_sup, []);
			{timeout, RemainingTabs} ->
				force(RemainingTabs);
			TablesResult->
				throw(TablesResult)
		end
	of
		{ok, Supervisor} ->
			{ok, Supervisor, #state{}}
	catch
		throw:Error ->
			error_logger:error_report(mnesia:error_description(Error)),
			Error
	end;
start({takeover, _Node}, _StartArgs) ->
	{error, not_implemented};
start({failover, _Node}, _StartArgs) ->
	{error, not_implemented}.

%% @spec (State::state()) -> state()
%%
%% @doc Called when the application is about to be shut down,
%% 		before any processes are terminated.
%% @private
%%
prep_stop(State = #state{}) ->
	State.

%% @spec (State::state()) -> ok
%%
%% @doc Called when the application is about to be shut down,
%% 		before any processes are terminated.
%% @private
%%
stop(_State = #state{}) ->
	ok.

%% @spec (Changed, New, Removed) -> ok
%% 	Changed = [{Par, Val}]
%% 	New = [{Par, Val}]
%%	Removed = [Par]
%% 	Par = atom()
%% 	Val = term()
%%
%% @doc Called after a code  replacement, if there are any 
%% 		changes to the configuration  parameters.
%% @private
%%
config_change(_Changed, _New, _Removed) -> ok.

%%----------------------------------------------------------------------
%%  internal functions
%%----------------------------------------------------------------------

%% @spec (Tables) -> ok
%% 	Tables = [atom()]
%%
%% @doc Force load the list of tables.
%% @hidden
%%
force([H|T]) ->
	error_logger:info_msg("Forcing load of ~w table from disk ...", [H]),
	case mnesia:force_load_table(H) of
		yes ->
			force(T);
		Error ->
			error_logger:error_report(mnesia:error_description(Error)),
			throw(Error)
	end;
force([]) ->
	ok.
	
