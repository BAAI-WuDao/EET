import torch
import numpy as np
# from eet.transformers.modeling_bert import EETBertModel
# from modeling_albert import EETAlbertModel
from eet.transformers.modeling_albert import EETAlbertModel
from transformers import AlbertModel

import time

using_half = True
seq_len = 128
batch = 4
loop = 100

def main():
    torch.set_grad_enabled(False)

    input = np.random.randint(1000,9000,seq_len * batch,dtype="int64")
    input_ids = torch.from_numpy(input).long().reshape(batch, seq_len).cuda()

    data_type = torch.float32
    if using_half:
        data_type = torch.float16
    eet_model = EETAlbertModel.from_pretrained('albert-base-v1',max_batch = batch,data_type = data_type)
    ts_model = AlbertModel.from_pretrained('albert-base-v1').cuda()
    if using_half:
        ts_model = ts_model.half()
      
    attention_mask = None
    for i in range(loop):
        res_eet = eet_model(input_ids, attention_mask=attention_mask)


    torch.cuda.synchronize()
    t1 = time.perf_counter()
    for i in range(loop):
        res_eet = eet_model(input_ids, attention_mask=attention_mask)
    torch.cuda.synchronize()
    t2 = time.perf_counter()
    time_eet = t2 - t1
    print('Time for EET : ', time_eet)
    torch.cuda.synchronize()
    t3 = time.perf_counter()
    for i in range(loop):
        res_ts = ts_model(input_ids,attention_mask)
    torch.cuda.synchronize()
    t4= time.perf_counter()
    time_ts = t4 -t3
    print('Time for Transformers: ', time_ts)
    print('SpeedUp is ', time_ts / time_eet)

if __name__ == '__main__':
    main()
