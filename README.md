# Voxel Prototype

This repository now hosts a Godot 4.5 project for experimenting with voxel terrain rendering and interaction.

## Getting started

1. Install [Godot 4.5](https://godotengine.org/download/windows/).
2. Clone this repository.
3. Open the project by pointing Godot to the repository root (the `project.godot` file lives in the root directory).
4. Run the project. The default scene (`scenes/Main.tscn`) will load automatically.

## Controls

- **W/A/S/D**: Move around the world.
- **Space**: Ascend.
- **Mouse**: Look around (press `Q` to toggle cursor capture).
- **Left Mouse Button**: Remove the block under the cursor.
- **Right Mouse Button**: Place a block along the hit surface.

## Project structure

- `scenes/` contains reusable Godot scenes. `scenes/Main.tscn` is the bootstrap entry point.
- `scripts/` contains GDScript files, including the `VoxelWorld` terrain generator and chunk mesher.
- `default_env.tres` defines the default environment used by the renderer.
- `icon.svg` is the project icon displayed in the editor and export templates.

The Python/Tkinter prototype has been removed so the repository is fully focused on the Godot voxel workflow.
