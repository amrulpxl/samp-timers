use crate::error::{TimerError, TimerResult};
use crate::amx_manager::AmxManager;

const MAX_CALLBACK_PARAMS: usize = 16;
const MAX_STRING_PARAM_LENGTH: usize = 1024;

#[derive(Debug, Clone)]
pub enum CallbackParam {
    Integer(i32),
    Float(f32),
    String(String),
}

impl CallbackParam {
    pub fn validate(&self) -> TimerResult<()> {
        match self {
            CallbackParam::String(s) => {
                if s.len() > MAX_STRING_PARAM_LENGTH {
                    return Err(TimerError::ParameterValidation(
                        format!("String parameter too long: {} > {} chars", s.len(), MAX_STRING_PARAM_LENGTH)
                    ));
                }
            }
            CallbackParam::Float(f) => {
                if !f.is_finite() {
                    return Err(TimerError::ParameterValidation(
                        "Float parameter must be finite (not NaN or infinite)".to_string()
                    ));
                }
            }
            CallbackParam::Integer(_) => {} /* always valid */
        }
        Ok(())
    }
}

#[derive(Debug, Clone)]
pub struct CallbackData {
    pub params: Vec<CallbackParam>,
}

impl CallbackData {
    pub fn new() -> Self {
        CallbackData {
            params: Vec::with_capacity(4), /* pre-allocate for common case */
        }
    }

    pub fn with_capacity(capacity: usize) -> Self {
        if capacity <= 4 {
            Self::new()
        } else {
            CallbackData {
                params: Vec::with_capacity(capacity.min(MAX_CALLBACK_PARAMS)),
            }
        }
    }

    pub fn add_param(&mut self, param: CallbackParam) -> TimerResult<()> {
        if self.params.len() >= MAX_CALLBACK_PARAMS {
            return Err(TimerError::ParameterValidation(
                format!("Too many parameters: {} > {}", self.params.len() + 1, MAX_CALLBACK_PARAMS)
            ));
        }

        param.validate()?;
        self.params.push(param);
        Ok(())
    }

    pub fn validate(&self) -> TimerResult<()> {
        for param in &self.params {
            param.validate()?;
        }
        Ok(())
    }
}

pub async fn execute_callback(
    callback_name: &str,
    params: &Option<CallbackData>,
) -> TimerResult<()> {
    if callback_name.trim().is_empty() {
        return Err(TimerError::InvalidCallback(callback_name.to_string()));
    }

    if let Some(callback_data) = params {
        callback_data.validate()?;
    }

    tracing::debug!("Executing callback: {} with {} parameters",
                   callback_name,
                   params.as_ref().map_or(0, |p| p.params.len()));

    let execution_start = std::time::Instant::now();

    if !AmxManager::has_instances() {
        tracing::warn!("No AMX instances available, simulating callback execution for: {}", callback_name);

        match params {
            Some(callback_data) => {
                tracing::trace!("Simulated callback {} parameters:", callback_name);
                for (i, param) in callback_data.params.iter().enumerate() {
                    match param {
                        CallbackParam::Integer(val) => {
                            tracing::trace!("  [{}]: integer = {}", i, val);
                        }
                        CallbackParam::Float(val) => {
                            tracing::trace!("  [{}]: float = {:.6}", i, val);
                        }
                        CallbackParam::String(val) => {
                            tracing::trace!("  [{}]: string = '{}' (len={})", i, val, val.len());
                        }
                    }
                }
            }
            None => {
                tracing::trace!("Simulated callback {} has no parameters", callback_name);
            }
        }
    } else {
        tracing::debug!("Executing actual SAMP callback: {}", callback_name);

        match AmxManager::execute_callback(callback_name, params) {
            Ok(return_value) => {
                tracing::debug!("Callback {} returned: {}", callback_name, return_value);
            }
            Err(e) => {
                tracing::error!("Callback {} execution failed: {}", callback_name, e);
                return Err(e);
            }
        }
    }

    let execution_time = execution_start.elapsed();
    tracing::debug!("Callback {} completed in {:?}", callback_name, execution_time);

    if execution_time.as_millis() > 10 {
        tracing::warn!("Slow callback execution: {} took {:?}", callback_name, execution_time);
    }

    Ok(())
}

pub fn is_valid_callback_name(name: &str) -> bool {
    if name != name.trim() {
        return false;
    }

    if name.is_empty() {
        return false;
    }

    if name.len() > 64 {
        return false;
    }

    if let Some(first_char) = name.chars().next() {
        if !first_char.is_alphabetic() && first_char != '_' {
            return false;
        }
    } else {
        return false;
    }

    name.chars().all(|c| c.is_alphanumeric() || c == '_')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_callback_name_validation() {
        assert!(is_valid_callback_name("ValidCallback"));
        assert!(is_valid_callback_name("_private_callback"));
        assert!(is_valid_callback_name("callback123"));
        assert!(is_valid_callback_name("OnPlayerConnect"));
        
        assert!(!is_valid_callback_name(""));
        assert!(!is_valid_callback_name("123invalid"));
        assert!(!is_valid_callback_name("invalid-name"));
        assert!(!is_valid_callback_name("invalid name"));
        assert!(!is_valid_callback_name("   ")); 
    }

    #[test]
    fn test_callback_data_creation() {
        let mut data = CallbackData::new();
        assert_eq!(data.params.len(), 0);

        data.add_param(CallbackParam::Integer(42)).expect("Failed to add integer param");
        data.add_param(CallbackParam::Float(3.14)).expect("Failed to add float param");
        data.add_param(CallbackParam::String("test".to_string())).expect("Failed to add string param");

        assert_eq!(data.params.len(), 3);
    }

    #[test]
    fn test_callback_data_with_capacity() {
        let mut data = CallbackData::with_capacity(2);
        assert_eq!(data.params.len(), 0);
        assert!(data.params.capacity() >= 2);

        data.add_param(CallbackParam::Integer(100)).expect("Failed to add integer param");
        data.add_param(CallbackParam::String("capacity_test".to_string())).expect("Failed to add string param");

        assert_eq!(data.params.len(), 2);

        let data_new = CallbackData::new();
        assert_eq!(data_new.params.len(), 0);
    }

    #[test]
    fn test_edge_case_callback_names() {
        let long_name = "a".repeat(65);
        assert!(!is_valid_callback_name(&long_name));
        
        let exact_name = "a".repeat(64);
        assert!(is_valid_callback_name(&exact_name));
        
        assert!(is_valid_callback_name("a"));
        assert!(is_valid_callback_name("_"));
        assert!(!is_valid_callback_name("1abc"));
        assert!(!is_valid_callback_name("-abc"));
        assert!(!is_valid_callback_name(" abc")); //leading space should be invalid
        assert!(!is_valid_callback_name("abc ")); //trailing space should be invalid
        assert!(!is_valid_callback_name(" abc ")); //both spaces should be invalid
    }
}
