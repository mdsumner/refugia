"""Write the shared cell tables (pilots/export_cells.R) as parquet.

python3 -I sources/cells_parquet.py <dir>

Reads <dir>/cells_metrics.csv and <dir>/cells_flags.csv, writes
cells_metrics.parquet and cells_flags.parquet beside them (zstd), with
string columns dictionary encoded and level as int8. The cell column holds
S2 cell tokens (strings), never bare 64-bit ids.
"""
import os
import sys

import pyarrow as pa
import pyarrow.csv as pcsv
import pyarrow.parquet as pq

d = sys.argv[1] if len(sys.argv) > 1 else "data/mvp"
types = {
    "cells_metrics": {"domain": pa.string(), "source": pa.string(), "period": pa.string(),
                      "level": pa.int8(), "cell": pa.string(), "lon": pa.float64(),
                      "lat": pa.float64(), "region_set": pa.string(), "region": pa.string(),
                      "variable": pa.string(), "metric": pa.string(), "value": pa.float64(),
                      "units": pa.string()},
    "cells_flags": {"domain": pa.string(), "level": pa.int8(), "cell": pa.string(),
                    "lon": pa.float64(), "lat": pa.float64(), "region_set": pa.string(),
                    "region": pa.string(), "kind": pa.string(), "flag": pa.bool_()},
}
for name, ct in types.items():
    t = pcsv.read_csv(os.path.join(d, name + ".csv"),
                      convert_options=pcsv.ConvertOptions(column_types=ct,
                                                          true_values=["TRUE"],
                                                          false_values=["FALSE"]))
    of = os.path.join(d, name + ".parquet")
    pq.write_table(t, of, compression="zstd",
                   use_dictionary=[c for c, ty in ct.items() if ty == pa.string() and c != "cell"])
    print(of, t.num_rows, "rows", os.path.getsize(of) // 1024, "KB")
