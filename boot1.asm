;******************************************************************************
;	boot1.asm
;		- a simple bootloader
;
;	OS Development Tutorial
; 	http://www.brokenthorn.com/Resources/OSDev3.html
;******************************************************************************

org					0x7c00				; We are loaded by BIOS at 0x7c00

bits	16								; We are still in 16 bit real mode

Start:
		cli								; Clear all interrupts
		hlt								; Halt the system
		
times 510 - ($-$$) db 0					; We have to be 512 bytes. Clear the
										; rest of the bytes with 0.
										
dw	0xAA55								; Boot signature
