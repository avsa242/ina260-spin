# ina260-spin
-------------

This is a P8X32A/Propeller 1, P2X8C4M64P/Propeller 2 driver object for the TI INA260 Precision Current and Power monitor IC

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* I2C connection at up to 400kHz (P1), with alternate address support
* Read manufacturer ID, die ID
* Read shunt current, bus voltage, calculated power
* Set operation mode (one-shot/triggered, continuous, power-down)
* Set conversion time for voltage and current measurements
* Set measurement averaging samples
* Set interrupt/alert source, threshold, active state (open-collector high/low), latching
* Read flags: conversion ready, power overflowed


## Requirements

P1/SPIN1:
* spin-standard-library
* P1/SPIN1: 1 extra core/cog for the PASM I2C engine (none if the bytecode-based engine is used)
* sensor.power.common.spinh (provided by spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* sensor.power.common.spin2h (provided by p2-spin-standard-library)


## Compiler Compatibility

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.5.0)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (6.5.0)       | Native/PASM  | OK                    |
| P2        | SPIN2    | FlexSpin (6.5.0)       | NuCode       | OK                    |
| P2        | SPIN2    | FlexSpin (6.5.0)       | Native/PASM2 | OK                    |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Limitations

* Interrupt threshold parameter is currently a word, which isn't very intuitive
* Doesn't support high-speed mode (2.94MHz)

