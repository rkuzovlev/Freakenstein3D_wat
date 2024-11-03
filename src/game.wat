(module
    (export "render" (func $render))
    (export "init" (func $init))
    (export "update" (func $update))
    
    (export "frame" (memory $frame))
    (export "map" (memory $map))
    
    (export "player_x" (global $player_x))
    (export "player_y" (global $player_y))
    (export "map_width" (global $map_width))
    (export "map_height" (global $map_height))
    (export "FOV" (global $FOV))

    (import "Math" "sin" (func $sin (param f32) (result f32)))
    (import "common" "log" (func $log (param f32)))
    
    (global $canvas_width (mut i32) (i32.const 0))
    (global $canvas_height (mut i32) (i32.const 0))
    (global $canvas_half_height (mut i32) (i32.const 0))
    (global $frame_counter (mut i32) (i32.const 0))
    (global $delta_time (mut f32) (f32.const 0))
    (global $player_x (mut f32) (f32.const 3.5))
    (global $player_y (mut f32) (f32.const 3.5))
    (global $FOV (mut f32) (f32.const 1.0471975512))  ;; field of view between 0 and PI
    (global $half_FOV (mut f32) (f32.const 0.5235987756))
    (global $map_width (mut i32) (i32.const 5))
    (global $map_height (mut i32) (i32.const 5))
    
    (memory $frame 6)
    (memory $common 1)
    (memory $map 1)
    (data (memory $map) (i32.const 0)  
        "#####"
        "#...#"
        "#.#.#"
        "#...#"
        "#####"
    )

    (func $update (param $delta_time f32) (param $w i32) (param $a i32) (param $s i32) (param $d i32)
        local.get $delta_time
        global.set $delta_time

        local.get $w
        i32.const 1
        i32.eq
        if
            global.get $player_y
            local.get $delta_time
            f32.sub
            global.set $player_y
        end

        local.get $s
        i32.const 1
        i32.eq
        if
            global.get $player_y
            local.get $delta_time
            f32.add
            global.set $player_y
        end

        local.get $d
        i32.const 1
        i32.eq
        if
            global.get $player_x
            local.get $delta_time
            f32.add
            global.set $player_x
        end

        local.get $a
        i32.const 1
        i32.eq
        if
            global.get $player_x
            local.get $delta_time
            f32.sub
            global.set $player_x
        end
        
        call $inc_frame_counter)

    (func $init (param $canvas_width i32) (param $canvas_height i32)
        local.get $canvas_width
        global.set $canvas_width

        local.get $canvas_height
        global.set $canvas_height
        
        local.get $canvas_height
        i32.const 2
        i32.div_u
        global.set $canvas_half_height)

    (func $render_pixel (param $x i32) (param $y i32) (param $r i32) (param $g i32) (param $b i32)
        (local $offset i32)
        (local $value i32)
        
        local.get $y
        global.get $canvas_width
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
        i32.store (memory $frame))

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
            global.get $canvas_height
            i32.lt_u
            if
                ;; reset ix
                i32.const 0
                local.set $ix
                
                ;; loop by pixel in line
                loop $loop_x
                    local.get $ix
                    global.get $canvas_width
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
        end)

    (func $render_old
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
            global.get $canvas_height
            i32.lt_u
            if
                ;; reset ix
                i32.const 0
                local.set $ix
                
                ;; loop by pixel in line
                loop $loop_x
                    local.get $ix
                    global.get $canvas_width
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
        end)

    (func $render_background_pixel (param $x i32) (param $y i32)
        local.get $y
        global.get $canvas_half_height
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
