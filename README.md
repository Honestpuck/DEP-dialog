# DEP-dialog

This is a  hack of Dan K. Snelson's Setup-Your-Mac dialog script project.
I have kept his README and named it DANS-README.md to make it
perfectly clear that most of the code is his and all the errors are mine.

 I've thrown out his welcome screen  since that was easier than making it 
 optional at one clock in the morning and I don't want it for my current project. 
 It will probably get added back eventually. The biggest change is I have  
 developed a method for populating the array of dialog steps. In the directory
"snippets" you will find small text files that each define one item in the array. 
 
 Write a text file containing the list of items you want from the snippets
directory and run  `snippets.py`.  A script is created called 
`DEP-dialog.zsh` that runs `dialog` with a list of enrolment steps and
a nice display.

The default name for the text file is `snippets.txt` but you can use another 
name and specify it on the command line to `snippets.py`.

If you use a different name for the file such as "Jemix" then the name of the
script becomes `DEP-dialog-<filename>.zsh` or, in our example,
`DEP-dialog-Jemix.zsh`.

This system was put together so if you are a large organisation with multiple
offices or an MSP with multiple customers you can quickly generate a script
without the errors of cut and paste since you only need to check a snippet is
valid once. I don't know how Jamf might feel about the icon hashes in this
repo so I have only included 4 snippets for your testing.

Most of this was put together over a single late night so as well as thanking
the below for parts of the code:

```
Adam Codega
Dan K. Snelson
Bart Reardon
James White
```

I would also like to thank [SBS Australia's
Tour De France coverage](https://www.sbs.com.au/sport/tour-de-france) and the
 incredibly performance of Barguil, Vingegaard, Bardet, Quintana, Yates, and 
 Thomas on Stage 11 of the 2022 race as they climbed the Col du Gabilier and 
 the Col du Granon. It kept me up and awake to write this code.
