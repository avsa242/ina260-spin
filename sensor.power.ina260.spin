{
----------------------------------------------------------------------------------------------------
    Filename:       sensor.power.ina260.spin
    Description:    Driver for the TI INA260 Precision Current and Power Monitor IC
    Author:         Jesse Burt
    Started:        Nov 13, 2019
    Updated:        Mar 2, 2025
    Copyright (c) 2025 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

#include "sensor.power.common.spinh"

CON

    { default I/O settings; these can be overridden in the parent object }
    SCL             = 28
    SDA             = 29
    I2C_FREQ        = 100_000
    I2C_ADDR        = %0000


    SLAVE_WR        = core.SLAVE_ADDR
    SLAVE_RD        = core.SLAVE_ADDR|1

    I2C_MAX_FREQ    = core.I2C_MAX_FREQ

'   Address pins vs slave addresses
'   A1  A0  SLAVE ADDRESS
'   GND GND 100_0000
'   GND VS+ 100_0001
'   GND SDA 100_0010
'   GND SCL 100_0011
'   VS+ GND 100_0100
'   VS+ VS+ 100_0101
'   VS+ SDA 100_0110
'   VS+ SCL 100_0111
'   SDA GND 100_1000
'   SDA VS+ 100_1001
'   SDA SDA 100_1010
'   SDA SCL 100_1011
'   SCL GND 100_1100
'   SCL VS+ 100_1101
'   SCL SDA 100_1110
'   SCL SCL 100_1111

' Operating modes
    POWERDN         = %000
    CURR_TRIGD      = %001
    VOLT_TRIGD      = %010
    CURR_VOLT_TRIGD = %011
    POWERDN2        = %100
    CURR_CONT       = %101
    VOLT_CONT       = %110
    CURR_VOLT_CONT  = %111

' Interrupt/alert pin sources
    INT_CURRENT_HI  = 1 << 5
    INT_CURRENT_LO  = 1 << 4
    INT_BUSVOLT_HI  = 1 << 3
    INT_BUSVOLT_LO  = 1 << 2
    INT_POWER_HI    = 1 << 1
    INT_CONV_READY  = 1 << 0

' Interrupt/alert pin level/polarity
    INTLVL_LO       = 0
    INTLVL_HI       = 1

VAR

    long _addr_bits

OBJ

#ifdef INA260_I2C_BC
    i2c:    "com.i2c.nocog"                     ' I2C engine (bytecode; no additional cogs needed)
#else
    i2c:    "com.i2c"                           ' I2C engine (PASM; 1 additional cog)
#endif
    core:   "core.con.ina260"                   ' HW-specific constants
    time:   "time"


PUB null()
' This is not a top-level object


PUB start(): status
' Start using default I/O settings
    return startx(SCL, SDA, I2C_FREQ, I2C_ADDR)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS): status
' Start using custom settings
'   SCL_PIN:    I2C clock, 0..31
'   SDA_PIN:    I2C data, 0..31
'   I2C_HZ:     I2C bus speed (max official specification is 400_000 but is unenforced)
'   ADDR_BITS:  I2C alternate address bit, %0000..%1111
'   Returns:
'       cog ID+1 of I2C engine on success (= calling cog ID+1, if the bytecode I2C engine is used)
'       0 on failure
    if (    lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and ...
            lookdown(ADDR_BITS: %0000..%1111) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.usleep(core.T_POR)
            _addr_bits := (ADDR_BITS << 1)
            reset()
            if ( dev_id() == core.DEVID_RESP )
            return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()
    _addr_bits := 0


PUB adc2amps(adc_word): a
' Convert current ADC word to amperage
'   Returns: current in microamperes
    return (~~adc_word) * 1_250


PUB adc2volts(adc_word): v
' Convert bus voltage ADC word to voltage
'   Returns: voltage in microvolts
    return (adc_word & $7fff) * 1_250


PUB adc2watts(adc_word): w
' Convert power ADC word to wattage
'   Returns: power in microwatts
    return (adc_word * 10_000)


PUB current_data(ch=0): a
' Read the measured current, in microamperes
'   NOTE: If averaging is enabled, this will return the averaged value
    return readreg(core.CURRENT)


PUB current_conv_time(ctm=-2): c
' Set conversion time for shunt current measurement, in microseconds
'   Valid values: 140, 204, 332, 588, *1100, 2116, 4156, 8244
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CONFIG)
    case ctm
        140, 204, 332, 588, 1100, 2116, 4156, 8244:
            ctm := lookdownz(ctm: 140, 204, 332, 588, 1100, 2116, 4156, 8244) << core.ISHCT
            ctm := ((c & core.ISHCT_MASK) | ctm)
            writereg(core.CONFIG, ctm)
        other:
            c := (c >> core.ISHCT) & core.ISHCT_BITS
            return lookupz(c: 140, 204, 332, 588, 1100, 2116, 4156, 8244)


