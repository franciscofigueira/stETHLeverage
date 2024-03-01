-include .env

all:  remove install build

# Clean the repo
clean  :; forge clean

remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install:;  forge install foundry-rs/forge-std --no-commit && forge install https://github.com/balancer/balancer-v2-monorepo --no-commit

update:; forge update

build:; forge build

test :; forge test 
