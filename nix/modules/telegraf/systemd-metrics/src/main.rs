use async_std;
use zbus::{self, dbus_proxy, Connection, ConnectionBuilder, Result, zvariant::{Type, OwnedObjectPath, Value}, fdo::PropertiesProxy};
use zbus_names::InterfaceName;
use serde::{Serialize, Deserialize};
use std::time::SystemTime;
use futures::future::{self, FutureExt, TryFutureExt};
use futures::stream::{self, StreamExt, TryStreamExt, FuturesUnordered};
use influxdb2::models::{DataPoint, data_point::DataPointError, FieldValue, WriteDataPoint};
use std::io;

#[derive(Debug, Type, Serialize, Deserialize)]
pub struct UnitStatus {
    /// The primary unit name as string
    pub name: String,
    /// The human readable description string
    pub description: String,
    /// The load state (i.e. whether the unit file has been loaded successfully)
    pub load_state: String,
    /// The active state (i.e. whether the unit is currently started or not)
    pub active_state: String,
    /// The sub state (a more fine-grained version of the active state that is specific to the unit type, which the active state is not)
    pub sub_state: String,
    /// A unit that is being followed in its state by this unit, if there is any, otherwise the empty string.
    pub followed: String,
    /// The unit object path
    pub path: OwnedObjectPath,
    /// If there is a job queued for the job unit the numeric job id, 0 otherwise
    pub job_id: u32,
    /// The job type as string
    pub job_type: String,
    /// The job object path
    pub job_path: OwnedObjectPath,
}

#[dbus_proxy(
    interface = "org.freedesktop.systemd1.Manager",
    default_service = "org.freedesktop.systemd1",
    default_path = "/org/freedesktop/systemd1"
)]
trait SystemdManager {
    #[dbus_proxy(property)]
    fn architecture(&self) -> Result<String>;
    #[dbus_proxy(property)]
    fn environment(&self) -> Result<Vec<String>>;

    fn list_units(&self) -> Result<Vec<UnitStatus>>;
}

fn timeit<F: Fn() -> T, T>(f: F) -> T {
    let start = SystemTime::now();
    let result = f();
    let end = SystemTime::now();
    let duration = end.duration_since(start).unwrap();
    println!("it took {:?}", duration);
    result
}

async fn connect() -> Result<Connection> {
    future::ready(ConnectionBuilder::address("unix:path=/run/systemd/private"))
        .and_then(|b| b.p2p().build())
        .or_else(|e| {
            println!("private connection failed: {:?}", e);
            Connection::system()
        }).await
}

struct Scraper {
    connection: Connection,
    all_properties: bool,
}

fn to_initial_uppercase(s: &str) -> String {
    s
        .chars()
        .next()
        .map_or(String::new(), |c|
             c
             .to_uppercase()
             .chain(s.chars().skip(1))
             .collect()
        )
}

impl Scraper {
    async fn scrape(&self) -> Result<()> {
        let proxy = SystemdManagerProxy::new(&self.connection).await?;
        let units = proxy.list_units().await?;
        stream::iter(units).map(Ok).try_for_each_concurrent(10, |unit| async move {
            self.scrape_unit(&unit).await
        }).await
    }

    async fn scrape_unit(&self, unit: &UnitStatus) -> Result<()> {
        let mut builder = DataPoint::builder("systemd_unit")
            .tag("Id", &unit.name)
            ;
        //println!(" {} - {}", unit.name, unit.path);
        let properties_proxy =
            PropertiesProxy::builder(&self.connection)
            .destination("org.freedesktop.systemd1")?
            .path(unit.path.clone())?
            .build()
            .await?;
        if self.all_properties {
            let properties = properties_proxy.get_all(InterfaceName::from_static_str_unchecked("")).await?;
            for (key, value) in &properties {
                println!("  {}={:?}", key, value);
            }
        }
        let unit_type = unit.name.rsplit_once(".").map(|(_, v)| v).unwrap_or(&unit.name);
        builder = builder.tag("unit_type", unit_type);
        let interface_name = InterfaceName::try_from(
            format!(
                "org.freedesktop.systemd1.{}",
                to_initial_uppercase(unit_type),
            )
        )?;
        for key in ["Slice", "ControlGroup", "CPUUsageNSec", "IOReadBytes", "IOWriteBytes", "IOReadOperations", "IOWriteOperations", "MemoryCurrent", "IPIngressBytes", "IPIngressPackets", "IPEgressBytes", "IPEgressPackets"] {
            let value = properties_proxy.get(interface_name.clone(), key).await.map_or_else(
                |_| None,
                |value| {
                    match value.into() {
                        Value::U64(u64::MAX) => None,
                        Value::U8(v) => Some(Into::<FieldValue>::into(Into::<i64>::into(v))),
                        Value::Bool(v) => Some(v.into()),
                        Value::I16(v) => Some(Into::<i64>::into(v).into()),
                        Value::U16(v) => Some(Into::<i64>::into(v).into()),
                        Value::I32(v) => Some(Into::<i64>::into(v).into()),
                        Value::U32(v) => Some(Into::<i64>::into(v).into()),
                        Value::I64(v) => Some(Into::<i64>::into(v).into()),
                        Value::U64(v) => Some((v.min(i64::MAX as u64) as i64).into()),
                        Value::F64(v) => Some(v.into()),
                        Value::Str(s) if s.len() == 0 => None,
                        Value::Str(s) => Some(TryInto::<String>::try_into(s).unwrap().into()),
                        v => {
                            println!("  can't convert {}={:?}", key, v);
                            None
                        },
                    }
                },
            );
            match value {
                Some(FieldValue::String(s)) => {
                    builder = builder.tag(key, s);
                },
                Some(v) => {
                    builder = builder.field(key, v);
                }
                None => {}
            };
        }
        match builder.build() {
            Err(DataPointError::AtLeastOneFieldRequired { .. }) => {},
            Ok(p) => p.write_data_point_to(io::stdout()).unwrap(),
        }
        Ok::<(), zbus::Error>(())
    }
}

#[async_std::main]
async fn main() -> Result<()> {
    let connection = connect().await?;

    let proxy = SystemdManagerProxy::new(&connection).await?;
    println!("Host architecture: {}", proxy.architecture().await?);
    println!("Environment:");
    for env in proxy.environment().await? {
        println!("  {}", env);
    }
    let scraper = Scraper{
        connection,
        all_properties: false,
    };
    println!("Units:");
    timeit(|| async_std::task::block_on(scraper.scrape()))?;

    Ok(())
}

