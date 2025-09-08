# Contributing to SeedSphere

Thanks for your interest in contributing! This guide explains how to set up your environment, the workflow for proposing changes, and our coding style.

## Development setup

- Requirements
  - Node.js 22.x (LTS or current)
  - npm (comes with Node)

- Install and run
  - Install dependencies:
    - `npm install`
  - Start development server (Express + Vite dev):
    - `npm run dev`
  - Build production assets:
    - `npm run build`
  - Preview production server locally:
    - `npm run preview`

- Testing
  - Run tests:
    - `npm test`

## Branching and PR flow

- Create a feature branch from `dev`:
  - `git checkout -b feature/short-description`
- Keep commits small and self-contained.
- Update or add tests where applicable.
- Run a production build locally before requesting review:
  - `npm run build`
- Open a Pull Request targeting `dev` and fill out the PR template.
- After review and squash/merge into `dev`, maintainers will merge to `main` as needed for releases.

## Coding style

- Frontend: Vue 3 Composition API, Tailwind v4, DaisyUI v5.
- Backend: Node/Express with CommonJS modules under `server/` and ES modules in the entry.
- UI
  - Use centralized spacing variables and helpers (see `src/assets/main.css`).
  - Use label‑less toggles with tooltips and `toggle-success` for green-on state on the Configure page.
- Security
  - Follow the production CSP in `server/index.js` when adding external resources.
  - Avoid storing secrets in the repo. Use environment variables.

## Commit messages

- Use clear types and scopes, for example:
  - `feat(configure): add stacked layout to Optimization card`
  - `fix(cors): reflect Origin header for web.strem.io`
  - `chore: repo hygiene`

## Reporting bugs and requesting features

- Use the GitHub issue templates (Bug Report, Feature Request).
- For security issues, please follow the instructions in `SECURITY.md`.
