### Package
version       = "0.1.3"
author        = "Mamy André-Ratsimbazafy"
description   = "A n-dimensional tensor (ndarray) library"
license       = "Apache License 2.0"

### Dependencies
requires "nim >= 0.17.2", "nimblas >= 0.1.3", "nimcuda >= 0.1.4"

## Install files
srcDir = "src"

### BLAS support
## OSX
# switch("define","openblas")
# switch("clibdir", "/usr/local/opt/openblas/lib")
# switch("cincludes", "/usr/local/opt/openblas/include")

### BLIS support
# switch("define","blis")

### Compute with full detected optimizations
{.passC: "-march=native".}

## Testing tasks
proc test(name: string) =
  if not dirExists "bin":
    mkDir "bin"
  if not dirExists "nimcache":
    mkDir "nimcache"
  --run
  --nimcache: "nimcache"
  switch("out", ("./bin/" & name))
  setCommand "c", "tests/" & name & ".nim"


task test, "Run all tests - Default BLAS":
  test "all_tests"

task test_cuda, "Run all tests - Cuda backend with CUBLAS":
  switch("cincludes", "/opt/cuda/include")
  test "all_tests_cuda"

task test_deprecated, "Run all tests on deprecated static[Backend] procs":
  test "all_tests_deprecated"

task test_openblas, "Run all tests - OpenBLAS":
  ## Should work but somehow Nim doesn't find libopenblas.dylib on MacOS
  when defined(macosx):
    switch("define","openblas")
    switch("clibdir", "/usr/local/opt/openblas/lib")
    switch("cincludes", "/usr/local/opt/openblas/include")
  test "all_tests"

task test_blis, "Run all tests - BLIS":
  switch("define","blis")
  test "all_tests"