#!/usr/bin/env python3
"""Read-only atlas checks. Warnings identify cells needing visual review."""
import argparse
from pathlib import Path
from PIL import Image


def inspect(path: Path, columns: int, rows: int) -> list[str]:
    image = Image.open(path).convert('RGBA')
    alpha = image.getchannel('A')
    problems = []
    for row in range(rows):
        for col in range(columns):
            box = (round(col * image.width / columns),
                   round(row * image.height / rows),
                   round((col+1) * image.width / columns),
                   round((row+1) * image.height / rows))
            cell = alpha.crop(box)
            mask = cell.point(lambda value: 255 if value >= 64 else 0)
            bbox = mask.getbbox()
            name = f'row{row+1}/column{col+1}'
            if bbox is None:
                problems.append(f'{name}: empty cell')
                continue
            x0, y0, x1, y1 = bbox
            if x0 <= 1 or y0 <= 1 or x1 >= cell.width-1 or y1 >= cell.height-1:
                problems.append(f'{name}: opaque content touches cell edge; possible clipping')
            histogram = mask.histogram()
            coverage = histogram[255] / (cell.width * cell.height)
            if coverage > .9:
                problems.append(f'{name}: {coverage:.0%} opaque; possible background contamination')
            if coverage < .03:
                problems.append(f'{name}: {coverage:.1%} opaque; unusually small head')
            # Uniformly opaque corners commonly indicate a painted background.
            corners = [cell.getpixel((x,y)) for x in (0,cell.width-1)
                       for y in (0,cell.height-1)]
            if min(corners) >= 64:
                problems.append(f'{name}: four corners opaque; background likely retained')
    return problems


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('atlases', nargs='+', type=Path)
    parser.add_argument('--columns', default=6, type=int)
    parser.add_argument('--rows', default=4, type=int)
    args = parser.parse_args()
    total = 0
    for path in args.atlases:
        problems = inspect(path, args.columns, args.rows)
        total += len(problems)
        print(f'{path.name}: {len(problems)} review flags')
        for problem in problems:
            print('  '+problem)
    print(f'{len(args.atlases)} atlases inspected; {total} review flags. '
          'A clean report does not establish anatomical alignment or art quality.')


if __name__ == '__main__':
    main()
