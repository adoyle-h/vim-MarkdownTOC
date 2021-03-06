if exists("g:loaded_MarkdownTocPlugin")
    finish
endif
let g:loaded_MarkdownTocPlugin = 1

if !exists("g:vmt_depth")
    let g:vmt_depth = 999
endif

if !exists("g:vmt_indent")
    let g:vmt_indent = repeat(' ', 4)
endif

if !exists("g:vmt_style")
    let g:vmt_style = 'default'
endif

if !exists("g:vmt_signature")
    let g:vmt_signature = 'MarkdownTOC'
endif

if !exists("g:vmt_auto_update_on_save")
    let g:vmt_auto_update_on_save = 1
endif

if !exists("g:vmt_dont_insert_fence")
    let g:vmt_dont_insert_fence = 0
endif

let g:GFMHeadingIds = {}

function! s:HeadingLineRegex()
    return '\v(^.+$\n^\=+$|^.+$\n^\-+$|^#{1,6})'
endfunction

function! s:GetSections(beginRegex, endRegex)
    let l:winview = winsaveview()
    let l:sections = {}

    normal! gg
    let l:flags = "Wc"
    let l:beginLine = 0
    let l:regex = a:beginRegex
    while search(l:regex, l:flags)
        let l:lineNum = line(".")
        if l:beginLine == 0
            let l:beginLine = l:lineNum
            let l:regex = a:endRegex
        else
            let l:sections[l:beginLine] = l:lineNum
            let l:beginLine = 0
            let l:regex = a:beginRegex
        endif
        let l:flags = "W"
    endwhile

    call winrestview(l:winview)

    return l:sections
endfunction

function! s:GetCodeSections()
    let l:codeSections = {}

    call extend(l:codeSections, <SID>GetSections("^```", "^```"))
    call extend(l:codeSections, <SID>GetSections("^{% highlight", "^{% endhighlight"))

    return l:codeSections
endfunction

function! s:IsLineInCodeSections(codeSections, lineNum)
    for beginLine in keys(a:codeSections)
        if a:lineNum >= str2nr(beginLine)
            if a:lineNum <= a:codeSections[beginLine]
                return 1
            endif
        endif
    endfor

    return 0
endfunction

function! s:GetHeadingLines()
    let l:winview = winsaveview()
    let l:headingLines = []
    let l:codeSections = <SID>GetCodeSections()

    let l:headingLineRegex = <SID>HeadingLineRegex()
    let l:flags = "W"

    while search(l:headingLineRegex, l:flags) != 0
        let l:line = getline(".")
        let l:lineNum = line(".")
        if <SID>IsLineInCodeSections(l:codeSections, l:lineNum) == 0
            " === compatible with Setext Style headings
            let l:nextLine = getline(l:lineNum + 1)
            if matchstr(l:nextLine, '\v^\=+$') != ""
                let l:line = "# " . l:line
            elseif matchstr(l:nextLine, '\v^\-+$') != ""
                let l:line = "## " . l:line
            endif
            " ===

            call add(l:headingLines, l:line)
        endif
    endwhile

    call winrestview(l:winview)

    return l:headingLines
endfunction

function! s:GetHeadingLevel(headingLine)
    return match(a:headingLine, '[^#]')
endfunction

function! s:GetHeadingLinkGFM(headingName)
    let l:headingLink = tolower(a:headingName)

    let l:headingLink = substitute(l:headingLink, "\\%^_\\+\\|_\\+\\%$", "", "g")
    let l:headingLink = substitute(l:headingLink, "\\%#=0[^[:alnum:]\u4e00-\u9fbf _-]", "", "g")
    let l:headingLink = substitute(l:headingLink, " ", "-", "g")

    if l:headingLink ==# ""
        let l:nullKey = "<null>"
        if has_key(g:GFMHeadingIds, l:nullKey)
            let g:GFMHeadingIds[l:nullKey] += 1
            let l:headingLink = l:headingLink . "-" . g:GFMHeadingIds[l:nullKey]
        else
            let g:GFMHeadingIds[l:nullKey] = 0
        endif
    elseif has_key(g:GFMHeadingIds, l:headingLink)
        let g:GFMHeadingIds[l:headingLink] += 1
        let l:headingLink = l:headingLink . "-" . g:GFMHeadingIds[l:headingLink]
    else
        let g:GFMHeadingIds[l:headingLink] = 0
    endif

    return l:headingLink
endfunction

