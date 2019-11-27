#!/usr/bin/env bash
ln -s `pwd` $HOME/.config/nvim

curl https://raw.githubusercontent.com/theJian/packman.lua/master/packman.lua -o $HOME/.config/nvim/lua/packman.lua
