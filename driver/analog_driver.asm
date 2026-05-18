; Analog Joystick Driver for Amstrad CPC/GX4000
; Z80 assembly for RASM assembler
;
; Provides routines to read an analog joystick via the
; GX4000/Plus ADC ports and convert to digital directions,
; based on the Tennis Cup 2 cartridge analog joystick routine.
;
;   https://www.cpcwiki.eu/index.php/Tennis_Cup_2_(cartridge)
;
; The ADC returns values 00h-3Fh (0-63). Center position is 1Fh (31).
; A dead zone of +/-13h (19) around center is applied, so only
; deflections beyond 14h (20) from center register as direction.
;
; Works with the Analog ACEpansion plugin for ACE emulator.

; System equates
PPI_PORTA:     equ &F400  ; PPI Port A - PSG data / keyboard
PPI_PORTB:     equ &F500  ; PPI Port B - status lines
PPI_PORTC:     equ &F600  ; PPI Port C - keyboard row select
PPI_CONTROL:   equ &F700  ; PPI control port

AY_REG_SEL:    equ &F600  ; AY register select (via PPI)
AY_REG_RD:     equ &F400  ; AY register read (via PPI)
AY_CTL:        equ &F680  ; AY control lines

; ADC ports (GX4000/Plus ASIC memory-mapped I/O)
ADC_CH0:       equ 6808h  ; ADC channel 0 - X axis
ADC_CH1:       equ 6809h  ; ADC channel 1 - Y axis

; Joystick bit positions (digital format)
JOY_UP:        equ 0      ; bit 0
JOY_DOWN:      equ 1      ; bit 1
JOY_LEFT:      equ 2      ; bit 2
JOY_RIGHT:     equ 3      ; bit 3
JOY_FIRE1:     equ 4      ; bit 4

; Keyboard row masks for AY PSG
ROW_JOYSTICK_0: equ %10001110  ; Keyboard row 8, enable AY PSG
ROW_JOYSTICK_1: equ %10001111  ; Keyboard row 9

; ADC center and threshold constants
ADC_CENTER:    equ 1Fh    ; center value (31 for 0-63 range)
ADC_THRESH:    equ 14h    ; dead zone threshold (+/-20 from center)

; Driver entry at &A000 (AMSDOS safe RAM area)
                org &A000

; ---- Jump table for fixed entry points ----
                jp analog_init_main    ; &A000 (3 bytes)
                jp analog_read_main    ; &A003 (3 bytes)
; &A006: start of main code area

; ---- Variables (after jump table, accessed via API calls or PEEK) ----
analog_driver_start:

joy_state:      ds 1          ; &A006: combined state bits:
                              ;   bit0=up, bit1=down, bit2=left,
                              ;   bit3=right, bit4=fire1
joy_x_raw:      ds 1          ; &A007: raw ADC X value (00h-3Fh)
joy_y_raw:      ds 1          ; &A008: raw ADC Y value (00h-3Fh)
joy_fire:       ds 1          ; &A009: fire button (0=release, 1=pressed)

; ---- analog_init_main ----
; Initialize AY PSG for joystick reading
; Based on Tennis Cup 2 initialization sequence
; Entry: CALL &A000
; Input: none
; Output: none (variables zeroed)

; Note: &A000 can be CALLed for init (the jump at &A000 points here)
; After init, PEEK the variable addresses above for state

analog_init_main:
                push af
                push bc

                xor a
                ld (joy_state), a
                ld (joy_x_raw), a
                ld (joy_y_raw), a
                ld (joy_fire), a

                ; Configure PPI: Port A = input, Port B = output,
                ; Port C upper = output, Port C lower = output
                ld bc, PPI_CONTROL
                ld a, 82h
                out (c), a

                ; Select AY register 14 (Port A data)
                ld a, 14
                ld bc, AY_REG_SEL
                out (c), a

                ; Toggle AY control: latch register address
                ld bc, AY_CTL
                ld a, %10000000   ; BC1=0, BDIR=1 (latch)
                out (c), a
                ld a, %00000000   ; BC1=0, BDIR=0 (idle)
                out (c), a

                ; Read current AY Port A direction
                ld a, 7
                ld bc, AY_REG_SEL
                out (c), a

                ld bc, AY_CTL
                ld a, %10000000
                out (c), a
                ld a, %00000000
                out (c), a

                ld bc, AY_REG_RD
                in a, (c)
                or %00111111      ; set low 6 bits as input
                ld bc, AY_REG_RD
                out (c), a

                ; Re-select AY register 14 for data reads
                ld a, 14
                ld bc, AY_REG_SEL
                out (c), a
                ld bc, AY_CTL
                ld a, %10000000
                out (c), a
                ld a, %00000000
                out (c), a

                pop bc
                pop af
                ret

