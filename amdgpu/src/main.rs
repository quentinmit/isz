#![feature(maybe_uninit_as_bytes)]
#![feature(maybe_uninit_write_slice)]

use std::thread;
use std::time::Duration;
use std::sync::mpsc;
use std::io::BufRead;
use glob::glob;
use log::{info,warn};

mod interface;
mod histogram;

fn main() {
    let mut readers: Vec<_> = glob("/sys/class/drm/*/device/gpu_metrics").unwrap().filter_map(|entry|
        match entry {
            Ok(path) => interface::MetricsReader::new(path).ok(),
            Err(e) => {
                warn!("failed to read: {}", e);
                None
            },
        }
    ).collect();

    let (send, recv) = mpsc::sync_channel(0);

    thread::spawn(move || {
        for line in std::io::stdin().lock().lines() {
            send.send(()).unwrap();
        }
    });

    while true {
        if recv.recv_timeout(Duration::from_millis(5)).is_ok() {
            for r in &readers {
                r.report();
            }
        }
        for r in &mut readers {
            r.record();
        }
    }

    println!("Hello, world!");
}
