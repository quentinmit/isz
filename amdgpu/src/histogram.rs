use heapless;
use itertools::Itertools;
use num_traits::Float;

pub struct ExponentialHistogram<const MAX_SIZE: usize = 160> {
    max_scale: isize,
    zero_threshold: Option<f64>,
    scale: Option<isize>,
    sum: f64,
    index_offset: Option<isize>,
    /// bucket 0 has bounds 0-1, bucket 1 has bounds 1-base, etc.
    buckets: heapless::Vec<u64, MAX_SIZE>,
}

fn index_scale_0_for_value(value: f64) -> isize {
    // https://opentelemetry.io/docs/specs/otel/metrics/data-model/#scale-zero-extract-the-exponent
    let (mantissa, exponent, sign) = value.integer_decode();
    let log = mantissa.ilog2();
    let power_of_2 = mantissa == 0x10000000000000;
    (exponent as isize) + (log as isize) - (power_of_2 as isize)
}

fn index_for_value(scale: isize, value: f64) -> Option<isize> {
    // Adapted from
    // https://opentelemetry.io/docs/specs/otel/metrics/data-model/#scale-zero-extract-the-exponent
    // but with support for negative scales
    let (mantissa, exponent, sign) = value.integer_decode();
    if mantissa == 0 {
        return None
    }
    let mantissa_log = mantissa.ilog2();
    let mantissa_one = (mantissa >> mantissa_log) << mantissa_log;
    let power_of_2 = mantissa == mantissa_one;
    let exponent_index = (exponent as isize) + (mantissa_log as isize);
    if scale >= 0 {
        let shift = mantissa_log - (scale as u32);
        let mantissa_shifted = (mantissa - mantissa_one) >> shift;
        Some((exponent_index << scale) + (mantissa_shifted as isize) - (power_of_2 as isize))
    } else {
        Some((exponent_index - (power_of_2 as isize)) >> -scale)
    }
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
            max_scale: 20,
            zero_threshold: Some(1.0),
            scale: None,
            sum: 0.0,
            index_offset: None,
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

    fn bucket_for_value(&mut self, value: f64) -> usize {
        let scale = *self.scale.get_or_insert_with(|| ideal_scale_for_value(value, MAX_SIZE).min(self.max_scale));
        let mut bucket = match index_for_value(scale, value) {
            Some(index) if index >= 0 => (index as usize) + 1,
            _ => 0,
        };
        while bucket >= self.buckets.capacity() {
            self.compress();
            bucket = match index_for_value(scale, value) {
                Some(index) if index >= 0 => (index as usize) + 1,
                _ => 0,
            };
        }
        if bucket >= self.buckets.len() {
            self.buckets.resize_default(bucket + 1);
        }
        bucket
    }

    pub fn record(&mut self, value: f64) {
        let bucket = self.bucket_for_value(value);
        self.buckets[bucket] += 1;
        self.sum += value;
    }
}

mod tests {
    use super::*;

    #[test]
    fn test_index_for_value() {
        for (scale, value, index) in &[
            (0, 1.0, -1),
            (0, 1.5, 0),
            (0, 2.0, 0),
            (0, 4.0, 1),
            (0, 5.0, 2),
            (1, 1.0, -1),
            (1, 1.5, 1),
            (1, 2.0, 1),
            (1, 4.0, 3),
            (1, 5.0, 4),
            (-1, 1.0, -1),
            (-1, 1.5, 0),
            (-1, 2.0, 0),
            (-1, 4.0, 0),
            (-1, 5.0, 1),
        ] {
            if *scale == 0 {
                assert_eq!(index_scale_0_for_value(*value), *index, "index_scale_0_for_value({:?})", value);
            }
            assert_eq!(index_for_value(*scale, *value), Some(*index), "index_for_value({:?}, {:?})", scale, value);
        }
    }

    #[test]
    fn test_bucket_for_value() {
        assert_eq!(index_for_value(0, 0.0), Some(0));
        assert_eq!(index_for_value(0, 1.0), Some(0));
        assert_eq!(index_for_value(0, 1.5), Some(1));
        assert_eq!(index_for_value(0, 2.5), Some(2));
    }

    #[test]
    fn test_ideal_scale_for_value() {
        assert_eq!(ideal_scale_for_value(127.0, 8), 0);
        assert_eq!(ideal_scale_for_value(129.0, 8), -1);
    }
}
