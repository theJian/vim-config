if exists('current_compiler')
    finish
endif
let current_compiler = 'go'

CompilerSet makeprg=tsc\ $*\ --outDir\ build\ %
CompilerSet errorformat=%+A\ %#%f\ %#(%l\\\,%c):\ %m,%C%m
