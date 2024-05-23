#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define VERSION "4.0.3"

#define DEBUG 0

// Teams
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

// Zombie classes
#define ZOMBIE_CLASS_SMOKER 1
#define ZOMBIE_CLASS_BOOMER 2
#define ZOMBIE_CLASS_HUNTER 3
#define ZOMBIE_CLASS_SPITTER 4
#define ZOMBIE_CLASS_JOCKEY 5
#define ZOMBIE_CLASS_CHARGER 6
#define ZOMBIE_CLASS_TANK 8

// Special infected types (for indexing).
// Keep the same order as zombie classes.
#define SI_TYPES 6
#define SI_INDEX_SMOKER 0
#define SI_INDEX_BOOMER 1
#define SI_INDEX_HUNTER 2
#define SI_INDEX_SPITTER 3
#define SI_INDEX_JOCKEY 4
#define SI_INDEX_CHARGER 5

// Keep the same order as zombie classes.
static const char z_spawns[SI_TYPES][] = { "z_spawn_old smoker auto", "z_spawn_old boomer auto", "z_spawn_old hunter auto", "z_spawn_old spitter auto", "z_spawn_old jockey auto", "z_spawn_old charger auto" };

#if DEBUG
// Keep the same order as zombie classes.
static const char debug_si_indexes[SI_TYPES][] = { "SI_INDEX_SMOKER", "SI_INDEX_BOOMER", "SI_INDEX_HUNTER", "SI_INDEX_SPITTER", "SI_INDEX_JOCKEY", "SI_INDEX_CHARGER" };
#endif

static const char z_spawn_old[] = "z_spawn_old";

// Convar handles
Handle h_si_spawn_limits[SI_TYPES];
Handle h_si_spawn_weights[SI_TYPES];
Handle h_si_spawn_weight_mods[SI_TYPES];
Handle h_si_spawn_sizes_min;
Handle h_si_spawn_sizes_max;
Handle h_si_spawn_times_min;
Handle h_si_spawn_times_max;
Handle h_si_spawn_delay_min;
Handle h_si_spawn_delay_max;
Handle h_count_tanks;

// Convar data
int si_spawn_limits[SI_TYPES];
int si_spawn_weights[SI_TYPES];
float si_spawn_weight_mods[SI_TYPES];
int si_spawn_sizes_min[8];
int si_spawn_sizes_max[8];
float si_spawn_times_min[8];
float si_spawn_times_max[8];
float si_spawn_delay_min;
float si_spawn_delay_max;
bool count_tanks;

// Spawn timer
Handle h_spawn_timer;
bool is_spawn_timer_running;

// Used as array index.
int alive_survivors;

// Used by GetVScriptOutput().
ConVar gCvarBuffer;

public Plugin myinfo = {
	name = "L4D2 Dynamic SI Spawner",
	author = "Garamond",
	description = "Dynamic special infected spawner",
	version = VERSION,
	url = "https://github.com/garamond13/L4D2-Dynamic-SI-Spawner"
};

