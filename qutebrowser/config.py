config.load_autoconfig()

config.source('nord-qutebrowser.py')

padding = 8
c.tabs.padding = { 
    "bottom": padding,
    "top": padding,
    "left": padding,
    "right": padding,
}
config.bind('<Alt-h>', 'tab-prev')
config.bind('<Alt-l>', 'tab-next')
config.bind('<Shift-j>', 'tab-prev')
config.bind('<Shift-k>', 'tab-next')
config.bind('x', 'tab-close')
config.bind('d', 'scroll-page 0 1')
config.bind('u', 'scroll-page 0 -1')
config.bind('<Cmd-Shift-t>', 'undo')

c.scrolling.smooth = False
c.url.searchengines = {"DEFAULT": "https://www.google.com/search?q={}"}
c.url.start_pages = "https://www.google.com/"

