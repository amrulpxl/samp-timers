use std::sync::atomic::{AtomicI32, AtomicBool, AtomicUsize, Ordering};
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
static ACTIVE_TIMER_COUNT: AtomicUsize = AtomicUsize::new(0);

const MAX_TIMERS: usize = 10000;
const MAX_DELAY_MS: i32 = 2_147_483_647; /* max i32 value */

#[derive(Debug)]
pub struct Timer {
    pub id: i32,
    pub delay_ms: u64,
    pub repeat: bool,
    pub callback: String,
    pub params: Option<CallbackData>,
    pub created_at: Instant,
    pub last_execution: Option<Instant>,
    pub execution_count: u64,
    pub task_handle: Option<JoinHandle<()>>,
}

impl Timer {
    pub fn new(
        delay_ms: i32,
        repeat: bool,
        callback: String,
        params: Option<CallbackData>,
    ) -> TimerResult<Self> {
        if delay_ms <= 0 || delay_ms > MAX_DELAY_MS {
            return Err(TimerError::InvalidDelay(delay_ms));
        }

        if !crate::callback::is_valid_callback_name(&callback) {
            return Err(TimerError::InvalidCallback(callback));
        }

        if let Some(ref params) = params {
            params.validate()?;
        }

        /* check resource limits */
        let current_count = ACTIVE_TIMER_COUNT.load(Ordering::Acquire);
        if current_count >= MAX_TIMERS {
            return Err(TimerError::ResourceExhaustion(
                format!("Maximum timer limit reached: {}", MAX_TIMERS)
            ));
        }

        let current_id = TIMER_ID_COUNTER.load(Ordering::Relaxed);
        if current_id >= i32::MAX - 1000 { /* leave some buffer */
            return Err(TimerError::IdOverflow);
        }

        let id = TIMER_ID_COUNTER.fetch_add(1, Ordering::SeqCst);
        if id <= 0 || id >= i32::MAX - 1000 {
            return Err(TimerError::IdOverflow);
        }

        Ok(Timer {
            id,
            delay_ms: delay_ms as u64,
            repeat,
            callback,
            params,
            created_at: Instant::now(),
            last_execution: None,
            execution_count: 0,
            task_handle: None,
        })
    }

    pub fn mark_execution(&mut self) {
        self.last_execution = Some(Instant::now());
        self.execution_count += 1;
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
        ACTIVE_TIMER_COUNT.fetch_add(1, Ordering::Release);

        let task_handle = self.runtime.spawn(Self::timer_task(
            timer_id,
            Arc::clone(&timer_arc),
            timers_ref,
        ));

        /* update task handle with timeout protection */
        match timer_arc.try_write_for(Duration::from_millis(100)) {
            Some(mut timer_guard) => {
                timer_guard.task_handle = Some(task_handle);
            }
            None => {
                task_handle.abort();
                self.timers.remove(&timer_id);
                ACTIVE_TIMER_COUNT.fetch_sub(1, Ordering::Release);
                tracing::error!("Failed to acquire write lock for timer {} within timeout", timer_id);
                return Err(TimerError::Internal("Failed to acquire timer write lock within timeout".to_string()));
            }
        }

        tracing::debug!("Timer {} created and started (delay={}ms, repeat={})", timer_id, delay_ms, repeat);
        Ok(timer_id)
    }

    pub fn kill_timer(&self, timer_id: i32) -> TimerResult<()> {
        if let Some((_, timer_arc)) = self.timers.remove(&timer_id) {
            if let Some(timer_guard) = timer_arc.try_read_for(Duration::from_millis(50)) {
                if let Some(ref handle) = timer_guard.task_handle {
                    handle.abort();
                }
            }

            ACTIVE_TIMER_COUNT.fetch_sub(1, Ordering::Release);
            tracing::debug!("Timer {} killed and removed", timer_id);
            Ok(())
        } else {
            Err(TimerError::TimerNotFound(timer_id))
        }
    }

