"""Command-line entry point of the tools container.

  python cli.py init         fill analytics_db once if it is empty (runs automatically at startup)
  python cli.py etl          re-run the nightly ETL
  python cli.py lineage      register the cross-database ETL lineage in OpenMetadata
  python cli.py reset-data   re-seed the source databases + ETL
  python cli.py wipe         delete everything DEMO.md creates in OpenMetadata
"""
import sys

import nexabank
import openmeta

cmd = sys.argv[1] if len(sys.argv) > 1 else "init"
if cmd == "init":
    if nexabank.analytics_ready():
        print("analytics_db already filled; nothing to do")
    else:
        nexabank.run_etl()
elif cmd == "etl":
    nexabank.run_etl()
elif cmd == "lineage":
    openmeta.register_etl_lineage()
elif cmd == "reset-data":
    nexabank.reset_data()
elif cmd == "wipe":
    openmeta.wipe()
else:
    sys.exit(__doc__)
