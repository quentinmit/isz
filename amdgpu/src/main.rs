#![feature(maybe_uninit_as_bytes)]
#![feature(maybe_uninit_write_slice)]

use std::thread;
use std::collections::HashSet;
use std::time::{Duration, Instant};
use std::sync::mpsc;
use std::io::BufRead;
use std::fs;
use glob::glob;
use log::{info, warn, debug, trace};
use env_logger;

mod interface;
mod histogram;
mod lspci;

fn main() {
    env_logger::init();
    let devices: HashSet<_> = glob("/sys/class/drm/*/device/gpu_metrics").unwrap().filter_map(|entry|
        match entry {
            Ok(path) => {
                info!("Found metrics at {:?}", path);
                fs::canonicalize(path).ok()
            },
            Err(e) => {
                warn!("failed to read: {}", e);
                None
            },
        }
    ).collect();
    let mut readers: Vec<_> = devices.iter().filter_map(|path| {
        info!("Found metrics at {:?}", path);
        interface::MetricsReader::new(path).ok()
    }).collect();

    let (send, recv) = mpsc::sync_channel(0);

    thread::spawn(move || {
        for _line in std::io::stdin().lock().lines() {
            send.send(()).unwrap();
        }
    });

    loop {
        if recv.recv_timeout(Duration::from_millis(5)).is_ok() {
            let start = Instant::now();
            let mut w = std::io::stdout().lock();
            for r in &readers {
                if let Err(e) = r.report(&mut w) {
                    warn!("failed to report: {:?}", e);
                }
            }
            debug!("reporting took {:?}", start.elapsed());
        }
        let start = Instant::now();
        for r in &mut readers {
            if let Err(e) = r.record() {
                warn!("failed to record: {:?}", e);
            }
        }
        debug!("recording took {:?}", start.elapsed());
    }
}
