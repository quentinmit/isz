use heapless;
use itertools::Itertools;
use num_traits::Float;
use std::iter;
use std::cell::RefCell;
use log::{info, trace};
use std::fmt::{Debug, self};

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

fn base(scale: isize) -> f64 {
    (-scale as f64).exp2().exp2()
}

fn index_for_value(scale: isize, value: f64) -> Option<isize> {
    // Adapted from
    // https://opentelemetry.io/docs/specs/otel/metrics/data-model/#scale-zero-extract-the-exponent
    // but with support for positive scales
    let (mantissa, exponent, sign) = value.integer_decode();
    if mantissa == 0 || sign < 0 {
        return None
    }
    let mantissa_log = mantissa.ilog2();
    let mantissa_one = (mantissa >> mantissa_log) << mantissa_log;
    let power_of_2 = mantissa == mantissa_one;
    let exponent_index = (exponent as isize) + (mantissa_log as isize);
    if scale >= 0 {
        if power_of_2 {
            Some((exponent_index << scale) - 1)
        } else {
            let base = base(scale);
            Some(value.log(base) as isize)
        }
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

    fn compress(&mut self) {
        self.scale -= 1;
        // Preserve first zero bucket as-is
        if self.buckets.len() > 1 {
            let second_half = self.index_offset.unwrap() & 1;
            // If the new first bucket consists of only the second half of the
            // old first bucket, add an extra zero to make sure the buckets
            // aren't misaligned.
            let shift = second_half as usize;
            self.index_offset = self.index_offset.map(|o| o >> 1);
            let (zero, rest) = self.buckets.split_at(1);
            let rest = iter::repeat(0)
                .take(shift)
                .chain(rest.into_iter().map(|v| *v));
            self.buckets = zero.into_iter().map(|v| *v).chain(
                rest
                    .chunks(2)
                    .into_iter()
                    .map(|chunk| chunk.sum())
            ).collect();
            trace!("compress: new scale {:?}, new index_offset {:?}, buckets {:?}", self.scale, self.index_offset, self.buckets);
            trace!("samples = {:?}", self.sample().collect::<Vec<_>>());
        }
    }

    /// Returns the index a value would be placed in at the current scale.
    fn index_for_value(&mut self, value: f64) -> Option<isize> {
        index_for_value(self.scale, value)
    }

    /// Returns the array index that a value with the given index at the current scale should be placed in.
    fn resize_to_fit(&mut self, value: f64) -> usize {
        let index = match self.index_for_value(value) {
            None => {
                trace!("incrementing zero bucket");
                return 0;
            },
            Some(index) => index,
        };
        trace!("making space for index {:?} at scale {:?}", index, self.scale);
        let i = match self.index_offset {
            None => {
                // No buckets yet; place the item in a newly created bucket.
                self.index_offset = Some(index);
                1
            }
            Some(index_offset) => {
                // Calculate number of buckets to insert at the beginning.
                let shift = (index_offset.saturating_sub(index)).max(0) as usize;
                let mut i = index - index_offset + 1;
                let new_length = (i.max(1) as usize).max(self.buckets.len()).saturating_add(shift);
                trace!("would need a hypothetical bucket {:?} resulting in {} buckets", i, new_length);
                if new_length > self.buckets.capacity() {
                    self.compress();
                    return self.resize_to_fit(value);
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
        i
    }

    pub fn record(&mut self, value: f64) {
        self.record_weighted(value, 1)
    }

    pub fn record_weighted(&mut self, value: f64, weight: u64) {
        trace!("recording value {:?} with weight {:?}", value, weight);
        let index = self.index_for_value(value);
        let i = self.resize_to_fit(value);
        if i >= self.buckets.len() {
            self.buckets.resize_default(i+1);
        }
        self.buckets[i] += weight;
        self.sum += value * (weight as f64);
    }
    pub fn sample(&self) -> impl Iterator<Item = (f64, u64)> + '_ {
        let base = base(self.scale);
        self.buckets.iter().enumerate().map(move |(i, count)| {
            let upper_bound = match self.index_offset {
                None => f64::INFINITY,
                Some(index_offset) => base.powi(((i as isize)+index_offset) as i32),
            };
            (upper_bound, *count)
        })
    }
}

struct PrintIter<T> {
    iter: RefCell<Option<T>>,
}

impl<T: IntoIterator<Item = (f64, u64)>> Debug for PrintIter<T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> Result<(), fmt::Error> {
        if let Some(iter) = self.iter.take() {
            let mut start = f64::NEG_INFINITY;
            for (end, count) in iter {
                if f.alternate() {
                    f.write_str("\n    ")?;
                }
                write!(f, "({:20}, {:20}): {}", start, end, count)?;
                if f.alternate() {
                    f.write_str("")?;
                }
                start = end;
            }
        }
        Ok(())
    }
}

impl<const MAX_SIZE: usize> Debug for ExponentialHistogram<MAX_SIZE> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> Result<(), fmt::Error> {
        f.debug_struct("ExponentialHistogram")
            .field("scale", &self.scale)
            .field("base", &base(self.scale))
            .field("buckets", &PrintIter{iter: RefCell::new(Some(self.sample()))})
            .finish()
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

    fn record_print<const N: usize>(h: &mut ExponentialHistogram<N>, value: f64) {
        h.record(value);
        trace!("after recording {}: {:#?}", value, h);
    }

    #[test]
    fn test_zero_value() {
        let mut h = ExponentialHistogram::<160>::new();
        record_print(&mut h, 0.0);
        assert_eq!(h.index_offset, None);
        assert_eq!(&h.buckets, &[1]);
    }

    #[test]
    fn test_single_value() {
        let mut h = ExponentialHistogram::<160>::new();
        record_print(&mut h, 1.0);
        assert_eq!(h.scale, 20);
        assert_eq!(h.index_offset, Some(-1));
        assert_eq!(&h.buckets, &[0, 1]);
    }

    #[test]
    fn test_two_values() {
        let mut h = ExponentialHistogram::<10>::new();
        record_print(&mut h, 1.0);
        record_print(&mut h, 10.0);
        assert_eq!(h.scale, 1);
        assert_eq!(h.index_offset, Some(-1));
        assert_eq!(&h.buckets, &[0, 1, 0, 0, 0, 0, 0, 0, 1]);
    }

    #[test]
    fn test_large_values() {
        let mut h = ExponentialHistogram::<10>::new();
        record_print(&mut h, 1024.0);
        record_print(&mut h, 1024.1);
        assert_eq!(h.scale, 15);
        assert_eq!(h.index_offset, Some(327679));
        assert_eq!(&h.buckets, &[0, 1, 0, 0, 0, 0, 1]);
    }
    #[test]
    fn test_shifting() {
        let mut h = ExponentialHistogram::<10>::new();
        record_print(&mut h, 1024.0);
        record_print(&mut h, 512.0);
        assert_eq!(h.scale, 3);
        assert_eq!(h.index_offset, Some(71));
        assert_eq!(&h.buckets, &[0, 1, 0, 0, 0, 0, 0, 0, 0, 1]);
    }
    #[test]
    fn test_ideal_scale_for_value() {
        assert_eq!(ideal_scale_for_value(127.0, 8), 0);
        assert_eq!(ideal_scale_for_value(129.0, 8), -1);
    }
}