public void OnPluginStart()
{	
	// Special infected limits.
	h_si_spawn_limits[SI_INDEX_SMOKER] = CreateConVar("dsis_smoker_limit", "1", "Max amount of smokers present at once.", FCVAR_NONE, true, 0.0);
	h_si_spawn_limits[SI_INDEX_BOOMER] = CreateConVar("dsis_boomer_limit", "1", "Max amount of boomers present at once.", FCVAR_NONE, true, 0.0);
	h_si_spawn_limits[SI_INDEX_HUNTER] = CreateConVar("dsis_hunter_limit", "1", "Max amount of hunters present at once.", FCVAR_NONE, true, 0.0);
	h_si_spawn_limits[SI_INDEX_SPITTER] = CreateConVar("dsis_spitter_limit", "1", "Max amount of spitters present at once.", FCVAR_NONE, true, 0.0);
	h_si_spawn_limits[SI_INDEX_JOCKEY] = CreateConVar("dsis_jockey_limit", "1", "Max amount of jockeys present at once.", FCVAR_NONE, true, 0.0);
	h_si_spawn_limits[SI_INDEX_CHARGER] = CreateConVar("dsis_charger_limit", "1", "Max amount of chargers present at once.", FCVAR_NONE, true, 0.0);

	// Special infected weights.
	h_si_spawn_weights[SI_INDEX_SMOKER] = CreateConVar("dsis_smoker_weight", "100", "Weight for a smoker spawning.", FCVAR_NONE, true, 1.0, true, 100.0);
	h_si_spawn_weights[SI_INDEX_BOOMER] = CreateConVar("dsis_boomer_weight", "100", "Weight for a boomer spawning.", FCVAR_NONE, true, 1.0, true, 100.0);
	h_si_spawn_weights[SI_INDEX_HUNTER] = CreateConVar("dsis_hunter_weight", "100", "Weight for a hunter spawning.", FCVAR_NONE, true, 1.0, true, 100.0);
	h_si_spawn_weights[SI_INDEX_SPITTER] = CreateConVar("dsis_spitter_weight", "100", "Weight for a spitter spawning.", FCVAR_NONE, true, 1.0, true, 100.0);
	h_si_spawn_weights[SI_INDEX_JOCKEY] = CreateConVar("dsis_jockey_weight", "100", "Weight for a jockey spawning.", FCVAR_NONE, true, 1.0, true, 100.0);
	h_si_spawn_weights[SI_INDEX_CHARGER] = CreateConVar("dsis_charger_weight", "100", "Weight for a charger spawning.", FCVAR_NONE, true, 1.0, true, 100.0);

	// Special infected weight modifiers.
	h_si_spawn_weight_mods[SI_INDEX_SMOKER] = CreateConVar("dsis_smoker_mod", "1.0", "Weight modifier for each next smoker spawning.", FCVAR_NONE, true, 0.01, true, 1.0);
	h_si_spawn_weight_mods[SI_INDEX_BOOMER] = CreateConVar("dsis_boomer_mod", "1.0", "Weight modifier for each next boomer spawning.", FCVAR_NONE, true, 0.01, true, 1.0);
	h_si_spawn_weight_mods[SI_INDEX_HUNTER] = CreateConVar("dsis_hunter_mod", "1.0", "Weight modifier for each next hunter spawning.", FCVAR_NONE, true, 0.01, true, 1.0);
	h_si_spawn_weight_mods[SI_INDEX_SPITTER] = CreateConVar("dsis_spitter_mod", "1.0", "Weight modifier for each next spitter spawning.", FCVAR_NONE, true, 0.01, true, 1.0);
	h_si_spawn_weight_mods[SI_INDEX_JOCKEY] = CreateConVar("dsis_jockey_mod", "1.0", "Weight modifier for each next jockey spawning.", FCVAR_NONE, true, 0.01, true, 1.0);
	h_si_spawn_weight_mods[SI_INDEX_CHARGER] = CreateConVar("dsis_charger_mod", "1.0", "Weight modifier for each next charger spawning.", FCVAR_NONE, true, 0.01, true, 1.0);
	
	// Special infected spawn sizes.
	h_si_spawn_sizes_min = CreateConVar("dsis_sizes_min", "1 1 2 2 3 3 4 4", "Min amount of SI spawned at each spawn interval for NO. alive survivors (1-8).");
	h_si_spawn_sizes_max = CreateConVar("dsis_sizes_max", "2 2 3 3 4 4 5 5", "Max amount of SI spawned at each spawn interval for NO. alive survivors (1-8). Also the limit of SI present at the same time.");
	
	// Special infected spawn times.
	h_si_spawn_times_min = CreateConVar("dsis_times_min", "20.0 20.0 22.0 22.0 24.0 24.0 26.0 26.0", "Min SI spawn interval in seconds for for NO. alive survivors (1-8).");
	h_si_spawn_times_max = CreateConVar("dsis_times_max", "60.0 60.0 62.0 62.0 64.0 64.0 66.0 66.0", "Max SI spawn interval in seconds for for NO. alive survivors (1-8).");
	
	// Special infected spawn delays.
	h_si_spawn_delay_min = CreateConVar("dsis_delay_min", "0.4", "Min delay in seconds for each individual SI spawn.", FCVAR_NONE, true, 0.1);
	h_si_spawn_delay_max = CreateConVar("dsis_delay_max", "2.0", "Max delay in seconds for each individual SI spawn.", FCVAR_NONE, true, 0.1);

	h_count_tanks = CreateConVar("dsis_count_tanks", "1", "Will aggroed tanks be counted as SI.", FCVAR_NONE, true, 0.0, true, 1.0);

	// Used by GetVScriptOutput().
	gCvarBuffer = CreateConVar("sm_vscript_return", "", "Buffer used to return vscript values. Do not use.");

	// Hook events.
	HookEvent("player_spawn", event_player_spawn);
	HookEvent("player_death", event_player_death);
	HookEvent("player_left_safe_area", event_player_left_safe_area, EventHookMode_PostNoCopy);
	HookEvent("round_end", event_round_end, EventHookMode_Pre);

	AutoExecConfig(true, "dsis");
}

