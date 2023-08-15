#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#define PLUGIN_VERSION "2.0.0"

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
Handle h_si_spawn_weights[SI_TYPES];
Handle h_si_spawn_size_min;
Handle h_si_spawn_size_per_survivor;
Handle h_si_spawn_time_min;
Handle h_si_spawn_time_limit;
Handle h_si_spawn_time_per_survivor;
Handle h_si_spawn_delay;

int si_limit;
int si_spawn_limits[SI_TYPES];
int si_spawn_weights[SI_TYPES];
int si_spawn_wsum;
int si_spawn_size_min;
int si_spawn_size_max;
int si_spawn_size_per_survivor;
float si_spawn_time_min;
float si_spawn_time_max;
float si_spawn_time_limit;
float si_spawn_time_per_survivor;
float si_spawn_delay;
int alive_survivors;
int si_type_counts[SI_TYPES];
int si_total_count;

//timer
Handle h_spawn_timer;
bool is_spawn_timer_started;

public Plugin myinfo = {
	name = "L4D2 Dynamic SI Spawner",
	author = "Garamond",
	description = "Dynamic special infected spawner",
	version = PLUGIN_VERSION,
	url = "https://github.com/garamond13/L4D2-Dynamic-SI-Spawner"
};

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

	//special infected weights
	h_si_spawn_weights[SI_SMOKER] = CreateConVar("l4d2_dsis_smoker_weight", "100", "The weight for a smoker spawning", FCVAR_NONE, true, 1.0, true, 100.0);
	h_si_spawn_weights[SI_BOOMER] = CreateConVar("l4d2_dsis_boomer_weight", "100", "The weight for a boomer spawning", FCVAR_NONE, true, 1.0, true, 100.0);
	h_si_spawn_weights[SI_HUNTER] = CreateConVar("l4d2_dsis_hunter_weight", "100", "The weight for a hunter spawning", FCVAR_NONE, true, 1.0, true, 100.0);
	h_si_spawn_weights[SI_SPITTER] = CreateConVar("l4d2_dsis_spitter_weight", "100", "The weight for a spitter spawning", FCVAR_NONE, true, 1.0, true, 100.0);
	h_si_spawn_weights[SI_JOCKEY] = CreateConVar("l4d2_dsis_jockey_weight", "100", "The weight for a jockey spawning", FCVAR_NONE, true, 1.0, true, 100.0);
	h_si_spawn_weights[SI_CHARGER] = CreateConVar("l4d2_dsis_charger_weight", "100", "The weight for a charger spawning", FCVAR_NONE, true, 1.0, true, 100.0);
	
	//special infected spawn size
	h_si_spawn_size_min = CreateConVar("l4d2_dsis_spawn_size_min", "1", "The min amount of special infected spawned at each spawn interval", FCVAR_NONE, true, 0.0);
	h_si_spawn_size_per_survivor = CreateConVar("l4d2_dsis_spawn_size_per_survivor", "1", "The amount of special infected being added per alive survivor", FCVAR_NONE, true, 0.0);
	
	//special infected spawn time
	h_si_spawn_time_min = CreateConVar("l4d2_dsis_spawn_time_min", "15.0", "The min auto spawn time (seconds) for special infected", FCVAR_NONE, true, 0.0);
	h_si_spawn_time_limit = CreateConVar("l4d2_dsis_spawn_time_limit", "60.0", "The max auto spawn time (seconds) for special infected", FCVAR_NONE, true, 1.0);
	h_si_spawn_time_per_survivor = CreateConVar("l4d2_dsis_time_per_survivor", "3.0", "The amount of auto spawn time being reduced per alive survivor", FCVAR_NONE, true, 0.0);
	h_si_spawn_delay = CreateConVar("l4d2_dsis_spawn_delay", "0.1", "The delay in seconds for each spawn", FCVAR_NONE, true, 0.1);

	//hook events
	HookEvent("round_end", event_round_end, EventHookMode_Pre);
	HookEvent("map_transition", event_round_end, EventHookMode_Pre);
	HookEvent("player_spawn", survivor_check_on_event);
	HookEvent("player_death", survivor_check_on_event);
	HookEvent("player_left_safe_area", event_player_left_safe_area);

	AutoExecConfig(true, "l4d2_dsis");
}

public void OnConfigsExecuted()
{
	si_limit = GetConVarInt(h_si_limit);
	si_spawn_size_min = GetConVarInt(h_si_spawn_size_min);
	si_spawn_size_per_survivor = GetConVarInt(h_si_spawn_size_per_survivor);
	si_spawn_time_min = GetConVarFloat(h_si_spawn_time_min);
	si_spawn_time_limit = GetConVarFloat(h_si_spawn_time_limit);
	si_spawn_time_per_survivor = GetConVarFloat(h_si_spawn_time_per_survivor);
	si_spawn_delay = GetConVarFloat(h_si_spawn_delay);
	set_si_spawn_limits();
	set_si_spawn_weights();
	disbale_director_spawn_si();
}

void set_si_spawn_limits()
{
	for (int i = 0; i < SI_TYPES; i++)
		si_spawn_limits[i] = GetConVarInt(h_si_spawn_limits[i]);
}

