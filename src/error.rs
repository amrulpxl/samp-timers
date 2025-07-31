use thiserror::Error;

#[derive(Error, Debug)]
pub enum TimerError {
    #[error("Invalid delay: {0}ms (must be positive)")]
    InvalidDelay(i32),

    #[error("Timer with ID {0} not found")]
    TimerNotFound(i32),

    #[error("Invalid callback name: '{0}' (empty or invalid)")]
    InvalidCallback(String),

    #[error("Failed to parse callback parameters: {0}")]
    ParameterParseError(String),

    #[error("Timer system is shutting down")]
    SystemShutdown,

    #[error("Failed to spawn timer task: {0}")]
    TaskSpawnError(String),

    #[error("Callback execution failed: {0}")]
    CallbackExecutionError(String),

    #[error("Timer ID overflow (too many timers created)")]
    IdOverflow,

    #[error("Internal error: {0}")]
    Internal(String),
}

impl TimerError {
    pub fn to_error_code(&self) -> i32 {
        match self {
            TimerError::InvalidDelay(_) => -1,
            TimerError::TimerNotFound(_) => -2,
            TimerError::InvalidCallback(_) => -3,
            TimerError::ParameterParseError(_) => -4,
            TimerError::SystemShutdown => -5,
            TimerError::TaskSpawnError(_) => -6,
            TimerError::CallbackExecutionError(_) => -7,
            TimerError::IdOverflow => -8,
            TimerError::Internal(_) => -99,
        }
    }

    pub fn to_user_message(&self) -> String {
        match self {
            TimerError::InvalidDelay(delay) => format!("Invalid delay: {}ms (must be positive)", delay),
            TimerError::TimerNotFound(id) => format!("Timer {} not found", id),
            TimerError::InvalidCallback(name) => format!("Invalid callback name: '{}'", name),
            TimerError::ParameterParseError(msg) => format!("Parameter error: {}", msg),
            TimerError::SystemShutdown => "Timer system is shutting down".to_string(),
            TimerError::TaskSpawnError(msg) => format!("Task spawn error: {}", msg),
            TimerError::CallbackExecutionError(msg) => format!("Callback error: {}", msg),
            TimerError::IdOverflow => "Too many timers created".to_string(),
            TimerError::Internal(msg) => format!("Internal error: {}", msg),
        }
    }
}

pub type TimerResult<T> = Result<T, TimerError>;
