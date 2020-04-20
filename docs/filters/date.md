Filter `date`
=============

<!-- {% raw %} -->

Filter `date(format)`:
* `format`: The date format

Date filter and function use [date](https://github.com/Tieske/date) package.

Parsing
-------

Value must have number/words representing date and/or time. 
Use commas and spaces as delimiters. 
Strings enclosed by parenthesis is treated as a comment and is ignored, these parentheses may be nested. 
The stated day of the week is ignored whether its correct or not. A string containing an invalid date is an error. 
For example, a string containing two years or two months is an error. 
Time must be supplied if date is not given, vice versa.

**Time Format.**  Hours, minutes, and seconds are separated by colons, although all need not be specified. 
"10:", "10:11", and "10:11:12" are all valid. 
If the 24-hour clock is used, it is an error to specify "PM" for times later than 12 noon. 
For example, "23:15 PM" is an error.

**Time Zone Format.**  First character is a sign "+" (east of UTC) or "-" (west of UTC). 
Hours and minutes offset are separated by colons.
Another format is `[sign][number]`. If `[number]` is less than 24, it is the offset in hours e.g. "-10" = -10 hours. 
Otherwise it is the offset in houndred hours e.g. "+75" = "+115" = +1.25 hours.

**Date Format.**  Short dates can use either a "/" or "-" date separator, but must follow the month/day/year format

**Supported ISO 8601 Formats.**

* YYYY-MM-DD — where YYYY is the year, MM is the month of the year, and DD is the day of the month ("2000-12-31", "20001231").
* YYYY-DDD — where YYYY is the year, DDD is the day of the year ("1995-035", "1995035").
* YYYY-WDD-D — where YYYY is the year, DDD is the day of the year ("1997-W01-1", "1997W017").
* DATE HH:MM:SS.SSS — Where DATE is the date format discuss above, HH is the hour, 
  MM is the miute, SS.SSS is the seconds (fraction is optional) ("1995-02-04 24:00:51.536", "1976-W01-1 12:12:12.123").
* DATE TIME +HH:MM, DATE TIME -HHMM, DATE TIME Z, — 

**Parsable month value.**
If a function needs a month value it must be a string or a number. 
If the month is a string, it must be the name of the month full or abbreviated. 
If the month is a number, that number must be 1-12 (January-December).

| Index | Abbreviation | Full Name |
|-------|--------------|-----------|
|1      | Jan          | January   |
|2      | Feb          | February  |
|3      | Mar          | March     |
|4      | Apr          | April     |
|5      | May          | May       |
|6      | Jun          | June      |
|7      | Jul          | July      |
|8      | Aug          | August    |
|9      | Sep          | September |
|10     | Oct          | October   |
|11     | Nov          | November  |
|12     | Dec          | December  |

Formatting
----------

The `format` string follows the same rules as the `strftime` standard C function.

| Spec | Description |
|------|-------------|
| '%a' | Abbreviated weekday name (Sun) |
| '%A' | Full weekday name (Sunday) |
| '%b' | Abbreviated month name (Dec) |
| '%B' | Full month name (December) |
| '%C' | Year/100 (19, 20, 30) |
| '%d' | The day of the month as a number (range 1 - 31) |
| '%g' | year for ISO 8601 week, from 00 (79) |
| '%G' | year for ISO 8601 week, from 0000 (1979) |
| '%h' | same as %b |
| '%H' | hour of the 24-hour day, from 00 (06) |
| '%I' | The hour as a number using a 12-hour clock (01 - 12) |
| '%j' | The day of the year as a number (001 - 366) |
| '%m' | Month of the year, from 01 to 12 |
| '%M' | Minutes after the hour 55 |
| '%p' | AM/PM indicator (AM) |
| '%S' | The second as a number (59, 20 , 01) |
| '%u' | ISO 8601 day of the week, to 7 for Sunday (7, 1) |
| '%U' | Sunday week of the year, from 00 (48) |
| '%V' | ISO 8601 week of the year, from 01 (48) |
| '%w' | The day of the week as a decimal, Sunday being 0 |
| '%W' | Monday week of the year, from 00 (48) |
| '%y' | The year as a number without a century (range 00 to 99) |
| '%Y' | Year with century (2000, 1914, 0325, 0001) |
| '%z' | Time zone offset, the date object is assumed local time (+1000, -0230) |
| '%Z' | Time zone name, the date object is assumed local time |
| '%\b' | Year, if year is in BCE, prints the BCE Year representation, otherwise result is similar to "%Y" (1 BCE, 40 BCE) # |
| '%\f' | Seconds including fraction (59.998, 01.123) # |
| '%%' | percent character % |
| '%r' | 12-hour time, from 01:00:00 AM (06:55:15 AM); same as "%I:%M:%S %p" |
| '%R' | hour:minute, from 01:00 (06:55); same as "%I:%M" |
| '%T' | 24-hour time, from 00:00:00 (06:55:15); same as "%H:%M:%S" |
| '%D' | month/day/year from 01/01/00 (12/02/79); same as "%m/%d/%y" |
| '%F' | year-month-day (1979-12-02); same as "%Y-%m-%d" |
| '%c' | The preferred date and time representation; same as "%x %X" |
| '%x' | The preferred date representation, same as "%a %b %d %\b" |
| '%X' | The preferred time representation, same as "%H:%M:%\f" |
| '${iso}'     | Iso format, same as "%Y-%m-%dT%T" |
| '${http}'    | http format, same as "%a, %d %b %Y %T GMT" |
| '${ctime}'   |ctime format, same as "%a %b %d %T GMT %Y" |
| '${rfc850}'  | RFC850 format, same as "%A, %d-%b-%y %T GMT" |
| '${rfc1123}' | RFC1123 format, same as "%a, %d %b %Y %T GMT" |
| '${asctime}' | asctime format, same as "%a %b %d %T %Y" |

<!-- {% endraw %} -->