# Copyright 2017 Mamy André-Ratsimbazafy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

proc transpose*(t: Tensor): Tensor {.noSideEffect.}=
    ## Transpose a Tensor. For N-d Tensor with shape (0, 1, 2 ... n-1)
    ## the resulting tensor will have dimensions (n-1, ... 2, 1, 0)
    ## Data is copied as is and not modified.

    # First convert the offset pointer back to index
    let offset_idx = t.offset_to_index

    result.dimensions = t.dimensions.reversed
    result.strides = t.strides.reversed
    result.data = t.data

    ptrMath:
        result.offset = addr(result.data[0]) + offset_idx