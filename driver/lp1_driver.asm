; LP-1 Light Pen Driver for Amstrad CPC
; Z80 assembly for RASM assembler
;
; Provides routines to read the LP-1 light pen position
; via the joystick port interface.
;
; LP-1 connects to joystick port and uses the DOWN signal
; as a light sensor input. When the pen detects the CRT beam,
; it pulls the DOWN line LOW.
;
; This driver works with the LP-1 ACEpansion plugin for ACE emulator.

; System equates
CRTC_REG_SEL:    equ &BC00      ; CRTC register select port
CRTC_REG_WR:     equ &BD00      ; CRTC register write port
CRTC_STATUS:     equ &BE00      ; CRTC status port (read)
CRTC_REG_RD:     equ &BF00      ; CRTC register read port

PPI_PORTA:       equ &F400      ; PPI Port A - PSG data / keyboard
PPI_PORTB:       equ &F500      ; PPI Port B - status lines
PPI_PORTC:       equ &F600      ; PPI Port C - keyboard row select
PPI_CONTROL:     equ &F700      ; PPI control port

GA_SELECT:       equ &7F00      ; Gate Array select port

AY_REG_SEL:      equ &F600      ; AY register select (via PPI)
AY_REG_RD:       equ &F400      ; AY register read (via PPI)
AY_CTL:          equ &F680      ; AY control lines

; Joystick port bit definitions (read via AY Port A, row 8 or 9)
; Joystick port 0 = keyboard row 8
; Joystick port 1 = keyboard row 9
JOY_UP:          equ 0          ; bit 0
JOY_DOWN:        equ 1          ; bit 1 (LP-1 light sensor)
JOY_LEFT:        equ 2          ; bit 2
JOY_RIGHT:       equ 3          ; bit 3
JOY_FIRE1:       equ 4          ; bit 4
JOY_FIRE2:       equ 5          ; bit 5

; Keyboard row masks for joystick selection
ROW_JOYSTICK_0:  equ %10001110  ; Keyboard row 8, enable AY PSG
ROW_JOYSTICK_1:  equ %10001111  ; Keyboard row 9

; CRTC register indices
CRTC_R14_RASTER: equ 14         ; Raster/line register
CRTC_R12_MA_H:   equ 12         ; Memory Address High
CRTC_R13_MA_L:   equ 13         ; Memory Address Low

; Screen dimensions (CPC mode 0)
SCREEN_WIDTH:    equ 160
SCREEN_HEIGHT:   equ 200

; Driver variables - these should be in a safe RAM area
; They're placed at &A000 (AMSDOS area, typically unused during programs)
                org &A000

lp1_driver_start:

; Variables
pen_x:          ds 2             ; X position (16-bit)
pen_y:          ds 2             ; Y position (16-bit)
pen_visible:    ds 1             ; Pen visibility flag (0=off screen)
pen_button:     ds 1             ; Button state (0=released, non-0=pressed)
calibrate_x:    ds 2             ; X calibration value
calibrate_y:    ds 2             ; Y calibration value
driver_state:   ds 1             ; Driver state byte

; Public API entry points
; ======================

; Initialize the LP-1 driver
; Sets up default calibration values
; Input: none
; Output: none
lp1_init:
                push af
                push hl

                xor a
                ld (pen_x), a
                ld (pen_x+1), a
                ld (pen_y), a
                ld (pen_y+1), a
                ld (pen_visible), a
                ld (pen_button), a
                ld (driver_state), a

                ; Default calibration values (CPC mode 0, 160x200)
                ld hl, SCREEN_WIDTH
                ld (calibrate_x), hl
                ld hl, SCREEN_HEIGHT
                ld (calibrate_y), hl

                pop hl
                pop af
                ret

