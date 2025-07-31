# Timers Plugin

Timer plugins for SA-MP servers built with Rust.

## Installation

### Prerequisites

- Rust compiler (1.70+) with i686 target support
- SA-MP server (0.3.7 or later)

### Building

1. Clone or download this repository
2. Install Rust i686 target: `rustup target add i686-pc-windows-msvc` (Windows) or `rustup target add i686-unknown-linux-gnu` (Linux)
3. Build the plugin:

```bash
# For Windows
cargo build --release --target i686-pc-windows-msvc

# For Linux
cargo build --release --target i686-unknown-linux-gnu
```

4. Copy the compiled plugin:
   - Windows: `target/i686-pc-windows-msvc/release/timers.dll` → `plugins/timers.dll`
   - Linux: `target/i686-unknown-linux-gnu/release/libtimers.so` → `plugins/timers.so`

5. Copy `timers.inc` to your `pawno/include/` directory

6. Add to your `server.cfg`:
   ```
   plugins timers
   ```

## API Reference

### Functions

#### `Timer_Set(delay_ms, bool:repeat, const callback[])`
Creates a new timer with specified delay and repeat behavior.

- **delay_ms**: Delay in milliseconds (must be positive)
- **repeat**: Whether the timer should repeat
- **callback**: Name of the callback function
- **Returns**: Timer ID on success, negative error code on failure

#### `Timer_SetEx(delay_ms, bool:repeat, const callback[], const format[], ...)`
Creates a timer with parameters for the callback.

- **format**: Parameter format string (`i`=integer, `f`=float, `s`=string)
- **...**: Parameters to pass to the callback

#### `Timer_SetOnce(delay_ms, const callback[])`
Convenience function for creating one-shot timers.

#### `Timer_SetOnceEx(delay_ms, const callback[], const format[], ...)`
One-shot timer with parameters.

#### `Timer_Kill(timerid)`
Kills/stops a timer by its ID.

- **Returns**: `true` if successful, `false` otherwise

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| -1 | `TIMER_ERROR_INVALID_DELAY` | Invalid delay (must be positive) |
| -2 | `TIMER_ERROR_NOT_FOUND` | Timer not found |
| -3 | `TIMER_ERROR_INVALID_CALLBACK` | Invalid callback name |
| -4 | `TIMER_ERROR_PARAM_PARSE` | Failed to parse parameters |
| -5 | `TIMER_ERROR_SYSTEM_SHUTDOWN` | System shutting down |
| -6 | `TIMER_ERROR_TASK_SPAWN` | Failed to spawn timer task |
| -7 | `TIMER_ERROR_CALLBACK_EXEC` | Callback execution failed |
| -8 | `TIMER_ERROR_ID_OVERFLOW` | Timer ID overflow |
| -99 | `TIMER_ERROR_INTERNAL` | Internal error |

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