PUB dev_id(): id
' Read device ID
'   Returns:
'       Most-significant word: Die ID
'       Least-significant word: Mfr ID
    return (die_id() << 16) | mfr_id()


PUB die_id(): id
' Read the Die ID from the chip
'   Returns: $2270
    return readreg(core.DIE_ID)


PUB int_clear() | tmp
' Clear active interrupt
'   NOTE: This method is only effective when interrupts are latched (int_latch_ena() == true)
    readreg(core.ENABLE, 1)                     ' simply reading this reg clears a latched int


PUB int_polarity(st=-2): c
' Set interrupt active level/polarity
'   Valid values:
'      *INTLVL_LO   (0) Active low
'       INTLVL_HI   (1) Active high
'   Any other value polls the chip and returns the current setting
'   NOTE: The ALERT pin is open collector
    c := readreg(core.ENABLE)
    case st
        INTLVL_LO, INTLVL_HI:
            st <<= core.APOL
            st := ( (c & core.APOL_MASK) | st)
            writereg(core.ENABLE, st)
        other:
            return ( (c >> core.APOL) & 1)


PUB int_mask(msk=-2): c
' Set interrupt mask
'   Valid values:
'       Bits: 5..0
'       5: Over current limit
'       4: Under current limit
'       3: Bus voltage over-voltage
'       2: Bus voltage under-voltage
'       1: Power over-limit
'       0: Conversion ready
'   Any other value polls the chip and returns the current setting
'   NOTE: Only one source may be enabled at a time. If more than one source is enabled,
'       only the function in the higher significant bit position will be used.
'   NOTE: INT_ symbols can optionally be used to define sources
'    (defined near top of this file)
    c := readreg(core.ENABLE)
    case msk
        %000000..%111111:
            msk <<= core.ALERTS
            msk := ( (c & core.ALERTS_MASK) | msk)
            writereg(core.ENABLE, msk)
        other:
            return (c >> core.ALERTS) & core.ALERTS_BITS


PUB int_latch_ena(st=-2): c
' Enable latching of interrupts
'   Valid values:
'       TRUE (-1 or 1): Active interrupts remain asserted until cleared manually
'       FALSE (0): Active interrupts clear when the fault has been cleared
    c := readreg(core.ENABLE)
    case ||(st)
        0, 1:
            st := ||(st) & 1
            st := ( (c & core.LEN_MASK) | st)
            writereg(core.ENABLE, st)
        other:
            return ( (c & 1) == 1)


