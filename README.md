# 2EL - 2CL - MEV - Package

This package spins up 2EL nodes (geth) & 2CL nodes (lighthouse) and then spins up MEV infrastructure on top.

## Caveats

1. The code waits for the first epoch before spinning up MEV components
2. Users need to wait for the second epoch (64th slot) to see validators getting registered
3. At the 3rd epoch (96th slot) mev-relay-api will start showing activity
4. At the 4th epoch (128th slot) users will start seeing payloads getting delivered

## Run Instructions

`kurtosis run github.com/kurtosis-tech/2-el-cl-mev-package`