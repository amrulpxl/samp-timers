#include <a_samp>
#include <timers>

#if !defined _timers_included
    #error "This gamemode requires timers.inc to be included"
#endif

new g_ServerTimer = -1;
new g_PlayerTimers[MAX_PLAYERS] = {-1, ...};
new g_AnnouncementTimer = -1;
new g_LastHealthRegen[MAX_PLAYERS]; 

main(){}

public OnGameModeInit()
{
    g_ServerTimer = Timer_Set(30000, true, "OnServerHeartbeat");
    if (!IsValidTimerID(g_ServerTimer)) {
        printf("ERROR: Failed to create server timer: %s", GetTimerErrorMessage(g_ServerTimer));
    } else {
        printf("Server heartbeat timer created with ID: %d", g_ServerTimer);
    }
    
    g_AnnouncementTimer = Timer_SetEx(300000, true, "OnServerAnnouncement", TIMER_PARAM_STRING, 0, 0.0, "Welcome to our server!");
    if (!IsValidTimerID(g_AnnouncementTimer)) {
        printf("ERROR: Failed to create announcement timer: %s", GetTimerErrorMessage(g_AnnouncementTimer));
    }
    
    new invalid_timer = Timer_Set(-1000, true, "InvalidCallback");
    if (!IsValidTimerID(invalid_timer)) {
        printf("Expected error caught: %s", GetTimerErrorMessage(invalid_timer));
    }

    new empty_callback = Timer_Set(1000, false, "");
    if (!IsValidTimerID(empty_callback)) {
        printf("Expected error caught: %s", GetTimerErrorMessage(empty_callback));
    }
    
    return 1;
}

public OnGameModeExit()
{
    if (IsValidTimerID(g_ServerTimer)) {
        Timer_Kill(g_ServerTimer);
        printf("Server timer %d killed", g_ServerTimer);
        g_ServerTimer = -1;
    }
    
    if (IsValidTimerID(g_AnnouncementTimer)) {
        Timer_Kill(g_AnnouncementTimer);
        printf("Announcement timer %d killed", g_AnnouncementTimer);
        g_AnnouncementTimer = -1;
    }
    
    for (new i = 0; i < MAX_PLAYERS; i++) {
        if (IsValidTimerID(g_PlayerTimers[i])) {
            Timer_Kill(g_PlayerTimers[i]);
            g_PlayerTimers[i] = -1;
        }
    }
    
    print("All timers cleaned up");
    return 1;
}

