######################################################################
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved. #
# SPDX-License-Identifier: MIT-0                                     #
######################################################################
 
import os
import pandas as pd



def extract_values_from_list(in_list):
    ret_dict = {}
    # Extract the latency numbers
    cur_line = in_list[5]
    cur_line_split = cur_line[1:-2].split(' ')
    ret_dict['p50'] = float(cur_line_split[0])
    ret_dict['p90'] = float(cur_line_split[1])
    ret_dict['p95'] = float(cur_line_split[2])

    # Extract Throughput
    cur_line = in_list[7]
    cur_line_split = cur_line.split(' ')
    ret_dict['throughput'] = float(cur_line_split[-1])

    return ret_dict

dir_name = os.getenv('LOG_DIRECTORY')
assert dir_name is not None, 'Specify LOG_DIRECTORY environment variable'

if (dir_name):
    file_list = os.listdir(dir_name)
    # Extract *.log files
    file_list = [x for x in file_list if x.endswith('.log')]

    extract_data_list = []
    for cur_file in file_list:
        with open('%s/%s'%(dir_name, cur_file)) as fp:
            file_contents = fp.readlines()
            extract_data = extract_values_from_list(file_contents)

            cur_file_no_ext = cur_file.split('.')[0]
            cur_file_no_ext_split = cur_file_no_ext.split('-')
            extract_data['length'] = int(cur_file_no_ext_split[-2])
            extract_data['batch_size'] = int(cur_file_no_ext_split[-1])
            extract_data['model_name'] = cur_file_no_ext

            extract_data_list.append(extract_data)

    extract_pd = pd.DataFrame.from_dict(extract_data_list)

    print(extract_pd.sort_values(by='throughput', ascending=False).to_string())