# Setup of the Dev Enviroment

These steps were tested on an Ubuntu 24.04 machine.

## Prerequisites

0. Init the git submodule
```shell
git submodule update --init --recursive
```

1. First, install the Nix package manager and add your user to the `nix-users` group (you will have to log out and back in):
```shell
user:~$ sudo apt install nix-bin
user:~$ sudo adduser marton nix-users
```
1. Install the STM32 programmer from here: https://www.st.com/en/development-tools/stm32cubeprog.html#get-software (You will have to log in or create an account.)
Before moving on, make sure that the `STM32_Programmer_CLI` binary is on your path.

1. Open the development enviroment with all the necessary dependencies.

```shell
user:~/artifacts$ nix --extra-experimental-features nix-command --extra-experimental-features flakes develop
```
4. Now you have a shell with all the necessary programs/tools to run the examples. 
