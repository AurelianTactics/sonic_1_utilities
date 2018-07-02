level_max_x = {
-- Green Hill Zone
    ["zone=0,act=0"] = 0x2560,
    ["zone=0,act=1"] = 0x1F60,
    ["zone=0,act=2"] = 0x292A,

-- Marble Zone
    ["zone=2,act=0"] = 0x1860,
    ["zone=2,act=1"] = 0x1860,
    ["zone=2,act=2"] = 0x1720,

-- Spring Yard Zone
    ["zone=4,act=0"] = 0x2360,
    ["zone=4,act=1"] = 0x2960,
    ["zone=4,act=2"] = 0x2B83,

-- Labyrinth Zone
    ["zone=1,act=0"] = 0x1A50,
    ["zone=1,act=1"] = 0x1150,
    ["zone=1,act=2"] = 0x1CC4,

-- Star Light Zone
    ["zone=3,act=0"] = 0x2060,
    ["zone=3,act=1"] = 0x2060,
    ["zone=3,act=2"] = 0x1F48,

-- Scrap Brain Zone
    ["zone=5,act=0"] = 0x2260,
    ["zone=5,act=1"] = 0x1EE0,
    -- ["zone=5,act=2"] = 000000, -- does not have a max x
}

function clip(v, min, max)
    if v < min then
        return min
    elseif v > max then
        return max
    else
        return v
    end
end

prev_lives = 3

function contest_done()
    if data.lives < prev_lives then
        return true
    end
    prev_lives = data.lives

    if calc_progress(data) >= 1 then
        return true
    end

    return false
end

offset_x = nil
end_x = nil
prev_x = nil --added these for waypoint check
prev_y = nil

function calc_progress(data)
    if offset_x == nil then
        offset_x = -data.x
        local key = string.format("zone=%d,act=%d", data.zone, data.act)
        end_x = level_max_x[key] - data.x
	prev_x = data.x
	prev_y = data.y
    end

    local cur_x = clip(data.x + offset_x, 0, end_x)
    return cur_x / end_x
end

prev_progress = 0
frame_count = 0
frame_limit = 18000

function contest_reward()
    frame_count = frame_count + 1
    local progress = calc_progress(data)
    local reward = (progress - prev_progress) * 9000
    prev_progress = progress

    -- bonus for beating level quickly
    if progress >= 1 then
        reward = reward + (1 - clip(frame_count/frame_limit, 0, 1)) * 1000
    end
    return reward
end


function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end


tolerance_check = 0 --sets how close to human trajectory needs to be
-- calc progress along a trajectory
function calc_trajectory_progress(data)
    
    local ret_value = check_progress_dict(data.x,data.y)
    if ret_value ~= nil then
	return ret_value
    end
 
    if tolerance_check > 1 then
	local z1 = 1
	while (z1 < tolerance_check) do
	    ret_value = check_progress_dict(data.x,data.y-z1)
	    if ret_value ~= nil then
	        break
	    end
	    ret_value = check_progress_dict(data.x,data.y+z1)
	    if ret_value ~= nil then
	        break
	    end
	    ret_value = check_progress_dict(data.x-z1,data.y)
	    if ret_value ~= nil then
	        break
	    end
	    ret_value = check_progress_dict(data.x+z1,data.y)
	    if ret_value ~= nil then
	        break
	    end
	    ret_value = check_progress_dict(data.x-z1,data.y+z1)
	    if ret_value ~= nil then
	        break
	    end
	    ret_value = check_progress_dict(data.x+z1,data.y-z1)
	    if ret_value ~= nil then
	        break
	    end
	    ret_value = check_progress_dict(data.x-z1,data.y-z1)
	    if ret_value ~= nil then
	        break
	    end
	    ret_value = check_progress_dict(data.x+z1,data.y+z1)
	    if ret_value ~= nil then
	        break
	    end
	    z1 = z1 + 1
	end
    end
    return ret_value  
end

function check_progress_dict(x,y)
    local key = tostring(x) .. "," .. tostring(y)
    if level_progress_dict[key] ~= nil then
	return tonumber(level_progress_dict[key])
    end
    return nil
