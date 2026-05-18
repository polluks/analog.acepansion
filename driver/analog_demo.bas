10 REM Analog Joystick Demonstration Program
20 REM For Amstrad CPC/GX4000 with Analog ACEpansion
30 REM Based on Tennis Cup 2 analog joystick routine
40 REM 
50 MEMORY &9FFF
60 LOAD"analog_driver.bin",&A000
70 
80 REM Initialize the driver
90 CALL &A000
100 
110 MODE 0
120 BORDER 0
130 INK 0,0:INK 1,24:INK 2,6:INK 3,15
140 
150 REM Draw instruction
160 LOCATE 1,23:PRINT"Analog Joystick Demo - Move stick & press fire!"
170 LOCATE 1,24:PRINT"X:      Y:      Fire:"
180 
190 REM Main loop - read analog joystick
200 CALL &A003          : REM Read analog joystick
210 
220 x=PEEK(&A007)       : REM Read raw X (0-63)
230 y=PEEK(&A008)       : REM Read raw Y (0-63)
240 f=PEEK(&A009)       : REM Read fire state
250 
260 REM Display raw values
270 LOCATE 4,24:PRINT STRING$(4," ")
280 LOCATE 4,24:PRINT x
290 LOCATE 12,24:PRINT STRING$(4," ")
300 LOCATE 12,24:PRINT y
310 LOCATE 22,24:PRINT STRING$(4," ")
320 LOCATE 22,24:PRINT f
330 
340 REM Draw a crosshair at position based on joystick deflection
350 px=80+(x-31)*2      : REM Map X 0-63 to screen coords
360 py=100+(y-31)*2     : REM Map Y 0-63 to screen coords
370 PLOT px,py,1
380 
390 REM Check fire button
400 IF f=0 GOTO 190
410 PLOT px,py,2        : REM Draw in color 2 when firing
420 
430 GOTO 190
