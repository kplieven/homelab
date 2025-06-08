#!/usr/bin/env python3

import os
import re
from datetime import datetime, timedelta
from typing import List

def parse_date_from_filename(filename: str) -> datetime:
    """Parse YYYYMMDD date from filename and return datetime object"""
    match = re.match(r'^[^0-9]*(\d{4})(\d{2})(\d{2})\.tar\.gz$', filename)
    if not match:
        return None
    year, month, day = map(int, match.groups())
    try:
        return datetime(year=year, month=month, day=day)
    except ValueError:
        return None

def get_backup_files(directory: str) -> List[datetime]:
    """Get all valid backup files with their dates"""
    backups = []
    for filename in os.listdir(directory):
        date = parse_date_from_filename(filename)
        if date:
            backups.append((date, filename))
    return sorted(backups, key=lambda x: x[0])

def should_keep_file(file_date: datetime, today: datetime) -> bool:
    """Determine if a file should be kept based on retention rules"""
    # Rule 4: Keep all backups of the last 3 days
    if file_date > today - timedelta(days=3):
        return True
    
    # Rule 1: Keep January 1st backups for the last two years
    if file_date.month == 1 and file_date.day == 1:
        if file_date.year >= today.year - 1:  # Current year and previous year
            return True
    
    # Rule 2: Keep first day of month for current and last month
    if file_date.day == 1:
        if file_date.year == today.year and file_date.month == today.month:
            return True
        last_month = today.replace(day=1) - timedelta(days=1)
        if file_date.year == last_month.year and file_date.month == last_month.month:
            current_month_first_day = today.replace(day=1)
            if current_month_first_day < today - timedelta(days=3):
                return True
    
    # Rule 3: Keep first day of the last 2 weeks, but only delete once
    # the current weekly one would not be kept by rule 4
    if file_date.weekday() == 0:
        if file_date > today - timedelta(weeks=2, days=3):
            return True
    
    return False

def apply_retention_policy(directory: str, dry_run: bool = True):
    """Apply retention policy to backup files"""
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    backups = get_backup_files(directory)
    
    print(f"Found {len(backups)} backup files")
    print("Files to be kept:")
    keep_count = 0
    delete_count = 0
    
    for date, filename in backups:
        if should_keep_file(date, today):
            print(f"KEEP: {filename}")
            keep_count += 1
        else:
            if dry_run:
                print(f"WOULD DELETE: {filename}")
            else:
                print(f"DELETING: {filename}")
                os.remove(os.path.join(directory, filename))
            delete_count += 1
    
    print(f"\nSummary:")
    print(f"Total files: {len(backups)}")
    print(f"Files to keep: {keep_count}")
    print(f"Files to delete: {delete_count}")
    if dry_run:
        print("\nThis was a dry run. No files were actually deleted.")
        print("Run with --apply to actually delete files.")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Apply backup retention policy")
    parser.add_argument("directory", help="Directory containing backup files")
    parser.add_argument("--apply", action="store_true", help="Actually delete files (default is dry run)")
    args = parser.parse_args()
    
    apply_retention_policy(args.directory, dry_run=not args.apply)