public void OnConfigsExecuted()
{
	// Get convars.
	//

	for (int i = 0; i < SI_TYPES; ++i) {
		si_spawn_limits[i] = GetConVarInt(h_si_spawn_limits[i]);
		si_spawn_weights[i] = GetConVarInt(h_si_spawn_weights[i]);
		si_spawn_weight_mods[i] = GetConVarFloat(h_si_spawn_weight_mods[i]);
	}

	// Get si_spawn_sizes_min
	int idx;
	int reloc_idx;
	int arr_idx;
	char buffer[8];
	char args[64];
	GetConVarString(h_si_spawn_sizes_min, args, sizeof(args));
	do {
		idx = BreakString(args[reloc_idx], buffer, sizeof(buffer));
		reloc_idx += idx;
		si_spawn_sizes_min[arr_idx++] = StringToInt(buffer);
	} while(idx != -1);

	// Get si_spawn_sizes_max
	reloc_idx = 0;
	arr_idx = 0;
	GetConVarString(h_si_spawn_sizes_max, args, sizeof(args));
	do {
		idx = BreakString(args[reloc_idx], buffer, sizeof(buffer));
		reloc_idx += idx;
		si_spawn_sizes_max[arr_idx++] = StringToInt(buffer);
	} while(idx != -1);

	// Get si_spawn_times_min
	reloc_idx = 0;
	arr_idx = 0;
	GetConVarString(h_si_spawn_times_min, args, sizeof(args));
	do {
		idx = BreakString(args[reloc_idx], buffer, sizeof(buffer));
		reloc_idx += idx;
		si_spawn_times_min[arr_idx++] = StringToFloat(buffer);
	} while(idx != -1);

	// Get si_spawn_times_max
	reloc_idx = 0;
	arr_idx = 0;
	GetConVarString(h_si_spawn_times_max, args, sizeof(args));
	do {
		idx = BreakString(args[reloc_idx], buffer, sizeof(buffer));
		reloc_idx += idx;
		si_spawn_times_max[arr_idx++] = StringToFloat(buffer);
	} while(idx != -1);

	si_spawn_delay_min = GetConVarFloat(h_si_spawn_delay_min);
	si_spawn_delay_max = GetConVarFloat(h_si_spawn_delay_max);
	count_tanks = GetConVarBool(h_count_tanks);

	#if DEBUG
	for (int i = 0; i < SI_TYPES; ++i)
		PrintToServer("si_spawn_limits[%s] = %i", debug_si_indexes[i], si_spawn_limits[i]);
	for (int i = 0; i < SI_TYPES; ++i)
		PrintToServer("si_spawn_weights[%s] = %i", debug_si_indexes[i], si_spawn_weights[i]);
	for (int i = 0; i < SI_TYPES; ++i)
		PrintToServer("si_spawn_weight_mods[%s] = %f", debug_si_indexes[i], si_spawn_weight_mods[i]);
	for (int i = 0; i < 8; ++i)
		PrintToServer("si_spawn_sizes_min[%i] = %i", i, si_spawn_sizes_min[i]);
	for (int i = 0; i < 8; ++i)
		PrintToServer("si_spawn_sizes_max[%i] = %i", i, si_spawn_sizes_max[i]);
	for (int i = 0; i < 8; ++i)
		PrintToServer("si_spawn_times_min[%i] = %f", i, si_spawn_times_min[i]);
	for (int i = 0; i < 8; ++i)
		PrintToServer("si_spawn_times_max[%i] = %f", i, si_spawn_times_max[i]);
	PrintToServer("si_spawn_delay_min = %f", si_spawn_delay_min);
	PrintToServer("si_spawn_delay_max = %f", si_spawn_delay_max);
	PrintToServer("count_tanks = %i", count_tanks);
	#endif
	
	//

	// Disbale director spawn special infected.
	SetConVarInt(FindConVar("z_smoker_limit"), 0);
	SetConVarInt(FindConVar("z_boomer_limit"), 0);
	SetConVarInt(FindConVar("z_hunter_limit"), 0);
	SetConVarInt(FindConVar("z_spitter_limit"), 0);
	SetConVarInt(FindConVar("z_jockey_limit"), 0);
	SetConVarInt(FindConVar("z_charger_limit"), 0);
}

void event_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS) {

		// Count on the next frame, fixes miscount on idle.
		RequestFrame(count_alive_survivors);
	
	}
}

void event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS)
		count_alive_survivors();
}

