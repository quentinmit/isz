use heapless;
use itertools::Itertools;

pub struct ExponentialHistogram<const MAX_SIZE: usize = 160> {
    scale: Option<isize>,
    maxScale: isize,
    sum: f64,
    /// bucket 0 has bounds 0-1, bucket 1 has bounds 1-base, etc.
    buckets: heapless::Vec<u64, MAX_SIZE>,
}

fn bucket_for_value(scale: isize, value: f64) -> usize {
    println!("bucket_for_value({:?}, {:?})", scale, value);
    if value <= 1.0 {
        return 0;
    }
    // See https://opentelemetry.io/blog/2023/exponential-histograms
    // and https://opentelemetry.io/docs/specs/otel/metrics/sdk/#base2-exponential-bucket-histogram-aggregation
    // base = 2 ^ (2 ^ -scale)
    let base = 2f64.powf(2f64.powf(-scale as f64));
    // upper bound of bucket i is base ^ (i + 1)
    // i = log_b(n) - 1
    let index = value.log(base);
    println!("log_{:?}({:?}) = {:?}", base, value, index);
    // bucket 0 is the 0-1 bucket, so add 1
    (index as usize)+1
}
fn ideal_scale_for_value(value: f64, max_size: usize) -> isize {
    // "Best resolution (highest scale) is achieved when the number of positive
    // or negative range buckets exceeds half the maximum size, such that
    // increasing scale by one would not be possible given the size
    // constraint."

    let scale = 2.0f64.log(value.powf(1.0/((max_size-1) as f64))).log2();
    println!("scale = {:?}", scale);
    scale.floor() as isize
}

impl<const MAX_SIZE: usize> ExponentialHistogram<MAX_SIZE> {
    pub fn new() -> Self {
        Self {
            scale: None,
            maxScale: 20,
            sum: 0.0,
            buckets: heapless::Vec::new(),
        }
    }

    fn compress(&mut self) {
        self.scale = self.scale.map(|s| s + 1);
        // Preserve first zero bucket as-is
        if self.buckets.len() > 1 {
            assert!(matches!(self.scale, Some(_)));
            let (zero, rest) = self.buckets.split_at(1);
            self.buckets = zero.into_iter().map(|v| *v).chain(
                rest
                //.into_iter()
                .chunks(2)
                .map(|chunk| chunk.iter().map(|v| *v).sum())
            ).collect();
        }
    }

    pub fn record(&mut self, value: f64) {
        let scale = *self.scale.get_or_insert_with(|| ideal_scale_for_value(value, MAX_SIZE).min(self.maxScale));
        let mut bucket = bucket_for_value(scale, value);
        while bucket >= self.buckets.capacity() {
            self.compress();
            bucket = bucket_for_value(scale, value);
        }
        if bucket >= self.buckets.len() {
            self.buckets.resize_default(bucket + 1);
        }
        self.buckets[bucket] += 1;
        self.sum += value;
    }
}

mod tests {
    use super::*;

    #[test]
    fn test_bucket_for_value() {
        assert_eq!(bucket_for_value(0, 0.0), 0);
        assert_eq!(bucket_for_value(0, 1.0), 0);
        assert_eq!(bucket_for_value(0, 1.5), 1);
        assert_eq!(bucket_for_value(0, 2.5), 2);
    }

    #[test]
    fn test_ideal_scale_for_value() {
        assert_eq!(ideal_scale_for_value(127.0, 8), 0);
        assert_eq!(ideal_scale_for_value(129.0, 8), -1);
    }
}