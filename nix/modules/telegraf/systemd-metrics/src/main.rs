use async_std;
use zbus::{self, dbus_proxy, Connection, Result, zvariant::{Type, OwnedObjectPath}, fdo::PropertiesProxy};
use zbus_names::InterfaceName;
use serde::{Serialize, Deserialize};
use std::time::SystemTime;

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

#[async_std::main]
async fn main() -> Result<()> {
    let connection = Connection::system().await?;

    let proxy = SystemdManagerProxy::new(&connection).await?;
    println!("Host architecture: {}", proxy.architecture().await?);
    println!("Environment:");
    for env in proxy.environment().await? {
        println!("  {}", env);
    }
    println!("Units:");
    timeit(|| async_std::task::block_on(async {
        for unit in proxy.list_units().await? {
            println!(" {} - {}", unit.name, unit.path);
            let properties = PropertiesProxy::builder(&connection).path(unit.path)?.build().await?.get_all(InterfaceName::from_static_str_unchecked("")).await?;
            for (key, value) in &properties {
                println!("  {}={:?}", key, value);
            }
        }
        Ok::<(), zbus::Error>(())
    }))?;

    Ok(())
}

