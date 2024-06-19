'''
This file contains the main entry point for the Gomoku game application.
'''
from tkinter import messagebox as tkmessagebox
from game import Game
from gomoku_gui import GomokuGUI
if __name__ == "__main__":
    game = Game()
    gui = GomokuGUI(game)
    gui.run()