#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.0"

#define DEBUG 0

//teams
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

//zombie classes
#define SI_CLASS_SMOKER 1
#define SI_CLASS_BOOMER 2
#define SI_CLASS_HUNTER 3
#define SI_CLASS_SPITTER 4
#define SI_CLASS_JOCKEY 5
#define SI_CLASS_CHARGER 6

//special infected types (for indexing), keep same order as zombie classes
#define SI_TYPES 6
#define SI_SMOKER 0
#define SI_BOOMER 1
#define SI_HUNTER 2
#define SI_SPITTER 3
#define SI_JOCKEY 4
#define SI_CHARGER 5

//keep same order as zombie classes
char z_spawns[SI_TYPES][16] = { "smoker auto", "boomer auto", "hunter auto", "spitter auto", "jockey auto", "charger auto" };

//convar handles
Handle h_si_limit;
Handle h_si_spawn_limits[SI_TYPES];
Handle h_si_spawn_size_min;
Handle h_si_spawn_size_per_player;
Handle h_si_spawn_time_min;
Handle h_si_spawn_time_limit;
Handle h_si_spawn_time_per_player;

int si_limit;
int si_spawn_limits[SI_TYPES];
int si_spawn_size_min;
int si_spawn_size_max;
int si_spawn_size_per_player;
float si_spawn_time_min;
float si_spawn_time_max;
float si_spawn_time_limit;
float si_spawn_time_per_player;
int alive_players;
int si_type_counts[SI_TYPES];
int si_total_count;

//timer
Handle h_spawn_timer;
bool is_spawn_timer_started;

