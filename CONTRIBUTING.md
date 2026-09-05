# Contributing to bash-cli-starter

First off, thank you for considering contributing to `bash-cli-starter`! Contributions are what make the open-source community an incredible place to learn, inspire, and create.

## Code of Conduct

Please remain respectful, constructive, and friendly in all issues, pull requests, and discussions.

## How Can I Contribute?

### 1. Reporting Bugs

Before opening a new issue, please search existing issues to see if it has already been reported. When submitting a bug report, please include:

- Your operating system and environment (e.g., WSL2 Ubuntu, macOS, Windows PowerShell).
- Your Bash version (`bash --version`).
- Clear steps to reproduce the issue.
- Expected vs. actual behavior.

### 2. Suggesting Features

Feature suggestions are always welcome! Please open an issue outlining:

- The problem your feature solves.
- Proposed implementation details or syntax.
- Why this addition benefits a general-purpose Bash boilerplate.

### 3. Submitting Pull Requests

1. **Fork the Repository**:
   Fork `sempitern0/bash-cli-starter` to your own GitHub account.

2. **Clone and Initialize**:

   ```bash
   git clone [https://github.com/YOUR-USERNAME/bash-cli-starter.git](https://github.com/YOUR-USERNAME/bash-cli-starter.git)
   cd bash-cli-starter
   make setup
   ```

3. **Create a Feature Branch**:

   ```bash
   git checkout -b feature/my-new-feature
   ```

4. **Development Guidelines**:
   - Keep scripts modular and placed in `lib/` when appropriate.
   - Run `make lint` to ensure all shell scripts pass ShellCheck cleanly.
   - Ensure line endings remain **LF** (`\n`).
   - Keep external dependencies to a minimum to preserve cross-platform portability.

5. **Commit & Push**:
   Commit your changes (the pre-commit hook will run automatically) and push to your fork:

   ```bash
   git push origin feature/my-new-feature
   ```

6. **Open a Pull Request**:
   Submit your PR against the `main` branch of `sempitern0/bash-cli-starter`.

Thank you for your help!
