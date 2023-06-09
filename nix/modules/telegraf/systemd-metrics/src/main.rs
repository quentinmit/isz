use async_std;
use zbus::{self, dbus_proxy, Connection, ConnectionBuilder, zvariant::{Type, OwnedObjectPath, Value}, fdo::PropertiesProxy};
use zbus_names::InterfaceName;
use serde::{Serialize, Deserialize};
use std::time::Instant;
use futures::future::{self, TryFutureExt};
use futures::stream::{self, StreamExt, TryStreamExt};
use influxdb2::models::{DataPoint, data_point::DataPointError, FieldValue, WriteDataPoint};
use std::io::{self, BufRead};
use std::collections::HashSet;
use log::{warn, info, debug, trace};
use clap::Parser;

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
    fn list_units(&self) -> zbus::Result<Vec<UnitStatus>>;
}

async fn connect() -> zbus::Result<Connection> {
    future::ready(ConnectionBuilder::address("unix:path=/run/systemd/private"))
        .and_then(|b| b.p2p().build())
        .or_else(|e| {
            warn!("private connection failed: {:?}", e);
            Connection::system()
        }).await
}

struct Scraper {
    connection: Connection,
    tags: HashSet<String>,
    properties: Option<HashSet<String>>,
    get_all: bool,
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
    async fn scrape(&self) -> zbus::Result<()> {
        let proxy = SystemdManagerProxy::new(&self.connection).await?;
        let units = proxy.list_units().await?;
        stream::iter(units).map(Ok).try_for_each_concurrent(10, |unit| async move {
            self.scrape_unit(&unit).await
        }).await
    }

    async fn scrape_unit(&self, unit: &UnitStatus) -> zbus::Result<()> {
        let mut builder = DataPoint::builder("systemd_unit")
            .tag("Id", &unit.name)
            ;
        trace!("scraping {} - {}", unit.name, unit.path);
        let properties_proxy =
            PropertiesProxy::builder(&self.connection)
            .destination("org.freedesktop.systemd1")?
            .path(unit.path.clone())?
            .build()
            .await?;
        let unit_type = unit.name.rsplit_once(".").map(|(_, v)| v).unwrap_or(&unit.name);
        builder = builder.tag("unit_type", unit_type);
        let interface_name = InterfaceName::try_from(
            format!(
                "org.freedesktop.systemd1.{}",
                to_initial_uppercase(unit_type),
            )
        )?;
        let property_names: HashSet<&str> = match &self.properties {
            Some(p) => (&self.tags).union(p).map(|s| s.as_str()).collect(),
            None => self.tags.iter().map(|s| s.as_str()).collect(),
        };
        let properties = match (self.get_all, &self.properties) {
            (true, _) | (false, None) => {
                let mut properties = properties_proxy.get_all(InterfaceName::from_static_str_unchecked("")).await?;
                if let Some(_) = &self.properties {
                    properties.retain(|key, _| property_names.contains(&key.as_str()));
                }
                properties
            },
            (false, Some(_)) => {
                stream::iter(property_names).filter_map(|key| async {
                    properties_proxy.get(interface_name.clone(), key).await.ok().map(|value| (key.into(), value))
                }).collect().await
            }
        };
        for (key, value) in &properties {
            trace!("  {}={:?}", key, value);
            let value = match value.into() {
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
                Value::Str(s) => Some(Into::<String>::into(s).into()),
                v => {
                    warn!("  can't convert {}={:?}", key, v);
                    None
                },
            };
            match value {
                Some(FieldValue::String(s)) if self.tags.contains(key) => {
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

const DEFAULT_TAGS: &[&str] = &[
    "Slice",
    "ControlGroup",
    "LoadState",
];

const DEFAULT_PROPERTIES: &[&str] = &[
    "ActiveState",
    "SubState",
    "NRestarts",
    "CPUUsageNSec",
    "IOReadBytes",
    "IOReadOperations",
    "IOWriteBytes",
    "IOWriteOperations",
    "MemoryCurrent",
    "MemoryMax",
    "IPIngressBytes",
    "IPIngressPackets",
    "IPEgressBytes",
    "IPEgressPackets",
    "TasksCurrent",
    "ActiveEnterTimestamp",
    "ActiveExitTimestamp",
    "InactiveEnterTimestamp",
    "InactiveExitTimestamp",
    // socket
    "NConnections",
    "NAccepted",
    "NRefused",
];


#[derive(Parser)]
struct Cli {
    #[arg(short, long, num_args=0.., default_values_t=DEFAULT_TAGS.into_iter().map(|v| v.to_string()))]
    tags: Vec<String>,
    #[arg(short, long, num_args=0.., default_values_t=DEFAULT_PROPERTIES.into_iter().map(|v| v.to_string()))]
    properties: Vec<String>,
    #[arg(long)]
    get_all: bool,
}

#[async_std::main]
async fn main() -> zbus::Result<()> {
    pretty_env_logger::init();

    let cli = Cli::parse();

    let connection = connect().await?;

    let scraper = Scraper{
        connection,
        tags: cli.tags.into_iter().collect(),
        properties: Some(cli.properties).filter(|p| p.len() > 0).map(|p| p.into_iter().collect()),
        get_all: cli.get_all,
    };
    let stdin = io::stdin();
    for _ in stdin.lock().lines() {
        let start = Instant::now();
        let result = scraper.scrape().await;
        info!("scrape took {:?}", start.elapsed());
        result?;
    }

    Ok(())
}

