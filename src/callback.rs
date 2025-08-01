use crate::error::{TimerError, TimerResult};

#[derive(Debug, Clone)]
pub enum CallbackParam {
    Integer(i32),
    Float(f32),
    String(String),
}

#[derive(Debug, Clone)]
pub struct CallbackData {
    pub params: Vec<CallbackParam>,
}

impl CallbackData {
    pub fn new() -> Self {
        CallbackData {
            params: Vec::new(),
        }
    }

    pub fn add_param(&mut self, param: CallbackParam) {
        self.params.push(param);
    }
}

pub async fn execute_callback(
    callback_name: &str,
    params: &Option<CallbackData>,
) -> TimerResult<()> {
    if callback_name.trim().is_empty() {
        return Err(TimerError::InvalidCallback(callback_name.to_string()));
    }

    println!("--- EXECUTING CALLBACK: {} ---", callback_name);
    tracing::info!("--- EXECUTING CALLBACK: {} ---", callback_name);

    match params {
        Some(callback_data) => {
            println!("TIMER CALLBACK: {} with {} parameters", callback_name, callback_data.params.len());
            tracing::info!("TIMER CALLBACK: {} with {} parameters", callback_name, callback_data.params.len());

            for (i, param) in callback_data.params.iter().enumerate() {
                match param {
                    CallbackParam::Integer(val) => {
                        println!("  Parameter {}: integer = {}", i, val);
                        tracing::info!("  Parameter {}: integer = {}", i, val);
                    }
                    CallbackParam::Float(val) => {
                        println!("  Parameter {}: float = {:.6}", i, val);
                        tracing::info!("  Parameter {}: float = {:.6}", i, val);
                    }
                    CallbackParam::String(val) => {
                        println!("  Parameter {}: string = '{}'", i, val);
                        tracing::info!("  Parameter {}: string = '{}'", i, val);
                    }
                }
            }
        }
        None => {
            println!("TIMER CALLBACK: {} (no parameters)", callback_name);
            tracing::info!("TIMER CALLBACK: {} (no parameters)", callback_name);
        }
    }

    tokio::time::sleep(tokio::time::Duration::from_millis(1)).await;

    println!("--- CALLBACK COMPLETED: {} ---", callback_name);
    tracing::info!("--- CALLBACK COMPLETED: {} ---", callback_name);
    Ok(())
}

pub fn is_valid_callback_name(name: &str) -> bool {
    if name != name.trim() {
        return false;
    }

    let trimmed = name.trim();

    if trimmed.is_empty() {
        return false;
    }

    if trimmed.len() > 64 {
        return false;
    }

    if let Some(first_char) = trimmed.chars().next() {
        if !first_char.is_alphabetic() && first_char != '_' {
            return false;
        }
    } else {
        return false;
    }
    trimmed.chars().all(|c| c.is_alphanumeric() || c == '_')
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
        
        data.add_param(CallbackParam::Integer(42));
        data.add_param(CallbackParam::Float(3.14));
        data.add_param(CallbackParam::String("test".to_string()));
        
        assert_eq!(data.params.len(), 3);
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