end

prev_step = 0

-- reward as compared to user trajectory
function reward_by_trajectory()
    frame_count = frame_count + 1
    local level_done = calc_progress(data)
    local temp_progress = calc_trajectory_progress(data)
    
    local reward = 0
    if temp_progress ~= nil then
	reward = (temp_progress/level_dict_len - prev_step/level_dict_len) * 9000
	reward = clip(reward,-400.1,400.1)	
	prev_step = temp_progress
    end

    if level_done >= 1 then
	reward = reward + (1 - clip(frame_count/frame_limit, 0, 1)) * 1000
    end

    return reward
end


prev_step_max = 0
-- reward that allows backtracking, only rewarded by getting max trajectory
function reward_by_max_trajectory()
    frame_count = frame_count + 1
    local level_done = calc_progress(data)
    local temp_progress = calc_trajectory_progress(data)

    local reward = reward_by_ring(data)
    if (temp_progress ~= nil and temp_progress > prev_step_max) then
	reward = (temp_progress/level_dict_len - prev_step_max/level_dict_len) * 9000
	reward = clip(reward,-400.1,400.1)
	prev_step_max = temp_progress
    end


    --penalty for having zero rings: small negative reward AND you can't get more trajectory progress
	--either use this reward function or the one above it
--[=====[ 
    if first_ring_gotten == 1 and data.rings == 0 then
	reward = reward - 0.1
    else
	if (temp_progress ~= nil and temp_progress > prev_step_max) then
	    reward = (temp_progress/level_dict_len - prev_step_max/level_dict_len) * 9000
	    reward = clip(reward,-400.1,400.1)
	    prev_step_max = temp_progress
 	end
    end
--]=====]

    if level_done >= 1 then
	reward = reward + (1 - clip(frame_count/frame_limit, 0, 1)) * 1000
    end

    return reward
end


prev_ring_num = 0
function reward_by_ring(data)
    local ring_reward = 0
    local current_ring_num = data.rings
    if current_ring_num < prev_ring_num then
	ring_reward = -10.0
    elseif current_ring_num > prev_ring_num then
	if prev_ring_num == 0 then
	    ring_reward = 2.0
	else
	    ring_reward = 0.1
	end
    end

    prev_ring_num = current_ring_num
    return ring_reward
end

waypoint_length = 22
function get_waypoint_x_dict()
    local ret_x = {}
    ret_x[0] = 1164
    ret_x[1] = 1107
    ret_x[2] = 1909
    ret_x[3] = 2037
    ret_x[4] = 2332
    ret_x[5] = 2510
    ret_x[6] = 2709
    ret_x[7] = 2457
    ret_x[8] = 2154
    ret_x[9] = 3038
    ret_x[10] = 3309
    ret_x[11] = 3172
    ret_x[12] = 3216
    ret_x[13] = 3730
    ret_x[14] = 4442
    ret_x[15] = 4565
    ret_x[16] = 4673
    ret_x[17] = 5581
    ret_x[18] = 4853
    ret_x[19] = 5141
    ret_x[20] = 6412
    ret_x[21] = 7404

    return ret_x
end

function get_waypoint_y_dict()
    local ret_y = {}
    ret_y[0] = 675
    ret_y[1] = 748
    ret_y[2] = 867
    ret_y[3] = 1251
    ret_y[4] = 1516
    ret_y[5] = 1260
    ret_y[6] = 1068
    ret_y[7] = 1004
    ret_y[8] = 940
    ret_y[9] = 620
    ret_y[10] = 995
    ret_y[11] = 1196
    ret_y[12] = 1203
    ret_y[13] = 1180
    ret_y[14] = 1196
    ret_y[15] = 1251
    ret_y[16] = 1260
    ret_y[17] = 1004
    ret_y[18] = 419
    ret_y[19] = 492
    ret_y[20] = 1228
    ret_y[21] = 1516
    return ret_y
end

waypoint_x_dict = get_waypoint_x_dict()
waypoint_y_dict = get_waypoint_y_dict()

