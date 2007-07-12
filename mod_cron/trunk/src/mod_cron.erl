%%%----------------------------------------------------------------------
%%% File    : mod_cron.erl
%%% Author  : Badlop
%%% Purpose : Execute scheduled tasks
%%% Created : 12 July 2007
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(mod_cron).
-author('').
-vsn('$Revision$').

-behaviour(gen_mod).

-export([
	ctl_process/3,
	start/2, 
	stop/1]).

-include("ejabberd_ctl.hrl").

-record(task, {taskid, timerref, host, task}).


%% ---------------------
%% gen_mod 
%% ---------------------

start(Host, Opts) -> 
    ejabberd_ctl:register_commands(Host, command_list(), ?MODULE, ctl_process),
    Tasks = gen_mod:get_opt(tasks, Opts, []),
    catch ets:new(cron_tasks, [ordered_set, named_table, public, {keypos, 2}]),
	[add_task(Host, Task) || Task <- Tasks].

stop(Host) ->
    ejabberd_ctl:unregister_commands(Host, command_list(), ?MODULE, ctl_process),
	% Delete tasks of this host
	[delete_task(Task) || Task <- get_tasks(Host)].


%% ---------------------
%% Task management 
%% ---------------------

% Method to add new task
add_task(Host, Task) ->
	{Time_num, Time_unit, Mod, Fun, Args} = Task,

	% Convert to miliseconds
	Time = case Time_unit of
		seconds -> timer:seconds(Time_num);
		minutes -> timer:minutes(Time_num);
		hours -> timer:hours(Time_num);
		days -> timer:hours(Time_num)*24
	end,

	% Start timer
	{ok, TimerRef} = timer:apply_interval(Time, Mod, Fun, Args),

	% Get new task identifier
	TaskId = get_new_taskid(),

	% Store TRef
	Taskr = #task{
		taskid = TaskId,
		timerref = TimerRef,
		host = Host,
		task = Task
	},

	ets:insert(cron_tasks, Taskr).

get_new_taskid() ->
	case ets:last(cron_tasks) of
		'$end_of_table' -> 0;
		Id -> Id + 1
	end.

% Method to delete task, given a taskid
delete_taskid(TaskId) ->
	[Task] = ets:lookup(cron_tasks, TaskId),
	delete_task(Task).

% Method to delete task, given the whole task
delete_task(Task) ->
	timer:cancel(Task#task.timerref),
	ets:delete(cron_tasks, Task#task.taskid).

% Method to know existing tasks on a given host
get_tasks(Host) ->
	ets:select(cron_tasks, [{#task{host = Host, _ = '_'}, [], ['$_']}]).

% Method to know taskids of existing tasks on a given host
%get_tasks_ids(Host) ->
%	L = ets:match(cron_tasks, #task{host = Host, taskid = '$1', _ = '_'}),
%	[Id || [Id] <- L].


%% ---------------------
%% Commands 
%% ---------------------

command_list() ->
	[
		{"cron-list", "list scheduled tasks"},
		{"cron-del taskid", "delete this task from the schedule"}
	].

ctl_process(_Val, Host, ["cron-list"]) ->
	Tasks = get_tasks(Host),
    [io:format("~p ~p~n", [T#task.taskid, T#task.task]) || T <- Tasks],
    ?STATUS_SUCCESS;

ctl_process(_Val, _Host, ["cron-del", TaskId_string]) ->
	TaskId = list_to_integer(TaskId_string),
    Result = delete_taskid(TaskId),
	io:format("~p~n", [Result]),
    ?STATUS_SUCCESS;

ctl_process(Val, _Host, _Args) ->
	Val.
