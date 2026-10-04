"""Small helper to update localization/strings.csv safely.

Usage from other scripts:  from edit_strings import set_strings; set_strings({"KEY": ("en", "ro")})
Or run directly:           python3 tools/dev/edit_strings.py KEY "English" "Română"
"""
import csv, sys, os

CSV_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "localization", "strings.csv")

def load():
    with open(CSV_PATH, encoding="utf-8", newline="") as f:
        rows = list(csv.reader(f))
    return rows[0], rows[1:]

def save(header, rows):
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)

def set_strings(updates, after=None):
    header, rows = load()
    index = {r[0]: i for i, r in enumerate(rows)}
    for key, (en, ro) in updates.items():
        if key in index:
            rows[index[key]] = [key, en, ro]
        else:
            pos = index.get(after, len(rows) - 1) + 1 if after else len(rows)
            rows.insert(pos, [key, en, ro])
            index = {r[0]: i for i, r in enumerate(rows)}
            after = key if after else None
    save(header, rows)

if __name__ == "__main__":
    if len(sys.argv) == 4:
        set_strings({sys.argv[1]: (sys.argv[2], sys.argv[3])})
