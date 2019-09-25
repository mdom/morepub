[![Build Status](https://travis-ci.org/mdom/morepub.svg?branch=master)](https://travis-ci.org/mdom/morepub) [![Coverage Status](https://img.shields.io/coveralls/mdom/morepub/master.svg?style=flat)](https://coveralls.io/r/mdom/morepub?branch=master)
# NAME

morepub - minimal epub reader for the terminal

# SYNOPSIS

    morepub EPUB_FILE

# DESCRIPTION

morepub is a basic epub reader, that converts an epub to a single html
document. If the controlly tty is a terminal the documentation is opened
with _lynx(1)_ otherwise it's printed to stdout. All internal links are
preserved.

# COPYRIGHT AND LICENSE 

Copyright 2019 Mario Domgoergen `<mario@domgoergen.com>` 

This program is free software: you can redistribute it and/or modify 
it under the terms of the GNU General Public License as published by 
the Free Software Foundation, either version 3 of the License, or 
(at your option) any later version. 

This program is distributed in the hope that it will be useful, 
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
GNU General Public License for more details. 

You should have received a copy of the GNU General Public License 
along with this program.  If not, see &lt;http://www.gnu.org/licenses/>. 
