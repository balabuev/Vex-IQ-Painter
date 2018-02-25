import sys
import vexiq

#region config
lm  = vexiq.Motor(1)
rm  = vexiq.Motor(2, True) # Reverse Polarity
um  = vexiq.Motor(3)
ub  = vexiq.Bumper(4)
led = vexiq.TouchLed(5)
#endregion config

POSITIVE_OFFSET = 10000
GEARS_RATIO     = 5 * 3
READY_STR       = '\x0AVP_\x01\x0A'
READY_POS       = 30 * GEARS_RATIO

def main():
    while True:
        if sp.bytes_to_read() > 0:
            cmd = sp.read_byte()

            if cmd == 1:
                setup()
            elif cmd == 2:
                arg = sp.read_bytes(4)
                draw(ord(arg[0]) + ord(arg[1]) * 256 - POSITIVE_OFFSET,
                     ord(arg[2]) + ord(arg[3]) * 256 - POSITIVE_OFFSET)
            elif cmd == 3:
                arg = sp.read_bytes(4)
                move(ord(arg[0]) + ord(arg[1]) * 256 - POSITIVE_OFFSET,
                     ord(arg[2]) + ord(arg[3]) * 256 - POSITIVE_OFFSET)
            elif cmd == 4:
                drawing_finished()
            else:
                assert False

            sp.write(READY_STR, False) # ready

def move(a1, a2):
    led.named_color(vexiq.NamedColor.BLUE)
    move_up()
    move_to_pos(a1, a2)

def draw(a1, a2):
    led.named_color(vexiq.NamedColor.BLUE)
    move_down()
    move_to_pos(a1, a2)

def drawing_finished():
    move_up()
    move_to_pos(READY_POS, READY_POS)
    led.off()

def move_to_pos(a1, a2):
    lm.run_to_position(100, a1)
    rm.run_to_position(100, a2)

    while not lm.reached_target() or \
          not rm.reached_target():
        pass

def move_up():
    if um.position() > 90:
        um.run_until_position(100, 70)

def move_down():
    if um.position() < 90:
        um.run_until_position(50, 120)

def setup():
    led.named_color(vexiq.NamedColor.BLUE)
    led.blink(0.2, 0.2)

    um.off()
    lm.off()
    rm.off()

    setup_up_motor(30)
    setup_motor(lm, rm, 47 * GEARS_RATIO)
    setup_motor(rm, lm, 47 * GEARS_RATIO)
    move_to_pos(READY_POS, READY_POS)

    led.off()

def setup_up_motor(corr):
    um.run(30)
    while ub.is_pressed():
        sys.sleep(1)
    while not ub.is_pressed():
        pass
    um.run_until(30, corr)
    sys.sleep(0.3)
    um.reset_position()
    um.off()

def setup_motor(m, m2, corr):
    m.set_max_current(15)
    m.run(-100)
    while not m.stalled():
        pass
    sys.sleep(0.2)

    m.reset_position()
    m.run_until_position(100, corr, True)
    sys.sleep(0.2)

    m.reset_position()

    m.off()
    m.set_max_current(100)

sp = vexiq.Serial()
while sp.bytes_to_read() > 0: # Empty queue
    sp.read_bytes()           #
main()
