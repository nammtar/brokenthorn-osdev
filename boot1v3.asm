;******************************************************************************
;	boot1.asm
;		- a simple bootloader
;
;	OS Development Tutorial
; 	http://www.brokenthorn.com/Resources/OSDev4.html
;******************************************************************************

org					0x7c00				; We are loaded by BIOS at 0x7c00

bits	16								; We are still in 16 bit real mode

start:	jmp 	loader					; Jump over OEM block

;******************************************************************************
;	OEM Parameter block
;******************************************************************************

TIMES	0Bh-$+start		DB	0

bpbBytesPerSector:		DW	512
bpbSectorsPerCluster:	DB	1
bpbReservedSectors:		DW	1
bpbNumberOfFATs:		DB	2
bpbRootEntries:			DW	224
bpbTotalSectors:		DW	2880
bpbMedia:				DB	0xF0
bpbSectorsPerFAT:		DW	9
bpbSectorsPerTrack:		DW	18
bpbHeadsPerCylinder:	DW	2
bpbHiddenSectors:		DD	0
bpbTotalSectorsBig:		DD	0
bsDriveNumber:			DB	0
bsUnused:				DB	0
bsExtBootSignature:		DB	0x29
bsSerialNumber:			DD	0xa0a1a2a3
bsVolumeLabel			DB	"MOS FLOPPY "
bsFileSystem			DB	"FAT12   "

msg						DB	"Welcome to My Operating System!", 0

;**************************************
; Prints a string
; DS=>SI: 0 terminated string
;**************************************
print:
		lodsb
		or		al, al					; al=current character
		jz		printDone				; null terminator found
		mov		ah, 0eh					; get next character
		int		10h
		jmp		print
printDone:
		ret

;******************************************************************************
;	Bootloader Entry Point
;******************************************************************************
loader:

; --- Error fix 1 -------------------------------------------------------------
		xor		ax, ax					; Setup segments to ensure they are 0.
		mov		ds, ax					; Remember that we have ORG 0x7c00. This
		mov		es, ax					; means all addresses are based from
										; 0x7c00:0. Because the data segments
										; are within the same code segment, 
										; null them.
										
		mov		si, msg
		call	print
		
		xor		ax, ax					; Clear ax
		int		0x12					; Get the amount of KB from BIOS

		cli								; Clear all interrupts
		hlt								; Halt the system
		
times 510 - ($-$$) db 0					; We have to be 512 bytes. Clear the
										; rest of the bytes with 0.
										
dw	0xAA55								; Boot signature
