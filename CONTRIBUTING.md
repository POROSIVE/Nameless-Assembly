# Contributions
Thank you for your interest in contributing to Nameless Assembly Project.

## Before You Start
- Read README.md
- Check open issues
- Discuss large changes before even tried to work on implementation
- Follow the official Godot GDScript style guide.
- Use typed GDScript whenever practical.
- Keep functions small and focused.
- Avoid unnecessary global state.
- Prefer composition over large inheritance hierarchies.
- Do not modify another contributor's system without discussing it first.
- Do not commit generated files.
- Do not commit `.godot/`.
- All contributors must use "Godot 4.7.2" Forward+ renderer

## Development
1. Fork/clone repository
2. Create a feature branch
3. Make changes
4. Test in Godot
5. Commit changes
6. Open a Pull Request

## Branch Naming
  ```bash
feature/<name>
fix/<name>
refactor/<name>
docs/<name>
  ```

Examples:
  ```bash
feature/inventory
fix/enemy-pathfinding
refactor/save-system
  ```

## Naming
Files:
snake_case

Classes:
PascalCase

Functions:
snake_case

Variables:
snake_case

Constants:
CONSTANT_CASE

Signals:
past_tense

Examples:
  ```bash
  func open_door():
      pass
  signal door_opened
  const MAX_SPEED := 300.0
  var movement_speed := 100.0
  ```

## Comments
Comments should explain WHY, not WHAT.

Bad:
  ```bash
# Increase health by 10
health += 10
  ```

Good:
  ```bash
# Respawn healing prevents the player from getting stuck
# in the death loop after checkpoint loading.
health += 10
  ```

## Functions
Functions should generally perform one logical responsibility.
Bad:
  ```bash
func process_player():
    move_player()
    check_inventory()
    save_game()
    update_ui()
    spawn_enemies()
  ```
Prefer separate responsibilities.

## Pull Requests
Every PR must:
- Have a clear description.
- Explain what changed.
- Explain how it was tested.
- Avoid unrelated changes

## Commits
follow the commit summary based on their type:

- feat: add player movement
- feat: add enemy health system
- fix: prevent player falling through floor
- refactor: simplify combat manager
- docs: update contribution guide
- chore: update Godot version

