/*
 * SA-MP Timers Plugin Include File
 * Version: 1.0.2
 * 
 * Features:
 * - Async timer execution with tokio runtime
 * - Thread-safe timer management
 * - Support for both repeating and one-shot timers
 * - Parameter passing to callback functions (integer, float, string)
 * - Automatic cleanup of expired timers
 * 
 * Author: Amrul
 * License: MIT
 */

#if defined _timers_included
    #endinput
#endif
#define _timers_included

/*
 * Timer Error Codes
 */
#define TIMER_ERROR_INVALID_DELAY    -1  /* Invalid delay (must be positive and <= 2147483647) */
#define TIMER_ERROR_NOT_FOUND        -2  /* Timer with specified ID not found */
#define TIMER_ERROR_INVALID_CALLBACK -3  /* Invalid callback name (must be valid identifier, max 64 chars) */
#define TIMER_ERROR_PARAM_PARSE      -4  /* Failed to parse callback parameters */
#define TIMER_ERROR_SYSTEM_SHUTDOWN  -5  /* Timer system is shutting down */
#define TIMER_ERROR_TASK_SPAWN       -6  /* Failed to spawn timer task */
#define TIMER_ERROR_CALLBACK_EXEC    -7  /* Callback execution failed */
#define TIMER_ERROR_ID_OVERFLOW      -8  /* Timer ID overflow (too many timers created) */
#define TIMER_ERROR_EXECUTION_TIMEOUT -9 /* Timer execution timeout */
#define TIMER_ERROR_RESOURCE_EXHAUSTION -10 /* Resource exhaustion (too many timers) */
#define TIMER_ERROR_PARAM_VALIDATION -11 /* Parameter validation failed */
#define TIMER_ERROR_INTERNAL         -99 /* Internal error */

/*
 * Parameter Type Constants
 */
#define TIMER_PARAM_INTEGER          0   // Integer parameter
#define TIMER_PARAM_FLOAT            1   // Float parameter  
#define TIMER_PARAM_STRING           2   // String parameter

/*
 * Native function declarations
 */

/**
 * Creates a new timer with specified delay and repeat behavior
 * 
 * @param delay_ms   Delay in milliseconds (must be positive)
 * @param repeat     Whether the timer should repeat (true) or run once (false)
 * @param callback   Name of the callback function to execute
 * @return           Timer ID on success, negative error code on failure
 */
native Timer_Set(delay_ms, bool:repeat, const callback[]);

/**
 * Creates a new timer with typed parameters for the callback
 *
 * @param delay_ms     Delay in milliseconds (must be positive)
 * @param repeat       Whether the timer should repeat (true) or run once (false)
 * @param callback     Name of the callback function to execute
 * @param param_type   Parameter type (TIMER_PARAM_INTEGER/FLOAT/STRING)
 * @param int_param    Integer parameter (used if param_type=TIMER_PARAM_INTEGER)
 * @param float_param  Float parameter (used if param_type=TIMER_PARAM_FLOAT)
 * @param string_param String parameter (used if param_type=TIMER_PARAM_STRING)
 * @return             Timer ID on success, negative error code on failure
 */
native Timer_SetEx(delay_ms, bool:repeat, const callback[], param_type, int_param, Float:float_param, const string_param[]);

/**
 * Creates a one-shot timer (convenience function)
 * 
 * @param delay_ms   Delay in milliseconds (must be positive)
 * @param callback   Name of the callback function to execute
 * @return           Timer ID on success, negative error code on failure
 */
native Timer_SetOnce(delay_ms, const callback[]);

/**
 * Creates a one-shot timer with typed parameters
 *
 * @param delay_ms     Delay in milliseconds (must be positive)
 * @param callback     Name of the callback function to execute
 * @param param_type   Parameter type (TIMER_PARAM_INTEGER/FLOAT/STRING)
 * @param int_param    Integer parameter (used if param_type=TIMER_PARAM_INTEGER)
 * @param float_param  Float parameter (used if param_type=TIMER_PARAM_FLOAT)
 * @param string_param String parameter (used if param_type=TIMER_PARAM_STRING)
 * @return             Timer ID on success, negative error code on failure
 */
native Timer_SetOnceEx(delay_ms, const callback[], param_type, int_param, Float:float_param, const string_param[]);

