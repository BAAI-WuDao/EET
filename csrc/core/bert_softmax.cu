#include "core/common.cuh"
#include <cuda_runtime.h>
#include <cuda_fp16.h>

// bert softmax code modified from Nvidia's DeepLearningExamples
// https://github.com/NVIDIA/DeepLearningExamples/blob/master/FasterTransformer/v3.1/fastertransformer/cuda/open_attention.cu#L1399-L1583

template <typename T>
__global__
void softmax_kernel_bert(T *qk_buf, const T* attr_mask,const int head_num, const int seq_len, const T scalar)
{
    int batch_id = blockIdx.x / head_num;
    int qk_offset = blockIdx.x * seq_len * seq_len;
    int mask_offset = batch_id * seq_len * seq_len;
    __shared__ float s_sum, s_max;

    for(int i = 0; i < seq_len; ++i)
    {
        float qk = threadIdx.x < seq_len ? (float)qk_buf[threadIdx.x + qk_offset] : 0.0f;
        float mask_val = threadIdx.x < seq_len ? (float)attr_mask[threadIdx.x + mask_offset] : 0.0f;
      
        mask_val = (1.0f - mask_val) * -10000.0f;
        float tmp = threadIdx.x < seq_len ? (float)(qk * (float)scalar + mask_val): -1e20f;

        float max_val = blockReduceMax<float>(tmp);

        if(threadIdx.x == 0)
            s_max = max_val;
        __syncthreads();

        qk = threadIdx.x < seq_len ? __expf(tmp - s_max) : 0.0f;

        float sum_val = blockReduceSum<float>(qk);

        if(threadIdx.x == 0)
        {
            s_sum = sum_val + 1e-6f;
        }
        __syncthreads();

        if(threadIdx.x < seq_len)
            qk_buf[threadIdx.x + qk_offset] = (T)(qk / s_sum);

        qk_offset += seq_len;
    }
}

template <class T>
void bert_softmax_kernel(void *qk_buf, void *attr_mask, const int &batch_size,
                         const int &head_num, const int &seq_len, const float &scalar, const cudaStream_t stream)
{
  dim3 grid, block;

  if (seq_len <= 32)
    block.x = 32;
  else if (seq_len > 32 && seq_len <= 64)
    block.x = 64;
  else if (seq_len > 64 && seq_len <= 128)
    block.x = 128;
  else if (seq_len > 128 && seq_len <= 256)
    block.x = 256;
  else if (seq_len > 256 && seq_len <= 512)
    block.x = 512;
  else
    block.x = 1024;

  grid.x = batch_size * head_num;
  softmax_kernel_bert<T><<<grid, block, 0, stream>>>((T *)qk_buf, (T *)attr_mask, head_num, seq_len, scalar);
}

template void bert_softmax_kernel<float>(void *qk_buf, void* attr_mask,const int& batch_size, 
                                      const int& head_num, const int& seq_len, const float& scalar, const cudaStream_t stream);
template void bert_softmax_kernel<half>(void *qk_buf, void* attr_mask,const int& batch_size, 
                                      const int& head_num, const int& seq_len, const float& scalar, const cudaStream_t stream);
