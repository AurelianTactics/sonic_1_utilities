import sys
import retro
import csv
import time
import pickle
from baselines.common.atari_wrappers import WarpFrame, FrameStack
import numpy as np
from sonic_util_test import AllowBacktracking #, make_env
from collections import OrderedDict


level_string = 'MarbleZone.Act1'#'StarLightZone.Act3'
movie_path = 'retro-movies/human/SonicTheHedgehog-Genesis/contest/SonicTheHedgehog-Genesis-{}-0000.bk2'.format(level_string)
movie = retro.Movie(movie_path)
movie.step()

scenario_string= 'test_retro'#'test_retro' #'trajectory_max'
env = retro.make(game=movie.get_game(), state=level_string, scenario=scenario_string, use_restricted_actions=retro.ACTIONS_ALL)
env = WarpFrame(env)


env.initial_state = movie.get_state()
_obs = env.reset()
obs_list = [_obs,_obs,_obs,_obs]
reward_list = [0.,0.,0.]

#turns action keys from movie into action number from sonic utils
#dictionary for these action keys:[['LEFT'], ['RIGHT'], ['LEFT', 'DOWN'], ['RIGHT', 'DOWN'], ['RIGHT', 'B'], ['DOWN'], ['NOOP'], ['B']]
NOOP_constant = 6
def sonic_define_action_dict():
    temp_dict = {}
    temp_dict['B'] = 7
    temp_dict['NOOP'] = 6
    temp_dict['DOWN'] = 5
    temp_dict['RIGHT', 'DOWN'] = 4
    temp_dict['LEFT', 'DOWN'] = 3
    temp_dict['RIGHT', 'B'] = 2
    temp_dict['RIGHT'] = 1
    temp_dict['LEFT'] = 0

    ret_dict = {} #B,DOWN,LEFT,RIGHT
    ret_dict[(True, True, True, True)] = temp_dict['B']
    ret_dict[(True, True, True, False)] = temp_dict['B']
    ret_dict[(True, True, False, True)] = temp_dict['B']
    ret_dict[(True, True, False, False)] = temp_dict['B']
    ret_dict[(True, False, True, True)] = temp_dict['B']
    ret_dict[(True, False, True, False)] = temp_dict['B']
    ret_dict[(True, False, False, True)] = temp_dict['RIGHT', 'B']
    ret_dict[(True, False, False, False)] = temp_dict['B']
    ret_dict[(False, True, True, True)] = temp_dict['DOWN']
    ret_dict[(False, True, True, False)] = temp_dict['LEFT', 'DOWN']
    ret_dict[(False, True, False, True)] = temp_dict['RIGHT', 'DOWN']
    ret_dict[(False, True, False, False)] = temp_dict['DOWN']
    ret_dict[(False, False, True, True)] = temp_dict['NOOP']
    ret_dict[(False, False, True, False)] = temp_dict['LEFT']
    ret_dict[(False, False, False, True)] = temp_dict['RIGHT']
    ret_dict[(False, False, False, False)] = temp_dict['NOOP']

    return ret_dict

#b, left, right, down
def game_get_dict_key(keys):
    # if A, B, C active activates B since all three jump
    if keys[1] or keys[8]:
        keys[0] = True
    # if both left and right, neither
    # if keys[6] and keys[7]:
    #     keys[6] = False
    #     keys[7] = False
    #B, DOWN, LEFT, RIGHT
    key = (keys[0], keys[5], keys[6], keys[7])

    return key


button_dict = ['B', 'A', 'MODE', 'START', 'UP', 'DOWN', 'LEFT', 'RIGHT', 'C', 'Y', 'X', 'Z']
num_buttons = len(button_dict)
game_dict = sonic_define_action_dict(key_dict)
num_steps = 0
total_reward = 0.
keys_file = open('keys.csv','w')
keys_csv = csv.DictWriter(keys_file,fieldnames=['step','keys','action','r','x','y','rings'])
keys_csv.writeheader()

rew_constant = 0.5
prev_action = -19

print('stepping movie')

transitions = []

debug = int(sys.argv[1])

while movie.step():
    if debug:
        env.render()
        time.sleep(0.005)
    keys = []
    key_string = '_'
    for i in range(num_buttons):
        keys.append(movie.get_key(i))
        if movie.get_key(i):
            key_string += button_dict[i] + "_"
    game_a = game_dict[game_get_dict_key(keys)]


    trans = {}
    trans['episode_id'] = 0
    trans['obs'] = list(obs_list) #defined by env.reset() above for first one

    _obs, _rew, _done, _info = env.step(keys)
    num_steps += 1
    total_reward += _rew

    #saved_state = env.em.get_state() #doesn't work with WarpFrame and FrameStack wrappers
    current_x = _info['x']
    current_y = _info['y']
    keys_csv.writerow({'step': num_steps, 'keys':key_string, 'action':game_a, 'r':_rew, 'x':current_x, 'y':current_y, 'rings':_info['rings']})
    if debug and _rew > -10:
        print(np.round(_rew,2), "_",total_reward,"_", _info['rings'],"--{},{}".format(current_x,current_y), "--",frames_since_ring_lost)

    shaped_rew = _rew

    reward_list.pop(0)
    reward_list.append(_rew) #reward_list.append(shaped_rew) #
    trans['rewards'] = list(reward_list)
    trans['end_time'] = time.time()
    trans['info'] = dict(_info)
    trans['start_state'] = None
    obs_list.pop(0)
    obs_list.append(_obs)
    trans['new_obs'] = list(obs_list)
    trans['model_outs'] = {}
    trans['model_outs']['actions'] = np.array([game_a])
    trans['episode_step'] = num_steps - 1
    trans['total_reward'] = total_reward
    trans['is_last'] = False
    if game_a != NOOP_constant or prev_action != NOOP_constant:
        if _rew < 100: #not doing end of level transitions, can mess things up
            transitions.append(trans)
    prev_action = game_a

transitions[-1]['is_last'] = True

with open('human_transitions.p', 'wb') as handle:
    pickle.dump(transitions, handle, protocol=pickle.HIGHEST_PROTOCOL)

keys_file.close()
