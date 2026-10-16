# Checking a sweep

Read this when one commit renames symbols or swaps a call across many files. Do not read each file by eye: check the sweep mechanically.

## The check

1. Build the **old → new map** from the declarations the commit changes.
2. Run every removed line through the map.
3. Compare the result with the added lines, after dropping whitespace, line rewraps, trailing commas and the order of import specifiers.
4. A file whose every hunk matches is a sweep file: it counts as **follows**, with the declarations as its source.

## Widen the match only by what the sweep did

- **Sorted lines.** A line a sorter moved after its rename (an object key, an import specifier reordered by a lint autofix) counts when the moved lines match as a set.
- **Names shared with built-ins.** A repo symbol that shares its name with a built-in method is mapped where the repo declares it, bare or on the repo's own object, and left alone on built-in calls. Dropping the name from the map instead falsely rejects every file that uses it.
- **Introduced converters.** A call wrapped in a converter the sweep introduced, plus the converter's import, counts once you have read the converter: this is the follows rule applied mechanically. It counts the same way when the file hoists the converted value into one local and uses that local where it used to write the conversion or the raw value. A converter on both sides of a comparison changes what counts as equal, so that file goes in review.
- **Renamed fields.** A field renamed together with every reader of it counts.
- **Split names.** When the sweep split one old name into two new ones by role, try each mapping per file and accept the file when one of them matches.

## Spot-check

Read a few accepted files and the smallest rejected ones by eye. A rejected file with a tiny diff usually means the map is missing a case, not that the file holds a real change.
