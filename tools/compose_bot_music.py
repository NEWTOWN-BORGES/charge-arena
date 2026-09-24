"""Reuse the retired alternative boss compositions exclusively for campaign bots."""
from pathlib import Path
from compose_cup_score import compose
root = Path(__file__).resolve().parents[1] / "audio" / "bots"
root.mkdir(exist_ok=True)
for index in range(1, 11):
    compose(index, root / f"music_bot_{index}.ogg", rhythm_gain=1.45)
