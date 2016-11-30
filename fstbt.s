;fast boot-loader in one sector
;"special delivery" version for Directi-DOS
;copyright (c) Peter Ferrie 2016
;thanks to 4am for inspiration and testing
;assemble using ACME
!cpu 6502
!to "fstbt",plain
*=$800

!byte 1

        tay                     ;A is last read sector+1 on entry
        lda     $C081           ;bank in ROM while leaving RAM write-enabled if it was before

        ;check array before checking sector number
        ;allows us to avoid a redundant seek if all slots are full in a track,
        ;and then the list ends

incindex
        inc     adrindex + 1    ;select next address

adrindex
        lda     adrtable - 1    ;15 entries in first row, 16 entries thereafter
        sta     $4FB            ;set 80-column state (final store is an #$FF to disable it)
        cmp     #$FF
        beq     jmpoep          ;#$C0 means end of data
        sta     $27             ;set high part of address

        ;2, 4, 6, 8, $0A, $0C, $0E
        ;because PROM increments by one itself
        ;and is too slow to read sectors in purely incremental order
        ;so we offer every other sector for read candidates

        iny
        cpy     #$10
        bcc     setsector       ;cases 1-$0F
        beq     sector1         ;finished with $0E
                                ;next should be 1 for 1, 3, 5, 7... sequence

        ;finished with $0F, now we are $11, so 16 sectors done

        jsr     seek            ;returns A=0

        ;back to 0

        tay
        !byte   $2C             ;mask LDY #1
sector1
        ldy     #1

setsector
        sty     $3D             ;set sector
        iny                     ;prepare to be next sector in case of unallocated sector
        lda     $27
        beq     incindex        ;empty slot, back to the top

        ;convert slot to PROM address

        txa
        lsr
        lsr
        lsr
        lsr
        tay
        ora     #$C0
        pha
        lda     #$5B            ;read-1
        pha
        lda     #2
        sta     $478, y         ;save current phase for DOS use when we exit
        lda     $C083
        lda     $C083           ;write-enable RAM and bank it in so read can decode
        rts                     ;return to PROM

seek
        inc     $41             ;next track
        asl     $40             ;carry clear, phase off
        jsr     seek1           ;returns carry set, not useful
        clc                     ;carry clear, phase off

seek1
        jsr     delay           ;returns with carry set, phase on
        inc     $40             ;next phase

delay
        lda     $40
        and     #3
        rol
        ora     $2B             ;merge in slot
        tay
        lda     $C080, y
        lda     #$30
        jmp     $FCA8           ;common delay for all phases

jmpoep
        jsr     $FE89           ;rehook keyboard (needed particularly after PR#)
        jsr     $FE93           ;rehook video
        jsr     $FB2F           ;text mode
        sta     $C00C
        sta     $C00E           ;clear 80-column mode
        lda     $C083           ;bank in our RAM, write-enabled
        jmp     $D000           ;jump to unpacker

adrtable
!byte $dd,$dc,$db,$da,$d9,$d8,$d7,$d6,$d5,$d4,$d3,$d2,$d1,$d0,$de
!byte $df,$ed,$ec,$eb,$ea,$e9,$e8,$e7,$e6,$e5,$e4,$e3,$e2,$e1,$e0,$ee
!byte $FF ;end of list
