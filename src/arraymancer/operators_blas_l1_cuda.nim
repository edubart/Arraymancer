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

# ####################################################################
# Helper proc

template cudaVV_A_eq_A_p_bB[T: SomeReal](
  a: var CudaTensor[T], beta: T, b: CudaTensor[T]) =
  # Vector: A = A + beta B

  # We need to pass an address to CuBLAS for beta
  # If the input is not a variable but a float directly
  # It won't have an address and can't be used by CUBLAS
  let be = beta

  check cublas_axpy(a.shape[0],
             unsafeAddr(be),
             b.get_data_ptr, b.strides[0],
             a.get_data_ptr, a.strides[0])

template cudaVV_C_eq_A_p_bB[T: SomeReal](a: CudaTensor,
                                         beta: T, b,
                                         result: CudaTensor[T]) =
  # Vector: C = A + beta B
  result = newCudaTensor[T](a.shape)

  check cublas_copy(a.len, a.get_data_ptr, a.strides[0],
                    result.get_data_ptr, result.strides[0])

  cudaVV_A_eq_A_p_bB(result, beta, b)

template cudaMM_A_eq_aA_p_bB[T: SomeReal](
  alpha: T, a: var CudaTensor[T],
  beta: T, b: CudaTensor[T]) =
  # Matrix: A = alpha A + beta B

  # TODO: remove this contiguous layout constraint (via conversion or custom kernel)
  if not (isContiguous(a) and isContiguous(b)):
    raise newException(ValueError, "NotImplemented: for now both tensors should be contiguous")

  if not is_F_contiguous(a):
    raise newException(ValueError, "NotImplemented: the modified tensor must have a column-major layout")

  let transpose_B = if is_F_contiguous(b): CUBLAS_OP_N
                    else: CUBLAS_OP_T
  let ld_B = if is_F_contiguous(b): b.strides[1]
             else: b.strides[0]

  # We need to pass an address to CuBLAS for alpha
  # If the input is not a variable but a float directly
  # It won't have an address and can't be used by CUBLAS
  let
    al = alpha
    be = beta

  check cublas_geam(CUBLAS_OP_N, transpose_B,
                    a.shape[0], a.shape[1],
                    unsafeAddr(al),
                    a.get_data_ptr, a.strides[1],
                    unsafeAddr(be),
                    b.get_data_ptr, ld_B,
                    a.get_data_ptr, a.strides[1])
  # In column-majour layout a.shape[0] == a.strides[1]

template cudaMM_C_eq_aA_p_aB[T: SomeReal](alpha: T, a: CudaTensor[T],
                                          beta: T, b: CudaTensor[T],
                                          result: CudaTensor[T]) =
  # TODO: remove this contiguous layout constraint (via conversion or custom kernel)
  if not (isContiguous(a) and isContiguous(b)):
    raise newException(ValueError, "NotImplemented: for now both tensors should be contiguous")

  result = newCudaTensor[T](a.shape) # result is colMajor

  let
    al = alpha
    be = beta

  let
    transpose_A = if is_F_contiguous(a): CUBLAS_OP_N
                  else: CUBLAS_OP_T
    ld_A = if is_F_contiguous(a): a.strides[1]
           else: a.strides[0]

    transpose_B = if is_F_contiguous(b): CUBLAS_OP_N
                  else: CUBLAS_OP_T
    ld_B = if is_F_contiguous(b): b.strides[1]
           else: b.strides[0]

  check cublas_geam(transpose_A, transpose_B,
                    a.shape[0], a.shape[1],
                    unsafeAddr(al),
                    a.get_data_ptr, ld_A,
                    unsafeAddr(be),
                    b.get_data_ptr, ld_B,
                    result.get_data_ptr, result.strides[1])

# ####################################################################
# BLAS Level 1 (Vector dot product, Addition, Scalar to Vector/Matrix)

proc `.*`*[T: SomeReal](a, b: CudaTensor[T]): T {.inline.}=
  ## Vector to Vector dot (scalar) product
  when compileOption("boundChecks"): check_dot_prod(a,b)
  check cublas_dot( a.shape[0],
                    a.get_data_ptr, a.strides[0],
                    b.get_data_ptr, b.strides[0],
                    addr result)

