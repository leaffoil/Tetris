extends Node

enum Difficulty { EASY, NORMAL, HARD }

const SETTINGS := {
	Difficulty.EASY: {"name": "Easy", "start_level": 0, "speed_mult": 0.8},
	Difficulty.NORMAL: {"name": "Normal", "start_level": 0, "speed_mult": 1.0},
	Difficulty.HARD: {"name": "Hard", "start_level": 5, "speed_mult": 1.3},
}

var difficulty: int = Difficulty.NORMAL
