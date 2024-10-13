(module
    (export "render" (func $render))
    (export "frame" (memory $frame_mem))
    (export "init" (func $init))
    
    (global $cw (mut i32) (i32.const 0))  ;; canvas width
    (global $ch (mut i32) (i32.const 0))  ;; canvas height
    (global $frame_counter (mut i32) (i32.const 0))
    
    (memory $frame_mem 6)
    (memory $common 1)

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

        local.get $r
        i32.const 24
        i32.shl
        local.set $value

        local.get $g
        i32.const 16
        i32.shl
        local.get $value
        i32.or
        local.set $value

        local.get $b
        i32.const 8
        i32.shl 
        local.get $value
        i32.or
        local.set $value

        i32.const 255
        local.get $value
        i32.or
        local.set $value

        local.get $offset
        local.get $value
        i32.store (memory $frame_mem)
    )

    (func $render
        (local $r i32)
        (local $g i32)
        (local $b i32)
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
                        local.get $ix
                        i32.const 10
                        i32.div_s
                        i32.const 1
                        i32.and
                        local.set $tmp

                        local.get $iy
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

                        ;; move x depends on frame_counter x = (x + frame_counter) % cw
                        global.get $frame_counter
                        local.get $ix
                        i32.add
                        global.get $cw
                        i32.rem_u

                        local.get $iy
                        local.get $r
                        local.get $g
                        local.get $b
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

    (func $inc_frame_counter
        i32.const 1
        global.get $frame_counter
        i32.add
        global.set $frame_counter
    )
)