proc `+=`*[T: SomeReal](a: var CudaTensor[T], b: CudaTensor[T]) =
  ## Tensor in-place addition
  ## Only Vector-Vector and Matrix-Matrix addition are supported for now.
  ## For Matrix-Matrix, both matrices must have a contiguous layout.

  when compileOption("boundChecks"): check_add(a,b)

  if a.rank == 1:
    cudaVV_A_eq_A_p_bB(a, 1.T, b)
  elif a.rank == 2:
    cudaMM_A_eq_aA_p_bB(1.T, a, 1.T, b)
  else:
    raise newException(ValueError, "NotImplemented: Tensor addition is not implemented for 3D+ tensors")

  # TODO: if a and b share the same location, copy a to a new location
  # a += transpose(a) fails with CUBLAS ERROR 7.

proc `+`*[T: SomeReal](a,b: CudaTensor[T]): CudaTensor[T] =
  ## Tensor addition
  ## Only Vector-Vector and Matrix-Matrix addition are supported for now
  ## For Matrix-Matrix, both matrices must have a contiguous layout.

  when compileOption("boundChecks"): check_add(a,b)

  if a.rank == 1:
    cudaVV_C_eq_A_p_bB(a, 1.T, b, result)
  elif a.rank == 2:
    cudaMM_C_eq_aA_p_aB(1.T, a, 1.T, b, result)
  else:
    raise newException(ValueError, "NotImplemented: Tensor addition is not implemented for 3D+ tensors")


proc `-=`*[T: SomeReal](a: var CudaTensor[T], b: CudaTensor[T]) =
  ## Tensor in-place substraction
  ## Only Vector-Vector and Matrix-Matrix addition are supported for now.
  ## For Matrix-Matrix, both matrices must have a contiguous layout.

  when compileOption("boundChecks"): check_add(a,b)

  if a.rank == 1:
    cudaVV_A_eq_A_p_bB(a, -1.T, b)
  elif a.rank == 2:
    cudaMM_A_eq_aA_p_bB(1.T, a, -1.T, b)
  else:
    raise newException(ValueError, "NotImplemented: Tensor addition is not implemented for 3D+ tensors")

  # TODO: if a and b share the same location, copy a to a new location
  # a -= transpose(a) fails with CUBLAS ERROR 7.

proc `-`*[T: SomeReal](a,b: CudaTensor[T]): CudaTensor[T] =
  ## Tensor substraction
  ## Only Vector-Vector and Matrix-Matrix addition are supported for now
  ## For Matrix-Matrix, both matrices must have a contiguous layout.

  when compileOption("boundChecks"): check_add(a,b)

  if a.rank == 1:
    cudaVV_C_eq_A_p_bB(a, -1.T, b, result)
  elif a.rank == 2:
    cudaMM_C_eq_aA_p_aB(1.T, a, -1.T, b, result)
  else:
    raise newException(ValueError, "NotImplemented: Tensor addition is not implemented for 3D+ tensors")

proc `*=`*[T:SomeReal](t: var CudaTensor[T]; a: T) {.inline.}=
  ## Tensor inplace multiplication by a scalar

  let alpha = a # We need an pointer/address, if is a value it wouldn't have one

  # We multiply all elements of the CudaTensor regardless of shape/strides
  # So this operation can be applied to tensors of all ranks.
  # Hence we use the whole allocated length and a stride of 1
  check cublas_scal(t.len, unsafeAddr(alpha), t.get_data_ptr, 1)

proc `*`*[T:SomeReal](a: T, t: CudaTensor[T]): CudaTensor[T] {.inline.}=
  ## Tensor multiplication by a scalar

  result = t.clone()
  result *= a

proc `*`*[T:SomeReal](t: CudaTensor[T], a: T): CudaTensor[T] {.inline.}=
  ## Tensor multiplication by a scalar
  a * t

proc `/=`*[T:SomeReal](t: var CudaTensor[T]; a: T) {.inline.}=
  ## Tensor in-place division by a scalar
  t *= (1/a)

proc `/`*[T:SomeReal](t: CudaTensor[T], a: T): CudaTensor[T] {.inline.}=
  ## Tensor division by a scalar
  (1/a) * t

proc `/`*[T:SomeReal](a: T, t: CudaTensor[T]): CudaTensor[T] {.inline.}=
  ## Tensor division by a scalar
  (1/a) * t