10 REM LP-1 Light Pen Demonstration Program
20 REM For Amstrad CPC with LP-1 ACEpansion
30 REM 
40 MEMORY &9FFF
50 LOAD"lp1_driver.bin",&A000
60 
70 REM Initialize the driver
80 CALL &A003
90 
100 MODE 0
110 BORDER 0
120 INK 0,0:INK 1,24:INK 2,6:INK 3,15
130 
140 REM Draw a button grid
150 FOR y=0 TO 3
160   FOR x=0 TO 3
170     LOCATE x*10+1,y*5+1
180     PRINT CHR$(143);
190     LOCATE x*10+5,y*5+1
200     PRINT "BUTTON";x+y*4+1
210   NEXT x
220 NEXT y
230 
240 REM Draw instruction
250 LOCATE 1,22:PRINT"LP-1 Light Pen Demo - Point & click!"
260 
270 REM Main loop - track pen and detect clicks
280 CALL &A006   : REM Read position (port 1)
290 IF NOT PEEK(&A008) GOTO 280  : REM If not visible, skip
300 
310 x=PEEK(&A000)+PEEK(&A001)*256  : REM Read X
320 y=PEEK(&A002)+PEEK(&A003)*256  : REM Read Y
330 
340 REM Draw a crosshair at pen position
350 PLOT x,y,1
360 
370 REM Check button state
380 IF PEEK(&A00A)=0 GOTO 280
390 
400 REM Button pressed - draw in color 2
410 PLOT x,y,2
420 
430 REM Wait for button release
440 CALL &A006:CALL &A012
450 IF PEEK(&A00A) GOTO 440
460 
470 GOTO 280
