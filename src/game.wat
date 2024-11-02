(module
    (export "render" (func $render))
    (export "frame" (memory $frame_mem))
    (export "init" (func $init))
    (export "update" (func $update))
    
    (global $canvasW (mut i32) (i32.const 0))  ;; canvas width
    (global $canvasH (mut i32) (i32.const 0))  ;; canvas height
    (global $canvasHalfH (mut i32) (i32.const 0))  ;; canvas half height
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
        end)

    (func $init (param $canvasW i32) (param $canvasH i32)
        local.get $canvasW
        global.set $canvasW

        local.get $canvasH
        global.set $canvasH
        
        local.get $canvasH
        i32.const 2
        i32.div_u
        global.set $canvasHalfH)

    (func $render_pixel (param $x i32) (param $y i32) (param $r i32) (param $g i32) (param $b i32)
        (local $offset i32)
        (local $value i32)
        
        local.get $y
        global.get $canvasW
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
        i32.store (memory $frame_mem))

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
            global.get $canvasH
            i32.lt_u
            if
                ;; reset ix
                i32.const 0
                local.set $ix
                
                ;; loop by pixel in line
                loop $loop_x
                    local.get $ix
                    global.get $canvasW
                    i32.lt_u

                    if
                        local.get $ix
                        local.get $iy
                        call $render_background_pixel

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

        call $inc_frame_counter)

    (func $render_background_pixel (param $x i32) (param $y i32)
        local.get $y
        global.get $canvasHalfH
        i32.lt_u
        if
            ;; render sky
            local.get $x
            local.get $y
            i32.const 100
            i32.const 150
            i32.const 240
            call $render_pixel
        else
            ;; render floor
            local.get $x
            local.get $y
            i32.const 170
            i32.const 60
            i32.const 25
            call $render_pixel
        end)

    (func $inc_frame_counter
        i32.const 1
        global.get $frame_counter
        i32.add
        global.set $frame_counter)
)