/**
 * Kills/stops a timer by its ID
 *
 * @param timerid    ID of the timer to kill
 * @return           true if timer was killed successfully, false otherwise
 */
native Timer_Kill(timerid);

/**
 * Gets the number of currently active timers
 *
 * @return           Number of active timers
 */
native Timer_GetActiveCount();

/**
 * Gets the number of registered AMX instances for callback execution
 *
 * @return           Number of AMX instances available for callbacks
 */
native Timer_GetAmxInstanceCount();

/**
 * Gets information about a timer
 *
 * @param timerid    ID of the timer to query
 * @return           Timer delay in milliseconds, or -1 if timer not found
 */
native Timer_GetInfo(timerid);

/*
 * Utility macros and functions
 */

/**
 * Check if a timer operation was successful
 */
#define IsValidTimerID(%0) (%0 > 0)

/**
 * Check if a timer operation failed
 */
#define IsTimerError(%0) (%0 < 0)

/**
 * Get error message for timer error code
 */
stock GetTimerErrorMessage(error_code)
{
    new message[128];
    switch(error_code)
    {
        case TIMER_ERROR_INVALID_DELAY: format(message, sizeof(message), "Invalid delay (must be positive and <= 2147483647)");
        case TIMER_ERROR_NOT_FOUND: format(message, sizeof(message), "Timer not found");
        case TIMER_ERROR_INVALID_CALLBACK: format(message, sizeof(message), "Invalid callback name (must be valid identifier, max 64 chars)");
        case TIMER_ERROR_PARAM_PARSE: format(message, sizeof(message), "Failed to parse parameters");
        case TIMER_ERROR_SYSTEM_SHUTDOWN: format(message, sizeof(message), "Timer system is shutting down");
        case TIMER_ERROR_TASK_SPAWN: format(message, sizeof(message), "Failed to spawn timer task");
        case TIMER_ERROR_CALLBACK_EXEC: format(message, sizeof(message), "Callback execution failed");
        case TIMER_ERROR_ID_OVERFLOW: format(message, sizeof(message), "Timer ID overflow (too many timers created)");
        case TIMER_ERROR_RESOURCE_EXHAUSTION: format(message, sizeof(message), "Resource exhaustion (too many timers)");
        case TIMER_ERROR_PARAM_VALIDATION: format(message, sizeof(message), "Parameter validation failed");
        case TIMER_ERROR_INTERNAL: format(message, sizeof(message), "Internal error");
        default: format(message, sizeof(message), "Unknown error (%d)", error_code);
    }
    return message;
}

/*
 * Additional utility functions for better timer management
 */

/**
 * Check if an error code indicates a recoverable error
 */
stock bool:IsTimerErrorRecoverable(error_code)
{
    switch(error_code)
    {
        case TIMER_ERROR_NOT_FOUND, TIMER_ERROR_CALLBACK_EXEC, TIMER_ERROR_EXECUTION_TIMEOUT:
            return true;
        default:
            return false;
    }
}

/**
 * Validate timer delay before creating timer
 */
stock bool:IsValidTimerDelay(delay_ms)
{
    return (delay_ms > 0 && delay_ms <= 2147483647);
}

/**
 * Create a timer with automatic error handling and logging
 */
stock CreateTimerSafe(delay_ms, bool:repeat, const callback[], bool:log_errors = true)
{
    new timer_id = Timer_Set(delay_ms, repeat, callback);

    if (IsTimerError(timer_id) && log_errors) {
        printf("[TIMER ERROR] Failed to create timer '%s': %s", callback, GetTimerErrorMessage(timer_id));
    }

    return timer_id;
}

/**
 * Create a timer with parameters and automatic error handling
 */
stock CreateTimerExSafe(delay_ms, bool:repeat, const callback[], param_type, int_param, Float:float_param, const string_param[], bool:log_errors = true)
{
    new timer_id = Timer_SetEx(delay_ms, repeat, callback, param_type, int_param, float_param, string_param);

    if (IsTimerError(timer_id) && log_errors) {
        printf("[TIMER ERROR] Failed to create timer '%s' with parameters: %s", callback, GetTimerErrorMessage(timer_id));
    }

    return timer_id;
}