; Read the current light pen position
; This is the main poll routine - call it frequently
; It will update pen_x, pen_y when the pen detects light
;
; The technique:
; 1. Wait for VSYNC to synchronize beam position
; 2. Select the joystick port keyboard row
; 3. Read the CRTC raster and memory address while polling
; 4. When DOWN goes low (pen triggered), record the position
;
; Input:  A = joystick port (0 or 1)
; Output: CF = 1 if position updated, 0 if not
;         pen_x, pen_y updated with new position
lp1_read_position:
                push bc
                push de
                push hl

                ; Select joystick port
                cp 0
                jr z, .select_port0
                ld a, ROW_JOYSTICK_1
                jr .select_done
.select_port0:
                ld a, ROW_JOYSTICK_0
.select_done:
                ld (driver_state), a

                ; Wait for VSYNC to begin
                call lp1_wait_vsync

                ; Now poll for light pen trigger
                ; At this point the CRT beam is at the top of the screen
                ; We read CRTC position and poll the joystick simultaneously

                ld bc, 0          ; B = raster line counter, C = unused
                ld de, 0          ; DE = MA counter

.poll_loop:
                ; Read CRTC raster register (R14)
                ld bc, CRTC_REG_SEL
                ld a, CRTC_R14_RASTER
                out (c), a
                ld bc, CRTC_REG_RD
                in a, (c)
                ld b, a           ; B = current raster line

                ; Read CRTC memory address (R12:R13)
                ld bc, CRTC_REG_SEL
                ld a, CRTC_R13_MA_L
                out (c), a
                ld bc, CRTC_REG_RD
                in a, (c)
                ld e, a           ; E = MA low byte

                ld bc, CRTC_REG_SEL
                ld a, CRTC_R12_MA_H
                out (c), a
                ld bc, CRTC_REG_RD
                in a, (c)
                ld d, a           ; D = MA high byte

                ; Poll the joystick port for the DOWN signal
                call lp1_read_joystick

                ; Check if DOWN bit is 0 (light detected by LP-1)
                rrca
                rrca              ; shift DOWN bit into carry
                jr c, .not_triggered

                ; Pen triggered! Record the position
                ld a, b
                ld (pen_y), a
                xor a
                ld (pen_y+1), a

                ; Calculate X position from memory address
                ; X = (MA mod screen_width_in_bytes) * pixels_per_byte
                ; Simplified: MA counts characters, each char = 1 byte in mode 0
                ; In mode 0, each byte holds 2 pixels (4 bits per pixel)
                ; so X = (MA % &28) * 2 for mode 0 with 40 byte rows
                ld hl, 0
                ld a, e
                and &3F           ; mask to within a row (max 63 bytes)
                ; For mode 0: X = a * 2 (2 pixels per byte)
                ; For mode 1: X = a * 4 (4 pixels per byte)  
                ; For mode 2: X = a * 1 (8 pixels per byte)
                ; Default: assume mode 0
                add a, a          ; multiply by 2 for mode 0
                ld (pen_x), a
                xor a
                ld (pen_x+1), a

                ; Mark pen as visible
                ld a, 1
                ld (pen_visible), a

                ; Read button state
                call lp1_read_joystick
                bit JOY_FIRE1, a
                jr z, .button_pressed
                xor a
                ld (pen_button), a
                jr .done_trigger

.button_pressed:
                ld a, 1
                ld (pen_button), a
                jr .done_trigger

.not_triggered:
                ; Check if we've passed the visible screen area
                ld a, b
                cp SCREEN_HEIGHT+16  ; allow some vertical overscan
                jr nc, .timeout

                ; Small delay to avoid hammering the bus
                ; and to let the beam advance
                push bc
                ld b, 4
.delay_loop:
                djnz .delay_loop
                pop bc

                jr .poll_loop

.timeout:
                ; Pen not detected this frame
                xor a
                ld (pen_visible), a
                or a              ; CF = 0
                pop hl
                pop de
                pop bc
                ret

.done_trigger:
                scf               ; CF = 1 (position updated)
                pop hl
                pop de
                pop bc
                ret

; Wait for the vertical sync (VSYNC) signal
; This synchronizes us with the start of a new frame
lp1_wait_vsync:
                push af
                push bc

                ; Read PPI Port B to check VSYNC status
                ; Bit 5 = VSYNC (1 = in VSYNC)
