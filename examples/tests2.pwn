#include <a_samp>
#include <timers>

#if !defined _timers_included
    #error "This gamemode requires timers.inc to be included"
#endif

main(){}

#define MAX_TEST_TIMERS 10
new g_TestTimers[MAX_TEST_TIMERS] = {-1, ...};
new g_TestCounter = 0;

public OnGameModeInit()
{
    printf("[TEST 1] Creating timer with integer parameter...");
    g_TestTimers[0] = Timer_SetOnceEx(2000, "MyIntegerCallback", 0, 42, 0.0, "");
    if (IsValidTimerID(g_TestTimers[0])) {
        printf("SUCCESS: Integer timer created with ID %d", g_TestTimers[0]);
    } else {
        printf("FAILED: Integer timer creation failed: %s", GetTimerErrorMessage(g_TestTimers[0]));
    }
    
    printf("[TEST 2] Creating timer with float parameter...");
    g_TestTimers[1] = Timer_SetOnceEx(3000, "MyFloatCallback", 1, 0, 3.14159265, "");
    if (IsValidTimerID(g_TestTimers[1])) {
        printf("SUCCESS: Float timer created with ID %d", g_TestTimers[1]);
    } else {
        printf("FAILED: Float timer creation failed: %s", GetTimerErrorMessage(g_TestTimers[1]));
    }
    
    printf("[TEST 3] Creating timer with string parameter...");
    g_TestTimers[2] = Timer_SetOnceEx(4000, "MyStringCallback", 2, 0, 0.0, "Hello World from Timer!");
    if (IsValidTimerID(g_TestTimers[2])) {
        printf("SUCCESS: String timer created with ID %d", g_TestTimers[2]);
    } else {
        printf("FAILED: String timer creation failed: %s", GetTimerErrorMessage(g_TestTimers[2]));
    }
    
    printf("[TEST 4] Creating timer with no parameters...");
    g_TestTimers[3] = Timer_SetOnce(5000, "MyNoParameterCallback");
    if (IsValidTimerID(g_TestTimers[3])) {
        printf("SUCCESS: No-parameter timer created with ID %d", g_TestTimers[3]);
    } else {
        printf("FAILED: No-parameter timer creation failed: %s", GetTimerErrorMessage(g_TestTimers[3]));
    }
    
    printf("[TEST 5] Creating repeating timer with integer parameter...");
    g_TestTimers[4] = Timer_SetEx(6000, true, "MyRepeatingCallback", 0, 100, 0.0, "");
    if (IsValidTimerID(g_TestTimers[4])) {
        printf("SUCCESS: Repeating timer created with ID %d", g_TestTimers[4]);
    } else {
        printf("FAILED: Repeating timer creation failed: %s", GetTimerErrorMessage(g_TestTimers[4]));
    }
    
    printf("[TEST 6] Creating timer with mixed parameter types...");
    g_TestTimers[5] = Timer_SetOnceEx(7000, "MyMixedParametersCallback", 0, 999, 0.0, "");
    g_TestTimers[6] = Timer_SetOnceEx(7500, "MyMixedParametersCallback", 1, 0, 2.71828, "");
    g_TestTimers[7] = Timer_SetOnceEx(8000, "MyMixedParametersCallback", 2, 0, 0.0, "Mixed Test");
    
    printf("[TEST 7] Creating timer with edge case values...");
    g_TestTimers[8] = Timer_SetOnceEx(9000, "MyEdgeCaseCallback", 0, 2147483647, 0.0, ""); // MAX_INT
    
    printf("[TEST 8] Testing error cases...");
    new error_timer1 = Timer_Set(-1000, false, "InvalidDelay"); 
    printf("Expected error for negative delay: %s", GetTimerErrorMessage(error_timer1));
    
    new error_timer2 = Timer_Set(1000, false, ""); 
    printf("Expected error for empty callback: %s", GetTimerErrorMessage(error_timer2));
    
    new error_timer3 = Timer_Set(1000, false, "123InvalidName"); 
    printf("Expected error for invalid callback name: %s", GetTimerErrorMessage(error_timer3));
    
    printf("[TEST 9] Testing timer management functions...");
    printf("Active timer count: %d", Timer_GetActiveCount());
    
    if (IsValidTimerID(g_TestTimers[0])) {
        new delay = Timer_GetInfo(g_TestTimers[0]);
        printf("Timer %d info - delay: %d ms", g_TestTimers[0], delay);
    }
    printf("Watch console for callback executions...");  
    return 1;
}

