use samp::prelude::*;
use samp::{initialize_plugin, native};

mod timer;
mod error;
mod callback;

use timer::TimerManager;
pub struct TimerPlugin {
    timer_manager: TimerManager,
}

#[derive(Debug, Clone, Copy)]
enum TimerParamType {
    Integer,
    Float,
    String,
}

impl TimerParamType {
    fn from_i32(val: i32) -> Option<Self> {
        match val {
            0 => Some(TimerParamType::Integer),
            1 => Some(TimerParamType::Float),
            2 => Some(TimerParamType::String),
            _ => None,
        }
    }
}

fn build_callback_data(param_type: TimerParamType, int_param: i32, float_param: f32, string_param: &str) -> callback::CallbackData {
    let mut callback_data = callback::CallbackData::new();
    match param_type {
        TimerParamType::Integer => callback_data.add_param(callback::CallbackParam::Integer(int_param)),
        TimerParamType::Float => callback_data.add_param(callback::CallbackParam::Float(float_param)),
        TimerParamType::String => callback_data.add_param(callback::CallbackParam::String(string_param.to_string())),
    }
    callback_data
}

impl SampPlugin for TimerPlugin {
    fn on_load(&mut self) {
        tracing::info!("Timers Plugin v1.0.1 has been loaded");
        tracing::info!("timer plugins initialized");
    }

    fn on_unload(&mut self) {
        tracing::info!("SA-MP Timers Plugin unloading...");
        self.timer_manager.shutdown();
        tracing::info!("All timers stopped and cleaned up");
    }
}

