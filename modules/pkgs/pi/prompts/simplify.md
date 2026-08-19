Search for inefficiencies and points where the code can be refactored or simplified. Remove any functionality or checks that are redundant. For example:

- Prefer simple code over "defence in depth" code. Do not have redundant checks
- Do not create unecessary helper functions that do not perform a big task and would be easier to read if inlined
- Do not get caught up on overly complicated edge cases

The end result should have code that is easier to read, shorter, and has less technical debt.
