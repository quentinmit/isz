use std::{mem, fs::File, os::unix::fs::FileExt, io::Read, io::Write, io::BufWriter};
use macros::Metrics;
use paste::paste;
use uninit::read::ReadIntoUninit;
use uninit::extension_traits::AsOut;
use log::{info,trace,warn, error};
use influxdb2::models::data_point::{DataPoint,DataPointBuilder,WriteDataPoint};

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

pub trait Recorder<M: Metrics> {
    fn record(&mut self, m: &M);
    fn report<W: Write>(&self, w: W) -> std::io::Result<()>;
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

#[test]
fn test_report() {
    let sample_data = include_bytes!("../testdata/sample.bin");
    let metrics: gpu_metrics_v2_2 = sample_data.as_ref().try_into().expect("sample data is v2.2");
    let mut r: recorder_gpu_metrics_v2_2 = Default::default();
    r.last_system_clock_counter = Some(metrics.system_clock_counter - 10);
    r.record(&metrics);
    let mut buf = BufWriter::new(Vec::new());
    r.report(&mut buf);
    info!("recorder after report: {:?}", r);
    let bytes = buf.into_inner().unwrap();
    let string = String::from_utf8(bytes).unwrap();
    assert_eq!(string, "");
}

fn record_from_file<M: Metrics, R: Recorder<M>>(f: &mut File, r: &mut R) -> Result<(), Error> {
    let m = M::try_from_file(f)?;
    r.record(&m);
    Ok(())
}

fn report<W: Write, F>(mut w: W, builder: F, field: &str, iter: impl Iterator<Item = (f64, u64)>) -> std::io::Result<()>
    where F: Fn() -> DataPointBuilder
{
    for (le, value) in iter {
        builder().tag("le", le.to_string()).field(field, value as i64).build().expect("always has field").write_data_point_to(&mut w)?;
    }
    Ok(())
}

macro_rules! metrics_reader {
    ($( ( $format_revision:literal, $content_revision:literal ) ),+ ) => {
        paste! {
            enum RecorderType {
                $(
                    [<gpu_metrics_v $format_revision _ $content_revision>]([<recorder_gpu_metrics_v $format_revision _ $content_revision>]),
                )+
            }

            impl RecorderType {
                fn new(f: &mut File) -> Result<Self, Error> {
                    let mut buf = [0u8; mem::size_of::<metrics_table_header>()];
                    f.read_exact(&mut buf).map_err(|_| Error::IO)?;
                    let header: metrics_table_header = buf.as_ref().try_into().map_err(|_| Error::BadHeader)?;
                    match (header.format_revision, header.content_revision) {
                        $(
                            ($format_revision, $content_revision) => Ok(Self::[<gpu_metrics_v $format_revision _ $content_revision>](Default::default())),
                        )+
                            _ => Err(Error::BadVersion),
                    }
                }
                fn sample(&mut self, f: &mut File) -> Result<(), Error> {
                    match self {
                        $(
                            Self::[<gpu_metrics_v $format_revision _ $content_revision>](r) => record_from_file(f, r),
                        )+
                    }
                }
                fn report(&self) -> std::io::Result<()> {
                    Ok(())
                }
            }
        }
    };
}

metrics_reader!{
    (1, 0),
    (1, 1),
    (1, 2),
    (1, 3),
    (2, 0),
    (2, 1),
    (2, 2),
    (2, 3)
}

pub struct MetricsReader {
    f: File,
    r: RecorderType,
}

impl MetricsReader {
    pub fn new<P: AsRef<std::path::Path>>(p: P) -> Result<Self, Error> {
        let mut f = File::open(p).map_err(|_| Error::IO)?;
        let mut r = RecorderType::new(&mut f)?;
        Ok(Self{
            f,
            r,
        })
    }
    pub fn record(&mut self) -> Result<(), Error> {
        if let Err(e) = self.r.sample(&mut self.f) {
            error!("failed reading sample: {:?}", e);
            self.r = RecorderType::new(&mut self.f)?;
        }
        Ok(())
    }
    pub fn report(&self) -> std::io::Result<()> {
        self.r.report()
    }
}
