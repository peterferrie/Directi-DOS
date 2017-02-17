;fast boot-loader in one sector
;"special delivery" version for Directi-DOS
;copyright (c) Peter Ferrie 2016
;thanks to 4am for inspiration and testing
;assemble using ACME
!cpu 6502
!to "fstbt",plain

        ; Disk
        PHASEOFF  = $c080
        PHASEON   = $c081

        ; P6PROM
        P6BUFF    = $26   ; ZP: 16-bit pointer to decoded disk nibbles
        P6SLOTx16 = $2b   ; ZP: Slot * 16, #$C600 -> #$60
        P6SECTOR  = $3D   ; ZP: Sector to read
        P6TRKHAVE = $40   ; ZP: Track Found or Actual
        P6TRKWANT = $41   ; ZP: Track Wanted or Expected
        P6READSEC = $c05c ; + P6SLOTx16 = $C65c: CLC, PHP, read sector

        ; Text Screen Holes
        ; Apple II Monitors Peeled, Page 16, Peripheral Controller Work Areas
        ; Laser 128 Reference Manual, Page 52, Figure 5.2, 4o Column Text Mode
        ;
        ; |Row |Slot 0|Slot 1|Slot 2|Slot 3|Slot 4|Slot 5|Slot 6|Slot 7|
        ; |:--:|:-----|:-----|:-----|:-----|:-----|:-----|:-----|:-----|
        ; |  0 | $478 | $479 | $47A | $47B | $47C | $47D | $47E | $47F |
        ; |  1 | $4F8 | $4F9 | $4FA | $4FB | $4FC | $4FD | $4FE | $4FF |
        ; |  2 | $578 | $579 | $57A | $57B | $57C | $57D | $57E | $57F |
        ; |  3 | $5F8 | $5F9 | $5FA | $5FB | $5FC | $5FD | $5FE | $5FF |
        ; |  4 | $678 | $679 | $67A | $67B | $67C | $67D | $67E | $67F |
        ; |  5 | $6F8 | $6F9 | $6FA | $6FB | $6FC | $6FD | $6FE | $6FF |
        ; |  6 | $778 | $779 | $77A | $77B | $77C | $77D | $77E | $77F |
        ; |  7 | $7F8 | $7F9 | $7FA | $7FB | $7FC | $7FD | $7FE | $7FF |
        TXTHOLE00 = $478
        TXTHOLE31 = $4fb

        ; Graphics!
        SCRN2     = $f879

        ; Mem/Softswitches
        ROMIN     = $c081 ; Disable LC Bank, read ROM
        LCBANK2   = $c083
        CLR80VID  = $c00c ; OFF 80-column display mode
        CLRALTCH  = $c00e ; OFF alternate character set (MouseText)

        ; Misc
        INIT      = $fb2f ; Set Text Mode, Set Window
        WAIT      = $fca8 ; wait _minimum_ 1/2(26+27 A+5A'^2) cycles -> *14 / 14.318181 uSeconds; see: Technote #12: The Apple II Firmware WAIT Routine
        SETKBD    = $fe89 ; IN#0
        SETVID    = $fe93 ; PR#0


;       .org $0800 ; 16-sector P6PROM Reads T0S0 into $0800
*=$800

!byte 1     ; First Byte = Number of sectors to read

        tay                     ;A is last read sector+1 on entry
        lda     ROMIN           ;bank in ROM

        ;check array before checking sector number
        ;allows us to avoid a redundant seek if all slots are full in a track,
        ;and then the list ends

incindex
        inc     adrindex + 1    ;select next address

adrindex
        lda     adrtable - 1    ;15 entries in first row, 16 entries thereafter
        sta     TXTHOLE31       ;set 80-column state (final store is an #$FF to disable it)
        cmp     #$FF
        beq     jmpoep          ;#$FF means end of data
        sta     P6BUFF+1        ;set high part of address

        ;2, 4, 6, 8, $0A, $0C, $0E
        ;because PROM increments by one itself
        ;and is too slow to read sectors in purely incremental order
        ;so we offer every other sector for read candidates

        iny
        cpy     #$10            ; 16 sectors/track
        bcc     setsector       ;cases 1-$0F
        beq     sector1         ;finished with $0E
                                ;next should be 1 for 1, 3, 5, 7... sequence

        ;finished with $0F, now we are $11, so 16 sectors done

        jsr     seek            ;returns A=0

        ;back to 0

        tay
        !byte   $2C             ; BIT $xxyy: mask LDY #1
sector1
        ldy     #1

setsector
        sty     P6SECTOR        ;set sector
        iny                     ;prepare to be next sector in case of unallocated sector
        lda     P6BUFF+1
        beq     incindex        ;empty slot, back to the top

        ;convert slot to PROM address

                                ; F879 SCRN2   BCC    RTMASKZ
                                ; F87B         LSR
                                ; F87C         LSR
                                ; F87D         LSR
                                ; F87E         LSR
                                ; F87F RTMASKZ AND #$0F
                                ; F881         RTS
        txa
        jsr     SCRN2+2         ;4xlsr
        tay
        ora     #>P6READSEC     ; Hi: $C0 -> $C65C = P6ReadSector
        pha
        lda     #<P6READSEC-1   ; Lo: $5B -> P6ReadSector-1
        pha
        lda     #2
        sta     TXTHOLE00, y    ;save current phase for DOS use when we exit

writeenable
        lda     LCBANK2
        lda     LCBANK2        ;write-enable RAM and bank it in so read can decode
        rts                     ;return to PROM

seek
        inc     P6TRKWANT       ;next track
        asl     P6TRKHAVE       ;carry clear, phase off
        jsr     seek1           ;returns carry set, not useful
        clc                     ;carry clear, phase off

seek1
        jsr     delay           ;returns with carry set, phase on
        inc     P6TRKHAVE       ;next phase

delay
        lda     P6TRKHAVE
        and     #3
        rol
        ora     P6SLOTx16       ;merge in slot
        tay
        lda     PHASEOFF, y
        lda     #$30
        jmp     WAIT            ;common delay for all phases

jmpoep
        jsr     SETKBD          ;rehook keyboard (needed particularly after PR#)
        jsr     SETVID          ;rehook video
        jsr     INIT            ;text mode
        sta     CLR80VID
        sta     CLRALTCH        ;clear 80-column mode
        jsr     writeenable     ;bank in our RAM, write-enabled
        jmp     $D000           ;jump to unpacker

adrtable
!byte $dd,$dc,$db,$da,$d9,$d8,$d7,$d6,$d5,$d4,$d3,$d2,$d1,$d0,$de
!byte $df,$ed,$ec,$eb,$ea,$e9,$e8,$e7,$e6,$e5,$e4,$e3,$e2,$e1,$e0,$ee
!byte $FF ;end of list
