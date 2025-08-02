fn main() {
    println!("cargo:rustc-env=CARGO_CFG_TARGET_ARCH=x86");
    
    let target = std::env::var("TARGET").unwrap_or_default();
    
    if !target.contains("i686") && !target.contains("x86") {
        eprintln!("Warning: Building for non-x86 target: {}", target);
        eprintln!("SAMP plugins require i686-pc-windows-msvc target");
    }
    
    if target.contains("windows") {
        println!("cargo:rustc-link-arg=/SUBSYSTEM:WINDOWS");
        println!("cargo:rustc-link-arg=/MACHINE:X86");
    }
    
    println!("cargo:rerun-if-changed=build.rs");
}
