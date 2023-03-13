extern crate bindgen;

use std::env;
use std::path::PathBuf;
use itertools::Itertools;

#[derive(Debug)]
pub struct Callbacks {}

impl bindgen::callbacks::ParseCallbacks for Callbacks {
    fn include_file(&self, filename: &str) {
        println!("cargo:rerun-if-changed={}", filename);
    }

    fn add_derives(&self, name: &str) -> Vec<String> {
        match name.split("_").collect_tuple() {
            Some(("gpu", "metrics", _, _)) => vec!["Metrics".into()],
            _ => vec![]
        }
    }
}

fn main() {
    // Tell cargo to invalidate the built crate whenever the wrapper changes
    println!("cargo:rerun-if-changed=bindings.h");

    // The bindgen::Builder is the main entry point
    // to bindgen, and lets you build up options for
    // the resulting bindings.
    let bindings = bindgen::Builder::default()
        // The input header we would like to generate
        // bindings for.
        .header("include/bindings.h")
        .clang_arg("-Iinclude")
        .allowlist_type("gpu_metrics_.*")
        // Tell cargo to invalidate the built crate whenever any of the
        // included header files changed.
        .parse_callbacks(Box::new(Callbacks{}))
        // Finish the builder and generate the bindings.
        .generate()
        // Unwrap the Result and panic on failure.
        .expect("Unable to generate bindings");

    // Write the bindings to the $OUT_DIR/kgd_pp_interface.rs file.
    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("kgd_pp_interface.rs"))
        .expect("Couldn't write bindings!");
}