void set_si_spawn_weights()
{
	for (int i = 0; i < SI_TYPES; i++) {
		si_spawn_weights[i] = GetConVarInt(h_si_spawn_weights[i]);
		si_spawn_wsum += si_spawn_weights[i];
	}
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

	start_spawn_timer();
	return Plugin_Continue;
}

public void survivor_check_on_event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS) {

		#if DEBUG
		PrintToConsoleAll("[DSIS] survivor_check_on_event()");
		#endif

		survivor_check();
	}
}

void survivor_check()
{
	alive_survivors = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
			alive_survivors++;
	set_si_spawn_size_max();
	set_si_spawn_time_max();

	#if DEBUG
	PrintToConsoleAll("[DSIS] survivor_check(); alive_survivors = %i; si_spawn_size_max = %i; si_spawn_time_max = %f", alive_survivors, si_spawn_size_max, si_spawn_time_max);
	#endif
}

void set_si_spawn_size_max()
{
    si_spawn_size_max = si_spawn_size_min + si_spawn_size_per_survivor * alive_survivors;
    if (si_spawn_size_max > si_limit)
        si_spawn_size_max = si_limit;
}

void set_si_spawn_time_max()
{
    si_spawn_time_max = si_spawn_time_limit - si_spawn_time_per_survivor * alive_survivors;
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
	if (si_total_count >= si_limit) {
		
		#if DEBUG
		PrintToConsoleAll("[DSIS] spawn_si(); si_total_count = %i; return", si_total_count);
		#endif

		return;
	}

	//set spawn size
	int difference = si_limit - si_total_count;
	int size = si_spawn_size_max > difference ? difference : si_spawn_size_max;
	size = si_spawn_size_min < size ? GetRandomInt(si_spawn_size_min, size) : size;

	#if DEBUG
	PrintToConsoleAll("[DSIS] spawn_si(); si_total_count = %i; size = %i", si_total_count, size);
	#endif

	float delay = si_spawn_delay;
	while (size > 0) {
		int index = get_si_index();

		//break on ivalid index, since get_si_index() has 5 retries to give valid index
		if (index < 0)
			break;
		
		//prevent instant spam of all specials at once
		CreateTimer(delay, z_spawn_old, index, TIMER_FLAG_NO_MAPCHANGE);

		delay += si_spawn_delay;
		size--;
	}
}

void count_si()
{
	//reset counts
	si_total_count = 0;
	for (int i = 0; i < SI_TYPES; i++)
		si_type_counts[i] = 0;

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED) {

			//detect special infected type by zombie class
			switch (GetEntProp(i, Prop_Send, "m_zombieClass")) {
				case SI_CLASS_SMOKER: {
					si_type_counts[SI_SMOKER]++;
					si_total_count++;
				}
				case SI_CLASS_BOOMER: {
					si_type_counts[SI_BOOMER]++;
					si_total_count++;
				}
				case SI_CLASS_HUNTER: {
					si_type_counts[SI_HUNTER]++;
					si_total_count++;
				}
				case SI_CLASS_SPITTER: {
					si_type_counts[SI_SPITTER]++;
					si_total_count++;
				}
				case SI_CLASS_JOCKEY: {
					si_type_counts[SI_JOCKEY]++;
					si_total_count++;
				}
				case SI_CLASS_CHARGER: {
					si_type_counts[SI_CHARGER]++;
					si_total_count++;
				}
			}
		}
	}
}

//get random index
int get_si_index()
{
	int retries = 5;
	while (retries > 0) {
		int tmp_wsum = 0;
		int index = GetRandomInt(1, si_spawn_wsum);
		
		#if DEBUG
		PrintToConsoleAll("[DSIS] get_si_index(); GetRandomInt() = %i", index);
		#endif
		
		//cycle trough weight ranges, find where random index falls and pick appropriate array index
		for (int i = 0; i < SI_TYPES; i++) {
			tmp_wsum += si_spawn_weights[i];
			if (index <= tmp_wsum) {
				index = i;
				break;
			}
		}

		#if DEBUG
		PrintToConsoleAll("[DSIS] get_si_index(); tmp_wsum = %i; si_spawn_wsum = %i; index = %i", tmp_wsum, si_spawn_wsum, index);
		#endif

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
	int client = get_random_alive_survivor();

	#if DEBUG
	PrintToConsoleAll("[DSIS] z_spawn_old(); client = %i", client);
	#endif
	
	//early return on invalid client
	if (!client)
		return Plugin_Continue;
	
	//create infected bot
	int bot = CreateFakeClient("Infected Bot");
	if (bot) {
		ChangeClientTeam(bot, TEAM_INFECTED);
		CreateTimer(0.1, kick_bot, bot, TIMER_FLAG_NO_MAPCHANGE);
	}

	//store command flags
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

int get_random_alive_survivor()
{
	if (alive_survivors) {
		int[] clients = new int[alive_survivors];
		int index = 0;
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
				clients[index++] = i;
		return clients[GetRandomInt(0, alive_survivors - 1)];
	}
	return 0;
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
