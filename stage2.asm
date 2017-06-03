; Note: Here, we are executed like a normal
; COM program, but we are still in Ring 0.
; We will use this loader to set up 32 bit
; mode and basic exception handling
 
; This loaded program will be our 32 bit Kernel.
 
; We do not have the limitation of 512 bytes here,
; so we can add anything we want here!

org 0x0			; Offset to 0, we will set segments later

bits 16			; We are still in real mode

; We are loaded at linear address 0x10000

jmp main		; Jump to main

;******************************************************************************
;		Prints a string
;		DS=>SI: 0 terminated string
;******************************************************************************

Print:
					lodsb				; Load next byte from from SI to AL
					or		al, al		; Is AL=0?
					jz		PrintDone	; Yep, null terminator found - bail out
					mov		ah, 0eh		; Nope, print the character
					int		10h
					jmp		Print		; Repeat until null terminator found
PrintDone:
					ret					; We are done, so return

;******************************************************************************
;		Second stage loader entry point
;******************************************************************************

main:
					cli					; Clear interrupts
					push	cs			; Ensure DS=CS
					pop		ds
					
					mov		si, Msg
					call 	Print
					
					cli					; Clear interrupts to prevent triple flt
					hlt					; Halt the system
					
;******************************************************************************
;		Data section
;******************************************************************************

Msg		db		"Preparing to load operating system...", 13, 10, 0
