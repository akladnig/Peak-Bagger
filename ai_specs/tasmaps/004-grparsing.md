# Grid Reference Parsing
This specification is to clarify the  parsing of map names and grid references of 004-prompt-spec.md

Update Map Name and Grid Reference Pasrsing as follows, using Wellington map and coordinate 55GEN194000507000 as an example:
- "Wellington" parses to 55GEN2000055000 (i.e. centre of map) - map name only
- "Wellington 15" parses to 55GEN1000050000
- "Wellington 1 5" parses to 55GEN1000050000
- "Wellington 1951" parses to 55GEN1900051000
- "Wellington 19 51" parses to 55GEN1900051000
- "Wellington 194507" parses to 55GEN1940050700
- "Wellington 194 507" parses to 55GEN1940050700
- "Wellington 19435078" parses to 55GEN1943050780
- "Wellington 1943 5078" parses to 55GEN1943050780
- "Wellington 1943250789" parses to 55GEN1943250789
- "Wellington 19432 50789" parses to 55GEN1943250789

When in the Wellington map:
- "15" parses to 55GEN1000050000
- "1 5" parses to 55GEN1000050000
- "1951" parses to 55GEN1900051000
- "19 51" parses to 55GEN1900051000
- "194507" parses to 55GEN1940050700
- "194 507" parses to 55GEN1940050700
- "19435078" parses to 55GEN1943050780
- "1943 5078" parses to 55GEN1943050780
- "1943250789" parses to 55GEN1943250789
- "19432 50789" parses to 55GEN1943250789
otherwise print an error message.

Prefixing any grid reference combination with a 2 letter 100k sqaure id will create a full coordinate. e.g. :
"EN0123456789" parses to 55GEN012345678
"EN 01234 56789" parses to 55GEN012345678

Create unit tests for all these.