void count_alive_survivors()
{
	alive_survivors = 0;
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
			++alive_survivors;

	#if DEBUG
	PrintToConsoleAll("[DSIS] count_alive_survivors(): alive_survivors = %i", alive_survivors);
	#endif
	
	alive_survivors = clamp(alive_survivors - 1, 0, 7);
}

void event_player_left_safe_area(Event event, const char[] name, bool dontBroadcast)
{
	#if DEBUG
	PrintToConsoleAll("[DSIS] event_player_left_safe_area()");
	#endif

	start_spawn_timer();
}

void start_spawn_timer()
{
	float timer = GetRandomFloat(si_spawn_times_min[alive_survivors], si_spawn_times_max[alive_survivors]);
	h_spawn_timer = CreateTimer(timer, auto_spawn_si);
	is_spawn_timer_running = true;
	
	#if DEBUG
	PrintToConsoleAll("[DSIS] start_spawn_timer(); timer = %f", timer);
	#endif
}

Action auto_spawn_si(Handle timer)
{
	is_spawn_timer_running = false;

	// Count special infected.
	int si_type_counts[SI_TYPES];
	int si_total_count;
	for (int i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i)) {

			// Detect special infected type by zombie class.
			switch (GetEntProp(i, Prop_Send, "m_zombieClass")) {
				case ZOMBIE_CLASS_SMOKER: {
					++si_type_counts[SI_INDEX_SMOKER];
					++si_total_count;
				}
				case ZOMBIE_CLASS_BOOMER: {
					++si_type_counts[SI_INDEX_BOOMER];
					++si_total_count;
				}
				case ZOMBIE_CLASS_HUNTER: {
					++si_type_counts[SI_INDEX_HUNTER];
					++si_total_count;
				}
				case ZOMBIE_CLASS_SPITTER: {
					++si_type_counts[SI_INDEX_SPITTER];
					++si_total_count;
				}
				case ZOMBIE_CLASS_JOCKEY: {
					++si_type_counts[SI_INDEX_JOCKEY];
					++si_total_count;
				}
				case ZOMBIE_CLASS_CHARGER: {
					++si_type_counts[SI_INDEX_CHARGER];
					++si_total_count;
				}
				case ZOMBIE_CLASS_TANK: {
					
					// Idealy should count only aggroed tanks.
					if (count_tanks) {
						char buffer[128]; // GetVScriptOutput() requires large buffer.
					
						// Returns "true" if any tanks are aggro on survivors.
						GetVScriptOutput("Director.IsTankInPlay()", buffer, sizeof(buffer));
					
						#if DEBUG
						PrintToConsoleAll("[DSIS] auto_spawn_si(): Director.IsTankInPlay() = %s", buffer);
						#endif

						if (!strcmp(buffer, "true"))
							++si_total_count;
					}
				
				}
			}

		}
	}

	// Spawn special infected.
	if (si_total_count < si_spawn_sizes_max[alive_survivors]) {
		
		// Set spawn size.
		int size = si_spawn_sizes_max[alive_survivors] - si_total_count;
		if (size > si_spawn_sizes_min[alive_survivors])
			size = GetRandomInt(si_spawn_sizes_min[alive_survivors], size);

		#if DEBUG
		PrintToConsoleAll("[DSIS] auto_spawn_si(): si_spawn_size_max = %i; si_total_count = %i; size = %i", si_spawn_sizes_max[alive_survivors], si_total_count, size);
		#endif

		int tmp_weights[SI_TYPES];
		float delay;
		while (size) {

			// Calculate temporary weights and their weight sum, including modifications.
			int tmp_wsum;
			for (int i = 0; i < SI_TYPES; ++i) {
				if (si_type_counts[i] < si_spawn_limits[i]) {
					tmp_weights[i] = si_spawn_weights[i];
					int tmp_count = si_type_counts[i];
					while (tmp_count) {
						tmp_weights[i] = RoundToNearest(float(tmp_weights[i]) * si_spawn_weight_mods[i]);
						--tmp_count;
					}
				}
				else
					tmp_weights[i] = 0;
				tmp_wsum += tmp_weights[i];
			}

			#if DEBUG
			for (int i = 0; i < SI_TYPES; ++i)
				PrintToConsoleAll("[DSIS] auto_spawn_si(): tmp_weights[%s] = %i", debug_si_indexes[i], tmp_weights[i]);
			#endif

			int index = GetRandomInt(1, tmp_wsum);

			#if DEBUG
			PrintToConsoleAll("[DSIS] auto_spawn_si(): index = %i", index);
			#endif

			// Cycle trough weight ranges, find where the random index falls and pick an appropriate array index.
			int range;
			for (int i = 0; i < SI_TYPES; ++i) {
				range += tmp_weights[i];
				if (index <= range) {
					index = i;
					++si_type_counts[index];
					break;
				}
			}

			#if DEBUG
			PrintToConsoleAll("[DSIS] auto_spawn_si(): range = %i; tmp_wsum = %i; index = %s", range, tmp_wsum, debug_si_indexes[index]);
			#endif

			delay += GetRandomFloat(si_spawn_delay_min, si_spawn_delay_max);
			if (delay > si_spawn_times_min[alive_survivors])
				delay = si_spawn_times_min[alive_survivors];
			CreateTimer(delay, fake_z_spawn_old, index, TIMER_FLAG_NO_MAPCHANGE);
			--size;
		}
	}

	#if DEBUG
	else
		PrintToConsoleAll("[DSIS] auto_spawn_si(): si_spawn_size_max = %i; si_total_count = %i; SI LIMIT REACHED!", si_spawn_sizes_max[alive_survivors], si_total_count);
	#endif

	// Restart the spawn timer.
	start_spawn_timer();

	return Plugin_Continue;
}

