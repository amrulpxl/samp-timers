use thiserror::Error;

#[derive(Error, Debug, Clone)]
pub enum TimerError {
    #[error("Invalid delay: {0}ms (must be positive and <= 2147483647)")]
    InvalidDelay(i32),

    #[error("Timer with ID {0} not found")]
    TimerNotFound(i32),

    #[error("Invalid callback name: '{0}' (must be valid identifier, max 64 chars)")]
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

    #[error("Resource exhaustion: {0}")]
    ResourceExhaustion(String),

    #[error("Parameter validation failed: {0}")]
    ParameterValidation(String),

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
            TimerError::ResourceExhaustion(_) => -10,
            TimerError::ParameterValidation(_) => -11,
            TimerError::Internal(_) => -99,
        }
    }

    pub fn to_user_message(&self) -> String {
        self.to_string()
    }

    pub fn is_recoverable(&self) -> bool {
        match self {
            TimerError::InvalidDelay(_)
            | TimerError::InvalidCallback(_)
            | TimerError::ParameterParseError(_)
            | TimerError::ParameterValidation(_) => false,

            TimerError::TimerNotFound(_)
            | TimerError::CallbackExecutionError(_) => true,

            TimerError::SystemShutdown
            | TimerError::TaskSpawnError(_)
            | TimerError::IdOverflow
            | TimerError::ResourceExhaustion(_)
            | TimerError::Internal(_) => false,
        }
    }
}

pub type TimerResult<T> = Result<T, TimerError>;
