#!/usr/bin/env python3
from __future__ import annotations

import shutil

from server import OBJECT_STORAGE_DIR, REPOSITORY, default_db


if __name__ == "__main__":
    REPOSITORY.reset(default_db)
    if OBJECT_STORAGE_DIR.exists():
        shutil.rmtree(OBJECT_STORAGE_DIR)
    OBJECT_STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    print("database reset: backend/data/treehole.db")
    print("object storage reset: backend/storage/objects")
