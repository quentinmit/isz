use std::{mem, fs::File, os::unix::fs::FileExt, io::Read};
use macros::Metrics;
use uninit::read::ReadIntoUninit;
use uninit::extension_traits::AsOut;

include!(concat!(env!("OUT_DIR"), "/kgd_pp_interface.rs"));

macro_rules! struct_try_from {
    ($type:ty) => {
        impl TryFrom<&[u8]> for $type {
            type Error = Error;
            fn try_from(value: &[u8]) -> Result<Self, Self::Error> {
                let size = mem::size_of::<Self>();
                let buf = value.get(0..size).ok_or(Error::BadLength)?;
                let mut out = mem::MaybeUninit::<Self>::uninit();
                unsafe {
                    // TODO: Too bad there's no try_write_slice
                    mem::MaybeUninit::write_slice(out.as_bytes_mut(), buf);
                    Ok(out.assume_init())
                }
            }
        }
    };
}

struct_try_from!(metrics_table_header);

pub trait Metrics: std::fmt::Debug {
    fn format_revision() -> usize where Self: Sized;
    fn content_revision() -> usize where Self: Sized;
    fn try_from_file(f: &mut File) -> Result<Self, Error> where Self: Sized;
}

pub trait Record<M: Metrics> {
    fn record(&mut self, m: &M);
}

#[derive(Debug)]
pub enum Error {
    BadHeader,
    BadVersion,
    BadLength,
    IO,
}

pub fn parse_metrics(buf: &[u8]) -> Result<Box<dyn Metrics>, Error> {
    let header: metrics_table_header = buf.try_into().map_err(|_| Error::BadHeader)?;
    if header.structure_size as usize != buf.len() {
        return Err(Error::BadLength);
    }
    match (header.format_revision, header.content_revision) {
        (1, 0) => TryInto::<gpu_metrics_v1_0>::try_into(buf).map(|v| Box::new(v) as Box<dyn Metrics>),
        (1, 1) => TryInto::<gpu_metrics_v1_1>::try_into(buf).map(|v| Box::new(v) as Box<dyn Metrics>),
        (1, 2) => TryInto::<gpu_metrics_v1_2>::try_into(buf).map(|v| Box::new(v) as Box<dyn Metrics>),
        (1, 3) => TryInto::<gpu_metrics_v1_3>::try_into(buf).map(|v| Box::new(v) as Box<dyn Metrics>),
        (2, 0) => TryInto::<gpu_metrics_v2_0>::try_into(buf).map(|v| Box::new(v) as Box<dyn Metrics>),
        (2, 1) => TryInto::<gpu_metrics_v2_1>::try_into(buf).map(|v| Box::new(v) as Box<dyn Metrics>),
        (2, 2) => TryInto::<gpu_metrics_v2_2>::try_into(buf).map(|v| Box::new(v) as Box<dyn Metrics>),
        (2, 3) => TryInto::<gpu_metrics_v2_3>::try_into(buf).map(|v| Box::new(v) as Box<dyn Metrics>),
        _ => Err(Error::BadVersion),
    }
}

#[test]
fn test_parse_metrics() {
    let sample_data = include_bytes!("../testdata/sample.bin");
    let metrics = parse_metrics(sample_data).unwrap();
    println!("{:?}", metrics);
}

pub struct MetricsReader<T: Metrics> {
    f: File,
    samples: Vec<T>,
}

impl <'a, T: Metrics> MetricsReader<T> {
    fn sample(&mut self) -> Result<(), Error> {
        let metrics = T::try_from_file(&mut self.f)?;
        println!("{:?}", metrics);
        //self.samples.push(metrics);
        Ok(())
    }
}
