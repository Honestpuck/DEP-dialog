#!/usr/bin/env python3
#
# Part of  DEP-dialog
#
# tonyw@honestpuck.com 2022-07-14

import sys
import os

# Variables
script = "./DEP-dialog"
if len(sys.argv) >= 2:
    snippet_list_file = sys.argv[1]
    script = script + "-" + snippet_list_file + ".zsh"
else:
    snippet_list_file = "snippets.txt"
    script = script + ".zsh"
snippet_directory = "./snippets"
template = "./template.zsh"

# load the list of snippets
with open(snippet_list_file) as my_file:
    snippet_list = my_file.readlines()

# do our worst
with open(template, "r") as template_read, open(script, "w") as shellscript:
    for line in template_read:
        if "###SNIPPETS###" in line:
            # write snippets
            for snippet in snippet_list:
                snippet = snippet.strip()
                snippet_file = f"{snippet_directory}/{snippet}.json"
                with open(snippet_file, "r") as snippet_txt:
                    shellscript.write(snippet_txt.read())
        else:
            # append content to second file
            shellscript.write(line)

# we might want to run this script from the command line for testing
os.chmod(script, 0o755)