--reward scaled by total distance travelled
--want total distance for level to be scaled with the 9k reward
--called once after prev_x and prev_y are initialized
waypoint_distance_table = {} --used in reward_by_max_waypoint
function get_total_distance(x,y)
    --local distance = math.sqrt((x-waypoint_x_dict[0])^2 + (y-waypoint_y_dict[0])^2)
    local distance = math.abs((x-waypoint_x_dict[0])) + math.abs((y-waypoint_y_dict[0]))
 
    for i = 0, waypoint_length-2 do
	waypoint_distance_table[i] = distance
    	--distance = distance + math.sqrt((waypoint_x_dict[i]-waypoint_x_dict[i+1])^2 + (waypoint_y_dict[i]-waypoint_y_dict[i+1])^2)
	distance = distance + math.abs((waypoint_x_dict[i]-waypoint_x_dict[i+1])) + math.abs((waypoint_y_dict[i]-waypoint_y_dict[i+1]))
    end
    waypoint_distance_table[waypoint_length-1] = distance

    return distance
end

--checks to see if waypoint reached. if so gives reward and sets waypoint to next waypoint
prev_distance = nil
current_waypoint = 0
waypoint_x = waypoint_x_dict[current_waypoint]
waypoint_y = waypoint_y_dict[current_waypoint]
waypoint_minibonus = 100/waypoint_length
function calc_waypoint(data)
    if data.x == waypoint_x and data.y == waypoint_y then
	prev_distance = nil
	current_waypoint = current_waypoint + 1
	if current_waypoint < waypoint_length then
	    waypoint_x = waypoint_x_dict[current_waypoint]
	    waypoint_y = waypoint_y_dict[current_waypoint]
	end
	--reward bonus for reaching waypoint
	return (1 - clip(frame_count/frame_limit, 0, 1)) * waypoint_minibonus
    end

    return 0
end


--get reward for getting closer to waypoint, less for further from waypoint
waypoint_reward_scale = nil
prev_screen_y = nil
prev_same_x = 0
prev_same_screen_y = 0
prev_anchor_y = nil

function reward_by_waypoint()
    frame_count = frame_count + 1
    local level_done = calc_progress(data)

    --local reward = reward_by_ring(data)
    local reward = 0
    reward = reward + calc_waypoint(data)

    if prev_distance == nil then
	--prev_distance = math.sqrt((prev_x-waypoint_x)^2 + (prev_y-waypoint_y)^2)
	prev_distance = math.abs((prev_x-waypoint_x)) + math.abs((prev_y-waypoint_y))
    end

    if waypoint_reward_scale == nil then
	local total_distance = get_total_distance(prev_x,prev_y)
	waypoint_reward_scale = 9000.0/total_distance
	prev_same_screen_y = data.screen_y
	prev_anchor_y = nil
    end

    --deaths aren't registed right away but sonic will move a lot on the y axis
	--this is a rough check for that
    if (data.x == prev_x) and (data.screen_y == prev_screen_y) then
	prev_same_x = prev_same_x + 1
	prev_same_screen_y = prev_same_screen_y + 1
    else
	prev_same_x = 0
	prev_same_screen_y = 0
	prev_anchor_y = data.y
    end


    if (prev_same_x <= 20) or (math.abs((data.y-prev_anchor_y)) < 65) then
	--local curr_distance = math.sqrt((data.x-waypoint_x)^2 + (data.y-waypoint_y)^2)
	local curr_distance = math.abs((data.x-waypoint_x)) + math.abs((data.y-waypoint_y))
	local distance_reward = (prev_distance - curr_distance)*waypoint_reward_scale
	reward = reward + distance_reward
    end
    
    prev_distance = curr_distance
    prev_x = data.x
    prev_y = data.y
    prev_screen_y = data.screen_y

    if level_done >= 1 then
	reward = reward + (1 - clip(frame_count/frame_limit, 0, 1)) * 1000
    end

    return reward
end

