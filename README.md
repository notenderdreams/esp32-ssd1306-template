# {{project-name}}

{{project-description}}

Bare-metal (`no_std`) ESP32 firmware template using `esp-hal` with SSD1306 OLED display connection over I2C.

## What's included

- ESP32 + `esp-hal` project scaffolding
- SSD1306 display support (`ssd1306` + `embedded-graphics`)
- Utility-style display output (status/uptime)
- Cross-platform setup scripts:
  - Bash: `scripts/setup.sh`
  - PowerShell: `scripts/setup.ps1`

## Generate a project

```bash
cargo generate --git https://github.com/notenderdreams/esp32-ssd1306-template.git --name my-esp32-app
```

## Setup

Use `just setup` and it will choose the right script for your OS automatically.

```bash
just setup
```

## Build and flash

```bash
just run
```

## Default I2C display wiring

- SDA: `GPIO21`
- SCL: `GPIO22`
