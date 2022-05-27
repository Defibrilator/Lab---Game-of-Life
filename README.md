# Game of Life in Nios II Assembly
 
The Game of Life is a cellular automaton devised by British mathematician John Conway in 1970.

The game requires no players: its evolution is determined by its initial state (also called the seed of the
game). The playing field of the game is an infinite two-dimensional grid of cells, where each cell is either
alive or dead. At each time step, the game evolves following this set of rules:
• Underpopulation: any living cell dies if it has (strictly) fewer than two live neighbours.
• Overpopulation: any living cell dies if it has (strictly) more than three live neighbours.
• Reproduction: any dead cell becomes alive if it has exactly three live neighbours.
• Stasis: Any live cell remains alive if it has two or three live neighbours.

The goal of this lab was to implement an assembly version of the game of life. In addition to the
previous rules, we added some control functions to the game, as well as walls, where no cell could
ever be alive in them. 