public Plugin myinfo =  
{
	name = "L4D2 Dynamic SI Spawner",
	author = "Garamond",
	description = "Dynamic special infected spawner",
	version = PLUGIN_VERSION,
	url = "https://github.com/garamond13/L4D2-Dynamic-SI-Spawner"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{	
	if(GetEngineVersion() != Engine_Left4Dead2) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success; 
}

public void OnPluginStart()
{
	h_si_limit = CreateConVar("l4d2_dsis_limit", "8", "The max amount of special infected present at once", FCVAR_NONE, true, 1.0);
	
	//special infected limits
	h_si_spawn_limits[SI_SMOKER] = CreateConVar("l4d2_dsis_smoker_limit", "1", "The max amount of smokers present at once", FCVAR_NONE, true, 0.0);
	h_si_spawn_limits[SI_BOOMER] = CreateConVar("l4d2_dsis_boomer_limit", "1", "The max amount of boomers present at once", FCVAR_NONE, true, 0.0);
	h_si_spawn_limits[SI_HUNTER] = CreateConVar("l4d2_dsis_hunter_limit", "1", "The max amount of hunters present at once", FCVAR_NONE, true, 0.0);
	h_si_spawn_limits[SI_SPITTER] = CreateConVar("l4d2_dsis_spitter_limit", "1", "The max amount of spitters present at once", FCVAR_NONE, true, 0.0);
	h_si_spawn_limits[SI_JOCKEY] = CreateConVar("l4d2_dsis_jockey_limit", "1", "The max amount of jockeys present at once", FCVAR_NONE, true, 0.0);
	h_si_spawn_limits[SI_CHARGER] = CreateConVar("l4d2_dsis_charger_limit", "1", "The max amount of chargers present at once", FCVAR_NONE, true, 0.0);
	
	//special infected spawn size
	h_si_spawn_size_min = CreateConVar("l4d2_dsis_spawn_size_min", "1", "The min amount of special infected spawned at each spawn interval", FCVAR_NONE, true, 0.0);
	h_si_spawn_size_per_player = CreateConVar("l4d2_dsis_spawn_size_per_player", "1", "The amount of special infected being added per alive player", FCVAR_NONE, true, 0.0);
	
	//special infected spawn time
	h_si_spawn_time_min = CreateConVar("l4d2_dsis_spawn_time_min", "15.0", "The min auto spawn time (seconds) for special infected", FCVAR_NONE, true, 0.0);
	h_si_spawn_time_limit = CreateConVar("l4d2_dsis_spawn_time_limit", "60.0", "The max auto spawn time (seconds) for special infected", FCVAR_NONE, true, 1.0);
	h_si_spawn_time_per_player = CreateConVar("l4d2_dsis_time_per_player", "3.0", "The amount of auto spawn time being reduced per alive player", FCVAR_NONE, true, 0.0);

	//hook events
	HookEvent("round_end", event_round_end, EventHookMode_Pre);
	HookEvent("map_transition", event_round_end, EventHookMode_Pre);
	HookEvent("player_death", player_check_on_event);
	HookEvent("player_left_safe_area", event_player_left_safe_area);

	AutoExecConfig(true, "l4d2_dsis");
}

public void OnConfigsExecuted()
{
	si_limit = GetConVarInt(h_si_limit);
	si_spawn_size_min = GetConVarInt(h_si_spawn_size_min);
	si_spawn_size_per_player = GetConVarInt(h_si_spawn_size_per_player);
	si_spawn_time_min = GetConVarFloat(h_si_spawn_time_min);
	si_spawn_time_limit = GetConVarFloat(h_si_spawn_time_limit);
	si_spawn_time_per_player = GetConVarFloat(h_si_spawn_time_per_player);
	set_si_spawn_limits();
	disbale_director_spawn_si();
}

void set_si_spawn_limits()
{
	for (int i = 0; i < SI_TYPES; ++i)
		si_spawn_limits[i] = GetConVarInt(h_si_spawn_limits[i]);
}

void disbale_director_spawn_si()
{
	SetConVarInt(FindConVar("z_smoker_limit"), 0);
	SetConVarInt(FindConVar("z_boomer_limit"), 0);
	SetConVarInt(FindConVar("z_hunter_limit"), 0);
	SetConVarInt(FindConVar("z_spitter_limit"), 0);
	SetConVarInt(FindConVar("z_jockey_limit"), 0);
	SetConVarInt(FindConVar("z_charger_limit"), 0);
}

public Action event_player_left_safe_area(Event event, const char[] name, bool dontBroadcast)
{
	#if DEBUG
	PrintToConsoleAll("[DSIS] event_player_left_safe_area()");
	#endif

	player_check();
	start_spawn_timer();
	return Plugin_Continue;
}

public void player_check_on_event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS) {

		#if DEBUG
		PrintToConsoleAll("[DSIS] player_check_on_event()");
		#endif

		player_check();
	}
}

void player_check()
{
	alive_players = 0;
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
			alive_players++;
	set_si_spawn_size_max();
	set_si_spawn_time_max();

	#if DEBUG
	PrintToConsoleAll("[DSIS] player_check(); alive_players = %i; si_spawn_size_max = %i; si_spawn_time_max = %f", alive_players, si_spawn_size_max, si_spawn_time_max);
	#endif
}

void set_si_spawn_size_max()
{
    si_spawn_size_max = si_spawn_size_min + si_spawn_size_per_player * alive_players;
    if (si_spawn_size_max > si_limit)
        si_spawn_size_max = si_limit;
}

void set_si_spawn_time_max()
{
    si_spawn_time_max = si_spawn_time_limit - si_spawn_time_per_player * alive_players;
    if (si_spawn_time_max < si_spawn_time_min)
        si_spawn_time_max = si_spawn_time_min;
}

void start_spawn_timer()
{
	end_spawn_timer();
	float timer = GetRandomFloat(si_spawn_time_min, si_spawn_time_max);
	h_spawn_timer = CreateTimer(timer, auto_spawn_si);
	is_spawn_timer_started = true;
	
	#if DEBUG
	PrintToConsoleAll("[DSIS] start_spawn_timer(); si_spawn_time_min = %f; si_spawn_time_max = %f; timer = %f", si_spawn_time_min, si_spawn_time_max, timer);
	#endif
}

