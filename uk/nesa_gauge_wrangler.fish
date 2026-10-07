#!/usr/bin/env fish

mkdir -p nesa_wrangled

set regions (ls nesa_ocr/**.tsv | cut -d'/' -f-3 | sort | grep -v 'archive' | uniq)
for region in $regions
    set matches
    for f in $region/*.tsv
        if head -n 1 $f | grep -q W7
            set matches $matches $f
        end
    end
    if test (count $matches) -gt 0
        set region_name (string replace -r '^nesa_ocr/' '' -- $region | string replace -r '/tsv$' '')
        string upper (head -n 1 $matches[1]) > nesa_wrangled/$region_name.tsv
        for f in $matches
            tail -n +2 $f >> nesa_wrangled/$region_name.tsv
        end
    end
end

# Convert the merged TSV tables to CSV.
cd nesa_wrangled
for f in *.tsv
    qsv fixlengths $f > (basename $f .tsv).csv
end
