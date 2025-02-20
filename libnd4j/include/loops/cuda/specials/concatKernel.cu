/* ******************************************************************************
 *
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License, Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0.
 *
 *  See the NOTICE file distributed with this work for additional
 *  information regarding copyright ownership.
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 ******************************************************************************/

//
// @author raver119@gmail.com
// @author Yurii Shyrma, created on 15.11.2018
//
#include <loops/special_kernels.h>


namespace sd {
///////////////////////////////////////////////////////////////////////
template <typename T>
SD_DEVICE void concatKernel(int numArrays, Pointer *data, Pointer *inputShapeInfos, void *vz, LongType *resultShapeInfo,
                            Pointer *tadPointers, Pointer *offsetPointers, LongType *zTadShape, LongType *zOffsets) {
  int tid = threadIdx.x + blockIdx.x * blockDim.x;

  int zRank = shape::rank(resultShapeInfo);

  auto result = reinterpret_cast<T *>(vz);
  auto dataT = reinterpret_cast<T **>(data);
  auto shapeInfoPointers = reinterpret_cast<LongType **>(inputShapeInfos);
  auto tadShapes = reinterpret_cast<LongType **>(tadPointers);
  auto tadOffsets = reinterpret_cast<LongType **>(offsetPointers);

  __shared__ int baseIdx;

  __shared__ int yLength;
  __shared__ char yOrder;
  __shared__ int yEWS;

  char zOrder = shape::order(resultShapeInfo);

  int zEWS = shape::elementWiseStride(resultShapeInfo);
  int tadEWS = shape::elementWiseStride(zTadShape);
  int zLength = shape::length(resultShapeInfo);

  __shared__ int arrOffset;
  __shared__ int numTads;

  if (shape::isVector(resultShapeInfo)) {
    if (zEWS >= 1) {
      for (int r = blockIdx.x; r < numArrays; r += gridDim.x) {
        if (shape::isVector(shapeInfoPointers[r]) ||
            shape::order(shapeInfoPointers[r]) == shape::order(resultShapeInfo)) {
          yLength = shape::length(shapeInfoPointers[r]);
          yEWS = shape::elementWiseStride(shapeInfoPointers[r]);
          // FIXME: this is bad
          __shared__ int baseIdx;
          if (threadIdx.x == 0) {
            baseIdx = 0;
            for (int f = 0; f < r; f++) {
              baseIdx += shape::length(shapeInfoPointers[f]);
            }
          }
          __syncthreads();
          for (int i = threadIdx.x; i < yLength && baseIdx + i < zLength; i += blockDim.x) {
            result[baseIdx + i * zEWS] = dataT[r][i * yEWS];
          }
          __syncthreads();
        } else {
          if (tid == 0) printf("Non-matched order for vector\n");
        }
      }
    } else {
      if (tid == 0) printf("Vector Non-1 zEWS\n");
    }
    return;
  }

  bool _vec = shape::isVector(resultShapeInfo);

  // TODO: to be pulled into separate kernel. matrix concatenation
  for (int r = 0; r < numArrays; r++) {
    auto currentShape = shapeInfoPointers[r];
    auto currentData = dataT[r];
    auto currentTad = tadShapes[r];
    auto currentOffsets = tadOffsets[r];

    if (threadIdx.x == 0) {
      yLength = shape::length(currentTad);
      yOrder = shape::order(currentTad);
      yEWS = shape::elementWiseStride(currentTad);
      numTads = shape::length(currentShape) / yLength;

      arrOffset = 0;
      for (int f = 0; f < r; f++) {
        arrOffset += shape::length(tadShapes[f]);
      }


    }
    __syncthreads();

    if (yLength == 1 && _vec) {
      // edge case, each thread will handle it's own tad then
      for (LongType j = tid; j < numTads; j += blockDim.x * gridDim.x) {
        LongType inputOffset = currentOffsets[j];
        LongType resultOffset = zOffsets[j];

        T *dataTAD = currentData + inputOffset;
        T *resultTAD = result + resultOffset;

        LongType sub[SD_MAX_RANK];

        shape::index2coords(arrOffset, zTadShape, sub);

        LongType baseOffset = shape::getOffset(zTadShape, sub);

        resultTAD += baseOffset;

        auto yRank = shape::rank(currentTad);
        auto tadRank = shape::rank(zTadShape);

        shape::index2coords(0, currentTad, sub);

        auto yOffset = shape::getOffset(currentTad, sub);
        resultOffset = shape::getOffset(zTadShape, sub);

        resultTAD[resultOffset] = dataTAD[yOffset];
      }
    } else {


      for (LongType j = blockIdx.x; j < numTads; j += gridDim.x) {
        auto inputOffset = currentOffsets[j];
        auto resultOffset = zOffsets[j];

        auto dataTAD = currentData + inputOffset;
        auto resultTAD = result + resultOffset;

        LongType sub[SD_MAX_RANK];

        shape::index2coords(arrOffset, zTadShape, sub);
        LongType baseOffset = shape::getOffset(zTadShape, sub);

        resultTAD += baseOffset;

        if (zOrder == yOrder && yEWS > 0 && tadEWS > 0) {
          for (int i = threadIdx.x; i < yLength; i += blockDim.x) {
            resultTAD[i * tadEWS] = dataTAD[i * yEWS];
          }
        } else {
          if (tadEWS > 0 && shape::order(resultShapeInfo) == shape::order(currentTad)) {

            if (threadIdx.x == 0) {
              baseIdx = 0;
              for (int f = 0; f < r; f++) {
                baseIdx += shape::length(shapeInfoPointers[f]);
              }
            }
            __syncthreads();

            if (numTads == 1) {
              for (int k = threadIdx.x; k < yLength; k += blockDim.x) {
                resultTAD[baseIdx + k * tadEWS] = dataTAD[k];
              }
            } else {
              LongType yIdx[SD_MAX_RANK];
              auto yRank = shape::rank(currentTad);

              for (LongType i = threadIdx.x; i < yLength; i += blockDim.x) {
                shape::index2coords(i, currentTad, yIdx);
                auto yOffset = shape::getOffset(currentTad, yIdx);

                resultTAD[baseIdx + i * tadEWS] = dataTAD[yOffset];
              }
            }
            __syncthreads();
          } else {
            LongType zIdx[SD_MAX_RANK];
            LongType yIdx[SD_MAX_RANK];

            for (LongType i = threadIdx.x; i < yLength; i += blockDim.x) {
              shape::index2coords(i, currentTad, yIdx);
              shape::index2coords(i, zTadShape, zIdx);

              auto yOffset = shape::getOffset(currentTad, yIdx);
              auto resultOffset = shape::getOffset(zTadShape, zIdx);

              resultTAD[resultOffset] = dataTAD[yOffset];
            }
          }
        }
        __syncthreads();
      }
    }
    __syncthreads();
  }
}

///////////////////////////////////////////////////////////////////////
template <typename T>
SD_KERNEL void execConcatKernel(int numArrays, Pointer *data, Pointer *inputShapeInfos, void *vz, LongType *zShapeInfo,
                                Pointer *tadPointers, Pointer *offsetPointers, LongType *zTadShape,
                                LongType *zOffsets) {
  concatKernel<T>(numArrays, data, inputShapeInfos, vz, zShapeInfo, tadPointers, offsetPointers, zTadShape, zOffsets);

}

///////////////////////////////////////////////////////////////////////
template <typename T>
SD_HOST void concatKernelGeneric(dim3 &launchDims, cudaStream_t *stream, int numArrays, Pointer *data,
                                 Pointer *inputShapeInfos, void *vz, LongType *zShapeInfo, Pointer *tadPointers,
                                 Pointer *offsetPointers, LongType *zTadShape, LongType *zOffsets) {
  execConcatKernel<T><<<launchDims.x, launchDims.y, launchDims.z, *stream>>>(
      numArrays, data, inputShapeInfos, vz, zShapeInfo, tadPointers, offsetPointers, zTadShape, zOffsets);
  DebugHelper::checkErrorCode(stream, "concatGenericLegacy(...) failed");
}

BUILD_SINGLE_TEMPLATE(template void concatKernelGeneric,
                      (dim3 & launchDims, cudaStream_t *stream, int numArrays, sd::Pointer *data,
                       sd::Pointer *inputShapeInfos, void *vz, sd::LongType *zShapeInfo, sd::Pointer *tadPointers,
                       sd::Pointer *offsetPointers, sd::LongType *zTadShape, sd::LongType *zOffsets),
                      SD_COMMON_TYPES);
}  // namespace sd
