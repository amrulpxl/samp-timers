use std::collections::HashMap;
use std::sync::Arc;
use parking_lot::RwLock;
use samp::prelude::*;
use crate::error::{TimerError, TimerResult};
use crate::callback::{CallbackData, CallbackParam};

/* thread-safe wrapper for AMX pointer */
struct AmxWrapper(*mut Amx);
unsafe impl Send for AmxWrapper {}
unsafe impl Sync for AmxWrapper {}

/* global AMX instance storage */
lazy_static::lazy_static! {
    static ref AMX_INSTANCES: Arc<RwLock<HashMap<usize, AmxWrapper>>> = Arc::new(RwLock::new(HashMap::new()));
}

pub struct AmxManager;

impl AmxManager {
    pub fn register_amx(amx: &Amx) {
        let amx_ptr = amx as *const Amx as *mut Amx;
        let amx_id = amx_ptr as usize;

        if amx_ptr.is_null() {
            return;
        }

        {
            let instances = AMX_INSTANCES.read();
            if instances.contains_key(&amx_id) {
                return; 
            }
        }

        let mut instances = AMX_INSTANCES.write();

        if !instances.contains_key(&amx_id) {
            instances.insert(amx_id, AmxWrapper(amx_ptr));
            tracing::debug!("Registered new AMX instance: {:p}", amx_ptr);
        }
    }
    
    pub fn execute_callback(callback_name: &str, params: &Option<CallbackData>) -> TimerResult<i32> {
        if callback_name.is_empty() {
            return Err(TimerError::InvalidCallback("Empty callback name".to_string()));
        }

        let amx_ptr = {
            let instances = AMX_INSTANCES.read();
            if instances.is_empty() {
                return Err(TimerError::Internal("No AMX instances available".to_string()));
            }

            let amx_wrapper = instances.values().next()
                .ok_or_else(|| TimerError::Internal("Failed to get AMX instance".to_string()))?;

            if amx_wrapper.0.is_null() {
                return Err(TimerError::Internal("AMX instance pointer is null".to_string()));
            }

            amx_wrapper.0
        }; 

        unsafe {
            let amx_ref = amx_ptr.as_ref()
                .ok_or_else(|| TimerError::Internal("AMX instance reference is invalid".to_string()))?;

            Self::execute_callback_on_amx(amx_ref, callback_name, params)
        }
    }
    
    unsafe fn execute_callback_on_amx(amx: &Amx, callback_name: &str, params: &Option<CallbackData>) -> TimerResult<i32> {
        if callback_name.is_empty() || callback_name.len() > 64 {
            return Err(TimerError::InvalidCallback(
                format!("Callback name '{}' is invalid", callback_name)
            ));
        }

        let callback_index = match amx.find_public(callback_name) {
            Ok(index) => index,
            Err(_) => {
                return Err(TimerError::CallbackExecutionError(
                    format!("Callback function '{}' not found", callback_name)
                ));
            }
        };

        if let Some(callback_data) = params {
            if callback_data.params.len() > 16 {
                return Err(TimerError::ParameterValidation(
                    "Too many parameters".to_string()
                ));
            }

            for param in callback_data.params.iter().rev() {
                match param {
                    CallbackParam::Integer(val) => {
                        if let Err(e) = amx.push(*val) {
                            return Err(TimerError::CallbackExecutionError(
                                format!("Failed to push integer: {:?}", e)
                            ));
                        }
                    }
                    CallbackParam::Float(val) => {
                        if !val.is_finite() {
                            return Err(TimerError::ParameterValidation("Invalid float".to_string()));
                        }
                        if let Err(e) = amx.push(*val) {
                            return Err(TimerError::CallbackExecutionError(
                                format!("Failed to push float: {:?}", e)
                            ));
                        }
                    }
                    CallbackParam::String(val) => {
                        if val.len() > 1024 {
                            return Err(TimerError::ParameterValidation("String too long".to_string()));
                        }

                        let allocator = amx.allocator();
                        match allocator.allot_string(val) {
                            Ok(amx_string) => {
                                if let Err(e) = amx.push(amx_string) {
                                    return Err(TimerError::CallbackExecutionError(
                                        format!("Failed to push string: {:?}", e)
                                    ));
                                }
                            }
                            Err(e) => {
                                return Err(TimerError::CallbackExecutionError(
                                    format!("Failed to allocate string: {:?}", e)
                                ));
                            }
                        }
                    }
                }
            }
        }

        match amx.exec(callback_index) {
            Ok(return_value) => {
                tracing::trace!("Callback '{}' executed successfully", callback_name);
                Ok(return_value)
            }
            Err(e) => {
                tracing::warn!("Callback '{}' execution failed: {:?}", callback_name, e);
                Err(TimerError::CallbackExecutionError(
                    format!("Callback execution failed: {:?}", e)
                ))
            }
        }
    }
    
    pub fn instance_count() -> usize {
        AMX_INSTANCES.read().len()
    }

    pub fn has_instances() -> bool {
        !AMX_INSTANCES.read().is_empty()
    }

    pub fn clear_all_instances() {
        let mut instances = AMX_INSTANCES.write();
        let count = instances.len();
        instances.clear();
        tracing::debug!("Cleared {} AMX instances", count);
    }
}
