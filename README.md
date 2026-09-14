# sql-banner-toolkit

Oracle SQL queries for Banner/Ellucian, published so other schools running
Banner can adapt them.

One folder per subject area, each with its own README covering what the query
does, what it needs, its output columns, the assumptions specific to this
institution, and dated audit notes.

| Folder | What it covers |
| --- | --- |
| [`veterans-benefits/`](veterans-benefits/) | VA certification and outreach |

## Adapting these elsewhere

Every query here was written against one institution's Banner instance and run
in SQL Developer. Before running one somewhere else, read that folder's README
down to **Assumptions** and **Audit notes** — they record what was checked
against real data, when, and what got removed after turning out to be
unnecessary. Those findings are the part least likely to hold at another school.

Term codes, email type codes (`TEMA` / `EMA`) and status indicators are all
local conventions. Nothing here touches anything but Banner tables, and nothing
needs privileges beyond read access to them.

## Data

No real student data is in this repository and none should be added. A query
that takes a pasted list expects placeholder values in the committed version;
fill it in locally and do not commit the result.
