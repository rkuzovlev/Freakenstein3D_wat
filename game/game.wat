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
    (export "intersection_map_max_distance_in_lines" (global $intersection_map_max_distance_in_lines))

    (import "Math" "sin" (func $sin (param f32) (result f32)))
    (import "Math" "cos" (func $cos (param f32) (result f32)))
    (import "Math" "atan" (func $atan (param f32) (result f32)))
    (import "common" "log" (func $log (param f32)))
    (import "common" "log" (func $logi (param i32)))
    (import "common" "onIntersectionFound" (func $on_intersection_found (param f32) (param f32)))
    
    (global $canvas_width       (mut i32) (i32.const 0))
    (global $canvas_height      (mut i32) (i32.const 0))
    
    (global $frame_counter (mut i32) (i32.const 0))
    (global $delta_time    (mut f32) (f32.const 0))
    
    (global $player_x          (mut f32) (f32.const 5.5))
    (global $player_y          (mut f32) (f32.const 3.5))
    (global $player_move_speed f32       (f32.const 1))
    (global $player_angle_view (mut f32) (f32.const 0))
    
    (global $FOV                    f32       (f32.const 1.0))      ;; field of view between 0 and PI
    (global $FOV_angle_step         (mut f32) (f32.const 0.1))      ;; default step, need to initialize in $init function
    (global $vertical_FOV           (mut f32) (f32.const 0.75))     ;; default value, need to initialize in $init function

    (global $map_width                  i32 (i32.const 37))
    (global $map_height                 i32 (i32.const 15))
    (global $map_cell_size_in_meters    f32 (f32.const 4))
    (global $map_wall_height_in_meters  f32 (f32.const 3))
    
    (global $intersection_last_near_distance        (mut f32) (f32.const 999999))
    (global $intersection_near_x                    (mut f32) (f32.const 0))
    (global $intersection_near_y                    (mut f32) (f32.const 0))
    (global $intersection_cell_x                    (mut i32) (i32.const 0))
    (global $intersection_cell_y                    (mut i32) (i32.const 0))
    (global $intersection_is_found                  (mut i32) (i32.const 0))
    (global $intersection_map_max_distance_in_lines i32       (i32.const 8))

    (memory $frame 30)
    (memory $common 1)
    (memory $map 1)
    (;
        0 - brick wall
        1 - room wall
    ;)
    (data (memory $map) (i32.const 0)  
        "1111000000000000000000000000000000000"
        "1..10.........0.....0.....0.....0...0"
        "1...........0.0.....0.....0.....0...0"
        "1..10.......0.000.00000.00000.0000.00"
        "01110.......0.......................0"
        "00000.......0.00000.0000000000.000000"
        "0...........0.0.........0...........0"
        "0...........0.0.........0...........0"
        "000000000000000000000000000000.000000"
        "0...................................0"
        "0...................................0"
        "0...................................0"
        "0...................................0"
        "0...................................0"
        "0000000000000000000000000000000000000"
    )

    (func $move_player_by_vector (param $dx f32) (param $dy f32)
        (local $rotated_x f32)
        (local $rotated_y f32)

        ;; turn dx dy vector by angle
        ;; rotated_x = x * cos(angle) - y * sin(angle)
        f32.const 0
        global.get $player_angle_view
        f32.sub
        call $cos
        local.get $dx
        f32.mul

        f32.const 0
        global.get $player_angle_view
        f32.sub
        call $sin
        local.get $dy
        f32.mul

        f32.sub
        local.set $rotated_x

        ;; rotated_y = x * sin(angle) + y * cos(angle)
        f32.const 0
        global.get $player_angle_view
        f32.sub
        call $sin
        local.get $dx
        f32.mul

        f32.const 0
        global.get $player_angle_view
        f32.sub
        call $cos
        local.get $dy
        f32.mul

        f32.add
        local.set $rotated_y

        global.get $player_x
        local.get $rotated_x
        global.get $delta_time
        f32.mul
        global.get $player_move_speed
        f32.mul
        f32.add
        global.set $player_x
        
        global.get $player_y
        local.get $rotated_y
        global.get $delta_time
        f32.mul
        global.get $player_move_speed
        f32.mul
        f32.add
        global.set $player_y)

    (func $update (param $delta_time f32) (param $player_angle_view f32) (param $dx f32) (param $dy f32)
        local.get $delta_time
        global.set $delta_time

        local.get $player_angle_view
        global.set $player_angle_view

        local.get $dx
        local.get $dy
        call $move_player_by_vector
        
        call $inc_frame_counter)

    (func $init (param $canvas_width i32) (param $canvas_height i32)
        (local $ratio f32)

        local.get $canvas_width
        global.set $canvas_width

        local.get $canvas_height
        global.set $canvas_height
        
        global.get $FOV
        local.get $canvas_width
        f32.convert_i32_s
        f32.div
        global.set $FOV_angle_step

        ;; find canvas width/height ratio
        local.get $canvas_width
        f32.convert_i32_s
        local.get $canvas_height
        f32.convert_i32_s
        f32.div
        local.set $ratio
        
        ;; set vertical_FOV depends on canvas ratio and FOV
        global.get $FOV
        local.get $ratio
        f32.div
        global.set $vertical_FOV)

    (func $map_get_cell (param $x i32) (param $y i32) (result i32)
        ;; cell_index = y * map_width + x
        local.get $y
        global.get $map_width
        i32.mul
        local.get $x
        i32.add
        
        i32.load8_u (memory $map))

    (func $shade_color_channel (param $color_channel_value i32) (param $shading f32) (result i32)
        local.get $color_channel_value
        f32.convert_i32_s
        local.get $shading
        f32.mul
        i32.trunc_f32_s)

    (func $render_pixel (param $x i32) (param $y i32) (param $r i32) (param $g i32) (param $b i32) (param $shading f32)
        (local $offset i32)
        (local $value i32)

        ;; (y * canvas_width + x) * 4    ;; need to multiply by 4 because of 4 bytes in one pixel RGBA
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
        local.get $shading
        call $shade_color_channel
        i32.const 16
        i32.shl
        local.get $value
        i32.or
        local.set $value

        local.get $g
        local.get $shading
        call $shade_color_channel
        i32.const 8
        i32.shl 
        local.get $value
        i32.or
        local.set $value

        local.get $r
        local.get $shading
        call $shade_color_channel
        local.get $value
        i32.or
        local.set $value

        local.get $offset
        local.get $value
        i32.store (memory $frame))

    (func $get_wall_sprite_based_on_map_cell (param $x i32) (param $y i32) (result (; width ;) i32) (result (; height ;) i32) (result (; sprite pointer ;) i32) (result (; tsx ;) f32) (result (; tsy ;) f32)
        (local $cell i32)

        local.get $x
        local.get $y
        call $map_get_cell
        
        local.tee $cell
        
        i32.const 48 ;; 0
        i32.eq
        if
            call $get_sprite_brick_wall
            f32.const 0.1
            f32.const 0.1
            return
        end

        local.get $cell
        i32.const 49 ;; 1
        i32.eq
        if
            call $get_sprite_room_wall
            f32.const 1
            f32.const 1
            return
        end

        unreachable)

    (func $draw_column (param $x i32)
        (local $iy i32)
        (local $y_wall_start i32)
        (local $y_wall_end i32)
        (local $shading f32)
        (local $angular_diameter f32)
        (local $wall_percent_start f32)
        (local $wall_height i32)
        (local $s_width i32)
        (local $s_height i32)
        (local $s_pointer i32)
        (local $r i32)
        (local $g i32)
        (local $b i32)
        (local $wall_x i32)
        (local $intersection_fraction f32)
        (local $tsx f32)
        (local $tsy f32)

        ;; angle = player_angle_view + FOV / 2 - FOV_angle_step * x
        global.get $player_angle_view
        global.get $FOV
        f32.const 2
        f32.div
        f32.add
        global.get $FOV_angle_step
        local.get $x
        f32.convert_i32_s
        f32.mul
        f32.sub
        call $get_intersection_for_angle
        
        global.get $intersection_is_found
        i32.const 1
        i32.eq
        if ;; we have intersection, draw wall
            global.get $intersection_cell_x
            global.get $intersection_cell_y
            call $get_wall_sprite_based_on_map_cell
            local.set $tsy
            local.set $tsx
            local.set $s_pointer
            local.set $s_height
            local.set $s_width

            call $get_intersection_fraction
            local.set $intersection_fraction

            ;; shading = 1 - (distance / max_distance)
            f32.const 1
            global.get $intersection_last_near_distance
            global.get $intersection_map_max_distance_in_lines
            f32.convert_i32_s
            f32.div
            f32.sub
            local.set $shading

            ;; angular_diameter = 2 * atan(D/(2*L)) - D размер объекта, L расстояние до объекта

            global.get $map_wall_height_in_meters
            f32.const 2
            global.get $map_cell_size_in_meters
            f32.mul
            global.get $intersection_last_near_distance
            f32.mul
            f32.div
            call $atan
            f32.const 2
            f32.mul
            local.set $angular_diameter

            f32.const 1
            local.get $angular_diameter
            global.get $vertical_FOV
            f32.div
            f32.sub
            local.tee $wall_percent_start
            f32.const 0
            f32.lt
            if 
                f32.const 0
                local.set $wall_percent_start
            end

            global.get $canvas_height
            f32.convert_i32_s
            f32.const 2
            f32.div
            f32.floor
            local.get $wall_percent_start
            f32.mul
            i32.trunc_f32_s
            local.set $y_wall_start


            local.get $y_wall_start
            i32.const 0
            i32.lt_s
            if
                i32.const 0
                local.set $y_wall_start
            end


            global.get $canvas_height
            local.get $y_wall_start
            i32.sub
            local.set $y_wall_end

            local.get $y_wall_end
            local.get $y_wall_start
            i32.sub
            local.set $wall_height

            local.get $y_wall_start
            local.set $iy

            loop $loop_y
                local.get $iy
                local.get $y_wall_end
                i32.lt_u

                if
                    local.get $s_width
                    local.get $s_height
                    
                    ;; x [0-1)
                    local.get $intersection_fraction

                    ;; y [0-1)
                    local.get $iy
                    local.get $y_wall_start
                    i32.sub
                    f32.convert_i32_s
                    local.get $wall_height
                    f32.convert_i32_s
                    f32.div

                    local.get $tsx
                    local.get $tsy

                    i32.const 1 ;; walls palette
                    local.get $s_pointer
                    call $get_sprite_color
                    local.set $b
                    local.set $g
                    local.set $r

                    local.get $x
                    local.get $iy
                    local.get $r
                    local.get $g
                    local.get $b
                    local.get $shading
                    call $render_pixel

                    ;; iy++
                    local.get $iy
                    i32.const 1
                    i32.add
                    local.set $iy

                    br $loop_y
                end
            end
        end)

    (func $get_intersection_fraction (result f32)
        (local $r f32)

        global.get $intersection_near_x
        global.get $intersection_near_x
        f32.floor
        f32.ne
        if
            global.get $intersection_near_x
            call $fract
            local.set $r
        else
            global.get $intersection_near_y
            call $fract
            local.set $r
        end

        local.get $r)

    (func $check_intersection (param $x f32) (param $y f32) (param $vx f32) (param $vy f32)
        (local $dvx f32)
        (local $dvy f32)
        (local $distance f32)
        (local $is_not_too_far i32) ;; boolean
        (local $is_near_then_before i32) ;; boolean
        (local $is_distance_ok i32) ;; boolean
        (local $check_cell_x i32)
        (local $check_cell_y i32)
        (local $is_wall i32) ;; boolean
        (local $is_cell_x_in_range i32) ;; boolean
        (local $is_cell_y_in_range i32) ;; boolean
        (local $cell_index i32)
        (local $cell i32)
    
        ;; dvx = x - player_x
        local.get $x
        global.get $player_x
        f32.sub
        local.set $dvx

        ;; dvy = y - player_y
        local.get $y
        global.get $player_y
        f32.sub
        local.set $dvy

        ;; distance = Math.sqrt(dvx*dvx + dvy*dvy)
        local.get $dvx
        local.get $dvx
        f32.mul
        local.get $dvy
        local.get $dvy
        f32.mul
        f32.add
        f32.sqrt
        local.set $distance

        ;; is_not_too_far = distance < MAP_MAX_LINES_INTERSECT_FIND
        local.get $distance
        global.get $intersection_map_max_distance_in_lines
        f32.convert_i32_s
        f32.lt
        if
            i32.const 1
            local.set $is_not_too_far
        else
            i32.const 0
            local.set $is_not_too_far
        end

        ;; is_near_then_before = distance < intersection_last_near_distance
        local.get $distance
        global.get $intersection_last_near_distance
        f32.lt
        if
            i32.const 1
            local.set $is_near_then_before
        else
            i32.const 0
            local.set $is_near_then_before
        end

        ;; is_distance_ok = false
        i32.const 0
        local.set $is_distance_ok

        ;; is_distance_ok = is_not_too_far && is_near_then_before
        local.get $is_not_too_far
        i32.const 1
        i32.eq
        if
            local.get $is_near_then_before
            i32.const 1
            i32.eq
            if
                i32.const 1
                local.set $is_distance_ok
            end
        end

        ;; check_cell_x = Math.floor(x + vx / 2)
        local.get $x
        local.get $vx
        f32.const 2
        f32.div
        f32.add
        f32.floor
        i32.trunc_f32_s
        local.set $check_cell_x

        ;; check_cell_y = Math.floor(y + vy / 2)
        local.get $y
        local.get $vy
        f32.const 2
        f32.div
        f32.add
        f32.floor
        i32.trunc_f32_s
        local.set $check_cell_y

        ;; is_wall = false
        i32.const 0
        local.set $is_wall

        ;; is_cell_x_in_range = false
        i32.const 0
        local.set $is_cell_x_in_range

        ;; is_cell_x_in_range = check_cell_x >= 0 && check_cell_x < map_width
        local.get $check_cell_x
        i32.const 0
        i32.ge_s
        if
            local.get $check_cell_x
            global.get $map_width
            i32.lt_s
            if
                i32.const 1
                local.set $is_cell_x_in_range
            end
        end

        ;; is_cell_y_in_range = false
        i32.const 0
        local.set $is_cell_y_in_range

        ;; is_cell_y_in_range = check_cell_y >= 0 && check_cell_y < map_height
        local.get $check_cell_y
        i32.const 0
        i32.ge_s
        if
            local.get $check_cell_y
            global.get $map_height
            i32.lt_s
            if
                i32.const 1
                local.set $is_cell_y_in_range
            end
        end

        ;; if (is_cell_x_in_range && is_cell_y_in_range)
        local.get $is_cell_x_in_range
        i32.const 1
        i32.eq
        if
            local.get $is_cell_y_in_range
            i32.const 1
            i32.eq
            if
                local.get $check_cell_x
                local.get $check_cell_y
                call $map_get_cell
                
                local.tee $cell
                
                i32.const 48 ;; 0
                i32.eq
                if
                    i32.const 1
                    local.set $is_wall
                end

                local.get $cell
                i32.const 49 ;; 1
                i32.eq
                if
                    i32.const 1
                    local.set $is_wall
                end
            end
        end

        ;; if (is_distance_ok && is_wall)
        local.get $is_distance_ok
        i32.const 1
        i32.eq
        if
            local.get $is_wall
            i32.const 1
            i32.eq
            if
                local.get $distance
                global.set $intersection_last_near_distance
                
                local.get $x
                global.set $intersection_near_x
                
                local.get $y
                global.set $intersection_near_y

                local.get $check_cell_x
                global.set $intersection_cell_x
                
                local.get $check_cell_y
                global.set $intersection_cell_y

                i32.const 1
                global.set $intersection_is_found
            end
        end)

    (func $check_horizontal (param $y f32) (param $vx f32) (param $vy f32)
        (local $x f32)
        ;; need to calculate
        ;; x = ((y - player_y) * vx) / vy + player_x

        ;; y - player_y
        local.get $y
        global.get $player_y
        f32.sub
        
        ;; * vx
        local.get $vx
        f32.mul

        ;; / vy
        local.get $vy
        f32.div

        ;; + player_x
        global.get $player_x
        f32.add
        local.set $x

        local.get $x
        f32.const 8388607 ;; magic number, max value of f32, pass checking if we exceed it
        f32.lt
        if
        
            local.get $x
            f32.const 0
            f32.gt
            if
                local.get $x
                local.get $y
                f32.const 0
                local.get $vy
                call $check_intersection
            end
        end)

    (func $check_vertical (param $x f32) (param $vx f32) (param $vy f32)
        (local $y f32)
        ;; need to calculate
        ;; y = ((x - player_x) * vy) / vx + player_y

        ;; x - player_x
        local.get $x
        global.get $player_x
        f32.sub
        
        ;; * vy
        local.get $vy
        f32.mul

        ;; / vx
        local.get $vx
        f32.div

        ;; + player_y
        global.get $player_y
        f32.add
        local.set $y
        
        local.get $y
        f32.const 8388607  ;; magic number, max value of f32, pass checking if we exceed it
        f32.lt
        if
        
            local.get $y
            f32.const 0
            f32.gt
            if
                local.get $x
                local.get $y
                local.get $vx
                f32.const 0
                call $check_intersection
            end
        end)

    
    (func $get_intersection_for_angle (param $angle f32)
        (local $vx f32)
        (local $vy f32)
        (local $loop_start f32)
        (local $x f32)
        (local $y f32)

        local.get $angle
        call $sin
        local.set $vx

        local.get $angle
        call $cos
        local.set $vy

        ;; set intersection variables to defauilts
        f32.const 999999
        global.set $intersection_last_near_distance
        f32.const 0
        global.set $intersection_near_x
        f32.const 0
        global.set $intersection_near_y
        i32.const 0
        global.set $intersection_cell_x
        i32.const 0
        global.set $intersection_cell_y
        i32.const 0
        global.set $intersection_is_found

        ;; for horizontal lines, we know y (y = 1, y = 2 ...)
        local.get $vy
        f32.const 0
        f32.lt
        if 
            ;; we are looking top
            ;; loop_start = Math.floor(player_y)
            global.get $player_y
            f32.floor
            local.set $loop_start

            ;; y = loop_start
            local.get $loop_start
            local.set $y

            loop $loop
                ;; y > loop_start - intersection_map_max_distance_in_lines
                local.get $y
                local.get $loop_start
                global.get $intersection_map_max_distance_in_lines
                f32.convert_i32_s
                f32.sub
                f32.gt

                if
                    local.get $y
                    local.get $vx
                    local.get $vy
                    call $check_horizontal

                    ;; y--
                    local.get $y
                    f32.const 1
                    f32.sub
                    local.set $y

                    br $loop
                end
            end
        end
        
        local.get $vy
        f32.const 0
        f32.gt
        if 
            ;; we are looking bottom
            global.get $player_y
            f32.ceil
            local.set $loop_start

            ;; y = loop_start
            local.get $loop_start
            local.set $y

            loop $loop
                ;; y < loop_start + intersection_map_max_distance_in_lines
                local.get $y
                local.get $loop_start
                global.get $intersection_map_max_distance_in_lines
                f32.convert_i32_s
                f32.add
                f32.lt

                if
                    local.get $y
                    local.get $vx
                    local.get $vy
                    call $check_horizontal

                    ;; y++
                    local.get $y
                    f32.const 1
                    f32.add
                    local.set $y

                    br $loop
                end
            end
        end

        ;; for vertical lines, we know x (x = 1, x = 2 ...)
        local.get $vx
        f32.const 0
        f32.gt
        if 
            ;; we are looking right
            ;; loop_start = Math.ceil(player_x)
            global.get $player_x
            f32.ceil
            local.set $loop_start

            ;; x = loop_start
            local.get $loop_start
            local.set $x

            loop $loop
                ;; x < loop_start + intersection_map_max_distance_in_lines
                local.get $x
                local.get $loop_start
                global.get $intersection_map_max_distance_in_lines
                f32.convert_i32_s
                f32.add
                f32.lt

                if
                    local.get $x
                    local.get $vx
                    local.get $vy
                    call $check_vertical

                    ;; x++
                    local.get $x
                    f32.const 1
                    f32.add
                    local.set $x

                    br $loop
                end
            end
        end
        
        local.get $vx
        f32.const 0
        f32.lt
        if
            ;; we are looking left
            global.get $player_x
            f32.floor
            local.set $loop_start

            ;; x = loop_start
            local.get $loop_start
            local.set $x

            loop $loop
                ;; x > loop_start - intersection_map_max_distance_in_lines
                local.get $x
                local.get $loop_start
                global.get $intersection_map_max_distance_in_lines
                f32.convert_i32_s
                f32.sub
                f32.gt

                if
                    local.get $x
                    local.get $vx
                    local.get $vy
                    call $check_vertical

                    ;; x--
                    local.get $x
                    f32.const 1
                    f32.sub
                    local.set $x

                    br $loop
                end
            end
        end

        global.get $intersection_is_found
        i32.const 1
        i32.eq
        if
            global.get $intersection_near_x
            global.get $intersection_near_y
            call $on_intersection_found
        end)

    (func $render
        call $render_background
        call $render_columns
        ;;call $render_smile
    )

    (func $render_columns
        (local $ix i32)

        i32.const 0
        local.set $ix

        ;; loop by pixel in line
        loop $loop_x
            local.get $ix
            global.get $canvas_width
            i32.lt_u

            if
                local.get $ix
                call $draw_column

                ;; ix++
                local.get $ix
                i32.const 1
                i32.add
                local.set $ix

                br $loop_x
            end
        end)

    (func $fract (param $num f32) (result f32)
        local.get $num
        local.get $num
        f32.floor
        f32.sub)
    
    (func $round (param $num f32) (result f32)
        local.get $num
        call $fract
        f32.const 0.5
        f32.ge
        if
            local.get $num
            f32.ceil
            return
        end

        local.get $num
        f32.floor)

    (func $get_texcoord (param $max i32) (param $d f32) (param $texture_size f32) (result i32)
        (local $d_normalized f32)

        local.get $d
        local.get $texture_size
        f32.div
        call $fract
        local.tee $d_normalized
        f32.const 0
        f32.lt
        if 
            f32.const 1
            local.get $d_normalized
            f32.sub
            local.set $d_normalized
        end

        local.get $max
        i32.const 1
        i32.sub
        f32.convert_i32_s
        local.get $d_normalized
        f32.mul
        call $round
        i32.trunc_f32_s)

    (;
    ;   $sw - sprite width
    ;   $sh - sprite height
    ;   $x - sprite color position x [0; 1)
    ;   $y - sprite color position y [0; 1)
    ;   $tsx - texture size by x default 1
    ;   $tsy - texture size by y default 1
    ;   $palette - palette number
    ;   $sprite_pointer 
    ;
    ;   result r g b i32
    ;)
    (func $get_sprite_color (param $sw i32) (param $sh i32) (param $x f32) (param $y f32) (param $tsx f32) (param $tsy f32) (param $palette i32) (param $sprite_pointer i32) (result i32) (result i32) (result i32)
        (local $color_palette_index i32)
        (local $r i32)
        (local $g i32)
        (local $b i32)
        (local $tex_coord_x i32)
        (local $tex_coord_y i32)
        (local $color_index i32)

        local.get $sw
        local.get $x
        local.get $tsx
        call $get_texcoord
        local.set $tex_coord_x

        local.get $sh
        local.get $y
        local.get $tsy
        call $get_texcoord
        local.set $tex_coord_y

        local.get $tex_coord_y
        local.get $sw
        i32.mul
        local.get $tex_coord_x
        i32.add
        local.set $color_index

        local.get $sprite_pointer
        local.get $color_index
        i32.const 2
        i32.div_s
        i32.add
        i32.load8_u (memory $sprites)
        local.set $color_palette_index

        local.get $color_index
        i32.const 2
        i32.rem_s
        i32.const 0
        i32.eq
        if
            ;; is even
            local.get $color_palette_index
            i32.const 4
            i32.shr_u
            local.set $color_palette_index
        else
            ;; is odd
            local.get $color_palette_index
            i32.const 0x0f
            i32.and
            local.set $color_palette_index
        end

        local.get $color_palette_index
        i32.const 0x0f
        i32.ne
        if
            local.get $palette
            i32.const 45
            i32.mul
            local.get $color_palette_index
            i32.const 3
            i32.mul
            i32.add
            local.set $color_palette_index
            
            local.get $color_palette_index
            i32.load8_u (memory $palettes)
            local.set $r

            local.get $color_palette_index
            i32.const 1
            i32.add
            i32.load8_u (memory $palettes)
            local.set $g

            local.get $color_palette_index
            i32.const 2
            i32.add
            i32.load8_u (memory $palettes)
            local.set $b
        end
        
        local.get $r
        local.get $g
        local.get $b)

    (func $render_sprite_color (param $x i32) (param $y i32) (param $palette i32) (param $sprite_pointer i32) (param $color_index i32)
        (local $color_palette_index i32)
        (local $r i32)
        (local $g i32)
        (local $b i32)

        local.get $sprite_pointer
        local.get $color_index
        i32.const 2
        i32.div_s
        i32.add
        i32.load8_u (memory $sprites)
        local.set $color_palette_index

        local.get $color_index
        i32.const 2
        i32.rem_s
        i32.const 0
        i32.eq
        if
            ;; is even
            local.get $color_palette_index
            i32.const 4
            i32.shr_u
            local.set $color_palette_index
        else
            ;; is odd
            local.get $color_palette_index
            i32.const 0x0f
            i32.and
            local.set $color_palette_index
        end

        local.get $color_palette_index
        i32.const 0x0f
        i32.ne
        if
            local.get $palette
            i32.const 45
            i32.mul
            local.get $color_palette_index
            i32.const 3
            i32.mul
            i32.add
            local.set $color_palette_index
            
            local.get $color_palette_index
            i32.load8_u (memory $palettes)
            local.set $r

            local.get $color_palette_index
            i32.const 1
            i32.add
            i32.load8_u (memory $palettes)
            local.set $g

            local.get $color_palette_index
            i32.const 2
            i32.add
            i32.load8_u (memory $palettes)
            local.set $b

            local.get $x
            local.get $y
            local.get $r
            local.get $g
            local.get $b
            f32.const 1
            call $render_pixel
        end)

    (func $render_smile
        (local $r i32)
        (local $g i32)
        (local $b i32)
        (local $iy i32)
        (local $ix i32)
        (local $width i32)
        (local $height i32)
        (local $pointer i32)
    
        i32.const 0
        local.set $iy

        i32.const 0
        local.set $ix

        call $get_sprite_smile ;; width height pointer
        local.set $pointer
        local.set $height
        local.set $width

        loop $loop_y
            local.get $iy
            i32.const 500
            i32.lt_u
            if
                ;; reset ix
                i32.const 0
                local.set $ix

                ;; loop by pixel in line
                loop $loop_x
                    local.get $ix
                    i32.const 300
                    i32.lt_u

                    if
                        local.get $width
                        local.get $height
                        
                        ;; x [0-1)
                        local.get $ix
                        f32.convert_i32_s
                        f32.const 300
                        f32.div

                        ;; y [0-1)
                        local.get $iy
                        f32.convert_i32_s
                        f32.const 500
                        f32.div

                        f32.const 1 ;; tsx
                        f32.const 1 ;; tsy

                        i32.const 0 ;; palette
                        local.get $pointer
                        call $get_sprite_color
                        local.set $b
                        local.set $g
                        local.set $r

                        local.get $ix
                        local.get $iy
                        local.get $r
                        local.get $g
                        local.get $b
                        f32.const 1
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
        end)

    (func $render_background
        (local $ix i32)
        (local $iy i32)

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
        (local $shading f32)

        ;; abs(y / canvas_height - 0.5) * 2
        local.get $y
        f32.convert_i32_s
        global.get $canvas_height
        f32.convert_i32_s
        f32.div
        f32.const 0.5
        f32.sub
        f32.abs
        f32.const 2
        f32.mul
        local.set $shading

        ;; y < canvas_height / 2
        local.get $y
        global.get $canvas_height
        i32.const 2
        i32.div_u

        i32.lt_u
        if
            ;; render ceil
            local.get $x
            local.get $y
            i32.const 130
            i32.const 120
            i32.const 110
            local.get $shading
            call $render_pixel
        else
            ;; render floor
            local.get $x
            local.get $y
            i32.const 140
            i32.const 100
            i32.const 60
            local.get $shading
            call $render_pixel
        end)

    (func $inc_frame_counter
        i32.const 1
        global.get $frame_counter
        i32.add
        global.set $frame_counter)

    (memory $palettes 1)
    (data (memory $palettes) (i32.const 0)  
        (; default palette 0 ;) "\ff\ff\ff\d3\d3\d3\78\78\78\9f\59\2d\00\00\00\bb\0a\1e\25\5c\14\01\5d\52\9d\91\01\28\72\33\64\24\24\3e\5f\8a\ea\e6\ca\3b\d6\bf\ea\5e\e0"
        (; walls palette 1 ;) "\78\78\78\9f\59\2d\25\5c\14\cd\c7\1d\00\00\00\bb\0a\1e\25\5c\14\01\5d\52\9d\91\01\28\72\33\64\24\24\3e\5f\8a\ea\e6\ca\3b\d6\bf\ea\5e\e0"
    )

    (;SPRITES
        test.sprt
        2lines.sprt
        smile.sprt
        brick_wall.sprt
        room_wall.sprt
    ;)
)