PUB int_set_thr(thr)
' Set interrupt/alert threshold
'   Valid values:
'       Current: 0..15_000_000 (microamps; clamped to range)
'       Voltage: 0..36_000_000 (microvolts; clamped to range)
'       Power: 540_000_000 (microwatts; clamped to range)
    case int_mask()                             ' determine scaling based on interrupt type set
        INT_CURRENT_HI, INT_CURRENT_LO:
            { current low or high threshold }
            thr := (0 #> thr <# 15_000000) / 1_250
        INT_BUSVOLT_HI, INT_BUSVOLT_LO:
            { voltage low or high threshold }
            thr := (0 #> thr <# 36_000000) / 1_250
        INT_POWER_HI:
            { power high threshold }
            thr := (0 #> thr <# 540_000000) / 10_000

    writereg(core.ALERT_LIMIT, thr)


PUB int_thresh(): t
' Get interrupt/alert threshold
    t := readreg(core.ALERT_LIMIT)
    case int_mask()                             ' determine scaling based on interrupt type set
        INT_CURRENT_HI, INT_CURRENT_LO, INT_BUSVOLT_HI, INT_BUSVOLT_LO:
            { current or voltage, low or high threshold }
            return (thresh * 1_250)
        INT_POWER_HI:
            { power high threshold }
            return (thresh * 10_000)
        other:
            { no interrupt mask set; just return the reg value unscaled }
            return thresh


PUB mfr_id(): id
' Read the Manufacturer ID from the chip
'   Returns: $5449
    return readreg(core.MFR_ID)


PUB opmode(md=-2): c
' Set operation mode
'   Valid values:
'       POWERDN (0): Power-down/shutdown
'       CURR_TRIGD (1): Shunt current, triggered
'       VOLT_TRIGD (2): Bus voltage, triggered
'       CURR_VOLT_TRIGD (3): Shunt current and bus voltage, triggered
'       POWERDN2 (4): Power-down/shutdown
'       CURR_CONT (5): Shunt current, continuous
'       VOLT_CONT (6): Bus voltage, continuous
'      *CURR_VOLT_CONT (7): Shunt current and bus voltage, continuous
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CONFIG)
    case md
        POWERDN, CURR_TRIGD, VOLT_TRIGD, CURR_VOLT_TRIGD, POWERDN2, CURR_CONT, VOLT_CONT, ...
        CURR_VOLT_CONT:
            md := lookdownz(md: POWERDN, CURR_TRIGD, VOLT_TRIGD, CURR_VOLT_TRIGD, POWERDN2, ...
                                    CURR_CONT, VOLT_CONT, CURR_VOLT_CONT)
            md := ( (c & core.MODE_MASK) | md)
            writereg(core.CONFIG, md)
        other:
            return (c & core.MODE_BITS)


PUB power_data(ch=0): p
' Read the power measured by the chip, in microwatts
'   NOTE: If averaging is enabled, this will return the averaged value
'   NOTE: The maximum value returned is 419_430_000
    return readreg(core.POWER)


PUB power_data_rdy(): f
' Flag indicating data from the last conversion is available for reading
'   Returns: TRUE (-1) if data available, FALSE (0) otherwise
    f := readreg(core.ENABLE)
    return ( (f & core.DRDY) <> 0)


PUB power_overflowed(): f
' Flag indicating power data exceeded the maximum measurable value (419_430_000uW or 419.43W)
    f := readreg(core.ENABLE)
    return ( (f & core.OVERFL) <> 0)


PUB reset()
' Reset the chip
'   NOTE: Equivalent to Power-On Reset
    writereg(core.CONFIG, core.SOFT_RES)


PUB samples_avg(smp=-2): c
' Set number of samples used for averaging measurements
'   Valid values: *1, 4, 16, 64, 128, 256, 512, 1024
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CONFIG)
    case smp
        1, 4, 16, 64, 128, 256, 512, 1024:
            smp := lookdownz(smp: 1, 4, 16, 64, 128, 256, 512, 1024) << core.AVG
            smp := ((c & core.AVG_MASK) | smp)
            writereg(core.CONFIG, smp)
        other:
            c := (c >> core.AVG) & core.AVG_BITS
            return lookupz(c: 1, 4, 16, 64, 128, 256, 512, 1024)


PUB voltage_data(ch=0): v
' Read the measured bus voltage, in microvolts
'   NOTE: If averaging is enabled, this will return the averaged value
'   NOTE: Full-scale range is 40_960_000uV
    return readreg(core.BUS_VOLTAGE)


PUB voltage_conv_time(ctm=-2): c
' Set conversion time for bus voltage measurement, in microseconds
'   Valid values: 140, 204, 332, 588, *1100, 2116, 4156, 8244
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CONFIG)
    case ctm
        140, 204, 332, 588, 1100, 2116, 4156, 8244:
            ctm := lookdownz(ctm: 140, 204, 332, 588, 1100, 2116, 4156, 8244) << core.VBUSCT
            ctm := ((c & core.VBUSCT_MASK) | ctm)
            writereg(core.CONFIG, ctm)
        other:
            c := (c >> core.VBUSCT) & core.VBUSCT_BITS
            return lookupz(c: 140, 204, 332, 588, 1100, 2116, 4156, 8244)


PRI readreg(reg_nr, len=2): v | cmd_pkt
' Read nr_bytes from the slave device into ptr_buff
    v := 0
    case reg_nr
        $00..$03, $06, $07, $fe, $ff:
            cmd_pkt.byte[0] := SLAVE_WR | _addr_bits
            cmd_pkt.byte[1] := reg_nr
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)

            i2c.start()
            i2c.write(SLAVE_RD | _addr_bits)
            i2c.rdblock_msbf(@v, len, i2c.NAK)
            i2c.stop()
        other:
            return


PRI writereg(reg_nr, val, len=2) | cmd_pkt
' Write nr_bytes from ptr_buff to the slave device
    case reg_nr
        $00:
            val |= core.RSVD_BITS
        $06, $07:
        other:
            return

    cmd_pkt.byte[0] := SLAVE_WR | _addr_bits
    cmd_pkt.byte[1] := reg_nr
    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.wrblock_msbf(@val, len)
    i2c.stop()

DAT
{
Copyright (c) 2025 Jesse Burt

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

