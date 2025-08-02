#include <a_samp>
#include <timers>

#if !defined _timers_included
    #error "This gamemode requires timers.inc to be included"
#endif

new g_ServerTimer = -1;
new g_PlayerTimers[MAX_PLAYERS] = {-1, ...};
new g_AnnouncementTimer = -1;
new g_LongTestTimers[MAX_PLAYERS] = {-1, ...};
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

    new amx_count = Timer_GetAmxInstanceCount();
    printf("AMX instances registered: %d", amx_count);
    
    new active_count = Timer_GetActiveCount();
    printf("Active timers: %d", active_count);

    new cleanup_timer = Timer_SetOnce(120000, "AutoCleanupAllTimers"); 
    if (IsValidTimerID(cleanup_timer)) {
        printf("Auto-cleanup timer set for 120 seconds");
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
        printf("Cleaned up health timer for player %d", playerid);
    }

    if (IsValidTimerID(g_LongTestTimers[playerid])) {
        Timer_Kill(g_LongTestTimers[playerid]);
        g_LongTestTimers[playerid] = -1;
        printf("Cleaned up long test timer for player %d", playerid);
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
                printf("[CMD] Player %d health timer delay: %d ms", playerid, delay);
                format(message, sizeof(message), "Your health timer delay: %d ms", delay);
                SendClientMessage(playerid, 0x00FFFFFF, message);
            }
        } else {
            printf("[CMD] Player %d has no active health timer", playerid);
        }

        if (IsValidTimerID(g_LongTestTimers[playerid])) {
            new delay = Timer_GetInfo(g_LongTestTimers[playerid]);
            if (delay != -1) {
                printf("[CMD] Player %d long test timer delay: %d ms", playerid, delay);
                format(message, sizeof(message), "Your long test timer delay: %d ms", delay);
                SendClientMessage(playerid, 0x00FFFFFF, message);
            }
        } else {
            printf("[CMD] Player %d has no active long test timer", playerid);
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

    if (strcmp("/longtest", cmdtext, true) == 0) {
        printf("[CMD] Player %d used /longtest command", playerid);

        if (IsValidTimerID(g_LongTestTimers[playerid])) {
            SendClientMessage(playerid, 0xFF0000FF, "You already have a long test timer running! Use /stoplong to stop it first.");
            printf("[CMD] Player %d already has long timer %d", playerid, g_LongTestTimers[playerid]);
            return 1;
        }

        new active_long_timers = 0;
        for (new i = 0; i < MAX_PLAYERS; i++) {
            if (IsValidTimerID(g_LongTestTimers[i])) {
                active_long_timers++;
            }
        }

        if (active_long_timers >= 2) {
            SendClientMessage(playerid, 0xFF0000FF, "Maximum 2 long test timers allowed. Wait for others to finish or use /stoplong.");
            printf("[CMD] Long timer limit reached: %d/2 active", active_long_timers);
            return 1;
        }

        g_LongTestTimers[playerid] = Timer_SetEx(10000, true, "OnLongTestTimer", TIMER_PARAM_INTEGER, playerid, 0.0, "");
        if (IsValidTimerID(g_LongTestTimers[playerid])) {
            printf("[CMD] Successfully created long-running timer %d for player %d", g_LongTestTimers[playerid], playerid);
            SendClientMessage(playerid, 0x00FF00FF, "Long-running test timer created (10 second interval). Use /stoplong to stop.");
        } else {
            printf("[CMD] Failed to create long timer for player %d: %s", playerid, GetTimerErrorMessage(g_LongTestTimers[playerid]));
            SendClientMessage(playerid, 0xFF0000FF, "Failed to create long timer.");
            g_LongTestTimers[playerid] = -1;
        }
        return 1;
    }

    if (strcmp("/stoplong", cmdtext, true) == 0) {
        printf("[CMD] Player %d used /stoplong command", playerid);

        if (IsValidTimerID(g_LongTestTimers[playerid])) {
            if (Timer_Kill(g_LongTestTimers[playerid])) {
                printf("[CMD] Successfully stopped long timer %d for player %d", g_LongTestTimers[playerid], playerid);
                SendClientMessage(playerid, 0x00FF00FF, "Long test timer stopped successfully.");
                g_LongTestTimers[playerid] = -1;
            } else {
                printf("[CMD] Failed to stop long timer %d for player %d", g_LongTestTimers[playerid], playerid);
                SendClientMessage(playerid, 0xFF0000FF, "Failed to stop long timer.");
            }
        } else {
            SendClientMessage(playerid, 0xFF0000FF, "You don't have any long test timer running.");
            printf("[CMD] Player %d has no long timer to stop", playerid);
        }
        return 1;
    }

    if (strcmp("/cmdlist", cmdtext, true) == 0) {
        printf("[CMD] Player %d used /cmdlist command", playerid);

        SendClientMessage(playerid, 0x00FFFFFF, "=== Timers Commands ===");
        SendClientMessage(playerid, 0x00FF00FF, "/testtimer - Create a test timer for your player");
        SendClientMessage(playerid, 0x00FF00FF, "/teststring - Create a timer with string parameter");
        SendClientMessage(playerid, 0x00FF00FF, "/testfloat - Create a timer with float parameter");
        SendClientMessage(playerid, 0x00FF00FF, "/longtest - Create a long-running timer (10s interval, max 2)");
        SendClientMessage(playerid, 0x00FF00FF, "/stoplong - Stop your long-running timer");
        SendClientMessage(playerid, 0x00FF00FF, "/restarttimer - Restart your health regeneration timer");
        SendClientMessage(playerid, 0x00FF00FF, "/killtimer - Kill your active timer");
        SendClientMessage(playerid, 0x00FF00FF, "/timerinfo - Show active timer count and your timer info");
        SendClientMessage(playerid, 0x00FF00FF, "/sethp [amount] - Set your health (e.g., /sethp 50)");
        SendClientMessage(playerid, 0x00FF00FF, "/debug - Run debug test and create debug timer");
        SendClientMessage(playerid, 0x00FF00FF, "/info - Show detailed timer information");
        SendClientMessage(playerid, 0x00FF00FF, "/cmdlist - Show this command list");

        printf("[CMD] Displayed command list to player %d", playerid);
        return 1;
    }

    return 0;
}

