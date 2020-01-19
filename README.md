# ina260-spin
-------------

This is a P8X32A/Propeller 1, P2X8C4M64P/Propeller 2 driver object for the TI INA260 Precision Current and Power monitor IC

## Salient Features

* I2C connection at up to 400kHz (P1), _TBD_ (P2)
* Read manufacturer ID, die ID
* Read shunt current, bus voltage, calculated power
* Set operation mode (one-shot/triggered, continuous, power-down)
* Set conversion time for voltage and current measurements
* Set measurement averaging samples
* Set interrupt/alert source, threshold, active state (open-collector high/low), latching
* Read flags: conversion ready, power overflowed

## Requirements

* P1/SPIN1: 1 extra core/cog for the PASM I2C driver
* N/A

## Compiler Compatibility

* SPIN1: OpenSpin (tested with 1.00.81)
* SPIN2: FastSpin (tested with 4.0.3-beta)

## Limitations

* Very early in development - may malfunction, or outright fail to build

## TODO

- [x] Implement methods for reading the three measurements
- [x] Implement methods for configuring the chip
- [x] Implement methods for setting interrupts/alerts
- [ ] Add support for alternate slave addresses
- [ ] Modify the alert threshold setting to accept natural values rather than a raw word
