use heapless;
use itertools::Itertools;
use num_traits::Float;
use std::iter;
use log::{info, trace};

pub struct ExponentialHistogram<const MAX_SIZE: usize = 160> {
    zero_threshold: Option<f64>,
    scale: isize,
    sum: f64,
    index_offset: Option<isize>,
    /// bucket 0 is the zero bucket, buckets 1-MAX_SIZE are positive exponential.
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
    if mantissa == 0 || sign < 0 {
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
    trace!("scale = {:?}", scale);
    scale.floor() as isize
}

impl<const MAX_SIZE: usize> ExponentialHistogram<MAX_SIZE> {
    pub fn new() -> Self {
        let max_scale = 20;
        Self {
            zero_threshold: Some(1.0),
            scale: max_scale,
            sum: 0.0,
            index_offset: None,
            buckets: heapless::Vec::new(),
        }
    }

    fn compress(&mut self, shift: usize) {
        self.scale -= 1;
        // Preserve first zero bucket as-is
        if self.buckets.len() > 1 {
            self.index_offset = self.index_offset.map(|o| o >> 1);
            let (zero, rest) = self.buckets.split_at(1);
            let rest = iter::repeat(0)
                .take(shift)
                .chain(rest.into_iter().map(|v| *v));
            // TODO: if index_offset & 1 then the first bucket needs to contain only one value.
            self.buckets = zero.into_iter().map(|v| *v).chain(
                rest
                    .chunks(2)
                    .into_iter()
                    .map(|chunk| chunk.sum())
            ).collect();
        }
    }

    /// Returns the index a value would be placed in at the current scale.
    fn index_for_value(&mut self, value: f64) -> Option<isize> {
        index_for_value(self.scale, value)
    }

    /// Returns the array index that a value with the given index at the current scale should be placed in.
    fn resize_to_fit(&mut self, index: isize) -> usize {
        let i = match self.index_offset {
            None => {
                // No buckets yet; place the item in a newly created bucket.
                self.index_offset = Some(index);
                1
            }
            Some(index_offset) => {
                // Calculate number of buckets to insert at the beginning.
                let shift = (index_offset - index).max(0) as usize;
                let mut i = index - index_offset + 1;
                if (i as usize).max(self.buckets.len()) + shift >= self.buckets.capacity() {
                    self.compress(shift);
                    return self.resize_to_fit(index >> 1);
                } else if shift > 0 {
                    let (zero, rest) = self.buckets.split_at(1);
                    self.buckets = zero
                        .into_iter().map(|v| *v)
                        .chain(iter::repeat(0).take(shift))
                        .chain(rest.into_iter().map(|v| *v))
                        .collect();
                    self.index_offset = Some(index_offset - (shift as isize));
                    i += shift as isize;
                }
                i as usize
            }
        };
        if i >= self.buckets.len() {
            self.buckets.resize_default(i+1);
        }
        i
    }

    pub fn record(&mut self, value: f64) {
        trace!("recording value {:?}", value);
        let index = self.index_for_value(value);
        match index {
            None => {
                // Zero bucket
                trace!("incrementing zero bucket");
                if self.buckets.len() < 1 {
                    self.buckets.resize_default(1);
                }
                self.buckets[0] += 1;
            }
            Some(index) => {
                let i = self.resize_to_fit(index);
                trace!("new scale = {:?}, new index_offset = {:?}, i = {:?}", self.scale, self.index_offset, i);
                self.buckets[i] += 1;
            }
        }
        self.sum += value;
    }
    pub fn sample(&self) -> impl Iterator<Item = (f64, u64)> + '_ {
        let base = (-self.scale as f64).exp2().exp2();
        self.buckets.iter().enumerate().map(move |(i, count)| {
            let upper_bound = match self.index_offset {
                None => f64::INFINITY,
                Some(index_offset) => base.powi(((i as isize)+index_offset) as i32),
            };
            (upper_bound, *count)
        })
    }
}

mod tests {
    use super::*;
    use test_log::test;

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
    fn test_zero_value() {
        let mut h = ExponentialHistogram::<160>::new();
        h.record(0.0);
        assert_eq!(h.index_offset, None);
        assert_eq!(&h.buckets, &[1]);
    }

    #[test]
    fn test_single_value() {
        let mut h = ExponentialHistogram::<160>::new();
        h.record(1.0);
        assert_eq!(h.scale, 20);
        assert_eq!(h.index_offset, Some(-1));
        assert_eq!(&h.buckets, &[0, 1]);
    }
    #[test]
    fn test_two_values() {
        let mut h = ExponentialHistogram::<10>::new();
        h.record(1.0);
        h.record(10.0);
        let samples: Vec<(f64, u64)> = h.sample().collect();
        info!("samples = {:?}", samples);
        assert_eq!(h.scale, 1);
        assert_eq!(h.index_offset, Some(-1));
        assert_eq!(&h.buckets, &[0, 1, 0, 0, 0, 0, 0, 0, 1]);
    }

    #[test]
    fn test_ideal_scale_for_value() {
        assert_eq!(ideal_scale_for_value(127.0, 8), 0);
        assert_eq!(ideal_scale_for_value(129.0, 8), -1);
    }
}