    pub fn shutdown(&self) {
        if self.shutdown_complete.load(Ordering::Acquire) {
            return;
        }

        tracing::info!("Initiating timer system shutdown...");
        SHUTDOWN_FLAG.store(true, Ordering::Release);

        let timer_ids: Vec<i32> = self.timers.iter().map(|entry| *entry.key()).collect();
        let total_timers = timer_ids.len();

        /* kill timers in parallel for faster shutdown */
        for chunk in timer_ids.chunks(100) { /* process in chunks to avoid overwhelming */
            for &timer_id in chunk {
                if let Some((_, timer_arc)) = self.timers.remove(&timer_id) {
                    if let Some(timer_guard) = timer_arc.try_read_for(Duration::from_millis(10)) {
                        if let Some(ref handle) = timer_guard.task_handle {
                            handle.abort();
                        }
                    }
                    ACTIVE_TIMER_COUNT.fetch_sub(1, Ordering::Release);
                }
            }
            /* small delay between chunks to prevent resource exhaustion */
            std::thread::sleep(Duration::from_millis(1));
        }

        /* wait for all tasks to finished with timeout */
        let shutdown_start = std::time::Instant::now();
        while ACTIVE_TIMER_COUNT.load(Ordering::Acquire) > 0 && shutdown_start.elapsed() < Duration::from_secs(5) {
            std::thread::sleep(Duration::from_millis(10));
        }

        self.shutdown_complete.store(true, Ordering::Release);
        let final_count = ACTIVE_TIMER_COUNT.load(Ordering::Acquire);

        if final_count > 0 {
            tracing::warn!("Timer system shutdown completed with {} timers still active (forced shutdown)", final_count);
        } else {
            tracing::info!("Timer system shutdown complete. Killed {} timers cleanly.", total_timers);
        }
    }

    pub fn active_timer_count(&self) -> usize {
        ACTIVE_TIMER_COUNT.load(Ordering::Acquire)
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
        let mut execution_count = 0u64;

        loop {
            if SHUTDOWN_FLAG.load(Ordering::Acquire) {
                tracing::debug!("Timer {} stopping due to shutdown", timer_id);
                break;
            }

            tokio::select! {
                _ = sleep(delay) => {},
                _ = tokio::task::yield_now() => {
                    if SHUTDOWN_FLAG.load(Ordering::Acquire) {
                        break;
                    }
                }
            }

            if SHUTDOWN_FLAG.load(Ordering::Acquire) {
                break;
            }

            if !timers.contains_key(&timer_id) {
                tracing::debug!("Timer {} was killed during sleep, stopping task", timer_id);
                return;
            }

            let callback_result = execute_callback(&callback, &params).await;

            match callback_result {
                Ok(()) => {
                    execution_count += 1;
                    tracing::trace!("Timer {} callback executed successfully (count: {})", timer_id, execution_count);

                    if let Some(mut timer_guard) = timer_arc.try_write_for(Duration::from_millis(1)) {
                        timer_guard.mark_execution();
                    }
                }
                Err(e) => {
                    tracing::warn!("Timer {} callback failed: {}", timer_id, e);
                    if !repeat {
                        tracing::debug!("One-shot timer {} failed, stopping", timer_id);
                        break;
                    }
                }
            }

            if !timers.contains_key(&timer_id) {
                tracing::debug!("Timer {} was killed during callback execution, stopping task", timer_id);
                return;
            }

            if !repeat {
                break;
            }

            if execution_count > 1_000_000 {
                tracing::warn!("Timer {} has executed {} times, potential runaway timer", timer_id, execution_count);
            }
        }
        if let Some((_, _)) = timers.remove(&timer_id) {
            ACTIVE_TIMER_COUNT.fetch_sub(1, Ordering::Release);
            tracing::debug!("Timer {} task completed and cleaned up (executions: {})", timer_id, execution_count);
        }
    }
}

impl Drop for TimerManager {
    fn drop(&mut self) {
        if !self.shutdown_complete.load(Ordering::Acquire) {
            self.shutdown();
        }

        if let Ok(runtime) = Arc::try_unwrap(std::mem::replace(&mut self.runtime, Arc::new(
            tokio::runtime::Builder::new_current_thread()
                .build()
                .expect("Failed to create dummy runtime")
        ))) {
            runtime.shutdown_timeout(Duration::from_secs(2));
        }
    }
}
