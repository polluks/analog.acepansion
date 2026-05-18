# Makefile for Analog Joystick Z80 Driver
# Requires RASM (Roudoudou's Z80 Assembler)
# https://www.cpcwiki.eu/index.php/Tennis_Cup_2_(cartridge)

RASM    = rasm
OUTPUT  = analog_driver.bin

all: $(OUTPUT)

$(OUTPUT): analog_driver.asm
	$(RASM) $< -ob $@

clean:
	rm -f $(OUTPUT)
