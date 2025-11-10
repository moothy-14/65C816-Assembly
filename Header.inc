;header for SNES

.segment "HEADER" ;$00FFC0-$00FFF
.byte "Animation Test       " ;rom name 21 chars

.segment "ROMINFO"
.byte $30		; LoROM FastROM
.byte $00		; extra chips in cartridge, 00: no extra RAM; 02: RAM with battery
.byte $08		; ROM size (2^# in kB)
.byte $00		; backup RAM size
.byte $01		; US
.byte $33		; publisher id
.byte $00		; ROM revision number
.word $0000  	; checksum of all bytes
.word $0000  	; $FFFF minus checksum

.segment "VECTORS"
.word $0000
.word $0000

;ffe4 - native mode vectors
.addr Irq_end  ;cop native **
.addr Irq_end  ;brk native **
.addr $0000  ;abort native not used *
.addr Nmi ;nmi native 
.addr Reset ;RESET native
.addr Irq ;irq native

;fff0 not used
.word $0000
.word $0000

;fff4 - emulation mode vectors
.addr Irq_end  ;cop emulation **
.addr $0000 ; not used
.addr $0000  ;abort not used *
.addr Nmi ;nmi emulation
.addr Reset ;RESET emulation
.addr Irq_end ;irq/brk emulation **

;* the SNES doesn't use the ABORT vector
;**the programmer could insert COP or BRK as debugging tools
;The SNES boots up in emulation mode, but then immediately
;  will be set in software to native mode
;IRQ_end is just an RTI
;the vectors here need to be in bank 00
;The SNES never looks at the checksum. Some emulators
;will give a warning message, if the checksum is wrong, 
;but it shouldn't matter. It will still run.