function! s:GetHeadingLinkRedcarpet(headingName)
    let l:headingLink = tolower(a:headingName)

    let l:headingLink = substitute(l:headingLink, "<[^>]\\+>", "", "g")
    let l:headingLink = substitute(l:headingLink, "&", "&amp;", "g")
    let l:headingLink = substitute(l:headingLink, "\"", "&quot;", "g")
    let l:headingLink = substitute(l:headingLink, "'", "&#39;", "g")

    let l:headingLink = substitute(l:headingLink, "[ \\-&+\\$,/:;=?@\"#{}|\\^\\~\\[\\]`\\*()%.!']\\+", "-", "g")
    let l:headingLink = substitute(l:headingLink, "-\\{2,}", "-", "g")
    let l:headingLink = substitute(l:headingLink, "\\%^[\\-_]\\+\\|[\\-_]\\+\\%$", "", "g")

    return l:headingLink
endfunction

function! s:GetHeadingName(headingLine)
    let l:headingName = substitute(a:headingLine, '^#*\s*', "", "")
    let l:headingName = substitute(l:headingName, '\s*#*$', "", "")

    let l:headingName = substitute(l:headingName, '\[\([^\[\]]*\)\]([^()]*)', '\1', "g")
    let l:headingName = substitute(l:headingName, '\[\([^\[\]]*\)\]\[[^\[\]]*\]', '\1', "g")

    return l:headingName
endfunction

function! s:GetHeadingLink(headingName, markdownStyle)
    if a:markdownStyle ==# "GFM"
        return <SID>GetHeadingLinkGFM(a:headingName)
    elseif a:markdownStyle ==# "Redcarpet"
        return <SID>GetHeadingLinkRedcarpet(a:headingName)
    endif
endfunction

function! GetHeadingLinkTest(headingLine, markdownStyle)
    let l:headingName = <SID>GetHeadingName(a:headingLine)
    return <SID>GetHeadingLink(l:headingName, a:markdownStyle)
endfunction

function! s:parseMarkdownConfig(list)
    let l:markdownConfig = {}

    for a in a:list
        let l:s = split(a, '=')
        if len(l:s) == 1
            let l:markdownConfig[l:s[0]] = v:true
        else
            let l:markdownConfig[l:s[0]] = l:s[1]
        endif
    endfor

    return l:markdownConfig
endfunction

function! s:listMarkdownConfig(config)
    let l:list = []
    for [key, value] in items(a:config)
        if value == v:true
            call add(l:list, key)
        else
            call add(l:list, key . '=' . value)
        endif
    endfor
    return l:list
endfunction

function! s:GetStyleFromConfig(markdownConfig)
    if get(a:markdownConfig, 'GFM') == v:true
        let l:markdownStyle = 'GFM'
    elseif get(a:markdownConfig, 'Redcarpet') == v:true
        let l:markdownStyle = 'Redcarpet'
    else
        let l:markdownStyle = ''
    end
    return l:markdownStyle
endfunction

function! s:GenToc(markdownConfig)
    let l:markdownConfig = a:markdownConfig
    let l:markdownStyle = s:GetStyleFromConfig(l:markdownConfig)

    if (l:markdownStyle != 'GFM' && l:markdownStyle != 'Redcarpet')
        let l:markdownStyle = 'GFM'
        let l:markdownConfig['GFM'] = v:true
    endif

    let l:depth = has_key(l:markdownConfig, 'depth') ? get(l:markdownConfig, 'depth') : g:vmt_depth
    let l:style = has_key(l:markdownConfig, 'style') ? get(l:markdownConfig, 'style') : g:vmt_style

    let l:headingLines = <SID>GetHeadingLines()
    let l:levels = []

    let g:GFMHeadingIds = {}

    for headingLine in l:headingLines
        call add(l:levels, <SID>GetHeadingLevel(headingLine))
    endfor

    let l:minLevel = min(l:levels)

    if g:vmt_dont_insert_fence == 0
        silent put =<SID>GetBeginFence(l:markdownConfig)
        " a blank line before TOC content
        silent put =''
    endif

    let l:i = 0
    let l:orders = {}
    for headingLine in l:headingLines
        let l:headingIndents = l:levels[i] - l:minLevel
        if (l:headingIndents >= l:depth)
            let l:i += 1
            continue
        endif

        let l:headingName = <SID>GetHeadingName(headingLine)
        let l:headingLink = <SID>GetHeadingLink(l:headingName, l:markdownStyle)

        let l:heading = s:GetIndentText(l:headingIndents)

        if (l:style == 'ordered')
            if (!has_key(l:orders, l:headingIndents))
                let l:orders[l:headingIndents] = 1
            endif
            let l:vmt_style_symbol = l:orders[l:headingIndents] . '.'
            let l:orders[l:headingIndents] += 1
        elseif (l:style == 'unordered')
            let l:vmt_style_symbol = '-'
        else
            let l:vmt_style_symbol = '*'
        endif

        let l:heading = l:heading . l:vmt_style_symbol . " [" . l:headingName . "]"
        let l:heading = l:heading . "(#" . l:headingLink . ")"

        silent put =l:heading

        let l:i += 1
    endfor

    " a blank line after toc to avoid effect typo of content below
    silent put =''

    if g:vmt_dont_insert_fence == 0
        silent put =<SID>GetEndFence()
    endif
