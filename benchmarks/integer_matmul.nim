import os, strutils, random
import ../src/arraymancer

proc matgen(n: int): auto =
    result = randomTensor(n,n, 100)

var n = 100
if paramCount()>0:
    n = parseInt(paramStr(1))
n = n div 2 * 2

let a, b = matgen n
let c = a * b

echo $c[n div 2, n div 2]
