;******************************************************************************
;	stage1.asm
;		- a simple bootloader
;
;	Operating System Development Series
;******************************************************************************

bits	16					; We are in 16 bit real mode

org		0					; We will set registers later

start:	
		jmp		main		; Jump to start of bootloader

;******************************************************************************
;	BIOS parameter block
;******************************************************************************

; BPB begins 3 bytes from start. We do a far jump, which is 3 bytes in size.
; If you use a short jump, add a "nop" after it to offset the 3rd byte.

bpbOEM						DB	"My OS   "	; OEM id (can't excees 8 bytes!)
bpbBytesPerSector:			DW	512
bpbSectorsPerCluster:		DB	1
bpbReservedSectors:			DW	1
bpbNumberOfFATs:			DB	2
bpbRootEntries:				DW	224
bpbTotalSectors:			DW	2880
bpbMedia:					DB	0xF8		;; 0xF1
bpbSectorsPerFAT:			DW	9
bpbSectorsPerTrack:			DW	18
bpbHeadsPerCylinder:		DW	2
bpbHiddenSectors:			DD	0
bpbTotalSectorsBig:			DD	0
bsDriveNumber:				DB	0
dsUnused:					DB	0
bsExtBootSignature:			DB	0x29
bsSerialNumber:				DD	0xa0a1a2a3
bsVolumeLabel:				DB	"MOS FLOPPY "
bsFileSystem:				DB	"FAT12  "

;******************************************************************************
;	Prints a string
;	DS=>SI: 0 terminated string
;******************************************************************************
Print:
		lodsb				; Load next byte from string from SI to AL
		or		al, al		; Does AL=0?
		jz		PrintDone	; Yes, null terminator found: bail out
		mov		ah, 0Eh		; No: print the character
		int		10h
		jmp		Print		; Repeat until null terminator found
PrintDone:
		ret					; We are done, so return
		
;******************************************************************************
;	Reads a series of sectors
; 	CX    => Number of sectors to read
; 	AX    => Starting sector
; 	ES:BX => Address of buffer to read to
;******************************************************************************
ReadSectors:
	.MAIN:
		mov		di, 0x0005	; Five retries for error
	.SECTORLOOP:
		push	ax
		push	bx
		push	cx
		call	LBACHS		; Convert starting sector to CHS
		mov		ah, 0x02	; BIOS function 2: read sector
		mov		al, 0x01	; Read one sector
		mov		ch, BYTE [absoluteTrack]	; Cylinder (Track)
		mov		cl, BYTE [absoluteSector]	; Sector
		mov		dh, BYTE [absoluteHead]		; Head
		mov		dl, BYTE [bsDriveNumber]	; Drive
		int		0x13		; Invoke BIOS
		jnc		.SUCCESS	; Test for read error
		xor		ax, ax		; BIOS function 0: reset disk
		int		0x13		; Invoke BIOS
		dec		di			; Decrement error counter
		pop		cx
		pop		bx
		pop		ax
		jnz		.SECTORLOOP	; If retry count not reached, attempt to read again
		int		0x18		; Failure to boot from disk, attempt to invoke BASIC
	.SUCCESS:
		mov		si, msgProgress
		call	Print
		pop		cx
		pop		bx
		pop		ax
		add		bx, WORD [bpbBytesPerSector]	; Queue next buffer
		inc		ax			; Queue next sector
		loop	.MAIN		; Read next sector
		ret
		
;******************************************************************************
;	Convert CHS to LBA
;	LBA = (cluster - 2) * <sectors per cluster>
;******************************************************************************
ClusterLBA:
		sub		ax, 0x0002	; Zero based cluster number
		xor		cx, cx		; Clear CX
		mov		cl, BYTE [bpbSectorsPerCluster]	; Convert byte to word
		mul		cx			; AX = AX * CX
		add		ax, WORD [datasector]	; Base data sector
		ret
		
;******************************************************************************
;	Convert LBA to CHS
; 	AX => LBA address to convert
;
;	absolute sector = (logical sector / sectors per track) + 1
;	absolute head = (logical sector / sectors per track) MOD number of heads
;	absolute track = logical sector / (sectors per track * number of heads)
;******************************************************************************
LBACHS:
		xor		dx, dx						; Clear DX
		div		WORD [bpbSectorsPerTrack]	; Calculate (logical sectors / 
											; 	sectors per track)
		inc		dl							; Adjust for sector 0 (add 1)
		mov		BYTE [absoluteSector], dl
		xor		dx, dx						; Clear DX
		div		WORD [bpbHeadsPerCylinder]	; Calculate
		mov		BYTE [absoluteHead], dl
		mov 	BYTE [absoluteTrack], al
		ret
		
;******************************************************************************
;	Bootloader entry point
;******************************************************************************
main:
	;-----------------------------------------------------
	; Code located at 0000:7C00, adjust segment registers
	;-----------------------------------------------------
		cli					; Disable interrupts
		mov		ax, 0x07C0	; Setup segment registers to point to our segment
		mov		ds, ax
		mov		es, ax
		mov		fs, ax
		mov		gs, ax
		
	;-----------------------------------------------------
	; Create stack
	;-----------------------------------------------------
		mov		ax, 0x0000	; Set the stack segment to 0
		mov		ss, ax		; and store in stack segment register
		mov		sp, 0xFFFF	; Set stack pointer to top of stack 
		sti					; Restore interrupts
		
	;-----------------------------------------------------
	; Display loading message
	;-----------------------------------------------------
		mov		si, msgLoading
		call	Print
		
	;-----------------------------------------------------
	; Load root directory table
	;-----------------------------------------------------
	LOAD_ROOT:
	; Compute size of root directory and store in CX
		xor		cx, cx
		xor		dx, dx
		mov		ax, 0x0020	; Directory entries are 32 (0x20) bytes
		mul		WORD [bpbRootEntries]		; Total size of directory
		div		WORD [bpbBytesPerSector]	; Sectors used by directory
		xchg	ax, cx
	
	; Compute location of root directory and store in AX
		mov		al, BYTE [bpbNumberOfFATs]		; Number of FATs
		mul		WORD [bpbSectorsPerFAT]			; Sectors used by FATs
		add		ax, WORD [bpbReservedSectors]	; Adjust for bootsector
		mov		WORD [datasector], ax			; Base of root directory
		add		WORD [datasector], cx
		
	; Read root directory into memory (7C00:0200)
		mov		bx, 0x0200		; Copy root dir above bootcode
		call	ReadSectors
		
	;-----------------------------------------------------
	; Find stage 2
	;-----------------------------------------------------
	; Browse root directory for binary image
		mov		cx, WORD [bpbRootEntries]	; Load loop counter
		mov		di, 0x0200					; Locate first root entry
	.LOOP:
		push	cx
		mov		cx, 0x000B					; Eleven charactor name
		mov		si, ImageName				; Image name to find
		push	di
		rep	cmpsb							; Test for entry match
		pop		di
		je		LOAD_FAT					; If entry matched, jump to LOAD_FAT
		pop		cx							; Entry didn't match
		add		di, 0x0020					; Check next entry
		loop	.LOOP
		jmp		FAILURE						; No matching entry found, jump to
											; 	FAILURE
		
	;-----------------------------------------------------
	; Load FAT
	;-----------------------------------------------------
	LOAD_FAT:
	; Save starting cluster of boot image
		mov		si, msgCRLF					; Print message
		call	Print
		mov		dx, WORD [di + 0x001A]		; Get cluster number from dir entry
		mov		WORD [cluster], dx			; File's first cluster
		
	; Compute size of FAT and store in CX
		xor		ax, ax
		mov		al, BYTE [bpbNumberOfFATs]	; Number of FATs
		mul		WORD [bpbSectorsPerFAT]		; Multiply by sectors per FAT
		mov		cx, ax						; Store result in CX
		
	; Compute location of FAT and store in AX
		mov		ax, WORD [bpbReservedSectors]	; Adjust for bootsector
		
	; Read FAT into memory (7C00:0200)
		mov		bx, 0x0200					; Copy FAT above bootcode
		call	ReadSectors
		
	; Read image file into memory (0050:0000)
		mov		si, msgCRLF					; Print message
		call	Print
		mov		ax, 0x0050					; File segment is 0x0050
		mov		es, ax						; Store in segment register ES
		mov		bx, 0x0000					; Set offset to 0
		push 	bx							; Push offset to stack
		
	;-----------------------------------------------------
	; Load stage 2
	;-----------------------------------------------------
	LOAD_IMAGE:
		mov		ax, WORD [cluster]			; Cluster to read
		pop		bx							; Buffer to read into
		call	ClusterLBA					; Convert cluster to LBA
		xor		cx, cx
		mov		cl, BYTE [bpbSectorsPerCluster]	; Sectors to read
		call	ReadSectors
		push	bx
		
	; Compute next cluster
		mov		ax, WORD [cluster]			; Identify current cluster
		mov		cx, ax						; Copy current cluster
		mov		dx, ax						; Copy current cluster
		shr		dx, 0x0001					; Divide by 2
		add		cx, dx						; Sum for (3/2)
		mov		bx, 0x0200					; Location of FAT in memory
		add		bx, cx						; Index into FAT
		mov		dx, WORD [bx]				; Read two bytes from FAT
		test	ax, 0x0001
		jnz		.ODD_CLUSTER
		
	.EVEN_CLUSTER:
		and		dx, 0000111111111111b		; Take low twelve bits
		jmp		.DONE
		
	.ODD_CLUSTER:
		shr		dx, 0x0004					; Take high twelve bits
		
	.DONE:
		mov		WORD [cluster], dx			; Store new cluster
		cmp 	dx, 0x0FF0					; Test for end of file
		jb		LOAD_IMAGE
		
	DONE:
		mov		si, msgCRLF
		call 	Print
		push	WORD 0x0050
		push	WORD 0x0000
		retf
		
	FAILURE:
		mov		si, msgFailure
		call	Print
		mov		ah, 0x00
		int		0x16						; Await keypress
		int		0x19						; Warm boot computer
		
absoluteSector		db	0x00
absoluteHead		db	0x00
absoluteTrack		db	0x00

datasector			dw	0x0000
cluster				dw	0x0000
ImageName			db	"KRNLDR  SYS"
msgLoading			db	0x0D, 0x0A, "Loading Boot Image ", 0x0D, 0x0A, 0x00
msgCRLF				db	0x0D, 0x0A, 0x00
msgProgress			db	".", 0x00
msgFailure			db	0x0D, 0x0A, "ERROR: Press any key to reboot", 0x0A, 0x00

TIMES	510-($-$$)	db	0
					dw	0xAA55