public OnPlayerConnect(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) {
        printf("ERROR: Invalid playerid %d in OnPlayerConnect", playerid);
        return 0;
    }

    new welcome_timer = Timer_SetOnceEx(2000, "OnPlayerWelcome", TIMER_PARAM_INTEGER, playerid, 0.0, "");
    if (!IsValidTimerID(welcome_timer)) {
        printf("Failed to create welcome timer for player %d: %s", playerid, GetTimerErrorMessage(welcome_timer));
    }

    g_PlayerTimers[playerid] = Timer_SetEx(5000, true, "OnPlayerHealthRegen", TIMER_PARAM_INTEGER, playerid, 0.0, "");
    if (!IsValidTimerID(g_PlayerTimers[playerid])) {
        printf("Failed to create health regen timer for player %d: %s", playerid, GetTimerErrorMessage(g_PlayerTimers[playerid]));
    }

    g_LastHealthRegen[playerid] = gettime();

    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) {
        printf("ERROR: Invalid playerid %d in OnPlayerDisconnect", playerid);
        return 0;
    }

    if (IsValidTimerID(g_PlayerTimers[playerid])) {
        Timer_Kill(g_PlayerTimers[playerid]);
        g_PlayerTimers[playerid] = -1;
        printf("Cleaned up timer for player %d", playerid);
    }
    
    g_LastHealthRegen[playerid] = gettime();
    
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) {
        printf("ERROR: Invalid playerid %d in OnPlayerCommandText", playerid);
        return 0;
    }

    if (strcmp("/testtimer", cmdtext, true) == 0) {
        printf("[CMD] Player %d used /testtimer command", playerid);
        new timer_id = Timer_SetOnceEx(3000, "OnTestTimer", TIMER_PARAM_INTEGER, playerid, 0.0, "");

        if (IsValidTimerID(timer_id)) {
            printf("[CMD] Successfully created test timer %d for player %d", timer_id, playerid);
            SendClientMessage(playerid, 0x00FF00FF, "Test timer created! Check console in 3 seconds.");
        } else {
            printf("[CMD] Failed to create test timer for player %d: %s", playerid, GetTimerErrorMessage(timer_id));
            new message[128];
            format(message, sizeof(message), "Failed to create test timer: %s",
                   GetTimerErrorMessage(timer_id));
            SendClientMessage(playerid, 0xFF0000FF, message);
        }
        return 1;
    }

    if (strcmp("/testfloat", cmdtext, true) == 0) {
        printf("[CMD] Player %d used /testfloat command", playerid);
        new timer_id = Timer_SetOnceEx(2000, "OnFloatTest", TIMER_PARAM_FLOAT, 0, 3.14159, "");

        if (IsValidTimerID(timer_id)) {
            printf("[CMD] Successfully created float timer %d for player %d", timer_id, playerid);
            SendClientMessage(playerid, 0x00FF00FF, "Float timer created! Check console in 2 seconds.");
        } else {
            printf("[CMD] Failed to create float timer for player %d: %s", playerid, GetTimerErrorMessage(timer_id));
            new message[128];
            format(message, sizeof(message), "Failed to create float timer: %s",
                   GetTimerErrorMessage(timer_id));
            SendClientMessage(playerid, 0xFF0000FF, message);
        }
        return 1;
    }

    if (strcmp("/teststring", cmdtext, true) == 0) {
        printf("[CMD] Player %d used /teststring command", playerid);
        new timer_id = Timer_SetOnceEx(1500, "OnStringTest", TIMER_PARAM_STRING, 0, 0.0, "Hello from timer!");

        if (IsValidTimerID(timer_id)) {
            printf("[CMD] Successfully created string timer %d for player %d", timer_id, playerid);
            SendClientMessage(playerid, 0x00FF00FF, "String timer created! Check console in 1.5 seconds.");
        } else {
            printf("[CMD] Failed to create string timer for player %d: %s", playerid, GetTimerErrorMessage(timer_id));
            new message[128];
            format(message, sizeof(message), "Failed to create string timer: %s",
                   GetTimerErrorMessage(timer_id));
            SendClientMessage(playerid, 0xFF0000FF, message);
        }
        return 1;
    }

    if (strcmp("/killtimer", cmdtext, true) == 0) {
        printf("[CMD] Player %d used /killtimer command", playerid);
    
        if (IsValidTimerID(g_PlayerTimers[playerid])) {
            new timer_id = g_PlayerTimers[playerid];
            printf("[CMD] Attempting to kill timer %d for player %d", timer_id, playerid);
            Timer_Kill(timer_id);
            printf("[CMD] Timer_Kill called for timer %d", timer_id);
            
            g_PlayerTimers[playerid] = -1;
            printf("[CMD] Successfully killed timer %d for player %d", timer_id, playerid);
            SendClientMessage(playerid, 0x00FF00FF, "Your health regeneration timer has been killed.");
        } else {
            printf("[CMD] Player %d has no active timer to kill", playerid);
            SendClientMessage(playerid, 0xFF0000FF, "You don't have an active timer.");
        }
        return 1;
    }
    
    if (strcmp("/restarttimer", cmdtext, true) == 0) {
        printf("[CMD] Player %d used /restarttimer command", playerid);
        
        if (IsValidTimerID(g_PlayerTimers[playerid])) {
            new old_timer = g_PlayerTimers[playerid];
            printf("[CMD] Killing existing timer %d for player %d", old_timer, playerid);
            Timer_Kill(old_timer);
            g_PlayerTimers[playerid] = -1;
            printf("[CMD] Killed existing timer for player %d", playerid);
        }
       
        g_PlayerTimers[playerid] = Timer_SetEx(5000, true, "OnPlayerHealthRegen", TIMER_PARAM_INTEGER, playerid, 0.0, "");
        if (IsValidTimerID(g_PlayerTimers[playerid])) {
            printf("[CMD] Successfully restarted timer %d for player %d", g_PlayerTimers[playerid], playerid);
            SendClientMessage(playerid, 0x00FF00FF, "Health regeneration timer restarted (5 second interval).");
        } else {
            printf("[CMD] Failed to restart timer for player %d: %s", playerid, GetTimerErrorMessage(g_PlayerTimers[playerid]));
            SendClientMessage(playerid, 0xFF0000FF, "Failed to restart timer.");
        }
        return 1;
    }

    if (strcmp("/timerinfo", cmdtext, true) == 0) {
        printf("[CMD] Player %d used /timerinfo command", playerid);
        new count = Timer_GetActiveCount();
        new message[128];
        format(message, sizeof(message), "Active timers: %d", count);
        SendClientMessage(playerid, 0x00FFFFFF, message);
        printf("[CMD] Active timer count: %d", count);

        if (IsValidTimerID(g_PlayerTimers[playerid])) {
            new delay = Timer_GetInfo(g_PlayerTimers[playerid]);
            if (delay != -1) {
                printf("[CMD] Player %d timer delay: %d ms", playerid, delay);
                format(message, sizeof(message), "Your timer delay: %d ms", delay);
                SendClientMessage(playerid, 0x00FFFFFF, message);
            }
        } else {
            printf("[CMD] Player %d has no active timer", playerid);
        }
        return 1;
    }
    
    if (strcmp("/sethp", cmdtext, true) == 0) {
        printf("[CMD] Player %d used /sethp command", playerid);
        
        if (IsPlayerConnected(playerid)) {
            SetPlayerHealth(playerid, 50.0);
            printf("[CMD] Set player %d health to 50.0", playerid);
            SendClientMessage(playerid, 0x00FF00FF, "Your health has been set to 50 HP!");
        } else {
            printf("[CMD] Player %d is not connected", playerid);
            SendClientMessage(playerid, 0xFF0000FF, "You are not connected!");
        }
        return 1;
    }
    
    return 0;
}

