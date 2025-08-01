use std::sync::atomic::{AtomicI32, AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;
use dashmap::DashMap;
use tokio::time::{sleep, Instant};
use tokio::task::JoinHandle;

use parking_lot::RwLock;

use crate::error::{TimerError, TimerResult};
use crate::callback::{CallbackData, execute_callback};

static TIMER_ID_COUNTER: AtomicI32 = AtomicI32::new(1);
static SHUTDOWN_FLAG: AtomicBool = AtomicBool::new(false);

#[derive(Debug)]
pub struct Timer {
    pub id: i32,
    pub delay_ms: u64,
    pub repeat: bool,
    pub callback: String,
    pub params: Option<CallbackData>,
    pub created_at: Instant,
    pub task_handle: Option<JoinHandle<()>>,
}

impl Timer {
    pub fn new(
        delay_ms: i32,
        repeat: bool,
        callback: String,
        params: Option<CallbackData>,
    ) -> TimerResult<Self> {
        if delay_ms <= 0 {
            return Err(TimerError::InvalidDelay(delay_ms));
        }

        if !crate::callback::is_valid_callback_name(&callback) {
            return Err(TimerError::InvalidCallback(callback));
        }

        let current_id = TIMER_ID_COUNTER.load(Ordering::Relaxed);
        if current_id >= i32::MAX {
            return Err(TimerError::IdOverflow);
        }

        let id = TIMER_ID_COUNTER.fetch_add(1, Ordering::SeqCst);
        if id <= 0 || id >= i32::MAX {
            return Err(TimerError::IdOverflow);
        }

        Ok(Timer {
            id,
            delay_ms: delay_ms as u64,
            repeat,
            callback,
            params,
            created_at: Instant::now(),
            task_handle: None,
        })
    }
}
pub struct TimerManager {
    timers: Arc<DashMap<i32, Arc<RwLock<Timer>>>>,
    runtime: Arc<tokio::runtime::Runtime>,
    shutdown_complete: Arc<AtomicBool>,
}

impl TimerManager {
    pub fn new() -> TimerResult<Self> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2) 
            .thread_name("samp-timer")
            .enable_all()
            .build()
            .map_err(|e| TimerError::TaskSpawnError(format!("Failed to create async runtime: {}", e)))?;

        Ok(TimerManager {
            timers: Arc::new(DashMap::new()),
            runtime: Arc::new(runtime),
            shutdown_complete: Arc::new(AtomicBool::new(false)),
        })
    }

    pub fn create_timer(
        &self,
        delay_ms: i32,
        repeat: bool,
        callback: String,
        params: Option<CallbackData>,
    ) -> TimerResult<i32> {
        if SHUTDOWN_FLAG.load(Ordering::Acquire) {
            return Err(TimerError::SystemShutdown);
        }

        let timer = Timer::new(delay_ms, repeat, callback, params)?;
        let timer_id = timer.id;

        let timers_ref = Arc::clone(&self.timers);
        let timer_arc = Arc::new(RwLock::new(timer));
        
        self.timers.insert(timer_id, Arc::clone(&timer_arc));

        let task_handle = self.runtime.spawn(Self::timer_task(
            timer_id,
            Arc::clone(&timer_arc),
            timers_ref,
        ));

        if let Some(mut timer_guard) = timer_arc.try_write() {
            timer_guard.task_handle = Some(task_handle);
        } else {
            self.timers.remove(&timer_id);
            tracing::error!("Failed to acquire write lock for timer {}", timer_id);
            return Err(TimerError::Internal("Failed to acquire timer write lock".to_string()));
        }

        tracing::debug!("Timer {} created and started", timer_id);
        Ok(timer_id)
    }

    pub fn kill_timer(&self, timer_id: i32) -> TimerResult<()> {
        println!("[TIMER] Attempting to kill timer {}", timer_id);
        
        if let Some(timer_entry) = self.timers.get(&timer_id) {
            let timer_arc = timer_entry.value().clone();
            
            if let Some(timer_guard) = timer_arc.try_read() {
                if let Some(ref handle) = timer_guard.task_handle {
                    println!("[TIMER] Aborting task for timer {}", timer_id);
                    handle.abort();
                }
            } else {
                println!("[TIMER] Could not acquire read lock for timer {}, proceeding with removal", timer_id);
            }
            
            self.timers.remove(&timer_id);
            println!("[TIMER] Timer {} killed and removed from map", timer_id);
            tracing::debug!("Timer {} killed and removed", timer_id);
            Ok(())
        } else {
            println!("[TIMER] Timer {} not found in map", timer_id);
            Err(TimerError::TimerNotFound(timer_id))
        }
    }

    pub fn shutdown(&self) {
        if self.shutdown_complete.load(Ordering::Acquire) {
            return; 
        }

        SHUTDOWN_FLAG.store(true, Ordering::Release);
        
        let timer_ids: Vec<i32> = self.timers.iter().map(|entry| *entry.key()).collect();
        let total_timers = timer_ids.len();

        for timer_id in timer_ids {
            let _ = self.kill_timer(timer_id);
        }

        if let Ok(runtime) = Arc::try_unwrap(self.runtime.clone()) {
            runtime.shutdown_timeout(Duration::from_secs(5));
        }

        self.shutdown_complete.store(true, Ordering::Release);
        tracing::info!("Timer system shutdown complete. Killed {} timers.", total_timers);
    }

    pub fn active_timer_count(&self) -> usize {
        self.timers.len()
    }

    pub fn get_timer_info(&self, timer_id: i32) -> Option<(u64, bool, String, std::time::Duration)> {
        if let Some(timer_entry) = self.timers.get(&timer_id) {
            let timer = timer_entry.read();
            let elapsed = timer.created_at.elapsed();
            Some((timer.delay_ms, timer.repeat, timer.callback.clone(), elapsed))
        } else {
            tracing::debug!("Timer {} not found in active timers (may be completed)", timer_id);
            None
        }
    }

    async fn timer_task(
        timer_id: i32,
        timer_arc: Arc<RwLock<Timer>>,
        timers: Arc<DashMap<i32, Arc<RwLock<Timer>>>>,
    ) {
        let (delay_ms, repeat, callback, params) = {
            let timer_guard = timer_arc.read();
            (
                timer_guard.delay_ms,
                timer_guard.repeat,
                timer_guard.callback.clone(),
                timer_guard.params.clone(),
            )
        };

        let delay = Duration::from_millis(delay_ms);
        println!("[TIMER] Timer {} started: delay={}ms, repeat={}, callback={}", timer_id, delay_ms, repeat, callback);

        loop {
            if SHUTDOWN_FLAG.load(Ordering::Acquire) {
                println!("[TIMER] Timer {} shutting down", timer_id);
                break;
            }

            println!("[TIMER] Timer {} sleeping for {}ms", timer_id, delay_ms);
            sleep(delay).await;

            if SHUTDOWN_FLAG.load(Ordering::Acquire) {
                println!("[TIMER] Timer {} shutting down after sleep", timer_id);
                break;
            }

            if !timers.contains_key(&timer_id) {
                println!("[TIMER] Timer {} was killed during sleep, stopping task", timer_id);
                break;
            }

            println!("[TIMER] Timer {} executing callback: {}", timer_id, callback);
            if let Err(e) = execute_callback(&callback, &params).await {
                println!("[TIMER] Timer {} callback execution failed: {}", timer_id, e);
                tracing::error!("Timer {} callback execution failed: {}", timer_id, e);
                if !repeat {
                    tracing::error!("One-shot timer {} failed: {}", timer_id,
                                  TimerError::CallbackExecutionError(format!("Callback '{}' failed: {}", callback, e)));
                    break; 
                }
            } else {
                println!("[TIMER] Timer {} callback executed successfully", timer_id);
            }

            if !timers.contains_key(&timer_id) {
                println!("[TIMER] Timer {} was killed during callback, stopping task", timer_id);
                break;
            }

            if !repeat {
                println!("[TIMER] Timer {} is one-shot, stopping", timer_id);
                break;
            }
        }
        timers.remove(&timer_id);
        println!("[TIMER] Timer {} task completed and cleaned up", timer_id);
        tracing::debug!("Timer {} task completed and cleaned up", timer_id);
    }
}

impl Drop for TimerManager {
    fn drop(&mut self) {
        if !self.shutdown_complete.load(Ordering::Acquire) {
            self.shutdown();
        }
    }
}
