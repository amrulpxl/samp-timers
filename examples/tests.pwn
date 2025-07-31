#include <a_samp>
#include <timers>

new g_ServerTimer = -1;
new g_PlayerTimers[MAX_PLAYERS] = {-1, ...};
new g_AnnouncementTimer = -1;

main(){}

public OnGameModeInit()
{
    g_ServerTimer = Timer_Set(30000, true, "OnServerHeartbeat");
    if (!IsValidTimerID(g_ServerTimer)) {
        printf("ERROR: Failed to create server timer: %s", GetTimerErrorMessage(g_ServerTimer));
    } else {
        printf("Server heartbeat timer created with ID: %d", g_ServerTimer);
    }
    
    g_AnnouncementTimer = Timer_SetEx(300000, true, "OnServerAnnouncement", 2, 0, 0.0, "Welcome to our server!");
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
    }
    
    if (IsValidTimerID(g_AnnouncementTimer)) {
        Timer_Kill(g_AnnouncementTimer);
        printf("Announcement timer %d killed", g_AnnouncementTimer);
    }
    
    for (new i = 0; i < MAX_PLAYERS; i++) {
        if (IsValidTimerID(g_PlayerTimers[i])) {
            Timer_Kill(g_PlayerTimers[i]);
        }
    }
    
    print("All timers cleaned up");
    return 1;
}

public OnPlayerConnect(playerid)
{
    new welcome_timer = Timer_SetOnceEx(2000, "OnPlayerWelcome", 0, playerid, 0.0, "");
    if (!IsValidTimerID(welcome_timer)) {
        printf("Failed to create welcome timer for player %d: %s", playerid, GetTimerErrorMessage(welcome_timer));
    }

    g_PlayerTimers[playerid] = Timer_SetEx(10000, true, "OnPlayerHealthRegen", 0, playerid, 0.0, "");
    if (!IsValidTimerID(g_PlayerTimers[playerid])) {
        printf("Failed to create health regen timer for player %d: %s", playerid, GetTimerErrorMessage(g_PlayerTimers[playerid]));
    }

    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if (IsValidTimerID(g_PlayerTimers[playerid])) {
        Timer_Kill(g_PlayerTimers[playerid]);
        g_PlayerTimers[playerid] = -1;
        printf("Cleaned up timer for player %d", playerid);
    }
    
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (strcmp("/testtimer", cmdtext, true) == 0) {
        new timer_id = Timer_SetOnceEx(3000, "OnTestTimer", 0, playerid, 0.0, "");

        if (IsValidTimerID(timer_id)) {
            SendClientMessage(playerid, 0x00FF00FF, "Test timer created! Check console in 3 seconds.");
        } else {
            new message[128];
            format(message, sizeof(message), "Failed to create test timer: %s",
                   GetTimerErrorMessage(timer_id));
            SendClientMessage(playerid, 0xFF0000FF, message);
        }
        return 1;
    }

    if (strcmp("/testfloat", cmdtext, true) == 0) {
        new timer_id = Timer_SetOnceEx(2000, "OnFloatTest", 1, 0, 3.14159, "");

        if (IsValidTimerID(timer_id)) {
            SendClientMessage(playerid, 0x00FF00FF, "Float timer created! Check console in 2 seconds.");
        } else {
            new message[128];
            format(message, sizeof(message), "Failed to create float timer: %s",
                   GetTimerErrorMessage(timer_id));
            SendClientMessage(playerid, 0xFF0000FF, message);
        }
        return 1;
    }

    if (strcmp("/teststring", cmdtext, true) == 0) {
        new timer_id = Timer_SetOnceEx(1500, "OnStringTest", 2, 0, 0.0, "Hello from timer!");

        if (IsValidTimerID(timer_id)) {
            SendClientMessage(playerid, 0x00FF00FF, "String timer created! Check console in 1.5 seconds.");
        } else {
            new message[128];
            format(message, sizeof(message), "Failed to create string timer: %s",
                   GetTimerErrorMessage(timer_id));
            SendClientMessage(playerid, 0xFF0000FF, message);
        }
        return 1;
    }
    
    if (strcmp("/killtimer", cmdtext, true) == 0) {
        if (IsValidTimerID(g_PlayerTimers[playerid])) {
            if (Timer_Kill(g_PlayerTimers[playerid])) {
                g_PlayerTimers[playerid] = -1;
                SendClientMessage(playerid, 0x00FF00FF, "Your health regeneration timer has been killed.");
            } else {
                SendClientMessage(playerid, 0xFF0000FF, "Failed to kill your timer.");
            }
        } else {
            SendClientMessage(playerid, 0xFF0000FF, "You don't have an active timer.");
        }
        return 1;
    }
    
    if (strcmp("/restarttimer", cmdtext, true) == 0) {
        if (IsValidTimerID(g_PlayerTimers[playerid])) {
            Timer_Kill(g_PlayerTimers[playerid]);
        }
       
        g_PlayerTimers[playerid] = Timer_SetEx(5000, true, "OnPlayerHealthRegen", 0, playerid, 0.0, "");
        if (IsValidTimerID(g_PlayerTimers[playerid])) {
            SendClientMessage(playerid, 0x00FF00FF, "Health regeneration timer restarted (5 second interval).");
        } else {
            SendClientMessage(playerid, 0xFF0000FF, "Failed to restart timer.");
        }
        return 1;
    }

    if (strcmp("/timerinfo", cmdtext, true) == 0) {
        new count = Timer_GetActiveCount();
        new message[128];
        format(message, sizeof(message), "Active timers: %d", count);
        SendClientMessage(playerid, 0x00FFFFFF, message);

        if (IsValidTimerID(g_PlayerTimers[playerid])) {
            new delay = Timer_GetInfo(g_PlayerTimers[playerid]);
            if (delay != -1) {
                format(message, sizeof(message), "Your timer delay: %d ms", delay);
                SendClientMessage(playerid, 0x00FFFFFF, message);
            }
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
    if (IsPlayerConnected(playerid)) {
        new welcome_msg[128];
        format(welcome_msg, sizeof(welcome_msg), "Welcome %s! Type /testtimer to test the timer system.", GetPlayerNameEx(playerid));
        SendClientMessage(playerid, 0x00FF00FF, welcome_msg);
    }
}

forward OnPlayerHealthRegen(playerid);
public OnPlayerHealthRegen(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) {
        printf("ERROR: Invalid playerid %d in OnPlayerHealthRegen", playerid);
        return;
    }

    if (IsPlayerConnected(playerid)) {
        new Float:health;
        GetPlayerHealth(playerid, health);

        if (health < 100.0 && health > 0.0) {
            new Float:new_health = health + 10.0;
            if (new_health > 100.0) new_health = 100.0;

            SetPlayerHealth(playerid, new_health);

            new message[64];
            format(message, sizeof(message), "Health regenerated: %.1f", new_health);
            SendClientMessage(playerid, 0x00FF00FF, message);
        }
    }
}

forward OnTestTimer(playerid);
public OnTestTimer(playerid)
{
    printf("Test timer executed for player %d", playerid);

    if (IsPlayerConnected(playerid)) {
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
    GetPlayerName(playerid, name, sizeof(name));
    return name;
}