forward OnServerHeartbeat();
public OnServerHeartbeat()
{
    static heartbeat_count = 0;
    heartbeat_count++;

    new hour, minute, second;
    gettime(hour, minute, second);
    printf("[%02d:%02d:%02d] Server heartbeat #%d - Players online: %d", hour, minute, second, heartbeat_count, GetPlayerPoolSize() + 1);

    if (heartbeat_count >= 20) {
        printf("Auto-stopping server heartbeat timer after %d executions", heartbeat_count);
        if (IsValidTimerID(g_ServerTimer)) {
            Timer_Kill(g_ServerTimer);
            g_ServerTimer = -1;
        }
        heartbeat_count = 0;
    }
}

forward OnServerAnnouncement(const message[]);
public OnServerAnnouncement(const message[])
{
    static announcement_count = 0;
    announcement_count++;

    printf("Server Announcement #%d: %s", announcement_count, message);
    SendClientMessageToAll(0x00FFFFFF, message);

    if (announcement_count >= 10) {
        printf("Auto-stopping announcement timer after %d executions", announcement_count);
        if (IsValidTimerID(g_AnnouncementTimer)) {
            Timer_Kill(g_AnnouncementTimer);
            g_AnnouncementTimer = -1;
        }
        announcement_count = 0;
    }
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
    static execution_count[MAX_PLAYERS] = {0, ...};
    execution_count[playerid]++;

    if (playerid < 0 || playerid >= MAX_PLAYERS) {
        printf("[HEALTH] ERROR: Invalid playerid %d in OnPlayerHealthRegen", playerid);
        return;
    }

    if (IsPlayerConnected(playerid)) {
        new Float:health;
        GetPlayerHealth(playerid, health);

        new current_time = gettime();
        new time_since_last = current_time - g_LastHealthRegen[playerid];

        if (health < 100.0 && health > 0.0) {
            if (time_since_last >= 5) {
                new Float:new_health = health + 10.0;
                if (new_health > 100.0) new_health = 100.0;

                SetPlayerHealth(playerid, new_health);
                g_LastHealthRegen[playerid] = current_time;

                printf("[HEALTH] Player %d health regenerated: %.1f -> %.1f", playerid, health, new_health);

                if (new_health - health >= 5.0) {
                    new message[64];
                    format(message, sizeof(message), "Health regenerated: %.1f", new_health);
                    SendClientMessage(playerid, 0x00FF00FF, message);
                }
            }
        }

        if (execution_count[playerid] >= 50) {
            printf("[HEALTH] Auto-stopping health regen timer for player %d after %d executions", playerid, execution_count[playerid]);
            if (IsValidTimerID(g_PlayerTimers[playerid])) {
                Timer_Kill(g_PlayerTimers[playerid]);
                g_PlayerTimers[playerid] = -1;
            }
            execution_count[playerid] = 0;
        }
    } else {
        printf("[HEALTH] Player %d is not connected, stopping timer", playerid);
        if (IsValidTimerID(g_PlayerTimers[playerid])) {
            Timer_Kill(g_PlayerTimers[playerid]);
            g_PlayerTimers[playerid] = -1;
        }
        execution_count[playerid] = 0;
    }
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

forward OnLongTestTimer(playerid);
public OnLongTestTimer(playerid)
{
    static execution_count[MAX_PLAYERS] = {0, ...};
    execution_count[playerid]++;

    printf("[LONG TEST] Timer execution #%d for player %d", execution_count[playerid], playerid);

    if (playerid >= 0 && playerid < MAX_PLAYERS && IsPlayerConnected(playerid)) {
        new message[128];
        format(message, sizeof(message), "Long test timer #%d executed!", execution_count[playerid]);
        SendClientMessage(playerid, 0xFFFF00FF, message);

        if (execution_count[playerid] >= 20) {
            printf("[LONG TEST] Auto-stopping long timer for player %d after %d executions", playerid, execution_count[playerid]);
            if (IsValidTimerID(g_LongTestTimers[playerid])) {
                Timer_Kill(g_LongTestTimers[playerid]);
                g_LongTestTimers[playerid] = -1;
                SendClientMessage(playerid, 0xFFFF00FF, "Long test timer auto-stopped after 20 executions.");
            }
            execution_count[playerid] = 0;
        }
    } else {
        printf("[LONG TEST] Player %d is not connected, stopping timer", playerid);
        if (IsValidTimerID(g_LongTestTimers[playerid])) {
            Timer_Kill(g_LongTestTimers[playerid]);
            g_LongTestTimers[playerid] = -1;
        }
        execution_count[playerid] = 0;
    }
}

forward AutoCleanupAllTimers();
public AutoCleanupAllTimers()
{
    printf("=== AUTO CLEANUP: Stopping all timers ===");
    new cleaned_count = 0;

    if (IsValidTimerID(g_ServerTimer)) {
        Timer_Kill(g_ServerTimer);
        printf("Auto-cleaned server heartbeat timer %d", g_ServerTimer);
        g_ServerTimer = -1;
        cleaned_count++;
    }

    if (IsValidTimerID(g_AnnouncementTimer)) {
        Timer_Kill(g_AnnouncementTimer);
        printf("Auto-cleaned announcement timer %d", g_AnnouncementTimer);
        g_AnnouncementTimer = -1;
        cleaned_count++;
    }

    for (new i = 0; i < MAX_PLAYERS; i++) {
        if (IsValidTimerID(g_PlayerTimers[i])) {
            Timer_Kill(g_PlayerTimers[i]);
            printf("Auto-cleaned player timer %d for player %d", g_PlayerTimers[i], i);
            g_PlayerTimers[i] = -1;
            cleaned_count++;
        }

        if (IsValidTimerID(g_LongTestTimers[i])) {
            Timer_Kill(g_LongTestTimers[i]);
            printf("Auto-cleaned long test timer %d for player %d", g_LongTestTimers[i], i);
            g_LongTestTimers[i] = -1;
            cleaned_count++;
        }
    }
    printf("active timer count: %d", Timer_GetActiveCount());
    printf("AMX instance count: %d", Timer_GetAmxInstanceCount());
}