impl TimerPlugin {
    #[native(name = "Timer_Set")]
    pub fn timer_set(
        &mut self,
        _amx: &Amx,
        delay_ms: i32,
        repeat: bool,
        callback: AmxString,
    ) -> AmxResult<i32> {
        let callback_str = callback.to_string();
        if !callback::is_valid_callback_name(&callback_str) {
            tracing::error!("Invalid callback name: {}", callback_str);
            return Ok(crate::error::TimerError::InvalidCallback(callback_str).to_error_code());
        }
        match self.timer_manager.create_timer(delay_ms, repeat, callback_str, None) {
            Ok(timer_id) => {
                tracing::debug!("Created timer {} with delay {}ms, repeat: {}", timer_id, delay_ms, repeat);
                Ok(timer_id)
            }
            Err(e) => {
                tracing::error!("Failed to create timer: {}", e.to_user_message());
                Ok(e.to_error_code())
            }
        }
    }
    #[native(name = "Timer_SetEx")]
    pub fn timer_set_ex(
        &mut self,
        _amx: &Amx,
        delay_ms: i32,
        repeat: bool,
        callback: AmxString,
        param_type: i32, // 0=int, 1=float, 2=string
        int_param: i32,
        float_param: f32,
        string_param: AmxString,
    ) -> AmxResult<i32> {
        let callback_str = callback.to_string();
        if !callback::is_valid_callback_name(&callback_str) {
            tracing::error!("Invalid callback name: {}", callback_str);
            return Ok(crate::error::TimerError::InvalidCallback(callback_str).to_error_code());
        }
        let param_type_enum = match TimerParamType::from_i32(param_type) {
            Some(pt) => pt,
            None => {
                tracing::error!("Invalid parameter type: {}", param_type);
                return Ok(crate::error::TimerError::ParameterParseError("Invalid parameter type".to_string()).to_error_code());
            }
        };
        let callback_data = build_callback_data(param_type_enum, int_param, float_param, &string_param.to_string());
        match self.timer_manager.create_timer(delay_ms, repeat, callback_str, Some(callback_data)) {
            Ok(timer_id) => {
                tracing::debug!("Created timer {} with parameter type {}", timer_id, param_type);
                Ok(timer_id)
            }
            Err(e) => {
                tracing::error!("Failed to create timer with parameters: {}", e.to_user_message());
                Ok(e.to_error_code())
            }
        }
    }
    #[native(name = "Timer_SetOnce")]
    pub fn timer_set_once(
        &mut self,
        _amx: &Amx,
        delay_ms: i32,
        callback: AmxString,
    ) -> AmxResult<i32> {
        let callback_str = callback.to_string();
        if !callback::is_valid_callback_name(&callback_str) {
            tracing::error!("Invalid callback name: {}", callback_str);
            return Ok(crate::error::TimerError::InvalidCallback(callback_str).to_error_code());
        }
        match self.timer_manager.create_timer(delay_ms, false, callback_str, None) {
            Ok(timer_id) => {
                tracing::debug!("Created one-shot timer {} with delay {}ms", timer_id, delay_ms);
                Ok(timer_id)
            }
            Err(e) => {
                tracing::error!("Failed to create one-shot timer: {}", e.to_user_message());
                Ok(e.to_error_code())
            }
        }
    }
    #[native(name = "Timer_SetOnceEx")]
    pub fn timer_set_once_ex(
        &mut self,
        _amx: &Amx,
        delay_ms: i32,
        callback: AmxString,
        param_type: i32, // 0=int, 1=float, 2=string
        int_param: i32,
        float_param: f32,
        string_param: AmxString,
    ) -> AmxResult<i32> {
        let callback_str = callback.to_string();
        if !callback::is_valid_callback_name(&callback_str) {
            let error = crate::error::TimerError::InvalidCallback(callback_str);
            tracing::error!("Timer creation failed: {}", error.to_user_message());
            return Ok(error.to_error_code());
        }
        let param_type_enum = match TimerParamType::from_i32(param_type) {
            Some(pt) => pt,
            None => {
                tracing::error!("Invalid parameter type: {}", param_type);
                return Ok(crate::error::TimerError::ParameterParseError("Invalid parameter type".to_string()).to_error_code());
            }
        };
        let callback_data = build_callback_data(param_type_enum, int_param, float_param, &string_param.to_string());
        match self.timer_manager.create_timer(delay_ms, false, callback_str, Some(callback_data)) {
            Ok(timer_id) => {
                tracing::debug!("Created one-shot timer {} with parameter type {}", timer_id, param_type);
                Ok(timer_id)
            }
            Err(e) => {
                tracing::error!("Failed to create one-shot timer with parameters: {}", e.to_user_message());
                Ok(e.to_error_code())
            }
        }
    }
    #[native(name = "Timer_Kill")]
    pub fn timer_kill(&mut self, _amx: &Amx, timer_id: i32) -> AmxResult<bool> {
        match self.timer_manager.kill_timer(timer_id) {
            Ok(()) => {
                tracing::debug!("Successfully killed timer {}", timer_id);
                Ok(true)
            }
            Err(e) => {
                tracing::warn!("Failed to kill timer {}: {}", timer_id, e.to_user_message());
                Ok(false)
            }
        }
    }
    #[native(name = "Timer_GetActiveCount")]
    pub fn timer_get_active_count(&self, _amx: &Amx) -> AmxResult<i32> {
        let count = self.timer_manager.active_timer_count();
        tracing::debug!("Active timer count: {}", count);
        Ok(count as i32)
    }
    #[native(name = "Timer_GetInfo")]
    pub fn timer_get_info(&self, _amx: &Amx, timer_id: i32) -> AmxResult<i32> {
        match self.timer_manager.get_timer_info(timer_id) {
            Some((delay_ms, repeat, callback, elapsed)) => {
                tracing::debug!("Timer {} info: delay={}ms, repeat={}, callback={}, elapsed={:?}",
                               timer_id, delay_ms, repeat, callback, elapsed);
                Ok(delay_ms as i32)
            }
            None => {
                tracing::warn!("Timer {} not found", timer_id);
                Ok(-1)
            }
        }
    }

}

initialize_plugin!(
    natives: [
        TimerPlugin::timer_set,
        TimerPlugin::timer_set_ex,
        TimerPlugin::timer_set_once,
        TimerPlugin::timer_set_once_ex,
        TimerPlugin::timer_kill,
        TimerPlugin::timer_get_active_count,
        TimerPlugin::timer_get_info,
    ],
    {
        tracing_subscriber::fmt()
            .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
            .init();

        let timer_manager = TimerManager::new().expect("Failed to initialize timer manager");
        TimerPlugin {
            timer_manager,
        }
    }
);