public OnGameModeExit()
{
    for (new i = 0; i < MAX_TEST_TIMERS; i++) {
        if (IsValidTimerID(g_TestTimers[i])) {
            if (Timer_Kill(g_TestTimers[i])) {
                printf("Killed timer %d", g_TestTimers[i]);
                g_TestTimers[i] = -1;
            }
        }
    }
    printf("Cleanup complete. Final active count: %d", Timer_GetActiveCount());
    return 1;
}

public OnPlayerConnect(playerid)
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) {
        printf("ERROR: Invalid playerid %d in OnPlayerConnect", playerid);
        return 0;
    }

    printf("[PLAYER EVENT] Player %d connected, creating personalized timer...", playerid);
    new personal_timer = Timer_SetOnceEx(1000, "MyPlayerSpecificCallback", 0, playerid, 0.0, "");
    if (IsValidTimerID(personal_timer)) {
        printf("Created personal timer %d for player %d", personal_timer, playerid);
    } else {
        printf("Failed to create personal timer for player %d: %s", playerid, GetTimerErrorMessage(personal_timer));
    }
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (playerid < 0 || playerid >= MAX_PLAYERS) {
        printf("ERROR: Invalid playerid %d in OnPlayerCommandText", playerid);
        return 0;
    }

    if (strcmp("/testdebug", cmdtext, true) == 0) {
        printf("[DEBUG CMD] Player %d requested debug test", playerid);
        
        new debug_timer = Timer_SetOnceEx(500, "MyDebugCallback", 0, playerid, 0.0, "");
        if (IsValidTimerID(debug_timer)) {
            SendClientMessage(playerid, 0x00FF00FF, "Debug timer created! Check console.");
            printf("Debug timer %d created for player %d", debug_timer, playerid);
        } else {
            SendClientMessage(playerid, 0xFF0000FF, "Failed to create debug timer!");
            printf("Failed to create debug timer for player %d: %s", playerid, GetTimerErrorMessage(debug_timer));
        }
        return 1;
    }
    
    if (strcmp("/killall", cmdtext, true) == 0) {
        printf("[KILL CMD] Player %d requested to kill all test timers", playerid);
        new killed_count = 0;
        
        for (new i = 0; i < MAX_TEST_TIMERS; i++) {
            if (IsValidTimerID(g_TestTimers[i])) {
                if (Timer_Kill(g_TestTimers[i])) {
                    killed_count++;
                    g_TestTimers[i] = -1;
                }
            }
        }
        
        new message[128];
        format(message, sizeof(message), "Killed %d timers. Active count: %d", killed_count, Timer_GetActiveCount());
        SendClientMessage(playerid, 0xFFFF00FF, message);
        printf("[KILL CMD] %s", message);
        return 1;
    }
    
    if (strcmp("/timerinfo", cmdtext, true) == 0) {
        printf("[INFO CMD] Player %d requested timer information", playerid);
        new active_count = Timer_GetActiveCount();
        
        new message[128];
        format(message, sizeof(message), "Active timers: %d", active_count);
        SendClientMessage(playerid, 0x00FFFFFF, message);
        
        printf("[INFO CMD] Current active timer count: %d", active_count);
        
        for (new i = 0; i < MAX_TEST_TIMERS; i++) {
            if (IsValidTimerID(g_TestTimers[i])) {
                new delay = Timer_GetInfo(g_TestTimers[i]);
                if (delay != -1) {
                    printf("[INFO CMD] Timer slot %d: ID=%d, delay=%dms (ACTIVE)", i, g_TestTimers[i], delay);
                } else {
                    printf("[INFO CMD] Timer slot %d: ID=%d (COMPLETED/KILLED)", i, g_TestTimers[i]);
                }
            } else {
                printf("[INFO CMD] Timer slot %d: No timer", i);
            }
        }
        return 1;
    }
    
    if (strcmp("/sethp", cmdtext, true) == 0) {
        printf("[HP CMD] Player %d requested to set HP to 50", playerid);
        
        if (IsPlayerConnected(playerid)) {
            SetPlayerHealth(playerid, 50.0);
            SendClientMessage(playerid, 0x00FF00FF, "Your health has been set to 50 HP!");
            printf("[HP CMD] Set player %d health to 50.0", playerid);
        } else {
            SendClientMessage(playerid, 0xFF0000FF, "You are not connected!");
            printf("[HP CMD] Player %d is not connected", playerid);
        }
        return 1;
    }
    
    return 0;
}