endfunction

function! s:GetIndentText(indent)
    return repeat(g:vmt_indent, a:indent)
endfunction

function! s:GetBeginFence(markdownConfig)
    let l:list = s:listMarkdownConfig(a:markdownConfig)
    return "<!-- " . g:vmt_signature . " " . join(l:list, ' ') . " -->"
endfunction

function! s:GetEndFence()
    return "<!-- /" . g:vmt_signature . " -->"
endfunction

function! s:GetBeginFencePattern()
    return '<!-- ' . g:vmt_signature . '\([a-zA-Z0-9=* ]\+\)* -->'
endfunction

function! s:GetEndFencePattern()
    return <SID>GetEndFence()
endfunction

function! s:UpdateToc()
    let l:winview = winsaveview()
    let l:tocBeginPattern = <SID>GetBeginFencePattern()

    normal! gg
    if search(l:tocBeginPattern, "Wc") == 0
        call winrestview(l:winview)
        return
    endif
    call winrestview(l:winview)

    let l:totalLineNum = line("$")

    let [l:markdownConfig, l:beginLineNumber, l:endLineNumber] = <SID>DeleteExistingToc()

    let l:markdownStyle = s:GetStyleFromConfig(l:markdownConfig)

    let l:isFirstLine = (l:beginLineNumber == 1)
    if l:beginLineNumber > 1
        let l:beginLineNumber -= 1
    endif

    if l:isFirstLine != 0
        call cursor(l:beginLineNumber, 1)
        silent put! =''
    endif

    call cursor(l:beginLineNumber, 1)
    call <SID>GenToc(l:markdownConfig)

    if l:isFirstLine != 0
        call cursor(l:beginLineNumber, 1)
        normal! dd
    endif

    " fix line number to avoid shake
    if l:winview['lnum'] > l:endLineNumber
        let l:diff = line("$") - l:totalLineNum
        let l:winview['lnum'] += l:diff
        let l:winview['topline'] += l:diff
    endif

    call winrestview(l:winview)
endfunction

function! s:DeleteExistingToc()
    let l:winview = winsaveview()

    normal! gg

    let l:tocBeginPattern = <SID>GetBeginFencePattern()
    let l:tocEndPattern = <SID>GetEndFencePattern()

    let l:beginLineNumber = -1
    let l:endLineNumber= -1

    let l:flags = "Wc"
    let l:markdownConfig = {}
    if search(l:tocBeginPattern, l:flags) != 0
        let l:beginLine = getline(".")
        let l:beginLineNumber = line(".")
        let l:matches = matchlist(l:beginLine, l:tocBeginPattern)[1]
        let l:markdownConfig = s:parseMarkdownConfig(split(l:matches, ' '))

        if search(l:tocEndPattern, l:flags) != 0
            let l:endLineNumber = line(".")
            execute l:beginLineNumber . "," . l:endLineNumber . "delete _"
        else
            echoe "Cannot find toc end fence. tocEndPattern: " . l:tocEndPattern
        endif
    else
        echoe "Cannot find toc begin fence. tocBeginPattern: " . l:tocBeginPattern
    endif

    call winrestview(l:winview)

    return [l:markdownConfig, l:beginLineNumber, l:endLineNumber]
endfunction

command! GenTocGFM :call <SID>GenToc({"GFM": v:true})
command! GenTocRedcarpet :call <SID>GenToc({"Redcarpet": v:true})
command! UpdateToc :call <SID>UpdateToc()
command! TocInsert :call <SID>GenToc({"GFM": v:true})
command! TocUpdate :call <SID>UpdateToc()

if g:vmt_auto_update_on_save == 1
    autocmd BufWritePre *.{md,mdown,mkd,mkdn,markdown,mdwn} :silent UpdateToc
endif
