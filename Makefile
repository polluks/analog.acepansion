# Makefile for Analog ACEpansion

ACEPANSION = analog
ACESDK     = /usr/include/
SIMPLECAT  = SimpleCat
CC         = gcc

CFLAGS  += -s -O2 -noixemul -nostdlib -fomit-frame-pointer
CFLAGS  += -D__NOLIBBASE__
CFLAGS  += -Wall -Wextra -Wpointer-arith
CFLAGS  += -I$(ACESDK) -I.

LDFLAGS  = -nostartfiles -noixemul

STRIP    = strip --strip-unneeded --remove-section .comment
OUTPUT   = Release/Plugins/$(ACEPANSION).acepansion

OBJS = o/lib_dummy.o o/acepansion.o o/interface_mui.o

.PHONY: all clean

all: $(OUTPUT)
	@ls -l $<
	-FlushLib $(notdir $(OUTPUT))

clean:
	-rm -rf $(OBJS) o/$(ACEPANSION).db $(OUTPUT) generated/locale_strings.h Release/Catalogs

o/$(ACEPANSION).db: $(OBJS)
	@echo "Linking $@..."
	@$(CC) $(LDFLAGS) $(OBJS) -o $@

$(OUTPUT): o/$(ACEPANSION).db
	@echo "Stripping $<..."
	@$(STRIP) -o $(OUTPUT) $<

o/acepansion.o: acepansion.c acepansion.h interface.h generated/locale_strings.h
	@echo "Compiling $@..."
	@$(CC) $(CFLAGS) -c -o $@ $<

o/interface_mui.o: interface_mui.c interface.h acepansion.h generated/locale_strings.h
	@echo "Compiling $@..."
	@$(CC) $(CFLAGS) -c -o $@ $<

o/lib_dummy.o: $(ACESDK)/acepansion/lib_dummy.c acepansion.h
	@echo "Compiling $@..."
	@$(CC) $(CFLAGS) -c -o $@ $<

generated/locale_strings.h: catalogs.cs
	@echo "Generating catalogs..."
	@$(SIMPLECAT) catalogs.cs QUIET
