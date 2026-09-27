"""Decode a one-time Roku diagnostics support code offline, without a server."""

import argparse
import json


ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
STAGES = ("app", "connect", "guide", "playback", "archive", "vod", "capabilities")


def decode(code: str) -> dict:
    compact = code.strip().replace("-", "")
    if len(code) > 120 or any(char not in ALPHABET for char in compact):
        raise ValueError("Invalid support code characters or length")
    if not compact.startswith("D1") or len(compact) < 6:
        raise ValueError("Unknown support code version")
    count = ALPHABET.index(compact[2])
    if not 1 <= count <= 8 or len(compact) != 3 + count * 7 + 3:
        raise ValueError("Invalid support code length")
    checksum = 0
    for char in compact[:-3]:
        checksum = (checksum * 31 + ALPHABET.index(char)) % 46656
    if compact[-3:] != encode36(checksum, 3):
        raise ValueError("Support code checksum mismatch")
    events = []
    for i in range(count):
        chunk = compact[3 + i * 7:10 + i * 7]
        stage = ALPHABET.index(chunk[0])
        number = int(chunk[1:4], 36) - 4095
        elapsed = ALPHABET.index(chunk[4])
        age = int(chunk[5:7], 36)
        if stage >= len(STAGES) or not -4095 <= number <= 4095 or elapsed > 35 or age > 60:
            raise ValueError("Support code field out of range")
        events.append({
            "stage": STAGES[stage], "code": number,
            "age_minutes": age,
            "elapsed_ms_bucket": f">={elapsed * 250}" if elapsed == 35 else f"{elapsed * 250}-{elapsed * 250 + 249}",
        })
    return {"schema": 1, "events": events}


def encode36(value: int, width: int) -> str:
    result = ""
    for _ in range(width):
        result = ALPHABET[value % 36] + result
        value //= 36
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("code", help="uppercase code shown on the TV")
    args = parser.parse_args()
    try:
        print(json.dumps(decode(args.code), indent=2))
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
