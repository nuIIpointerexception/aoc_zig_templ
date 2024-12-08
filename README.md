# aoc_zig

This is my repository for the [Advent of Code](https://adventofcode.com/) challenges in [Zig](https://ziglang.org/).
Other than overengineered solutions and highly optimized trash,
you will maybe find this also neat build system for fetching and submitting aoc code.
## Features
- Automatic input data fetching
- Submit your result with a command!
- Tests and benchmarking!
- Supports every year and every day!
## Usage

To fetch the input data for solutions, you need to provide a `TOKEN` file in the root directory of the repository. This file should contain a single line with your [advent of code](https://adventofcode.com/) cookie.

### Build & Run:
```bash
zig build <day> -Dyear=<year>
```
```bash
zig build 1
```
If no year is provided, the current year will be used.
If no day is provided, the current day will be used.
### Test:
```bash
zig build test:<day> -Dyear=<year
```
example for day 1 (automatic year detection):
```bash
zig build test:1
```
### Submit:
```bash
zig build submit:<day> -Dyear=<year
```
example:
```bash
zig build submit:1
```
### Hard reset / clean project:
```bash
zig build clean
```
NOTE: For your own safety you will have to add -Dconfirm=true to confirm this action!
## Contributing

Contributions are welcome!
If you have a solution to an existing solution,
feel free to submit a PR.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details