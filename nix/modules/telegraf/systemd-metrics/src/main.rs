use async_std;
use zbus::{self, dbus_proxy, Connection, ConnectionBuilder, Result, zvariant::{Type, OwnedObjectPath}, fdo::PropertiesProxy};
use zbus_names::InterfaceName;
use serde::{Serialize, Deserialize};
use std::time::SystemTime;
use futures::future::{self, FutureExt, TryFutureExt};
use futures::stream::{self, StreamExt, TryStreamExt, FuturesUnordered};

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

#[async_std::main]
async fn main() -> Result<()> {

    let all_properties = false;

    let connection = connect().await?;

    let proxy = SystemdManagerProxy::new(&connection).await?;
    println!("Host architecture: {}", proxy.architecture().await?);
    println!("Environment:");
    for env in proxy.environment().await? {
        println!("  {}", env);
    }
    println!("Units:");
    timeit(|| async_std::task::block_on(async {
        let units = proxy.list_units().await?;
        stream::iter(units).map(Ok).try_for_each_concurrent(10, |unit| {
            let conn = &connection;
            let (name, path) = (unit.name, unit.path);
            async move {
                println!(" {} - {}", name, path);
                let properties_proxy = PropertiesProxy::builder(conn).destination("org.freedesktop.systemd1")?.path(path.clone())?.build().await?;
                if all_properties {
                    let properties = properties_proxy.get_all(InterfaceName::from_static_str_unchecked("")).await?;
                    for (key, value) in &properties {
                        println!("  {}={:?}", key, value);
                    }
                }
                let unit_type = name.rsplit_once(".").map(|(_, v)| v).unwrap_or(&name);
                let interface_name = InterfaceName::try_from(
                    format!("org.freedesktop.systemd1.{}", unit_type.chars().next().map(|c| c.to_uppercase().chain(unit_type.chars().skip(1)).collect::<String>()).unwrap())
                )?;
                for key in ["ControlGroup", "IPIngressBytes", "IPIngressPackets", "IPEgressBytes", "IPEgressPackets"] {
                    properties_proxy.get(interface_name.clone(), key).await.map_or_else(
                        |e| println!("  {} error {:?}", key, e),
                        |value| println!("  {}={:?}", key, value)
                    );
                }
                Ok::<(), zbus::Error>(())
            }}).await
    }))?;

    Ok(())
}

