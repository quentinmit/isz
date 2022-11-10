use std::mem;

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
struct_try_from!(gpu_metrics_v1_0);
struct_try_from!(gpu_metrics_v1_1);
struct_try_from!(gpu_metrics_v1_2);
struct_try_from!(gpu_metrics_v1_3);
struct_try_from!(gpu_metrics_v2_0);
struct_try_from!(gpu_metrics_v2_1);
struct_try_from!(gpu_metrics_v2_2);
struct_try_from!(gpu_metrics_v2_3);

pub trait Metrics: std::fmt::Debug {

}
impl Metrics for gpu_metrics_v1_0 {}
impl Metrics for gpu_metrics_v1_1 {}
impl Metrics for gpu_metrics_v1_2 {}
impl Metrics for gpu_metrics_v1_3 {}
impl Metrics for gpu_metrics_v2_0 {}
impl Metrics for gpu_metrics_v2_1 {}
impl Metrics for gpu_metrics_v2_2 {}
impl Metrics for gpu_metrics_v2_3 {}

#[derive(Debug)]
pub enum Error {
    BadHeader,
    BadVersion,
    BadLength,
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