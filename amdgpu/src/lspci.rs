use std::process::Command;
use std::collections::HashMap;
use std::ffi::OsStr;

use shlex;
use thiserror::Error;

const LSPCI_KEYS: &[&str] = &[
    "slot",
    "class",
    "vendor_name",
    "device_name",
    "subsystem_vendor_name",
    "subsystem_name",
];

#[derive(Error, Debug)]
pub enum Error {
    #[error("error executing lspci: {0:?}")]
    IoError(#[from] std::io::Error),
    #[error("lspci output is invalid utf8: {0:?}")]
    FromUtf8Error(#[from] std::string::FromUtf8Error),
}



pub fn lspci_info(slot: &OsStr) -> Result<HashMap<String, String>, Error> {
    let output = Command::new("lspci")
    .arg("-s")
    .arg(slot)
    .arg("-mm")
    .arg("-nn")
    .output()?;
    let stdout = String::from_utf8(output.stdout)?;
    let (arg_parts, pos_parts): (Vec<_>, Vec<_>) =
        shlex::split(&stdout)
        .unwrap_or(vec![])
        .into_iter()
        .partition(|p| p.starts_with("-"));
    let pos_keys = LSPCI_KEYS
        .into_iter()
        .map(|s| String::from(*s))
        .zip(pos_parts.into_iter());
    let arg_keys = arg_parts.iter().filter_map(|p| {
        p.strip_prefix("-").and_then(|p| {
            let mut chars = p.chars();
            chars.next().map(|key|
                (key.to_string(), chars.as_str().to_string())
            )
        })
    });
    Ok(pos_keys.chain(arg_keys).collect())
}