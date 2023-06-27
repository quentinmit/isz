use proc_macro::TokenStream;
use quote::{quote, format_ident};
use syn::{parse_macro_input, DeriveInput, Data};
use itertools::Itertools;

fn parse_name(ident: &syn::Ident) -> Option<(usize, usize)> {
    match ident.to_string().split("_").collect_tuple() {
        Some(("gpu", "metrics", v_format_revision, content_revision)) => {
            Some((
                v_format_revision.trim_start_matches('v').parse::<usize>().ok()?,
                content_revision.parse::<usize>().ok()?,
            ))
        }
        _ => None
    }
}

#[proc_macro_derive(Metrics)]
pub fn
derive_macro_builder(input: TokenStream) -> TokenStream {
    let DeriveInput {
        ident: struct_name_ident,
        data,
        generics,
        ..
      }: DeriveInput = parse_macro_input!(input as DeriveInput);
      match data {
        Data::Struct(s) => {
            let (format_revision, content_revision) = parse_name(&struct_name_ident).unwrap();
            let instrument = format_ident!("instruments_{}", &struct_name_ident);
            let fields = s.fields.iter()
                .filter_map(|f| {
                    f.ident.as_ref().map(|n| n.to_string()).and_then(|field_name| {
                        match (field_name.as_ref(), &f.ty) {
                            ("system_clock_counter", _) => None,
                            ("padding"|"system_clock_counter", _) => None,
                            (_, syn::Type::Path(p)) => p.path.get_ident().and_then(|i| match i.to_string().as_ref() {
                                "u16"|"u32"|"u64" => f.ident.as_ref().map(
                                    |i| (
                                        i,
                                        quote!{ crate::histogram::ExponentialHistogram<20> },
                                        quote!{ self.#i.record_weighted(m.#i as f64, delta) },
                                    )
                                ),
                                _ => None
                            }),
                            (_, syn::Type::Array(a)) => {
                                let len = &a.len;
                                f.ident.as_ref().map(
                                    |ident| (
                                        ident,
                                        quote!{ [crate::histogram::ExponentialHistogram<20>; #len] },
                                        quote!{
                                            for (i, value) in m.#ident.iter().enumerate() {
                                                self.#ident[i].record_weighted(value as f64, delta);
                                            }
                                        },
                                    )
                                )
                            },
                            _ => {
                                eprintln!("type = {:?}", &f.ty);
                                None
                            },
                        }
                    })
                })
                .collect::<Vec<_>>();
            let instrument_fields: Vec<_> = fields.iter().map(|(ident, ty, _)| {
                quote!{ #ident: #ty }
            }).collect();
            let record_calls: Vec<_> = fields.iter().map(|(_, _, record)| record).collect();
            eprintln!(
                "ident = {:?}, fields = {:?}",
                struct_name_ident,
                fields,
            );
            quote!{
                struct #instrument {
                    last_system_clock_counter: Option<u64>,
                    #( #instrument_fields ),*
                }
                impl Record<#struct_name_ident> for #instrument {
                    fn record(&mut self, m: &#struct_name_ident) {
                        if let Some(last_system_clock_counter) = self.last_system_clock_counter {
                            let delta = m.system_clock_counter - last_system_clock_counter;
                            #( #record_calls );*
                        }
                        self.last_system_clock_counter = Some(m.system_clock_counter);
                    }
                }
                impl Metrics for #struct_name_ident {
                    fn format_revision() -> usize {
                        #format_revision
                    }
                    fn content_revision() -> usize {
                        #content_revision
                    }
                    fn try_from_file(f: &mut File) -> Result<Self, Error> {
                        let size = mem::size_of::<Self>();
                        let mut out = mem::MaybeUninit::<Self>::uninit();
                        unsafe {
                            let buf = std::slice::from_raw_parts_mut(out.as_mut_ptr() as *mut u8, size);
                            f.read_exact(buf).map_err(|_| Error::IO)?;
                            // TODO: Switch when read_into_uninit_exact is implemented for &File
                            //f.read_into_uninit_exact(out.as_out()).map_err(|_| Error::IO)?;
                            Ok(out.assume_init())
                        }.and_then(|s|
                                   match (s.common_header.format_revision as usize, s.common_header.content_revision as usize) {
                                       (#format_revision, #content_revision) => Ok(s),
                                       _ => Err(Error::BadVersion),
                                   }
                        )
                    }
                }
                impl TryFrom<&[u8]> for #struct_name_ident {
                    type Error = Error;
                    fn try_from(value: &[u8]) -> Result<Self, Self::Error> {
                        let size = mem::size_of::<Self>();
                        let buf = value.get(0..size).ok_or(Error::BadLength)?;
                        let mut out = mem::MaybeUninit::<Self>::uninit();
                        unsafe {
                            // TODO: Too bad there's no try_write_slice
                            mem::MaybeUninit::write_slice(out.as_bytes_mut(), buf);
                            Ok(out.assume_init())
                        }.and_then(|s|
                            match (s.common_header.format_revision as usize, s.common_header.content_revision as usize) {
                                (#format_revision, #content_revision) => Ok(s),
                                _ => Err(Error::BadVersion),
                            }
                        )
                    }
                }
            }
        }
        _ => quote!{}
      }.into()
}
