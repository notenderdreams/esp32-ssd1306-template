#![no_std]
#![no_main]

use esp_backtrace as _;
use log::info;
use esp_hal::{
    delay::Delay,
    i2c::master::{Config, I2c},
    main,
};
use embedded_graphics::{
    mono_font::{ascii::FONT_6X10, MonoTextStyle},
    pixelcolor::BinaryColor,
    prelude::*,
    text::{Baseline, Text},
};
use ssd1306::{prelude::*, I2CDisplayInterface, Ssd1306};

fn ui_style() -> MonoTextStyle<'static, BinaryColor> {
    MonoTextStyle::new(&FONT_6X10, BinaryColor::On)
}

fn u32_to_str(mut value: u32, buf: &mut [u8; 10]) -> &str {
    let mut i = buf.len();

    if value == 0 {
        i -= 1;
        buf[i] = b'0';
    } else {
        while value > 0 {
            i -= 1;
            buf[i] = b'0' + (value % 10) as u8;
            value /= 10;
        }
    }

    // ASCII digits are always valid UTF-8.
    core::str::from_utf8(&buf[i..]).unwrap()
}

fn draw_dashboard<D>(display: &mut D, uptime_secs: u32) -> Result<(), D::Error>
where
    D: DrawTarget<Color = BinaryColor>,
{
    let style = ui_style();

    display.clear(BinaryColor::Off)?;

    Text::with_baseline("ESP32 Utility", Point::new(0, 0), style, Baseline::Top).draw(display)?;
    Text::with_baseline("I2C SDA: GPIO21", Point::new(0, 14), style, Baseline::Top).draw(display)?;
    Text::with_baseline("I2C SCL: GPIO22", Point::new(0, 26), style, Baseline::Top).draw(display)?;
    Text::with_baseline("Uptime:", Point::new(0, 44), style, Baseline::Top).draw(display)?;

    let mut digits = [0u8; 10];
    let uptime = u32_to_str(uptime_secs, &mut digits);
    Text::with_baseline(uptime, Point::new(48, 44), style, Baseline::Top).draw(display)?;

    let suffix_x = 48 + (uptime.len() as i32 * 6);
    Text::with_baseline("s", Point::new(suffix_x, 44), style, Baseline::Top).draw(display)?;

    Ok(())
}

#[main]
fn main() -> ! {
    esp_println::logger::init_logger_from_env();

    let peripherals = esp_hal::init(esp_hal::Config::default());
    let delay = Delay::new();

    let i2c = I2c::new(peripherals.I2C0, Config::default())
        .unwrap()
        .with_sda(peripherals.GPIO21)
        .with_scl(peripherals.GPIO22);

    let interface = I2CDisplayInterface::new(i2c);

    let mut display = Ssd1306::new(interface, DisplaySize128x64, DisplayRotation::Rotate0)
        .into_buffered_graphics_mode();

    display.init().unwrap();

    info!("Display initialized");

    let mut uptime_secs = 0u32;

    loop {
        draw_dashboard(&mut display, uptime_secs).unwrap();
        display.flush().unwrap();

        info!("uptime={}s", uptime_secs);

        delay.delay_millis(1000u32);
        uptime_secs = uptime_secs.wrapping_add(1);
    }
}