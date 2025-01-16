(module
    (export "render" (func $render))
    (export "init" (func $init))
    (export "update" (func $update))
    
    (export "frame" (memory $frame))
    (export "map" (memory $map))
    (export "objects_intersected" (memory $objects_intersected))
    (export "objects" (memory $objects))
    
    (export "player_x" (global $player_x))
    (export "player_y" (global $player_y))
    (export "map_width" (global $map_width))
    (export "map_height" (global $map_height))
    (export "FOV" (global $FOV))
    (export "intersection_map_max_distance_in_lines" (global $intersection_map_max_distance_in_lines))

    (import "Math" "sin" (func $sin (param f32) (result f32)))
    (import "Math" "cos" (func $cos (param f32) (result f32)))
    (import "Math" "atan" (func $atan (param f32) (result f32)))
    (import "Math" "acos" (func $acos (param f32) (result f32)))
    (import "Math" "tan" (func $tan (param f32) (result f32)))
    (import "Math" "PI" (global $PI f32))
    (import "common" "log" (func $log (param f32)))
    (import "common" "log" (func $logi (param i32)))
    (import "common" "onIntersectionFound" (func $on_intersection_found (param f32) (param f32)))
    
    (global $canvas_width       (mut i32) (i32.const 0))
    (global $canvas_height      (mut i32) (i32.const 0))
    
    (global $frame_counter (mut i32) (i32.const 0))
    (global $delta_time    (mut f32) (f32.const 0))
    
    (global $player_x                           (mut f32) (f32.const 10.5))
    (global $player_y                           (mut f32) (f32.const 2.5))
    (global $player_move_speed                  f32       (f32.const 1.5))
    (global $player_angle_view                  (mut f32) (f32.const 0))
    (global $player_check_collision_distance    f32       (f32.const 0.35))
    
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
    
    (global $have_keys i32 (i32.const 0xf)) ;; 0b0001 - green key; 0b0010 - blue key; 0b0100 - red key; 0b1000 - yellow key
    
    (global $objects_intersected_count (mut i32) (i32.const 0)) 
    ;; intersection_object = { type: i32, distance_to_player: f32, intersection_fraction: f32 }
    (memory $objects_intersected 1) ;; [ intersection_object ]
    
    (global $objects_count (mut i32) (i32.const 0)) 
    ;; object = { type: i32, x: f32, y: f32 }
    ;; objects = [ object ]
    (memory $objects 1)

    (memory $frame 30)
    (memory $map 1)
    (;
        0 (48)  - brick wall
        1 (49)  - room wall
        G (71)  - green door
        B (82)  - blue door
        R (66)  - red door
        Y (89)  - yellow door
        g (103) - green key
        b (114) - blue key
        r (98)  - red key
        y (121) - yellow key
    ;)
    (data (memory $map) (i32.const 0)  
        "1111000000000000000000000000000000000"
        "1..10......g..0.....0.....0.....0...0"
        "1.............0.....0.....0.....0...0"
        "1..10......r..000.00000.00000.0000.00"
        "01110...............................0"
        "00000......b..00000.0000000000.000000"
        "0.............0.........0...........0"
        "0..........y..0.........0...........0"
        "000.0G0B0R0Y0.0000000000000000.000000"
        "0...................................0"
        "0...................................0"
        "0...................................0"
        "0...................................0"
        "0...................................0"
        "0000000000000000000000000000000000000"
    )

    (func $is_wall_by_x_y (param $x i32) (param $y i32) (result i32)
        (local $cell i32)

        local.get $x
        i32.const 0
        i32.lt_s
        if
            i32.const 0
            return
        end
        
        local.get $y
        i32.const 0
        i32.lt_s
        if
            i32.const 0
            return
        end

        local.get $x
        local.get $y
        call $map_get_cell
        
        local.tee $cell
        
        i32.const 48 ;; "0"
        i32.eq
        if
            i32.const 1
            return
        end

        local.get $cell
        i32.const 49 ;; "1"
        i32.eq
        if
            i32.const 1
            return
        end

        local.get $cell
        i32.const 71 ;; "G"
        i32.eq
        if
            i32.const 1
            return
        end

        local.get $cell
        i32.const 82 ;; "R"
        i32.eq
        if
            i32.const 1
            return
        end

        local.get $cell
        i32.const 66 ;; "B"
        i32.eq
        if
            i32.const 1
            return
        end

        local.get $cell
        i32.const 89 ;; "Y"
        i32.eq
        if
            i32.const 1
            return
        end

        i32.const 0)

    (func $vector_normalize (param $x f32) (param $y f32) (result f32) (result f32)
        (local $length f32)
        (local $nx f32)
        (local $ny f32)

        local.get $x
        local.set $nx

        local.get $y
        local.set $ny

        local.get $x
        local.get $y
        call $vector_distance
        local.tee $length
        f32.const 0
        f32.ne
        if
            ;; vector normalization
            local.get $x
            local.get $length
            f32.div
            local.set $nx

            local.get $y
            local.get $length
            f32.div
            local.set $ny
        end
        
        local.get $x
        local.get $y)

    ;; distance = sqrt(x * x + y * y)
    (func $vector_distance (param $x f32) (param $y f32) (result f32)
        local.get $x
        local.get $x
        f32.mul
        local.get $y
        local.get $y
        f32.mul
        f32.add
        f32.sqrt)

    (func $line_segment_distance (param $from_x f32) (param $from_y f32) (param $to_x f32) (param $to_y f32) (result f32)
        (local $x f32)
        (local $y f32)

        local.get $to_x
        local.get $from_x
        f32.sub
        local.set $x

        local.get $to_y
        local.get $from_y
        f32.sub
        local.set $y

        local.get $x
        local.get $y
        call $vector_distance)

    (func $is_player_collide_with_wall (param $wall_intersect_x f32) (param $wall_intersect_y f32) (result i32)
        local.get $wall_intersect_x
        i32.trunc_f32_s
        local.get $wall_intersect_y
        i32.trunc_f32_s
        call $is_wall_by_x_y
        i32.const 0
        i32.eq
        if
            i32.const 0
            return
        end

        global.get $player_x
        global.get $player_y
        local.get $wall_intersect_x
        local.get $wall_intersect_y
        call $line_segment_distance
        global.get $player_check_collision_distance
        f32.gt
        if
            i32.const 0
            return
        end

        i32.const 1)

    ;; check intersection with closest walls by move vector
    (func $check_player_wall_collisions (param $move_x f32) (param $move_y f32) (result f32) (result f32)
        (local $x f32)
        (local $y f32)
        (local $new_move_x f32)
        (local $new_move_y f32)

        local.get $move_x
        local.set $new_move_x

        local.get $move_y
        local.set $new_move_y

        local.get $move_x
        f32.const 0
        f32.gt
        if  ;; we moving right
            global.get $player_x
            f32.ceil
            global.get $player_y
            call $is_player_collide_with_wall
            i32.const 1
            i32.eq
            if
                f32.const 0
                local.set $new_move_x
            end
        end

        local.get $move_x
        f32.const 0
        f32.lt
        if  ;; we moving left
            global.get $player_x
            f32.floor
            f32.const 0.000001
            f32.sub
            global.get $player_y
            call $is_player_collide_with_wall
            i32.const 1
            i32.eq
            if
                f32.const 0
                local.set $new_move_x
            end
        end

        local.get $move_y
        f32.const 0
        f32.gt
        if  ;; we moving bottom
            global.get $player_x
            global.get $player_y
            f32.ceil
            call $is_player_collide_with_wall
            i32.const 1
            i32.eq
            if
                f32.const 0
                local.set $new_move_y
            end
        end

        local.get $move_y
        f32.const 0
        f32.lt
        if  ;; we moving top
            global.get $player_x
            global.get $player_y
            f32.floor
            f32.const 0.000001
            f32.sub
            call $is_player_collide_with_wall
            i32.const 1
            i32.eq
            if
                f32.const 0
                local.set $new_move_y
            end
        end
        
        local.get $new_move_x
        local.get $new_move_y)

    (func $move_player_by_delta_xy (param $dx f32) (param $dy f32)
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

        local.get $rotated_x
        local.get $rotated_y
        call $vector_normalize
        local.set $rotated_y
        local.set $rotated_x

        local.get $rotated_x
        local.get $rotated_y
        call $check_player_wall_collisions
        local.set $rotated_y
        local.set $rotated_x

        local.get $rotated_x
        global.get $delta_time
        f32.mul
        global.get $player_move_speed
        f32.mul
        global.get $player_x
        f32.add
        global.set $player_x
        
        local.get $rotated_y
        global.get $delta_time
        f32.mul
        global.get $player_move_speed
        f32.mul
        global.get $player_y
        f32.add
        global.set $player_y)

    (func $update (param $delta_time f32) (param $player_angle_view f32) (param $dx f32) (param $dy f32)
        local.get $delta_time
        global.set $delta_time

        local.get $player_angle_view
        global.set $player_angle_view

        local.get $dx
        local.get $dy
        call $move_player_by_delta_xy
        
        call $inc_frame_counter)
    
    (func $get_object_by_index (param $index i32) (result i32) (result f32) (result f32)
        (local $position i32)
        (local $type i32)
        (local $x f32)
        (local $y f32)

        local.get $index
        i32.const 12 ;; object size in bytes
        i32.mul
        local.set $position

        ;; load type
        local.get $position
        i32.load (memory $objects)
        local.set $type

        local.get $position
        i32.const 4
        i32.add
        local.set $position

        ;; load x
        local.get $position
        f32.load (memory $objects)
        local.set $x

        local.get $position
        i32.const 4
        i32.add
        local.set $position

        ;; load y
        local.get $position
        f32.load (memory $objects)
        local.set $y
        
        local.get $type
        local.get $x
        local.get $y)

    (func $init_object (param $x i32) (param $y i32) (param $object i32)
        (local $position i32)

        global.get $objects_count
        i32.const 12 ;; object size in bytes
        i32.mul
        local.set $position

        ;; store object type
        local.get $position
        local.get $object
        i32.store (memory $objects)
        
        local.get $position
        i32.const 4
        i32.add
        local.set $position

        ;; store x + 0.5
        local.get $position
        local.get $x
        f32.convert_i32_s
        f32.const 0.5
        f32.add
        f32.store (memory $objects)

        local.get $position
        i32.const 4
        i32.add
        local.set $position

        ;; store y + 0.5
        local.get $position
        local.get $y
        f32.convert_i32_s
        f32.const 0.5
        f32.add
        f32.store (memory $objects)
        
        global.get $objects_count
        i32.const 1
        i32.add
        global.set $objects_count
        
        ;; clear map cell, set floor tile "."
        local.get $x
        local.get $y
        i32.const 46 ;; .
        call $map_set_cell)

    (func $init_cell_object (param $x i32) (param $y i32) (param $cell_object i32)
        local.get $cell_object
        i32.const 103 ;; "g"
        i32.eq
        if
            local.get $x
            local.get $y
            i32.const 103
            call $init_object
            return
        end

        local.get $cell_object
        i32.const 114 ;; "r"
        i32.eq
        if
            local.get $x
            local.get $y
            i32.const 114
            call $init_object
            return
        end

        local.get $cell_object
        i32.const 98 ;; "b"
        i32.eq
        if
            local.get $x
            local.get $y
            i32.const 98
            call $init_object
            return
        end

        local.get $cell_object
        i32.const 121 ;; "y"
        i32.eq
        if
            local.get $x
            local.get $y
            i32.const 121
            call $init_object
            return
        end)

    (func $init_objects
        (local $ix i32)
        (local $iy i32)
        (local $cell i32)

        i32.const 0
        local.set $ix

        i32.const 0
        local.set $iy

        loop $loop_y
            local.get $iy
            global.get $map_height
            i32.lt_u
            if
                ;; reset ix
                i32.const 0
                local.set $ix
                
                loop $loop_x
                    local.get $ix
                    global.get $map_width
                    i32.lt_u

                    if
                        local.get $ix
                        local.get $iy
                        call $map_get_cell
                        local.set $cell

                        local.get $ix
                        local.get $iy
                        local.get $cell
                        call $init_cell_object

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
        global.set $vertical_FOV
        
        call $init_objects)

    (func $map_set_cell (param $x i32) (param $y i32) (param $cell i32)
        ;; cell_index = y * map_width + x
        local.get $y
        global.get $map_width
        i32.mul
        local.get $x
        i32.add
        
        local.get $cell

        i32.store8 (memory $map))

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

    (func $get_wall_sprite_based_on_map_cell (param $x i32) (param $y i32) (result (; width ;) i32) (result (; height ;) i32) (result (; sprite pointer ;) i32) (result (; palette ;) i32) (result (; tsx ;) f32) (result (; tsy ;) f32)
        (local $cell i32)

        local.get $x
        local.get $y
        call $map_get_cell
        
        local.tee $cell
        
        i32.const 48 ;; "0"
        i32.eq
        if
            call $get_sprite_brick_wall
            i32.const 1
            f32.const 0.1
            f32.const 0.1
            return
        end

        local.get $cell
        i32.const 49 ;; "1"
        i32.eq
        if
            call $get_sprite_room_wall
            i32.const 1
            f32.const 1
            f32.const 1
            return
        end

        local.get $cell
        i32.const 71 ;; "G"
        i32.eq
        if
            call $get_sprite_door
            i32.const 2
            f32.const 1
            f32.const 1
            return
        end

        local.get $cell
        i32.const 66 ;; "B"
        i32.eq
        if
            call $get_sprite_door
            i32.const 3
            f32.const 1
            f32.const 1
            return
        end

        local.get $cell
        i32.const 82 ;; "R"
        i32.eq
        if
            call $get_sprite_door
            i32.const 4
            f32.const 1
            f32.const 1
            return
        end

        local.get $cell
        i32.const 89 ;; "Y"
        i32.eq
        if
            call $get_sprite_door
            i32.const 5
            f32.const 1
            f32.const 1
            return
        end

        unreachable)

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

        f32.const 1
        local.get $r
        f32.sub)

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

                local.get $cell
                i32.const 71 ;; "G"
                i32.eq
                if
                    i32.const 1
                    local.set $is_wall
                end

                local.get $cell
                i32.const 82 ;; "R"
                i32.eq
                if
                    i32.const 1
                    local.set $is_wall
                end

                local.get $cell
                i32.const 66 ;; "B"
                i32.eq
                if
                    i32.const 1
                    local.set $is_wall
                end

                local.get $cell
                i32.const 89 ;; "Y"
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

    (func $calculate_intersection_with_horizontal_line (param $y f32) (param $vx f32) (param $vy f32) (result f32)
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
        f32.add)

    (func $check_horizontal (param $y f32) (param $vx f32) (param $vy f32)
        (local $x f32)
        
        local.get $y
        local.get $vx
        local.get $vy
        call $calculate_intersection_with_horizontal_line
        local.set $x

        local.get $x
        f32.const 9999999 ;; magic number, pass checking if we exceed it
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

    (func $calculate_intersection_with_vertical_line (param $x f32) (param $vx f32) (param $vy f32) (result f32)
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
        f32.add)

    (func $check_vertical (param $x f32) (param $vx f32) (param $vy f32)
        (local $y f32)
        
        local.get $x
        local.get $vx
        local.get $vy
        call $calculate_intersection_with_vertical_line
        local.set $y
        
        local.get $y
        f32.const 9999999  ;; magic number, pass checking if we exceed it
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

    (func $get_object_sprite_by_type (param $type i32) (result (; width ;) i32) (result (; height ;) i32) (result (; sprite pointer ;) i32) (result (; palette ;) i32)
        local.get $type
        i32.const 103 ;; "g"
        i32.eq
        if
            call $get_sprite_key
            i32.const 2
            return
        end

        local.get $type
        i32.const 114 ;; "b"
        i32.eq
        if
            call $get_sprite_key
            i32.const 3
            return
        end

        local.get $type
        i32.const 98 ;; "r"
        i32.eq
        if
            call $get_sprite_key
            i32.const 4
            return
        end

        local.get $type
        i32.const 121 ;; "y"
        i32.eq
        if
            call $get_sprite_key
            i32.const 5
            return
        end

        unreachable)

    (func $get_objects_intersected_by_index (param $index i32) (result (; type ;) i32) (result (; distance ;) f32) (result (; fraction ;) f32)
        (local $position i32)
        (local $type i32)
        (local $distance f32)
        (local $fraction f32)

        local.get $index
        i32.const 12 ;; object size in bytes
        i32.mul
        local.set $position

        ;; load type
        local.get $position
        i32.load (memory $objects_intersected)
        local.set $type

        local.get $position
        i32.const 4
        i32.add
        local.set $position

        ;; load distance
        local.get $position
        f32.load (memory $objects_intersected)
        local.set $distance

        local.get $position
        i32.const 4
        i32.add
        local.set $position

        ;; load distance
        local.get $position
        f32.load (memory $objects_intersected)
        local.set $fraction

        local.get $type
        local.get $distance
        local.get $fraction)

    (func $set_objects_intersected_by_index (param $index i32) (param $type i32) (param $distance f32) (param $fraction f32)
        (local $position i32)

        local.get $index
        i32.const 12 ;; object size in bytes
        i32.mul
        local.set $position

        ;; set type
        local.get $position
        local.get $type
        i32.store (memory $objects_intersected)

        local.get $position
        i32.const 4
        i32.add
        local.set $position

        ;; set distance
        local.get $position
        local.get $distance
        f32.store (memory $objects_intersected)
        
        local.get $position
        i32.const 4
        i32.add
        local.set $position

        ;; set fraction
        local.get $position
        local.get $fraction
        f32.store (memory $objects_intersected))

    (func $find_index_for_object_intersection_distance (param $distance f32) (result i32)
        (local $found_index i32)
        (local $i i32)
        (local $i_type i32)
        (local $i_distance f32)
        (local $i_fraction f32)

        i32.const 0
        local.set $i

        loop $loop
            local.get $i
            global.get $objects_intersected_count
            i32.ge_s
            if
                local.get $i
                return
            end

            local.get $i
            call $get_objects_intersected_by_index
            local.set $i_fraction
            local.set $i_distance
            local.set $i_type

            local.get $distance
            local.get $i_distance
            f32.lt
            if
                local.get $i
                return
            end

            ;; i++
            local.get $i
            i32.const 1
            i32.add
            local.set $i

            br $loop
        end

        unreachable)


    (func $move_object_intersection_items_downto_until_index (param $move_index i32)
        (local $i i32)
        (local $type i32)
        (local $distance f32)
        (local $fraction f32)

        global.get $objects_intersected_count
        local.set $i

        loop $loop
            local.get $i
            i32.const 0
            i32.lt_s
            if
                return
            end

            local.get $i
            local.get $move_index
            i32.lt_s
            if
                return
            end

            local.get $i
            call $get_objects_intersected_by_index
            local.set $fraction
            local.set $distance
            local.set $type

            local.get $i
            i32.const 1
            i32.add
            local.get $type
            local.get $distance
            local.get $fraction
            call $set_objects_intersected_by_index

            ;; i++
            local.get $i
            i32.const 1
            i32.sub
            local.set $i

            br $loop
        end

        unreachable)

    ;; вставим объект с типом type и дистанцией distance в массив objects_intersected
    ;; при вставке сразу сортируем от самой ближней к дальней
    (func $insert_to_objects_intersected (param $type i32) (param $distance f32) (param $fraction f32)
        (local $found_index i32)

        local.get $distance
        call $find_index_for_object_intersection_distance
        local.set $found_index

        local.get $found_index
        call $move_object_intersection_items_downto_until_index

        local.get $found_index
        local.get $type
        local.get $distance
        local.get $fraction
        call $set_objects_intersected_by_index

        global.get $objects_intersected_count
        i32.const 1
        i32.add
        global.set $objects_intersected_count)

    (func $get_intersection_with_object_for_angle (param $object_index i32) (param $angle f32)
        (local $type i32)
        (local $ox f32)
        (local $oy f32)
        (local $s_width i32)
        (local $s_height i32)
        (local $s_pointer i32)
        (local $s_patelle i32)
        ;; intersection local variables
        (local $iy f32)
        (local $ix f32)
        (local $yleft f32)
        (local $yright f32)
        (local $ctga f32)
        (local $tga f32)
        (local $intersection_distance_to_object f32)
        (local $intersection_distance_to_player f32)
        (local $intersection_fraction f32)
        (local $object_angle f32)
        (local $object_angle_tmp f32)
        (local $angle_tmp f32)
        (local $x f32)
        (local $y f32)
        (local $tmp f32)

        local.get $object_index
        call $get_object_by_index
        local.set $oy
        local.set $ox
        local.set $type

        local.get $type
        call $get_object_sprite_by_type
        local.set $s_patelle
        local.set $s_pointer
        local.set $s_height
        local.set $s_width


        (;
        нужно найти пересечение прямой проходящей через позицию объекта в заданой точке (ox, oy) и перпендикулярно углу обзора персонажа (a)
        и прямой проходяшей через позицию позицию игрока (px, py) и параллельно углу обзора персонажа (a)
        
        общее уравнение прямой проходящей через точку (tx, ty) и с углом поворота (a) в радианах
        y = tan(a) * (x - tx) + ty

        так как у нас система координат перевернутая, где (y) указывает вниз, при этом 0 угла поворота это не в направлении оси (x),
        а в направлении оси (y), то формулу надо переделать на
        y = (tan(a) * ty - tx + x) / tan(a)
        
        уравнение объекта и уравнение от обзора игрока одинаковы, разница только в том, что разные точки и разный угол
        угол у объекта будет равен углу обзора персонажа плюс PI/2

        таким образом уравнение объекта, где (ox, oy) позиция объекта и (a) угол обзора игрока
        y = (tan(a + pi/2) * oy - ox + x) / tan(a + pi/2)

        и уравнение прямой от игрока в сторону обзора, где (px, py) позиция игрока и (a) угол обзора игрока
        y = (tan(a) * py - px + x) / tan(a)

        надо найти пересечние, решаем систему уравнений
        _
        | y = (tan(a) * py - px + x) / tan(a)
        | y = (tan(a + pi/2) * oy - ox + x) / tan(a + pi/2)
        -

        выразим x из первого уравнения
        x = (y - (tan(a) * ty - tx) / tan(a)) * tan(a)
        
        подставим во второе уравнение
        y = (tan(a + pi/2) * oy - ox + ((y - (tan(a) * ty - tx) / tan(a)) * tan(a))) / tan(a + pi/2)

        oy = q
        ox = w
        ty = e
        tx = r
        y = (tan(a + pi/2) * q - w + ((y - (tan(a) * e - r) / tan(a)) * tan(a))) / tan(a + pi/2)

        надо выразить y, решил при помощи https://mathdf.com/equ/ru/

        y = (ty * tan(a) + oy * ctg(a) + ox - tx) / (tan(a) + ctg(a))

        найденный y подставляем в
        x = (y - (tan(a) * py - px) / tan(a)) * tan(a)

        получим (x, y) координаты пересечения прямой через позицию игрока и углом наклона (a)
        и прямой через позицию объекта и углом наклона (a + PI / 2) тоесть перпендикулярно углу (a)
        ;) 



        (;
        iy = (py * tan(a) + oy * ctg(a) + ox - px) / (tan(a) + ctg(a))

        ctga = ctg(a)
        tga = tan(a)
        yleft = py * tan(a) + oy * ctg(a) + ox - px
        yright = tan(a) + ctg(a)

        iy = yleft / yright
        ;)
        local.get $angle
        call $ctg
        local.set $ctga

        local.get $angle
        call $tan
        local.set $tga

        ;; yleft = py * tan(a) + oy * ctg(a) + ox - px
        ;; py * tan(a)
        global.get $player_y
        local.get $tga
        f32.mul

        ;; + oy * ctg(a)
        local.get $oy
        local.get $ctga
        f32.mul
        f32.add

        ;; + ox
        local.get $ox
        f32.add

        ;; - px
        global.get $player_x
        f32.sub
        local.set $yleft

        ;; yright = tan(a) + ctg(a)
        local.get $tga
        local.get $ctga
        f32.add
        local.set $yright

        ;; iy = yleft / yright
        local.get $yleft
        local.get $yright
        f32.div
        local.set $iy


        ;; ix = (y - (tan(a) * py - px) / tan(a)) * tan(a)
        local.get $iy
        local.get $tga
        global.get $player_y
        f32.mul
        global.get $player_x
        f32.sub
        local.get $tga
        f32.div
        f32.sub
        local.get $tga
        f32.mul
        local.set $ix


        ;; надо проверить дистанцию между пересечением и позицией объекта
        local.get $ix
        local.get $iy
        local.get $ox
        local.get $oy
        call $line_segment_distance
        local.set $intersection_distance_to_object

        ;; если дистанция от пересечения и до объекта меньше меньше заданого значения, то произошло пересечение 
        ;; мы же проверяет наоборот что дистанция больше, и если она больше, то просто выйдем из функции
        local.get $intersection_distance_to_object
        f32.const 0.14 ;; магическое число, 0.14 от ширины тайла
        f32.gt
        if
            return
        end

        ;; надо проверить дистанцию между пересечением и позицией персонажа
        local.get $ix
        local.get $iy
        global.get $player_x
        global.get $player_y
        call $line_segment_distance
        local.set $intersection_distance_to_player

        ;; если подошли слишком близко, то и не надо рендерить объект
        local.get $intersection_distance_to_player
        f32.const 0.3
        f32.lt
        if
            return
        end

        ;; если слишком далеко, то не надо рендерить объект
        local.get $intersection_distance_to_player
        global.get $intersection_map_max_distance_in_lines
        f32.convert_i32_s
        f32.gt
        if
            return
        end

        ;; если есть пересечение со стеной
        global.get $intersection_is_found
        i32.const 1
        i32.eq
        if
            ;; если объект за стеной, то не рендерим
            local.get $intersection_distance_to_player
            global.get $intersection_last_near_distance
            f32.gt
            if
                return
            end
        end

        ;; найдем вектор в направлении от игрока в объект
        local.get $ox
        global.get $player_x
        f32.sub
        local.set $x

        local.get $oy
        global.get $player_y
        f32.sub
        local.set $y

        ;; найдем угол от этого вектора к положительной оси y
        local.get $y
        
        local.get $x
        local.get $x
        f32.mul
        local.get $y
        local.get $y
        f32.mul
        f32.add
        f32.sqrt

        f32.div
        call $acos
        local.set $object_angle

        local.get $x
        f32.const 0
        f32.lt
        if
            global.get $PI
            global.get $PI
            f32.add
            local.get $object_angle
            f32.sub
            local.set $object_angle
        end


        ;; при проверке пересечения с объектом, мы проверяем линией а не лучом
        ;; это значит что пересечение будет в том числе, если стоим спиной к объекту
        ;; не будем рендерить если пересечение позади
        local.get $angle
        local.get $object_angle
        f32.sub
        f32.abs
        local.tee $tmp
        global.get $PI
        f32.const 0.8
        f32.mul
        f32.gt
        if
            local.get $tmp
            global.get $PI
            f32.const 1.2
            f32.mul
            f32.lt
            if
                return
            end
        end


        ;; в ситуации перехода через 0 получается что вектор обзора может быть ближе к 2PI а вектор к объекту ближе к 0
        ;; и мы не сможем правильно расчитать intersection_fraction
        ;; для этого проверяем разницу между angle и object_angle, и если она больше PI то надо преобразовать
        local.get $angle
        local.get $object_angle
        f32.sub
        f32.abs
        global.get $PI
        f32.gt
        if
            local.get $angle
            global.get $PI
            f32.gt
            if
                local.get $angle
                global.get $PI
                f32.const 2
                f32.mul
                f32.sub
                local.set $angle_tmp
                local.get $object_angle
                local.set $object_angle_tmp
            else
                local.get $angle
                local.set $angle_tmp
                local.get $object_angle
                global.get $PI
                f32.const 2
                f32.mul
                f32.sub
                local.set $object_angle_tmp
            end
        else
            local.get $angle
            local.set $angle_tmp
            local.get $object_angle
            local.set $object_angle_tmp
        end

        ;; в зависимости от того, что больше, угол куда мы сейчас кастуем или угол на котором распаложен объект
        ;; будет высчитываться intersection_fraction
        local.get $angle_tmp
        local.get $object_angle_tmp
        f32.ge
        if
            f32.const 1
            local.get $intersection_distance_to_object
            f32.sub
            f32.const 0.28 ;; магичесоке число, ширина объекта
            f32.div
            local.set $intersection_fraction
        else
            f32.const 0.14 ;; магичесоке число, половина ширины объекта
            local.get $intersection_distance_to_object
            f32.add
            f32.const 0.28 ;; магичесоке число, ширина объекта
            f32.div
            local.set $intersection_fraction
        end

        ;; случилось пересечение, добавим его в массив пересечений
        local.get $type
        local.get $intersection_distance_to_player
        local.get $intersection_fraction
        call $insert_to_objects_intersected)

    (func $clear_intersection_data
        loop $loop
            global.get $objects_intersected_count
            i32.const 0
            f32.const 0
            f32.const 0
            call $set_objects_intersected_by_index

            global.get $objects_intersected_count
            i32.const 0
            i32.ne
            if
                ;; i++
                global.get $objects_intersected_count
                i32.const 1
                i32.sub
                global.set $objects_intersected_count

                br $loop
            end
        end)
    
    (func $get_intersection_with_objects_for_angle (param $angle f32)
        (local $i i32)

        i32.const 0
        local.set $i

        call $clear_intersection_data

        loop $loop
            local.get $i
            global.get $objects_count
            i32.lt_u

            if
                local.get $i
                local.get $angle
                call $get_intersection_with_object_for_angle

                ;; i++
                local.get $i
                i32.const 1
                i32.add
                local.set $i

                br $loop
            end
        end)

    (func $get_shading_for_distance (param $distance f32) (result (; shading ;) f32)
        ;; shading = 1 - (distance / max_distance)
        f32.const 1
        local.get $distance
        global.get $intersection_map_max_distance_in_lines
        f32.convert_i32_s
        f32.div
        f32.sub)

    (func $get_angular_diameter (param $height f32) (param $distance f32) (result (; angular_diameter ;) f32)
        ;; angular_diameter = 2 * atan(D/(2*L)) - D размер объекта, L расстояние до объекта
        local.get $height
        f32.const 2
        global.get $map_cell_size_in_meters
        f32.mul
        local.get $distance
        f32.mul
        f32.div
        call $atan
        f32.const 2
        f32.mul)

    (func $draw_column (param $x i32)
        (local $i i32)
        (local $iy i32)
        (local $y_start i32)
        (local $y_end i32)
        (local $shading f32)
        (local $angular_diameter f32)
        (local $wall_percent_height f32)
        (local $wall_height i32)
        (local $wall_padding i32)
        (local $s_width i32)
        (local $s_height i32)
        (local $s_pointer i32)
        (local $s_palette i32)
        (local $r i32)
        (local $g i32)
        (local $b i32)
        (local $transparent i32)
        (local $wall_x i32)
        (local $intersection_fraction f32)
        (local $tsx f32)
        (local $tsy f32)
        (local $angle f32)
        (local $object_type i32)
        (local $object_distance f32)
        (local $object_percent_height f32)
        (local $object_height i32)
        (local $tmpi i32)
        (local $tmp f32)

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
        local.set $angle

        local.get $angle
        call $get_intersection_for_angle

        local.get $angle
        call $get_intersection_with_objects_for_angle
        
        global.get $intersection_is_found
        i32.const 1
        i32.eq
        if ;; we have intersection, draw wall
            global.get $intersection_cell_x
            global.get $intersection_cell_y
            call $get_wall_sprite_based_on_map_cell
            local.set $tsy
            local.set $tsx
            local.set $s_palette
            local.set $s_pointer
            local.set $s_height
            local.set $s_width

            call $get_intersection_fraction
            local.set $intersection_fraction

            global.get $intersection_last_near_distance
            call $get_shading_for_distance
            local.set $shading

            global.get $map_wall_height_in_meters
            global.get $intersection_last_near_distance
            call $get_angular_diameter
            local.set $angular_diameter

            ;; wall_percent_height = angular_diameter / vertical_FOV
            local.get $angular_diameter
            global.get $vertical_FOV
            f32.div
            local.set $wall_percent_height

            ;; wall_height = canvas_height * wall_percent_height
            global.get $canvas_height
            f32.convert_i32_s
            local.get $wall_percent_height
            f32.mul
            i32.trunc_f32_s
            local.set $wall_height

            local.get $wall_height
            global.get $canvas_height
            i32.le_s
            if
                global.get $canvas_height
                local.get $wall_height
                i32.sub
                i32.const 2
                i32.div_s
                local.set $y_start

                global.get $canvas_height
                local.get $y_start
                i32.sub
                local.set $y_end

                local.get $y_start
                local.set $wall_padding
            else
                i32.const 0
                local.set $y_start

                global.get $canvas_height
                local.set $y_end

                local.get $wall_height
                global.get $canvas_height
                i32.sub
                i32.const -2
                i32.div_s
                local.set $wall_padding
            end

            local.get $y_start
            local.set $iy

            loop $loop_y
                local.get $iy
                local.get $y_end
                i32.lt_u

                if
                    local.get $s_width
                    local.get $s_height
                    
                    ;; x [0-1)
                    local.get $intersection_fraction

                    ;; y [0-1)
                    local.get $iy
                    local.get $wall_padding
                    i32.sub
                    f32.convert_i32_s
                    local.get $wall_height
                    f32.convert_i32_s
                    f32.div

                    local.get $tsx
                    local.get $tsy

                    local.get $s_palette
                    local.get $s_pointer
                    call $get_sprite_pixel_color
                    local.set $transparent
                    local.set $b
                    local.set $g
                    local.set $r

                    local.get $transparent
                    i32.const 0
                    i32.eq
                    if
                        local.get $x
                        local.get $iy
                        local.get $r
                        local.get $g
                        local.get $b
                        local.get $shading
                        call $render_pixel
                    end

                    ;; iy++
                    local.get $iy
                    i32.const 1
                    i32.add
                    local.set $iy

                    br $loop_y
                end
            end
        end

        global.get $objects_intersected_count
        i32.const 0
        i32.ne
        if ;; есть пересечения с объектами, рисуем их
            global.get $objects_intersected_count
            i32.const 1
            i32.sub
            local.set $i
        
            loop $object_loop
                local.get $i
                i32.const 0
                i32.ge_s

                if
                    local.get $i
                    call $get_objects_intersected_by_index
                    local.set $intersection_fraction
                    local.set $object_distance
                    local.set $object_type

                    local.get $object_type
                    call $get_object_sprite_by_type
                    local.set $s_palette
                    local.set $s_pointer
                    local.set $s_height
                    local.set $s_width

                    local.get $object_distance
                    call $get_shading_for_distance
                    local.set $shading

                    f32.const 1.5
                    local.get $object_distance
                    call $get_angular_diameter
                    local.set $angular_diameter

                    ;; object_percent_height = angular_diameter / vertical_FOV
                    local.get $angular_diameter
                    global.get $vertical_FOV
                    f32.div
                    local.set $object_percent_height

                    ;; object_height = canvas_height * object_percent_height
                    global.get $canvas_height
                    f32.convert_i32_s
                    local.get $object_percent_height
                    f32.mul
                    i32.trunc_f32_s
                    local.set $object_height
                    
                    global.get $canvas_height
                    local.get $object_height
                    i32.sub
                    i32.const 2
                    i32.div_s
                    local.set $y_start

                    local.get $y_start
                    local.get $object_height
                    i32.add
                    local.set $y_end

                    local.get $y_start
                    local.set $iy

                    loop $loop_y
                        local.get $iy
                        local.get $y_end
                        i32.lt_u

                        if
                            local.get $s_width
                            local.get $s_height
                            
                            ;; x [0-1)
                            local.get $intersection_fraction

                            ;; y [0-1)
                            local.get $iy
                            local.get $y_start
                            i32.sub
                            f32.convert_i32_s
                            local.get $object_height
                            f32.convert_i32_s
                            f32.div

                            f32.const 1
                            f32.const 1

                            local.get $s_palette
                            local.get $s_pointer
                            call $get_sprite_pixel_color
                            local.set $transparent
                            local.set $b
                            local.set $g
                            local.set $r

                            local.get $transparent
                            i32.const 0
                            i32.eq
                            if
                                local.get $x
                                local.get $iy
                                local.get $r
                                local.get $g
                                local.get $b
                                local.get $shading
                                call $render_pixel
                            end

                            ;; iy++
                            local.get $iy
                            i32.const 1
                            i32.add
                            local.set $iy

                            br $loop_y
                        end
                    end


                    ;; i--
                    local.get $i
                    i32.const 1
                    i32.sub
                    local.set $i

                    br $object_loop
                end
            end
        end)

    (func $render
        call $render_background
        call $render_columns
        call $render_keys)

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
    
    (func $ctg (param $num f32) (result f32)
        f32.const 1
        local.get $num
        call $tan
        f32.div)
    
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
    ;   result r g b is_transparent i32
    ;)
    (func $get_sprite_pixel_color (param $sw i32) (param $sh i32) (param $x f32) (param $y f32) (param $tsx f32) (param $tsy f32) (param $palette i32) (param $sprite_pointer i32) (result i32) (result i32) (result i32) (result i32)
        (local $color_palette_index i32)
        (local $r i32)
        (local $g i32)
        (local $b i32)
        (local $is_transparent i32)
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

            i32.const 0
            local.set $is_transparent
        else
            i32.const 1
            local.set $is_transparent
        end

        local.get $r
        local.get $g
        local.get $b
        local.get $is_transparent)

    (func $render_sprite_on_screen (param $x i32) (param $y i32) (param $width i32) (param $height i32) (param $s_width i32) (param $s_height i32) (param $s_pointer i32) (param $palette i32)
        (local $r i32)
        (local $g i32)
        (local $b i32)
        (local $transparent i32)
        (local $iy i32)
        (local $ix i32)
        (local $x_to i32)
        (local $y_to i32)
    
        local.get $y
        local.set $iy

        local.get $y
        local.get $height
        i32.add
        local.set $y_to

        local.get $x
        local.set $ix

        local.get $x
        local.get $width
        i32.add
        local.set $x_to

        loop $loop_y
            local.get $iy
            local.get $y_to
            i32.lt_u
            if
                ;; reset ix
                local.get $x
                local.set $ix

                ;; loop by pixel in line
                loop $loop_x
                    local.get $ix
                    local.get $x_to
                    i32.lt_u

                    if
                        local.get $s_width
                        local.get $s_height
                        
                        ;; x [0-1)
                        local.get $ix
                        local.get $x
                        i32.sub
                        f32.convert_i32_s
                        local.get $width
                        f32.convert_i32_s
                        f32.div

                        ;; y [0-1)
                        local.get $iy
                        local.get $y
                        i32.sub
                        f32.convert_i32_s
                        local.get $height
                        f32.convert_i32_s
                        f32.div

                        f32.const 1 ;; tsx
                        f32.const 1 ;; tsy

                        local.get $palette
                        local.get $s_pointer
                        call $get_sprite_pixel_color
                        local.set $transparent
                        local.set $b
                        local.set $g
                        local.set $r

                        local.get $transparent
                        i32.const 0
                        i32.eq
                        if
                            local.get $ix
                            local.get $iy
                            local.get $r
                            local.get $g
                            local.get $b
                            f32.const 1
                            call $render_pixel
                        end

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

    (func $render_crosshair
        (local $width i32)
        (local $height i32)
        (local $pointer i32)
    
        call $get_sprite_crosshair
        local.set $pointer
        local.set $height
        local.set $width
        
        ;; x
        global.get $canvas_width
        i32.const 2
        i32.div_s
        i32.const 12
        i32.const 2
        i32.div_s
        i32.sub
        
        ;; y
        global.get $canvas_height
        i32.const 2
        i32.div_s
        i32.const 12
        i32.const 2
        i32.div_s
        i32.sub
        
        i32.const 12
        i32.const 12
        local.get $width
        local.get $height
        local.get $pointer
        i32.const 0
        call $render_sprite_on_screen)

    (func $have_key_by_color_number (param $num i32) (result i32)
        global.get $have_keys
        local.get $num
        i32.and
        local.get $num
        i32.eq
        if
            i32.const 1
            return
        end
        
        i32.const 0)

    (func $have_green_key (result i32)
        i32.const 1 ;; 0b1
        call $have_key_by_color_number)

    (func $have_blue_key (result i32)
        i32.const 2 ;; 0b10
        call $have_key_by_color_number)

    (func $have_red_key (result i32)
        i32.const 4 ;; 0b100
        call $have_key_by_color_number)

    (func $have_yellow_key (result i32)
        i32.const 8 ;; 0b1000
        call $have_key_by_color_number)

    (func $render_keys
        call $have_green_key
        i32.const 1
        i32.eq
        if
            i32.const 0
            i32.const 2
            call $render_key
        end

        call $have_blue_key
        i32.const 1
        i32.eq
        if
            i32.const 1
            i32.const 3
            call $render_key
        end

        call $have_red_key
        i32.const 1
        i32.eq
        if
            i32.const 2
            i32.const 4
            call $render_key
        end

        call $have_yellow_key
        i32.const 1
        i32.eq
        if
            i32.const 3
            i32.const 5
            call $render_key
        end)

    (func $render_key (param $offset i32)  (param $palette i32)
        (local $width i32)
        (local $height i32)
        (local $pointer i32)
    
        call $get_sprite_key
        local.set $pointer
        local.set $height
        local.set $width
        
        ;; x
        global.get $canvas_width
        i32.const 28 ;; render width
        i32.const 20
        i32.add
        local.get $offset
        i32.const 1
        i32.add
        i32.mul
        i32.sub
        
        ;; y
        global.get $canvas_height
        i32.const 20
        i32.sub
        i32.const 38 ;; render height
        i32.sub
        
        i32.const 28
        i32.const 38
        local.get $width
        local.get $height
        local.get $pointer
        local.get $palette
        call $render_sprite_on_screen)

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
        (; default palette 0 ;)     "\ff\ff\ff\d3\d3\d3\78\78\78\9f\59\2d\00\00\00\bb\0a\1e\25\5c\14\01\5d\52\9d\91\01\28\72\33\64\24\24\3e\5f\8a\ea\e6\ca\3b\d6\bf\ea\5e\e0"
        (; walls palette 1 ;)       "\78\78\78\9f\59\2d\25\5c\14\cd\c7\1d\00\00\00\bb\0a\1e\25\5c\14\01\5d\52\9d\91\01\28\72\33\64\24\24\3e\5f\8a\ea\e6\ca\3b\d6\bf\ea\5e\e0"
        (; green wall and key 2 ;)  "\ff\ff\ff\d3\d3\d3\a0\a0\a0\68\68\68\00\00\00\32\93\2f\25\5c\14\00\ff\11\9d\91\01\28\72\33\64\24\24\3e\5f\8a\ea\e6\ca\3b\d6\bf\ea\5e\e0"
        (; blue wall and key 3 ;)   "\ff\ff\ff\d3\d3\d3\a0\a0\a0\68\68\68\00\00\00\30\2f\93\14\19\5c\00\11\ff\9d\91\01\28\72\33\64\24\24\3e\5f\8a\ea\e6\ca\3b\d6\bf\ea\5e\e0"
        (; red wall and key 4 ;)    "\ff\ff\ff\d3\d3\d3\a0\a0\a0\68\68\68\00\00\00\93\2f\2f\5c\14\14\ff\00\00\9d\91\01\28\72\33\64\24\24\3e\5f\8a\ea\e6\ca\3b\d6\bf\ea\5e\e0"
        (; yellow wall and key 5 ;) "\ff\ff\ff\d3\d3\d3\a0\a0\a0\68\68\68\00\00\00\ab\a0\26\5a\5b\10\ff\f7\00\9d\91\01\28\72\33\64\24\24\3e\5f\8a\ea\e6\ca\3b\d6\bf\ea\5e\e0"
    )

    (;SPRITES
        brick_wall.sprt
        room_wall.sprt
        crosshair.sprt
        door.sprt
        key.sprt
    ;)
)