Action fake_z_spawn_old(Handle timer, any data)
{	
	int client = get_random_alive_survivor();
	if (client) {
		
		// Create infected bot.
		// Without this we may not be able to spawn our special infected.
		int bot = CreateFakeClient("");
		if (bot)
			ChangeClientTeam(bot, TEAM_INFECTED);

		// Store command flags.
		int flags = GetCommandFlags(z_spawn_old);

		// Clear "sv_cheat" flag from the command.
		SetCommandFlags(z_spawn_old, flags & ~FCVAR_CHEAT);

		FakeClientCommand(client, z_spawns[data]);

		// Restore command flags.
		SetCommandFlags(z_spawn_old, flags);

		#if DEBUG
		char buffer[32];
		GetClientName(client, buffer, sizeof(buffer));
		PrintToConsoleAll("[DSIS] fake_z_spawn_old(): client = %i [%s]; z_spawns[%s] = %s", client, buffer, debug_si_indexes[data], z_spawns[data]);
		#endif

		// Kick the bot.
		if (bot && IsClientConnected(bot))
			KickClient(bot);

	}

	#if DEBUG
	else
		PrintToConsoleAll("[DSIS] fake_z_spawn_old(): INVALID CLIENT!");
	#endif

	return Plugin_Continue;
}

void event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	end_spawn_timer();
}

public void OnMapEnd()
{
	end_spawn_timer();
}

void end_spawn_timer()
{
	if (is_spawn_timer_running) {
		CloseHandle(h_spawn_timer);
		is_spawn_timer_running = false;
	}
}

// Extra stock functions
//

// Source https://forums.alliedmods.net/showthread.php?t=317145
// If <RETURN> </RETURN> is removed as suggested.
/**
* Runs a single line of VScript code and returns values from it.
*
* @param	code			The code to run.
* @param	buffer			Buffer to copy to.
* @param	maxlength		Maximum size of the buffer.
* @return	True on success, false otherwise.
* @error	Invalid code.
*/
stock bool GetVScriptOutput(char[] code, char[] buffer, int maxlength)
{
	static int logic = INVALID_ENT_REFERENCE;
	if( logic == INVALID_ENT_REFERENCE || !IsValidEntity(logic) )
	{
		logic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if( logic == INVALID_ENT_REFERENCE || !IsValidEntity(logic) )
			SetFailState("Could not create 'logic_script'");

		DispatchSpawn(logic);
	}
	Format(buffer, maxlength, "Convars.SetValue(\"sm_vscript_return\", \"\" + %s + \"\");", code);

	// Run code
	SetVariantString(buffer);
	AcceptEntityInput(logic, "RunScriptCode");
	AcceptEntityInput(logic, "Kill");

	// Retrieve value and return to buffer
	gCvarBuffer.GetString(buffer, maxlength);
	gCvarBuffer.SetString("");

	if( buffer[0] == '\x0')
		return false;
	return true;
}

/*
Returns client of random alive survivor or 0 if there are no alive survivors.
*/
stock int get_random_alive_survivor()
{
	int[] clients = new int[MaxClients];
	int index;
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			clients[index++] = i; // We can't know who's last, so index will overflow!
	return index ? clients[GetRandomInt(0, index - 1)] : 0;
}

/*
Returns clamped val between min and max.
*/
stock int clamp(int val, int min, int max)
{
	return val > max ? max : (val < min ? min : val);
}
