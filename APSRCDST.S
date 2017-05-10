;license:BSD-3-Clause
;aPLib data decompressor for Apple II
;Peter Ferrie (peter.ferrie@gmail.com)
;assemble using ACME
;src<dst
!cpu 6502
!to "aplib",plain
*=$d000

;unpacker variables, no need to change these
src  = $0
dst  = $2
ecx  = $4
last = $6
tmp  = $8

        lda     #>pakoff
        sta     src+1
        lda     #<pakoff
        sta     src
        lda     #0
        sta     dst+1
        sta     dst
        sta     last
        sta     ecx+1
        jsr     unpack
        tay ;returns A=0
-       lda     $d600, y
        sta     $bf00, y
        iny
        bne     -
        ldx     $2b
        stx     $bfd6 ;set current slot in RWTS
        stx     $bfe4 ;set previous slot in RWTS
        ldx     #$16
--      stx     src
        txa
        asl
        bit     src
        beq     +
        ora     src
        eor     #$ff
        and     #$7e
-       bcs     +
        lsr
        bne     -
        tya
        sta     $fa80, x ;regenerate tables
        txa
        ora     #$80
        sta     $fa29, y ;regenerate tables
        iny
+       inx
        bpl     --
        tax ;A=FF
        txs ;clean stack
        jmp     $dd84 ;DOS entrypoint

unpack ;unpacker entrypoint

literal
        jsr     getput
        ldy     #2

nexttag
        jsr     getbit
        bcc     literal
        jsr     getbit
        bcc     codepair
        jsr     getbit
        bcs     onebyte
        jsr     getsrc
        lsr
        beq     donedepacking
        ldx     #0
        stx     ecx
        rol     ecx
        stx     last+1
        tax
        bne     domatch_with_2inc

getbit
        asl     last
        bne     .stillbitsleft
        jsr     getsrc
        asl
        sta     last
        inc     last

.stillbitsleft

donedepacking
        rts

onebyte
        ldy     #1
        sty     ecx
        iny
        lda     #0
        sta     tmp+1
        lda     #$10

.getmorebits
        pha
        jsr     getbit
        pla
        rol
        bcc     .getmorebits
        bne     domatch
        jsr     putdst

linktag
        bne     nexttag

codepair
        jsr     getgamma
-       jsr     dececx
        dey
        bne     -
        tay
        ora     ecx+1
        beq     +

normalcodepair
        dey
        sty     last+1
        jsr     getsrc
        tax
        !byte   $a9
+       iny
        jsr     getgamma
        cpy     #$7d
        bcs     domatch_with_2inc
        cpy     #5
        bcs     domatch_with_inc
        txa
        bmi     domatch_new_lastpos
        tya
        bne     domatch_new_lastpos

domatch_with_2inc
        inc     ecx
        bne     domatch_with_inc
        inc     ecx+1

domatch_with_inc
        inc     ecx
        bne     domatch_new_lastpos
        inc     ecx+1

domatch_new_lastpos

domatch_lastpos
        ldy     #1
        lda     last+1
        sta     tmp+1
        txa

domatch
        sta     tmp
        lda     src+1
        pha
        lda     src
        pha
        lda     dst
        clc
        adc     tmp
        sta     src
        lda     dst+1
        adc     tmp+1
        sta     src+1
-       jsr     getput
        jsr     dececx
        ora     ecx+1
        bne     -
        pla
        sta     src
        pla
        sta     src+1
        bne     linktag

getgamma
        lda     #1
        sta     ecx
        sta     ecx+1
        dec     ecx+1

.getgammaloop
        jsr     getbit
        rol     ecx
        rol     ecx+1
        jsr     getbit
        bcs     .getgammaloop
        rts

dececx
        lda     ecx
        bne     +
        dec     ecx+1
+       dec     ecx
        lda     ecx
        rts

getput
        jsr     getsrc

putdst
        pha
        lda     dst
        bne     +
        dec     dst+1
+       dec     dst
        pla
        sty     tmp
        ldy     #0
        sta     (dst), y
        ldy     tmp
        rts

getsrc
        lda     src
        bne     +
        dec     src+1
+       dec     src
        sty     tmp
        ldy     #0
        lda     (src), y
        ldy     tmp
        rts

!bin "d600-ffff.rev.pak.rev"
pakoff