void end_spawn_timer()
{
	if (is_spawn_timer_started) {
		CloseHandle(h_spawn_timer);
		is_spawn_timer_started = false;
	}
}

//gets called by start_spawn_timer()
public Action auto_spawn_si(Handle timer)
{
	is_spawn_timer_started = false;
	spawn_si();
	start_spawn_timer();
	return Plugin_Continue;
}

void spawn_si()
{   
	count_si();

	//early return if limit is reached
	if (si_total_count >= si_limit)
		return;

	//set spawn size
	int size;
	if (si_spawn_size_max > si_limit - si_total_count)
		size = si_limit - si_total_count;
	else
		size = si_spawn_size_max;
	size = GetRandomInt(si_spawn_size_min, size);

	#if DEBUG
	PrintToConsoleAll("[DSIS] spawn_si(); si_total_count = %i; size = %i", si_total_count, size);
	#endif

	while (size > 0) {
		int index = get_si_index();

		//break on ivalid index, since get_si_index() has 5 retries to give valid index
		if (index < 0)
			break;
		
		//prevent instant spam of all specials at once
		CreateTimer(GetRandomFloat(0.1, 1.6), z_spawn_old, index);

		size--;
	}
}

void count_si()
{
	for (int i = 0; i < SI_TYPES; ++i)
		si_type_counts[i] = 0;
	for (int i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED) {

			//detect special infected type by zombie class
			switch (GetEntProp(i, Prop_Send, "m_zombieClass")) {
				case SI_CLASS_SMOKER:
					si_type_counts[SI_SMOKER]++;
				case SI_CLASS_BOOMER:
					si_type_counts[SI_BOOMER]++;
				case SI_CLASS_HUNTER:
					si_type_counts[SI_HUNTER]++;
				case SI_CLASS_SPITTER:
					si_type_counts[SI_SPITTER]++;
				case SI_CLASS_JOCKEY:
					si_type_counts[SI_JOCKEY]++;
				case SI_CLASS_CHARGER:
					si_type_counts[SI_CHARGER]++;
			}
		}
	}
	si_total_count = 0;
	for (int i = 0; i < SI_TYPES; ++i)
		si_total_count += si_type_counts[i];
}

//get random index
int get_si_index()
{
	int retries = 5;
	while (retries > 0) {
		int index = GetRandomInt(0, SI_TYPES - 1);
		if (si_type_counts[index] < si_spawn_limits[index]) {
			si_type_counts[index]++;
			return index;
		}
		retries--;
	}
	return -1;
}

public Action z_spawn_old(Handle timer, any data)
{	
	int client = get_any_client();
	
	//early return on invalid client
	if (!client)
		return Plugin_Continue;
	
	create_infected_bot();
	int flags = GetCommandFlags("z_spawn_old");

	//remove sv_cheat flag from command
	SetCommandFlags("z_spawn_old", flags & ~FCVAR_CHEAT);

	FakeClientCommand(client, "%s %s", "z_spawn_old", z_spawns[data]);
	
	//restore command flags
	SetCommandFlags("z_spawn_old", flags);

	#if DEBUG
	PrintToConsoleAll("[DSIS] z_spawn_old(); z_spawns[%i] = %s", data, z_spawns[data]);
	#endif

	return Plugin_Continue;
}

int get_any_client()
{
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i))
			return i;
	return 0;
}

void create_infected_bot()
{
	int bot = CreateFakeClient("Infected Bot");
	if (bot) {
		ChangeClientTeam(bot, TEAM_INFECTED);
		CreateTimer(0.1, kick_bot, bot);
	}
}

public Action kick_bot(Handle timer, any data)
{
	if (IsClientInGame(data) && !IsClientInKickQueue(data) && IsFakeClient(data))
		KickClient(data);
	return Plugin_Continue;
}

public Action event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	end_spawn_timer();
	return Plugin_Continue;
}

public void OnMapEnd()
{
	end_spawn_timer();
}