prev_max_distance_reward = 0
--only get reward for going over prior max
--calculates reward based on where you are in terms of waypoints and progress to next waypoint
function reward_by_max_waypoint()

    frame_count = frame_count + 1
    local level_done = calc_progress(data)

    --local reward = reward_by_ring(data)
    local reward = 0
    calc_waypoint(data) --increments waypoint

    if waypoint_reward_scale == nil then
	local total_distance = get_total_distance(prev_x,prev_y)
	waypoint_reward_scale = 9000.0/total_distance
	prev_same_screen_y = data.screen_y
	prev_anchor_y = nil
    end

    --deaths aren't registed right away but sonic will move a lot on the y axis
	--this is a rough check for that
    if (data.x == prev_x) and (data.screen_y == prev_screen_y) then
	prev_same_x = prev_same_x + 1
	prev_same_screen_y = prev_same_screen_y + 1
    else
	prev_same_x = 0
	prev_same_screen_y = 0
	prev_anchor_y = data.y
    end

    if (prev_same_x <= 20) or (math.abs((data.y-prev_anchor_y)) < 65) then
	--local curr_distance = math.sqrt((data.x-waypoint_x)^2 + (data.y-waypoint_y)^2)
	local curr_distance = waypoint_distance_table[current_waypoint] - (math.abs((data.x-waypoint_x)) + math.abs((data.y-waypoint_y)))
    	local distance_reward = curr_distance*waypoint_reward_scale
	if distance_reward > prev_max_distance_reward then
	    reward = reward + (distance_reward - prev_max_distance_reward)
	    prev_max_distance_reward = distance_reward
	end
    end
    
    prev_x = data.x
    prev_y = data.y
    prev_screen_y = data.screen_y

    if level_done >= 1 then
	reward = reward + (1 - clip(frame_count/frame_limit, 0, 1)) * 1000
    end

    return reward
end

--have to follow demonstration trajectory exactly
follow_steps = 0
function reward_by_follow()
    frame_count = frame_count + 1
    local level_done = calc_progress(data)

    local reward = 0
    local follow_value = follow_table[follow_steps]
    local check_value = tostring(data.x) .. "," .. tostring(data.y)
    
    if follow_value == check_value then
	reward = reward + follow_reward_constant
	follow_steps = follow_steps + 1
    end

    local temp_progress = calc_trajectory_progress(data)

    if level_done >= 1 then
	reward = reward + (1 - clip(frame_count/frame_limit, 0, 1)) * 1000
    end

    return reward
end


-- load level dictionary 
level_dict_len = 6836

function get_level_progress_dict()
    local ret_value = {}
    ret_value["80,748"] = 1
    ret_value["81,748"] = 2
    --...
    ret_value["5999,3412"] = 6845
    return ret_value
end
level_progress_dict = get_level_progress_dict()


follow_steps_total = 8245
follow_reward_constant = 9000/follow_steps_total
function get_follow_table()
    ret_value = {}
    ret_value[0] = "80,748"
    ret_value[1] = "81,748"
    ret_value[2] = "82,748"
    ret_value[3] = "83,748"
    ret_value[4] = "84,748"
    ret_value[5] = "85,748"
    --...
    ret_value[8244] = "1449,2000"
    return ret_value
end
follow_table = get_follow_table()



-- load level dictionary and see how long it is
-- ideally Lua would read from a file. This works in Lua 5.1 but not in retro-gym Lua
--[=====[ 
level_dict_len = 8868

function get_level_progress_dict()
    local ret_value = {}
    ret_value["48,358"] = 1
    ret_value["6357,671"] = 8868



--    io.flush()
--    local temp = io.open("test_lua_search.txt","w")
--    local file = io.open("trajectory_test.csv", "r");


    for line in file:lines() do
	local temp_split = split(line, ",")
	local temp_key = temp_split[1] .. "," .. temp_split[2]
	local temp_value = temp_split[3]
	ret_dict[temp_key] = temp_value
	level_dict_len = level_dict_len + 1
    end
    io.close(file)

    return ret_value
end

level_progress_dict = get_level_progress_dict()
--]=====]


--[=====[ 
--]=====]