; ---- analog_read_main ----
; Read analog joystick and digital fire button.
; Converts ADC values to digital direction bits using
; the Tennis Cup 2 algorithm:
;   - Center at 1Fh, dead zone +/-13h
;   - Deflection >= +14h = direction
;   - Deflection <= -15h = opposite direction
;
; Entry: CALL &A003
; Output: A = joystick state
;         joy_state, joy_x_raw, joy_y_raw, joy_fire updated
analog_read_main:
                push bc

                ; Enable upper ROM to access ADC area
                ; (required on GX4000/Plus for ASIC I/O)
                ld bc, 7FB8h
                out (c), c

                ld c, 0           ; C = accumulator for joystick bits

                ; ---- Read ADC channel 0 (X-axis) ----
                ld a, (ADC_CH0)
                ld (joy_x_raw), a

                sub ADC_CENTER    ; A = deflection from center
                cp ADC_THRESH     ; >= +14h ?
                jp p, .right
                cp -ADC_THRESH    ; <= -15h? (0ECh = -20 = -14h)
                jp m, .left
                jr .x_done        ; dead zone
.right:
                set JOY_RIGHT, c
                jr .x_done
.left:
                set JOY_LEFT, c
.x_done:

                ; ---- Read ADC channel 1 (Y-axis) ----
                ld a, (ADC_CH1)
                ld (joy_y_raw), a

                sub ADC_CENTER    ; A = deflection from center
                cp ADC_THRESH     ; >= +14h ?
                jp p, .down
                cp -ADC_THRESH    ; <= -15h?
                jp m, .up
                jr .y_done
.up:
                set JOY_UP, c
                jr .y_done
.down:
                set JOY_DOWN, c
.y_done:

                ; ---- Read digital fire button ----
                ; Fire comes from digital joystick 1 via keyboard row 9,
                ; following Tennis Cup 2: analog directions + digital fire
                ld a, ROW_JOYSTICK_1
                ld bc, PPI_PORTC
                out (c), a

                ld bc, AY_REG_RD
                in a, (c)
                cpl               ; invert: 1 = active, 0 = inactive
                ld (joy_fire), a
                bit JOY_FIRE1, a
                jr z, .no_fire
                set JOY_FIRE1, c
.no_fire:

                ; Store combined state
                ld a, c
                ld (joy_state), a

                pop bc
                ret

; ---- analog_get_state ----
; Get current joystick state
; Entry: CALL &A006 (returns from variable directly)
; Output: A = joystick state (same as PEEK(&A006))
analog_get_state:
                push hl
                ld a, (joy_state)
                pop hl
                ret

; ---- analog_get_x ----
; Get raw X-axis ADC value
; Entry: CALL &A007
; Output: A = raw ADC X (00h-3Fh)
analog_get_x:
                push hl
                ld a, (joy_x_raw)
                pop hl
                ret

; ---- analog_get_y ----
; Get raw Y-axis ADC value
; Entry: CALL &A008
; Output: A = raw ADC Y (00h-3Fh)
analog_get_y:
                push hl
                ld a, (joy_y_raw)
                pop hl
                ret

; ---- analog_get_fire ----
; Get fire button state
; Entry: CALL &A009
; Output: A = 1 if fire pressed, 0 if released
analog_get_fire:
                push hl
                ld a, (joy_fire)
                pop hl
                ret

; ---- analog_demo_track ----
; Simple demonstration: read joystick and draw direction on screen
; Call in a loop to show current stick position
analog_demo_track:
                push af
                push bc
                push de
                push hl

                call analog_read_main
                ld a, (joy_state)

                ; Display direction on screen
                ; Mode 0 screen at &C000
                ; Draw arrows based on direction bits
                ld hl, &C000 + 40 * 100 + 78    ; center of screen

                bit JOY_UP, a
                jr z, .check_down
                ld (hl), %11110000              ; pixel marker
.check_down:
                bit JOY_DOWN, a
                jr z, .check_left
                ld (hl), %00001111
.check_left:
                bit JOY_LEFT, a
                jr z, .check_right
                ld (hl), %11111111
.check_right:
                bit JOY_RIGHT, a
                jr z, .check_fire
                ld (hl), %10101010
.check_fire:
                bit JOY_FIRE1, a
                jr z, .no_update
                ; Flash border on fire
                ld bc, &7F00
                ld a, 2
                out (c), a
.no_update:
                pop hl
                pop de
                pop bc
                pop af
                ret

analog_driver_end:

; Size of the driver code
analog_driver_size equ analog_driver_end - analog_driver_start