.wait_high:
                ld bc, PPI_PORTB
                in a, (c)
                and %00100000     ; check VSYNC bit
                jr nz, .wait_high

.wait_low:
                ld bc, PPI_PORTB
                in a, (c)
                and %00100000     ; wait for VSYNC to go high
                jr z, .wait_low

                pop bc
                pop af
                ret

; Read the joystick port via AY-3-8912
; Uses the pre-selected keyboard row from driver_state
; For the LP-1 on joystick port:
;   Row 8 = joystick port 0
;   Row 9 = joystick port 1 (default for LP-1)
;
; Output: A = joystick state (bits as JOY_UP/DOWN/LEFT/RIGHT/FIRE1/FIRE2)
;             0 = active, 1 = inactive
lp1_read_joystick:
                push bc

                ; Select keyboard row via PPI Port C
                ld a, (driver_state)
                ld bc, PPI_PORTC
                out (c), a

                ; Read AY register 14 (Port A data)
                ; AY register select via PPI
                ld bc, AY_REG_SEL
                ld a, 14          ; AY Register 14 = Port A data
                out (c), a

                ; Toggle AY control lines to latch register
                ld bc, AY_CTL
                ld a, %10000000   ; BC1=0, BDIR=1 (latch)
                out (c), a
                ld a, %00000000   ; BC1=0, BDIR=0 (idle)
                out (c), a

                ; Read the data from AY Port A
                ld bc, AY_REG_RD
                in a, (c)

                ; A contains inverse joystick state
                ; 0 = active (pressed), 1 = inactive
                ; LP-1 sends DOWN = 0 when light detected

                pop bc
                ret

; Get the current X position
; Output: HL = X position
lp1_get_x:
                push af
                ld hl, (pen_x)
                pop af
                ret

; Get the current Y position
; Output: HL = Y position
lp1_get_y:
                push af
                ld hl, (pen_y)
                pop af
                ret

; Check if pen is on screen
; Output: A = 1 if visible, 0 if not
lp1_is_visible:
                push hl
                ld a, (pen_visible)
                pop hl
                ret

; Check pen button state
; Output: A = 1 if pressed, 0 if released
lp1_button_state:
                push hl
                ld a, (pen_button)
                pop hl
                ret

; Simple demonstration routine
; Draws a pixel at the current pen position
; Call this in a loop to track pen movement
;
; Input: IX = pointer to byte-to-pixel mapping table
;        (or 0 to use default mode 0 mapping)
lp1_demo_track:
                push af
                push bc
                push de
                push hl

                ; Read pen position
                ld a, 1           ; joystick port 1 (default for LP-1)
                call lp1_read_position
                jr nc, .no_update

                ; Pen detected - draw a pixel on screen
                ; The CPC screen is organized as:
                ; Each row = 80 bytes (mode 0: 160 pixels x 2bpp)
                ; Screen starts at &C000
                ;
                ; Pixel address = &C000 + Y * 80 + X / 2
                ; Pixel bit position = (X & 1) * 4

                ld hl, (pen_y)
                ld de, 80         ; bytes per scanline
                mul de, hl        ; HL = Y * 80 (RASM supports MUL)
                ld de, (pen_x)
                srl e             ; DE = X / 2
                add hl, de
                ld de, &C000
                add hl, de        ; HL = screen address

                ; Now set the pixel
                ld a, (pen_x)
                and 1
                jr z, .even_pixel
                ; Odd pixel - use upper nibble
                ld a, %11110000
                ld (hl), a
                jr .pixel_set
.even_pixel:
                ; Even pixel - use lower nibble
                ld a, %00001111
                ld (hl), a
.pixel_set:

.no_update:
                pop hl
                pop de
                pop bc
                pop af
                ret

lp1_driver_end:

; Size of the driver code
lp1_driver_size equ lp1_driver_end - lp1_driver_start
