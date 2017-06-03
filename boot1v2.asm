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

;******************************************************************************
;	Bootloader Entry Point
;******************************************************************************

loader:
		cli								; Clear all interrupts
		hlt								; Halt the system
		
times 510 - ($-$$) db 0					; We have to be 512 bytes. Clear the
										; rest of the bytes with 0.
										
dw	0xAA55								; Boot signature
