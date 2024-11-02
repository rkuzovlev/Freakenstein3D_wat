(module
    (export "render" (func $render))
    (export "frame" (memory $frame_mem))
    (export "init" (func $init))
    (export "update" (func $update))
    
    (global $cw (mut i32) (i32.const 0))  ;; canvas width
    (global $ch (mut i32) (i32.const 0))  ;; canvas height
    (global $frame_counter (mut i32) (i32.const 0))
    (global $deltaTime (mut f32) (f32.const 0))
    (global $posX (mut i32) (i32.const 0))
    (global $posY (mut i32) (i32.const 0))
    
    (memory $frame_mem 6)
    (memory $common 1)

    (func $update (param $deltaTime f32) (param $w i32) (param $a i32) (param $s i32) (param $d i32)
        local.get $deltaTime
        global.set $deltaTime

        local.get $w
        i32.const 1
        i32.eq
        if
            global.get $posY
            i32.const 1
            i32.sub
            global.set $posY
        end

        local.get $s
        i32.const 1
        i32.eq
        if
            global.get $posY
            i32.const 1
            i32.add
            global.set $posY
        end

        local.get $d
        i32.const 1
        i32.eq
        if
            global.get $posX
            i32.const 1
            i32.add
            global.set $posX
        end

        local.get $a
        i32.const 1
        i32.eq
        if
            global.get $posX
            i32.const 1
            i32.sub
            global.set $posX
        end
    )

    (func $init (param $cw i32) (param $ch i32)
        local.get $cw
        global.set $cw
        local.get $ch
        global.set $ch
    )

    (func $render_pixel (param $x i32) (param $y i32) (param $r i32) (param $g i32) (param $b i32)
        (local $offset i32)
        (local $value i32)
        
        local.get $y
        global.get $cw
        i32.mul
        local.get $x
        i32.add
        i32.const 4
        i32.mul
        local.set $offset

        ;; should pass colors in reverse order because of little endian
        i32.const 255
        i32.const 24
        i32.shl
        local.set $value

        local.get $b
        i32.const 16
        i32.shl
        local.get $value
        i32.or
        local.set $value

        local.get $g
        i32.const 8
        i32.shl 
        local.get $value
        i32.or
        local.set $value

        local.get $r
        local.get $value
        i32.or
        local.set $value

        local.get $offset
        local.get $value
        i32.store (memory $frame_mem)
    )

    (func $get_pixel_color (param $x i32) (param $y i32) (result (;r;) i32) (result (;g;) i32) (result (;b;) i32)
        (local $r i32)
        (local $g i32)
        (local $b i32)
        (local $tmp i32)
        
        local.get $x
        i32.const 10
        i32.div_s
        i32.const 1
        i32.and
        local.set $tmp

        local.get $y
        i32.const 10
        i32.div_s
        i32.const 1
        i32.and
        local.get $tmp
        i32.xor

        if
            i32.const 255
            local.set $r
            i32.const 0
            local.set $g
            i32.const 0
            local.set $b
        else
            i32.const 255
            local.set $r
            i32.const 255
            local.set $g
            i32.const 255
            local.set $b
        end

        local.get $r
        local.get $g
        local.get $b
    )

    (func $render
        (local $ix i32)
        (local $iy i32)
        (local $tmp i32)

        i32.const 0
        local.set $ix

        i32.const 0
        local.set $iy

        ;; loop by screen lines
        loop $loop_y
            local.get $iy
            global.get $ch
            i32.lt_u
            if
                ;; reset ix
                i32.const 0
                local.set $ix
                
                ;; loop by pixel in line
                loop $loop_x
                    local.get $ix
                    global.get $cw
                    i32.lt_u

                    if
                        ;; move ix by posX
                        local.get $ix
                        global.get $posX
                        global.get $cw
                        call $move_pattern_by_offset

                        ;; move iy by posY
                        local.get $iy
                        global.get $posY
                        global.get $ch
                        call $move_pattern_by_offset

                        local.get $ix
                        local.get $iy
                        call $get_pixel_color

                        call $render_pixel

                        ;; ix++
                        local.get $ix
                        i32.const 1
                        i32.add
                        local.set $ix

                        br $loop_x
                    end
                end

                ;; iy++
                local.get $iy
                i32.const 1
                i32.add
                local.set $iy

                br $loop_y
            end
        end

        call $inc_frame_counter
    )

    (func $move_pattern_by_offset (param $i i32) (param $di i32) (param $max i32) (result i32)
        (local $tmp i32)
        ;; move i by di
        local.get $i
        local.get $di
        i32.add
        local.get $max
        i32.rem_s
        ;; have to change negative x offset to positive by max - i
        local.set $tmp
        local.get $tmp
        i32.const 0
        i32.lt_s
        if
            local.get $max
            local.get $tmp
            i32.add
            local.set $tmp
        end
        local.get $tmp
    )

    (func $inc_frame_counter
        i32.const 1
        global.get $frame_counter
        i32.add
        global.set $frame_counter
    )
)
