if exists('current_compiler')
    finish
endif
let current_compiler = 'typescript'

CompilerSet makeprg=tsc\ $*\ --outDir\ build\ %
CompilerSet errorformat=%+A\ %#%f\ %#(%l\\\,%c):\ %m,%C%m
