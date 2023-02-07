#![no_std]
#![no_main]

use core::panic::PanicInfo;

pub mod uart;
pub mod entry;

#[macro_use]
pub mod log;

// The never type "!" means diverging function (never returns).
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}

#[no_mangle]
pub extern "C" fn _start() -> ! {

    let mut myuart = uart::Uart::new(0x1000_0000);
    myuart.init();

    log::println!("MELLOW SWIRLED!");

    log::log!(Warning, "This is a test of the warning logging!");
    log::log!(Error, "This is a test of the error logging!");
    loop {}
}
