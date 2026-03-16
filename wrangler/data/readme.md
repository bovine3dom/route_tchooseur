# getting data

carefully scroll down and click all the buttons here:

https://data-interop.era.europa.eu/dataset-explorer

good idea to have full disk compression enabled or lots of space - it'll take up a few gigabytes uncompressed

the page needs JS even for clicking the download buttons. i haven't worked out how to automate it

the files themselves are a hodgepodge of zipped, unzipped, missing extensions. make them all be xml

e.g.

```fish
for f in *.zip; 7za e $f; end
rm *.zip
```


# todo

investigate full-etcs-fix... (norway?)
