---
layout: page
title: Filters › date
---

[← filters](./../filters.md)

<!-- {% raw %} -->

Filter `date(format)`:
* `format`: The date format

---

Parsing
-------

Value must have number/words representing date and/or time. 
Use commas and spaces as delimiters. 
The stated day of the week is ignored whether its correct or not. A string containing an invalid date is an error. 
For example, a string containing two years or two months is an error. 
Time must be supplied if date is not given, vice versa.

**Time Format.**  Hours, minutes, and seconds are separated by colons, although all need not be specified. 
"10:11", and "10:11:12" are all valid. 
If the 24-hour clock is used, it is an error to specify "PM" for times later than 12 noon. 
For example, "23:15 PM" is an error.

**Time Zone Format.**  First character is a sign "+" (east of UTC) or "-" (west of UTC). 
Hours and minutes offset are separated by colons.
Another format is `[sign][number]`. If `[number]` is less than 24, it is the offset in hours e.g. "-10" = -10 hours. 
Otherwise it is the offset in houndred hours e.g. "+75" = "+115" = +1.25 hours.

**Supported Format.**

* `YYYY-MM-DD`, `MM/DD/YYYY`, `MMMM DD YYYY`, `DD MMMM YYYY` — where YYYY is the year, MM is the month of the year, MMMM is the month full name or abbr, and DD is the day of the month ("2000-12-31", "20001231").
* `DATE HH:MM:SS` — Where DATE is the date format discuss above, HH is the hour, 
  MM is the miute, SS is the seconds ("1995-02-04 24:00:51", "1976-W01-1 12:12:12.123").
* `DATE TIME +HH:MM`, `DATE TIME -HHMM`, `DATE TIME UTC`

[Add your date formats](./../api.md#date-parser).

**Parsable month value.**

If a function needs a month value it must be a string or a number. 
If the month is a string, it must be the name of the month full or abbreviated. 
If the month is a number, that number must be 1-12 (January-December).

[Add localization of months](./../api.md#date-localization).

Formatting
----------

The `format` string follows the same rules as the `strftime` standard C function.

| Spec | Description | Examples |
|------|-------------|----------|
| **Day**  | | |
| `%a` | Abbreviated weekday name | `Sun`, `Mon` |
| `%A` | Full weekday name | `Sunday` |
| `%d` | The day of the month as a number (range 1 - 31) | `1`, `28` |
| `%j` | The day of the year as a number (001 - 366) | `052`, `230` |
| `%u` | ISO 8601 day of the week, to 7 for Sunday | `7`, `1` |
| `%w` | The day of the week as a decimal, Sunday being 0 | `1` |
| **Week** | | |
| `%U` | Sunday week of the year, from 00 | `48` |
| `%V` | ISO 8601 week of the year, from 01 | `48` |
| `%W` | Monday week of the year, from 00  | `48` |
| **Month** | | |
| `%b` | Abbreviated month name | `Dec`, `Jan` |
| `%B` | Full month name | `December` |
| `%m` | Month of the year, from 01 to 12 | `05`, `11` |
| **Year** | | |
| `%C` | Two digit representation of the century | `19`, `20`, `30` |
| `%g` | year for ISO 8601 week, from 00 | `79` |
| `%G` | year for ISO 8601 week, from 0000 | `1979` |
| `%y` | Two digit representation of the year | `00`, `25` |
| `%Y` | Four digit representation for the year | `2000`, `0325` |
| **Time** | | |
| `%H` | hour of the 24-hour day, from 00 | `06` |
| `%I` | The hour as a number using a 12-hour clock (01 - 12) | `02`, `10` |
| `%M` | Minutes after the hour | `55` |
| `%p` | AM/PM indicator | `AM`, `PM` |
| `%s` | Unix Epoch Time timestamp  | `305815200`, `1234567890` |
| `%S` | The second as a number | `59`, `20`, `01` |
| `%z` | Time zone offset as 'big number' | `+1000`, `-0230` |
| `%Z` | Time zone offset as 'short number' | `+3`, `+1:30` |
| **Misc** | | |
| `%%` | percent character | `%` |
| `%n` | A newline character (`\n`) |  |
| `%t` | A Tab character (`\t`) |  |

**Aliases**:
 
| Spec | Description | Format | Example |
|------|-------------|--------|---------|
| `$c` | Preferred date | `%a %b %d %H:%m%s %Y` | `Tue Jun 23 15:45:01 2020` |
| `$r` | 12-hour time, from 01:00:00 AM | `%I:%M:%S %p` | `06:55:15 AM` |
| `$R` | 12-hour:minute, from 01:00 | `%I:%M` | `06:55` |
| `$T` | 24-hour time, from 00:00:00 | `%H:%M:%S` | `06:55:15` |
| `$D` | month/day/year from 01/01/00 | `%m/%d/%y` | `12/02/79` |
| `$F` | year-month-day | `%Y-%m-%d` | `1979-12-02` |

[Add more aliases](./dev/date.md#aliases)
<!-- {% endraw %} -->