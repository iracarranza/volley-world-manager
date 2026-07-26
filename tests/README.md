# Tests

Run the headless foundation suite from the project root:

```sh
godot --headless --path . --script tests/test_runner.gd
```

The first suite covers normalized court coordinates, rotation legality, typed
offensive-play serialization, play validation, and manager playbook state.
