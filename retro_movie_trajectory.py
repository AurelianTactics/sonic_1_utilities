import sys
import retro
import csv
import time
import pickle
from baselines.common.atari_wrappers import WarpFrame, FrameStack
import numpy as np
from sonic_util_test import AllowBacktracking #, make_env
from collections import OrderedDict

#1 for viewing videos, 0 for creating waypoints
debug = int(sys.argv[1])

level_string = 'LabyrinthZone.Act3'#'StarLightZone.Act3'
replay_number = '008'
movie_path = 'retro-movies/human/SonicTheHedgehog-Genesis/contest/SonicTheHedgehog-Genesis-{}-0{}.bk2'.format(level_string,replay_number)
print(movie_path)
movie = retro.Movie(movie_path)
movie.step()

scenario_string= 'trajectory_max'#'test_retro' #'trajectory_max'
env = retro.make(game=movie.get_game(), state=level_string, scenario=scenario_string, use_restricted_actions=retro.ACTIONS_ALL)
env.initial_state = movie.get_state()
env.reset()

button_dict = ['B', 'A', 'MODE', 'START', 'UP', 'DOWN', 'LEFT', 'RIGHT', 'C', 'Y', 'X', 'Z']
num_buttons = len(button_dict)

num_steps = 0
total_reward = 0.
keys_file = open('keys.csv','w')
keys_csv = csv.DictWriter(keys_file,fieldnames=['step','keys','action','r','x','y','rings'])
keys_csv.writeheader()

trajectory_steps = 0
traj_dict = OrderedDict()
traj_skip_key = 'UP' #when this key is pressed, no trajectories from this frame will be used
traj_skip = 0

#creates a waypoint for the reward function when the user holds waypoint_key down for waypoint_threshold number of steps
waypoint_steps = 0
waypointx_dict = OrderedDict()
waypointy_dict = OrderedDict()
waypoint_key = 'START'
waypoint_this_frame = 0
waypoint_press = 0
waypoint_threshold = 30
prev_waypoint_x = 0
prev_waypoint_y = 0

#creates a trajectory to be followed step by step
follow_dict = OrderedDict()
follow_steps = 0
prev_x = 0
prev_y = 0


print('stepping movie')

while movie.step():
    if debug:
        env.render()
        time.sleep(0.001)
    keys = []
    key_string = '_'
    waypoint_this_frame = 0
    traj_skip = 0
    for i in range(num_buttons):
        keys.append(movie.get_key(i))
        if movie.get_key(i):
            key_string += button_dict[i] + "_"
            if button_dict[i] == waypoint_key:
                #print(movie.get_key(i),button_dict[i])
                waypoint_this_frame = 1
            if button_dict[i] == traj_skip_key:
                traj_skip = 1

    _obs, _rew, _done, _info = env.step(keys)
    num_steps += 1
    total_reward += _rew

    if waypoint_this_frame:
        waypoint_press += 1
    else:
        waypoint_press = 0

    current_x = _info['x']
    current_y = _info['y']
    keys_csv.writerow({'step': num_steps, 'keys':key_string, 'action':key_string, 'r':_rew, 'x':current_x, 'y':current_y, 'rings':_info['rings']})
    if debug: #and _rew > -1000:
        print(np.round(_rew,2), "_",np.round(total_reward,0),"_", _info['rings'],"--{},{}--{}".format(current_x,current_y,_info['screen_y']))
        #print(_info)



    #test not only that key was pressed continously but also that this isn't the same waypoint as the prior waypoint
    if waypoint_press >= waypoint_threshold and current_x != prev_waypoint_x and current_y != prev_waypoint_y:
        waypoint_press = 0
        prev_waypoint_x = current_x
        prev_waypoint_y = current_y
        waypointx_dict[waypoint_steps] = current_x
        waypointy_dict[waypoint_steps] = current_y
        waypoint_steps += 1
        print("waypoint created")


    #add trajectory to dict if not in dict previously
    key = "\"{},{}\"".format(current_x, current_y)
    if key not in traj_dict:
        trajectory_steps += 1
        if not traj_skip: #still want to accumulate reward for making it far in areas without a trajectory
            traj_dict[key] = trajectory_steps

    if not traj_skip and (prev_x != current_x or prev_y != current_y):
        follow_dict[follow_steps] = key
        follow_steps += 1
    prev_x = current_x
    prev_y = current_y

keys_file.close()

if not debug:
    t_file = open('traj_dict_{}_{}.csv'.format(level_string,replay_number),'w')
    t_csv = csv.DictWriter(t_file,fieldnames=['line'])
    for key,value in traj_dict.items():
        zString = "    ret_value[{}] = {}".format(key, value)
        t_csv.writerow({'line':zString})
    t_file.close()

    w_file = open('waypoint_dict_{}_{}.csv'.format(level_string,replay_number),'w')
    w_csv = csv.DictWriter(w_file,fieldnames=['line'])
    for key,value in waypointx_dict.items():
        zString = "    ret_x[{}] = {}".format(key,value)
        w_csv.writerow({'line':zString})
    for key,value in waypointy_dict.items():
        zString = "    ret_y[{}] = {}".format(key,value)
        w_csv.writerow({'line':zString})
    w_file.close()

    f_file = open('follow_dict_{}_{}.csv'.format(level_string, replay_number), 'w')
    f_csv = csv.DictWriter(f_file, fieldnames=['line'])
    for key, value in follow_dict.items():
        zString = "    ret_value[{}] = {}".format(key, value)
        f_csv.writerow({'line': zString})
    f_file.close()