forward OnServerHeartbeat();
public OnServerHeartbeat()
{
    new hour, minute, second;
    gettime(hour, minute, second);
    printf("[%02d:%02d:%02d] Server heartbeat - Players online: %d", hour, minute, second, GetPlayerPoolSize() + 1);
}

forward OnServerAnnouncement(const message[]);
public OnServerAnnouncement(const message[])
{
    printf("Server Announcement: %s", message);
    SendClientMessageToAll(0x00FFFFFF, message);
}

forward OnPlayerWelcome(playerid);
public OnPlayerWelcome(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) {
        printf("ERROR: Invalid playerid %d in OnPlayerWelcome", playerid);
        return;
    }

    if (IsPlayerConnected(playerid)) {
        new welcome_msg[128];
        format(welcome_msg, sizeof(welcome_msg), "Welcome %s! Type /testtimer to test the timer system.", GetPlayerNameEx(playerid));
        SendClientMessage(playerid, 0x00FF00FF, welcome_msg);
    }
}

forward OnPlayerHealthRegen(playerid);
public OnPlayerHealthRegen(playerid)
{
    printf("[HEALTH] ===== OnPlayerHealthRegen START for player %d =====", playerid);
    
    if (playerid < 0 || playerid >= MAX_PLAYERS) {
        printf("[HEALTH] ERROR: Invalid playerid %d in OnPlayerHealthRegen", playerid);
        return;
    }

    printf("[HEALTH] Player %d: checking connection...", playerid);
    if (IsPlayerConnected(playerid)) {
        new Float:health;
        GetPlayerHealth(playerid, health);
        printf("[HEALTH] Player %d: got health = %.1f", playerid, health);

        new current_time = gettime();
        new time_since_last = current_time - g_LastHealthRegen[playerid];
        printf("[HEALTH] Player %d: health=%.1f, time_since_last=%d seconds", playerid, health, time_since_last);

        if (health < 100.0 && health > 0.0) {
            printf("[HEALTH] Player %d: health is low, checking cooldown...", playerid);
            if (time_since_last >= 5) {
                new Float:new_health = health + 10.0;
                if (new_health > 100.0) new_health = 100.0;

                printf("[HEALTH] Player %d: setting health from %.1f to %.1f", playerid, health, new_health);
                SetPlayerHealth(playerid, new_health);
                g_LastHealthRegen[playerid] = current_time;

                printf("[HEALTH] Player %d health regenerated: %.1f -> %.1f", playerid, health, new_health);

                if (new_health - health >= 5.0) {
                    new message[64];
                    format(message, sizeof(message), "Health regenerated: %.1f", new_health);
                    SendClientMessage(playerid, 0x00FF00FF, message);
                    printf("[HEALTH] Player %d: sent health regen message", playerid);
                }
            } else {
                printf("[HEALTH] Player %d: cooldown active (%d seconds remaining)", playerid, 5 - time_since_last);
            }
        } else {
            printf("[HEALTH] Player %d: health is %.1f (no regen needed)", playerid, health);
        }
    } else {
        printf("[HEALTH] Player %d is not connected", playerid);
    }
    
    printf("[HEALTH] ===== OnPlayerHealthRegen END for player %d =====", playerid);
}

forward OnTestTimer(playerid);
public OnTestTimer(playerid)
{
    printf("Test timer executed for player %d", playerid);

    if (playerid >= 0 && playerid < MAX_PLAYERS && IsPlayerConnected(playerid)) {
        new result_msg[128];
        format(result_msg, sizeof(result_msg), "Test timer executed for player %d!", playerid);
        SendClientMessage(playerid, 0xFFFF00FF, result_msg);
    }
}

forward OnFloatTest(Float:value);
public OnFloatTest(Float:value)
{
    printf("Float test timer executed with value: %.5f", value);
}

forward OnStringTest(const message[]);
public OnStringTest(const message[])
{
    printf("String test timer executed with message: %s", message);
}

stock GetPlayerNameEx(playerid)
{
    new name[MAX_PLAYER_NAME];
    if (playerid >= 0 && playerid < MAX_PLAYERS && IsPlayerConnected(playerid)) {
        GetPlayerName(playerid, name, sizeof(name));
    } else {
        format(name, sizeof(name), "Player(%d)", playerid);
    }
    return name;
}
