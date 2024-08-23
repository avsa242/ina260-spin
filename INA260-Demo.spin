{
----------------------------------------------------------------------------------------------------
    Filename:       INA260-Demo.spin
    Description:    Demo of the INA260 driver
        * Power data output
    Author:         Jesse Burt
    Started:        Sep 18, 2019
    Updated:        Aug 23, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

' Uncomment the two lines below to use the bytecode-based I2C engine
'#define INA260_I2C_BC
'#pragma exportdef(INA260_I2C_BC)


CON

    _clkmode        = cfg._clkmode
    _xinfreq        = cfg._xinfreq


OBJ

    cfg:    "boardcfg.flip"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    sensor: "sensor.power.ina260" | SCL=28, SDA=29, I2C_FREQ=400_000, I2C_ADDR=%0000
    time:   "time"


pub main()

    repeat
        ser.pos_xy(0, 3)
        show_power_data()
        time.msleep(250)


CON

    { scaling factors for display }
    VF  = 1_000_000
    CF  = 1_000_000
    PF  = 1_000_000

PUB show_power_data()
' Scale down values from the sensor driver and display each
    ser.printf2(@"Voltage: %d.%06.6dv\n\r", (sensor.voltage() / VF), ...        ' whole .
                                            (sensor.voltage() // VF))           '   part

    ser.printf2(@"Current: %d.%06.6dA\n\r", (sensor.current() / CF), ...
                                            ||(sensor.current() // CF))

    ser.printf2(@"Power: %d.%06.6dW\n\r",   (sensor.power() / PF), ...
                                            (sensor.power() // PF))


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( sensor.start() )
        ser.strln(@"INA260 driver started")
    else
        ser.strln(@"INA260 driver failed to start - halting")
        repeat


DAT
{
Copyright (c) 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