forward MyIntegerCallback(value);
public MyIntegerCallback(value)
{
    printf("Received integer parameter: %d", value);
    if (value == 42) {
        printf("Expected: 42, Actual: %d, Match: YES", value);
    } else {
        printf("Expected: 42, Actual: %d, Match: NO", value);
    }
}

forward MyFloatCallback(Float:value);
public MyFloatCallback(Float:value)
{
    printf("Received float parameter: %.8f", value);
    printf("Expected: ~3.14159265, Actual: %.8f", value);
    printf("Precision test: %.2f", value);
}

forward MyStringCallback(const message[]);
public MyStringCallback(const message[])
{
    printf("Received string parameter: '%s'", message);
    printf("String length: %d characters", strlen(message));
    if (strcmp(message, "Hello World from Timer!") == 0) {
        printf("Expected: 'Hello World from Timer!', Match: YES");
    } else {
        printf("Expected: 'Hello World from Timer!', Match: NO");
    }
}

forward MyNoParameterCallback();
public MyNoParameterCallback()
{
    printf("This callback should have no parameters");
    printf("Execution count: %d", ++g_TestCounter);
}

forward MyRepeatingCallback(counter);
public MyRepeatingCallback(counter)
{
    static repeat_count = 0;
    repeat_count++;
    
    printf("Repeat execution #%d", repeat_count);
    printf("Received counter parameter: %d", counter);
    
    if (repeat_count >= 3) {
        printf("Stopping repeating timer after 3 executions...");
        if (IsValidTimerID(g_TestTimers[4])) {
            Timer_Kill(g_TestTimers[4]);
            g_TestTimers[4] = -1;
            printf("Repeating timer killed successfully");
        }
    }
}

forward MyMixedParametersCallback(param_type);
public MyMixedParametersCallback(param_type)
{
    printf("Parameter type indicator: %d", param_type);

    switch(param_type) {
        case 0: printf("This should be an integer parameter test");
        case 1: printf("This should be a float parameter test");
        case 2: printf("This should be a string parameter test");
        default: printf("Unknown parameter type: %d", param_type);
    }
}

forward MyEdgeCaseCallback(large_number);
public MyEdgeCaseCallback(large_number)
{
    printf("Received large number: %d", large_number);
    printf("Expected: 2147483647 (MAX_INT)");
    if (large_number == 2147483647) {
        printf("Match: YES");
    } else {
        printf("Match: NO");
    }
    printf("Negative test: %d", (large_number < 0));
}

forward MyPlayerSpecificCallback(playerid);
public MyPlayerSpecificCallback(playerid)
{
    printf("Target player ID: %d", playerid);
    if (playerid >= 0 && playerid < MAX_PLAYERS && IsPlayerConnected(playerid)) {
        printf("Player connected: YES");
        new player_name[MAX_PLAYER_NAME];
        GetPlayerName(playerid, player_name, sizeof(player_name));
        printf("Player name: %s", player_name);
        SendClientMessage(playerid, 0x00FF00FF, "Your personal timer has executed!");
    } else {
        printf("Player %d is no longer connected", playerid);
    }
}

forward MyDebugCallback(playerid);
public MyDebugCallback(playerid)
{
    printf("Debug test for player: %d", playerid);
    printf("Current timestamp: %d", gettime());
    printf("Active timer count: %d", Timer_GetActiveCount());

    if (playerid >= 0 && playerid < MAX_PLAYERS && IsPlayerConnected(playerid)) {
        SendClientMessage(playerid, 0xFFFF00FF, "Debug callback executed successfully!");
        printf("Debug message sent to player %d", playerid);
    }
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

stock PrintTimerStats()
{
    printf("Active timers: %d", Timer_GetActiveCount());

    new valid_count = 0;
    for (new i = 0; i < MAX_TEST_TIMERS; i++) {
        if (IsValidTimerID(g_TestTimers[i])) {
            valid_count++;
            new delay = Timer_GetInfo(g_TestTimers[i]);
            printf("Test timer %d: ID=%d, delay=%dms", i, g_TestTimers[i], delay);
        }
    }

    printf("Valid test timers: %d/%d", valid_count, MAX_TEST_TIMERS);
}

stock GetTimerStatusString(timerid, dest[], max_len = sizeof(dest))
{
    if (!IsValidTimerID(timerid)) {
        format(dest, max_len, "Invalid timer ID");
        return 0;
    }
    
    new delay = Timer_GetInfo(timerid);
    if (delay == -1) {
        format(dest, max_len, "Timer not found");
        return 0;
    }
    
    format(dest, max_len, "Timer %d: %dms delay", timerid, delay);
    return 1;
}