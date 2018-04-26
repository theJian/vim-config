" Vim syntax file
" Language: javascript.jsx
" Maintainer: theJian <thejianmail@gmail.com>

if exists("b:current_syntax") && b:current_syntax == "javascript.jsx"
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

" <tag id="sample">
syntax region jsxTag
    \ matchgroup=jsxTag start=+<[^ }/!?<>"'=:]\@=+
    \ matchgroup=jsxTag end=+\/\?>+
    \ contained
    \ contains=jsxTagName,jsxAttrib,jsxEqual,jsxString,jsxEscapeJsAttributes

" </tag>
syntax match jsxEndTag
    \ +</[^ /!?<>"']\+>+
    \ contained
    \ contains=jsxEndString

" <tag/>
syntax match jsxSelfClosingTag +<[^ /!?<>"'=:]\+\%(\%(=>\|[>]\@!\_.\)\)\{-}\/>+
    \ contained
    \ contains=jsxTag,@Spell
    \ transparent

" <tag></tag>
syntax region jsxRegion
    \ start=+\%(<\|\w\)\@<!<\z([^ /!?<>"'=:]\+\)+
    \ skip=+<!--\_.\{-}-->+
    \ end=+</\z1\_s\{-}>+
    \ end=+/>+
    \ fold
    \ contains=jsxSelfClosingTag,jsxRegion,jsxTag,jsxEndTag,jsxComment,jsxEntity,jsxEscapeJsContent,jsxString,@Spell
    \ keepend
    \ extend

syntax match jsxEndString
    \ +\w\++
    \ contained

" <!-- -->
syntax match jsxComment /<!--\_.\{-}-->/ display

syntax match jsxEntity "&[^; \t]*;" contains=jsxEntityPunct
syntax match jsxEntityPunct contained "[&.;]"

" <tag key={this.props.key}>
"  ^^^
syntax match jsxTagName
    \ +[<]\@<=[^ /!?<>"']\++
    \ contained
    \ display

" <tag key={this.props.key}>
"      ^^^
syntax match jsxAttrib
    \ +[-'"<]\@<!\<[a-zA-Z:_][-.0-9a-zA-Z0-9:_]*\>\(['">]\@!\|\>\|$\)+
    \ contained
    \ contains=jsxAttribPunct,jsxAttribHook
    \ display

syntax match jsxAttribPunct +[:.]+ contained display

" <tag id="sample">
"        ^
syntax match jsxEqual +=+ contained display

" <tag id="sample">
"          ^^^^^^
syntax region jsxString contained start=+"+ end=+"+ contains=jsxEntity,@Spell display

" <tag id='sample'>
"          ^^^^^^
syntax region jsxString contained start=+'+ end=+'+ contains=jsxEntity,@Spell display

" <tag key={this.props.key}>
"           ^^^^^^^^^^^^^^
syntax region jsxEscapeJsAttributes matchgroup=jsxAttributeBraces
    \ contained
    \ start=+{+
    \ end=+}\ze\%(\/\|\n\|\s\|<\|>\)+
    \ contains=TOP
    \ keepend
    \ extend

" <tag>{content}</tag>
"       ^^^^^^^
syntax region jsxEscapeJsContent matchgroup=jsxContentBraces
    \ contained
    \ start=+{+
    \ end=+}+
    \ contains=TOP
    \ keepend
    \ extend

syntax match jsxIfOperator +?+
syntax match jsxElseOperator +:+

syntax cluster jsExpression add=jsxRegion,jsxSelfClosingTag

highlight def link jsxString String
highlight def link jsxNameSpace Function
highlight def link jsxComment Error
highlight def link jsxEscapeJsAttributes jsxEscapeJsAttributes

if hlexists('htmlTag')
    highlight def link jsxTagName htmlTagName
    highlight def link jsxEqual htmlTag
    highlight def link jsxAttrib htmlArg
    highlight def link jsxTag htmlTag
    highlight def link jsxEndTag htmlTag
    highlight def link jsxEndString htmlTagName
    highlight def link jsxAttributeBraces htmlTag
else
    highlight def link jsxTagName Statement
    highlight def link jsxEndString Statement
    highlight def link jsxEqual Function
    highlight def link jsxTag Function
    highlight def link jsxEndTag Function
    highlight def link jsxAttrib Type
    highlight def link jsxAttributeBraces Special
endif

let b:current_syntax = 'javascript.jsx'
let &cpo = s:cpo_save
unlet s:cpo_save
