/**
 * [TF2] Workshop Sounds Fix
 * 
 * Adds some hooks to the soundscape and sound emitter systems to load soundscapes and
 * sound overrides embedded in Workshop maps by display name.
 * 
 * Soundscapes are handled server-side and work perfectly; certain sounds are handled on the
 * server and others on the client, so when it comes to overrides, your mileage may vary.
 * 
 * This has been an unfixed issue for years, Valve, what the fuck?
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdktools>
#include <dhooks>

#include <stocksoup/maps>
#include <stocksoup/log_server>

#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"
public Plugin myinfo = {
	name = "[TF2] Workshop Map Sounds Fix",
	author = "nosoop",
	description = "Load soundscapes / sound overrides by display name for Steam Workshop maps.",
	version = PLUGIN_VERSION,
	url = "localhost"
}

Address g_pSoundEmitterBase;
Handle g_SDKCallAddSoundscapeFile, g_SDKCallAddSoundOverrides;

ConVar g_SpewSoundOverrideLoadInfo;

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("tf2.workshop_sounds");
	if (!hGameConf) {
		SetFailState("Failed to load gamedata (tf2.workshop_sounds).");
	}
	
	g_pSoundEmitterBase = GameConfGetAddress(hGameConf, "soundemitterbase");
	
	/* SDKCall to add soundscapes */
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature,
			"CSoundscapeSystem::AddSoundscapeFile()");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if (!(g_SDKCallAddSoundscapeFile = EndPrepSDKCall())) {
		SetFailState("Could not init SDKCall to CSoundscapeSystem::AddSoundscapeFile()");
	}
	
	/* SDKCall to add sound overrides */
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"ISoundEmitterSystemBase::AddSoundOverride()");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_SDKCallAddSoundOverrides = EndPrepSDKCall())) {
		SetFailState("Could not init SDKCall to ISoundEmitterSystemBase::AddSoundOverride()");
	}
	
	/* Jook soundsccape init */
	Handle hookSoundscapeInit = DHookCreateFromConf(hGameConf, "CSoundscapeSystem::Init()");
	if (!hookSoundscapeInit) {
		SetFailState("Could not init detour on CSoundscapeSystem::Init()");
	}
	DHookEnableDetour(hookSoundscapeInit, true, OnSoundscapeInitPost);
	
	/* hook sound overrides handler */
	Handle hookSoundEmitterInit = DHookCreateFromConf(hGameConf,
			"CSoundEmitterSystem::LevelInitPreEntity()");
	if (!hookSoundEmitterInit) {
		SetFailState("Could not init detour on CSoundEmitterSystem::LevelInitPreEntity()");
	}
	DHookEnableDetour(hookSoundEmitterInit, true, OnSoundEmitterInit);
	
	/* sound override hook to verify and dump added overrides */
	Handle hookSoundEmitter = DHookCreate(
			GameConfGetOffset(hGameConf, "ISoundEmitterSystemBase::AddSoundOverride()"),
			HookType_Raw, ReturnType_Void, ThisPointer_Address, SpewSoundOverrideHook);
	DHookAddParam(hookSoundEmitter, HookParamType_CharPtr);
	DHookAddParam(hookSoundEmitter, HookParamType_Bool);
	DHookRaw(hookSoundEmitter, false, g_pSoundEmitterBase);
	
	delete hGameConf;
	
	g_SpewSoundOverrideLoadInfo = CreateConVar("spew_sound_override_load_info",
			"Spew loaded sound overrides.", "0");
}

/**
 * Some basic diagnostics to verify that sound overrides are injected.
 */
public MRESReturn SpewSoundOverrideHook(Address pSoundEmitter, Handle hParams) {
	if (g_SpewSoundOverrideLoadInfo.BoolValue) {
		char buffer[256];
		DHookGetParamString(hParams, 1, buffer, sizeof(buffer));
		LogServer("Debug:  Adding override file %s", buffer);
	}
	return MRES_Ignored;
}

/**
 * Post-hook that adds Workshop map soundscapes.
 */
public MRESReturn OnSoundscapeInitPost(Address pSoundscapeSystem, Handle hReturn) {
	char mapName[PLATFORM_MAX_PATH], mapSoundscapePath[PLATFORM_MAX_PATH];
	GetCurrentMap(mapName, sizeof(mapName));
	
	if (GetMapWorkshopID(mapName)) {
		GetMapDisplayName(mapName, mapName, sizeof(mapName));
		
		Format(mapSoundscapePath, sizeof(mapSoundscapePath), "scripts/soundscapes_%s.txt",
				mapName);
		
		if (FileExists(mapSoundscapePath, true)) {
			SDKCall(g_SDKCallAddSoundscapeFile, pSoundscapeSystem, mapSoundscapePath);
			LogServer("Loaded Workshop-embedded soundscape file %s", mapSoundscapePath);
		}
	}
	
	return MRES_Ignored;
}

/**
 * Post-hook that adds Workshop map sound overrides.
 */
public MRESReturn OnSoundEmitterInit(Address pSoundEmitterSystem) {
	char mapName[PLATFORM_MAX_PATH], mapSoundOverridePath[PLATFORM_MAX_PATH];
	GetCurrentMap(mapName, sizeof(mapName));
	
	if (GetMapWorkshopID(mapName)) {
		GetMapDisplayName(mapName, mapName, sizeof(mapName));
		
		Format(mapSoundOverridePath, sizeof(mapSoundOverridePath), "maps/%s_level_sounds.txt",
				mapName);
		
		if (FileExists(mapSoundOverridePath, true)) {
			SDKCall(g_SDKCallAddSoundOverrides, g_pSoundEmitterBase, mapSoundOverridePath,
					true);
			LogServer("Loaded Workshop-embedded sound overrides file %s", mapSoundOverridePath);
		}
	}
	
	return MRES_Ignored;
}
